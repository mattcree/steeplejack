---
id: CORE-003
title: Seeded RNG with independent substreams
milestone: M0
discipline: [ENG]
estimate_days: 0.5
status: ready
assignee: null
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
*Amended during implementation: the block below was **GDScript** (`class_name Rng extends
RefCounted`, `PackedInt64Array`), stale since [ADR-0004](../docs/03-tech/adr/0004-engine-change-to-unreal.md)
moved the project to C++. The authoritative signature is
[`interfaces.md#rngh--core-003`](../docs/03-tech/interfaces.md), which was already correct; this
block now matches it. See the Outcome.*

```cpp
class Rng {
public:
    explicit Rng(uint64_t seed) noexcept;
    uint32_t NextU32() noexcept;                       // xorshift128+
    float    NextFloat() noexcept;                     // [0, 1)
    float    RangeFloat(float lo, float hi) noexcept;
    int32_t  RangeInt(int32_t lo, int32_t hi) noexcept;         // [lo, hi)
    int32_t  PickWeighted(const float* weights, int n) noexcept;
    Rng      Fork(uint32_t tag) const noexcept;        // independent substream
    std::array<uint64_t, 2> State() const noexcept;
    void     Restore(const std::array<uint64_t, 2>&) noexcept;
};
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
`sj::Rng` — xorshift128+ with SplitMix64 seeding and forkable substreams. 19 test cases, 481,026
assertions, `make test-unit FILTER=rng` green. This is the first real module in `SteeplejackSim`.

### What changed
- `Source/SteeplejackSim/Public/Rng.h` — the interface exactly as `interfaces.md` fixes it.
- `Source/SteeplejackSim/Private/Rng.cpp` — implementation.
- `tests/unit/test_rng.cpp` — 19 cases.
- `tasks/CORE-003.md` — the Interface block was GDScript; replaced with the C++ from
  `interfaces.md`. See below.

### The task's Interface block was stale, and the spec link was not
The `## Interface` section specified `class_name Rng extends RefCounted`, `func next_u32() -> int`
and `PackedInt64Array` — **GDScript**, left over from before ADR-0004. Following it literally was
impossible. `docs/03-tech/interfaces.md#rngh--core-003`, which the task's own `spec:` points at,
was already correct C++ and is what I built against. AGENTS.md rule 9 says when a doc and reality
disagree one of them is a bug and you say which: here the task file was the bug and
`interfaces.md` was right, so the task file now matches it.

Worth flagging beyond this task: `work-breakdown.md` had the same disease (CORE-001 described as a
Godot project) and CORE-011 owns that one. Nobody has swept the `tasks/` tree for Godot leftovers,
and there are 50-odd task files. **This is likely not the only one.**

### Decisions
1. **SplitMix64 to expand the seed, never the seed as state.** xorshift128+ is absorbing at
   all-zero state — seeded naively with 0 it returns 0 forever — and `0` is the single most likely
   seed a human types. There is a test for exactly that.
2. **`NextU32` takes the high 32 bits** of the 64-bit output. xorshift128+'s low bits are
   measurably weaker and its lowest bit fails linearity tests outright.
3. **`RangeInt` uses Lemire multiply-shift with no rejection loop.** This is a determinism
   decision, not a performance one: a rejection loop consumes a variable number of draws, so the
   stream position would depend on the values drawn, and a replay landing on a different position
   diverges everywhere after it. One draw in, one value out, always — with a test asserting the
   state after 100 `RangeInt` calls equals the state after 100 `NextU32` calls. The residual bias
   is under one part in 2^32 for any span the sim will use.
4. **`Fork` is `const`.** It cannot advance the parent, which is the entire reason it exists: if
   forking moved the parent, adding one random call in the weather system would shift every joint
   in the grid and invalidate every recorded replay. Tested both ways — draining a fork 5,000
   times leaves the parent's next 500 values identical, and the parent's state is byte-identical
   across a `Fork` call.
5. **`PickWeighted` never returns a zero-weighted option.** A caller passing `0.0` for an option
   means "not available", and float rounding in the accumulate-and-sweep could otherwise return
   it on the final index. The fallback walks backwards to the last *positive* weight. Tested over
   20,000 draws against `{0.5, 0, 0.5, 0}`.
6. **Algorithm constants are named `constexpr`, not annotated literals.** `check_conventions.py`
   exempts `constexpr` lines from rule 2, so `kShiftA = 23` documents itself and passes the gate,
   where `// literal:` on a bare `23` would not have explained what it was.

### Surprises
- **`make test-unit FILTER=rng` silently passed with zero tests run.** doctest's `--test-case`
  filter matches test *names*, and mine did not contain "rng" — so the task's own `verify:`
  command reported `SUCCESS` against 0 of 23 cases. Every case is now prefixed `Rng:`. A verify
  command that passes vacuously is worse than one that fails, and nothing in the gate would have
  caught it.
- **The magic-number rule and an RNG are a bad fit on their face** — the file is nothing but
  constants — but the `constexpr` exemption turns out to be exactly the right shape. Naming
  `kSplitMixGamma` and the xorshift shift triple is better documentation than the bare numbers,
  which is presumably why the exemption is written that way.

### Follow-ups
- `tests/unit/test_harness.cpp` says "Delete this file once CORE-003 lands a real module with real
  tests." **I have not deleted it** — it is not in this task's `owns:`, and its four cases still
  earn their place proving the toolchain works without Unreal. Its second case is also now
  mis-titled ("the toolchain is C++17" — CORE-001 moved the project to C++20). Someone should
  either retitle it or retire it deliberately; it should not be deleted as a side effect.
- Sweep `tasks/` for other GDScript-era Interface blocks. Mine was not written to be wrong; it was
  written before ADR-0004 and never revisited.
- `Rng` has no benchmark. `performance-budget.md` gives `SteeplejackSim::Step` a 0.5 ms budget and
  the joint grid will draw heavily from this. Not needed yet, but CORE-006 should measure it.

### Verification
| # | Criterion | Result |
|---|---|---|
| 1 | Same seed, identical 10,000-value sequence | PASS |
| 2 | `Fork(7)` from the same parent state is reproducible | PASS |
| 3 | Draining a fork does not move the parent | PASS — 5,000 draws, parent's next 500 unchanged |
| 4 | `State()`/`Restore()` round-trips mid-sequence | PASS — same instance and across instances |
| 5 | `PickWeighted` within 1% over 100,000 draws | PASS — 0.6/0.3/0.1 within 1% |
| — | `make check` | PASS — 0 violations, 23/23 cases, 481,026 assertions |
