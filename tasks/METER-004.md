---
id: METER-004
title: Nerve recovery: stand, brew up, cigarette, look at the view
milestone: M1
discipline: [ENG, ART]
estimate_days: 2
status: ready
assignee: null
depends_on: [METER-002]
owns:
  - Source/SteeplejackSim/Public/Recovery.h
  - Source/SteeplejackSim/Private/Recovery.cpp
  - tests/unit/test_recovery.cpp
  - Source/SteeplejackGame/Player/States/TeaState.cpp
spec:
  - docs/01-gdd/03-meters-grip-nerve.md#recovery
  - docs/01-gdd/12-audio-design.md#music
  - docs/01-gdd/11-camera-controls-feel.md#camera
verify: make test-unit FILTER=test_recovery, plus a video of the tea break for review.
editor_required: false
risk: null
---

## Goal
Four nerve recovery actions, with the tea break built as a proper twelve-second set-piece.

## Why
The brew-up is the most characterful thing in the game. Players will do it when they do not need to, which is exactly the point — and it is one of the things the M3 playtest measures.

## Context
Tea: 12 s, camera locks to a slow fixed framing, wind noise drops, a flugelhorn cue plays, the character says something. Same cue every time so it becomes a comfort. The cigarette is the tempting bad option: fast, works anywhere, permanently lowers your ceiling for the shift. 'Look at the view' is a reward for the thing we want the player to do anyway.

## Acceptance
1. All four actions restore the tuned amounts over the tuned durations.
2. The cigarette reduces max nerve by 5 for the rest of the shift and this persists.
3. Tea requires a stable stance and both hands free; it is refused otherwise with a clear reason.
4. Interrupting tea part-way grants proportional recovery, not zero.
5. 'Look at the view' requires facing outward above 20 m.
6. The tea camera framing, audio duck and duration match the spec.

## Out of scope
The music cue itself is an M3 audio task; use a placeholder. No flask inventory (M3).

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
