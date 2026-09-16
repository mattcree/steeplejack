---
id: STRUCT-002
title: Joint grid generation from band definitions
milestone: M0
discipline: [ENG]
estimate_days: 2
status: ready
assignee: null
depends_on: [CORE-008, CORE-003]
owns:
  - sim/joints.gd
  - tests/unit/test_joints.gd
spec:
  - docs/03-tech/interfaces.md#simjointsgd--struct-002
  - docs/01-gdd/02-climbing-system.md#1-reading-the-brickwork
  - docs/03-tech/data-schemas.md#band-types-enum
verify: make test-unit FILTER=test_joints
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
```gdscript
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
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
