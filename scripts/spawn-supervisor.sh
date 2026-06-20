#!/usr/bin/env bash
# spawn-supervisor.sh — spawn a SUPERVISOR in a new WezTerm tab.
#
# Usage: spawn-supervisor.sh <pane_name> [<cwd>] [<task_dir>]
#
# Supervisors own orchestration of a fleet/initiative — they delegate to workers
# via spawn-worker.sh and keep main free as the user's conversation partner.
#
# Architecture:
#   user ──► main (discussion + delegation)
#              │ spawns
#              ▼
#         supervisor (orchestrates initiative, idle-cheap)
#              │ spawns
#              ▼
#         workers (execute tasks, report via attn)
#
# Supervisor reports to main via attn ONLY on meaningful checkpoints:
# (1) direction plan before spawning fleet, (2) milestones, (3) blockers,
# (4) done. NEVER DMs the user directly — main is the sole human relay.

set -euo pipefail

PANE_NAME="${1:?usage: spawn-supervisor.sh <pane_name> [<cwd>] [<task_dir>]}"
CWD="${2:-$HOME/.pi/agent}"
TASK_DIR="${3:-${TASK_DIR:-}}"
NOTES_DIR="${NOTES_DIR:-$HOME/.pi/agent/notes}"

SUPERVISOR_REGISTRY="${PI_SUPERVISOR_REGISTRY:-$HOME/.pi/agent/state/supervisor-registry.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# TRIAGE GATE — L3 supervisors still need sign-off
CHECK_TRIAGE="$SCRIPT_DIR/check-triage.sh"
if [[ -x "$CHECK_TRIAGE" ]]; then
  if ! "$CHECK_TRIAGE" "$PANE_NAME" "$TASK_DIR"; then
    echo "" >&2
    echo "REFUSING TO SPAWN SUPERVISOR '$PANE_NAME': triage gate failed." >&2
    exit 4
  fi
fi

# Sanity: wezterm available
command -v wezterm >/dev/null 2>&1 || { echo "ERROR: wezterm CLI not found" >&2; exit 1; }

# Check supervisor cap
SEMAPHORE="$SCRIPT_DIR/worker-semaphore.sh"
if [[ -r "$SEMAPHORE" ]]; then
  # shellcheck source=/dev/null
  source "$SEMAPHORE"
  if ! cs_has_supervisor_capacity; then
    echo "" >&2
    echo "REFUSING TO SPAWN SUPERVISOR '$PANE_NAME': supervisor cap reached (PI_MAX_SUPERVISORS=$(_cs_supervisor_max))." >&2
    echo "    - raise the cap: PI_MAX_SUPERVISORS=$(( $(_cs_supervisor_max) + 1 )) spawn-supervisor.sh ..." >&2
    exit 5
  fi
fi

# Spawn the supervisor pane
BASH_BIN="${PI_BASH:-/c/Program Files/Git/bin/bash.exe}"
[[ ! -x "$BASH_BIN" ]] && command -v bash >/dev/null 2>&1 && BASH_BIN="$(command -v bash)"

PANE_ID=$(wezterm cli spawn --cwd "$CWD" \
  -- "$BASH_BIN" -c \
  "ATTN_SESSION='${PANE_NAME}' pi --name '${PANE_NAME}' --dangerously-skip-permissions 2>&1" \
  2>/dev/null)

[[ -z "$PANE_ID" ]] && { echo "ERROR: wezterm cli spawn returned empty pane_id" >&2; exit 1; }

# Register in supervisor registry
mkdir -p "$(dirname "$SUPERVISOR_REGISTRY")"
[[ -f "$SUPERVISOR_REGISTRY" ]] || echo "{}" > "$SUPERVISOR_REGISTRY"
TMP="$(mktemp)"
jq --arg n "$PANE_NAME" --argjson id "$PANE_ID" '.[$n] = $id' "$SUPERVISOR_REGISTRY" > "$TMP" && mv "$TMP" "$SUPERVISOR_REGISTRY"

echo "OK: supervisor '$PANE_NAME' spawned at pane_id=$PANE_ID."
echo ""
echo "NEXT:"
echo "  1. Verify attn peer: '$PANE_NAME' visible in local peers"
echo "  2. Brief via: brief-worker.sh --supervisor '$PANE_NAME' <brief-file>"
echo "  3. Supervisor will send its DIRECTION plan to main via attn before spawning fleet"
echo ""
echo "  Supervisor pane_id: $PANE_ID"
