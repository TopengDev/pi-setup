# Supervisor: <INITIATIVE NAME>

**Status:** STARTING
**Started:** <YYYY-MM-DD HH:MM WIB>
**Supervisor:** <supervisor-window-name>
**Parent initiative:** [<initiative-slug>](../initiatives/<initiative-slug>.md)
**Direction:** <one-line summary of the plan + how the work is partitioned — also reported to main as the direction-confirmation checkpoint BEFORE spawning any worker>

<!--
  This is a SUPERVISOR's orchestration ledger (Wave-7). It is your fleet's
  resumable source of truth: if you (the supervisor) are killed or hit the
  session limit, you re-read THIS first and re-attach to your fleet instead of
  re-spawning done/in-flight workers. Maintain it religiously.

  You are Opus + idle-cheap/event-driven: spawn the fleet, then WAIT on events
  (worker result.json, stalls, milestones, decisions). Report UP to main via attn
  only on meaningful checkpoints. NEVER DM the user. NEVER set WHATSAPP=1.
-->

## Plan / partition

<How the initiative is decomposed into independent worker-sized tasks. Sequencing
(what's parallel vs gated). This is what you report to main as your DIRECTION
before spawning anything.>

## Fleet roster

<!-- One row per worker you spawn. Keep status + last result.json current. -->

| worker (window) | task | model | status | last result.json |
|-----------------|------|-------|--------|------------------|
| <window>        | <…>  | sonnet| STARTING/IN_PROGRESS/DONE/BLOCKED | <path or —> |

## Orchestration checkpoints (idempotent, resumable)

<!--
  ORCHESTRATION-level checkpoints (NOT the workers' internal steps). Each is
  idempotent: "task X delegated", "task X verified done", "milestone Y reported".
  Mark `[x]` ONLY after you VERIFIED it (worker result.json says done AND you
  checked the evidence). A `[x]` is safe to skip on resume. The Resume cursor
  points at the next incomplete orchestration step.
-->

- [ ] OC1: <e.g. "partition + report DIRECTION to main"> — _verify:_ <attn sent + acked>
- [ ] OC2: <e.g. "spawn + brief worker for task A"> — _verify:_ <peer up + brief submitted>
- [ ] OC3: <e.g. "task A verified done"> — _verify:_ <result.json status=done + evidence checked>

**Resume cursor:** OC1 (next incomplete orchestration step)

## Resume protocol (supervisor variant)

<!--
  Followed on EVERY (re)start, especially after a kill / session limit:
  1. READ THIS LEDGER FIRST, before any tool calls.
  2. Re-attach to the fleet: for each roster worker, check its tmux window is
     alive + read its STATE.md/result.json. Do NOT re-spawn a worker that is
     already DONE or still IN_PROGRESS. Re-spawn/resume only DEAD-and-unfinished ones.
  3. Trust `[x]` orchestration checkpoints — skip them. Continue from the Resume cursor.
  4. Set Status back to IN_PROGRESS, note the resume in Current progress.
-->

## Current progress

<What you (the supervisor) are doing/awaiting RIGHT NOW. Updated as the fleet moves.>

## Reports sent to main

<!-- Log of meaningful checkpoints reported up via attn (so you don't double-report
     and main can audit the signal). Newest at top. -->

- <YYYY-MM-DD HH:MM> — DIRECTION reported: <summary>

## Blockers

<!-- Anything halting the initiative, esp. items escalated to main for the user. Empty if none. -->

## Decisions log

<!-- Significant orchestration decisions: partitioning, which worker got Opus + why,
     re-spawn calls, scope changes. -->
