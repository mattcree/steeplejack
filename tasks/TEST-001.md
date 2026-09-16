---
id: TEST-001
title: Sim coverage gate
milestone: M1
discipline: [ENG]
estimate_days: 1
status: ready
assignee: null
depends_on: [METER-005, CLIMB-006, VERB-007, CORE-009, VERB-002]
owns:
  - tools/coverage.py
  - tests/perf/test_step_budget.cpp
spec:
  - docs/06-workflow/03-verification.md#coverage
  - docs/03-tech/adr/0003-determinism-and-testing.md#testing-strategy
verify: make test-coverage
editor_required: false
risk: null
---

## Goal
Fail CI if `SteeplejackSim` line coverage drops below 90%.

## Why
The sim/presentation split exists so that all the logic lives somewhere it can be tested exhaustively. A coverage gate is what stops that eroding one untested branch at a time.

## Context
`game/` is deliberately not coverage-gated — it is presentation and its correctness is visual. Report per-module so it is obvious which module regressed.

## Acceptance
1. Coverage is measured across `SteeplejackSim` only.
2. The gate fails below 90%.
3. Output is per-module so a regression is attributable.
4. Runs in under 30 s.
5. Current coverage at time of merge is recorded in `## Outcome`.

## Out of scope
No coverage requirement on `game/`.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
