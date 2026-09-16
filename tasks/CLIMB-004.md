---
id: CLIMB-004
title: Climb, transition and slide-down states
milestone: M1
discipline: [ENG]
estimate_days: 2
status: ready
assignee: null
depends_on: [PLAYER-001, CLIMB-001]
owns:
  - game/player/states/climb.gd
  - game/player/states/slide.gd
spec:
  - docs/01-gdd/02-climbing-system.md#the-verbs
  - docs/01-gdd/11-camera-controls-feel.md#feel--the-non-negotiables
  - docs/01-gdd/03-meters-grip-nerve.md#grip--the-short-meter
verify: godot --path . --headless -s tests/smoke_climb.gd
editor_required: false
risk: null
---

## Goal
Climbing an existing stack is fast and nearly free; transitioning onto a new section is deliberate and costs grip.

## Why
The asymmetry is the whole anti-tedium design: the route you built is quick to re-climb, but extending it is careful work. Get this wrong and a 28-anchor ascent is a chore.

## Context
Climb at 1.6 m/s, slide at 6 m/s. The transition onto a new section is the most dangerous moment in the loop and must feel like one — a held input with a commitment animation, not a step. Sliding is disabled when wet or carrying a ladder.

## Acceptance
1. Climb speed matches tuning; acceleration is 0.25 s.
2. Transition onto a new section is a deliberate held action with a grip cost.
3. Slide-down reaches 6 m/s, is loud and fast, and applies the nerve cost on landing.
4. Slide is blocked when wet or carrying a section.
5. Climbing a buckling section still works (the player must be able to escape).
6. Re-climbing an existing 55 m stack takes under 40 s.

## Out of scope
No IK (CLIMB-005), no falling (METER-005), no animation polish.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
