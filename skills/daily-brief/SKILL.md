---
name: daily-brief
description: Generate a morning daily brief summarizing yesterday's activity, today's priorities, open blockers, and reminders. Use when user says "daily brief", "morning briefing", or starts a new day.
---

# Daily Brief Generator

Generate a concise morning briefing summarizing where things stand.

## What to Include

### 1. Yesterday's Activity
Read the journal (`~/.claude/journal.md`) for yesterday's entries. Summarize in 2-3 bullet points.

### 2. Today's Priorities
Check:
- Open tasks from `~/.claude/tasks/` (projects with `status: active`)
- The NOW/NEXT columns for each active project
- Any deadlines approaching (within 3 days)

List top 3 priorities for today.

### 3. Open Blockers
Check all project task files for `WAITING` items. List anything that's blocked and who/what it's waiting on.

### 4. Active Reminders
Read `~/.claude/reminders.md` for any reminders due today.

### 5. Git Activity
Check git status in common project directories for uncommitted work.

### 6. Health Check
- Any failing CI from yesterday?
- Any security advisories or deprecation notices?
- Any servers/services that need attention?

## Output Format

```markdown
# ☀️ Daily Brief — {YYYY-MM-DD}

## Yesterday
- [activity summary from journal]

## Today's Priorities
1. **[Top priority]** — {context}
2. **[Second priority]** — {context}
3. **[Third priority]** — {context}

## Blockers
{List or "None — all clear"}

## Reminders
{List or "None due today"}

## Status
- Git: {clean/dirty in which repos}
- CI: {passing/failing/unknown}
- Deployments: {any active deployments}

---
*Generated at {time}*
```

## Rules

- Keep it brief — this is a scan, not a deep dive
- Be honest about blockers and risks
- If no data exists (fresh install, no journal), say so and suggest setting up
- Run at the start of each day's first session automatically
