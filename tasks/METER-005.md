---
id: METER-005
title: Slip-save, falling, and resume-at-stack
milestone: M1
discipline: [ENG]
estimate_days: 2
status: ready
assignee: null
depends_on: [METER-003, CLIMB-006]
owns:
  - Source/SteeplejackSim/Public/Slip.h
  - Source/SteeplejackSim/Private/Slip.cpp
  - tests/unit/test_slip.cpp
  - Source/SteeplejackGame/Player/States/FallState.cpp
spec:
  - docs/01-gdd/02-climbing-system.md#6-falling
  - docs/01-gdd/10-failure-and-difficulty.md#4-the-slip-save
  - docs/01-gdd/10-failure-and-difficulty.md#5-the-fall
  - docs/01-gdd/14-accessibility.md#motion--vertigo
verify: make test-unit FILTER=slip
editor_required: false
risk: R9
---

## Goal
A 900 ms grab window once per minute; failing it falls, and falling resumes from the ladder stack.

## Why
The player will fall. It must be readable, survivable-feeling, and never a save-scum. The stack-as-checkpoint is what makes a fall sting without wiping twenty-five minutes.

## Context
Clipped on: you drop to the safety line and shock-load that anchor at 2.5x — which may itself fail, and that is the grimmest moment in the game. Not clipped: camera goes wide, time dilates to 0.6, the stack streaks past, cut to black before impact. The slip-save budget of one per 60 s is what makes the second slip terrifying.

## Acceptance
1. The window is 900 ms on Jack difficulty and tracks the difficulty table.
2. The cooldown is enforced: a second slip within 60 s cannot be saved.
3. A successful save leaves grip at 15% and applies nerve -25.
4. Clipped falls shock-load the safety anchor at 2.5x and can cascade.
5. An unclipped fall serialises the stack and returns the player to its base on resume.
6. Time dilation and the fall camera respect the accessibility motion settings, including the 'minimal' option.

## Out of scope
Injuries, lost fees and the hospital beat are FAIL-001 at M2. This task ends the shift and resumes.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
