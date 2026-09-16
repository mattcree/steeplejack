---
id: STRUCT-001
title: Procedural chimney builder
milestone: M0
discipline: [ENG, TECH-ART]
estimate_days: 3
status: ready
assignee: null
depends_on: [CORE-008]
owns:
  - game/structures/chimney_builder.gd
  - game/structures/profile.gd
  - game/structures/chimney.tscn
spec:
  - docs/03-tech/architecture.md#procedural-structure-generation
  - docs/01-gdd/13-art-direction.md#procedural-chimney-generation
  - docs/03-tech/data-schemas.md#level-file
  - docs/03-tech/performance-budget.md#scene-budgets
verify: make test-levels
editor_required: false
risk: R5
---

## Goal
Generate a chimney mesh from a level's `structure` block: profile curve, batter steps, bands and cap.

## Why
Twelve levels are only affordable because no chimney is hand-modelled. This builder is the production system that makes idea-to-playable under thirty minutes possible.

## Context
Lathe from a profile curve. Round profile only for M0; octagonal, square and square-to-round come at M3 (STRUCT-003). One draw call for the shaft — if you find yourself making a node per band, stop. Weathering parameters go out as per-instance shader uniforms; the brick shader itself is ART-010 at M3, so a flat placeholder material is correct here.

## Acceptance
1. A 70 m chimney from `06-waterside.json` builds in a single `MeshInstance3D` with one surface.
2. Iron bands at 36 m and 48 m appear at the right heights as separate instanced geometry.
3. The corbelled cap oversails and is climbable-under (an overhang, for later).
4. Build time for a 110 m chimney is under 200 ms.
5. Triangle count for a 70 m chimney is under 8,000.
6. Changing `height` in the JSON and reloading changes the chimney with no code change.

## Out of scope
No brick texture or weathering shader (ART-010, M3). No pre-fracture (FELL-007, M4). No topping cell grid (TOP-001, M4).

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
