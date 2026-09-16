---
id: CORE-002
title: Self-hosted Unreal runner and the engine CI job
milestone: M0
discipline: [ENG, PROD]
estimate_days: 2
status: ready
assignee: null
depends_on: [CORE-001]
owns:
  - .github/workflows/ci.yml
  - docs/06-workflow/07-ci-runner.md
spec:
  - docs/06-workflow/03-verification.md#ci
  - docs/03-tech/adr/0004-engine-change-to-unreal.md#what-it-costs-and-the-mitigation
verify: a green run of the `game` job on a pull request
human_required: true  # provisioning physical CI hardware
editor_required: false
risk: R8
---

## Goal
Stand up a self-hosted runner with UE 5.5 and enable the `game` CI job.

## Why
GitHub-hosted runners cannot build Unreal — the engine is too large and the licence terms complicate
caching. Without a self-hosted runner the presentation layer has no automated verification at all.

## Context
The `fast` and `sim` jobs already run on GitHub-hosted runners and cover the whole gameplay layer;
this job only covers presentation. That asymmetry is by design (ADR-0004) and it means a red `game`
job is less urgent than a red `sim` job — but it still blocks merge once enabled.

The runner needs: UE 5.5, ~200 GB disk, Git LFS, and a warm DerivedDataCache. Document the setup in
`docs/06-workflow/07-ci-runner.md` so it can be rebuilt.

## Acceptance
1. A self-hosted runner tagged `unreal` is registered and building.
2. The `game` job's `if: false` is removed and it passes on a PR.
3. A deliberately broken UE automation test fails the job (demonstrate, then remove).
4. The `fast` job still completes in under 30 s and the `sim` job in under 2 minutes.
5. Runner setup is documented well enough to rebuild from scratch.
6. DerivedDataCache is shared between runs; a warm incremental build is under 10 minutes.

## Out of scope
No perf or screenshot jobs — nightly, at M6.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
