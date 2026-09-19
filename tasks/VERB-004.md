---
id: VERB-004
title: Anchor rating and capacity
milestone: M1
discipline: [ENG]
estimate_days: 1.5
status: review
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
**What changed:** `Anchor.h`/`Anchor.cpp` were built earlier with the tap test. This handoff
adds `tests/unit/test_anchor.cpp`, one test per criterion, and fixes the two criteria the code
got wrong:

- **Acceptance 2 was violated, and it was a gameplay bug.** Depth past the seat added a bonus to
  the score *before* the tier was chosen, so every cracked joint, even mid-band, rated **Poor**
  at full depth. A dog driven into a crack held 1 kN it should never have held, and the pip said
  Poor, so a player could trust it. Now a cracked joint is Failed before anything else is looked
  at. In the game, seating a dog there says "the joint is cracked — the dog went in but will hold
  nothing. Do not lash to it." instead of "Failed, 0.0 kN".
- **Acceptance 3 was contradicted.** The code, and an older test in `test_ascent.cpp`, said an
  unseated dog "holds nothing". The acceptance says one tier lower. The acceptance is the spec,
  so the code and the old test now follow it. The game only rates a dog once it is seated, so
  no play ever reached this.

Acceptance 1: all four ratings, plus the spalled-brick path. **The bent-dog path is not a
rating:** a strike that bends gains no depth and cannot be the blow that seats (tested). The game
then spoils the joint instead of rating anything. Acceptance 6 is `OldFixtures`: the same level
and seed give the same fixtures, and a different seed moves the rust. The interface's
`rate_free_fixture` became `OldFixtures` plus `Make` on the fixture's joint.

**Follow-ups:** none.
