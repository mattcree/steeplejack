---
id: VERB-006
title: Lash input alternatives (rotate / mash / hold)
milestone: M1
discipline: [ENG]
estimate_days: 0.5
status: ready
assignee: null
depends_on: [VERB-005]
owns:
  - Source/SteeplejackGame/Player/LashInput.cpp
  - Source/SteeplejackGame/Player/LashInput.h
spec:
  - docs/01-gdd/14-accessibility.md#motor
  - docs/01-gdd/11-camera-controls-feel.md#controls
verify: make test-unit FILTER=lashinput
editor_required: false
risk: null
---

## Goal
Three input methods for lashing that produce identical outcomes: stick rotation, button mash, and hold-only.

## Why
Stick rotation excludes players with motor impairments from a verb used on every single anchor. There is no version of this game that is playable without lashing.

## Context
All three must feed the same `rotation_rate` into `LashVerb.step`. Hold-only auto-wraps at a fixed rate — slower than expert rotation, faster than bad rotation, which is the right place for it.

## Acceptance
1. All three methods can complete a six-wrap lashing.
2. A test asserts the same wrap count and tension curve is reachable by each method.
3. Switching method mid-lash does not corrupt state.
4. The setting is available at every difficulty with no penalty or comment.

## Out of scope
Do not extend this to other verbs yet — the general hold-to-toggle system is A11Y-001.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
