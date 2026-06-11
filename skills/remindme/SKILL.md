---
name: remindme
description: Schedule natural-language reminders. Supports one-shot + recurring schedules, list/cancel sub-commands, and a stored-reminder model. Use when the user says /remindme, "remind me to…", "nudge me…", or wants to schedule a reminder/alert/heads-up.
argument-hint: <natural language reminder | list | cancel <slug-or-id> | cancel all>
---

# /remindme — Reminder Scheduler

Turns a natural-language request into a stored, scheduled reminder.

> ## ⚠️ pi scheduling reality — READ FIRST (the load-bearing FLAG)
>
> chilldawg's remindme fired reminders **autonomously** via Claude-only tools
> (`CronCreate` / `CronList` / `CronDelete` for one-shot + recurring jobs,
> `ScheduleWakeup` for sub-minute test mode) and delivered them as **WhatsApp
> DMs**. **pi has NONE of that infrastructure:**
>
> - **No `CronCreate` / `ScheduleWakeup`** — pi's tool set is `read`/`bash`/
>   `edit`/`write`/`grep`/`find`/`ls` + Playwright MCP. There is no in-agent
>   scheduler that can wake pi at a future time.
> - **No systemd / wa-sender queue** — pi runs on **Windows** (no systemd timers,
>   no `reminder-check` service, no wa-sender daemon).
> - **WhatsApp → Telegram** — pi's comms channel is Telegram, not WhatsApp.
>
> **What this means:** until a host-level scheduler is wired up, pi reminders are
> a **passive store**, not an autonomous fire. They are persisted to a markdown
> table and surfaced when the user (or the `daily-brief` skill) next asks. The
> natural-language parsing, slugging, and list/cancel logic below all work today;
> only the *autonomous fire-at-time* half is pending a pi decision.
>
> ### Two pi-decisions to make this fire unattended (FLAG for Toper)
> 1. **Scheduler:** wire **Windows Task Scheduler** (or `schtasks`) to invoke a
>    small pi run (or a plain script) at the reminder's due time, which then reads
>    the store and sends the due rows. This is the pi equivalent of CronCreate +
>    the systemd reminder-check service.
> 2. **Delivery:** a **Telegram Bot API** `sendMessage` curl via the `bash` tool
>    (`$TELEGRAM_BOT_TOKEN` + `$TELEGRAM_TOPER_CHAT_ID` in pi secrets) is the pi
>    equivalent of the WhatsApp send. See the `daily-brief` skill for the exact
>    curl shape.
>
> Do NOT ship instructions that call `CronCreate` / `ScheduleWakeup` /
> `mcp__plugin_whatsapp_whatsapp__send_message` — those tools do not exist in pi
> and would silently no-op. The store-based flow below is the truthful default.

## Store

- **File:** `~/.pi/agent/reminders.md` — a markdown table, one row per reminder.
- **Marker / id:** every reminder gets a short kebab-case `slug` derived from its
  content (e.g. `weekly-retro`, `call-bank`, `standup`) so `list` and `cancel`
  work by a stable label.
- **Timezone:** `Asia/Jakarta` (WIB = UTC+7) — store + display absolute due times
  in WIB. Anchor every relative time to the real clock (`date` in the `bash`
  tool); never hand-calculate dates.

Table shape:

```markdown
| slug | reminder | created (WIB) | due (WIB) | recurrence | status |
|------|----------|---------------|-----------|------------|--------|
| call-bank | call the bank | 2026-06-12 14:00 | 2026-06-12 16:00 | once | pending |
| weekly-retro | weekly retro | 2026-06-12 14:01 | 2026-06-16 06:58 | weekly Mon 06:58 | pending |
```

## Step 0: Parse the invocation

Read the argument and classify intent:

| If the argument… | Intent |
|---|---|
| starts with `list` | → **LIST** |
| starts with `cancel all` | → **CANCEL ALL** |
| starts with `cancel <x>` | → **CANCEL** one |
| anything else | → **CREATE** a reminder |
| empty | ask: "What should I remind you about, and when?" |

## Step 1 (CREATE): get the current clock

Always anchor to the real clock. Run via the `bash` tool:

```bash
TZ=Asia/Jakarta date '+now: %Y-%m-%d %H:%M:%S %Z (epoch %s, dow %u)'
```

Compute the absolute due time relative to this with `date -d` so you never
miscalculate a minute/hour/day/month rollover:

```bash
TZ=Asia/Jakarta date -d "+30 minutes" +"%Y-%m-%d %H:%M"   # "in 30 minutes"
TZ=Asia/Jakarta date -d "+2 hours"    +"%Y-%m-%d %H:%M"    # "in 2 hours"
TZ=Asia/Jakarta date -d "tomorrow 09:00" +"%Y-%m-%d %H:%M" # "tomorrow at 9am"
TZ=Asia/Jakarta date -d "2026-05-30 12:00" +"%Y-%m-%d %H:%M" # pinned date
```

> Note: `date -d` natural-language parsing is a GNU coreutils feature. On Windows
> this runs under **Git Bash** (which ships GNU `date`), so the calls above work.
> If a leaner environment lacks GNU `date`, fall back to explicit arithmetic.

### Early-nudge rule (when the user names a clock time)

A reminder that arrives late is useless. When the user gives an approximate clock
time, set the due minute **1–2 minutes early** (e.g. "9am" → `08:58`, "noon" →
`11:58`). Land on `:00`/`:30` exactly only if the user says "sharp"/"exactly" or
is coordinating with a specific meeting time.

## Step 2 (CREATE): determine recurrence

- **once** — "in 30 minutes", "tomorrow at 9am", "on May 30 at noon". Store one
  absolute `due` time, `recurrence = once`.
- **recurring** — "every day at 7am", "every Monday at 7am", "every weekday at
  9am", "every hour", "every 15 minutes". Store the first `due` time + a
  human-readable `recurrence` rule (and, once a scheduler is wired, encode it as a
  Windows Task Scheduler trigger or cron expression — see the quick-reference
  appendix). On each fire the scheduler recomputes the next `due`.

### Recurrence quick-reference (target schedule expressions, WIB)

For when a real scheduler is wired (cron-style, 5-field `M H DOM MON DOW`):

| Request | expression | recurrence label |
|---|---|---|
| every day at 7am | `58 6 * * *` | daily 06:58 |
| every Monday at 7am | `58 6 * * 1` | weekly Mon 06:58 |
| every weekday at 9am | `58 8 * * 1-5` | weekdays 08:58 |
| every Sat & Sun at 10am | `58 9 * * 0,6` | weekends 09:58 |
| every hour | `37 * * * *` | hourly :37 |
| every 15 minutes | `*/15 * * * *` | every 15m |

(day-of-week: `0`/`7` = Sunday, `1` = Monday … `6` = Saturday.)

## Step 3 (CREATE): write the row + confirm

1. Append a row to `~/.pi/agent/reminders.md` (create the file with the header if
   missing) via the `bash`/`edit` tools, with: `slug`, `reminder` (verbatim
   content), `created`, `due` (absolute WIB), `recurrence`, `status=pending`.
2. Confirm to the user in-session:

```
✅ Reminder stored — <slug>
   Topic:      <content>
   Due:        <absolute WIB datetime>  (<human schedule>)
   Recurrence: once | <rule>
   Delivery:   stored — surfaces on next /remindme list or daily-brief
               (autonomous fire pending a pi scheduler — see skill flag)
   Cancel:     /remindme cancel <slug>
```

> Be honest: do NOT tell the user it will "fire" or "ping" them at the due time
> unless a scheduler + Telegram delivery has actually been wired on this host.
> Until then it is a stored reminder surfaced on demand.

## The fire path (once a scheduler exists)

When Windows Task Scheduler (or equivalent) invokes the fire routine at a due
time, it should: read `~/.pi/agent/reminders.md` → select `pending` rows whose
`due` ≤ now (WIB) → for each, send the body to Toper via the Telegram Bot API
(`bash` + curl, token + chat id from pi secrets) → mark `once` rows `status=done`
and recompute the next `due` for `recurring` rows. Reminder body:

```
⏰ REMINDER

Topic: <content>
Scheduled: <human schedule>
```

Verify each Telegram `sendMessage` returned `ok:true`; retry once on failure and
surface the error rather than silently dropping the reminder. Never double-send
(only the fire routine sends; creation never sends).

## Sub-command: list

Read `~/.pi/agent/reminders.md`, show all `pending` reminders sorted by `due`,
bold any whose `due` is in the past (overdue). For each: slug, reminder, due
(WIB), recurrence. If none: "No scheduled reminders." Always note: *"(pi surfaces
reminders on demand; autonomous fire needs a scheduler — see skill flag.)"*

## Sub-command: cancel <slug-or-id>

1. Match the argument against the `slug` column.
2. Set matching row(s) `status=cancelled` (or remove the row). Confirm.
3. If no match: list the available reminder slugs so the user can retry.

## Sub-command: cancel all

Set every `pending` row to `status=cancelled` (or clear them). Report the count.

## Edge cases & rules

- **Ambiguous time** ("later", "soon", "this evening" with no hour) → ask for a concrete time rather than guessing.
- **Past time** ("at 5am" when it's already 05:40) → assume the next occurrence (tomorrow) and say so in the confirmation.
- **Empty content** → ask what to be reminded about.
- **Store path** is `~/.pi/agent/reminders.md` (markdown table).
- **Convert relative dates to absolute** on write — "tomorrow" → a concrete `YYYY-MM-DD HH:MM` WIB.
- **Garbage-collect** `done`/`cancelled` rows older than 30 days on any write.
- **Stay honest about the fire gap** — a stored reminder is not an autonomous one. Never imply it will ping at the due time unless the scheduler + Telegram path is actually configured on this host.
