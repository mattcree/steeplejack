---
id: VERB-007
title: Haul verb: gin wheel pendulum
milestone: M1
discipline: [ENG]
estimate_days: 2.5
status: ready
assignee: null
depends_on: [CORE-005, CORE-007]
owns:
  - sim/verbs/haul.gd
  - tests/unit/test_haul.gd
spec:
  - docs/03-tech/interfaces.md#simverbshaulgd--verb-007
  - docs/01-gdd/02-climbing-system.md#4--hauling--the-gin-wheel
  - docs/03-tech/adr/0002-physics-and-destruction.md#what-the-physics-engine-is-used-for
verify: make test-unit FILTER=test_haul
editor_required: false
risk: null
---

## Goal
A two-degree-of-freedom pendulum for hauled loads, steerable in antiphase to damp the swing.

## Why
The haul is the game's quiet moment and its best camera shot. It is also where the player learns that patience beats force.

## Context
An ODE at the fixed step, not a rope simulation (ADR-0002). Hauling faster adds amplitude; steering in antiphase damps it. Past `haul_foul_amplitude_degrees` the load fouls. Roughly thirty lines of code that carry enormous feel value — get the damping response right and it is instantly learnable.

## Interface
```gdscript
class_name HaulVerb extends RefCounted
class HaulState:
    var height: float
    var swing_deg: float
    var swing_vel: float
    var fouled: bool
static func step(s: HaulState, dt: float, pull: float, steer: float,
                 wind: float, load_kg: float, tuning: Tuning) -> void
```

## Acceptance
1. Pulling at full rate with no steering exceeds the foul threshold within 15 s.
2. Correct antiphase steering damps a 20 deg swing below 5 deg within 8 s.
3. Heavier loads swing slower and are harder to damp.
4. Wind adds a forcing term that the player can work against.
5. Deterministic and stable at the fixed step over 10,000 steps — no energy gain.

## Out of scope
No rope rendering, no camera work (CAM-002), no load-specific behaviour (steel bands are M3).

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
