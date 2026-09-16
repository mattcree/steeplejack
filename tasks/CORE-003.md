---
id: CORE-003
title: Seeded RNG with independent substreams
milestone: M0
discipline: [ENG]
estimate_days: 0.5
status: in_progress
assignee: agent
depends_on: [CORE-001]
owns:
  - Source/SteeplejackSim/Public/Rng.h
  - Source/SteeplejackSim/Private/Rng.cpp
  - tests/unit/test_rng.cpp
spec:
  - docs/03-tech/interfaces.md#simrnggd--core-003
  - docs/03-tech/adr/0003-determinism-and-testing.md#the-split
verify: make test-unit FILTER=rng
editor_required: false
risk: null
---

## Goal
A deterministic xorshift128 RNG with forkable substreams.

## Why
Determinism is the foundation of replay regression, which is the highest-leverage test in the project. Engine RNG cannot give us that.

## Context
`fork(tag)` is the important part: each subsystem takes its own substream so that adding one random call in the weather system does not shift every value in the joint grid and invalidate every recorded replay. Same tag must always give the same stream.

## Interface
```cpp
class_name Rng extends RefCounted
func _init(seed: int) -> void
func next_u32() -> int
func next_float() -> float
func range_float(lo: float, hi: float) -> float
func range_int(lo: int, hi: int) -> int
func pick_weighted(weights: Array[float]) -> int
func fork(tag: int) -> Rng
func state() -> PackedInt64Array
func restore(s: PackedInt64Array) -> void
```

## Acceptance
1. Same seed produces an identical 10,000-value sequence across two separate instances.
2. `fork(7)` from the same parent state always yields the same substream.
3. Adding a `next_float()` call to a forked stream does not change the parent stream's output.
4. `state()` / `restore()` round-trips exactly mid-sequence.
5. `pick_weighted` over `[0.6, 0.3, 0.1]` lands within 1% of those proportions over 100,000 draws.

## Out of scope
No noise functions, no shuffle helpers — add them when a task needs them.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
