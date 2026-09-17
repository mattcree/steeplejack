---
id: CORE-008
title: Level data loader
milestone: M0
discipline: [ENG]
estimate_days: 1.5
status: review
assignee: agent
depends_on: [CORE-004, CORE-014]
owns:
  - Source/SteeplejackSim/Public/Level.h
  - Source/SteeplejackSim/Private/Level.cpp
  - tests/unit/test_level.cpp
  - tests/fixtures/levels
  - tools/validate_data.py
reads:
  - data/levels/01-back-yard.json
  - data/levels/06-waterside.json
  - data/schemas/level.schema.json
spec:
  - docs/03-tech/interfaces.md#levelh--core-008
  - docs/03-tech/data-schemas.md#level-file
  - docs/01-gdd/01-core-loop.md#the-ascent-beat-rule
verify: make test-unit FILTER=level && make validate
editor_required: false
risk: null
---

## Goal
Parse a level JSON into typed data and re-implement the validator's rules in `validate()`.

## Why
Levels are data, not scenes. This loader is the only path from a designer's JSON to something playable, and its validator is the second line of defence against a broken level reaching playtest.

## Context
`tools/validate_data.py` already implements the rules in Python (band contiguity, quality sums, the Ascent Beat Rule, corridor/exclusion conflicts, scoring field names). `LevelData.validate()` must implement the same rules. A test must assert the two agree on both existing levels plus a deliberately broken fixture — a divergence between them is a bug in whichever is newer.

## Interface
See `docs/03-tech/interfaces.md` section `Level.h`, which is the contract:

```cpp
class LevelData {
public:
    static LevelData LoadFrom(const std::string& path);
    const std::string& Id() const noexcept;
    const std::string& Archetype() const noexcept;
    float TotalHeight() const noexcept;
    const BandSpec& BandAt(float height) const;
    std::vector<std::string> Validate() const;   // same rules as tools/validate_data.py
    // Structure(), Site(), Mission(), Scoring() return parsed sub-structs
};
```

Parse through `sj::JsonValue` (CORE-014). Do not write a third JSON reader.

## Acceptance
1. Both shipped levels load and `validate()` returns an empty array.
2. A fixture with a 25 m `plain` band returns an error mentioning the Ascent Beat Rule.
3. A fixture with a quality distribution summing to 1.35 returns an error.
4. A fixture with an exclusion inside the fall corridor returns an error.
5. `BandAt(37.0)` on `06-waterside` returns the `existing-band` band.
6. A test asserts C++ `validate()` and `tools/validate_data.py` produce the same error count on all fixtures.

## Out of scope
Do not build the reachability solver here — that is CORE-009 and it needs the joint grid.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
`Level.h` / `Level.cpp`, `tests/unit/test_level.cpp` (13 cases, 90 assertions), seven fixtures in
`tests/fixtures/levels/`, and a `--level` mode on `tools/validate_data.py`. All six acceptance
criteria pass. 115 test cases green overall.

**Acceptance 6 needed the Python validator to grow a single-file mode**

`validate_data.py`'s `main()` scans a fixed `data/levels/` directory, so there was no way to hand
both implementations the same fixture — and a parity test that cannot feed both the same file
cannot catch the thing it exists for. Added `--level <path>`, which prints a machine-readable
`N error(s)` and nothing else, refactoring the per-file rule calls into a shared `check_one()` so
the two entry points cannot drift from each other either. `make validate` is unchanged: same three
levels, same zero errors.

No task owned `validate_data.py`; it was in this task's `reads:` and is now in its `owns:`.

**The parity test earned itself immediately**

It compares `LevelData::Validate()` against `validate_data.py --level` over all seven fixtures, and
on the first run it found a real divergence: C++ printed `quality sums to 1.4`, Python printed
`1.3500`. The Python validator formats that one number to four decimal places on purpose — a
distribution wrong by 0.002 must not round to "1.0" in the message telling you it is not 1.0. The
C++ formatter matched per-message precision to Python's rather than picking one globally, and the
test now pins the four-place form.

That is a small bug. It is also exactly the class the test exists for: two implementations of one
rule set drift *silently*, because each keeps passing its own tests while they separate.

**Decisions**

- *`Validate()` never throws.* A broken level must be reportable, not fatal — editor tooling has to
  show a designer what is wrong with the file they are editing, and it cannot do that from a crash.
  There is a test that hands it `{}`, a level with no bands, and a FELL level with no site, and
  asserts none of them throw while the last still reports an error.
- *`BandAt()` does throw.* The opposite call: a height outside the structure is a caller bug, and
  returning the nearest band would put a climber in brickwork that is not there, which every caller
  downstream would then believe. Bands are half-open `[from, to)` so a boundary belongs to exactly
  one band, with the single exception that the very top of the structure belongs to the top band.
- *The rule constants are duplicated from `validate_data.py`, not read from tuning.* The Ascent Beat
  Rule's 20 m is a design commitment against risk R1, not a number a designer turns down on a
  Friday. Both copies are annotated `// literal:` naming the Python source line.
- *Corridor bearings wrap.* A fall corridor may run 340°→20°, and the naive `lo <= b <= hi` rejects
  every bearing inside it. Same branch as the Python `in_corridor()`, with its own test — it is the
  case most likely to diverge first, because it is the one a reimplementation gets wrong.
- *Error messages are prefixed with the bare filename*, as `validate_data.py` labels its own, so the
  two outputs can be diffed directly rather than only counted.
- *The fixtures are generated from `06-waterside.json` by mutation*, one defect each, so a fixture
  differs from a known-valid level in exactly the way its name says. `valid.json` is the control and
  asserts zero errors on both sides.

**Surprises**

- *The level data contains nulls.* `weather.gustIntervalSeconds` and `weather.ramp` are `null` in
  `06-waterside.json`. That vindicates CORE-014's decision to let `JsonValue` parse `null` to
  `Kind::Null` and leave the policy to the caller — `Tuning` rejects a null because a null tuning
  value reaches a getter as a zero, and a level legitimately uses one to mean "no gusts". Had the
  reader kept CORE-007's blanket rejection, this loader could not have read the shipped levels.
- *`BandSpec` is named in `interfaces.md` and defined nowhere.* The `Level.h` block says
  `const BandSpec& BandAt(float height) const` without a definition, and `Types.h` has no such
  struct. Defined it in `Level.h`, where it belongs — it is level data, not shared vocabulary. The
  interfaces block is unchanged and still accurate.
- *The parity test shells out to Python from a C++ unit test*, which is unusual enough to flag. It
  is the only way to compare two implementations in two languages, it skips with a `WARN` rather
  than a silent pass if `python3` cannot be run, and it fails outright if *no* fixture could be
  compared — the same rule TEST-003 applied to filtered test gates.

**Follow-ups**

- `LevelData` carries `SJ_API` with the same `#ifndef`-guarded stopgap as `Tuning.h` and `Clock.h`.
  Third copy. **CORE-015** owns the single `Export.h` that replaces all three; its acceptance should
  gain `Level.h`.
- `check_reachability` and `check_scoring` in `validate_data.py` are **not** re-implemented here.
  They were not in this task's acceptance and the task says the real reachability solver is CORE-009,
  but it means `Validate()` is not yet a complete mirror — the parity test passes because no fixture
  exercises them. Whoever does CORE-009 should extend both the C++ side and the fixtures, or the
  parity test will keep agreeing about rules neither one checks.
