#!/usr/bin/env bash
# Deliver a task brief to a spawned pi worker via WezTerm.
#
# Usage:
#   brief-worker.sh              <pane_name> <brief_file>      (full path — L2/L3)
#   brief-worker.sh --quick      <pane_name> <brief_file>      (L1 fast-path)
#   brief-worker.sh --supervisor <pane_name> <brief_file>      (supervisor preamble)
#
# What this does:
#   1. Looks up pane_id for <pane_name> from the worker registry
#   2. Validates STATE.md exists in the brief's directory
#   3. Injects a worker role-override preamble
#   4. Sends the combined preamble + brief content to the WezTerm pane
#   5. Submits with Enter (carriage return)
#
# Why a helper (not raw wezterm cli send-text)?
#   - Guarantees the role-override preamble is always injected
#   - STATE.md validation ensures the 3-tier hierarchy is set up
#   - Consistent brief delivery regardless of caller
#
# Adapted from chilldawg-setup's tmux-based brief-worker.sh for WezTerm.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${PI_WORKER_REGISTRY:-$HOME/.pi/agent/state/worker-registry.json}"
SUPERVISOR_REGISTRY="${PI_SUPERVISOR_REGISTRY:-$HOME/.pi/agent/state/supervisor-registry.json}"

# Parse flags
MODE="full"
case "${1:-}" in
  --quick|-q|--l1)  MODE="quick"; shift ;;
  --supervisor|-s)  MODE="supervisor"; shift ;;
esac

PANE_NAME="${1:?usage: brief-worker.sh [--quick|--supervisor] <pane_name> <brief_file>}"
BRIEF_FILE="${2:?usage: brief-worker.sh [--quick|--supervisor] <pane_name> <brief_file>}"

if [[ ! -f "$BRIEF_FILE" ]]; then
  echo "ERROR: brief file not found: $BRIEF_FILE" >&2
  exit 1
fi

BRIEF_DIR="$(dirname "$(realpath "$BRIEF_FILE")")"

# STATE.md validation (full path requires it; --quick accepts a stub)
STATE_FILE="$BRIEF_DIR/STATE.md"
if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: STATE.md not found at $STATE_FILE" >&2
  echo "  Every task needs a STATE.md alongside the brief (3-tier task hierarchy)." >&2
  echo "  Use --quick for L1 tasks with a stub STATE.md." >&2
  exit 3
fi

if [[ "$MODE" == "full" ]]; then
  # Full path: require parent initiative linkage in STATE.md
  if ! grep -qi "parent initiative" "$STATE_FILE"; then
    echo "ERROR: STATE.md at $STATE_FILE has no 'Parent initiative' reference." >&2
    echo "  Full-path tasks must link to a parent initiative for navigability." >&2
    echo "  Add: '**Parent initiative:** <slug>' to STATE.md, OR use --quick for L1 tasks." >&2
    exit 3
  fi
fi

# Resolve pane_id from registry
if [[ ! -f "$REGISTRY" ]]; then
  echo "ERROR: worker registry not found at $REGISTRY" >&2
  echo "  Did spawn-worker.sh run successfully?" >&2
  exit 1
fi

PANE_ID=$(jq -r --arg n "$PANE_NAME" '.[$n] // empty' "$REGISTRY" 2>/dev/null)
if [[ -z "$PANE_ID" ]]; then
  echo "ERROR: '$PANE_NAME' not found in worker registry ($REGISTRY)" >&2
  echo "  Available workers: $(jq -r 'keys[]' "$REGISTRY" 2>/dev/null | tr '\n' ' ')" >&2
  exit 1
fi

# Verify pane still alive
if ! wezterm cli list 2>/dev/null | python3 -c "
import json,sys
data = json.load(sys.stdin)
panes = [str(p.get('pane_id','')) for p in data]
sys.exit(0 if '${PANE_ID}' in panes else 1)
" 2>/dev/null; then
  echo "WARNING: pane_id $PANE_ID for '$PANE_NAME' not found in wezterm list." >&2
  echo "  Worker may have died. Re-spawn with spawn-worker.sh." >&2
fi

# Scan brief for secrets (safety gate)
if [[ "${PI_BRIEF_ALLOW_SECRETS:-0}" != "1" ]]; then
  _secret_patterns='(sk-[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY|[Pp]assword\s*[:=]\s*\S{8,}|[Ss]ecret\s*[:=]\s*\S{8,})'
  if grep -qP "$_secret_patterns" "$BRIEF_FILE" 2>/dev/null; then
    echo "ERROR: brief file appears to contain secrets — refusing to deliver." >&2
    echo "  Redact credentials before briefing. Silence with PI_BRIEF_ALLOW_SECRETS=1." >&2
    exit 1
  fi
fi

# Build role-override preamble
_build_preamble() {
  local worker_name="$1" mode="$2"

  if [[ "$mode" == "supervisor" ]]; then
    cat <<EOF
You are a SPAWNED SUPERVISOR named '${worker_name}' running in a WezTerm tab. You are NOT the main coordination session — main is SEPARATE and spawned you. Verify via attn peers: you appear as '${worker_name}', main appears as 'main'.

The AGENTS.md rule 'Main Session is DISCUSSION ONLY / never run dev commands here' does NOT apply to you. You ARE the orchestrator for your assigned initiative. You spawn Sonnet workers, you do NOT execute implementation yourself.

MANDATORY REPORTING via attn:
1. Send main your DIRECTION plan BEFORE spawning the fleet (catch drift early).
2. Send a progress update at each milestone boundary.
3. Send DONE / BLOCKED when the initiative completes or you hit a hard blocker.
4. NEVER DM the user directly. Escalations go: you -> main -> user. Main is the sole human relay.

On resume (killed / session limit): read STATE.md FIRST, re-attach to live workers (check wezterm list + their STATE.md/result.json) — do NOT re-spawn workers that are already done or still in-flight. Continue from Resume cursor.

The worker pool is GLOBAL/shared (PI_MAX_WORKERS, default 6) across all supervisors + main. If spawn-worker.sh refuses (exit 5), queue and retry as workers free up.

Open STATE.md FIRST, set status IN_PROGRESS, begin your orchestration.
EOF
  elif [[ "$mode" == "quick" ]]; then
    cat <<EOF
You are a SPAWNED WORKER named '${worker_name}' in a WezTerm tab. You are NOT the main session. Main spawned you via spawn-worker.sh.

The 'Main Session is DISCUSSION ONLY' rule does NOT apply to you. You ARE the executor. Do NOT delegate further.

When COMPLETE or BLOCKED, send main an attn message:
  attn_send to='main' message='[COMPLETE] <what was done, evidence>. STATE.md set to COMPLETE.'
  or
  attn_send to='main' message='[BLOCKED] <blocker, what you tried, what you need>. STATE.md set to BLOCKED.'

Open STATE.md FIRST, set status to IN_PROGRESS, execute the task, verify your work, report back.
EOF
  else
    cat <<EOF
You are a SPAWNED WORKER named '${worker_name}' running in a WezTerm tab. You are NOT the main coordination session — main is SEPARATE and spawned you via spawn-worker.sh. Verify your identity via attn peers: you will appear as '${worker_name}' while main appears as 'main'.

The AGENTS.md rule 'Main Session is DISCUSSION ONLY / never run dev commands here' does NOT apply to you. You ARE the executor. Do NOT delegate further. Do NOT spawn sub-workers.

## MANDATORY: attn reporting (push-based — replaces STATE.md polling)

Instead of main polling STATE.md, you PUSH status updates to main via attn_send:

1. **MILESTONE**: Send a progress update at every major milestone:
   attn_send to: 'main', message: '[PROGRESS] <milestone> done. Next: <next step>. STATE.md updated.'

2. **COMPLETE**: When the task is fully done and verified:
   attn_send to: 'main', message: '[COMPLETE] Task done. Summary: <what was built/fixed, verification evidence, any caveats>. report.md written + STATE.md set to COMPLETE.'

3. **BLOCKED**: If you hit a blocker you cannot resolve:
   attn_send to: 'main', message: '[BLOCKED] <describe blocker, what you tried, what you need>. STATE.md set to BLOCKED.'

## Checkpoint discipline (resumable work)

Decompose your task into idempotent sub-steps. Mark a checkpoint [x] ONLY after verifying its effect landed (file written + re-read, command exit 0 + output asserted). The Resume cursor in STATE.md points at the first incomplete checkpoint. On resume, trust [x] checkpoints and skip them.

## On start

1. Open STATE.md FIRST
2. Set status to IN_PROGRESS
3. Fill in the Starting point section
4. Execute your task using the normal task discipline (read before edit, verify after write, no hallucinating APIs)
5. On completion: write report.md + result.json in the task notes dir, set STATE.md status to COMPLETE
6. Send attn completion report to main
EOF
  fi
}

# Build the combined preamble + brief
PREAMBLE="$(_build_preamble "$PANE_NAME" "$MODE")"
COMBINED=$(printf '%s\n\n---\n\n' "$PREAMBLE"; cat "$BRIEF_FILE")

# Send to pane
echo "Sending brief to '$PANE_NAME' (pane_id=$PANE_ID)..."
printf '%s' "$COMBINED" | wezterm cli send-text --pane-id "$PANE_ID" --no-paste

# Submit with Enter
sleep 0.3
wezterm cli send-text --pane-id "$PANE_ID" --no-paste $'\r'

echo "OK: brief delivered to '$PANE_NAME' (pane $PANE_ID). Waiting for worker to accept..."
sleep 2

# Peek at pane to verify
PANE_NOW=$(wezterm cli get-text --pane-id "$PANE_ID" 2>/dev/null | tail -10 || echo "(pane unreadable)")
echo ""
echo "--- pane tail (last 10 lines) ---"
echo "$PANE_NOW"
echo "--- end ---"
echo ""
echo "If the worker accepted, it should be processing the brief."
echo "Monitor: wezterm cli get-text --pane-id $PANE_ID | tail -20"
