---
id: CLIMB-002
title: Load sharing and cascade failure
milestone: M1
discipline: [ENG]
estimate_days: 2
status: blocked
assignee: null
depends_on: [CLIMB-001]
owns:
  - Source/SteeplejackSim/Public/Load.h
  - Source/SteeplejackSim/Private/Load.cpp
  - tests/unit/test_load.cpp
spec:
  - docs/03-tech/interfaces.md#simloadgd--climb-002
  - docs/01-gdd/02-climbing-system.md#load-sharing--why-old-mistakes-matter
  - docs/01-gdd/10-failure-and-difficulty.md#the-fairness-contract
verify: make test-unit FILTER=load
editor_required: false
risk: R1
---

## Goal
Distribute load down the stack with exponential falloff, and resolve progressive anchor failure in order.

## Why
This is what makes the corner you cut ten minutes ago still matter. Cascade failure is the game's most dramatic event and the player must always be able to trace it.

## Context
Falloff 0.55, so the top three anchors take about 80%. Cascade returns failed anchor indices in failure order so the HUD can burn them down the screen like a fuse. Fully deterministic — no RNG anywhere in this module.

## Interface
```cpp
class_name LoadModel extends RefCounted
static func share(stack: Stack, at_section: int, total_kn: float, tuning: Tuning) -> Array[float]
static func apply(stack: Stack, at_section: int, total_kn: float, tuning: Tuning) -> void
static func cascade(stack: Stack, failed_anchor: int, tuning: Tuning) -> Array[int]
```

## Acceptance
1. Shares sum to the total load, to within floating-point tolerance.
2. The top three anchors take 78-82% of load on a 12-section stack.
3. A Poor anchor under 1.2 kN static holds; under a 2.5x dynamic factor it fails.
4. Cascade from anchor 8 fails 7, 6, 5 in that order on a stack of Poor anchors, deterministically.
5. Cascade stops at the first anchor with capacity to absorb the redistributed load.
6. Two identical cascades produce identical index arrays.

## Out of scope
No visual or audio feedback — UI-001 renders the fuse.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked

**Not blocking the build — a question about which of two numbers is the design.**

*The question.* Acceptance 2 asks for the top three anchors to take 78-82% of the load on a
12-section stack, and the context says "falloff 0.55, so the top three anchors take about 80%". They
disagree. `0.55^n` normalised over the chain puts 83.4% on the top three (over twelve dogs and the
ground; 83.4% over twelve dogs alone as well — the tail is too small to matter).

*What I did.* Implemented the data exactly as written, and tested the formula rather than the range,
so the number moves as soon as the falloff does. `test_stack.cpp` documents the disagreement in the
case that would otherwise assert the range.

*Options.* (a) Widen the acceptance to about 83% — the GDD's formula and `climbing.json` agree with
each other and only the range is off. (b) Set `loadShareFalloff` to 0.585, which gives 80.1%.

*Recommendation.* (a). "About 80%" was describing the formula, and 83% is about 80%. Changing a
tuning target to fit an acceptance range written from a mental approximation of it would be the
wrong way round.

## Outcome
**What changed:** built inside `Stack.h`/`Stack.cpp`, with the tests in
`tests/unit/test_stack.cpp`, not `Load.h`/`Load.cpp`/`test_load.cpp`. Load sharing and cascade
act on the stack's own anchors, and a separate module would have had to mirror them. That is the
declared deviation from `owns`. Criteria 1 and 3–6 are the "Stack: acceptance N" tests in the
CLIMB-002 block. Criterion 2 is the open question above, and it has a test that documents it
rather than a range check.

**Status is `blocked`** only so that it matches BLOCKED.md. Everything is built, and the answer
changes one tuning number or one acceptance line.
