---
id: STRUCT-001
title: Procedural chimney builder (Nanite)
milestone: M0
discipline: [ENG, TECH-ART]
estimate_days: 3
status: ready
assignee: null
depends_on: [CORE-008]
owns:
  - Source/SteeplejackGame/Structures/ChimneyBuilder.h
  - Source/SteeplejackGame/Structures/ChimneyBuilder.cpp
  - Source/SteeplejackGame/Structures/ProfileCurve.h
spec:
  - docs/03-tech/architecture.md#procedural-structure-generation
  - docs/01-gdd/13-art-direction.md#geometry
  - docs/03-tech/data-schemas.md#level-file
  - docs/03-tech/performance-budget.md#scene-budgets
verify: make test-levels, plus a visual check that a 70 m chimney builds as one Nanite primitive.
editor_required: false
risk: R5
---

## Goal
Generate a chimney mesh from a level's `structure` block — profile curve, batter steps, bands, cap —
as a single Nanite primitive.

## Why
Twelve levels are only affordable because no chimney is hand-modelled. This builder is the
production system that makes idea-to-playable-in-thirty-minutes possible, and it is what lets the
project hit photoreal fidelity without an art team.

## Context
Generate with GeometryScript at load, then convert to Nanite. Round profile only for M0; octagonal,
square and square-to-round come at M3 (STRUCT-003).

The brick **master material** (ART-010) is a separate task and is the thing that carries the
gameplay read; this task just needs correct UVs and per-instance parameter plumbing for soot
gradient, salt bloom, erosion and cracking. A grey placeholder material is correct here.

## Acceptance
1. A 70 m chimney from `06-waterside.json` builds as one Nanite-enabled primitive.
2. Iron bands at 36 m and 48 m appear at the right heights as separate instanced geometry.
3. The corbelled cap oversails and is climbable-under (an overhang, for later).
4. Build time for a 110 m chimney is under 400 ms.
5. UV layout supports world-aligned brick tiling with no visible seam on the shaft.
6. Changing `height` in the JSON and reloading changes the chimney with no code change.

## Out of scope
The brick material is ART-010. Pre-fracture is FELL-007 (M4). The topping cell grid is TOP-001 (M4).

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
