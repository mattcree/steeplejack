---
id: CORE-005
title: Fixed-step simulation driver with render interpolation
milestone: M0
discipline: [ENG]
estimate_days: 1.5
status: ready
assignee: null
depends_on: [CORE-004, CORE-007]
owns:
  - Source/SteeplejackSim/Public/Clock.h
  - Source/SteeplejackSim/Private/Clock.cpp
  - tests/unit/test_clock.cpp
  - Source/SteeplejackGame/SteeplejackGameMode.h
  - Source/SteeplejackGame/SteeplejackGameMode.cpp
spec:
  - docs/03-tech/interfaces.md#simclockgd--core-005
  - docs/03-tech/adr/0003-determinism-and-testing.md#the-split
  - docs/03-tech/architecture.md#the-frame
verify: make test-unit FILTER=clock
editor_required: false
risk: null
---

## Goal
Step the simulation at exactly 60 Hz regardless of frame rate, and interpolate presentation between steps.

## Why
Everything downstream — determinism, replay, the whole test strategy — rests on the sim advancing in fixed, reproducible increments. Getting this wrong invalidates every test in the project.

## Context
Accumulator pattern; see the pseudocode in `docs/03-tech/architecture.md` under 'The frame'. Clamp the accumulator to avoid a spiral of death after a long frame (cap at 5 steps). `alpha()` is what presentation lerps with. Delete `game/bootstrap.*` as part of this task and point `project.godot` at `main.tscn`.

## Interface
```cpp
class_name SimClock extends RefCounted
const TICK: float = 1.0 / 60.0
func advance(real_delta: float) -> int
func alpha() -> float
```

## Acceptance
1. Feeding 1.0 s of deltas in 30 fps chunks yields exactly 60 steps; so does feeding it in 144 fps chunks.
2. `alpha()` stays in [0, 1).
3. A 2-second stall produces at most 5 steps, not 120.
4. `sim.step` timing is instrumented and printed in dev builds.
5. `game/bootstrap.*` is deleted and `main.tscn` is the main scene.

## Out of scope
Do not add the intent recorder — CORE-006 — or any gameplay.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
