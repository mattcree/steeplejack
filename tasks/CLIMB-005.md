---
id: CLIMB-005
title: Hand and foot IK onto ladder rungs (Control Rig + FBIK)
milestone: M1
discipline: [ENG, ART]
estimate_days: 2.5
status: ready
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
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
