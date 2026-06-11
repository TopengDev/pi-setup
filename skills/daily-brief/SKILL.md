---
name: daily-brief
description: Generate a structured daily brief (morning or evening) from tasks, work-queue, and calendar, then deliver it to Toper. Invoked as "/daily-brief morning" or "/daily-brief evening" (optionally with "--dry-run").
argument-hint: morning|evening [--dry-run]
---

# Daily Brief — morning + evening notification

One-shot skill. Reads tasks + work-queue + calendar, formats a brief, delivers it
to Christopher, exits. Run manually, or from a scheduler if one is wired up.

**Timezone:** `Asia/Jakarta` (WIB = UTC+7) — do all time math in WIB.

> ## pi adaptation flags (read before relying on auto-delivery)
>
> chilldawg ran this on Linux with infra pi does not yet have. Three things need
> a pi decision before the **send** half works unattended. The **generate +
> print** half works fully today with pi's `read`/`glob`/`bash` tools.
>
> 1. **Delivery channel — WhatsApp → Telegram (FLAG).** chilldawg sent the brief
>    as a WhatsApp DM via a WhatsApp MCP to a fixed Toper JID. pi's comms channel
>    is **Telegram**, and pi's default tool set (`read`/`bash`/`edit`/`write`/
>    `grep`/`find`/`ls` + Playwright MCP) has **no Telegram send tool**. Until a
>    Telegram delivery path is wired (a Telegram bot `sendMessage` curl via the
>    `bash` tool with a bot token + chat id, or a Telegram MCP), this skill
>    **generates + prints** the brief; it cannot auto-send. Decide the Telegram
>    path, then fill in Step 5.
> 2. **Scheduling — systemd timers → Windows (FLAG).** chilldawg fired this at
>    06:00 + 21:00 WIB via systemd `--user` timers. pi runs on **Windows (no
>    systemd)**. Use **Windows Task Scheduler** (or run it manually) once the
>    delivery path exists. This is a known memory/automation follow-up wave.
> 3. **Calendar — Google Calendar MCP (FLAG).** chilldawg queried a
>    `Google Calendar` MCP. pi has no calendar MCP in its default tool set. If no
>    calendar source is available, **skip the calendar sections gracefully** and
>    note it in the brief (the tasks + work-queue halves still produce a useful
>    brief).
>
> Default behavior on pi today: run the full pipeline EXCEPT the send, and print
> the formatted message (same as `--dry-run`). Wire Step 5 + a scheduler to make
> it unattended.

## Argument parsing

The argument will be `morning`, `evening`, `morning --dry-run`, or `evening --dry-run`.

- `mode` = first word (`morning` or `evening`). If missing or unrecognized → abort with error message.
- `dry_run` = true if `--dry-run` appears anywhere in args, OR env var `DAILY_BRIEF_DRY_RUN=1`, **OR no Telegram delivery path is configured yet** (see flag 1 — print instead of send).

In dry-run mode: run the full pipeline EXCEPT the delivery send. Instead print the final formatted message to stdout under a banner `=== DRY RUN (not sent) ===`.

## Step 1 — idempotency lock

Lock file path: `~/.local/share/daily-brief/last-run-{mode}` (mode = morning or evening).
It contains a single line: `YYYY-MM-DD HH:MM` in WIB.

Use the `bash` tool to check:

```bash
NOW_WIB=$(TZ=Asia/Jakarta date +"%Y-%m-%d %H:%M")
LOCK=~/.local/share/daily-brief/last-run-MODE
if [ -f "$LOCK" ] && [ "$(cat "$LOCK")" = "$NOW_WIB" ]; then
  echo "[daily-brief] already ran this minute ($NOW_WIB), skipping"
  exit 0
fi
```

Replace `MODE` with the actual mode. Only write the lock file AFTER a successful send (or after a successful dry-run print). Never write the lock on error paths.

## Step 2 — read tasks

Glob `~/.pi/agent/tasks/*.md` (exclude `INDEX.md` and `archive/`). For each task file:

- Read the frontmatter `project:` name (falls back to filename).
- Parse the `## NOW`, `## NEXT`, `## WAITING`, `## Completed` sections.
- Task line format: `- [ ] description [...] \`YYYY-MM-DD\`` (backtick-wrapped date at end, optional).
- **For morning brief:**
  - `tasks_due_today` = open `[ ]` items whose backtick date == today (WIB) OR items in `## NOW` tier with no date.
  - `now_count` = total open `[ ]` items under `## NOW` across all projects.
  - `waiting` = items under `## WAITING` — extract "who" from phrasing like "waiting on X" / "need X from Y" / "blocked by Z".
- **For evening brief:** tasks are not included (evening brief is events-only per format spec).

Skip `## Completed` items entirely.

## Step 2.5 — read work-queue (delegated workers + paused threads)

Read `~/.pi/agent/state/work-queue.md` (if your install keeps the work-queue under
the main session notes dir instead, read it there). Parse the markdown tables
under these section headers:

- `## In-flight (worker actively running)` → `inflight` list — capture `Name`, `State`, `Last update`
- `## Paused — awaiting Toper decision` → `paused_decision` list — capture `Name`, `What's needed`
- `## Paused — awaiting external (push, deploy, third-party)` → `paused_external` list — capture `Name`, `What's blocking`

Skip `## Backlog` and `## Recently shipped` — those don't surface in the brief.

For each table:
- Skip the header row + separator row.
- Skip rows whose first cell is `_(none)_`, empty, or only whitespace.
- Truncate long values to ~60 chars with `…` so single-line bullets stay scannable on phone.

Counts: `inflight_n`, `paused_decision_n`, `paused_external_n`. Total `open_threads_n = inflight_n + paused_decision_n + paused_external_n`.

If the work-queue file is missing → set all three lists to empty + `open_threads_n=0`, continue silently (no error nag in the brief). The skill must not crash on a missing work-queue.

This section's labels use a casual Bahasa standup voice. The format applies to BOTH morning and evening flows.

## Step 3 — query calendar (graceful — see flag 3)

If a calendar source is available to pi (a calendar MCP, or an `.ics`/exported
file you can read), list events in the relevant window. If NO calendar source is
available, note `📅 calendar source not configured` once in the brief, skip the
calendar sections, and continue with tasks + work-queue.

### Time windows (all WIB)

- **Morning (intended run ~06:00 WIB):**
  - "TODAY" window: now → 21:00 WIB today
  - "NEXT 7 DAYS HIGHLIGHTS" window: 21:00 WIB today → 21:00 WIB (today + 7 days). Summarize as one event per day (the "top" event — prefer marked-important, longest, or earliest work-hours event).
- **Evening (intended run ~21:00 WIB):**
  - "LATE NIGHT" window: 22:00 WIB today → 23:59 WIB today
  - "EARLY MORNING" window: 00:00 WIB tomorrow → 06:00 WIB tomorrow

Dates should be formatted `DD MMM` (e.g. `15 Apr`) and weekdays as `Mon`, `Tue`, etc. Use WIB throughout.

## Step 4 — format message

### Morning template

```
🌅 *Good morning!* {Weekday}, {DD MMM}

📋 *TODAY* (until 9 PM)
{HH:MM} — {event title} ({calendar})
...
(or "✓ Clear — no events")

✅ *TASKS DUE TODAY* ({N})
• {task description}
...
(omit section if N=0)

📅 *NEXT 7 DAYS HIGHLIGHTS*
• {Weekday DD}: {top event}
...
(omit section if empty)

📌 *STILL OPEN*
• {N} NOW tasks across projects
• {N} waiting on others ({comma-separated names, max 3, then "+K more"})
(omit section if both zero)

📋 *OPEN THREADS* ({open_threads_n})
🔄 jalan ({inflight_n}):
• {name} — {state}
…
⏸️ nunggu lu ({paused_decision_n}):
• {name} — {what's needed}
…
⏳ nunggu eksternal ({paused_external_n}):
• {name} — {what's blocking}
…

_detail: work-queue.md_
(omit the entire 📋 section if open_threads_n == 0. Within it, omit any sub-section whose count is 0 — e.g. drop the 🔄 line + bullets if inflight_n == 0.)
```

### Evening template

```
🌙 *Tonight + early morning* {DD}-{DD+1} {MMM}

🌃 *LATE NIGHT* (10 PM – 12 AM)
• {HH:MM} — {event}
...
(omit section if empty; if BOTH sections empty, show "✓ Clear night")

🌌 *EARLY MORNING* (12 AM – 6 AM)
• {HH:MM} — {event}
...

📋 *OPEN THREADS* ({open_threads_n})
🔄 jalan ({inflight_n}):
• {name} — {state}
…
⏸️ nunggu lu ({paused_decision_n}):
• {name} — {what's needed}
…
⏳ nunggu eksternal ({paused_external_n}):
• {name} — {what's blocking}
…

_detail: work-queue.md_
(same omission rules as morning: drop the entire 📋 block if open_threads_n == 0; drop empty sub-sections.)

😴 sleep well — {summary line}
```

The `{summary line}` for evening: if both sections empty → `nothing scheduled, rest easy`; if only late night has events → `busy late night, early start clear`; if only early morning → `quiet tonight, early wake tomorrow`; if both → `busy stretch ahead, nap when you can`.

### Telegram formatting rules

- Telegram supports `*bold*` and `_italic_` in Markdown parse mode (set `parse_mode=Markdown` on the API call), or `<b>`/`<i>` in HTML parse mode. Pick one and be consistent.
- Bullet character: `• ` (Unicode bullet + space). NOT `- `.
- No markdown headers (`#`). Use `*BOLD*` + emoji for section headers as shown.
- Preserve blank lines between sections.
- Keep each event/task on one line (truncate long titles to ~80 chars with `…`).

## Step 5 — deliver (FLAG — wire the Telegram path)

If NOT dry-run AND a Telegram delivery path is configured:

Send the formatted message to Toper via Telegram. The simplest pi-native path is
a Telegram Bot API call through the `bash` tool:

```bash
# Requires a bot token + Toper's chat id (store in pi secrets, never inline):
#   $TELEGRAM_BOT_TOKEN, $TELEGRAM_TOPER_CHAT_ID
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_TOPER_CHAT_ID}" \
  --data-urlencode "parse_mode=Markdown" \
  --data-urlencode "text=${BRIEF_BODY}"
```

> Until `$TELEGRAM_BOT_TOKEN` + `$TELEGRAM_TOPER_CHAT_ID` exist in pi's secrets,
> treat the run as dry-run and PRINT the brief (see flag 1). Do NOT invent a
> chat id or token. Do NOT fall back to any other channel.

If dry-run (or no delivery path): print the formatted message between
`=== DRY RUN START ===` / `=== DRY RUN END ===` banners to stdout. Do NOT send.

## Step 6 — log + lock

Log file: `~/.local/share/daily-brief/log/{mode}-{YYYY-MM-DD}.log` (WIB date).

Append a line:
```
[YYYY-MM-DD HH:MM:SS WIB] {mode} brief — tasks_due={N} open_threads={open_threads_n} events_today={M} sent={yes|no|dry-run} calendar={configured|unavailable}
```

Then update the lock file to the current WIB minute (only on success / dry-run print).

## Error handling

- Missing tasks dir → treat as 0 tasks, continue.
- No calendar source → degrade gracefully, continue with tasks + work-queue.
- Delivery send error → log error, exit 1 (don't update lock).
- Unknown mode → print usage, exit 1.

## Never-do list

- Never read the messaging inbox or reply to messages — this skill is send-only.
- Never modify `~/.pi/agent/tasks/*.md` files — read-only.
- Never deliver to any recipient other than Toper's configured chat id.

## Done

After successful send (or dry-run print), print exactly:
```
DONE — {mode} brief sent to Toper at {HH:MM WIB}
```
(or `DONE — {mode} brief dry-run printed` in dry-run mode).
