---
name: journal
description: Maintain a chronological activity journal. Use after every meaningful action — log what was done, decisions made, and context for future reference.
---

# Journal — Activity Log

Keep a running journal of all meaningful activity. This creates a searchable timeline of what happened when.

## Journal File

- **Location**: `~/.claude/journal.md`
- **Format**: Chronological, newest entry at top
- **One line per entry** in the log section

## Entry Format

```markdown
## YYYY-MM-DD

- **HH:MM** — [Category] — <what happened, 1 line max>
```

Categories: `TASK`, `DECISION`, `DEPLOY`, `COMMIT`, `NOTE`, `BLOCKER`, `CLIENT`

## When to Log

Log automatically after:
- Any significant code change committed
- Any deployment
- Any architectural decision made
- Any client interaction
- Any blocker discovered or resolved
- End of each working session (summary)

## Auto-Journal Triggers

After committing code: log the commit message and scope
After running `/preflight` or `/ship`: log the outcome
After any `git push`: log the branch and whether CI passed
After any discussion that results in a decision

## Rules

- Keep entries to ONE LINE maximum — be terse
- Never log routine operations (reading files, running `ls`, basic edits)
- Only log externally meaningful actions: commits, deploys, decisions, client comms
- The journal is chronological and append-only — never edit old entries, add a correction entry instead
- Include project context for cross-project clarity: `[project-name] — description`
