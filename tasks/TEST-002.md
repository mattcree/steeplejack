---
id: TEST-002
title: Replay regression harness
milestone: M1
discipline: [ENG]
estimate_days: 1
status: review
assignee: null
depends_on: [CORE-006, LVL-000]
owns:
  - tests/replay/regression.cpp
  - data/replays/00-greybox-expert.replay
spec:
  - docs/06-workflow/03-verification.md#rung-7-is-the-one-that-matters
  - docs/03-tech/adr/0003-determinism-and-testing.md#recording-and-replay
verify: make test-replay
editor_required: false
risk: null
---

## Goal
Replay a recorded expert run of the grey-box level in CI and fail on any change to the outcome.

## Why
The highest-leverage test in the project. It turns a tuning change into a readable diff of two outcomes, which is how the game gets balanced without playing it twelve times.

## Context
Record an expert run of the grey-box level by hand. The harness replays it headlessly and asserts final state: anchors placed, ratings, spans, time taken, grip and nerve at the summit. When a change legitimately alters the outcome, re-record and put the diff in the PR body — the diff *is* the justification.

## Acceptance
1. `make test-replay` replays the recorded run and passes.
2. Changing a value in `climbing.json` makes it fail with a readable before/after diff.
3. The diff names the fields that changed, not just 'mismatch'.
4. The harness runs in under 60 s.
5. A documented one-command path exists to re-record: `make record LEVEL=00-greybox`.

## Out of scope
Per-level invoices need the scoring model (M2). Assert climbing state for now.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
**What changed, and how it differs from the task as written:** the task imagines a hand-recorded
intent file replayed by a C++ harness (`tests/replay/regression.cpp`). That needs the verbs to
run from intents inside the sim, and today their orchestration (climb, tap, drive, lash, haul)
is in `godot/scripts/player.gd`. So:

- **The "expert" is `test_ascent.gd`'s bot,** which climbs the Grey Box with the real verbs. At
  a fixed frame rate and the level's own seed it is deterministic: consecutive runs give the same
  climb.
- **`godot/scripts/ascent_regression.gd`** extends the bot through a new `_finished()` hook, so
  the test itself is unchanged. It records the climb's outcome, rounded where the game is
  continuous:
  - time, sections, hauls, dogs
  - every dog's height and rating
  - every span and its lashing
  - grip and nerve at the end
- **`data/replays/00-greybox-expert.replay`** is that outcome, as JSON.

Declared deviations: the script instead of `regression.cpp`, and a Godot dependency. CI runs it
in the `godot` job (`make replay-regression`); the recording made locally matched on GitHub's runner
the first time, so the climb is deterministic across machines.

1. `make test-replay` runs the sim's replay-format tests and then this comparison, and passes.
2. and 3. Checked by hand. With `tapTestSeconds` 0.8 → 2.0 it fails with
   `game_seconds: 845.5 -> 888.5` and `nerve_at_end: 34.7 -> 26.5`, naming each field and its
   before and after. Arrays are compared by index (`anchors[3].rating: sound -> fair`), and a
   length change is reported. A change that does not alter the climb passes, correctly:
   `hammerSoftnessFloor` 0.34 → 0.30 left every dog needing the same number of the bot's blows.
4. About 30 s.
5. `make record` (LEVEL defaults to, and only accepts, `00-greybox`).

**Follow-ups:** the task's real intent replay (ADR-0003) needs a sim-side step that applies
intents to the verbs. CORE-006's recorder and replay are ready for it. When that exists, the bot
can record its intents and this comparison can run in CI with no engine.
