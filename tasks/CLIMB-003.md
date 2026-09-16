---
id: CLIMB-003
title: Ladder flex shader and instancing
milestone: M1
discipline: [TECH-ART]
estimate_days: 2
status: ready
assignee: null
depends_on: [CLIMB-001]
owns:
  - game/structures/ladder.gd
  - game/structures/ladder_flex.gdshader
spec:
  - docs/01-gdd/02-climbing-system.md#spans-and-flex
  - docs/01-gdd/11-camera-controls-feel.md#feel--the-non-negotiables
  - docs/03-tech/performance-budget.md#performance-critical-paths
verify: Visual check at 3, 5, 7 and 9 m spans; perf check asserts one draw call for the whole stack.
editor_required: false
risk: null
---

## Goal
Render the ladder stack as one MultiMesh with a vertex shader that bends each section by its span and load.

## Why
Flex communicates the single most important risk number in the game with no UI at all. It is a vertex shader and a spring, it costs nothing, and it is how the player learns to fear a long span.

## Context
Per-instance uniform carries deflection from `Stack.flex_deflection_m`. A visible bounce as the player climbs sells it. One draw call for the entire stack — 28 sections must not be 28 nodes.

## Acceptance
1. The whole stack renders in one draw call regardless of section count.
2. Bend is clearly visible at 5 m and imperceptible at 3 m.
3. Climbing a flexing section produces a visible bounce driven by player position.
4. No visual popping when a section changes span band.
5. Under 400 triangles per section.

## Out of scope
No breakage animation on buckle (that is a later VFX task). No ladder condition visuals.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
