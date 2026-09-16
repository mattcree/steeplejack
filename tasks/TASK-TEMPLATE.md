---
id: AREA-NNN
title: <one line, under 70 chars>
milestone: M0
discipline: [ENG]
estimate_days: 1
status: draft
assignee: null
depends_on: []
owns:
  - Source/SteeplejackSim/Public/YourThing.h
reads:
  - Source/SteeplejackSim/Public/Types.h
spec:
  - docs/01-gdd/xx.md#section-anchor
verify: make test-unit FILTER=YourThing
editor_required: false
risk: null
---

## Goal
One sentence. What exists at the end that does not exist now.

## Why
Why this matters, pointing at a pillar or a spec decision. Two sentences at most.

## Context
What an agent needs that is not obvious from the spec links: prior art in the repo, gotchas,
approaches already rejected and why. Link, don't copy.

## Interface
The exact signatures this task must provide and consume, copied from
`docs/03-tech/interfaces.md` so the task is self-contained.

## Acceptance
1. Checkable criterion.
2. Checkable criterion.

## Out of scope
What a well-meaning agent will be tempted to also do. Say no here.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups created. -->
