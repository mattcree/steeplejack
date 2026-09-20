---
id: FELL-006
title: "Act 4, and what a felling costs you in daylight"
milestone: M0
discipline: [ENG]
estimate_days: 1
status: done
assignee: null
depends_on: [FELL-003]
owns:
  - Source/SteeplejackSim/Public/Fell.h
  - Source/SteeplejackSim/Private/Fell.cpp
  - tests/unit/test_fell.cpp
reads:
  - Source/SteeplejackSim/Public/Level.h
  - data/tuning/felling.json
spec:
  - docs/01-gdd/06-felling-system.md
verify: make test-unit FILTER=Fell:
editor_required: false
risk: null
---

## Goal
Pack the gob, light it, run — and a shift that every cell, every prop and every metre off the top
is spending.

## Why
Firing was one keypress, which is a third of a felling missing. And `shiftMinutes` had been
authored in every level file since the first one and read by nothing, so a felling cost you
nothing but clicks.

## Context
The design is precise about why packing matters: "poor packing = slow burn = the chimney drops
before the props are fully gone = worse accuracy". So it costs twice — a half-packed gob smoulders
for 68 seconds instead of 45 and lands ±11.1° instead of ±7.6°. More time to get clear, and a worse
fall to get clear of.

The match is deterministic on the level's seed. A coin flip you cannot learn is not tension.

**Two docs disagreed about the price of height.** The felling system doc says 40 seconds a metre;
level-07 said eight metres costs twelve minutes, which is ninety. The system doc wins — it is the
spec for the system and 40 s is the number the game quotes the player — and level-07 is corrected.

## Interface
`Fell::ShiftCostSeconds`, `Fell::MaxHeightReductionM`, `Fell::BurnSeconds`, `Fell::MatchTakes`,
and `FellPlan::packingQuality`. See [`interfaces.md`](../docs/03-tech/interfaces.md).

## Acceptance
1. A worked gob costs about half the level's authored shift.
2. Packing quality moves both the burn time and the accuracy, in the directions the design gives.
3. The match fails in wind, succeeds when sheltered, and behaves the same way every run.
4. Being inside the safe line when the props go is its own consequence, not a worse grade.

## Out of scope
The topping system that would make taking height off an actual climb; the railway timetable at
Great Aire.

## Outcome
Done. `LevelData::ShiftMinutes()` exists now, which is what made the shift readable at all.

**The trade is not yet a decision, and level-07 says so.** Twenty metres off takes the cone from
7.6° to the floor at 2.0° for thirteen minutes of a shift that nothing else is spending, because
Act 2's climbing is not priced. It becomes a decision when the strip-out and the ascent are on the
same clock. Better to have the arithmetic right and say what it does not yet mean than to fake a
tension that is not there.
