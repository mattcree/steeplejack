---
id: CLIMB-006
title: Stack serialisation (the checkpoint)
milestone: M1
discipline: [ENG]
estimate_days: 1
status: ready
assignee: null
depends_on: [CLIMB-002]
owns:
  - Source/SteeplejackSim/Private/StackSerialise.cpp
  - tests/unit/test_save.cpp
spec:
  - docs/01-gdd/02-climbing-system.md#the-ladder-stack-is-the-checkpoint
  - docs/03-tech/architecture.md#save-data
  - docs/01-gdd/10-failure-and-difficulty.md#5-the-fall
verify: make test-unit FILTER=save
editor_required: false
risk: null
---

## Goal
Serialise and restore the ladder stack, because the stack is the game's only checkpoint.

## Why
No save points, no flags — progress is the structure the player built. This unifies mechanic and system, and it means checkpointing costs the player material and time.

## Context
Serialise the stack, not the player. On resume the player starts at the bottom of their own ladders with the shift reset. Version the format from day one; a save that cannot be migrated is a bug report you cannot reproduce.

## Acceptance
1. A 14-section stack round-trips with identical anchors, spans, lashings and conditions.
2. The format carries a version field and an unknown version fails with a clear message.
3. Round-trip is byte-identical on a second save.
4. Serialising a 28-section stack produces under 20 KB.
5. Restoring a stack whose level JSON has changed fails loudly rather than producing a corrupt route.

## Out of scope
No career save (money, reputation, the engine) — that is M3.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
