---
name: remindme
description: Set reminders for future follow-up. Use when the user wants to be reminded about something, set a todo with a deadline, or schedule a future check-in.
---

# Remindme — Scheduled Reminders

Set reminders that surface at a specified time.

## Usage

```
/remindme <what> in <time>     — e.g. "/remindme check deploy logs in 2 hours"
/remindme <what> at <time>     — e.g. "/remindme standup notes at 3pm"
/remindme <what> tomorrow      — e.g. "/remindme follow up with client tomorrow"
```

## Implementation

1. Parse the reminder text and time from arguments
2. Store the reminder in `~/.claude/reminders.md`:
```markdown
| ID | Reminder | Created | Due | Status |
|----|----------|---------|-----|--------|
| 1 | Check deploy logs | 2026-01-15 14:00 | 2026-01-15 16:00 | pending |
```

3. Write to a simple markdown table format that's easy to read
4. Confirm to user: "Reminder set: [what] at [when]"

## Checking Reminders

When asked "what are my reminders" or "check reminders":
1. Read `~/.claude/reminders.md`
2. Show pending reminders sorted by due date
3. Highlight overdue reminders in bold

## Completing Reminders

When user says "done with [reminder]" or "mark reminder #N as done":
1. Update the status in reminders.md from `pending` to `done`

## Rules
- Store in `~/.claude/reminders.md` (simple markdown table)
- Parse natural language time expressions: "in 2 hours", "tomorrow 9am", "next Monday", "at 3pm"
- Always confirm the parsed time with the user before storing
- Delete reminders older than 30 days (done status)
