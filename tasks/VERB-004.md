---
id: VERB-004
title: Anchor rating and capacity
milestone: M1
discipline: [ENG]
estimate_days: 1.5
status: ready
assignee: null
depends_on: [VERB-003]
owns:
  - Source/SteeplejackSim/Public/Anchor.h
  - Source/SteeplejackSim/Private/Anchor.cpp
  - tests/unit/test_anchor.cpp
spec:
  - docs/03-tech/interfaces.md#simanchorgd--verb-004
  - docs/01-gdd/02-climbing-system.md#anchor-rating
  - docs/01-gdd/10-failure-and-difficulty.md#the-fairness-contract
verify: make test-unit FILTER=anchor
editor_required: false
risk: R1
---

## Goal
Turn a seated dog into a rated anchor with an explicit kN capacity, including free fixtures.

## Why
The anchor rating is the game's central promise of fairness: the player is always told what they are hanging from. Everything in the failure model reads from here.

## Context
Player plus gear is 1.2 kN static, times 2.5 on a hard step. So Poor (1.0 kN) is a gamble on every move, Fair (2.5 kN) is fine if you are gentle, Sound (5.0 kN) is forgotten about. Free fixtures (old dogs, iron bands) are rated on inspection, not on placement — that is the speed-for-uncertainty gamble the grey-box level's third band is built around.

## Interface
```cpp
class_name AnchorModel extends RefCounted
static func rate(joint: Joint, depth: float, spall: float, tuning: Tuning) -> AnchorRate
static func capacity_kn(rate: AnchorRate, tuning: Tuning) -> float
static func make(joint: Joint, depth: float, spall: float, tuning: Tuning) -> Anchor
static func rate_free_fixture(band_params: Dictionary, rng: Rng, tuning: Tuning) -> AnchorRate
```

## Acceptance
1. All four rating outcomes are reachable and unit tested, including the bent-dog and spalled-brick paths.
2. A Cracked joint always rates FAILED regardless of depth.
3. An under-seated dog (depth below `dog_seat_depth_fraction`) rates one tier lower than the joint would allow.
4. Capacities match `climbing.json` exactly.
5. A property test: rating never improves as spall increases.
6. Free-fixture rating is deterministic for a given seed and band.

## Out of scope
Load distribution and cascade are CLIMB-002. HUD pips are UI-001.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
