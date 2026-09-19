---
id: VERB-007
title: Haul verb: gin wheel pendulum
milestone: M1
discipline: [ENG]
estimate_days: 2.5
status: review
assignee: null
depends_on: [CORE-005, CORE-007]
owns:
  - Source/SteeplejackSim/Public/Verbs/Haul.h
  - Source/SteeplejackSim/Private/Verbs/Haul.cpp
  - tests/unit/test_haul.cpp
spec:
  - docs/03-tech/interfaces.md#simverbshaulgd--verb-007
  - docs/01-gdd/02-climbing-system.md#4--hauling--the-gin-wheel
  - docs/03-tech/adr/0002-physics-and-destruction.md#what-the-physics-engine-is-used-for
verify: make test-unit FILTER=haul
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
```cpp
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
**What changed:** `sj::haul::Step` is a semi-implicit pendulum on a shortening rope, as ADR-0002
asks: θ'' = −(g/L)·sin θ − c·θ' + (pump + steer + wind)/m. `AmplitudeDeg` gives the swing's
amplitude from its angle and velocity, for the meter. `Arrived` says when the load is up.
`tests/unit/test_haul.cpp` states the five acceptance criteria as five tests, plus two more
("steering *with* the swing makes it worse", and "patience beats force": full-speed hauling with an
antiphase hand arrives clean). The Godot binding (`haul_begin`/`haul_step`) and the gin wheel in
`godot/scripts/player.gd` are the ADR-0006 replacement for the Unreal side. They are outside this
task's `owns` and declared here.

**Decisions made:** the interface above is the GDScript sketch from before ADR-0004. The C++
signature is in `docs/03-tech/interfaces.md`. The two constants that predate the model,
`haulSwingGainPerSpeed` and `haulSwingDampPerSteerInput`, had no units and failed acceptance 1 or 2
whichever way they were read. They were recalibrated against the tests to 1.9 and 4.6.
`haulAirDampingPerSecond` and `haulWindDegPerS2PerMs` are new tuning keys.

**Surprises:** acceptance 5, "no energy gain", passes with an explicit integrator too, as long as
the real damping is left in: damping removes more than the integrator adds. So a test run with the
real tuning could never fail. The test builds an undamped tuning of its own, so that the integrator
is the only thing that can add or remove energy. It also checks the swing has not quietly bled away.

**Follow-ups:** CAM-002's haul shot exists in Godot (camera down the rope, facing the wall). The
full-ascent test (`godot/scripts/test_ascent.gd`) hauls ten sections to 55 m with an antiphase
hand, and none fouls.
