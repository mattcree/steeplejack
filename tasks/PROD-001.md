---
id: PROD-001
title: Confirm ADR-0001 (engine choice) with the project lead
milestone: M0
discipline: [PROD]
estimate_days: 0.5
status: ready
assignee: null
depends_on: []
owns:
  - docs/03-tech/adr/0001-engine-choice.md
spec:
  - docs/03-tech/adr/0001-engine-choice.md#decision
  - docs/03-tech/architecture.md#repository-layout
verify: grep -q 'Status:\*\* Accepted' docs/03-tech/adr/0001-engine-choice.md
editor_required: false
risk: null
---

## Goal
Get an explicit yes or no on Godot 4 as the engine, and record it.

## Why
Every M0 task assumes Godot. Reversal is free now and costs ~4 months after M3. This is the cheapest decision in the project and the most expensive one to defer.

## Context
ADR-0001 documents the alternative (three.js + TypeScript + Rapier) fully costed. The design docs and `sim/` are engine-agnostic by construction, so a reversal would cost the render/animation/UI layer only. Present the trade honestly; do not advocate.

## Acceptance
1. The ADR's `Status:` line reads `Accepted` or `Rejected` (not `Proposed`).
2. If rejected, a new ADR-0004 records the chosen engine and the tasks in M0 are re-scoped in the same PR.
3. The `Deciders:` line names a real person.

## Out of scope
Do not start CORE-001 before this is Accepted.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
