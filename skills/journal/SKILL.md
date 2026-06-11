---
name: journal
description: Append a tagged, timestamped entry to the append-only activity journal so the memory-consolidation audit can later promote state-bearing facts to canonical memory. Use when something worth remembering happens (a decision, a preference/correction, a durable project fact, a reference) or when the user says /journal.
---

# /journal — capture an activity-log entry

Appends one entry to the **append-only** activity journal at
`~/.pi/agent/memory/journal.md`. A periodic audit later reads the un-audited
entries and **promotes** the state-bearing ones into canonical
`~/.pi/agent/memory/<type>_<slug>.md` files — so nothing worth keeping silently
drops between sessions. This is the *capture* half of that loop; the audit is
the *consolidate* half.

This is the lightweight, in-session counterpart to the `remember` skill:
`/journal` is a fast append you do continuously as things happen; the audit
does the careful classification + deduped promotion. Prefer `/journal`
mid-session; the audit upgrades the keepers automatically.

> **Scheduling flag (pi):** chilldawg ran the consolidation audit
> (`journal-audit.py`) on a daily **systemd timer** (~04:00 WIB). pi runs on
> **Windows** with **no systemd**. Until a scheduler is wired up (Windows Task
> Scheduler, or a manual `pi`-invoked run), treat the audit as **manual** — run
> it yourself when you want to consolidate, or ask Toper to schedule it. The
> *capture* half (this skill) works fully today; only the *automatic* promotion
> half is pending a pi scheduling decision. This is a known PW-wave follow-up
> (memory automation), not a bug in this skill.

## When to journal

Append an entry the moment any of these happen — don't wait to be asked:

- **decision** — a choice was made (direction, architecture, strategy, a "we'll do X not Y")
- **feedback** — Toper expressed a preference or correction about how the agent should work
- **project** — a durable fact about ongoing work: a goal, a constraint, a state change, a HEAD/commit, an env quirk
- **reference** — a pointer to a person, tool, resource, credential location, repo, endpoint
- **ephemeral** — transient status / chatter you want logged but the audit should NOT promote (it will skip these)

If it would be lost between sessions and is worth recalling later → journal it
(decision/feedback/project/reference). If it's just in-flight noise but you want
a breadcrumb → tag it `ephemeral`.

## How to use

Append the entry with a timestamp (Asia/Jakarta), a validated tag, and the
exact line format the audit parses. pi has no `journal-add.sh` helper script
ported yet — append directly with the `bash` tool:

```bash
JOURNAL=~/.pi/agent/memory/journal.md
TAG="decision"                 # decision | feedback | project | reference | ephemeral
SUMMARY="one-line summary"
DETAIL="optional longer detail"   # may be empty
TS="$(TZ=Asia/Jakarta date '+%Y-%m-%d %H:%M %Z')"
mkdir -p "$(dirname "$JOURNAL")"
{
  printf -- '- [%s] (%s) %s\n' "$TS" "$TAG" "$SUMMARY"
  [ -n "$DETAIL" ] && printf -- '  %s\n' "$DETAIL"
} >> "$JOURNAL"
echo "journaled [$TS] ($TAG) $SUMMARY"
```

> If/when a `journal-add.sh` helper is ported to pi, prefer it over the inline
> block above (it centralizes the tag-validation + timestamp + format). Until
> then, the block above is the source of truth for the entry format.

### Examples

```bash
# a decision
#   - [2026-06-12 14:03 WIB] (decision) Switched signal-trader to Strategy E (100% TP5 + BE-trail at TP3)

# feedback from Toper, with detail
#   - [2026-06-12 14:05 WIB] (feedback) Toper prefers hard-block over warn for git hooks
#       Came up while dropping the redundant tsc-check hook.

# a durable project fact
#   - [2026-06-12 14:08 WIB] (project) pi-setup at HEAD <sha>, pushed to origin/master, tree clean

# a reference pointer
#   - [2026-06-12 14:10 WIB] (reference) Pulse MinIO bucket = product-images on container aenoxa-pos-minio-1

# breadcrumb the audit should skip
#   - [2026-06-12 14:12 WIB] (ephemeral) Spawned worker; round-trip verified
```

## Rules

1. **One fact per entry.** Keep the summary to a single line; put nuance in the detail line.
2. **Pick the most specific tag.** decision/feedback/project/reference get promoted; ephemeral is skipped.
3. **Never hand-edit past entries** in journal.md — append only. The audit tracks a high-water timestamp; rewriting history breaks idempotency.
4. **Don't duplicate `remember`.** If Toper explicitly asks to "remember X" as a durable fact right now, the `remember` skill (write the memory file directly) is fine. Use `/journal` for the continuous, low-friction capture that the audit consolidates.
5. **Never put secrets in an entry** — reference where a credential lives (e.g. "$VAR in secrets.env"), never the value.

## Verify

After appending, re-read the tail of `~/.pi/agent/memory/journal.md` and confirm
the new line is present with the right tag + timestamp. The entry is now queued
for the next consolidation audit (manual on pi until a scheduler is wired up).
