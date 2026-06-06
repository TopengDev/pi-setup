#!/usr/bin/env node
/**
 * MCP server wrapping the attn daemon API.
 * Usage: node attn-mcp-server.js
 * OpenCode config:
 *   "mcpServers": { "attn": { "type": "stdio", "command": "node", "args": ["mcp/attn-mcp-server.js"] } }
 */

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { ListToolsRequestSchema, CallToolRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const http = require('http');

const ATTN_URL = 'http://127.0.0.1:9742';
let lastInboundFrom = null;

// ── Attn daemon helpers ──────────────────────────────────────────────────
function attnPost(path, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request({
      hostname: '127.0.0.1', port: 9742, path, method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) },
      timeout: 15000,
    }, (res) => {
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(buf || '{}') }); }
        catch { resolve({ status: res.statusCode, body: buf }); }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function attnGet(path) {
  return new Promise((resolve, reject) => {
    http.get(`${ATTN_URL}${path}`, (res) => {
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => {
        try { resolve(JSON.parse(buf)); }
        catch { resolve(buf); }
      });
    }).on('error', reject);
  });
}

// ── MCP Server ──────────────────────────────────────────────────────────
const server = new Server(
  { name: 'attn-mcp', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

// Tool definitions
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'attn_send',
      description: 'Send an encrypted message to another agent via the attn relay. Use their Ethereum address (0x...) or .attn name.',
      inputSchema: {
        type: 'object',
        properties: {
          to: { type: 'string', description: 'Recipient address (0x...) or .attn name' },
          message: { type: 'string', description: 'Message text to send' },
        },
        required: ['to', 'message'],
      },
    },
    {
      name: 'attn_reply',
      description: 'Reply to the most recent inbound attn message.',
      inputSchema: {
        type: 'object',
        properties: {
          message: { type: 'string', description: 'Reply message text' },
        },
        required: ['message'],
      },
    },
    {
      name: 'attn_status',
      description: 'Check the attn daemon status and relay connection.',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'attn_peers',
      description: 'List your attn contacts and known agents.',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'attn_local_peers',
      description: 'List locally connected attn sessions (other pi sessions on this machine).',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'attn_history',
      description: 'Fetch recent message history with a specific agent.',
      inputSchema: {
        type: 'object',
        properties: {
          with: { type: 'string', description: 'Agent address or .attn name' },
          limit: { type: 'number', description: 'Number of messages (default: 20)' },
        },
        required: ['with'],
      },
    },
  ],
}));

// Tool execution
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'attn_send': {
        const { status, body } = await attnPost('/send', { to: args.to, message: args.message });
        return { content: [{ type: 'text', text: JSON.stringify({ id: body.id, status: body.status || status }) }] };
      }
      case 'attn_reply': {
        if (!lastInboundFrom) {
          return { content: [{ type: 'text', text: 'Error: No inbound message to reply to' }] };
        }
        const { status, body } = await attnPost('/send', { to: lastInboundFrom, message: args.message });
        return { content: [{ type: 'text', text: JSON.stringify({ id: body.id, status: body.status || status }) }] };
      }
      case 'attn_status': {
        const data = await attnGet('/status');
        return { content: [{ type: 'text', text: JSON.stringify(data) }] };
      }
      case 'attn_peers': {
        const data = await attnGet('/peers');
        return { content: [{ type: 'text', text: JSON.stringify(data) }] };
      }
      case 'attn_local_peers': {
        const data = await attnGet('/local-peers');
        return { content: [{ type: 'text', text: JSON.stringify(data) }] };
      }
      case 'attn_history': {
        const data = await attnGet(`/history?with=${encodeURIComponent(args.with)}&limit=${args.limit || 20}`);
        return { content: [{ type: 'text', text: JSON.stringify(data) }] };
      }
      default:
        return { content: [{ type: 'text', text: `Unknown tool: ${name}` }], isError: true };
    }
  } catch (e) {
    return { content: [{ type: 'text', text: `Error: ${e.message}` }], isError: true };
  }
});

// Start
const transport = new StdioServerTransport();
server.connect(transport).then(() => {
  console.error('attn-mcp: listening on stdio');
}).catch(e => {
  console.error('attn-mcp: failed to start:', e.message);
  process.exit(1);
});
