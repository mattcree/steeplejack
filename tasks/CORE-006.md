---
id: CORE-006
title: Intent recorder and replay playback
milestone: M0
discipline: [ENG]
estimate_days: 2
status: review
assignee: null
depends_on: [CORE-005, CORE-003]
owns:
  - Source/SteeplejackSim/Public/Intent.h
  - Source/SteeplejackSim/Public/Recorder.h
  - Source/SteeplejackSim/Public/Replay.h
  - Source/SteeplejackSim/Private/Recorder.cpp
  - Source/SteeplejackSim/Private/Replay.cpp
  - tests/replay/test_replay_roundtrip.cpp
spec:
  - docs/03-tech/interfaces.md#simintentgd-simrecordergd-simreplaygd--core-006
  - docs/03-tech/adr/0003-determinism-and-testing.md#recording-and-replay
  - docs/06-workflow/03-verification.md#rung-7-is-the-one-that-matters
verify: make test-unit FILTER=replayroundtrip
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
See `docs/03-tech/interfaces.md` section `Intent.h`, `Recorder.h`, `Replay.h`.

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
**What changed:** `Intent.h`, `Recorder.h`/`.cpp` and `Replay.h`/`.cpp` implement the
interface in `interfaces.md`, plus `RequireTuning` and `ReplayError` (documented there).
`tests/replay/test_replay_roundtrip.cpp` has one test per acceptance criterion, plus three more:
order inside a tick survives the encoding, every float comes back to the bit, and malformed files
are refused. The run it records drives real sim code (grip, nerve, hammer strikes on four joints)
and compares a hash of that state on every one of 3,600 ticks. It also compares the intents
themselves, so an intent that happened to have no effect cannot drop out unnoticed.
`make test-replay` and `make test-determinism` now find tests, where before they printed "no such
tests yet".

**Decisions made:**

- The file format was designed for size. Rows are delta-ticked. Trailing fields at their defaults
  are left off. Consecutive ticks with the same intent in the same slot are one row with a repeat
  count, so a held climb key is one row, not 240. The slot (the intent's index within its tick)
  is packed with the kind as slot × 32 + kind. Without it, the run-length encoding would lose the
  order inside a tick, and Look-then-Climb is a different tick from Climb-then-Look.
- The seed is written as a string, because a uint64 does not survive a JSON number.
- Floats are written shortest-round-trip, and each one is checked on the way out. The reader
  parses doubles and narrows them, and if the shortest float spelling double-rounds, the double
  spelling is written instead.

**Surprises:**

- −0.0 == 0.0. "Leave defaults off" first dropped a recorded −0.0, and the replay read +0.0. It
  was caught by the every-float test. Defaults and run extension now compare bits.
- Acceptance 4 is closer than expected. A minute with a fresh full-precision mouse delta on 80%
  of ticks, close to a worst case, is about 99 KB. A real mouse prints shorter. If it ever needs
  margin, quantise Look to the mouse's own counts at the input layer; that is a semantic change,
  not a format one.

**Follow-ups:** nothing records yet. The Godot layer has to emit intents (a `Recorder` in the
binding, fed from `player.gd`'s verbs) and have a replay driver. That is the start of TEST-002,
which also needs the verbs to accept intents rather than read keys, and the
`climb_input`/`walk_input`/`aim_override` seams in `player.gd` are the first step toward that.
