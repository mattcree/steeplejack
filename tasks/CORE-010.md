---
id: CORE-010
title: Git LFS and the Content size gate
milestone: M0
discipline: [ENG, PROD]
estimate_days: 0.5
status: ready
assignee: null
depends_on: [CORE-001]
owns:
  - .gitattributes
  - tools/check_content_size.py
spec:
  - docs/03-tech/adr/0004-engine-change-to-unreal.md#other-costs-accepted
  - docs/03-tech/performance-budget.md#scene-budgets
verify: python3 tools/check_content_size.py, and a test asset round-trips through LFS.
editor_required: false
risk: null
---

## Goal
Git LFS configured and enforced before the first binary asset lands, plus a nightly size gate.

## Why
`Content/` is binary and unmergeable. Retrofitting LFS after assets are committed means rewriting
history, which is painful and breaks everyone's clones. **This must land before ART-010 or ART-020.**

## Context
`.gitattributes` already declares the LFS patterns but LFS has never been initialised on the remote
and no asset has been through it. Verify the round-trip with a real test asset before trusting it.

Cap is 25 GB (see the performance budget). At photoreal fidelity with Megascans that is reachable,
so the gate needs to exist from the start rather than being added when it is already breached.

## Acceptance
1. `git lfs install` documented in the README, and the remote has LFS enabled.
2. A test `.uasset` commits, pushes, clones fresh and round-trips byte-identical.
3. `tools/check_content_size.py` reports `Content/` size and fails over 25 GB.
4. It runs nightly in CI and warns at 20 GB.
5. The `fast` CI job still clones with `lfs: false` and stays under 30 s.

## Out of scope
No asset pipeline or import automation. Just the plumbing and the gate.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
