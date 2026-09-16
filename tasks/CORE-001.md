---
id: CORE-001
title: Godot project skeleton and bootstrap scene
milestone: M0
discipline: [ENG]
estimate_days: 0.5
status: ready
assignee: null
depends_on: [PROD-001]
owns:
  - project.godot
  - game/bootstrap.gd
  - game/bootstrap.tscn
reads:
  - docs/03-tech/architecture.md
  - docs/03-tech/adr/0001-engine-choice.md
spec:
  - docs/03-tech/adr/0001-engine-choice.md#decision
  - docs/03-tech/architecture.md#repository-layout
  - docs/03-tech/performance-budget.md#targets
verify: godot --path . --headless --quit
editor_required: false
risk: null
---

## Goal
A Godot 4.4 project that opens, runs headless, and exits zero.

## Why
Everything in M0 depends on a project that boots. Nothing else.

## Context
`project.godot` already exists in skeleton form. Set the Forward+ renderer, a 60 Hz physics tick, Jolt, and GDScript warnings-as-errors for untyped declarations (that last one is what makes rule 1 of the conventions enforceable at compile time).

## Acceptance
1. `godot --path . --headless --quit` exits 0 with no errors or warnings.
2. `physics/common/physics_ticks_per_second` is 60 and `physics_jitter_fix` is 0.0.
3. `debug/gdscript/warnings/untyped_declaration` is set to error (2).
4. `game/bootstrap.tscn` is the main scene and prints one line confirming the tuning directory was found.

## Out of scope
Do not add the fixed-step driver — that is CORE-005, which replaces bootstrap with main.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
