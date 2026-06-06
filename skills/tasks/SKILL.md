---
name: tasks
description: Manage the task tracking system — create, update, and review project tasks across all tracked projects. Use when the user asks about tasks, status, project tracking, or says /tasks.
---

# Task Management System

Track project tasks using a simple markdown-based system inspired by personal kanban.

## Task File Location

Live task files: `~/.claude/tasks/` (per-machine, not in dotfiles repo)
Template: `chilldawg-setup/claude/tasks/TEMPLATE.md`

## Task File Format

```markdown
---
project: {Project Name}
description: {one-line description}
status: {active|planning|paused|done}
deadline: {YYYY-MM-DD or empty}
---

## NOW
- [ ] {current priority task} `{date added}`

## NEXT
- [ ] {what comes after NOW} `{date added}`

## LATER
- [ ] {known but deferred} `{date added}`

## WAITING
- [ ] {blocked on someone/something} — waiting on: {who/what} `{date added}`

## Completed
- [x] {done task} `{date completed}`
```

## Dashboard (INDEX.md)

```markdown
# Task Dashboard

| Project | Status | NOW | NEXT | WAITING | Next Action |
|---------|--------|-----|------|---------|-------------|
| {name} | active | 1 | 2 | 0 | {one-line next action} |

## This Week
1. {top priority}
2. {second priority}
3. {third priority}
```

## Commands

### `/tasks` — Show dashboard
Read `INDEX.md` and display the dashboard table + this week's priorities.

### `/tasks add <project>` — Add a project
Create a new task file from TEMPLATE.md, add to INDEX.md

### `/tasks <project>` — Show project tasks
Display the full task file for a specific project.

### `/tasks now <project> <task>` — Add to NOW
Add a task to the NOW section of a project.

### `/tasks next <project> <task>` — Add to NEXT
Add a task to the NEXT section.

### `/tasks done <project> <task #>` — Mark as done
Move a task from NOW/NEXT to Completed.

### `/tasks waiting <project> <task> — waiting on: <who>` — Mark as waiting
Move a task to WAITING section.

## Rules

- Task files are LIVE data — per-machine, not in dotfiles repo
- The repo's `claude/tasks/` contains TEMPLATES and SKELETONS only
- Update `INDEX.md` when adding or changing project status
- Never commit live task data to the dotfiles repo
- Move tasks through: LATER → NEXT → NOW → Completed
- Keep NOW limited to 3-5 items max per project
