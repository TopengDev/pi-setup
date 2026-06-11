# pi-setup — Chill Dawg's pi Agent Configuration

Complete pi coding agent rig. Skills, rules, extensions, and templates that turn a vanilla pi install into a fully-equipped development command center. Designed for Windows + Git Bash + WezTerm.

## Quick Start

```bash
# 1. Install pi globally
npm install -g @earendil-works/pi-coding-agent

# 2. Clone this config
mkdir -p ~/.pi/agent ~/.agents
git clone https://github.com/TopengDev/pi-setup.git ~/pi-setup-tmp

# 3. Install skills
cp -r ~/pi-setup-tmp/skills/* ~/.pi/agent/skills/
cp -r ~/pi-setup-tmp/skills/* ~/.agents/skills/ 2>/dev/null || true

# 4. Install extensions
cp -r ~/pi-setup-tmp/extensions/* ~/.pi/agent/extensions/

# 5. Install templates
cp -r ~/pi-setup-tmp/notes/* ~/.pi/agent/notes/

# 6. Install config
cp ~/pi-setup-tmp/AGENTS.md ~/.pi/agent/AGENTS.md

# 7. Set up secrets
cp .env.example ~/.pi/agent/secrets.env
# Edit ~/.pi/agent/secrets.env with your API keys

# 8. Clean up
rm -rf ~/pi-setup-tmp
```

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| **pi** | Coding agent CLI | `npm install -g @earendil-works/pi-coding-agent` |
| **Git Bash** | Shell (MSYS2/MinGW64) | Comes with [Git for Windows](https://git-scm.com/download/win) |
| **WezTerm** | Terminal multiplexer (worker tabs) | `winget install wez.wezterm` or [wezterm.org](https://wezterm.org) |
| **Node.js** | Runtime (≥18) | `winget install OpenJS.NodeJS.LTS` |
| **Git** | Version control | Comes with Git for Windows |

### Optional but Recommended

| Tool | Purpose |
|------|---------|
| **Docker Desktop** | Container builds on Windows |
| **Telegram Bot** | Remote control via [pi-remote](https://github.com/TopengDev/pi-remote) |
| **gitleaks** | Pre-push secret scan (`winget install gitleaks`) — see [Secret-Scan Hook](#secret-scan-hook-opt-in) |

## Environment

This config is built for:
- **OS:** Windows 11 Pro
- **Shell:** Git Bash (`bash.exe` from Git for Windows)
- **Terminal:** WezTerm (multiplexing, worker tabs)
- **Paths:** Forward slashes or properly escaped backslashes. Git Bash handles `/c/Users/...` paths.

### Shell Profile

Git Bash sources `/etc/profile` and `/etc/bash.bashrc` on startup. Create `~/.bashrc` to auto-load secrets:

```bash
# ~/.bashrc
export NODE_PATH="$(npm root -g)"
source ~/.pi/agent/secrets.env 2>/dev/null
```

## Secrets

All credentials live in `~/.pi/agent/secrets.env` (gitignored, never committed).

```bash
# Copy the template
cp .env.example ~/.pi/agent/secrets.env

# Edit with your keys
$EDITOR ~/.pi/agent/secrets.env
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
| `OPENAI_API_KEY` | Tertiary provider |
| `GEMINI_API_KEY` | Image generation (creative skill) |
| `VPS_HOST` / `VPS_USER` / `VPS_PASSWORD` | Remote VPS access |
| `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ZONE_ID` | DNS management |

## Secret-Scan Hook (opt-in)

This repo ships a `pre-push` hook at `config/git/hooks/` that runs [gitleaks](https://github.com/gitleaks/gitleaks) over the commits being pushed and **blocks the push** if a secret is detected. It uses a bundled `gitleaks.toml` that adds Anthropic `sk-ant-` key rules on top of gitleaks' defaults (the stock 8.21.x ruleset lacks them).

It is **opt-in** — nothing activates it automatically. To enable it for this repo:

```bash
# from the repo root
git config core.hooksPath config/git/hooks
```

Or enable it globally for every repo on the machine (point at wherever this config is installed):

```bash
git config --global core.hooksPath ~/.pi/agent/config/git/hooks
```

**Requirements & behavior:**
- Needs `gitleaks` on `PATH`. On Windows: `winget install gitleaks` (or `scoop install gitleaks` / `choco install gitleaks`). Git Bash inherits the Windows `PATH`, so the `.exe` is found automatically.
- **Fails open** — if `gitleaks` is not installed, the hook prints a warning and allows the push (a missing tool never bricks every push). Install gitleaks to get protection.
- Scans only the **new** commits per ref (fast — it does not re-scan all of history on every push).
- **Bypass** a false positive for one push with `git push --no-verify`, or add a `gitleaks:allow` comment / a `.gitleaksignore` entry.

## Directory Layout

After installation, your pi configuration lives at:

```
~/.pi/agent/
├── AGENTS.md              # Global rules (from this repo)
├── secrets.env            # Credentials (NOT in repo)
├── skills/                # Global skills
│   ├── commit/            # Conventional commits
│   ├── creative/          # Design asset generation
│   ├── frontend-design/   # Production-grade UI
│   ├── wezterm/           # Worker spawning
│   └── ...                # (21 skills total)
├── extensions/
│   └── attn/              # Encrypted agent-to-agent messaging
├── notes/
│   ├── initiatives/       # Multi-day project tracking
│   └── templates/         # STATE.md, initiative.md
├── repositories/          # Project codebases
└── tasks/                 # Task tracking artifacts
```

```
~/.agents/skills/          # Secondary skills directory
└── (mirrors ~/.pi/agent/skills/)
```

## Skills — Complete Reference

### Workflow Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| **commit** | `/commit`, "commit changes" | Conventional commit messages, structured workflow |
| **preflight** | "push", "verify builds" | Local CI/CD checks before pushing |
| **ship** | "ship", "deploy", "push" | Full pipeline: security review, test, version, commit, preflight, push |
| **project-init** | `/project-init`, "new project" | Scaffold a new project with everything needed to start |

### Task & Project Management

| Skill | Trigger | What it does |
|-------|---------|--------------|
| **tasks** | `/tasks`, "project status" | Task tracking system across all projects |
| **daily-brief** | "daily brief", "morning" | Morning summary of yesterday + today's priorities |
| **status-report** | "status report", "weekly update" | Weekly client status reports from actual project state |
| **handover** | `/handover`, "hand over project" | Comprehensive project handover documentation package |
| **remindme** | "remind me", "set reminder" | Future follow-up reminders with deadlines |

### Design & Frontend

| Skill | Trigger | What it does |
|-------|---------|--------------|
| **frontend-design** | "build UI", "create component" | Distinctive, production-grade frontend interfaces |
| **oneshot-webapp** | `/oneshot-webapp`, "pitch demo" | Pitch-grade demo webapps, fast |
| **creative** | `/creative`, "generate image" | AI image generation with multi-model routing, design theory |
| **ui-ux-pro-max** | "design system", "UI review" | 50+ styles, 161 palettes, 57 font pairings, UX guidelines |
| **tailwind-design-system** | "design system", "component library" | Tailwind CSS v4 design systems, tokens, component libraries |

### Quality & Memory

| Skill | Trigger | What it does |
|-------|---------|--------------|
| **qa** | `/qa`, "test thoroughly" | Adversarial QA across 10 dimensions, severity-graded report |
| **vercel-react-best-practices** | React/Next.js tasks | Performance optimization from Vercel Engineering |
| **remember** | "/remember", "save this" | Persistent memory management |
| **journal** | After every action | Chronological activity journal |
| **find-skills** | "how do I...", "find a skill" | Discover and install new skills |

### Terminal & Workers

| Skill | Trigger | What it does |
|-------|---------|--------------|
| **wezterm** | `/wezterm spawn`, worker delegation | Manage WezTerm tabs, panes, and worker sessions |

## Scripts

Maintenance + safety tooling under `scripts/` (bash + python3, Windows/Git-Bash friendly):

| Script | What it does |
|--------|--------------|
| **`skill-eval.sh`** | Structural validator for the skill library — asserts every `SKILL.md` has valid frontmatter, companion refs resolve, and any `evals/evals.json` is schema-valid. Read-only, CI-able. `--json` for machine output, `--strict` to fail on warnings. Exit 0 = green. See [`SKILL-EVALS.md`](scripts/SKILL-EVALS.md) for the eval schema. |
| **`scan-brief.sh`** | No-creds-in-brief warn-scanner — scans a worker brief for literal secret values and warns (pattern-class + line, never the value), fail-open. Strips `$VAR` / `secrets.env` so credential-by-reference never trips it. `--strict` to block. Backs the [No Credentials In A Brief](AGENTS.md) rule. |

```bash
# validate the whole skill library (run from repo root)
bash scripts/skill-eval.sh

# pre-flight a brief before handing it to a worker
bash scripts/scan-brief.sh notes/my-task/brief.md
```

## Extensions

### attn — Encrypted Agent-to-Agent Messaging

End-to-end encrypted messaging between pi agents via the attn relay network. Uses Ethereum keypairs for identity, WebSocket for real-time communication.

**Features:**
- `attn_send` — send encrypted messages to any agent
- `attn_reply` — reply to the most recent inbound message
- `attn_history` — fetch conversation history
- `attn_peers` — list known contacts
- `attn_local_peers` — list locally connected sessions (worker tabs)
- `attn_status` — check relay connection

**Setup:** The attn daemon auto-starts with pi. Identity keys are generated on first run and stored at `~/.attn/.env`. The daemon listens on `localhost:9742`.

**Remote Control:** Combine with [pi-remote](https://github.com/TopengDev/pi-remote) (Telegram → attn bridge) for mobile remote control of your pi session.

## Templates

### STATE.md — Worker Task Tracking

Workers use this template to track live progress. Main session monitors it.

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
- [ ] Criterion 2

## Child Tasks
- [ ] `task-slug-1` — description
- [ ] `task-slug-2` — description

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
```

## AGENTS.md — The Rule System

The heart of this setup. `AGENTS.md` defines how the agent behaves. Key sections:

### Global Rules
- **Bug Fixing** — root cause analysis, no surface-level patches
- **Research** — ultra-thorough, multi-source, cite everything
- **Read Before Writing** — understand full architecture before editing
- **Verify Your Work** — run it, trace it, test edges
- **Don't Hallucinate APIs** — verify every function/flag before use
- **Plan Before Executing** — prototype → plan → execute for complex changes
- **No Build Without Closure** — no implementation until all unknowns resolved
- **Security-First** — input validation, auth, secrets, exposure
- **Don't Assume — Ask** — ambiguous requirements get clarifying questions

### Task Hierarchy
- **Triage** — mandatory L1/L2/L3 classification before any task
- **3-Tier Task Hierarchy** — Initiative → Task → Steps, mandatory for delegation
- **Main Session = Discussion Only** — workers execute, main coordinates

### Deployment & VPS
- **NEVER code directly on VPS** — local → git → push → pull/deploy
- VPS is a deployment target, not a development environment

### Website Defaults
- **i18n + Multi-theme** mandatory for Aenoxa ecosystem websites
- **One-Shot Webapp** non-negotiables for pitch demos (light mode only, fast ship)

### Remote Control
- Telegram bridge forwards messages via attn
- Authorized addresses get full agent control
- Replies always route back to the originating channel

### Working Style
- Christopher thinks abstract, fast-paced, nonlinear
- Be direct, concise, don't over-explain known topics
- Proactive memory saving

### Customizing

Edit `~/.pi/agent/AGENTS.md` to adjust rules for your setup. Key sections to personalize:
- **Infrastructure Access** — your VPS, Cloudflare, API keys
- **Project Locations** — where your codebases live
- **Who I'm Working With** — your name, working style
- **What We're Building** — your products and services
- **Secrets** — path to your secrets file

## Windows-Specific Notes

### Path Handling
- Use forward slashes: `/c/Users/You/project`
- Git Bash auto-translates to Windows paths
- Node.js requires Windows-style paths for `require()` and `fs` operations — use `cygpath -w` to convert

### Process Management
- **NEVER** `taskkill //F //IM node.exe` — kills ALL node processes including pi
- Kill specific PIDs: `netstat -ano | findstr :9742` then `taskkill //PID <pid> //F`
- Worker tabs auto-close on exit (WezTerm `exit_behavior = 'Close'`)

### Shell Differences
- `~/.bashrc` may not exist by default — create it if needed
- `chmod` has no effect on NTFS — ignore `chmod` instructions
- `sshpass` not included — use Node.js `ssh2` package for password-based SSH

## Remote Control

Optionally control pi from Telegram on your phone. Two paths:

### Standalone (No VPS)

Run the bot directly on your machine:

```bash
cd remote-control
npm install
cp .env.example .env
# Edit .env with your Telegram credentials
node telegram-bot.js
```

See [remote-control/README.md](remote-control/README.md) for detailed setup.

### Docker on VPS

For a hosted, always-on bridge:

```bash
git clone https://github.com/TopengDev/pi-remote.git
cd pi-remote
cp .env.example .env
# Edit .env with your Telegram credentials
docker compose up -d
```

See [pi-remote](https://github.com/TopengDev/pi-remote) for full documentation.

## Project Conventions

### Commits
- Conventional commits: `type(scope): description`
- Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `style`, `perf`, `ci`, `build`
- Subject ≤72 characters, no Co-Authored-By

### Codebases
- Live in `~/.pi/agent/repositories/<project-name>/`
- Each has its own `.pi/AGENTS.md` for project-specific rules
- All use git from day one

## Notes
- English is the working language. Indonesian names/terms appear naturally where they exist in projects
- The agent may reference `.claude/` paths from older setups — replace with `~/.pi/agent/` equivalents
- Worker sessions auto-register on attn via `ATTN_SESSION` env var
