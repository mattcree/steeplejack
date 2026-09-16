---
id: CORE-008
title: Level data loader
milestone: M0
discipline: [ENG]
estimate_days: 1.5
status: ready
assignee: null
depends_on: [CORE-004]
owns:
  - Source/SteeplejackSim/Public/Level.h
  - Source/SteeplejackSim/Private/Level.cpp
  - tests/unit/test_level.cpp
reads:
  - data/levels/01-back-yard.json
  - data/levels/06-waterside.json
  - data/schemas/level.schema.json
  - tools/validate_data.py
spec:
  - docs/03-tech/interfaces.md#simlevelgd--core-008
  - docs/03-tech/data-schemas.md#level-file
  - docs/01-gdd/01-core-loop.md#the-ascent-beat-rule
verify: make test-unit FILTER=test_level && make validate
editor_required: false
risk: null
---

## Goal
Parse a level JSON into typed data and re-implement the validator's rules in `validate()`.

## Why
Levels are data, not scenes. This loader is the only path from a designer's JSON to something playable, and its validator is the second line of defence against a broken level reaching playtest.

## Context
`tools/validate_data.py` already implements the rules in Python (band contiguity, quality sums, the Ascent Beat Rule, corridor/exclusion conflicts, scoring field names). `LevelData.validate()` must implement the same rules. A test must assert the two agree on both existing levels plus a deliberately broken fixture — a divergence between them is a bug in whichever is newer.

## Interface
```cpp
class_name LevelData extends RefCounted
static func load_from(path: String) -> LevelData
func band_at(height: float) -> Dictionary
func total_height() -> float
func validate() -> Array[String]
```

## Acceptance
1. Both shipped levels load and `validate()` returns an empty array.
2. A fixture with a 25 m `plain` band returns an error mentioning the Ascent Beat Rule.
3. A fixture with a quality distribution summing to 1.35 returns an error.
4. A fixture with an exclusion inside the fall corridor returns an error.
5. `band_at(37.0)` on `06-waterside` returns the `existing-band` band.
6. A test asserts C++ `validate()` and `tools/validate_data.py` produce the same error count on all fixtures.

## Out of scope
Do not build the reachability solver here — that is CORE-009 and it needs the joint grid.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
