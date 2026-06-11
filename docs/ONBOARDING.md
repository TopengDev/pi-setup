# Onboarding

A top-to-bottom walkthrough for setting up pi-setup on a fresh **Windows** machine.
For the architecture (what lands where and why), see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Who is this for?

- **Future-you** on a new laptop or after a reformat.
- Someone mirroring this environment to work alongside.

If a machine already has a `~/.pi/agent/` (or `~/.opencode/`) directory, `install.sh`
will back up anything it replaces to `<file>.pre-install` — but read §5 first so you
know what it touches.

## Mental model

This is a **copy**, not a symlink farm. After install there are two things:

1. **The repo** — wherever you cloned it. The source of truth.
2. **Copies under `$HOME`** — `~/.pi/agent/` (or `~/.opencode/`) + `~/.agents/`. These
   are *copies*; editing them does **not** edit the repo. To change config: edit the
   repo, re-run `install.sh`, verify with `setup-doctor.sh`.

`secrets.env` is its own category: it lives next to the agent config, is gitignored,
holds real credentials, and is **never** overwritten by the installer once it exists.

---

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| **pi** *(or OpenCode)* | The coding-agent CLI | `npm install -g @earendil-works/pi-coding-agent` (pi) / `@earendil-works/opencode` (opencode) |
| **Git for Windows** | Provides **Git Bash** (the shell everything runs in) + `git` | <https://git-scm.com/download/win> |
| **Node.js ≥18** | Runtime for pi/OpenCode + the attn MCP server | `winget install OpenJS.NodeJS.LTS` |
| **Python 3** | Used by `skill-eval.sh` / `setup-doctor` for JSON parsing | `winget install Python.Python.3` (or bundled with Git for Windows' toolchain) |

Optional:

| Tool | Purpose |
|---|---|
| **WezTerm** | Terminal multiplexer for worker tabs (`winget install wez.wezterm`) |
| **gitleaks** | Pre-push secret scan (`winget install gitleaks`) — opt-in, see §6 |
| **Telegram bot** | Mobile remote control via `remote-control/` or pi-remote |

> Run **all** of the steps below inside **Git Bash**, not PowerShell/CMD. `$HOME`
> resolves to `/c/Users/<you>` and the install paths assume that.

---

## Step-by-step

### 1. Sanity check

```bash
bash --version     # Git Bash
node --version     # >= 18
git --version
which pi || which opencode
```

### 2. Clone + pick your branch

```bash
git clone https://github.com/TopengDev/pi-setup.git ~/pi-setup
cd ~/pi-setup
# pi (default):     stay on master
# OpenCode variant: git checkout opencode
```

The branch decides the profile: `master` → `pi`, `opencode` → `opencode`.

### 3. Dry-run first (see what will happen)

```bash
./install.sh --dry-run
```

This prints every copy it *would* make — and writes nothing. Confirm the
source → destination mapping looks right for your profile before the real run.

### 4. Install

```bash
./install.sh
```

The installer copies skills, rules, templates, and (on opencode) commands + the MCP
server into the live agent directories, then seeds `secrets.env` from `.env.example`.
Force a profile if auto-detection is wrong: `./install.sh --profile pi`.

### 5. Set up secrets

The installer created an empty `secrets.env` from the template. Fill it in:

```bash
# pi:        ~/.pi/agent/secrets.env
# opencode:  ~/.opencode/secrets.env
$EDITOR ~/.pi/agent/secrets.env
```

Then source it on shell start by adding to `~/.bashrc`:

```bash
export NODE_PATH="$(npm root -g)"
source ~/.pi/agent/secrets.env 2>/dev/null   # (or ~/.opencode/secrets.env)
```

Required keys: `DEEPSEEK_API_KEY` (or `ANTHROPIC_API_KEY`) + `GH_TOKEN`. The rest are
optional (see `.env.example` for the full list). **Never commit `secrets.env`** — it
is gitignored for exactly this reason.

On **opencode**, also fill the provider keys in `~/.opencode/opencode.json`.

### 6. (Optional) Enable the secret-scan hook

```bash
# from the repo root — blocks a push if gitleaks finds a secret in the new commits
git config core.hooksPath config/git/hooks
```

Needs `gitleaks` on PATH (`winget install gitleaks`). Fails open (warns + allows) if
gitleaks is absent, so a missing tool never bricks your pushes.

### 7. Verify

```bash
bash scripts/setup-doctor.sh
```

Expect `VERDICT: PASS`. Any `DRIFT` line tells you exactly which file is missing or
stale — re-run `install.sh` to reconcile, then re-run the doctor.

### 8. Launch

```bash
pi          # or: opencode
```

---

## Updating later

```bash
cd ~/pi-setup
git pull
./install.sh          # re-copies anything that changed (idempotent — no churn otherwise)
bash scripts/setup-doctor.sh
```

If you hand-edited a live file, `install.sh` backs it up to `<file>.pre-install` before
restoring the repo version. To keep a local change, make it in the repo and commit it.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `setup-doctor` reports `STALE` | You edited a live file; re-run `install.sh` (your edit is saved as `<file>.pre-install`). |
| Wrong profile detected | Pass `--profile pi` or `--profile opencode` explicitly. |
| `npm install` skipped (opencode) | You ran with `--ci`/`--dry-run`, or `npm` isn't on PATH. Run `(cd ~/.opencode/mcp && npm install)`. |
| Secrets not picked up | Confirm `~/.bashrc` sources `secrets.env`, then open a fresh Git Bash shell. |
| Symlink errors | You shouldn't see any — this installer copies, never links. If you do, you're on an old install.sh; `git pull`. |
