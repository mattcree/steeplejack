---
id: CORE-002
title: Enable the Godot headless jobs in CI
milestone: M0
discipline: [ENG]
estimate_days: 1
status: ready
assignee: null
depends_on: [CORE-001]
owns:
  - .github/workflows/ci.yml
  - tests/run_tests.gd
  - Makefile
reads:
  - docs/06-workflow/03-verification.md
spec:
  - docs/06-workflow/03-verification.md#ci
  - docs/03-tech/adr/0003-determinism-and-testing.md#testing-strategy
verify: make ci
editor_required: false
risk: null
---

## Goal
Turn on the `engine` job group in CI so Godot unit tests run on every push.

## Why
The fast (Python) checks already run. Until the engine jobs run, `sim/` correctness is unverified and rungs 5-8 of the verification ladder are aspirational.

## Context
`.github/workflows/ci.yml` currently has the engine job marked `continue-on-error` with a note pointing at this task. GUT is the test runner. Pin the Godot version; do not use `latest`.

## Acceptance
1. `tests/run_tests.gd` runs GUT headlessly and exits non-zero on any failure.
2. The `engine` job no longer sets `continue-on-error`.
3. A deliberately failing test fails the workflow (demonstrate in the PR, then remove it).
4. The fast job group still completes in under 60 seconds.

## Out of scope
Do not add perf or visual jobs — those are nightly and come at M6.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
