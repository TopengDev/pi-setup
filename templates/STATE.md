# Task: <NAME>

**Status:** STARTING
**Started:** <YYYY-MM-DD HH:MM WIB>
**Worker:** <worker-name>
**Parent initiative:** [<initiative-slug>](../initiatives/<initiative-slug>.md)

## Starting point

<What existed when worker took over the task. Code/data/infra baseline. Key references read.>

## Roadmap

- [ ] Step 1
- [ ] Step 2
- [ ] Step 3
- [ ] Step 4
- [ ] Step 5

## Checkpoints (idempotent, resumable)

<!--
  RESUMABLE JOURNAL — the contract that lets a killed/limit-hit worker resume
  instead of redoing work or needing a babysitter. Maintain this religiously.

  Rules:
  1. Decompose the task into CHECKPOINTS — sub-steps that are each individually
     IDEMPOTENT (safe to re-run / re-check without harm or duplication).
  2. Mark a checkpoint `[x]` ONLY AFTER you have VERIFIED its effect actually
     landed (file written + re-read, command exit 0 + output asserted, row in DB,
     endpoint returns 200). A checkpoint marked done MUST be safe to skip on resume.
     If you cannot verify it, it is NOT done — leave it `[ ]`.
  3. Record the verification proof inline (how you confirmed it). On resume you (or
     a fresh you) trust `[x]` + its proof and SKIP straight to the first `[ ]`.
  4. Keep the "Resume cursor" line pointing at the next incomplete checkpoint.
  5. For a non-idempotent action (e.g. "send the email", "force-push"), make the
     checkpoint a GUARDED one: record a sentinel BEFORE acting and check it on
     resume (e.g. "if marker file X exists, already sent — skip"). Note the guard.

  Format (newest checkpoints at the bottom, in execution order):
-->

- [ ] CP1: <idempotent sub-step> — _verify:_ <how you'll confirm it landed>
- [ ] CP2: <idempotent sub-step> — _verify:_ <…>
- [ ] CP3: <idempotent sub-step> — _verify:_ <…>

**Resume cursor:** CP1 (next incomplete checkpoint)

## Resume protocol

<!--
  Followed on EVERY (re)start of this worker — especially after a kill / session
  limit / crash. A re-brief (resume-worker.sh) injects a RESUME preamble that
  points here. Steps:

  1. READ THIS STATE.md FIRST, before any work tool calls.
  2. Read the Checkpoints section. Every `[x]` is DONE + verified — do NOT redo it
     (the work is idempotent and already landed; redoing risks duplication/cost).
  3. Find the first `[ ]` checkpoint (the Resume cursor). For any GUARDED
     non-idempotent checkpoint, re-check its sentinel before assuming state.
  4. Briefly re-verify the LAST `[x]` is still true (cheap sanity that the prior
     run's effect persisted), then continue from the first `[ ]`.
  5. Update "Current progress" to note you resumed and from which checkpoint.
-->

## Current progress

<What worker is doing RIGHT NOW. Updated continuously as work progresses.>

## Completed

<!-- Move items here from Roadmap as they finish. Newest at top. -->

## Blockers

<!-- Any blockers, external dependencies, halted state. Leave empty if none. -->

## Decisions log

<!-- Optional: significant decisions made during the task. Why this approach over alternatives. -->
