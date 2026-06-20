#!/usr/bin/env bash
# Spawn a pi worker in a new WezTerm tab with attn plugin force-loaded.
#
# Usage: spawn-worker.sh <pane_name> [<cwd>] [<task_dir>]
#   <task_dir> (or $TASK_DIR env) — task notes dir holding triage.json + STATE.md.
#   If omitted, the triage gate resolves it by convention:
#   {{NOTES_DIR}}/<pane_name>-<YYYY-MM-DD>/triage.json (newest match).
#
# After this script returns 0, MAIN SESSION MUST verify attn round-trip
# by calling attn peers and confirming <pane_name> appears in the local
# peers list before sending the brief.

set -euo pipefail

PANE_NAME="${1:?usage: spawn-worker.sh <pane_name> [<cwd>] [<task_dir>]}"
CWD="${2:-$HOME/.pi/agent}"
TASK_DIR="${3:-${TASK_DIR:-}}"
NOTES_DIR="${NOTES_DIR:-$HOME/.pi/agent/notes}"

# Worker registry: maps name -> pane_id (JSON file, self-pruning)
REGISTRY="${PI_WORKER_REGISTRY:-$HOME/.pi/agent/state/worker-registry.json}"
SUPERVISOR_REGISTRY="${PI_SUPERVISOR_REGISTRY:-$HOME/.pi/agent/state/supervisor-registry.json}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# TRIAGE GATE (3-tier task hierarchy enforcement) ----------------------------
CHECK_TRIAGE="$SCRIPT_DIR/check-triage.sh"
if [[ -x "$CHECK_TRIAGE" ]]; then
  if ! "$CHECK_TRIAGE" "$PANE_NAME" "$TASK_DIR"; then
    echo "" >&2
    echo "REFUSING TO SPAWN '$PANE_NAME': triage gate failed (see above)." >&2
    echo "Every worker needs a triage.json (task-complexity-triage + 3-tier)." >&2
    echo "See scripts/TRIAGE-SCHEMA.md" >&2
    exit 4
  fi
else
  echo "WARNING: triage gate script not found/executable at $CHECK_TRIAGE" >&2
  echo "  Triage gate SKIPPED for '$PANE_NAME'. Repair before relying on enforcement." >&2
fi
# ---------------------------------------------------------------------------

# Sanity: wezterm must be available
if ! command -v wezterm >/dev/null 2>&1; then
  echo "ERROR: wezterm CLI not found in PATH. Is WezTerm installed?" >&2
  exit 1
fi

# Sanity: pane name must not already be registered (alive)
_pane_alive() {
  local name="$1"
  local pid
  pid=$(jq -r --arg n "$name" '.[$n] // empty' "$REGISTRY" 2>/dev/null)
  [[ -n "$pid" ]] || return 1
  # Verify pane is actually alive in wezterm
  wezterm cli list 2>/dev/null | grep -q "\"pane_id\":${pid}" || return 1
  return 0
}

if _pane_alive "$PANE_NAME"; then
  echo "ERROR: worker '$PANE_NAME' already exists (pane still alive in WezTerm)." >&2
  echo "  Kill it first or choose a different name." >&2
  exit 2
fi

# CONCURRENCY GOVERNOR --------------------------------------------------------
SEMAPHORE="$SCRIPT_DIR/worker-semaphore.sh"
if [[ -r "$SEMAPHORE" ]]; then
  # shellcheck source=/dev/null
  source "$SEMAPHORE"
  SPAWN_WAIT="${PI_SPAWN_WAIT:-0}"
  if ! cs_has_capacity; then
    if [[ "$SPAWN_WAIT" =~ ^[0-9]+$ ]] && (( SPAWN_WAIT > 0 )); then
      echo "[semaphore] at cap — waiting up to ${SPAWN_WAIT}s for a free slot..." >&2
      _got_slot=0
      for ((w = 0; w < SPAWN_WAIT; w++)); do
        sleep 1
        if cs_has_capacity 2>/dev/null; then _got_slot=1; break; fi
      done
      if (( _got_slot == 0 )); then
        echo "" >&2
        echo "REFUSING TO SPAWN '$PANE_NAME': worker cap reached (PI_MAX_WORKERS=$(_cs_max_workers))." >&2
        echo "  Live workers: $(cs_live_count). Kill a finished worker or raise the cap." >&2
        exit 5
      fi
      echo "[semaphore] slot freed — proceeding." >&2
    else
      echo "" >&2
      echo "REFUSING TO SPAWN '$PANE_NAME': worker cap reached (PI_MAX_WORKERS=$(_cs_max_workers))." >&2
      echo "  Live workers: $(cs_live_count). Options:" >&2
      echo "    - finish/kill a worker, then retry" >&2
      echo "    - raise the cap:   PI_MAX_WORKERS=$(( $(_cs_max_workers) + 2 )) spawn-worker.sh ..." >&2
      echo "    - wait for a slot: PI_SPAWN_WAIT=120 spawn-worker.sh ...  (waits up to 120s)" >&2
      echo "    - inspect fleet:   fleetview.sh" >&2
      exit 5
    fi
  fi
else
  echo "WARNING: worker-semaphore.sh not found at $SEMAPHORE — concurrency governor skipped." >&2
fi
# ---------------------------------------------------------------------------

# Spawn a new WezTerm tab. Returns the pane_id (integer).
# Use Git Bash explicitly (pi needs bash, not powershell).
# The pane runs: ATTN_SESSION=<name> pi --name <name> --dangerously-skip-permissions
BASH_BIN="${PI_BASH:-/c/Program Files/Git/bin/bash.exe}"
if [[ ! -x "$BASH_BIN" ]] && command -v bash >/dev/null 2>&1; then
  BASH_BIN="$(command -v bash)"
fi

PANE_ID=$(wezterm cli spawn --cwd "$CWD" \
  -- "$BASH_BIN" -c \
  "ATTN_SESSION='${PANE_NAME}' pi --name '${PANE_NAME}' --dangerously-skip-permissions 2>&1" \
  2>/dev/null)

if [[ -z "$PANE_ID" ]]; then
  echo "ERROR: wezterm cli spawn returned empty pane_id — WezTerm may not be running or CLI not available." >&2
  exit 1
fi

echo "OK: spawned pane_id=$PANE_ID for worker '$PANE_NAME'."

# Register in worker registry
mkdir -p "$(dirname "$REGISTRY")"
if [[ ! -f "$REGISTRY" ]]; then echo "{}" > "$REGISTRY"; fi
TMP_REG="$(mktemp)"
jq --arg n "$PANE_NAME" --argjson id "$PANE_ID" '.[$n] = $id' "$REGISTRY" > "$TMP_REG" && mv "$TMP_REG" "$REGISTRY"
echo "OK: registered in $REGISTRY ($PANE_NAME -> pane $PANE_ID)."

# Wait for pi to boot (poll for attn peer)
echo "Waiting for pi to boot... (may take 15-20s)"
sleep 5

echo ""
echo "OK: worker '$PANE_NAME' spawned at pane_id=$PANE_ID."
echo ""
echo "NEXT (main session MUST do):"
echo "  1. Call attn peers — confirm '$PANE_NAME' appears in local peers"
echo "  2. If NOT visible after 30s: kill with wezterm cli send-text --pane-id $PANE_ID $'\\x04'"
echo "  3. Only after peer confirmed: send brief via brief-worker.sh '$PANE_NAME' <brief-file>"
echo ""
echo "  Worker pane_id: $PANE_ID (use in WezTerm Leader+1-9 or wezterm cli activate-pane)"
