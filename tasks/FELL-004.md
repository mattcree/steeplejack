---
id: FELL-004
title: The site you are felling into
milestone: M0
discipline: [ENG]
estimate_days: 1
status: done
assignee: null
depends_on: [FELL-003]
owns:
  - godot/scripts/fell_site.gd
reads:
  - data/levels/06-waterside.json
  - godot/scripts/town.gd
spec:
  - docs/01-gdd/06-felling-system.md
verify: make godot-script SCRIPT=res://scripts/test_felling.gd
editor_required: false
risk: null
---

## Goal
The exclusions, the corridor, the safe line and the crowd, generated from the level file and standing on the ground where you can walk to them.

## Why
"The survey is a map-reading activity in first person, with no overlay map." A pump house that exists only as a square on a HUD panel is not somewhere you can walk to, and the money you owe for flattening it is a number rather than a mistake.

## Context
town.gd starts at 120 m and is scenery. This is the 120 m it leaves out. Buildings are sized by
what they cost so a greenhouse reads as a greenhouse and a chapel reads as a chapel.

Nameplates fade past 70 m deliberately: a label you can read from the far side of the field is an
overlay map, which is the thing the design says this survey does not have.

## Interface
See [`docs/03-tech/interfaces.md`](../docs/03-tech/interfaces.md) — `Gob.h` (FELL-001) and `Fell.h`
(FELL-002) are written out there in full.

## Acceptance
1. Every authored exclusion is a building at its bearing and distance, named.
2. The corridor is painted on the ground with a rope down each edge.
3. The safe line is marked at the distance the level authors.
4. The crowd is deterministic and reacts when it lands.

## Out of scope
Crowd control as a mechanic, which is Great Aire's twist and its own task.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
Built.
