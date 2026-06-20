#!/usr/bin/env bash
# fleetview.sh — read-only one-screen dashboard of all active pi workers.
#
# Shows: each worker's name, pane_id, STATE.md status, mtime (STALLED if >10min),
# checkpoint progress (done/remaining), Resume cursor, and parent initiative.
#
# Usage:
#   fleetview.sh            one-shot view
#   fleetview.sh --watch    refresh every 30s (Ctrl+C to exit)
#   fleetview.sh --watch 10 refresh every 10s
#
# Adapted from chilldawg-setup's tmux-based fleetview.sh for WezTerm.
# NEVER takes any action on workers — read-only.

set -uo pipefail

REGISTRY="${PI_WORKER_REGISTRY:-$HOME/.pi/agent/state/worker-registry.json}"
SUPERVISOR_REGISTRY="${PI_SUPERVISOR_REGISTRY:-$HOME/.pi/agent/state/supervisor-registry.json}"
NOTES_DIR="${NOTES_DIR:-$HOME/.pi/agent/notes}"
STALL_THRESHOLD_MIN="${PI_STALL_THRESHOLD_MIN:-10}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse args
WATCH=0
WATCH_INTERVAL=30
if [[ "${1:-}" == "--watch" ]]; then
  WATCH=1
  WATCH_INTERVAL="${2:-30}"
fi

# Source semaphore for live_pane_ids
# shellcheck source=/dev/null
[[ -r "$SCRIPT_DIR/worker-semaphore.sh" ]] && source "$SCRIPT_DIR/worker-semaphore.sh" || true

_render() {
  local now; now=$(date +%s)
  local live_panes; live_panes="$(_cs_live_pane_ids 2>/dev/null || true)"

  # Workers
  local worker_count=0
  echo "════════════════════════════════════════════════════════════════"
  echo " PI FLEET VIEW — $(date '+%Y-%m-%d %H:%M:%S')"
  echo "════════════════════════════════════════════════════════════════"

  if [[ ! -f "$REGISTRY" ]] || [[ "$(jq '. | length' "$REGISTRY" 2>/dev/null)" == "0" ]]; then
    echo " (no registered workers)"
  else
    echo " WORKERS:"
    echo ""
    while IFS=$'\t' read -r name pane_id; do
      [[ -n "$pane_id" ]] || continue
      local alive="dead"
      echo "$live_panes" | grep -qx "$pane_id" && alive="ALIVE" || true

      # Find task dir (newest match for this name)
      local task_dir="" state_file=""
      shopt -s nullglob
      local dirs=("$NOTES_DIR/${name}-"*/)
      shopt -u nullglob
      if (( ${#dirs[@]} > 0 )); then
        task_dir="${dirs[-1]}"
        state_file="${task_dir}STATE.md"
      fi

      # STATUS from STATE.md
      local status="(no STATE.md)" mtime_age="?" is_stalled=""
      if [[ -f "$state_file" ]]; then
        status=$(grep -i "^\*\*Status:\*\*\|^Status:" "$state_file" 2>/dev/null | head -1 | sed 's/.*Status:\*\*\s*//' | xargs || echo "unknown")
        local mtime; mtime=$(stat -c %Y "$state_file" 2>/dev/null || echo 0)
        local age=$(( (now - mtime) / 60 ))
        mtime_age="${age}m ago"
        if (( age >= STALL_THRESHOLD_MIN )) && [[ "$alive" == "ALIVE" ]]; then
          is_stalled=" ⚠️ STALLED"
        fi
      fi

      # Checkpoint progress
      local done_count=0 remaining_count=0 resume_cursor=""
      if [[ -f "$state_file" ]]; then
        done_count=$(grep -c '^\- \[x\]' "$state_file" 2>/dev/null || echo 0)
        remaining_count=$(grep -c '^\- \[ \]' "$state_file" 2>/dev/null || echo 0)
        resume_cursor=$(grep -i "^## Resume cursor" -A1 "$state_file" 2>/dev/null | tail -1 | xargs || echo "")
      fi

      # Parent initiative
      local initiative=""
      if [[ -f "$state_file" ]]; then
        initiative=$(grep -i "parent initiative:" "$state_file" 2>/dev/null | head -1 | sed 's/.*:\s*//' | xargs || echo "")
      fi

      printf " %-28s pane=%-5s %s\n" "$name" "$pane_id" "$alive"
      printf "   status: %-20s mtime: %s%s\n" "$status" "$mtime_age" "$is_stalled"
      printf "   checkpoints: %d done, %d remaining" "$done_count" "$remaining_count"
      [[ -n "$resume_cursor" ]] && printf "  | cursor: %s" "$resume_cursor"
      printf "\n"
      [[ -n "$initiative" ]] && printf "   initiative: %s\n" "$initiative"
      echo ""
      (( worker_count++ )) || true
    done < <(jq -r 'to_entries[] | [.key, (.value|tostring)] | @tsv' "$REGISTRY" 2>/dev/null)
  fi

  # Supervisors
  local sup_count=0
  if [[ -f "$SUPERVISOR_REGISTRY" ]] && [[ "$(jq '. | length' "$SUPERVISOR_REGISTRY" 2>/dev/null)" != "0" ]]; then
    echo "────────────────────────────────────────────────────────────────"
    echo " SUPERVISORS:"
    echo ""
    while IFS=$'\t' read -r name pane_id; do
      [[ -n "$pane_id" ]] || continue
      local alive="dead"
      echo "$live_panes" | grep -qx "$pane_id" && alive="ALIVE" || true
      printf " %-28s pane=%-5s %s\n" "$name" "$pane_id" "$alive"
      (( sup_count++ )) || true
    done < <(jq -r 'to_entries[] | [.key, (.value|tostring)] | @tsv' "$SUPERVISOR_REGISTRY" 2>/dev/null)
    echo ""
  fi

  echo "────────────────────────────────────────────────────────────────"
  local max_w; max_w="${PI_MAX_WORKERS:-6}"
  local max_s; max_s="${PI_MAX_SUPERVISORS:-4}"
  echo " capacity: $worker_count/$max_w workers  $sup_count/$max_s supervisors"
  [[ "$WATCH" == "1" ]] && echo " (watching — Ctrl+C to exit, refresh every ${WATCH_INTERVAL}s)"
  echo "════════════════════════════════════════════════════════════════"
}

if [[ "$WATCH" == "0" ]]; then
  _render
else
  while true; do
    clear 2>/dev/null || true
    _render
    sleep "$WATCH_INTERVAL"
  done
fi
