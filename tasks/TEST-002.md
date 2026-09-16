---
id: TEST-002
title: Replay regression harness
milestone: M1
discipline: [ENG]
estimate_days: 1
status: ready
assignee: null
depends_on: [CORE-006, LVL-000]
owns:
  - tests/replay/regression.cpp
  - data/replays/00-greybox-expert.replay
spec:
  - docs/06-workflow/03-verification.md#rung-7-is-the-one-that-matters
  - docs/03-tech/adr/0003-determinism-and-testing.md#recording-and-replay
verify: make test-replay
editor_required: false
risk: null
---

## Goal
Replay a recorded expert run of the grey-box level in CI and fail on any change to the outcome.

## Why
The highest-leverage test in the project. It turns a tuning change into a readable diff of two outcomes, which is how the game gets balanced without playing it twelve times.

## Context
Record an expert run of the grey-box level by hand. The harness replays it headlessly and asserts final state: anchors placed, ratings, spans, time taken, grip and nerve at the summit. When a change legitimately alters the outcome, re-record and put the diff in the PR body — the diff *is* the justification.

## Acceptance
1. `make test-replay` replays the recorded run and passes.
2. Changing a value in `climbing.json` makes it fail with a readable before/after diff.
3. The diff names the fields that changed, not just 'mismatch'.
4. The harness runs in under 60 s.
5. A documented one-command path exists to re-record: `make record LEVEL=00-greybox`.

## Out of scope
Per-level invoices need the scoring model (M2). Assert climbing state for now.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
