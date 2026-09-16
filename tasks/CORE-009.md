---
id: CORE-009
title: Reachability solver and level validation gate
milestone: M0
discipline: [ENG]
estimate_days: 2
status: ready
assignee: null
depends_on: [STRUCT-002]
owns:
  - Source/SteeplejackSim/Public/Reachability.h
  - Source/SteeplejackSim/Private/Reachability.cpp
  - tests/unit/test_reachability.cpp
spec:
  - docs/03-tech/interfaces.md#simreachabilitygd--core-009
  - docs/03-tech/data-schemas.md#validation-rules-enforced-in-ci
  - docs/01-gdd/02-climbing-system.md#spans-and-flex
verify: make test-levels
editor_required: false
risk: R5
---

## Goal
Prove, headlessly, that a level's top can be reached with its authored ladder allowance at spans no worse than 6 m.

## Why
Authoring an unwinnable level is easy and the failure is invisible until someone plays it for twenty minutes. This catches it in seconds.

## Context
A greedy upward search over the joint grid is sufficient — we need existence, not optimality. Treat Cracked joints as unusable and free fixtures as usable. `tools/validate_data.py` already does a coarse arithmetic version of this check; the real one needs the grid.

## Interface
```cpp
class_name Reachability extends RefCounted
class Route:
    var anchors: Array[int]
    var sections: int
    var max_span: float
static func solve(grid: JointGrid, ladders: int, max_span: float) -> Route
```

## Acceptance
1. Both shipped levels return a valid route.
2. A fixture level with a 9 m band of Cracked joints and no free fixtures returns null.
3. A fixture with too few ladders for its height returns null.
4. `make test-levels` runs every file in `data/levels/` and fails CI on any error.
5. Solving a 110 m level takes under 500 ms.

## Out of scope
Not a route *recommender* — the player must find their own route. This only proves one exists.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
