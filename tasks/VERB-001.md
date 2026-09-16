---
id: VERB-001
title: Tap-test verb
milestone: M1
discipline: [ENG]
estimate_days: 1
status: ready
assignee: null
depends_on: [STRUCT-002, CORE-007]
owns:
  - sim/verbs/tap.gd
  - tests/unit/test_tap.gd
spec:
  - docs/03-tech/interfaces.md#simverbstapgd--verb-001
  - docs/01-gdd/02-climbing-system.md#1-reading-the-brickwork
  - docs/01-gdd/04-tools-and-verbs.md#tap-test
verify: make test-unit FILTER=test_tap
editor_required: false
risk: R1
---

## Goal
A 0.8 s aimed action that reveals a joint's tier by sound, with a gloves penalty.

## Why
This is the game's signature action and the one players should perform constantly. It must be cheap, snappy and satisfying, or the whole material-reading skill collapses.

## Context
Deliberately cheap so players tap constantly. Gloves reduce resolution by one tier (`tuning.gloves.tap_tier_penalty`) — a real trade the player opts into. `pip_shape` is a SHAPE index, not a colour, because the accessibility fallback must not rely on colour.

## Interface
```gdscript
class_name TapVerb extends RefCounted
class TapResult:
    var tier: JointTier
    var confidence: float
    var sound_id: String
    var pip_shape: int
static func tap(joint: Joint, tuning: Tuning, wearing_gloves: bool) -> TapResult
```

## Acceptance
1. Returns the joint's true tier when not wearing gloves.
2. With gloves, adjacent tiers become indistinguishable per the tuning penalty, deterministically (not randomly).
3. `sound_id` maps to a bank key that exists in `game/audio/banks/tap/`.
4. `pip_shape` returns four distinct values for four tiers.
5. The action takes `tuning.tap_test_seconds` and has a max range of `tuning.tap_test_max_range_metres`.

## Out of scope
No audio playback and no reticle rendering — AUD-001 and VERB-002 own those.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
