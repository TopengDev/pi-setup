#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# setup-doctor.sh — READ-ONLY drift auditor for pi-setup.
#
# Reports divergence between what this repo SHIPS and what the live agent
# directories actually have. Changes NOTHING. Safe to run anytime, any number of
# times. The companion verifier to install.sh: install.sh copies the repo into
# ~/.pi/agent / ~/.opencode / ~/.agents; setup-doctor asserts that copy is current.
#
# Profile-aware (auto-detected from branch / .opencode.json, override with --profile):
#   • pi       → ~/.pi/agent/{skills,extensions,notes,AGENTS.md} + ~/.agents/skills
#   • opencode → ~/.opencode/{skills,notes,commands,mcp,opencode.json,CLAUDE.md,AGENTS.md}
#                + ~/.agents/{skills,notes} + secrets.env
#
# NO systemd / VPS / daemon checks — pi runs on Windows + Git Bash, which has none.
#
# Usage:
#   setup-doctor.sh                  # full report
#   setup-doctor.sh --profile pi     # force a profile
#   setup-doctor.sh --quiet          # only DRIFT lines + verdict
#   setup-doctor.sh --no-color       # disable ANSI color
#
# Exit codes:
#   0  no drift   (every area the repo declares is live + current)
#   1  drift      (at least one MISSING / STALE area)
#   2  self-error (couldn't locate repo)
# ──────────────────────────────────────────────────────────────────────────────

set -uo pipefail   # NOT -e: a single failed check must not abort the whole audit.

QUIET=0
USE_COLOR=1
PROFILE=""
[ -t 1 ] || USE_COLOR=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --quiet|-q) QUIET=1 ;;
    --no-color) USE_COLOR=0 ;;
    --profile)  shift; PROFILE="${1:-}";
                case "$PROFILE" in pi|opencode) ;; *) echo "invalid --profile '$PROFILE'" >&2; exit 2 ;; esac ;;
    -h|--help)  sed -n '2,38p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

if [ "$USE_COLOR" = "1" ]; then
  C_G=$'\033[32m'; C_R=$'\033[31m'; C_Y=$'\033[33m'; C_B=$'\033[36m'; C_DIM=$'\033[2m'; C_0=$'\033[0m'
else
  C_G=''; C_R=''; C_Y=''; C_B=''; C_DIM=''; C_0=''
fi

PASS=0; DRIFT=0; SKIP=0
pass() { PASS=$((PASS+1));  [ "$QUIET" = "1" ] || printf '  %sPASS%s  %s\n' "$C_G" "$C_0" "$1"; }
drift(){ DRIFT=$((DRIFT+1));                printf '  %sDRIFT%s %s\n' "$C_R" "$C_0" "$1"; }
skip() { SKIP=$((SKIP+1));   [ "$QUIET" = "1" ] || printf '  %sSKIP%s  %s\n' "$C_Y" "$C_0" "$1"; }
sect() { [ "$QUIET" = "1" ] || printf '\n%s== %s ==%s\n' "$C_B" "$1" "$C_0"; }

# ── locate repo root (this script lives in <repo>/scripts/) ───────────────────
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SELF/.." && pwd)"
if [ ! -f "$REPO_DIR/install.sh" ]; then
  echo "${C_R}FATAL${C_0}: could not find install.sh at $REPO_DIR/install.sh (is this script in <repo>/scripts/?)" >&2
  exit 2
fi

# ── profile detection (mirror install.sh) ─────────────────────────────────────
if [ -z "$PROFILE" ]; then
  branch=""
  if command -v git >/dev/null 2>&1 && git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    branch="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  fi
  case "$branch" in
    opencode) PROFILE="opencode" ;;
    master|main) PROFILE="pi" ;;
    *) if [ -f "$REPO_DIR/.opencode.json" ]; then PROFILE="opencode"; else PROFILE="pi"; fi ;;
  esac
fi

[ "$QUIET" = "1" ] || {
  printf '%ssetup-doctor%s — drift audit  %s%s%s\n' "$C_B" "$C_0" "$C_DIM" "$(date '+%Y-%m-%d %H:%M:%S')" "$C_0"
  printf '%srepo:%s %s   %sprofile:%s %s\n' "$C_DIM" "$C_0" "$REPO_DIR" "$C_DIM" "$C_0" "$PROFILE"
}

# check_file <repo-rel-src> <abs-dst> — dst must exist + be byte-identical to repo src.
check_file() {
  local src="$REPO_DIR/$1" dst="$2"
  if [ ! -f "$src" ]; then skip "repo source absent ($1) — nothing to check at $dst"; return; fi
  if [ ! -e "$dst" ]; then drift "MISSING: $dst (expected copy of $1)"; return; fi
  if cmp -s "$src" "$dst"; then pass "$dst == $1"; else drift "STALE: $dst differs from repo $1 (re-run install.sh)"; fi
}

# check_tree <repo-rel-src-dir> <abs-dst-dir> — every repo file must exist + match at dst.
# Additive model: extra files at dst are NOT drift (install.sh never deletes).
check_tree() {
  local srcdir="$REPO_DIR/$1" dstdir="$2"
  if [ ! -d "$srcdir" ]; then skip "repo source dir absent ($1)"; return; fi
  if [ ! -d "$dstdir" ]; then drift "MISSING dir: $dstdir (expected copy of $1/)"; return; fi
  local missing=0 stale=0 total=0
  while IFS= read -r -d '' f; do
    total=$((total+1))
    local rel="${f#"$srcdir"/}"
    local dst="$dstdir/$rel"
    if [ ! -e "$dst" ]; then drift "MISSING: $dstdir/$rel"; missing=$((missing+1));
    elif ! cmp -s "$f" "$dst"; then drift "STALE: $dstdir/$rel differs from repo"; stale=$((stale+1)); fi
  done < <(find "$srcdir" -type f -print0)
  if [ "$missing" -eq 0 ] && [ "$stale" -eq 0 ]; then pass "$dstdir/ matches $1/ ($total files)"; fi
}

# ── per-profile checks ────────────────────────────────────────────────────────
if [ "$PROFILE" = "pi" ]; then
  PI_HOME="$HOME/.pi/agent"; AGENTS_HOME="$HOME/.agents"
  sect "skills";      check_tree skills "$PI_HOME/skills"; check_tree skills "$AGENTS_HOME/skills"
  sect "extensions";  check_tree extensions "$PI_HOME/extensions"
  sect "notes";       check_tree notes "$PI_HOME/notes"
  sect "rules";       check_file AGENTS.md "$PI_HOME/AGENTS.md"
  sect "secrets"
  if [ -f "$PI_HOME/secrets.env" ]; then pass "$PI_HOME/secrets.env present"; else drift "$PI_HOME/secrets.env MISSING (cp .env.example then edit)"; fi
else
  OC_HOME="$HOME/.opencode"; AGENTS_HOME="$HOME/.agents"
  sect "skills";      check_tree skills "$AGENTS_HOME/skills"; check_tree skills "$OC_HOME/skills"
  sect "notes";       check_tree notes "$AGENTS_HOME/notes"; check_tree notes "$OC_HOME/notes"
  sect "rules";       check_file CLAUDE.md "$OC_HOME/CLAUDE.md"; check_file AGENTS.md "$OC_HOME/AGENTS.md"
  sect "opencode config"; check_file .opencode.json "$OC_HOME/opencode.json"
  sect "commands";    check_tree commands "$OC_HOME/commands"
  sect "mcp";         check_tree mcp "$OC_HOME/mcp"
  sect "secrets"
  if [ -f "$OC_HOME/secrets.env" ]; then pass "$OC_HOME/secrets.env present"; else drift "$OC_HOME/secrets.env MISSING (cp .env.example then edit)"; fi
fi

# ── verdict ───────────────────────────────────────────────────────────────────
printf '\n%s──────────────────────────────────────────%s\n' "$C_DIM" "$C_0"
if [ "$DRIFT" -eq 0 ]; then
  printf '%sVERDICT: PASS%s — no drift. %d checks passed, %d skipped.\n' "$C_G" "$C_0" "$PASS" "$SKIP"
  exit 0
else
  printf '%sVERDICT: DRIFT%s — %d issue(s). %d passed, %d skipped.\n' "$C_R" "$C_0" "$DRIFT" "$PASS" "$SKIP"
  printf '%sRe-run install.sh to reconcile, then re-run setup-doctor.%s\n' "$C_DIM" "$C_0"
  exit 1
fi
