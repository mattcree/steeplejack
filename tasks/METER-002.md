---
id: METER-002
title: Nerve meter: height, wind, exposure and shocks
milestone: M1
discipline: [ENG]
estimate_days: 1.5
status: in_progress
assignee: agent
depends_on: [METER-001]
owns:
  - Source/SteeplejackSim/Private/MetersNerve.cpp
  - tests/unit/test_nerve.cpp
spec:
  - docs/01-gdd/03-meters-grip-nerve.md#nerve--the-long-meter
  - docs/01-gdd/03-meters-grip-nerve.md#low-nerve-effects-this-is-the-whole-point
verify: make test-unit FILTER=nerve
editor_required: false
risk: R1
---

## Goal
Nerve as the slow meter that makes height mechanically frightening rather than just visually impressive.

## Why
Without nerve, a 110 m chimney plays exactly like a 12 m one. Nerve is what converts altitude into difficulty.

## Context
Nerve never kills the player directly — it makes them worse at the job, which kills them. Implement the four effect bands as reported state; the presentation layer decides what to do with them. The height factor formula and all shock values are in `meters.json`.

## Acceptance
1. The drain formula matches the GDD exactly for height, wind and exposure factors.
2. Height factor clamps to [0.25, 3.0].
3. All nine shock events are implemented with the tuned values.
4. `band()` returns the four bands at the tuned thresholds.
5. Nerve starts at 90, not 100.
6. Max nerve can be reduced (the cigarette penalty) and current nerve clamps to it.

## Out of scope
Recovery actions are METER-004. Visual and audio effects are UI-001 and AUD-003.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
