#!/usr/bin/env bash
# scan-brief.sh — no-creds-in-brief warn-scanner (fail-OPEN).
#
# Scans a worker brief (or any handoff text) for LITERAL secret VALUES — the same
# gitleaks secret-prefix set the pre-push hook uses. On a hit it prints a LOUD
# warning naming the pattern-CLASS + line number (NEVER the matched value), then
# EXITS 0 ANYWAY — this is a WARN, not a block, consistent with a fail-open
# preflight (a brief that legitimately *discusses* a key prefix must still pass).
#
# The point: catch an accidental paste of a real key into a brief. Credentials
# belong by REFERENCE ($VPS_PASSWORD, "see ~/.pi/agent/secrets.env"), never as
# literal values (see AGENTS.md → "No Credentials In A Brief").
#
# It must NOT fire on the CORRECT pattern: var-references ($FOO / ${FOO}) or the
# literal string "secrets.env" — those are stripped from each line before testing,
# so "$VPS_PASSWORD" / "${ANTHROPIC_API_KEY}" / "secrets.env" can never trip it.
#
# Usage:
#   scan-brief.sh <file> [<file> ...]   # scan one or more brief files
#   scan-brief.sh -                     # scan stdin
#   scan-brief.sh --strict <file>       # exit 1 (block) on a hit instead of warn
#   scan-brief.sh -h|--help             # this header
#
# Exit codes:
#   0  no hit, OR a hit in default (fail-open warn) mode
#   1  a hit AND --strict was given
#   2  usage error (no input / unreadable file)
#
# Opt-out: PI_BRIEF_ALLOW_SECRETS=1 silences the scan entirely (exit 0, no output).
# Windows/Git-Bash friendly: pure bash + grep + sed (no external deps).

set -uo pipefail

STRICT=0
declare -a FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    -) FILES+=("-") ;;
    -*) echo "scan-brief: unknown flag: $1 (try --help)" >&2; exit 2 ;;
    *) FILES+=("$1") ;;
  esac
  shift
done

if [ "${PI_BRIEF_ALLOW_SECRETS:-0}" = "1" ]; then
  exit 0
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "scan-brief: no input (give a file, or '-' for stdin). Try --help." >&2
  exit 2
fi

# pattern-class label | ERE  (same prefix engine as the global gitleaks hook)
SECRET_CLASSES=(
  "Anthropic-key|sk-ant-[A-Za-z0-9_-]{20,}"
  "OpenAI-style-key|sk-[A-Za-z0-9]{32,}"
  "GitHub-token|gh[pousr]_[A-Za-z0-9]{36,}"
  "GitHub-fine-PAT|github_pat_[A-Za-z0-9_]{22,}"
  "AWS-access-key-id|AKIA[0-9A-Z]{16}"
  "Google-API-key|AIza[0-9A-Za-z_-]{35}"
  "Slack-token|xox[baprs]-[A-Za-z0-9-]{10,}"
  "PEM-private-key|-----BEGIN [A-Z ]*PRIVATE KEY-----"
)

ANY_HIT=0

scan_stream() {
  local label_src="$1"     # printable name of the source (file path or "stdin")
  local hit=0 lineno=0 bline residue cls label pat
  while IFS= read -r bline || [ -n "$bline" ]; do
    lineno=$((lineno+1))
    # Strip var-refs ${VAR} and $VAR, and the literal token "secrets.env", so the
    # correct credential-by-reference pattern never matches.
    residue="$(printf '%s' "$bline" | sed -E 's/\$\{[A-Za-z_][A-Za-z0-9_]*\}//g; s/\$[A-Za-z_][A-Za-z0-9_]*//g; s/secrets\.env//g')"
    for cls in "${SECRET_CLASSES[@]}"; do
      label="${cls%%|*}"; pat="${cls#*|}"
      # `grep -- ` terminates options so the leading-dash PEM pattern is a pattern.
      if printf '%s' "$residue" | grep -qE -- "$pat" 2>/dev/null; then
        if [ "$hit" = "0" ]; then
          echo "" >&2
          echo "╔══════════════════════════════════════════════════════════════════╗" >&2
          echo "║  ⚠  BRIEF MAY CONTAIN A LITERAL SECRET — no-creds-in-brief rule  ║" >&2
          echo "╚══════════════════════════════════════════════════════════════════╝" >&2
          echo "  Source: $label_src" >&2
          echo "  Credentials belong by REFERENCE (\$VPS_PASSWORD, 'see ~/.pi/agent/secrets.env')," >&2
          echo "  never as literal values. Detected (pattern-CLASS + line, value NOT shown):" >&2
        fi
        echo "    • line $lineno — pattern-class [$label]" >&2
        hit=1
      fi
    done
  done
  if [ "$hit" = "1" ]; then ANY_HIT=1; fi
}

for f in "${FILES[@]}"; do
  if [ "$f" = "-" ]; then
    scan_stream "stdin" < /dev/stdin
  elif [ -r "$f" ]; then
    scan_stream "$f" < "$f"
  else
    echo "scan-brief: cannot read '$f' — skipping." >&2
  fi
done

if [ "$ANY_HIT" = "1" ]; then
  if [ "$STRICT" = "1" ]; then
    echo "  → BLOCKED (--strict). Scrub the brief + rotate the key if it was real." >&2
    echo "" >&2
    exit 1
  fi
  echo "  → PROCEEDING ANYWAY (fail-open warn). If this is a false positive (the brief" >&2
  echo "    legitimately discusses a key prefix), silence with PI_BRIEF_ALLOW_SECRETS=1." >&2
  echo "    If it's a REAL key: scrub the brief now and rotate the key." >&2
  echo "" >&2
fi

exit 0
