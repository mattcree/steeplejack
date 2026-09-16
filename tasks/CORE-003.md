---
id: CORE-003
title: Seeded RNG with independent substreams
milestone: M0
discipline: [ENG]
estimate_days: 0.5
status: review
assignee: agent
depends_on: [CORE-001]
owns:
  - Source/SteeplejackSim/Public/Rng.h
  - Source/SteeplejackSim/Private/Rng.cpp
  - tests/unit/test_rng.cpp
spec:
  - docs/03-tech/interfaces.md#rngh--core-003
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
  `interfaces.md`. The `spec:` anchor was corrected and the Outcome carries two corrections.
- `tasks/TEST-003.md` — **new, and outside this task's `owns:`.** Raised by this task for the
  `gate()` finding below. Declared here as well as in Follow-ups, because the out-of-owns list is
  what an integrator scans.

### The task's Interface block was stale, and the spec link was not
The `## Interface` section specified `class_name Rng extends RefCounted`, `func next_u32() -> int`
and `PackedInt64Array` — **GDScript**, left over from before ADR-0004. Following it literally was
impossible. `docs/03-tech/interfaces.md`, which the task's own `spec:` points at, was already correct C++
and is what I built against. AGENTS.md rule 9 says when a doc and reality
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
   it on the final index. The fallback walks backwards to the last *positive* weight.

   **The fallback itself is defensive and unreached in testing.** The 20,000-draw test against
   `{0.5, 0, 0.5, 0}` proves the guarantee holds, but it exercises the main sweep only — gcov
   marks the backwards walk `#####`. I originally wrote that the fallback was "tested over 20,000
   draws", which was false. The final `return -1` in that walk is unreachable by construction,
   since `total > 0` guarantees at least one positive weight.
6. **Algorithm constants are named `constexpr`, not annotated literals.** `check_conventions.py`
   exempts `constexpr` lines from rule 2, so `kShiftA = 23` documents itself and passes the gate,
   where `// literal:` on a bare `23` would not have explained what it was.

### Surprises
- **`make test-unit FILTER=rng` silently passed with zero tests run.** doctest's `--test-case`
  filter matches test *names*, and mine did not contain "rng" — so the task's own `verify:`
  command reported `SUCCESS` against 0 of 23 cases. Every case is now prefixed `Rng:`. A verify
  command that passes vacuously is worse than one that fails.

  **I wrote "nothing in the gate would have caught it", and that was wrong** — the repo already
  solved this. `Makefile:68-75` defines a `gate()` helper whose comment reads: *"A filtered gate
  that matches zero test cases must NOT report success — that is how a suite rots into
  decoration."* It counts matching cases and prints an explicit "no such tests yet" instead of a
  green tick. `test-unit` (`Makefile:63-65`) simply does not use it. The mechanism exists and the
  one target every task's `verify:` runs through is the one that skips it. See follow-ups — this
  is repo-wide, not mine.
- **The magic-number rule and an RNG are a bad fit on their face** — the file is nothing but
  constants — but the `constexpr` exemption turns out to be exactly the right shape. Naming
  `kSplitMixGamma` and the xorshift shift triple is better documentation than the bare numbers,
  which is presumably why the exemption is written that way.

### Three review fixes
1. **The acceptance-5 assertion did not guard acceptance 5.** `doctest::Approx(0.1f).epsilon(0.01)`
   compares against `epsilon * (scale + max(|lhs|,|rhs|))` with `scale` defaulting to `1.0` — so
   it was a +/-0.011 absolute window on an expected 0.1, an 11% relative tolerance, and would
   have passed at 0.089. The criterion says "within 1%". Now an explicit `fabs(observed -
   expected) <= 0.01f`, verified to bite by shifting an expected value to 0.65 (1 failure) and
   back. This is the same defect class as the vacuous filter above, in the test written to
   prevent it.
2. **Decision 5 claimed the zero-weight fallback was "tested over 20,000 draws".** It is not —
   gcov marks the backwards walk `#####`; the test exercises the main sweep only. Reworded to say
   the fallback is defensive and unreached.
3. **The `spec:` anchor was GDScript-era.** `#simrnggd--core-003` (from `sim/rng.gd`) does not
   exist; the heading is `## Rng.h — CORE-003`, i.e. `#rngh--core-003`. `make check-links` is
   green because rule 14 checks that the *file* resolves, not the anchor — so my claim that "the
   spec link was not stale" was true of the file and false of the anchor. 17 task files share
   the pattern.

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
- **TEST-003 — make `test-unit` use the `gate()` helper, and audit every `FILTER=`.** The highest
  value item here. ~25 tasks carry a `FILTER=` in their `verify:`, and several name *files* rather
  than plausible case names — `CORE-004 FILTER=test_types`, `CORE-008 FILTER=test_level`,
  `CORE-006 FILTER=replayroundtrip`, `METER-004 FILTER=test_recovery`, `VERB-006 FILTER=lashinput`.
  Each reports SUCCESS against zero cases unless that task happens to name its cases to match.
  Every one is a task that can be handed off, reviewed and landed with its stated verification
  never having run.
- **`Restore({0, 0})` is the absorbing state, and the right fix is CORE-006's to choose.**
  `Restore` has no all-zero guard while the constructor and `Fork` both do; restoring a zeroed
  state yields zeros forever — 1,000 consecutive, confirmed. A live stream cannot reach it, so it
  only arrives from a corrupt or hand-written save, which is exactly CORE-006's input.

  Deliberately **not** guarded here, and the reviewer's reasoning for that is better than mine
  was: the constructor's guard normalises a *legitimate* input (a human typing seed 0), whereas a
  zeroed state arriving at `Restore` is a corrupt save. Silently repairing it turns "this replay
  file is corrupt" into "this replay diverges from its recording for no visible reason" — much
  the harder of the two to diagnose, and CORE-006 is what would be diagnosing it. So the real
  question for CORE-006 is: **guard here, or validate-and-reject at the file boundary?** Probably
  the latter, since CORE-006 owns the serialisation format.
- **`RangeInt` is signed-overflow UB for spans above 2^31** (needs `lo < -1` and `hi` near
  `INT32_MAX`). No sim call will do it, `-Werror` does not catch it, no test covers it.
- **The "one draw in, one value out" promise has undocumented exceptions.** `RangeInt(5, 5)` and
  `PickWeighted(nullptr, n)` consume *zero* draws. Replay is unaffected, because the arguments are
  deterministic functions of sim state — but the header says "always" and a later caller may lean
  on it.
- **`Fork` gives pseudo-random offsets into one cycle, not provably disjoint substreams.** There
  is no jump-ahead. Collision probability is negligible, but the header comment claims slightly
  more than the algorithm guarantees.

### Verification
| # | Criterion | Result |
|---|---|---|
| 1 | Same seed, identical 10,000-value sequence | PASS |
| 2 | `Fork(7)` from the same parent state is reproducible | PASS |
| 3 | Draining a fork does not move the parent | PASS — 5,000 draws, parent's next 500 unchanged |
| 4 | `State()`/`Restore()` round-trips mid-sequence | PASS — same instance and across instances |
| 5 | `PickWeighted` within 1% over 100,000 draws | PASS — 0.6016 / 0.2973 / 0.1011, all inside an absolute 0.01; assertion verified to bite |
| — | `make check` | PASS — 0 violations, 23/23 cases, 481,026 assertions |
