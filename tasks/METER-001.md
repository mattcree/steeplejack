---
id: METER-001
title: Grip meter and the five stances
milestone: M1
discipline: [ENG]
estimate_days: 1.5
status: ready
assignee: null
depends_on: [CORE-007]
owns:
  - Source/SteeplejackSim/Public/Meters.h
  - Source/SteeplejackSim/Private/MetersGrip.cpp
  - tests/unit/test_grip.cpp
spec:
  - docs/03-tech/interfaces.md#simmeters_gripgd-simmeters_nervegd-simwobblegd--meter-0123
  - docs/01-gdd/03-meters-grip-nerve.md#grip--the-short-meter
  - docs/01-gdd/02-climbing-system.md#5-grip-and-why-climbing-is-free-but-working-is-not
verify: make test-unit FILTER=grip
editor_required: false
risk: null
---

## Goal
Grip as a 12-second window on one-handed work, with five stances that trade set-up time for drain rate.

## Why
Grip is not a stamina bar — it converts a limit into a decision. The stance table is the difficulty dial for the entire game.

## Context
Drains only when a hand is off the ladder. Recovers at 25/s with both hands on. Every modifier in `meters.json` must be implemented: ladder carry, wet, cold, cracked rib, gloves. The cold cap (max grip 80 until two minutes of work) matters for the winter levels later.

## Acceptance
1. Drain rates for all five stances match `meters.json` exactly.
2. Full recovery from zero takes about 4 s.
3. All five modifiers are implemented and unit tested.
4. Below 20 the tremor flag is set.
5. At zero, the model reports a slip condition (it does not resolve it — that is METER-005).
6. A property test: grip never exceeds max or drops below zero.

## Out of scope
Nerve is METER-002. Wobble is METER-003. Slip resolution is METER-005.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
