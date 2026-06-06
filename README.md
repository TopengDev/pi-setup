# opencode-setup — Chill Dawg's OpenCode Configuration

Complete OpenCode agent configuration. Rules, commands, MCP servers, and templates that turn a vanilla OpenCode install into a fully-equipped development command center. Designed for Windows + Git Bash.

## Quick Start

```bash
# 1. Install OpenCode
npm install -g @earendil-works/opencode

# 2. Clone this config
git clone https://github.com/TopengDev/pi-setup.git ~/opencode-setup-tmp
cd ~/opencode-setup-tmp
git checkout opencode

# 3. Install MCP dependencies
cd mcp && npm install && cd ..

# 4. Set up OpenCode config
mkdir -p ~/.opencode
cp .opencode.json ~/.opencode/opencode.json
cp CLAUDE.md ~/.opencode/CLAUDE.md

# 5. Set up commands
mkdir -p ~/.opencode/commands
cp commands/*.md ~/.opencode/commands/

# 6. Set up templates
mkdir -p ~/.opencode/notes/templates
cp notes/templates/* ~/.opencode/notes/templates/

# 7. Set up secrets
cp .env.example ~/.opencode/secrets.env
# Edit ~/.opencode/secrets.env with your API keys

# 8. Clean up
rm -rf ~/opencode-setup-tmp
```

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **OpenCode** | Coding agent CLI | `npm install -g @earendil-works/opencode` |
| **Git Bash** | Shell (MSYS2/MinGW64) | Comes with [Git for Windows](https://git-scm.com/download/win) |
| **Node.js** | Runtime (≥18) | `winget install OpenJS.NodeJS.LTS` |
| **Git** | Version control | Comes with Git for Windows |

### Optional but Recommended

| Tool | Purpose |
|------|---------|
| **attn daemon** | Encrypted agent-to-agent messaging (MCP) |
| **Telegram Bot** | Remote control via [pi-remote](https://github.com/TopengDev/pi-remote) |

## Environment

This config is built for:
- **OS:** Windows 11 Pro
- **Shell:** Git Bash (`bash.exe` from Git for Windows)
- **Paths:** Forward slashes or properly escaped backslashes. Git Bash handles `/c/Users/...` paths.

### Shell Profile

Git Bash sources `/etc/profile` and `/etc/bash.bashrc` on startup. Create `~/.bashrc` to auto-load secrets:

```bash
# ~/.bashrc
export NODE_PATH="$(npm root -g)"
source ~/.opencode/secrets.env 2>/dev/null
```

## Secrets

All credentials live in `~/.opencode/secrets.env` (gitignored, never committed).

```bash
# Copy the template
cp .env.example ~/.opencode/secrets.env

# Edit with your keys
$EDITOR ~/.opencode/secrets.env
```

### Required Keys

| Variable | Purpose | Get it from |
|----------|---------|-------------|
| `DEEPSEEK_API_KEY` | Primary AI provider | [DeepSeek Platform](https://platform.deepseek.com) |
| `ANTHROPIC_API_KEY` | Fallback provider | [Anthropic Console](https://console.anthropic.com) |
| `GH_TOKEN` | GitHub API (create repos, push) | [GitHub Settings → Tokens](https://github.com/settings/tokens) (classic, `repo` scope) |

### Optional Keys

| Variable | Purpose |
|----------|---------|
| `OPENAI_API_KEY` | Tertiary provider + image generation |
| `GEMINI_API_KEY` | Image generation (creative command) |
| `VPS_HOST` / `VPS_USER` / `VPS_PASSWORD` | Remote VPS access |
| `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ZONE_ID` | DNS management |

## Directory Layout

After installation, your OpenCode configuration lives at:

```
~/.opencode/
├── opencode.json          # Providers, agents, MCP servers
├── CLAUDE.md              # Global rules (from this repo)
├── secrets.env            # Credentials (NOT in repo)
├── commands/              # Custom commands
│   ├── commit.md          # Conventional commits
│   ├── preflight.md       # Local CI/CD checks
│   ├── tasks.md           # Task tracking
│   ├── creative.md        # Design asset generation
│   ├── qa.md              # Adversarial QA
│   └── frontend-design.md # Production-grade UI
├── notes/
│   ├── initiatives/       # Multi-day project tracking
│   └── templates/         # STATE.md, initiative.md
└── repositories/          # Project codebases
```

## Commands

OpenCode custom commands. Invoke with `/command-name`.

### Workflow Commands

| Command | Trigger | What it does |
|---------|---------|--------------|
| **commit** | `/commit`, "commit changes" | Conventional commits with proper staging and message format |
| **preflight** | "push", "verify builds" | Local CI/CD checks — lint, types, tests, build |
| **tasks** | `/tasks`, "project status" | Task tracking with NOW/NEXT/LATER/WAITING columns |

### Design & Quality Commands

| Command | Trigger | What it does |
|---------|---------|--------------|
| **frontend-design** | "build UI", "create component" | Production-grade UI — 12 vibe archetypes, typography systems, scrollytelling |
| **creative** | `/creative`, "generate image" | AI image generation — multi-model routing, 20 hard bans, self-critique scoring |
| **qa** | `/qa`, "test thoroughly" | Adversarial QA — quick (3 dims) or full (10 dims), P0-P4 severity report |

## MCP — attn Messaging

End-to-end encrypted messaging between OpenCode agents via the attn relay network. Uses Ethereum keypairs for identity, HTTP for daemon communication.

**6 MCP Tools:**
- `attn_send` — send encrypted messages to any agent
- `attn_reply` — reply to the most recent inbound message
- `attn_history` — fetch conversation history
- `attn_peers` — list known contacts
- `attn_local_peers` — list locally connected sessions
- `attn_status` — check relay connection

**Setup:**
```bash
cd mcp && npm install
```

The MCP server (`mcp/attn-mcp-server.js`) communicates with the attn daemon on `localhost:9742`. Configured automatically via `.opencode.json`.

**Remote Control:** Combine with [pi-remote](https://github.com/TopengDev/pi-remote) (Telegram → attn bridge) for mobile remote control of your OpenCode session.

## Templates

### STATE.md — Task Tracking

Track live task progress.

**Statuses:** `STARTING` → `IN_PROGRESS` → `COMPLETE` | `BLOCKED`

```markdown
# STATE — {{TASK_NAME}}
**Status:** {{STARTING | IN_PROGRESS | COMPLETE | BLOCKED}}
**Worker:** {{worker-name}}
**Parent initiative:** [{{initiative-slug}}](../initiatives/{{initiative-slug}}.md)

## Roadmap
- [ ] Step 1
- [ ] Step 2

## Completed
- [x] Step done — timestamp

## Current Progress
(LIVE updates)

## Blockers
(If BLOCKED: what's blocking, what's needed)
```

### initiative.md — Multi-Day Project Tracking

```markdown
# Initiative: {{name}}
**Status:** {{active | completed | paused}}
**Started:** {{YYYY-MM-DD}}

## Outcome
(What does success look like?)

## Success Criteria
- [ ] Criterion 1

## Child Tasks
| Task | Slug | Status |
|------|------|--------|

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
```

## CLAUDE.md — The Rule System

The heart of this setup. `CLAUDE.md` defines how the agent behaves. Key sections:

### Global Rules
- **Cognitive Workflow** — ANALYZE → PLAN → EXECUTE → VERIFY pipeline
- **Bug Fixing** — root cause analysis, no surface-level patches
- **Research** — ultra-thorough, multi-source (min 3, at least 1 source code), cite everything
- **Read Before Writing** — understand full architecture before editing
- **Verify Your Work** — run it, trace it, test edges
- **Don't Hallucinate APIs** — verify every function/flag before use
- **Plan Before Executing** — prototype → plan → execute for complex changes
- **No Build Without Closure** — no implementation until all unknowns resolved
- **Security-First** — input validation, auth, secrets, exposure
- **Don't Assume — Ask** — ambiguous requirements get clarifying questions

### Task Hierarchy
- **Triage** — mandatory L1/L2/L3 classification before any task
- **3-Tier Tracking** — Initiative → Task → Steps

### Deployment & VPS
- **NEVER code directly on VPS** — local → git → push → pull/deploy

### Website Defaults
- **i18n + Multi-theme** mandatory for Aenoxa ecosystem websites
- **One-Shot Webapp** non-negotiables for pitch demos

### Remote Control
- Telegram bridge forwards messages via attn MCP
- Authorized addresses get full agent control

### Working Style
- Christopher thinks abstract, fast-paced, nonlinear
- Be direct, concise, don't over-explain known topics

## Windows-Specific Notes

### Path Handling
- Use forward slashes: `/c/Users/You/project`
- Git Bash auto-translates to Windows paths

### Shell Differences
- `~/.bashrc` may not exist by default — create it if needed
- `chmod` has no effect on NTFS — ignore `chmod` instructions

## Remote Control

Optionally control OpenCode from Telegram on your phone.

### Docker on VPS (Recommended)

For a hosted, always-on bridge:

```bash
git clone https://github.com/TopengDev/pi-remote.git
cd pi-remote
cp .env.example .env
# Edit .env with your Telegram credentials
docker compose up -d
```

Messages flow through: Telegram → pi-remote (VPS) → attn relay → attn MCP → OpenCode.

### Standalone

Run the bot directly on your machine:

```bash
cd remote-control
npm install
cp .env.example .env
# Edit .env with your Telegram credentials
node telegram-bot.js
```

See [remote-control/README.md](remote-control/README.md) for detailed setup.

## Project Conventions

### Commits
- Conventional commits: `type(scope): description`
- Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `style`, `perf`, `ci`, `build`
- Subject ≤72 characters, no Co-Authored-By
- Use `/commit` command

### Codebases
- Live in `~/.opencode/repositories/<project-name>/`
- Each has its own `CLAUDE.md` for project-specific rules
- All use git from day one

## Differences from pi-setup (master branch)

| Aspect | pi-setup (master) | opencode-setup (this branch) |
|--------|-------------------|------------------------------|
| Config file | `AGENTS.md` | `CLAUDE.md` + `.opencode.json` |
| Messaging | pi extension (TypeScript, WebSocket) | MCP server (stdio, HTTP) |
| Skills | 20+ skill directories | 6 custom commands |
| Worker spawning | WezTerm multiplexing | Terminal-native |
| Task tracking | `~/.pi/agent/tasks/` | `~/.opencode/tasks/` |
| Secrets location | `~/.pi/agent/secrets.env` | `~/.opencode/secrets.env` |
| Config path | `~/.pi/agent/` | `~/.opencode/` |

## Notes
- English is the working language. Indonesian names/terms appear naturally where they exist in projects
- The `skills/` directory contains full skill documentation — commands are simpler entry points
- The `opencode` branch removes pi-specific files (WezTerm skill, attn extension) and replaces with MCP
