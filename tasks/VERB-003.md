---
id: VERB-003
title: Hammer: power, angle and depth
milestone: M1
discipline: [ENG]
estimate_days: 3
status: ready
assignee: null
depends_on: [CORE-007, STRUCT-002]
owns:
  - sim/verbs/hammer.gd
  - tests/unit/test_hammer.gd
spec:
  - docs/03-tech/interfaces.md#simverbshammergd--verb-003
  - docs/01-gdd/02-climbing-system.md#2-dogging-in--the-hammer
  - docs/01-gdd/04-tools-and-verbs.md#dog-in
verify: make test-unit FILTER=test_hammer
editor_required: false
risk: R1
---

## Goal
Resolve a single hammer strike from power, angle error, joint softness and tool condition.

## Why
MVP criterion 5 is whether the verbs have a mastery curve. The hammer is the most-repeated action in the game and carries most of that curve. If it has no skill ceiling, the project has a serious problem.

## Context
Three axes of skill, not a timing bar: power (arc length at release), angle (reticle offset, already wobble-affected by the caller), depth (persistent per-dog accumulation). The designed insight the player should discover is that 60-75% power with a clean angle beats 100% power — make sure the model actually produces that. Formulas are in the GDD section; implement them literally and tune from JSON.

## Interface
```gdscript
class_name HammerVerb extends RefCounted
static func strike(joint: Joint, current_depth: float, power: float,
                   angle_error_deg: float, tool_condition: float,
                   tuning: Tuning) -> StrikeResult
```

## Acceptance
1. Five strikes at 0.7 power and under 4 deg error seat a dog from 0 to at least 80% depth in a Sound joint.
2. A property test proves 0.65-0.75 power outperforms 1.0 power across the angle-error range — the designed insight holds.
3. Soft (perished) mortar reaches depth in fewer strikes than sound mortar.
4. Full power at over 10 deg error bends the dog with high probability.
5. Over-driving a low-quality joint produces spall; spall reduces the eventual rating.
6. Pure function: no state, no RNG, deterministic for identical inputs.

## Out of scope
No swing state machine, no wobble computation, no animation, no audio — those belong to the caller, METER-003, ART-001 and AUD-002 respectively.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
