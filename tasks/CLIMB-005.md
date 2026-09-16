---
id: CLIMB-005
title: Hand and foot IK onto ladder rungs
milestone: M1
discipline: [ENG, ART]
estimate_days: 4
status: ready
assignee: null
depends_on: [CLIMB-004]
owns:
  - game/player/ik_rig.gd
  - game/player/skeleton.tscn
spec:
  - docs/01-gdd/11-camera-controls-feel.md#feel--the-non-negotiables
  - docs/01-gdd/02-climbing-system.md#the-verbs
verify: Video review: hands land on actual rungs at 3, 5 and 7 m spans and on a flexing section.
editor_required: true
risk: R2
---

## Goal
Hands and feet contact real rung positions on procedurally placed, flexing ladders.

## Why
The highest-value animation work in the project. It is what makes the ladders feel like objects rather than a climbing surface, and it is directly load-bearing for MVP criteria 1 and 6.

## Context
**This is risk R2 and the longest task before the M1 gate — start it early and give it to your best person.** If it exceeds 8 days, fall back to the two-pose contact system (hands snap to the nearest rung at fixed offsets with a short blend): 80% of the quality at 20% of the cost. Decide at day 8, not day 20.

## Acceptance
1. Hands land within 3 cm of an actual rung at 3, 5 and 7 m spans.
2. Contact tracks a flexing section as it bends.
3. No foot sliding during the climb cycle.
4. IK runs only when the player is on-screen within 30 m (perf budget).
5. Solve cost stays under 1.5 ms including animation.
6. Fallback decision recorded in `## Outcome` if the two-pose system was used instead.

## Out of scope
No hand contact for work verbs (hammering, lashing) — that is a later task if playtest asks for it.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
