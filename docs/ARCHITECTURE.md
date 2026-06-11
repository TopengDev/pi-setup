# Architecture — pi-setup

The single source-of-truth for how this repo turns a vanilla **pi** (or **OpenCode**)
coding-agent install into a fully-equipped command center. Read this before changing
anything: a future reader (or a fresh agent) should be able to reconstruct the whole
layout from this one document.

> **Honesty contract.** This doc is the *map*. `scripts/setup-doctor.sh` is the
> *verifier* — it asserts that what the repo ships is actually present + current in the
> live agent directories. If this doc and the doctor ever disagree, the doctor wins.

---

## 1. Big picture

This is a **COPY-model** config repo, not a symlink farm. `install.sh` copies the
repo's files into the live agent directories under `$HOME`. There is no "edit the
live file = edit the repo" magic — you edit the repo, then **re-run `install.sh`** to
push changes out (and `setup-doctor.sh` to confirm they landed).

Why copy instead of symlink? The target is **Windows + Git Bash + WezTerm**. Symlinks
on Windows need Developer Mode and behave inconsistently under Git Bash's MSYS layer.
A plain copy is portable, predictable, and needs no special privileges.

There is **no Linux, no systemd, no VPS, no Claude-Code hook engine** in this design.
Everything here runs on a Windows workstation with Git Bash as the shell.

```
pi-setup/                  (this repo — the source of truth)
├── AGENTS.md              ← global rule system (both branches)
├── CLAUDE.md              ← OpenCode rule file (opencode branch only)
├── .opencode.json         ← OpenCode config template (opencode branch only)
├── .env.example           ← secrets template (seeds secrets.env)
├── skills/                ← skill library (one dir per skill, each with SKILL.md)
├── extensions/            ← pi extensions (attn messaging) — master branch
├── commands/              ← OpenCode slash-commands — opencode branch
├── mcp/                   ← attn MCP server (Node) — opencode branch
├── notes/templates/       ← STATE.md + initiative.md worker templates
├── config/git/hooks/      ← opt-in gitleaks pre-push secret scan
├── scripts/               ← maintenance + safety tooling (install-adjacent)
├── remote-control/        ← standalone Telegram → agent bridge
├── docs/                  ← this file + ONBOARDING.md
├── install.sh             ← the COPY installer (branch/profile aware)
└── .github/workflows/     ← CI (structural gate + windows install smoke)
```

---

## 2. Two branches, two profiles

The repo ships on two branches that differ ONLY in runtime plumbing — the **rule
content is identical** (the OpenCode `CLAUDE.md` is the `AGENTS.md` rules, path-
substituted; the opencode branch keeps `AGENTS.md` too).

| | **master** (`pi` profile) | **opencode** (`opencode` profile) |
|---|---|---|
| Agent CLI | `@earendil-works/pi-coding-agent` | `@earendil-works/opencode` |
| Config home | `~/.pi/agent/` | `~/.opencode/` |
| Secondary skills | `~/.agents/skills/` | `~/.agents/skills/` + `~/.agents/notes/` |
| Rules file | `AGENTS.md` | `CLAUDE.md` + `AGENTS.md` |
| Agent runtime | `extensions/attn/` (pi TS extension) | `mcp/attn-mcp-server.js` (stdio MCP) + `.opencode.json` |
| Slash commands | — (skills only) | `commands/*.md` |
| Secrets path | `~/.pi/agent/secrets.env` | `~/.opencode/secrets.env` |

`install.sh` and `setup-doctor.sh` are **profile-aware**: they auto-detect the
profile from the checked-out branch (`master`/`main` → `pi`, `opencode` → `opencode`),
falling back to the presence of `.opencode.json`. Override with `--profile pi|opencode`.

---

## 3. Install layout (what lands where)

### pi profile (master)

| Repo source | Live destination |
|---|---|
| `skills/*` | `~/.pi/agent/skills/` **and** `~/.agents/skills/` |
| `extensions/*` | `~/.pi/agent/extensions/` |
| `notes/*` | `~/.pi/agent/notes/` |
| `AGENTS.md` | `~/.pi/agent/AGENTS.md` |
| `.env.example` | `~/.pi/agent/secrets.env` *(only if absent — never clobbered)* |

### opencode profile (opencode)

| Repo source | Live destination |
|---|---|
| `skills/*` | `~/.agents/skills/` **and** `~/.opencode/skills/` |
| `notes/*` | `~/.agents/notes/` **and** `~/.opencode/notes/` |
| `CLAUDE.md` | `~/.opencode/CLAUDE.md` |
| `AGENTS.md` | `~/.opencode/AGENTS.md` |
| `.opencode.json` | `~/.opencode/opencode.json` |
| `commands/*` | `~/.opencode/commands/` |
| `mcp/*` | `~/.opencode/mcp/` *(+ `npm install` for the MCP server's deps)* |
| `.env.example` | `~/.opencode/secrets.env` *(only if absent — never clobbered)* |

---

## 4. install.sh — the copy engine

`install.sh` is idempotent, non-destructive, and Windows/Git-Bash safe.

- **Copy, never link.** Every file is `cp`'d to its destination.
- **Idempotent.** A file that already matches the repo (byte-identical, via `cmp`) is
  skipped — re-running produces no churn (CI asserts 0 copies on a 2nd run).
- **Backup-on-overwrite.** If a destination file exists and *differs*, it is moved to
  `<file>.pre-install` before being replaced (one backup; never re-stacked).
- **secrets.env is sacred.** `secrets.env` is seeded from `.env.example` only when it
  does **not** exist. An existing (populated) secrets file is **never** overwritten.
- **Additive.** Files present at the destination but absent from the repo are left
  alone — the installer never deletes.

Flags: `--profile pi|opencode`, `--dry-run` (prints, writes nothing), `--force`
(re-copy even identical files), `--ci` / `PI_SETUP_CI=1` (non-interactive; skips the
opencode `npm install`).

---

## 5. setup-doctor.sh — the verifier

`scripts/setup-doctor.sh` is **read-only**. It detects the profile the same way
`install.sh` does, then asserts every declared destination exists and is byte-identical
to the repo source (`PASS` / `DRIFT` per area). Extra files at the destination are not
drift (matching install.sh's additive model). Exit `0` = clean, `1` = drift, `2` =
self-error. **No systemd / daemon / VPS checks** — there are none on this platform.

Run it anytime: `bash scripts/setup-doctor.sh`. After any `install.sh` it must report
`PASS` (CI gates on exactly this on the Windows runner).

---

## 6. CI

Two workflows in `.github/workflows/`, both running on every push/PR to both branches:

1. **`structural.yml`** (ubuntu-latest, fast) — `skill-eval.sh` over the skill library,
   `bash -n` on every shell script + the pre-push hook, and a JSON-validity check on
   every `*.json`. The cheap gate.
2. **`install-windows.yml`** (**windows-latest**, Git Bash) — the validation that
   cannot be done on Linux. Runs `install.sh --ci` into the runner's `HOME`, asserts
   the expected files landed at the profile's paths, proves a 2nd run is idempotent,
   proves `secrets.env` survives a re-run, proves `--dry-run` writes nothing, and runs
   `setup-doctor.sh` (must be `PASS`). Branch-aware: pi layout on master, opencode
   layout on the opencode branch. **A green run here = the install is Windows-validated.**

---

## 7. Scripts & safety tooling (`scripts/`)

| Script | Role |
|---|---|
| `install`-adjacent `setup-doctor.sh` | Read-only drift audit (see §5). |
| `skill-eval.sh` | Structural validator for the skill library (frontmatter, companion refs, evals schema). CI-able. |
| `scan-brief.sh` | No-creds-in-brief warn-scanner — flags literal secrets in a worker brief by pattern-class + line (never the value), fail-open. Backs the **No Credentials In A Brief** rule in `AGENTS.md`. |

The opt-in **gitleaks pre-push hook** (`config/git/hooks/pre-push` + `gitleaks.toml`)
scans new commits for secrets and blocks the push on a hit (fail-open if gitleaks is
absent). Enable per-repo: `git config core.hooksPath config/git/hooks`.

---

## 8. What this repo deliberately is NOT

- **Not a dotfiles symlink farm** — copy model, on purpose (Windows).
- **No systemd timers / autonomous overnight loop** — Windows has no `systemctl --user`.
  Periodic jobs (if any) are run manually or via Task Scheduler, out of band.
- **No VPS development** — codebases live locally; the VPS (if used) is a deploy target.
- **No Claude-Code hook engine** — rules live in always-loaded `AGENTS.md`/`CLAUDE.md`,
  not in a settings.json hook map.
