---
id: VERB-005
title: Lash verb: wraps, tension, hitch vs full
milestone: M1
discipline: [ENG]
estimate_days: 2
status: ready
assignee: null
depends_on: [VERB-004]
owns:
  - Source/SteeplejackSim/Public/Verbs/Lash.h
  - Source/SteeplejackSim/Private/Verbs/Lash.cpp
  - tests/unit/test_lash.cpp
spec:
  - docs/03-tech/interfaces.md#simverbslashgd--verb-005
  - docs/01-gdd/04-tools-and-verbs.md#lash
  - docs/01-gdd/02-climbing-system.md#the-verbs
verify: make test-unit FILTER=lash
editor_required: false
risk: null
---

## Goal
Rope a ladder to an anchor: continuous rotation builds wraps and tension; three wraps is a hitch, six is a full lashing.

## Why
The only continuous, physical input in the game. It is what makes tying a rope feel like tying a rope, and it is the clearest fast-and-worse decision in the anchor loop.

## Context
Smooth continuous rotation must be meaningfully faster than jerky input — that is where the skill lives. Tension decays if the player pauses. A quick hitch holds but drifts `tuning.lash_hitch_drift_cm_per_minute`, so over a long job the ladder walks off the anchor; that delayed consequence is deliberate.

## Interface
```cpp
class_name LashVerb extends RefCounted
class LashState:
    var wraps: int
    var tension: float
    var tied: bool
    var slipping: bool
static func step(s: LashState, dt: float, rotation_rate: float, tuning: Tuning) -> void
static func tie_off(s: LashState, tuning: Tuning) -> Lashing
static func drift_per_minute_cm(l: Lashing, tuning: Tuning) -> float
```

## Acceptance
1. Six wraps at a steady rotation rate completes in roughly `6 * lash_seconds_per_wrap_ideal`.
2. Jerky input (alternating rate) takes at least 40% longer for the same wrap count — proven in a test.
3. Tension decays when `rotation_rate` is zero.
4. Tying off below three wraps yields NONE and the state reports slipping.
5. Hitch drift is non-zero and full-lashing drift is zero.

## Out of scope
Input mapping and accessibility alternatives are VERB-006.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
