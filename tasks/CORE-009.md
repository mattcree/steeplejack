---
id: CORE-009
title: Reachability solver and level validation gate
milestone: M0
discipline: [ENG]
estimate_days: 2
status: review
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
**What changed:** `Reachability.h`/`Reachability.cpp` and `tests/unit/test_reachability.cpp`,
as owned. **Outside `owns`, declared:**

- `Level.h`/`Level.cpp` gain `LoadoutLadders()`, parsed from `loadoutHint.ladders`.
- `climbing.json` gains three keys that mirror the game's geometry:
  - `climberShoulderAboveFeetMetres` 1.45 (player.gd's CAPSULE_HALF + 0.55)
  - `climberWallStandoffMetres` 0.65 (LADDER_STANDOFF + BODY_OFF_LADDER)
  - `ladderCoversMetres` 0.30 (face.gd's UNDER_LADDER)
- The binding gains `loadout_ladders()`, and **the game now fills the cradle from the level**. It
  was a hard-coded 12 against the Grey Box's 14, so a careful player could run out of ladder on
  a level this gate had passed.

1. and 4. One test solves every file in `data/levels/` with its own loadout and the grid the game
   builds (the level's seed, the game's climbing line). All three are climbable at 6 m.
   `make test-levels` already filters on `*Reachability*`, so a new level is gated the day it is
   added.
2. A 9 m cracked band is not crossable, and the route stops at the crack. A control with the
   crack healed is climbable.
3. Three ladders for 40 m fails, and twelve succeed.
5. 110 m solves in about 0.2 ms, against a 500 ms budget.

A fifth test shows the span limit is really read: a 5 m crack is crossable at 6 m and not at 4 m.

**Decisions made:** greedy (from each dog, the highest usable joint in reach) is exact for
existence here. A higher dog's next window reaches at least as high, so nothing a lower dog could
do is lost. Reach is checked from every stance on the section, not just the top, because a joint
the span allows may only be reachable standing lower.

The game reads the same keys: `player.gd`'s targeting and lean work from `shoulders()`
(`climberShoulderAboveFeetMetres`), and `face.gd`'s `under_ladder` uses `ladderCoversMetres`.
The gate and the game cannot drift apart on what "in reach" means. `climberWallStandoffMetres`
is still the sum of two scene constants (LADDER_STANDOFF + BODY_OFF_LADDER), because it places
geometry rather than deciding anything.

**Follow-ups:** none.
