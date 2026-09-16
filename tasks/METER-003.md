---
id: METER-003
title: Wobble — the one number every verb reads
milestone: M1
discipline: [ENG]
estimate_days: 0.5
status: ready
assignee: null
depends_on: [METER-002]
owns:
  - Source/SteeplejackSim/Public/Wobble.h
  - Source/SteeplejackSim/Private/Wobble.cpp
  - tests/unit/test_wobble.cpp
spec:
  - docs/01-gdd/03-meters-grip-nerve.md#interaction-between-the-two
  - docs/00-vision.md#anti-pillars-things-we-will-not-do
verify: make test-unit FILTER=wobble
editor_required: false
risk: R7
---

## Goal
A single function that computes reticle wobble from grip, nerve, stance and wind gust.

## Why
Four systems push on one number and every skill verb reads it. Centralising it is what stops the game accumulating a third meter and a dozen special cases.

## Context
**This is the only place wobble may be computed.** A verb that computes its own wobble is rejected in review — see the anti-pillars. If a verb needs different wobble behaviour, it takes a multiplier, it does not reimplement the function.

## Interface
```cpp
class_name Wobble extends RefCounted
static func amplitude_deg(m: Meters, ctx: MeterContext, gust: float, tuning: Tuning) -> float
```

## Acceptance
1. Output matches the product of base, stance, grip, nerve and gust multipliers from `meters.json`.
2. Wobble is 1.0x base with full grip, calm nerve, belted stance and no gust.
3. Wobble reaches 6x base at zero grip, zero nerve, one-handed, in a gust.
4. A grep across `SteeplejackSim` finds no other wobble computation (asserted by a convention check added in this task).
5. Pure and deterministic.

## Out of scope
Do not add per-verb wobble behaviour here. Verbs scale the result.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
