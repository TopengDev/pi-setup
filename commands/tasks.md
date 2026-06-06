# /tasks — Task Tracking System

Manage project tasks using a simple markdown-based system inspired by personal kanban.

## Task File Location

Live task files: `~/.opencode/tasks/` (per-machine, not in any repo)
Template: `templates/TASK_TEMPLATE.md`

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

### Show dashboard
Read `INDEX.md` and display the dashboard table + this week's priorities.

### Add a project
Create a new task file from template, add to INDEX.md

### Show project tasks
Display the full task file for a specific project.

### Add to NOW
Add a task to the NOW section of a project.

### Add to NEXT
Add a task to the NEXT section.

### Mark as done
Move a task from NOW/NEXT to Completed.

### Mark as waiting
Move a task to WAITING section, note who/what is blocking.

## Rules

- Task files are LIVE data — per-machine, not in any git repo
- Keep NOW limited to 3-5 items max per project
- Move tasks through: LATER → NEXT → NOW → Completed
- Update INDEX.md when adding or changing project status
