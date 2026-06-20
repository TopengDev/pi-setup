#!/usr/bin/env bash
# resume-worker.sh — re-brief a killed/stalled worker via WezTerm.
#
# Usage: resume-worker.sh <pane_name> <task_dir> [--with-brief <orig_brief>]
#
# Injects a RESUME preamble pointing the worker at its STATE.md and Resume cursor,
# then optionally re-injects the original brief for full context.
# Delegates delivery to brief-worker.sh (so the worker re-absorbs the role-override).

set -euo pipefail

PANE_NAME="${1:?usage: resume-worker.sh <pane_name> <task_dir> [--with-brief <orig_brief>]}"
TASK_DIR="${2:?usage: resume-worker.sh <pane_name> <task_dir> [--with-brief <orig_brief>]}"
WITH_BRIEF=""
if [[ "${3:-}" == "--with-brief" && -n "${4:-}" ]]; then
  WITH_BRIEF="$4"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${PI_WORKER_REGISTRY:-$HOME/.pi/agent/state/worker-registry.json}"

STATE_FILE="$TASK_DIR/STATE.md"
if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: STATE.md not found at $STATE_FILE" >&2
  exit 1
fi

# Resolve pane_id
PANE_ID=$(jq -r --arg n "$PANE_NAME" '.[$n] // empty' "$REGISTRY" 2>/dev/null)
if [[ -z "$PANE_ID" ]]; then
  echo "ERROR: '$PANE_NAME' not found in registry. Run spawn-worker.sh first." >&2
  exit 1
fi

# Extract Resume cursor from STATE.md
RESUME_CURSOR=$(grep -i "^## Resume cursor" -A1 "$STATE_FILE" 2>/dev/null | tail -1 | xargs || echo "first incomplete checkpoint")

# Build resume preamble as a temp brief file
TMP_BRIEF="$(mktemp /tmp/resume-XXXXXX.md)"
trap "rm -f $TMP_BRIEF" EXIT

cat > "$TMP_BRIEF" << RESUME
## RESUME — CONTINUE FROM CHECKPOINT

You are resuming a previously interrupted task. DO NOT start over. DO NOT redo completed work.

**Your task dir:** $TASK_DIR
**STATE.md:** $STATE_FILE
**Resume cursor:** $RESUME_CURSOR

**Resume protocol:**
1. Read STATE.md immediately — it is your source of truth.
2. Trust all [x] checkpoints — they were verified before being marked done.
3. Cheaply re-verify the last [x] checkpoint still holds (e.g., check the file/command output).
4. Continue from the first [ ] checkpoint (your Resume cursor).
5. Keep updating STATE.md as you work. Mark checkpoints [x] only AFTER verifying each one.

RESUME

if [[ -n "$WITH_BRIEF" ]]; then
  echo "" >> "$TMP_BRIEF"
  echo "---" >> "$TMP_BRIEF"
  echo "" >> "$TMP_BRIEF"
  echo "## Original Brief (for full context)" >> "$TMP_BRIEF"
  echo "" >> "$TMP_BRIEF"
  cat "$WITH_BRIEF" >> "$TMP_BRIEF"
fi

# Detect L1 (stub STATE.md) by checking for parent initiative linkage
if grep -qi "parent initiative" "$STATE_FILE" 2>/dev/null; then
  MODE_FLAG=""
else
  MODE_FLAG="--quick"
fi

# Deliver via brief-worker.sh
"$SCRIPT_DIR/brief-worker.sh" $MODE_FLAG "$PANE_NAME" "$TMP_BRIEF"

echo ""
echo "OK: resume brief delivered to '$PANE_NAME' (pane $PANE_ID)."
