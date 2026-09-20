---
id: FELL-005
title: Act 1, the survey
milestone: M0
discipline: [ENG]
estimate_days: 1
status: done
assignee: null
depends_on: [FELL-003]
owns:
  - godot/scripts/felling.gd
reads:
  - Source/SteeplejackSim/Public/Fell.h
spec:
  - docs/01-gdd/06-felling-system.md
verify: make godot-script SCRIPT=res://scripts/test_felling.gd
editor_required: false
risk: null
---

## Goal
Walk the site, read the lean with a plumb bob from two positions, drive two pegs down the line you want.

## Why
Act 1 was the one act with nothing in it, and it is the act that makes the site worth building.

## Context
Movement was an orbit at a fixed distance, which meant the pump house 30 m away - the thing you
are trying not to flatten - was somewhere you literally could not go.

The lean is not written on the chimney. Two plumb readings at least 55 degrees apart and you have
it; fewer and you are guessing, and the guess costs `fallAccuracyUnsurveyedDegrees` of cone. That
penalty is a rule, so it lives in `Fell::Predict` with a test on it, not in a script.

## Interface
See [`docs/03-tech/interfaces.md`](../docs/03-tech/interfaces.md) — `Gob.h` (FELL-001) and `Fell.h`
(FELL-002) are written out there in full.

## Acceptance
1. You can walk anywhere on the site out to twice the safe line, and not into the chimney.
2. One plumb reading is not a survey, and neither are two from nearly the same place.
3. Not surveying widens the cone by the tuned amount.
4. Two pegs at least `PEG_MIN_APART_M` apart set the fall line, and can be pulled up again.

## Out of scope
Measuring the height by shadow or by pacing, which the design offers as an expert move.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
Built.
