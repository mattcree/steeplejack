---
id: VERB-006
title: Lash input alternatives (rotate / mash / hold)
milestone: M1
discipline: [ENG]
estimate_days: 0.5
status: review
assignee: null
depends_on: [VERB-005]
owns:
  - Source/SteeplejackGame/Player/LashInput.cpp
  - Source/SteeplejackGame/Player/LashInput.h
spec:
  - docs/01-gdd/14-accessibility.md#motor
  - docs/01-gdd/11-camera-controls-feel.md#controls
verify: make test-unit FILTER=VERB-006
editor_required: false
risk: null
---

## Goal
Three input methods for lashing that produce identical outcomes: stick rotation, button mash, and hold-only.

## Why
Stick rotation excludes players with motor impairments from a verb used on every single anchor. There is no version of this game that is playable without lashing.

## Context
All three must feed the same `rotation_rate` into `LashVerb.step`. Hold-only auto-wraps at a fixed rate — slower than expert rotation, faster than bad rotation, which is the right place for it.

## Acceptance
1. All three methods can complete a six-wrap lashing.
2. A test asserts the same wrap count and tension curve is reachable by each method.
3. Switching method mid-lash does not corrupt state.
4. The setting is available at every difficulty with no penalty or comment.

## Out of scope
Do not extend this to other verbs yet — the general hold-to-toggle system is A11Y-001.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
**What changed:** under ADR-0006 the input layer is `player.gd` (`_lash_input`,
`LASH_METHODS`, **L** to cycle), not `LashInput.cpp`/`.h`. That is the declared deviation from
`owns`. The sim side is `lash::RateFromMash` and `lash::RateFromHold`.

1. and 2. "Lash: VERB-006 acceptance 1 and 2" drives rotate, mash (four presses a second) and
   hold each to six wraps, and each must tie off as a Full lashing with nothing slipping. That
   is the same end state, but **not the same tension curve over time**, which is how
   acceptance 2 reads. Nothing compares the curves, and hold is deliberately slower (next
   point). A reviewer should decide whether "reachable" means the end state (as tested) or the
   curve.
3. `test_lash_game.gd` switches method mid-lash and checks every turn already on stays on.
4. There is no difficulty setting in this build. **L** works in every state with no message
   other than the method's name and how to use it.

**Decisions made:** hold is slower than an expert's rotation and faster than a bad one. That
is the task's own context ("never the best way, never a punishment"), and "Lash: holding is
slower than a good hand and faster than a bad one" asserts it. Every method finishes as a Full
lashing, so none of them makes a worse lashing, only a slower or faster one.

**Follow-ups:** a visible list of the three methods in the F1 options, so the setting can be found
before the first lashing. It is only discoverable from the lash HUD now.
