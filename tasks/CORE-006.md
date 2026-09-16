---
id: CORE-006
title: Intent recorder and replay playback
milestone: M0
discipline: [ENG]
estimate_days: 2
status: ready
assignee: null
depends_on: [CORE-005, CORE-003]
owns:
  - sim/intent.gd
  - sim/recorder.gd
  - sim/replay.gd
  - tests/replay/test_replay_roundtrip.gd
spec:
  - docs/03-tech/interfaces.md#simintentgd-simrecordergd-simreplaygd--core-006
  - docs/03-tech/adr/0003-determinism-and-testing.md#recording-and-replay
  - docs/06-workflow/03-verification.md#rung-7-is-the-one-that-matters
verify: make test-unit FILTER=test_replay_roundtrip
editor_required: false
risk: R1
---

## Goal
Record every player intent per tick, serialise it with the seed and tuning hash, and replay it to an identical final state.

## Why
This is the single highest-leverage engineering decision in the project. It gives us regression tests, playtest telemetry, 40 KB bug reports and a balance-change diff tool, all from one mechanism.

## Context
An intent is a small struct, not an input event — `HAMMER_RELEASE(power, angle_error)`, not `mouse_up`. That keeps replays stable across input remapping and accessibility settings. The replay stores `tuning_hash`; loading a replay against different tuning must fail loudly with the two hashes, not silently produce different numbers.

## Interface
See `docs/03-tech/interfaces.md` section `sim/intent.gd, sim/recorder.gd, sim/replay.gd`.

## Acceptance
1. Recording 3,600 ticks of synthetic intents and replaying them produces a tick-for-tick identical state trace.
2. Replaying twice from the same file produces identical results.
3. A replay recorded against a different tuning hash fails with an error naming both hashes.
4. A 60-second replay serialises to under 100 KB.
5. `intents_at(tick)` returns an empty array for ticks with no input, without allocating.

## Out of scope
Do not build the regression harness that asserts invoices — that is TEST-002, and it needs a level and a scoring model.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
