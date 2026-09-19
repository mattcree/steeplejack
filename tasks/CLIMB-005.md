---
id: CLIMB-005
title: Hand and foot IK onto ladder rungs (Control Rig + FBIK)
milestone: M1
discipline: [ENG, ART]
estimate_days: 2.5
status: review
assignee: null
depends_on: [CLIMB-004]
owns:
  - Source/SteeplejackGame/Player/IKComponent.h
  - Source/SteeplejackGame/Player/IKComponent.cpp
  - Content/Characters/CR_Steeplejack.uasset
spec:
  - docs/01-gdd/11-camera-controls-feel.md#feel--the-non-negotiables
  - docs/01-gdd/02-climbing-system.md#the-verbs
  - docs/03-tech/adr/0004-engine-change-to-unreal.md#what-unreal-buys-that-is-specific-to-this-game
verify: Video review: hands land on actual rungs at 3, 5 and 7 m spans and on a flexing section.
human_required: true
editor_required: true
risk: R2
---

> **2026-09-19:** Unreal is removed from the project. This need does not depend on the engine, so the task stays open, but its `owns:` paths and any Unreal specifics predate ADR-0006. Retarget them to `godot/` before starting.

## Goal
Hands and feet contact real rung positions on procedurally placed, flexing ladders.

## Why
The highest-value animation work in the project. It is what makes the ladders feel like objects
rather than a climbing surface, and it is directly load-bearing for MVP criteria 1 and 6.

## Context
**Risk R2, and on the critical path.** Under Godot this was a 4-day bespoke solve; under Unreal it
is Control Rig + Full Body IK, which is a solved problem — estimate reduced to 2.5 days and the
risk downgraded from HIGH to MEDIUM. That downgrade was one of the four reasons for ADR-0004.

Rung positions come from `sj::Stack`, which is sim data, not scene geometry. The IK targets must
track the **flexing** ladder, so read the deflection from `Stack::FlexDeflectionM`, not from the
rendered mesh.

The fallback if this still overruns (decide at day 5, not day 12): a two-pose contact system where
hands snap to the nearest rung at fixed offsets with a short blend. 80% of the quality at 20% of the
cost. Record the decision in `## Outcome` either way.

## Acceptance
1. Hands land within 3 cm of an actual rung at 3, 5 and 7 m spans.
2. Contact tracks a flexing section as it bends, driven by `Stack::FlexDeflectionM`.
3. No foot sliding during the climb cycle.
4. IK is disabled beyond 30 m from camera (perf budget).
5. Control Rig evaluation stays within the 1.5 ms character budget including Chaos Cloth.
6. Fallback decision recorded in `## Outcome` if the two-pose system was used instead.

## Out of scope
No hand contact for work verbs (hammering, lashing) — a later task if playtest asks for it.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
**What changed:** under ADR-0006 this is Godot's `TwoBoneIK3D`, one per limb, driven by
`godot/scripts/rung_grip.gd`, not Control Rig. The declared deviation from `owns`: rung_grip.gd,
wiring in player.gd, and `godot/scripts/test_grip.gd` (in `make godot-test`).

- Every hand and foot is *planted* on a real rung (chimney.gd's geometry, bow included) and stays
  there. A limb whose rung falls a rung behind the body reaches for the next one, arcing out from
  the ladder. Limbs go in diagonal pairs (left hand with right foot, then right hand with left
  foot), and a pair only moves while the other holds. Reaches aim for where the body will be, not
  where it is.
- The canned climb cycle is held still under the IK. It was the "very wrong animation" this
  replaces.
- The hammer hand lets go for a tap, a blow, lashing or hauling, and while a slip is open. It
  takes its rung back as soon as the swing is over.
- At the head of the ladder there is no rung above, so the hands go flat on the brick and the
  drawn body settles onto the top rung. Drawing only: the game's height and reach are unchanged.

Acceptance:

1. At rest every limb's solved bone is 0.000–0.015 m from its rung, measured at
   `skeleton_updated` (after the IK). Span length makes no difference: rungs are every
   `RUNG_GAP` whatever the span.
2. The hand's contact point moves by exactly the ladder's bow (tested). The bow is the sim's
   `FlexDeflectionM` via `stack_step`, **capped for the eye at 0.34 m in chimney.gd**. Contact
   follows the drawn ladder, which is what the eye checks against, and not the uncapped sim value.
3. No sliding. A planted limb's target is its rung. While one pair reaches, the other holds
   (worst 0.074 m of stretch at the full 1.6 m/s climb, exact at rest).
4. Not done. There is one character, always within a few metres of the camera.
5. Not measured: nothing measures GPU/CPU frame time in Godot (see performance-budget.md). Four
   two-bone solves are negligible.
6. No fallback: full IK.

**Surprises:** the IK looked broken in the first test, with hands half a metre off, because the
test read the skeleton outside the modifier pass. Solved poses exist only at `skeleton_updated`.
Also, the ladder's A/D shuffle was inverted, reported at the same time and fixed separately.

**Follow-ups:** feet are placed, not oriented, so a foot sometimes turns out sideways on its rung.
Hands likewise do not close round the rung.
