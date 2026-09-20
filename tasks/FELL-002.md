---
id: FELL-002
title: The fall: where it goes, where it breaks, what it costs
milestone: M0
discipline: [ENG]
estimate_days: 1
status: done
assignee: null
depends_on: [FELL-001]
owns:
  - Source/SteeplejackSim/Public/Fell.h
  - Source/SteeplejackSim/Private/Fell.cpp
  - tests/unit/test_fell.cpp
reads:
  - Source/SteeplejackSim/Public/Gob.h
  - Source/SteeplejackSim/Public/Rng.h
spec:
  - docs/01-gdd/06-felling-system.md
  - docs/03-tech/adr/0002-physics-and-destruction.md
verify: make test-unit FILTER=Fell:
editor_required: false
risk: null
---

## Goal
Given a site, a gob and a plan, where the chimney lands, where it breaks and what that is worth.

## Why
A felling is a bet the player makes at the survey and cannot take back. This is what settles it, and the prediction it shows beforehand is what makes the bet a judgement rather than a guess.

## Context
Three pulls - the hole you cut, the lean, the wind - and it goes where their sum points.
The gob is the unit the others are quoted against and only has authority in proportion to how much
of it is cut, so an uncut chimney is steered entirely by its lean.

Two findings not in the design doc:

* **A lean pointing straight back at the gob does not turn the fall.** It cancels most of the gob's
  authority instead, which leaves the fall line twitching at whatever is not exactly opposite.
  Fighting a lean head on does not move the answer, it makes it nervous. What drags a chimney off
  its pegs is a lean *across* the cut.
* **The fracture coefficient was not a free choice.** Walking the hinge over and breaking the
  highest band whose bending stress passes the threshold gives 2 breaks on Waterside and Kershaw's,
  3 on Great Aire and 3 again after its required 18 m comes off by hand - "typically 2-4 breaks",
  "clean (3-4 chunks)" - out of one coefficient and a minimum chunk length.

## Interface
See [`docs/03-tech/interfaces.md`](../docs/03-tech/interfaces.md) — `Gob.h` (FELL-001) and `Fell.h`
(FELL-002) are written out there in full.

## Acceptance
1. A chimney falls into the hole you cut, within a couple of degrees of the cut's centre.
2. Fighting the lean widens the cone by `fallAccuracyPerLeanFoughtDegree` per degree; going with it costs nothing.
3. Height taken off by hand is worth about 1.5 degrees per 5 m, as the design quotes to the player.
4. Not surveying the lean costs `fallAccuracyUnsurveyedDegrees`.
5. The fall lands inside the cone `Predict` drew, and the same inputs always give the same fall.

## Out of scope
The hinge animation and the dust (FELL-003). Salvage and reputation, which belong with the economy.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
Built. 15 test cases. The accuracy cone is an honest prediction rather than a fudge applied
afterwards - a test asserts the fall really does land inside the cone the HUD drew, which is the
property that makes the whole instrument trustworthy.

Deterministic per ADR-0002, seeded off the level and forked off the gob, so a level always falls the
same way and a player can learn one.
