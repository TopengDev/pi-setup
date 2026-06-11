#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# pi-setup install script
#
# COPY-model installer (NO symlinks — Git Bash on Windows handles symlinks poorly
# and they need Developer Mode). Copies this repo's config into the live agent
# directories. Idempotent (re-running is safe + quiet on identical files),
# backs up any existing real file to <file>.pre-install before overwriting, and
# NEVER clobbers an existing secrets.env.
#
# Branch / profile aware:
#   • pi profile       → ~/.pi/agent/  + ~/.agents/skills/   (master branch)
#   • opencode profile → ~/.opencode/  + ~/.agents/...        (opencode branch)
# The profile is auto-detected from the checked-out branch (or the presence of
# .opencode.json), and can be forced with --profile.
#
# Usage:
#   ./install.sh                      # auto-detect profile, copy everything
#   ./install.sh --profile pi         # force the pi profile
#   ./install.sh --profile opencode   # force the opencode profile
#   ./install.sh --dry-run            # print what WOULD happen, change nothing
#   ./install.sh --force              # overwrite even identical files (still backs up)
#   ./install.sh --ci                 # non-interactive (also via PI_SETUP_CI=1);
#                                     #   proceeds without secrets.env, skips npm install
#   ./install.sh --help               # this header
#
# Windows / Git Bash notes:
#   • Pure copy — no symlinks, no reliance on chmod taking effect on NTFS.
#   • $HOME resolves to /c/Users/<you> under Git Bash; all paths are quoted.
#   • npm install (opencode mcp/) runs only if `npm` is on PATH and not --ci/--dry-run.
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
FORCE=0
CI=0
PROFILE=""

# CI can also be requested via env so a GitHub Action can set it without flags.
[ "${PI_SETUP_CI:-0}" = "1" ] && CI=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    --ci)      CI=1 ;;
    --profile)
      shift
      PROFILE="${1:-}"
      case "$PROFILE" in
        pi|opencode) ;;
        *) echo "invalid --profile '$PROFILE' (want: pi | opencode)" >&2; exit 2 ;;
      esac
      ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

# ── helpers ───────────────────────────────────────────────────────────────────
log()  { printf '\033[36m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[warn]\033[0m %s\n' "$*"; }
err()  { printf '\033[31m[err]\033[0m %s\n' "$*" >&2; }

# files_equal <a> <b> — true if both exist and are byte-identical.
files_equal() { [ -f "$1" ] && [ -f "$2" ] && cmp -s "$1" "$2"; }

# ensure_dir <abs-dir> — mkdir -p (honors --dry-run).
ensure_dir() {
  [ -d "$1" ] && return 0
  if [ "$DRY_RUN" -eq 1 ]; then log "would mkdir -p $1"; else mkdir -p "$1"; fi
}

# backup_if_real <abs-dst> — if dst is an existing regular file (or dir), move it
# to <dst>.pre-install so the copy doesn't silently destroy a real edit. Idempotent:
# if a .pre-install backup already exists, leave the original alone (don't stack).
backup_if_real() {
  local dst="$1"
  [ -e "$dst" ] || return 0
  local backup="${dst}.pre-install"
  if [ -e "$backup" ]; then
    warn "backup already exists ($backup) — not re-backing up $dst"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "would back up $dst -> $backup"
  else
    mv "$dst" "$backup"
    log "backed up $dst -> $backup"
  fi
}

# copy_file <repo-rel-src> <abs-dst>
#   Copy a single file. Idempotent: skips when dst is byte-identical (unless --force).
#   Backs up a differing existing file first.
copy_file() {
  local src="$REPO_DIR/$1" dst="$2"
  if [ ! -f "$src" ]; then
    warn "missing source (skipping): $1"
    return 0
  fi
  if files_equal "$src" "$dst" && [ "$FORCE" -eq 0 ]; then
    log "ok (identical): $dst"
    return 0
  fi
  ensure_dir "$(dirname "$dst")"
  [ -e "$dst" ] && backup_if_real "$dst"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "would copy $1 -> $dst"
  else
    cp -f "$src" "$dst"
    log "copied $1 -> $dst"
  fi
}

# copy_tree <repo-rel-src-dir> <abs-dst-dir>
#   Copy a directory's CONTENTS into dst (recursively, per-file). Per-file backup +
#   identical-skip so the whole tree is idempotent and an existing real file in dst
#   is preserved as <file>.pre-install. Files present in dst but not the repo are
#   left untouched (additive copy, never a destructive sync).
copy_tree() {
  local srcdir="$REPO_DIR/$1" dstdir="$2"
  if [ ! -d "$srcdir" ]; then
    warn "missing source dir (skipping): $1"
    return 0
  fi
  ensure_dir "$dstdir"
  # Walk every regular file under srcdir; recreate its relative path under dstdir.
  while IFS= read -r -d '' f; do
    local rel="${f#"$srcdir"/}"
    local dst="$dstdir/$rel"
    if files_equal "$f" "$dst" && [ "$FORCE" -eq 0 ]; then
      log "ok (identical): $dst"
      continue
    fi
    ensure_dir "$(dirname "$dst")"
    [ -e "$dst" ] && backup_if_real "$dst"
    if [ "$DRY_RUN" -eq 1 ]; then
      log "would copy $1/$rel -> $dst"
    else
      cp -f "$f" "$dst"
      log "copied $1/$rel -> $dst"
    fi
  done < <(find "$srcdir" -type f -print0)
}

# install_secrets <abs-dst> — copy .env.example to secrets.env ONLY if it does not
# already exist. NEVER overwrite a populated secrets file (it holds real creds).
install_secrets() {
  local dst="$1"
  if [ -f "$dst" ]; then
    log "ok (secrets.env already present — left untouched): $dst"
    return 0
  fi
  if [ ! -f "$REPO_DIR/.env.example" ]; then
    warn "no .env.example in repo — cannot seed secrets.env"
    return 0
  fi
  ensure_dir "$(dirname "$dst")"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "would seed secrets.env from .env.example -> $dst (edit it with real keys)"
  else
    cp "$REPO_DIR/.env.example" "$dst"
    log "seeded secrets.env from .env.example -> $dst (now edit it with your keys)"
  fi
}

# ── profile detection ─────────────────────────────────────────────────────────
# Priority: explicit --profile → current git branch → presence of .opencode.json.
if [ -z "$PROFILE" ]; then
  branch=""
  if command -v git >/dev/null 2>&1 && git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    branch="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  fi
  case "$branch" in
    opencode) PROFILE="opencode" ;;
    master|main) PROFILE="pi" ;;
    *)
      # detached HEAD / unknown branch / no git: fall back to file presence.
      if [ -f "$REPO_DIR/.opencode.json" ]; then PROFILE="opencode"; else PROFILE="pi"; fi
      ;;
  esac
fi
log "profile: $PROFILE  (branch: ${branch:-n/a})"
[ "$DRY_RUN" -eq 1 ] && log "DRY RUN — no files will be written."

# ── per-profile install ───────────────────────────────────────────────────────
if [ "$PROFILE" = "pi" ]; then
  PI_HOME="$HOME/.pi/agent"
  AGENTS_HOME="$HOME/.agents"

  log "=== skills ==="
  copy_tree skills "$PI_HOME/skills"
  copy_tree skills "$AGENTS_HOME/skills"

  log "=== extensions ==="
  copy_tree extensions "$PI_HOME/extensions"

  log "=== notes (templates) ==="
  copy_tree notes "$PI_HOME/notes"

  log "=== rules (AGENTS.md) ==="
  copy_file AGENTS.md "$PI_HOME/AGENTS.md"

  log "=== secrets ==="
  install_secrets "$PI_HOME/secrets.env"

elif [ "$PROFILE" = "opencode" ]; then
  OC_HOME="$HOME/.opencode"
  AGENTS_HOME="$HOME/.agents"

  log "=== skills ==="
  copy_tree skills "$AGENTS_HOME/skills"
  copy_tree skills "$OC_HOME/skills"

  log "=== notes (templates) ==="
  copy_tree notes "$AGENTS_HOME/notes"
  copy_tree notes "$OC_HOME/notes"

  log "=== rules (CLAUDE.md + AGENTS.md) ==="
  copy_file CLAUDE.md "$OC_HOME/CLAUDE.md"
  copy_file AGENTS.md "$OC_HOME/AGENTS.md"

  log "=== opencode config ==="
  # .opencode.json is the repo template name; it installs as ~/.opencode/opencode.json
  copy_file .opencode.json "$OC_HOME/opencode.json"

  log "=== commands ==="
  copy_tree commands "$OC_HOME/commands"

  log "=== mcp servers ==="
  copy_tree mcp "$OC_HOME/mcp"
  # Install the attn MCP server's node deps. Skipped in --ci/--dry-run (CI only
  # validates placement) and when npm is absent (fail-open with a clear hint).
  if [ "$CI" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
    log "skipping 'npm install' for mcp/ (ci/dry-run) — run it manually: (cd $OC_HOME/mcp && npm install)"
  elif command -v npm >/dev/null 2>&1; then
    if [ -f "$OC_HOME/mcp/package.json" ]; then
      log "running npm install in $OC_HOME/mcp ..."
      ( cd "$OC_HOME/mcp" && npm install ) || warn "npm install failed in mcp/ — run it manually later"
    fi
  else
    warn "npm not found — skipping mcp/ deps. Install Node.js then: (cd $OC_HOME/mcp && npm install)"
  fi

  log "=== secrets ==="
  install_secrets "$OC_HOME/secrets.env"
fi

# ── done ──────────────────────────────────────────────────────────────────────
echo ""
log "install complete (profile: $PROFILE)."
[ "$DRY_RUN" -eq 1 ] && log "(dry run — no changes were made)"
echo ""
log "Next steps:"
if [ "$PROFILE" = "pi" ]; then
  log "  1. edit ~/.pi/agent/secrets.env with your API keys"
  log "  2. source it from ~/.bashrc:  source ~/.pi/agent/secrets.env 2>/dev/null"
  log "  3. run:  pi"
else
  log "  1. edit ~/.opencode/secrets.env with your API keys"
  log "  2. fill provider keys in ~/.opencode/opencode.json"
  log "  3. run:  opencode"
fi
