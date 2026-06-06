---
name: wezterm
description: Manage WezTerm tabs, panes, and worker sessions. Use for spawning worker pi sessions, sending briefs, monitoring output, and navigating the terminal workspace. This is the Windows equivalent of the tmux skill.
---

# WezTerm Terminal Control

Manage WezTerm multiplexing for worker delegation — the Windows replacement for tmux-based worker spawning.

## Environment

- **WezTerm default shell:** `powershell.exe -NoLogo` (configured in `~/.wezterm.lua`)
- **pi runtime:** Git Bash at `C:/Program Files/Git/bin/bash.exe` (MSYS2/MINGW64) — must use full path to avoid WSL bash
- **pi command:** `pi` on PATH (npm global), works inside Git Bash
- **Leader key:** `Ctrl+A` (tmux-compatible)
- **Key bindings:** Leader+c new tab, Leader+& close tab, Leader+x close pane, Leader+z zoom, Leader+1-9 switch tab
- **Tab auto-close:** `exit_behavior = 'Close'` set — tabs close when process exits

## Core Concept

One **main pi session** (this one) handles discussion, triage, and delegation. Execution happens in separate WezTerm tabs (workers) within the same window. This skill provides the primitives to spawn, brief, monitor, and kill workers.

```
Main Session (tab 0)         Worker Tab 1           Worker Tab 2
┌─────────────────┐          ┌──────────────┐        ┌──────────────┐
│ Discuss & Delegate│          │ pi --name     │        │ pi --name     │
│ (never executes   │─spawn──▶│ "worker-xxx"  │        │ "worker-yyy"  │
│  implementation)  │          │               │        │               │
│                   │─brief──▶│ reads AGENTS.md│       │               │
│                   │          │ executes task  │        │               │
│                   │◀─attn───│ [COMPLETE/     │        │               │
│                   │          │  PROGRESS/      │        │               │
│                   │          │  BLOCKED]        │        │               │
└─────────────────┘          └──────────────┘        └──────────────┘
```

Navigation: `Leader+1-9` switches tabs, `Leader+n` next tab, `Leader+p` prev tab.
Tabs auto-close when worker exits: `exit_behavior = 'Close'` in wezterm.lua.

## Commands

### `/wezterm list` — Show all windows and panes

```bash
wezterm cli list
```

Parse the output to show a readable table of active windows, tabs, and panes.

### `/wezterm spawn <name> [cwd]` — Create a worker tab

Spawn a new WezTerm tab with a named pi session running inside bash, then return the pane-id.

```bash
WORKER_NAME="<name>"
WORKER_CWD="${2:-$(pwd)}"

# MUST use Git Bash explicitly — plain "bash" resolves to WSL bash
# which uses /mnt/c paths and can't find node/pi installed on Windows
# Spawns in a new TAB in the current window (no --new-window)
wezterm cli spawn --cwd "$WORKER_CWD" \
  -- "/c/Program Files/Git/bin/bash.exe" -c "ATTN_SESSION='$WORKER_NAME' pi --name '$WORKER_NAME'"
```

After spawning:
1. Wait 15 seconds for pi to boot and load AGENTS.md + skills
2. Run `wezterm cli list` again to confirm the new pane
3. Report: "Worker '$WORKER_NAME' spawned at pane-id X"

**CRITICAL RULES:**
- Workers spawn inside bash, not powershell — pi needs bash
- Workers auto-inherit the CWD's AGENTS.md plus global `~/.pi/agent/AGENTS.md`
- Default CWD should be the project repository, not `~/.pi/agent/`

### `/wezterm brief <pane-id> <brief-file>` — Send a task brief

Paste a brief file into a worker pane. Pipes the brief via stdin to avoid clipboard issues.

```bash
PANE_ID="<pane-id>"
BRIEF_FILE="<brief-file>"

# Build the brief with worker role-override preamble (3-tier task hierarchy)
{
  echo "## ⚠️ CRITICAL: ATTN REPORTING — YOUR LAST ACTION"
  echo ""
  echo "When your task is COMPLETE or BLOCKED, your FINAL action is:"
  echo "  attn_send to='main' with a brief completion report"
  echo "Example: 'DONE: edited shell.sh, added safe-kill rule. verified with grep.'"
  echo "Do NOT just update STATE.md and stop. Main relies on attn for push notifications."
  echo ""
  echo "---"
  echo ""
  echo "# WORKER ROLE OVERRIDE (read FIRST, applies to everything below)"
  echo ""
  echo "You are a SPAWNED WORKER named '\$WORKER_NAME' running in a WezTerm tab. You are NOT the main coordination session — main is SEPARATE and spawned you via wezterm."
  echo ""
  echo "The AGENTS.md rule 'Main Session is DISCUSSION ONLY / never run dev commands here' does NOT apply to you. You ARE the executor. Do NOT delegate further. Do NOT spawn sub-workers."
  echo ""
  echo "---"
  echo ""
  echo "## MANDATORY: attn reporting (push-based — replaces STATE.md polling)"
  echo ""
  echo "Instead of main polling STATE.md, you PUSH status updates to main via attn_send:"
  echo ""
  echo "1. **MILESTONE — SHOULD**: Send a progress update at every major milestone:"
  echo "   attn_send to: 'main'"
  echo "   message: \"[PROGRESS] <milestone> done. Next: <next step>. STATE.md updated.\""
  echo ""
  echo "2. **COMPLETE — MUST**: When the task is fully done and verified:"
  echo "   attn_send to: 'main'"
  echo "   message: \"[COMPLETE] Task done. Summary: <what was built/fixed, verification evidence, any caveats>. report.md written + STATE.md set to COMPLETE.\""
  echo ""
  echo "3. **BLOCKED — MUST**: If you hit a blocker you cannot resolve:"
  echo "   attn_send to: 'main'"
  echo "   message: \"[BLOCKED] <describe blocker, what you tried, what you need>. STATE.md set to BLOCKED.\""
  echo ""
  echo "Main receives these as push notifications — no polling lag. DO NOT wait for main to discover you're done. PUSH it."

  echo "---"
  echo ""
  cat "$BRIEF_FILE"
} | wezterm cli send-text --pane-id "$PANE_ID" --no-paste

# Send Enter (\r = carriage return) to submit — \n adds newlines in pi's editor
wezterm cli send-text --pane-id "$PANE_ID" --no-paste $'\r'

echo "Brief sent to pane $PANE_ID"
```

### `/wezterm peek <pane-id> [lines]` — Capture pane content

Read what's displayed in a worker pane to monitor progress.

```bash
wezterm cli get-text --pane-id <pane-id> | tail -<lines>
```

### `/wezterm send <pane-id> <text>` — Send text to a pane

Send a message or command to a worker pane.

```bash
wezterm cli send-text --pane-id <pane-id> --no-paste "<text>"
```

### `/wezterm kill <pane-id>` — Kill a worker

Send Ctrl+D (EOF) to bash. Pi exits → bash exits → WezTerm tab auto-closes (`exit_behavior = 'Close'`).

```bash
# Ctrl+D sends EOF — closes bash, tab auto-closes immediately
wezterm cli send-text --pane-id <pane-id> --no-paste $'\x04'
sleep 2
# Verify tab closed
wezterm cli list 2>&1 | grep -q "$PANE_ID" && echo "Still open — use Leader+&" || echo "Tab killed"
```

Alternatively: `Leader+&` (close tab), click the X on the tab.

### `/wezterm split` — Split current pane

Create a horizontal or vertical split in the current window.

```bash
# Horizontal split (left-right)
wezterm cli split-pane --horizontal --cwd "$(pwd)"

# Vertical split (top-bottom) 
wezterm cli split-pane --bottom --cwd "$(pwd)"
```

## Worker Lifecycle Protocol

### Pre-Spawn (L2/L3 — full 3-tier discipline)

Main session MUST complete ALL of these atomically BEFORE spawning:

1. **Initiative file** at `~/.pi/agent/notes/initiatives/<slug>.md` — create or update (add this task to "Child tasks")
2. **Task notes dir** at `.pi/tasks/<task-slug>-<YYYY-MM-DD>/`
3. **triage.json** in that dir (`level`, `scope`, `created`; L3 needs `signoff: true`)
4. **brief.md** in that dir — the task description
5. **STATE.md** from template `~/.pi/agent/notes/templates/STATE.md` — fill: NAME, worker name, parent initiative slug, starting point, initial roadmap
6. THEN: spawn + brief

### Pre-Spawn (L1 fast-path)

1. Task notes dir at `.pi/tasks/<slug>-<date>/`
2. **triage.json** with `"level":"L1"`
3. One-line **brief.md** + stub **STATE.md** (name/status only — no initiative, no parent linkage)
4. Spawn + brief

### Spawn → Complete lifecycle

1. **SPAWN**: `/wezterm spawn <name> <project-dir>`
2. **WAIT**: 15 seconds for pi to boot + load AGENTS.md + skills
3. **BRIEF**: `/wezterm brief <pane-id> .pi/tasks/<slug>-<date>/brief.md`
4. **MONITOR (push-based)**: Workers push status via attn_send to 'main' — no polling. Main watches attn for [PROGRESS], [COMPLETE], and [BLOCKED] messages. If a worker goes silent >20 min with no attn update, main investigates via `/wezterm peek <pane-id>` or checking STATE.md directly.
4a. **VERIFY ATTN REGISTRATION**: After spawning the worker, run `curl localhost:9742/local-peers` from main and confirm the worker's `ATTN_SESSION` name appears in the response. If the worker name is not listed, the worker didn't load the attn extension — investigate and re-spawn if necessary. A worker without attn cannot push status updates to main.
5. **REPORT VIA ATTN**: Worker MUST call attn_send to main with completion report on finish. On blocker: attn_send blocker details to main. Main MUST kill worker via Ctrl+D immediately after receiving attn DONE report.
6. **COMPLETE**: Worker sends `attn_send to: 'main'` with [COMPLETE] report, sets STATE.md to COMPLETE + writes report.md. Main reviews, then kills worker with `/wezterm kill <pane-id>`.
7. **BLOCKED**: Worker sends `attn_send to: 'main'` with [BLOCKED] details, sets STATE.md to BLOCKED. Main surfaces to Christopher.

### Monitoring Protocol (push-based via attn)

Workers push status updates to main via `attn_send to: 'main'`. Main does NOT poll STATE.md — it reacts to incoming attn messages.

| Event | Trigger | Worker action | Main action |
|-------|---------|---------------|-------------|
| Milestone reached | Every major sub-goal done | `attn_send to: 'main'` [PROGRESS] message (SHOULD) | Acknowledge, no action needed unless direction looks wrong |
| Task complete | All work done + verified | `attn_send to: 'main'` [COMPLETE] message (MUST) | Review report.md, kill worker tab |
| Blocked | Unresolvable blocker hit | `attn_send to: 'main'` [BLOCKED] message (MUST) | Surface blocker to Christopher, decide next steps |
| Silent >20 min | No attn update received | — (worker may be stuck) | `/wezterm peek <pane-id>` or check STATE.md |
| Worker alive check | Every 15 min (passive) | — | `wezterm cli list \| grep <pane-id>` — if dead, flag to Christopher |

## Rules

- NEVER execute implementation in the main pi session — spawn a worker
- L1 trivial code tasks get a worker (fast-path). Pure-comms L1 (answer Q, read file, check status) stays in main.
- Always complete ALL pre-spawn setup BEFORE calling `/wezterm spawn`
- Always inject the WORKER ROLE OVERRIDE preamble before any brief
- Workers MUST open STATE.md as their FIRST action
- Monitor workers via attn push notifications — workers push [PROGRESS]/[COMPLETE]/[BLOCKED] to main. STATE.md is the durable record, attn is the real-time signal.
- Kill worker tabs when tasks are complete (Ctrl+D) — don't leave orphans
- Worker tabs should be named after their task slug for traceability
- Template files: `~/.pi/agent/notes/templates/STATE.md` and `initiative.md`
