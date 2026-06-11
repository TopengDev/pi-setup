#!/usr/bin/env bash
# skill-eval.sh — STRUCTURAL validator + EVAL runner for the pi-setup skills.
#
# Protects the skill library from silent breakage. For EVERY skill it asserts the
# SKILL.md exists, has valid frontmatter (required keys, no malformed YAML), every
# COMPANION FILE the SKILL.md references resolves on disk, any declared tool refs
# are known, and any evals/evals.json is schema-valid. Changes NOTHING — read-only,
# idempotent, safe to run any number of times. CI-able (Windows + Git Bash + Linux).
#
# Usage:
#   skill-eval.sh                 # validate every skill, full report
#   skill-eval.sh <skill> [...]   # validate only the named skill(s)
#   skill-eval.sh --quiet         # only FAIL/WARN lines + the final verdict
#   skill-eval.sh --no-color      # disable ANSI color
#   skill-eval.sh --skills-dir D  # point at a different skills dir (default: auto)
#   skill-eval.sh --json          # emit a machine-readable JSON report to stdout
#   skill-eval.sh --strict        # treat WARN as failure too (exit 1 on any WARN)
#   skill-eval.sh --list          # list discovered skills + their kind, then exit
#   skill-eval.sh -h|--help       # this header
#
# Exit codes:
#   0  all structural checks passed (WARNs allowed unless --strict)
#   1  at least one structural FAIL (a real break: missing file, bad frontmatter,
#      dangling companion ref, unknown tool ref, malformed evals.json)
#   2  harness self-error (couldn't locate the skills dir / no python3)
#
# What it checks per skill (a FAIL is a hard break; a WARN is a smell):
#   FM1  SKILL.md exists + is non-empty                                  (FAIL)
#   FM2  frontmatter is a well-formed `---`-delimited YAML block         (FAIL)
#   FM3  required keys present: name, description                        (FAIL)
#   FM4  `name` matches the directory name                              (FAIL)
#   FM5  description non-trivial (>= 20 chars)                          (WARN)
#   FM6  only recognized top-level frontmatter keys                     (WARN)
#   CF1  every ./-prefixed or subdir markdown link to a *.md/*.json/... companion
#        file inside the skill resolves on disk                          (FAIL)
#   CF2  every referenced subdir (agents/ prompts/ rules/ evals/ ...) exists
#        and is non-empty when the SKILL.md points into it              (FAIL)
#   TL1  every allowed-tools entry names a known pi tool (read/bash/edit/write/
#        grep/find/ls/skill) — pi skills rarely declare these; unknown → WARN  (WARN)
#   EV1  evals/evals.json (if present) parses as JSON                    (FAIL)
#   EV2  evals.json has skill_name (== skill) + a non-empty evals array  (FAIL)
#   EV3  each eval has id + prompt + (assertions|expected_output)        (FAIL)
#   EV4  assertion-style eval `checks` (the runnable format, if present) are
#        well-formed {type,...}                                          (FAIL)
#
# Dependency-light by design: bash + python3 (for all YAML/JSON parsing). No jq,
# no yq, no node. Windows/Git-Bash friendly (python3 ships with Git for Windows'
# recommended toolchain, or via `winget install Python.Python.3`).
#
# Companion-file reference model (deliberately conservative to avoid FALSE
# POSITIVES on the many SKILL.md files that embed OUTPUT TEMPLATES referencing
# files the skill GENERATES, e.g. handover.md / docs/DEPLOYMENT.md, and on
# CONDITIONAL RUNTIME refs like .agents/product-marketing-context.md):
#   A markdown link `[text](target)` is treated as a COMPANION ref (and therefore
#   must resolve) ONLY when target is clearly a same-dir asset, i.e. it
#     - is NOT a URL (no scheme://),  is NOT an anchor (#...),  is NOT mailto:,
#     - does NOT start with / ~ . (except a leading ./),  contains no $ or < or >,
#     - starts with "./"  OR  starts with a recognized companion subdir
#       (agents/ prompts/ rules/ evals/),
#     - AND that target actually has a real-looking extension (.md .json .txt
#       .sh .py .yml .yaml .toml .csv .png .svg).
#   Everything else (bare-word "see foo.md" prose, generated-output templates,
#   external/runtime paths, <placeholder> templated names) is NOT enforced — it
#   is reported under --json as "skipped_refs" for transparency but never FAILs.
#   Refs that live inside a ``` fenced code block are ALSO skipped (they are
#   examples / generated snippets, not live links).

set -uo pipefail   # NOT -e: one failing check must never abort the whole run.

# ── args ──────────────────────────────────────────────────────────────────────
QUIET=0; USE_COLOR=1; EMIT_JSON=0; STRICT=0; LIST_ONLY=0
SKILLS_DIR=""
declare -a ONLY=()
[ -t 1 ] || USE_COLOR=0

while [ $# -gt 0 ]; do
  case "$1" in
    --quiet|-q)   QUIET=1 ;;
    --no-color)   USE_COLOR=0 ;;
    --json)       EMIT_JSON=1; QUIET=1 ;;   # JSON mode implies quiet human output
    --strict)     STRICT=1 ;;
    --list)       LIST_ONLY=1 ;;
    --skills-dir) shift; SKILLS_DIR="${1:-}" ;;
    -h|--help)    sed -n '2,75p' "$0"; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do ONLY+=("$1"); shift; done; break ;;
    -*) echo "unknown flag: $1 (try --help)" >&2; exit 2 ;;
    *)  ONLY+=("$1") ;;
  esac
  shift
done

command -v python3 >/dev/null 2>&1 || { echo "skill-eval: python3 required" >&2; exit 2; }

# ── locate skills dir ─────────────────────────────────────────────────────────
# Priority: --skills-dir → PI_SKILLS_DIR → repo-relative to this script →
#           ~/.pi/agent/skills  → ~/.agents/skills  (the live install paths).
SELF="$(cd "$(dirname "$0")" && pwd)"
if [ -z "$SKILLS_DIR" ]; then
  if [ -n "${PI_SKILLS_DIR:-}" ]; then
    SKILLS_DIR="$PI_SKILLS_DIR"
  elif [ -d "$SELF/../skills" ]; then
    SKILLS_DIR="$(cd "$SELF/../skills" && pwd)"
  elif [ -d "$HOME/.pi/agent/skills" ]; then
    SKILLS_DIR="$HOME/.pi/agent/skills"
  elif [ -d "$HOME/.agents/skills" ]; then
    SKILLS_DIR="$HOME/.agents/skills"
  fi
fi
[ -n "$SKILLS_DIR" ] && [ -d "$SKILLS_DIR" ] || {
  echo "skill-eval: could not locate skills dir (tried --skills-dir, \$PI_SKILLS_DIR, $SELF/../skills, ~/.pi/agent/skills, ~/.agents/skills)" >&2
  exit 2
}

# ── color ─────────────────────────────────────────────────────────────────────
if [ "$USE_COLOR" = "1" ]; then
  C_G=$'\033[32m'; C_R=$'\033[31m'; C_Y=$'\033[33m'; C_B=$'\033[36m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_0=$'\033[0m'
else
  C_G=''; C_R=''; C_Y=''; C_B=''; C_DIM=''; C_BOLD=''; C_0=''
fi

# ── tallies ───────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; WARN=0
SKILLS_TOTAL=0; SKILLS_FAILED=0
declare -a FAILED_SKILLS=()

# Per-run human print helpers (skipped entirely in JSON mode).
hp()    { [ "$EMIT_JSON" = "1" ] && return 0; printf '%b' "$1"; }
pass()  { PASS=$((PASS+1)); [ "$QUIET" = "1" ] || hp "    ${C_G}PASS${C_0}  $1\n"; }
fail()  { FAIL=$((FAIL+1)); hp "    ${C_R}FAIL${C_0}  $1\n"; }
warn()  { WARN=$((WARN+1)); hp "    ${C_Y}WARN${C_0}  $1\n"; }
note()  { [ "$QUIET" = "1" ] || hp "    ${C_DIM}·     $1${C_0}\n"; }

# ── the python validator core ─────────────────────────────────────────────────
# All structural parsing happens in one python pass per skill (robust YAML/JSON,
# fenced-code awareness, link extraction). It prints a tab-separated stream of:
#   <LEVEL>\t<CODE>\t<message>
# where LEVEL ∈ {PASS,FAIL,WARN,NOTE,SKIPREF} and additionally a trailing
#   META\t<json>
# line carrying the per-skill summary for the --json aggregate. bash tallies +
# colorizes; python stays pure stdout so it's trivially testable in isolation.
validate_skill_py() {
  local skill_dir="$1" skill_name="$2"
  SKILL_DIR="$skill_dir" SKILL_NAME="$skill_name" python3 - <<'PY'
import os, re, sys, json

skill_dir  = os.environ["SKILL_DIR"]
skill_name = os.environ["SKILL_NAME"]
emit = []
def out(level, code, msg): emit.append(f"{level}\t{code}\t{msg}")

meta = {
    "skill": skill_name, "fail": 0, "warn": 0,
    "companion_refs_ok": [], "companion_refs_bad": [],
    "skipped_refs": [], "tools": [], "evals": None,
}
def F(code, msg): meta["fail"]+=1; out("FAIL", code, msg)
def W(code, msg): meta["warn"]+=1; out("WARN", code, msg)
def P(code, msg): out("PASS", code, msg)

skill_md = os.path.join(skill_dir, "SKILL.md")

# ── FM1: SKILL.md exists + non-empty ──────────────────────────────────────────
if not os.path.isfile(skill_md):
    F("FM1", "SKILL.md missing")
    print("\n".join(emit)); print("META\t"+json.dumps(meta)); sys.exit(0)
raw = open(skill_md, encoding="utf-8", errors="replace").read()
if not raw.strip():
    F("FM1", "SKILL.md is empty")
    print("\n".join(emit)); print("META\t"+json.dumps(meta)); sys.exit(0)
P("FM1", "SKILL.md present + non-empty")

# ── FM2: well-formed frontmatter block ────────────────────────────────────────
# Must START with a line that is exactly '---' then a later line exactly '---'.
lines = raw.splitlines()
if not lines or lines[0].strip() != "---":
    F("FM2", "no frontmatter: file does not start with '---'")
    print("\n".join(emit)); print("META\t"+json.dumps(meta)); sys.exit(0)
end = None
for i in range(1, len(lines)):
    if lines[i].strip() == "---":
        end = i; break
if end is None:
    F("FM2", "frontmatter '---' never closed")
    print("\n".join(emit)); print("META\t"+json.dumps(meta)); sys.exit(0)
fm_text = "\n".join(lines[1:end])
body    = "\n".join(lines[end+1:])

# Parse frontmatter the way the skill loader does — TOLERANT scalar extraction,
# NOT strict YAML. This is deliberate and load-bearing: real SKILL.md frontmatter
# routinely contains values that are NOT valid standalone YAML but ARE valid skill
# frontmatter because the loader reads each `key:` value as a plain STRING, e.g.
#   description: ... Cost-budgeted: quick/standard/deep ...   (a 2nd ':' → YAML
#                                                              "mapping values not
#                                                              allowed here")
#   argument-hint: ["Client Name" "Project Name" amount]      (not valid flow-seq)
# A strict `yaml.safe_load` of the block FALSE-FAILS those skills even though they
# load + run fine in production. So we only FAIL on genuinely broken STRUCTURE.
#
# Grammar accepted:  KEY: VALUE  |  KEY: >  / KEY: |  (block scalar)  |  bare
#   `metadata:` then 2-space-indented children. KEY is [A-Za-z0-9_-]+ at column 0.
# A frontmatter is malformed ONLY if: it has ZERO parseable top-level keys, OR a
# non-blank, non-indented, non-`#comment` line at column 0 is NOT a `key:` line
# (that's broken structure the loader would choke on too).
parser = "tolerant"
fm = {}
fm_struct_errors = []
cur_key = None; block_indicator = None; block_lines = []
in_metadata = False

def _unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
        v = v[1:-1]
    return v.strip()

def flush_block():
    global cur_key, block_indicator, block_lines
    if cur_key is not None and block_indicator is not None:
        fm[cur_key] = "\n".join(block_lines).strip()
    cur_key = None; block_indicator = None; block_lines = []

KEY_RE = re.compile(r'^([A-Za-z0-9_-]+):[ \t]*(.*)$')
for fmline in fm_text.splitlines():
    stripped = fmline.strip()
    # block scalar continuation: indented or blank lines belong to the open block
    if block_indicator is not None:
        if stripped == "" or fmline.startswith((" ", "\t")):
            block_lines.append(stripped); continue
        flush_block()  # a column-0 non-blank line closes the block
    if stripped == "" or stripped.startswith("#"):
        continue
    indented = fmline.startswith((" ", "\t"))
    # nested metadata children (we don't assert on them, just don't misread them)
    if in_metadata and indented:
        continue
    if in_metadata and not indented:
        in_metadata = False
    m = KEY_RE.match(fmline)
    if not m:
        # a column-0 line that isn't `key:`-shaped → structurally broken frontmatter
        if not indented:
            fm_struct_errors.append(stripped[:60])
        continue
    k, v = m.group(1), m.group(2)
    if re.match(r'^metadata$', k) and v.strip() == "":
        in_metadata = True
        fm.setdefault("metadata", "")  # mark presence (children ignored)
        continue
    if v.strip() in (">", "|", ">-", "|-", ">+", "|+"):
        cur_key = k; block_indicator = v.strip(); block_lines = []
    else:
        fm[k] = _unquote(v)
flush_block()

if fm_struct_errors:
    F("FM2", f"malformed frontmatter line(s) (not 'key: value'): "
             f"{'; '.join(fm_struct_errors[:3])}")
    print("\n".join(emit)); print("META\t"+json.dumps(meta)); sys.exit(0)
if not fm:
    F("FM2", "frontmatter block has no parseable keys")
    print("\n".join(emit)); print("META\t"+json.dumps(meta)); sys.exit(0)
P("FM2", f"frontmatter parses ({parser}, {len(fm)} keys)")

# ── FM3: required keys ────────────────────────────────────────────────────────
for k in ("name", "description"):
    if k not in fm or fm.get(k) in (None, ""):
        F("FM3", f"required frontmatter key missing/empty: {k}")
if "name" in fm and "description" in fm and fm.get("name") and fm.get("description"):
    P("FM3", "required keys present (name, description)")

# ── FM4: name matches dir ─────────────────────────────────────────────────────
nm = (fm.get("name") or "").strip()
if nm and nm != skill_name:
    F("FM4", f"name '{nm}' != directory '{skill_name}'")
elif nm:
    P("FM4", f"name matches directory ('{skill_name}')")

# ── FM5: description quality ──────────────────────────────────────────────────
desc = (fm.get("description") or "").strip()
if desc and len(desc) < 20:
    W("FM5", f"description very short ({len(desc)} chars) — weak trigger surface")
elif desc:
    P("FM5", f"description ok ({len(desc)} chars)")

# ── FM6: recognized keys ──────────────────────────────────────────────────────
# Keys the pi skill loader recognizes (a superset of what pi-setup skills use:
# name, description, argument-hint, metadata, license).
KNOWN = {"name","description","argument-hint","allowed-tools","license",
         "metadata","user-invocable","model","disable-model-invocation"}
unknown = [k for k in fm.keys() if k not in KNOWN]
if unknown:
    W("FM6", f"unrecognized top-level frontmatter key(s): {', '.join(unknown)}")
else:
    P("FM6", "all frontmatter keys recognized")

# ── companion-file references (CF1/CF2) ───────────────────────────────────────
# Strip fenced code blocks from the BODY before extracting links (code fences
# hold examples / generated output, not live companion links).
def strip_fences(text):
    out_lines = []; in_fence = False; fence = None
    for ln in text.splitlines():
        s = ln.lstrip()
        if not in_fence and (s.startswith("```") or s.startswith("~~~")):
            in_fence = True; fence = s[:3]; continue
        if in_fence and s.startswith(fence):
            in_fence = False; fence = None; continue
        if not in_fence:
            out_lines.append(ln)
    return "\n".join(out_lines)

body_nf = strip_fences(body)

# ENFORCED non-`./` companion subdirs — restricted to the STRUCTURAL companion
# dirs that unambiguously hold skill companion files. Deliberately EXCLUDES docs/
# templates/ scripts/ assets/ data/ — those overwhelmingly appear as
# GENERATED-OUTPUT refs or external/runtime paths, and enforcing them yields false
# positives. A `./`-prefixed link to any of those IS still enforced (the `./` is
# an explicit "this is my companion" signal); bare `docs/...` falls through.
COMPANION_SUBDIRS = ("agents/","prompts/","rules/","evals/")
REAL_EXT = (".md",".json",".txt",".sh",".py",".yml",".yaml",".toml",".csv",
            ".png",".svg",".jpg",".jpeg",".webp")
link_re = re.compile(r'\[[^\]]*\]\(([^)]+)\)')

def is_companion_target(t):
    t = t.strip()
    if not t: return False
    if "://" in t: return False                  # URL
    if t.startswith(("#","mailto:","tel:")): return False
    if any(c in t for c in "$<>"): return False  # shell var / <placeholder>
    if t.startswith(("~","/")): return False     # absolute / home
    # ./-prefixed OR a recognized companion subdir
    rel = t[2:] if t.startswith("./") else t
    if t.startswith("./") or any(rel.startswith(p) or t.startswith(p) for p in COMPANION_SUBDIRS):
        # must look like a real file (has a known extension), strip #anchor/query
        base = rel.split("#",1)[0].split("?",1)[0]
        if any(base.lower().endswith(e) for e in REAL_EXT):
            return True
    return False

seen_targets = set()
cf_checked = 0
for m in link_re.finditer(body_nf):
    target = m.group(1).strip()
    # markdown allows "(path 'title')" — drop a trailing quoted title
    target = re.sub(r'\s+["\'].*["\']$', '', target).strip()
    norm = target[2:] if target.startswith("./") else target
    norm = norm.split("#",1)[0].split("?",1)[0]
    if is_companion_target(target):
        if norm in seen_targets: continue
        seen_targets.add(norm)
        cf_checked += 1
        fp = os.path.join(skill_dir, norm)
        if os.path.exists(fp):
            meta["companion_refs_ok"].append(norm)
        else:
            meta["companion_refs_bad"].append(norm)
            F("CF1", f"dangling companion ref: {norm} (referenced in SKILL.md, not on disk)")
    else:
        # record non-enforced refs that *look* file-ish for transparency
        nb = norm.split("#",1)[0]
        if any(nb.lower().endswith(e) for e in REAL_EXT) and "://" not in target:
            meta["skipped_refs"].append(target)

if cf_checked and not meta["companion_refs_bad"]:
    P("CF1", f"all {cf_checked} companion ref(s) resolve")
elif cf_checked == 0:
    out("NOTE","CF1","no enforced companion refs (skill is self-contained or uses templated/external refs)")

# CF2: subdir-template refs like `agents/<name>.md` or `rules/<slug>.md` imply the
# named subdir must exist + be non-empty IN THE SKILL DIR. The hard part is NOT
# false-positiving on EXTERNAL / RUNTIME paths that merely CONTAIN one of these
# segment names. Rule: a subdir ref counts ONLY when the subdir token sits at a
# CLEAN left boundary — the immediately preceding char is start-of-string or one
# of whitespace / ` / ( / quote — i.e. it is NOT preceded by '.', '/', '~', or a
# word char. We scan the body WITH fences left in, because the canonical "how to
# access" pattern is often shown inside a code fence.
subdir_re = re.compile(
    r'(?P<pre>^|[\s`("\'])'
    r'(?P<sd>(?:agents|prompts|rules|evals|templates))/'
    r'[A-Za-z0-9_.<>-]'           # at least one path char after the slash
)
referenced_subdirs = set()
for m in subdir_re.finditer(body):
    referenced_subdirs.add(m.group("sd"))
for sd in sorted(referenced_subdirs):
    p = os.path.join(skill_dir, sd)
    if os.path.isdir(p) and any(os.scandir(p)):
        P("CF2", f"referenced subdir '{sd}/' exists + non-empty")
    elif os.path.isdir(p):
        W("CF2", f"referenced subdir '{sd}/' exists but is EMPTY")
    else:
        F("CF2", f"referenced subdir '{sd}/' does not exist (SKILL.md points into it)")

# ── allowed-tools (TL1) ───────────────────────────────────────────────────────
# pi exposes a small built-in tool set (read/bash/edit/write/grep/find/ls + skill
# invocation). pi-setup skills currently declare NO `allowed-tools` (they inherit
# the default set), so this almost always no-ops. If a skill DOES declare them, we
# validate each entry against pi's known tools and WARN (not FAIL) on an unknown
# token — it could be a future tool, and a wrong allowlist entry only narrows a
# skill's tools, it doesn't break the loader.
PI_TOOLS = {"read","bash","edit","write","grep","find","ls","skill"}
at = fm.get("allowed-tools")
if at is not None:
    if isinstance(at, str):
        toks = [t.strip() for t in at.split(",") if t.strip()]
    elif isinstance(at, list):
        toks = [str(t).strip() for t in at if str(t).strip()]
    else:
        toks = []
    meta["tools"] = toks
    unknownb = [t for t in toks if t.lower() not in PI_TOOLS]
    if unknownb:
        W("TL1", f"unrecognized tool name(s) for pi (known: {', '.join(sorted(PI_TOOLS))}): {', '.join(unknownb)}")
    elif toks:
        P("TL1", f"all {len(toks)} allowed-tools entries are known pi tools")
else:
    out("NOTE","TL1","no allowed-tools (skill inherits default tool set)")

# ── evals (EV1-EV4) ───────────────────────────────────────────────────────────
evals_path = os.path.join(skill_dir, "evals", "evals.json")
if os.path.isfile(evals_path):
    try:
        ev = json.load(open(evals_path, encoding="utf-8"))
    except Exception as e:
        F("EV1", f"evals/evals.json is not valid JSON: {e}")
        ev = None
    if ev is not None:
        P("EV1", "evals/evals.json parses as JSON")
        meta["evals"] = {"path": "evals/evals.json", "count": 0, "kind": "unknown"}
        sn = ev.get("skill_name")
        arr = ev.get("evals")
        if sn != skill_name:
            F("EV2", f"evals.json skill_name '{sn}' != '{skill_name}'")
        if not isinstance(arr, list) or len(arr) == 0:
            F("EV2", "evals.json has no non-empty 'evals' array")
        else:
            meta["evals"]["count"] = len(arr)
            P("EV2", f"evals.json well-formed (skill_name ok, {len(arr)} eval cases)")
            # detect kind: judgment (assertions/expected_output) vs runnable (checks)
            runnable = sum(1 for e in arr if isinstance(e, dict) and "checks" in e)
            meta["evals"]["kind"] = "runnable" if runnable == len(arr) else (
                                    "mixed" if runnable else "judgment")
            bad_cases = 0
            for idx, e in enumerate(arr):
                if not isinstance(e, dict):
                    F("EV3", f"eval[{idx}] is not an object"); bad_cases+=1; continue
                if "id" not in e:
                    F("EV3", f"eval[{idx}] missing 'id'"); bad_cases+=1
                if not e.get("prompt") and "checks" not in e:
                    F("EV3", f"eval id={e.get('id',idx)} missing 'prompt'"); bad_cases+=1
                has_judge = bool(e.get("assertions")) or bool(e.get("expected_output"))
                has_checks = isinstance(e.get("checks"), list) and len(e["checks"])>0
                if not has_judge and not has_checks:
                    F("EV3", f"eval id={e.get('id',idx)} has neither assertions/expected_output nor checks")
                    bad_cases+=1
                # EV4: validate runnable checks shape
                if isinstance(e.get("checks"), list):
                    for ci, c in enumerate(e["checks"]):
                        if not isinstance(c, dict) or "type" not in c:
                            F("EV4", f"eval id={e.get('id',idx)} check[{ci}] malformed (need object with 'type')")
                            bad_cases+=1
            if bad_cases == 0:
                P("EV3", f"all {len(arr)} eval cases structurally valid ({meta['evals']['kind']})")
else:
    out("NOTE","EV","no evals/evals.json (optional — add one to enable eval validation)")

print("\n".join(emit))
print("META\t"+json.dumps(meta))
PY
}

# ── per-skill driver: run python, tally levels, colorize, capture META ────────
declare -a JSON_SKILLS=()
process_skill() {
  local dir="$1" name; name="$(basename "$dir")"
  SKILLS_TOTAL=$((SKILLS_TOTAL+1))
  [ "$QUIET" = "1" ] || hp "\n  ${C_BOLD}${C_B}▸ ${name}${C_0}\n"

  local raw meta_json="" sk_fail=0
  raw="$(validate_skill_py "$dir" "$name")"
  # stream lines → tally + print; pluck the META line for JSON aggregate.
  while IFS=$'\t' read -r level code msg; do
    case "$level" in
      PASS)    pass "[$code] $msg" ;;
      FAIL)    fail "[$code] $msg"; sk_fail=$((sk_fail+1)) ;;
      WARN)    warn "[$code] $msg" ;;
      NOTE)    note "[$code] $msg" ;;
      SKIPREF) note "[$code] skipped non-companion ref: $msg" ;;
      META)    : ;;  # handled below via awk
    esac
  done <<< "$raw"
  meta_json="$(printf '%s\n' "$raw" | awk -F'\t' '$1=="META"{print $2}')"

  if [ "$sk_fail" -gt 0 ]; then
    SKILLS_FAILED=$((SKILLS_FAILED+1)); FAILED_SKILLS+=("$name")
    [ "$QUIET" = "1" ] && [ "$EMIT_JSON" = "0" ] && hp "  ${C_R}✗ ${name}: ${sk_fail} FAIL${C_0}\n"
  fi
  [ -n "$meta_json" ] && JSON_SKILLS+=("$meta_json")
}

# ── discover skills ───────────────────────────────────────────────────────────
declare -a DIRS=()
if [ "${#ONLY[@]}" -gt 0 ]; then
  for s in "${ONLY[@]}"; do
    if [ -d "$SKILLS_DIR/$s" ]; then DIRS+=("$SKILLS_DIR/$s")
    else echo "skill-eval: no such skill '$s' under $SKILLS_DIR" >&2; exit 2; fi
  done
else
  # `-L` (follow symlinks): if the live install path is itself a SYMLINK to the
  # repo's skills dir, plain `find <symlink> -type d` does NOT descend into it,
  # which would silently yield ZERO skills (a dangerous false-OK for a gate).
  while IFS= read -r d; do DIRS+=("$d"); done < <(find -L "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
fi

# A regression harness must NEVER report "all pass" while validating nothing.
if [ "${#DIRS[@]}" -eq 0 ]; then
  echo "skill-eval: no skills found under $SKILLS_DIR (is it the right dir?)" >&2
  exit 2
fi

if [ "$LIST_ONLY" = "1" ]; then
  for d in "${DIRS[@]}"; do
    n="$(basename "$d")"
    kind="leaf"; { [ -d "$d/agents" ] || [ -d "$d/prompts" ] || [ -d "$d/rules" ]; } && kind="hub"
    ev=""; [ -f "$d/evals/evals.json" ] && ev=" +evals"
    printf '  %-28s %s%s\n' "$n" "$kind" "$ev"
  done
  exit 0
fi

# ── header ────────────────────────────────────────────────────────────────────
[ "$EMIT_JSON" = "1" ] || hp "${C_BOLD}skill-eval${C_0} — structural validation of ${#DIRS[@]} skill(s)\n${C_DIM}  dir: $SKILLS_DIR${C_0}\n"

for d in "${DIRS[@]}"; do process_skill "$d"; done

# ── JSON aggregate ────────────────────────────────────────────────────────────
if [ "$EMIT_JSON" = "1" ]; then
  printf '{\n  "skills_dir": %s,\n' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$SKILLS_DIR")"
  printf '  "totals": {"skills": %d, "skills_failed": %d, "pass": %d, "fail": %d, "warn": %d},\n' \
         "$SKILLS_TOTAL" "$SKILLS_FAILED" "$PASS" "$FAIL" "$WARN"
  printf '  "skills": [\n'
  for i in "${!JSON_SKILLS[@]}"; do
    sep=","; [ "$i" -eq $(( ${#JSON_SKILLS[@]} - 1 )) ] && sep=""
    printf '    %s%s\n' "${JSON_SKILLS[$i]}" "$sep"
  done
  printf '  ]\n}\n'
fi

# ── verdict ───────────────────────────────────────────────────────────────────
if [ "$EMIT_JSON" = "0" ]; then
  hp "\n${C_BOLD}── verdict ──${C_0}\n"
  hp "  skills: ${SKILLS_TOTAL}   failed: ${SKILLS_FAILED}\n"
  hp "  checks: ${C_G}${PASS} pass${C_0}  ${C_R}${FAIL} fail${C_0}  ${C_Y}${WARN} warn${C_0}\n"
  if [ "${#FAILED_SKILLS[@]}" -gt 0 ]; then
    hp "  ${C_R}FAILED:${C_0} ${FAILED_SKILLS[*]}\n"
  fi
  if [ "$FAIL" -eq 0 ] && { [ "$STRICT" = "0" ] || [ "$WARN" -eq 0 ]; }; then
    hp "  ${C_G}${C_BOLD}OK${C_0} — all structural checks passed.\n"
  elif [ "$FAIL" -eq 0 ]; then
    hp "  ${C_Y}${C_BOLD}STRICT FAIL${C_0} — structural checks passed but WARN present (--strict).\n"
  else
    hp "  ${C_R}${C_BOLD}BREAK${C_0} — ${FAIL} structural failure(s) across ${SKILLS_FAILED} skill(s).\n"
  fi
fi

# exit
if [ "$FAIL" -gt 0 ]; then exit 1; fi
if [ "$STRICT" = "1" ] && [ "$WARN" -gt 0 ]; then exit 1; fi
exit 0
