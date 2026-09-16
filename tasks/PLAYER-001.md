---
id: PLAYER-001
title: Character controller and state machine
milestone: M0
discipline: [ENG]
estimate_days: 2
status: ready
assignee: null
depends_on: [CORE-005]
owns:
  - game/player/controller.gd
  - game/player/state_machine.gd
  - game/player/player.tscn
  - game/player/states/idle.gd
  - game/player/states/walk.gd
spec:
  - docs/01-gdd/11-camera-controls-feel.md#controls
  - docs/01-gdd/11-camera-controls-feel.md#feel--the-non-negotiables
  - docs/03-tech/architecture.md#the-frame
verify: godot --path . --headless -s tests/smoke_player.gd
editor_required: false
risk: null
---

## Goal
A kinematic capsule that walks the ground, driven by intents, with a state machine other tasks can extend.

## Why
Climb, slide, tea and fall states all hang off this. Getting the state machine shape right now saves four tasks of refactoring later.

## Context
Kinematic body, not dynamic (ADR-0002). The controller converts input to `Intent` structs and hands them to the sim; it must not make gameplay decisions itself. States are separate files so that CLIMB-004, METER-004 and METER-005 can each own one without conflicting.

## Acceptance
1. Walks the grey-box field with acceleration and deceleration — nothing snaps to a new velocity.
2. Reaching full speed takes 0.25 s, per the feel targets.
3. Input to visible response is under 50 ms.
4. Adding a new state is one new file plus one registration line.
5. The controller emits intents and reads sim state; it contains no gameplay logic (checked in review).

## Out of scope
No climbing (CLIMB-004), no IK (CLIMB-005), no animation beyond a placeholder capsule.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
