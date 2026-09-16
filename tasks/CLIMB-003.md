---
id: CLIMB-003
title: Ladder stack rendering and flex (ISM + material custom data)
milestone: M1
discipline: [TECH-ART, ENG]
estimate_days: 2
status: ready
assignee: null
depends_on: [CLIMB-001]
owns:
  - Source/SteeplejackGame/Structures/LadderStackComponent.h
  - Source/SteeplejackGame/Structures/LadderStackComponent.cpp
  - Content/Materials/M_LadderFlex.uasset
spec:
  - docs/01-gdd/02-climbing-system.md#spans-and-flex
  - docs/01-gdd/11-camera-controls-feel.md#feel--the-non-negotiables
  - docs/03-tech/performance-budget.md#things-that-will-hurt-if-we-let-them
verify: Visual check at 3, 5, 7 and 9 m spans; stat command asserts one ISM for the whole stack.
editor_required: false
risk: null
---

## Goal
Render the whole ladder stack as one instanced static mesh, with a world-position-offset material
that bends each section by its span and load.

## Why
Flex communicates the single most important risk number in the game with no UI at all. It costs a
material node graph and a per-instance float, and it is how the player learns to fear a long span.

## Context
Per-instance custom data float carries deflection from `sj::Stack::FlexDeflectionM`. A visible
bounce as the player climbs sells it. **One ISM for the entire stack** — 28 sections must not be 28
actors. Megascans weathered timber for the material base.

## Acceptance
1. The whole stack renders as one `InstancedStaticMeshComponent` regardless of section count.
2. Bend is clearly visible at 5 m and imperceptible at 3 m.
3. Climbing a flexing section produces a visible bounce driven by player position.
4. No popping when a section changes span band.
5. Under 1.5k triangles per section; WPO cost within the base-pass budget.
6. Collision follows the bent geometry closely enough that IK contact stays correct.

## Out of scope
No breakage animation on buckle (a later VFX task). No ladder condition visuals.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
