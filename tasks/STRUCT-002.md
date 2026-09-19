---
id: STRUCT-002
title: Joint grid generation from band definitions
milestone: M0
discipline: [ENG]
estimate_days: 2
status: review
assignee: null
depends_on: [CORE-008, CORE-003]
owns:
  - Source/SteeplejackSim/Public/Joints.h
  - Source/SteeplejackSim/Private/Joints.cpp
  - tests/unit/test_joints.cpp
spec:
  - docs/03-tech/interfaces.md#simjointsgd--struct-002
  - docs/01-gdd/02-climbing-system.md#1-reading-the-brickwork
  - docs/03-tech/data-schemas.md#band-types-enum
verify: make test-unit FILTER=joints
editor_required: false
risk: R1
---

## Goal
Turn a level's band list into a deterministic grid of candidate mortar joints with hidden quality and derived tier.

## Why
The joint grid is the gameplay surface of every structure in the game. Everything the player reads, taps and hammers comes from here.

## Context
Candidate density is roughly one joint per 0.25 m^2 of face (`structure.jointGrid.candidateDensity`). Quality is drawn from each band's distribution using a forked RNG substream so that other systems' random calls never shift it. `params.forcePerishedAt` / `forceCrackedAt` place authored joints at exact heights — level 1 depends on this to put a cracked joint on the obvious climbing line.

## Interface
```cpp
class_name JointGrid extends RefCounted
static func generate(level: LevelData, rng: Rng, tuning: Tuning) -> JointGrid
func at_height(h: float, tolerance: float) -> Array[Joint]
func nearest(pos: Vector3, max_range: float) -> Joint
func by_id(id: int) -> Joint
func count() -> int
func band_at(h: float) -> String
```

## Acceptance
1. Generating twice from the same seed produces identical grids.
2. Realised tier proportions within each band match the authored distribution to within 2% over the band's joints.
3. `forceCrackedAt: [7.0]` on level 1 produces a Cracked joint within 0.1 m of 7.0 m.
4. `nearest()` returns a null-object Joint (not `null`) when nothing is in range.
5. A 110 m chimney generates in under 50 ms.
6. Adding an RNG call elsewhere in the sim does not change the generated grid.

## Out of scope
No visual representation — the brick shader reads this later. No occupancy logic beyond the `occupied` flag.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
**What changed:** the grid is `Source/SteeplejackSim/Public/JointGrid.h` and
`Private/JointGrid.cpp`, and the tests are `tests/unit/test_joint_grid.cpp`, not
`Joints.h`/`Joints.cpp`/`test_joints.cpp`. Those are the declared deviations from `owns`. The six
acceptance criteria are six tests named "JointGrid: acceptance 1" to "6". Nine more cover
clustering, the visual tell's reliability per band, forced joints and the old fixtures.

**Decisions made:** each band's tiers are stratified, not drawn independently. A band of 40
joints gets its authored proportions to the joint, which is what makes acceptance 2's "within 2%"
hold on short bands. The visual tell (`Apparent`) is only as good as the band's
`visualReadReliability`, and the misreads are seeded, so the same joint lies the same way every
time. The grid is generated on its own fork of the level seed (acceptance 6).

**Surprises:** authored joints (`forceCrackedAt`) overwrote each other when two fell in one
course. They are collected first and placed after.

**Follow-ups:** none.
