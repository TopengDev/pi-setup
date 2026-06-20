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
#   ./install.sh --remote-stack       # also clone + build attn-agnostic + pi-remote
#                                     #   (opt-in: sets up the full Telegram remote control)
#   ./install.sh --help               # this header
#
# Windows / Git Bash notes:
#   • Pure copy — no symlinks, no reliance on chmod taking effect on NTFS.
#   • $HOME resolves to /c/Users/<you> under Git Bash; all paths are quoted.
#   • npm install (opencode mcp/) runs only if `npm` is on PATH and not --ci/--dry-run.
#   • --remote-stack invokes PowerShell to build the Go attn daemon on Windows.
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
FORCE=0
CI=0
PROFILE=""
REMOTE_STACK=0

# CI can also be requested via env so a GitHub Action can set it without flags.
[ "${PI_SETUP_CI:-0}" = "1" ] && CI=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)      DRY_RUN=1 ;;
    --force)        FORCE=1 ;;
    --ci)           CI=1 ;;
    --remote-stack) REMOTE_STACK=1 ;;
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

# ── remote stack (opt-in) ─────────────────────────────────────────────────────
# Sets up the full Telegram remote-control stack:
#   attn-agnostic — the Go attn daemon + CLI + pi adapter extension
#   pi-remote     — the Telegram ↔ attn bridge bot
#
# Only runs when --remote-stack is passed.  All steps are idempotent.
# ─────────────────────────────────────────────────────────────────────────────

# Detect OS once (used by all rs_* helpers).
_rs_detect_os() {
  case "$(uname -s 2>/dev/null)" in
    Linux*)              echo "linux" ;;
    Darwin*)             echo "darwin" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)                   echo "unknown" ;;
  esac
}

# rs_clone_repo <url> <dst-dir> <name>
rs_clone_repo() {
  local url="$1" dir="$2" name="$3"
  if [ -d "$dir/.git" ]; then
    log "remote-stack: $name already cloned at $dir"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then log "would clone $name $url -> $dir"; return 0; fi
  log "remote-stack: cloning $name ..."
  ensure_dir "$(dirname "$dir")"
  git clone --depth=1 "$url" "$dir" || { err "failed to clone $name from $url"; return 1; }
  log "remote-stack: cloned $name -> $dir"
}

# rs_go_version — latest stable from go.dev/dl; falls back to hardcoded minimum.
rs_go_version() {
  if command -v python3 >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
    local v
    v=$(curl -fsSL 'https://go.dev/dl/?mode=json' 2>/dev/null | \
        python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['version'])" 2>/dev/null || true)
    [ -n "$v" ] && { echo "$v"; return; }
  fi
  echo "go1.25.11"   # minimum that satisfies go.mod (go 1.25.0)
}

# rs_ensure_go <os> — install Go user-space if not on PATH.
rs_ensure_go() {
  local os="$1"
  if command -v go >/dev/null 2>&1; then
    log "remote-stack: Go already on PATH: $(go version)"; return 0
  fi
  # Check our user-space install location.
  if [ -x "$HOME/sdk/go/bin/go" ]; then
    export PATH="$HOME/sdk/go/bin:$PATH"
    log "remote-stack: Go found at ~/sdk/go: $(go version)"; return 0
  fi
  case "$os" in
    linux|darwin)
      if [ "$DRY_RUN" -eq 1 ]; then log "would install Go to ~/sdk/go"; return 0; fi
      local goos arch ver tarball url
      case "$os" in linux) goos="linux" ;; darwin) goos="darwin" ;; esac
      case "$(uname -m)" in
        x86_64|amd64)   arch="amd64" ;;
        aarch64|arm64)  arch="arm64" ;;
        *) warn "remote-stack: unsupported arch for Go auto-install: $(uname -m)"; return 1 ;;
      esac
      ver=$(rs_go_version)
      tarball="${ver}.${goos}-${arch}.tar.gz"
      url="https://go.dev/dl/${tarball}"
      log "remote-stack: installing $ver to ~/sdk/go from $url ..."
      mkdir -p "$HOME/sdk"
      local tmp
      tmp=$(mktemp)
      curl -fsSL "$url" -o "$tmp" || { err "failed to download Go: $url"; rm -f "$tmp"; return 1; }
      tar -C "$HOME/sdk" -xzf "$tmp" && rm -f "$tmp"
      export PATH="$HOME/sdk/go/bin:$PATH"
      log "remote-stack: Go installed: $(go version)"
      log "  Add to ~/.bashrc:  export PATH=\"\$HOME/sdk/go/bin:\$PATH\""
      ;;
    windows)
      # Try winget (Windows 11 / modern Windows 10).
      if command -v winget >/dev/null 2>&1; then
        log "remote-stack: installing Go via winget ..."
        winget install GoLang.Go.1.25 --silent --accept-package-agreements --accept-source-agreements 2>/dev/null || true
        export PATH="/c/Program Files/Go/bin:$PATH"
      fi
      if ! command -v go >/dev/null 2>&1; then
        warn "remote-stack: Go not found after winget attempt."
        warn "  Install Go manually: https://go.dev/dl  (winget: winget install GoLang.Go.1.25)"
        warn "  Then re-run: ./install.sh --remote-stack"
        return 1
      fi
      log "remote-stack: Go available: $(go version)"
      ;;
    *)
      warn "remote-stack: Go not found. Install from https://go.dev/dl and re-run --remote-stack."
      return 1 ;;
  esac
}

# rs_build_attn <clone-dir> <os>
rs_build_attn() {
  local attn_dir="$1" os="$2"
  local bin_dir="$HOME/.local/bin"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "would build + install attn-agnostic binaries to $bin_dir"
    return 0
  fi

  # Idempotent: skip if binaries already present (Linux: attnd, Windows: attnd.exe).
  if ([ -x "$bin_dir/attnd" ] || [ -x "$bin_dir/attnd.exe" ]) && \
     ([ -x "$bin_dir/attn"  ] || [ -x "$bin_dir/attn.exe"  ]); then
    log "remote-stack: attn-agnostic binaries already at $bin_dir — skipping build"
    log "  (to rebuild: delete $bin_dir/attnd[.exe] and re-run --remote-stack)"
    return 0
  fi

  log "remote-stack: building attn-agnostic ..."
  mkdir -p "$bin_dir"

  case "$os" in
    linux|darwin)
      rs_build_attn_unix "$attn_dir" "$os" "$bin_dir"
      ;;
    windows)
      rs_build_attn_windows "$attn_dir" "$bin_dir"
      ;;
    *)
      warn "remote-stack: cannot auto-build on $os. Build attn-agnostic manually:"
      warn "  cd $attn_dir && bash scripts/build.sh && cp dist/linux-amd64/* $bin_dir/"
      return 1 ;;
  esac
}

# rs_build_attn_unix <clone-dir> <os> <bin-dir>
#   Builds from source via bash (not sh — build.sh uses pipefail which dash rejects).
#   Copies binaries to bin-dir and runs attnd -init.
rs_build_attn_unix() {
  local attn_dir="$1" os="$2" bin_dir="$3"
  local arch
  case "$(uname -m)" in
    x86_64|amd64)  arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) warn "remote-stack: unsupported arch: $(uname -m)"; return 1 ;;
  esac
  local target="${os}-${arch}"

  # Build binaries into attn_dir/dist/<target>/ using bash explicitly.
  ( cd "$attn_dir" && bash scripts/build.sh "${os}/${arch}" ) || \
    { err "remote-stack: attn-agnostic build failed (bash scripts/build.sh ${os}/${arch})"; return 1; }

  # Copy all produced binaries to bin_dir.
  local dist_dir="$attn_dir/dist/${target}"
  [ -d "$dist_dir" ] || { err "remote-stack: expected dist dir not found: $dist_dir"; return 1; }
  local copied=0
  for b in "$dist_dir"/*; do
    [ -f "$b" ] || continue
    local bname
    bname="$(basename "$b")"
    case "$bname" in
      *.txt|*.md) continue ;;  # skip SHA256SUMS.txt, README, etc.
    esac
    cp "$b" "$bin_dir/$bname"
    chmod 0755 "$bin_dir/$bname"
    copied=$((copied + 1))
  done
  [ "$copied" -gt 0 ] || { err "remote-stack: no binaries found in $dist_dir"; return 1; }
  log "remote-stack: $copied binaries installed to $bin_dir"

  # Generate identity (idempotent — attnd -init skips keygen if key exists).
  # Non-fatal: on sandboxed CI environments this may fail; the daemon generates
  # the key on first real startup.
  log "remote-stack: running attnd -init ..."
  local attn_home="${ATTN_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/attn}"
  mkdir -p "$attn_home"
  ATTN_HOME="$attn_home" "$bin_dir/attnd" -init \
    && log "remote-stack: attn identity ready in $attn_home" \
    || warn "remote-stack: attnd -init failed (key will be generated on first daemon start)"
}

# rs_build_attn_windows <clone-dir> <bin-dir>
rs_build_attn_windows() {
  local attn_dir="$1" bin_dir="$2"

  # Prefer pwsh.exe (PowerShell 7+) over powershell.exe (Windows PowerShell 5.1).
  local ps_cmd=""
  command -v pwsh.exe     >/dev/null 2>&1 && ps_cmd="pwsh.exe"
  command -v powershell.exe >/dev/null 2>&1 && [ -z "$ps_cmd" ] && ps_cmd="powershell.exe"

  if [ -z "$ps_cmd" ]; then
    warn "remote-stack: PowerShell not found. Build manually:"
    warn "  Open PowerShell, cd to attn-agnostic, run: \$env:ATTN_SKIP_SERVICE='1'; .\\scripts\\install.ps1"
    return 1
  fi

  # Convert POSIX paths to Windows for PowerShell.
  local attn_win bin_win
  attn_win="$(cygpath -w "$attn_dir" 2>/dev/null || echo "$attn_dir")"
  bin_win="$(cygpath -w "$bin_dir"   2>/dev/null || echo "$bin_dir")"

  log "remote-stack: building via PowerShell ($ps_cmd) ..."
  "$ps_cmd" -ExecutionPolicy Bypass -Command "
    \$env:ATTN_REPO_DIR='${attn_win}';
    \$env:ATTN_BIN_DIR='${bin_win}';
    \$env:ATTN_SKIP_SERVICE='1';
    & '${attn_win}\\scripts\\install.ps1'
  " || { err "remote-stack: PowerShell build failed"; return 1; }
}

# rs_wire_pi_adapter <attn-clone-dir> <pi-home>
#   Replace the old bundled attn extension with the attn-agnostic pi adapter.
rs_wire_pi_adapter() {
  local attn_dir="$1" pi_home="$2"
  local adapter_src="$attn_dir/adapters/pi"
  local ext_dst="$pi_home/extensions/attn"

  if [ ! -d "$adapter_src" ]; then
    warn "remote-stack: pi adapter not found at $adapter_src — skipping"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "would replace $ext_dst with attn-agnostic pi adapter from $adapter_src"
    return 0
  fi

  # Idempotent marker: adapter has src/index.ts; old extension did not.
  if [ -f "$ext_dst/src/index.ts" ]; then
    log "remote-stack: attn-agnostic pi adapter already wired at $ext_dst"
  else
    # Back up the old extension if present.
    if [ -d "$ext_dst" ]; then
      local backup="${ext_dst}.pre-install"
      if [ ! -d "$backup" ]; then
        mv "$ext_dst" "$backup"
        log "remote-stack: backed up old extension -> $backup"
      fi
    fi
    ensure_dir "$ext_dst"
    cp -rf "$adapter_src/." "$ext_dst/"
    log "remote-stack: installed pi adapter -> $ext_dst"
  fi

  # Install runtime deps (idempotent: npm install is safe to re-run).
  if [ -f "$ext_dst/package.json" ] && command -v npm >/dev/null 2>&1; then
    log "remote-stack: npm install in $ext_dst ..."
    ( cd "$ext_dst" && npm install --omit=dev ) || \
      warn "remote-stack: npm install failed in adapter dir — run manually: cd $ext_dst && npm install --omit=dev"
  fi
}

# rs_setup_pi_remote <clone-dir>
rs_setup_pi_remote() {
  local remote_dir="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "would set up pi-remote in $remote_dir"
    return 0
  fi

  # Defensive: strip any residual terminal escape sequences from bot.js.
  local botjs="$remote_dir/bot/bot.js"
  if [ -f "$botjs" ] && command -v python3 >/dev/null 2>&1; then
    python3 - "$botjs" <<'PYEOF' 2>/dev/null && log "remote-stack: escape-sequence guard applied to bot.js" || true
import re, sys
with open(sys.argv[1], 'rb') as f:
    c = f.read()
cleaned = re.sub(rb'\x1b\[[^a-zA-Z]*[a-zA-Z]', b'', c)
with open(sys.argv[1], 'wb') as f:
    f.write(cleaned)
PYEOF
  fi

  # npm install for the bot.
  local bot_dir="$remote_dir/bot"
  if [ -f "$bot_dir/package.json" ] && command -v npm >/dev/null 2>&1; then
    log "remote-stack: npm install in $bot_dir ..."
    ( cd "$bot_dir" && npm install ) || \
      warn "remote-stack: npm install failed — run manually: cd $bot_dir && npm install"
  fi

  # Seed .env from .env.example if not already present.
  local env_file="$remote_dir/.env"
  if [ ! -f "$env_file" ] && [ -f "$remote_dir/.env.example" ]; then
    cp "$remote_dir/.env.example" "$env_file"
    log "remote-stack: seeded $env_file (edit with your Telegram token + PI_ADDRESS)"
  fi
}

# remote_stack_setup — orchestrates the full remote-stack install.
remote_stack_setup() {
  log ""
  log "=== remote stack (attn-agnostic + pi-remote) ==="

  local rs_os
  rs_os="$(_rs_detect_os)"
  log "remote-stack: OS = $rs_os"

  if ! command -v git >/dev/null 2>&1; then
    err "remote-stack: 'git' not found — install Git and re-run with --remote-stack"
    return 1
  fi

  # Determine pi home (used for cloning and extension wiring).
  local pi_home="$HOME/.pi/agent"
  ensure_dir "$pi_home"

  # 1. attn-agnostic
  local attn_dir="$pi_home/attn-agnostic"
  rs_clone_repo "https://github.com/TopengDev/attn-agnostic.git" "$attn_dir" "attn-agnostic"
  rs_ensure_go "$rs_os" || { warn "remote-stack: Go unavailable; skipping attn build (re-run after installing Go)"; }
  if command -v go >/dev/null 2>&1 || [ -x "$HOME/sdk/go/bin/go" ]; then
    rs_build_attn "$attn_dir" "$rs_os"
  fi
  rs_wire_pi_adapter "$attn_dir" "$pi_home"

  # 2. pi-remote
  local remote_dir="$pi_home/pi-remote"
  rs_clone_repo "https://github.com/TopengDev/pi-remote.git" "$remote_dir" "pi-remote"
  rs_setup_pi_remote "$remote_dir"

  log ""
  log "=== remote stack complete ==="
  log ""
  log "Next steps for the remote stack:"
  log "  1. Fill secrets in ~/.pi/agent/secrets.env:"
  log "       DEEPSEEK_API_KEY   — from https://platform.deepseek.com"
  log "       TELEGRAM_BOT_TOKEN — from @BotFather on Telegram"
  log "       SUPERUSER_TG_ID    — your numeric Telegram ID (@userinfobot)"
  log "  2. Start the attn daemon:"
  if [ "$rs_os" = "linux" ] || [ "$rs_os" = "darwin" ]; then
    log "       systemctl --user start attnd   OR   ~/.local/bin/attnd &"
  else
    log "       start the 'attnd' Scheduled Task (or run ~/.local/bin/attnd.exe directly)"
  fi
  log "  3. Get your attn address:  attn status"
  log "  4. Edit $pi_home/pi-remote/.env:"
  log "       PI_ADDRESS=<your attnd address from step 3>"
  log "  5. Start the Telegram bridge:"
  log "       source ~/.pi/agent/secrets.env && node $pi_home/pi-remote/bot/bot.js"
  log "  6. Chat your pi agent via Telegram!"
}

[ "$REMOTE_STACK" -eq 1 ] && remote_stack_setup

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
