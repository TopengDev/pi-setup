#!/usr/bin/env bash
# worker-semaphore.sh — concurrency governor for pi worker fleet.
#
# Source this file to get the semaphore functions:
#   source worker-semaphore.sh
#   cs_has_capacity   # returns 0 if a slot is free
#   cs_live_count     # print live worker count
#   cs_status         # human-readable summary
#
# Config env vars:
#   PI_MAX_WORKERS         max concurrent pipeline workers, GLOBAL/shared (default 6)
#   PI_MAX_SUPERVISORS     max concurrent supervisors (default 4)
#   PI_WORKER_REGISTRY     override the worker registry file path
#   PI_SUPERVISOR_REGISTRY override the supervisor registry file path
#
# Uses: worker registry (name->pane_id JSON) intersected with live wezterm panes.
# Fail-open: if count can't be determined, the spawn is allowed.

REGISTRY="${PI_WORKER_REGISTRY:-$HOME/.pi/agent/state/worker-registry.json}"
SUPERVISOR_REGISTRY="${PI_SUPERVISOR_REGISTRY:-$HOME/.pi/agent/state/supervisor-registry.json}"

_cs_max_workers()    { echo "${PI_MAX_WORKERS:-6}"; }
_cs_supervisor_max() { echo "${PI_MAX_SUPERVISORS:-4}"; }

# Get list of live pane IDs from wezterm
_cs_live_pane_ids() {
  wezterm cli list 2>/dev/null \
    | python3 -c "
import json,sys
try:
    data = json.load(sys.stdin)
    for p in data:
        print(str(p.get('pane_id','')))
except:
    pass
" 2>/dev/null || true
}

# Count live workers: entries in registry whose pane_id is still alive in wezterm
cs_live_count() {
  [[ -f "$REGISTRY" ]] || { echo 0; return 0; }
  local live_panes
  live_panes="$(_cs_live_pane_ids)"
  # For each name in registry, check if pane_id is in live_panes
  local count=0
  while IFS=$'\t' read -r name pane_id; do
    [[ -n "$pane_id" ]] || continue
    if echo "$live_panes" | grep -qx "$pane_id"; then
      (( count++ )) || true
    fi
  done < <(jq -r 'to_entries[] | [.key, (.value|tostring)] | @tsv' "$REGISTRY" 2>/dev/null)
  echo "$count"
}

cs_supervisor_live_count() {
  [[ -f "$SUPERVISOR_REGISTRY" ]] || { echo 0; return 0; }
  local live_panes
  live_panes="$(_cs_live_pane_ids)"
  local count=0
  while IFS=$'\t' read -r name pane_id; do
    [[ -n "$pane_id" ]] || continue
    if echo "$live_panes" | grep -qx "$pane_id"; then
      (( count++ )) || true
    fi
  done < <(jq -r 'to_entries[] | [.key, (.value|tostring)] | @tsv' "$SUPERVISOR_REGISTRY" 2>/dev/null)
  echo "$count"
}

cs_has_capacity() {
  local live max
  live=$(cs_live_count 2>/dev/null) || { return 0; }  # fail-open on error
  max=$(_cs_max_workers)
  (( live < max ))
}

cs_has_supervisor_capacity() {
  local live max
  live=$(cs_supervisor_live_count 2>/dev/null) || { return 0; }
  max=$(_cs_supervisor_max)
  (( live < max ))
}

cs_register_worker() {
  local name="$1" pane_id="${2:-}"
  [[ -n "$pane_id" ]] || return 0  # no pane_id supplied, skip
  mkdir -p "$(dirname "$REGISTRY")"
  [[ -f "$REGISTRY" ]] || echo "{}" > "$REGISTRY"
  local tmp; tmp="$(mktemp)"
  jq --arg n "$name" --argjson id "$pane_id" '.[$n] = $id' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
}

cs_register_supervisor() {
  local name="$1" pane_id="${2:-}"
  [[ -n "$pane_id" ]] || return 0
  mkdir -p "$(dirname "$SUPERVISOR_REGISTRY")"
  [[ -f "$SUPERVISOR_REGISTRY" ]] || echo "{}" > "$SUPERVISOR_REGISTRY"
  local tmp; tmp="$(mktemp)"
  jq --arg n "$name" --argjson id "$pane_id" '.[$n] = $id' "$SUPERVISOR_REGISTRY" > "$tmp" && mv "$tmp" "$SUPERVISOR_REGISTRY"
}

# Prune dead entries from registry (housekeeping)
cs_prune_registry() {
  local reg="$1"
  [[ -f "$reg" ]] || return 0
  local live_panes; live_panes="$(_cs_live_pane_ids)"
  local tmp; tmp="$(mktemp)"
  jq --argjson live "$(echo "$live_panes" | jq -R -s '[split("\n")[] | select(length>0) | tonumber? // empty]')" \
    'with_entries(select(.value as $id | ($live | index($id)) != null))' \
    "$reg" > "$tmp" && mv "$tmp" "$reg"
}

# Status report (for fleetview or manual inspection)
cs_status() {
  local wlive wsup_live wmax smax
  wlive=$(cs_live_count 2>/dev/null || echo "?")
  wsup_live=$(cs_supervisor_live_count 2>/dev/null || echo "?")
  wmax=$(_cs_max_workers)
  smax=$(_cs_supervisor_max)

  echo "workers:     $wlive / $wmax  (PI_MAX_WORKERS)"
  echo "supervisors: $wsup_live / $smax  (PI_MAX_SUPERVISORS)"
  echo "registry:    $REGISTRY"

  if [[ -f "$REGISTRY" ]]; then
    echo ""
    echo "registered workers:"
    local live_panes; live_panes="$(_cs_live_pane_ids)"
    while IFS=$'\t' read -r name pane_id; do
      local status="dead"
      echo "$live_panes" | grep -qx "$pane_id" && status="ALIVE"
      printf "  %-30s pane=%-6s %s\n" "$name" "$pane_id" "$status"
    done < <(jq -r 'to_entries[] | [.key, (.value|tostring)] | @tsv' "$REGISTRY" 2>/dev/null)
  fi
}

# If called directly (not sourced), run status report
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-status}" in
    status) cs_status ;;
    prune)  cs_prune_registry "$REGISTRY"; cs_prune_registry "$SUPERVISOR_REGISTRY"; echo "pruned" ;;
    count)  cs_live_count ;;
    *) echo "usage: worker-semaphore.sh [status|prune|count]" >&2; exit 1 ;;
  esac
fi
