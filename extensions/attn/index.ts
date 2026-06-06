import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { Type } from 'typebox';
import { spawn, execSync } from 'node:child_process';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { openSync } from 'node:fs';
import WebSocket from 'ws';

// --- Config ---

const DAEMON_URL = 'http://127.0.0.1:9742';
const WS_URL = 'ws://127.0.0.1:9742';
const DAEMON_DIR = join(homedir(), '.pi', 'agent', 'repositories', 'attn-core');

const ATTN_SESSION = process.env.ATTN_SESSION || null;

let ws: import('ws').WebSocket | null = null;
let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
let lastInboundFrom: string | null = null;
let localPeers: string[] = [];

// --- Daemon lifecycle ---

function isDaemonRunning(): boolean {
  try {
    execSync(`curl -s ${DAEMON_URL}/status`, { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

function startDaemon(): void {
  if (isDaemonRunning()) return;

  try {
    const child = spawn('node', ['dist/index.js'], {
      cwd: DAEMON_DIR,
      detached: true,
      stdio: ['ignore', 'ignore', openSync('/tmp/attn-daemon.log', 'a')],
    });
    child.unref();
  } catch {
    // Daemon may not be built yet — skip silently
  }
}

function stopDaemon(): boolean {
  try {
    // Find PID listening on port 9742 (safe — only kills the attn daemon)
    const out = execSync('netstat -ano | findstr :9742', {
      encoding: 'utf-8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    const match = out.match(/:9742\s+\S+\s+\S+\s+\S+\s+(\d+)/);
    if (match && match[1]) {
      const pid = match[1];
      execSync(`taskkill //PID ${pid} //F`, { stdio: 'ignore' });
      return true;
    }
  } catch {
    // No process on port 9742 or kill failed — nothing to stop
  }
  return false;
}

function restartDaemon(): void {
  stopDaemon();
  // Brief pause to let OS release the port
  setTimeout(() => startDaemon(), 500);
}

function connectDaemonWs(pi: ExtensionAPI): void {
  if (ws) {
    try { ws.close(); } catch { /* ignore */ }
  }
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }

  try {
    const sessionParam = ATTN_SESSION ? `?session=${encodeURIComponent(ATTN_SESSION)}` : '';
    ws = new WebSocket(`${WS_URL}${sessionParam}`);

    ws.on('open', () => {
      // Connected — ready to receive messages
    });

    ws.on('message', (raw: { toString: () => string }) => {
      try {
        const msg = JSON.parse(raw.toString()) as {
          type: string;
          from?: string;
          message?: string;
          filename?: string;
          path?: string;
          size?: number;
          id?: string;
          ts?: number;
          trust?: string;
          agentName?: string;
          groupId?: string;
          groupName?: string;
          reactionMessageId?: string;
          local?: boolean;
        };

        // File message
        if (msg.type === 'file' && msg.from && msg.path) {
          lastInboundFrom = msg.from;
          const name = msg.agentName || msg.from;
          const sizeKB = Math.round((msg.size || 0) / 1024);
          pi.sendUserMessage(
            `[attn] 📎 File from ${name}: ${msg.filename} (${sizeKB} KB)\nSaved to: ${msg.path}`,
            { deliverAs: 'steer' },
          );
        } else if (msg.type === 'message' && msg.from && msg.message) {
          lastInboundFrom = msg.from;

          // Build notification summary
          let prefix = '';
          const name = msg.agentName || msg.from;
          if (msg.local) {
            prefix = '💻 Local: ';
          } else if (msg.trust === 'pending') {
            prefix = '⚠️ Pending: ';
          } else if (msg.trust === 'reaction') {
            pi.sendUserMessage(
              `[attn] ${name} reacted ${msg.message} to a message`,
              { deliverAs: 'steer' },
            );
            return;
          } else if (msg.groupId) {
            prefix = `[${msg.groupName || msg.groupId}] `;
          }

          const truncated =
            msg.message.length > 300
              ? msg.message.slice(0, 300) + '...'
              : msg.message;

          pi.sendUserMessage(
            `[attn] ${prefix}Message from ${name}:\n\n${truncated}\n\n---\nUse attn_reply or attn_send to respond.`,
            { deliverAs: 'steer' },
          );
        } else if (msg.type === 'local-ack') {
          // Silently track local delivery confirmations
        }
      } catch {
        // ignore parse errors
      }
    });

    ws.on('close', () => {
      ws = null;
      // Reconnect after 5 seconds
      reconnectTimer = setTimeout(() => connectDaemonWs(pi), 5000);
    });

    ws.on('error', () => {
      ws = null;
      reconnectTimer = setTimeout(() => connectDaemonWs(pi), 5000);
    });
  } catch {
    // ws module not available — tools still work via REST
  }
}

// --- HTTP helper ---

async function daemonFetch(
  path: string,
  options?: { method?: string; body?: unknown },
): Promise<unknown> {
  const url = `${DAEMON_URL}${path}`;
  const res = await fetch(url, {
    method: options?.method ?? 'GET',
    headers: { 'Content-Type': 'application/json' },
    body: options?.body ? JSON.stringify(options.body) : undefined,
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(err || `HTTP ${res.status}`);
  }

  return res.json();
}

// --- Export extension ---

export default function (pi: ExtensionAPI) {
  // Auto-start daemon on session start
  pi.on('session_start', async () => {
    startDaemon();
    // Give daemon a moment to start, then connect
    setTimeout(() => connectDaemonWs(pi), 2000);
  });

  // attn_send — send a message to another agent
  pi.registerTool({
    name: 'attn_send',
    label: 'attn Send',
    description:
      'Send an encrypted message to another agent via attn. Use their Ethereum address (0x...) or .attn name.',
    parameters: Type.Object({
      to: Type.String({
        description: 'Recipient address (0x...) or .attn name',
      }),
      message: Type.String({ description: 'Message text to send' }),
    }),
    async execute(_toolCallId, params) {
      try {
        // Always refresh local peers cache before deciding routing
        try {
          const lp = (await daemonFetch('/local-peers')) as {
            sessions: string[];
            count: number;
          };
          localPeers = lp.sessions.filter((s) => s !== ATTN_SESSION);
        } catch {
          // If daemon not reachable, fall through to relay attempt
        }

        // Check if target is a local peer
        if (localPeers.includes(params.to)) {
          if (!ws || ws.readyState !== WebSocket.OPEN) {
            return {
              content: [{ type: 'text', text: `Local peer ${params.to} found but WS not connected. Try again shortly.` }],
              details: { error: 'ws not connected' },
            };
          }

          ws.send(
            JSON.stringify({
              type: 'local',
              to: params.to,
              message: params.message,
            }),
          );

          return {
            content: [
              {
                type: 'text',
                text: `Local message sent to ${params.to}`,
              },
            ],
            details: { local: true, to: params.to },
          };
        }

        // Otherwise send via relay
        const result = (await daemonFetch('/send', {
          method: 'POST',
          body: { to: params.to, message: params.message },
        })) as { id: string; status: string };

        return {
          content: [
            {
              type: 'text',
              text: `Message sent to ${params.to} (id: ${result.id})`,
            },
          ],
          details: result,
        };
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        return {
          content: [{ type: 'text', text: `Failed to send: ${msg}` }],
          details: { error: msg },
        };
      }
    },
  });

  // attn_local_peers — list locally connected attn sessions
  pi.registerTool({
    name: 'attn_local_peers',
    label: 'attn Local Peers',
    description:
      'List locally connected attn sessions (worker tabs, other pi instances on this machine).',
    parameters: Type.Object({}),
    async execute() {
      try {
        const result = (await daemonFetch('/local-peers')) as {
          sessions: string[];
          count: number;
        };

        // Update local cache
        localPeers = result.sessions.filter((s) => s !== ATTN_SESSION);

        if (result.count === 0) {
          return {
            content: [
              {
                type: 'text',
                text: 'No local attn sessions connected.',
              },
            ],
            details: result,
          };
        }

        const lines = result.sessions.map(
          (s) => `  ${s === ATTN_SESSION ? '→ ' : '  '}${s}${s === ATTN_SESSION ? ' (this session)' : ''}`,
        );
        const text = `Local attn sessions (${result.count}):\n${lines.join('\n')}`;

        return {
          content: [{ type: 'text', text }],
          details: result,
        };
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        return {
          content: [
            { type: 'text', text: `Failed to fetch local peers: ${msg}` },
          ],
          details: { error: msg },
        };
      }
    },
  });

  // attn_peers — list contacts / known agents
  pi.registerTool({
    name: 'attn_peers',
    label: 'attn Peers',
    description:
      'List your attn contacts and known agents. For local sessions use attn_local_peers.',
    parameters: Type.Object({}),
    async execute() {
      try {
        const result = (await daemonFetch('/peers')) as {
          peers: Array<{ address: string; name: string | null; added_at: string }>;
        };

        if (result.peers.length === 0) {
          return {
            content: [
              {
                type: 'text',
                text: 'No contacts yet. Use POST /contacts or .attn names to add contacts.',
              },
            ],
            details: result,
          };
        }

        const lines = result.peers.map(
          (p) => `  ${p.name || p.address} (${p.address}) — added ${p.added_at}`,
        );
        const text = `Contacts (${result.peers.length}):\n${lines.join('\n')}`;

        return {
          content: [{ type: 'text', text }],
          details: result,
        };
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        return {
          content: [{ type: 'text', text: `Failed to fetch peers: ${msg}` }],
          details: { error: msg },
        };
      }
    },
  });

  // attn_reply — reply to the last inbound message
  pi.registerTool({
    name: 'attn_reply',
    label: 'attn Reply',
    description:
      'Reply to the most recent inbound attn message.',
    parameters: Type.Object({
      message: Type.String({ description: 'Reply message text' }),
    }),
    async execute(_toolCallId, params) {
      if (!lastInboundFrom) {
        return {
          content: [
            {
              type: 'text',
              text: 'No recent inbound message to reply to.',
            },
          ],
          details: {},
        };
      }

      try {
        const result = (await daemonFetch('/send', {
          method: 'POST',
          body: { to: lastInboundFrom, message: params.message },
        })) as { id: string; status: string };

        return {
          content: [
            {
              type: 'text',
              text: `Reply sent to ${lastInboundFrom} (id: ${result.id})`,
            },
          ],
          details: result,
        };
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        return {
          content: [{ type: 'text', text: `Failed to reply: ${msg}` }],
          details: { error: msg },
        };
      }
    },
  });

  // attn_history — fetch message history with a peer
  pi.registerTool({
    name: 'attn_history',
    label: 'attn History',
    description:
      'Fetch recent message history with a specific agent or address.',
    parameters: Type.Object({
      with: Type.String({
        description: 'Agent address, .attn name, or group ID',
      }),
      limit: Type.Optional(
        Type.Number({ description: 'Number of messages (default: 20)' }),
      ),
    }),
    async execute(_toolCallId, params) {
      try {
        const limit = params.limit ?? 20;
        const result = (await daemonFetch(
          `/history?with=${encodeURIComponent(params.with)}&limit=${limit}`,
        )) as {
          messages: Array<{
            id: string;
            peer: string;
            direction: string;
            content: string;
            ts: string;
          }>;
        };

        if (result.messages.length === 0) {
          return {
            content: [
              {
                type: 'text',
                text: `No history with ${params.with}.`,
              },
            ],
            details: result,
          };
        }

        const lines = result.messages.map((m) => {
          const dir = m.direction === 'inbound' ? '←' : '→';
          const time = new Date(m.ts).toLocaleString();
          const preview =
            m.content.length > 150
              ? m.content.slice(0, 150) + '...'
              : m.content;
          return `  ${dir} [${time}] ${preview}`;
        });

        const text = `History with ${params.with} (${result.messages.length} messages):\n${lines.join('\n')}`;

        return {
          content: [{ type: 'text', text }],
          details: result,
        };
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        return {
          content: [
            { type: 'text', text: `Failed to fetch history: ${msg}` },
          ],
          details: { error: msg },
        };
      }
    },
  });

  // attn_status — check daemon/relay status
  pi.registerTool({
    name: 'attn_status',
    label: 'attn Status',
    description:
      'Check the attn daemon status and relay connection.',
    parameters: Type.Object({}),
    async execute() {
      try {
        const result = (await daemonFetch('/status')) as {
          address: string;
          relayConnected: boolean;
          peers: number;
        };

        const text = [
          `attn daemon: running`,
          `Address: ${result.address}`,
          `Relay: ${result.relayConnected ? 'connected' : 'disconnected'}`,
          `Contacts: ${result.peers}`,
        ].join('\n');

        return {
          content: [{ type: 'text', text }],
          details: result,
        };
      } catch {
        return {
          content: [
            {
              type: 'text',
              text: 'attn daemon is not running. It should auto-start shortly.',
            },
          ],
          details: { running: false },
        };
      }
    },
  });
}
