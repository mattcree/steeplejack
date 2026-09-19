---
id: TEST-001
title: Sim coverage gate
milestone: M1
discipline: [ENG]
estimate_days: 1
status: review
assignee: null
depends_on: [METER-005, CLIMB-006, VERB-007, CORE-009, VERB-002]
owns:
  - tools/coverage.py
  - tests/perf/test_step_budget.cpp
spec:
  - docs/06-workflow/03-verification.md#coverage
  - docs/03-tech/adr/0003-determinism-and-testing.md#testing-strategy
verify: make test-coverage
editor_required: false
risk: null
---

## Goal
Fail CI if `SteeplejackSim` line coverage drops below 90%.

## Why
The sim/presentation split exists so that all the logic lives somewhere it can be tested exhaustively. A coverage gate is what stops that eroding one untested branch at a time.

## Context
`game/` is deliberately not coverage-gated — it is presentation and its correctness is visual. Report per-module so it is obvious which module regressed.

## Acceptance
1. Coverage is measured across `SteeplejackSim` only.
2. The gate fails below 90%.
3. Output is per-module so a regression is attributable.
4. Runs in under 30 s.
5. Current coverage at time of merge is recorded in `## Outcome`.

## Out of scope
No coverage requirement on `game/`.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
**What changed:** `tools/coverage.py` existed but could not have failed.

- **It passed when it measured nothing.** "gcov produced no data" and "no gcov installed" both
  exited 0, and it did produce no data: it pointed gcov at the wrong object directory. Both now
  fail, the same rule as test-unit's zero-match filter (TEST-003).
- **The total was an unweighted mean of per-file percentages,** so a 2-line header counted as
  much as the 240-line JSON reader. It is now covered lines over total lines.
- Measurement uses gcov's JSON over the sim library's own data files only. A header compiled
  into several units counts a line covered if any unit ran it. Stale `.gcda` counts from an
  earlier run are cleared first, and `build-coverage/` is gitignored.

1. Only `Source/SteeplejackSim` is measured: the library's objects, filtered to that path.
2. `--gate 99` exits 1 and the default 90 exits 0 (checked by hand; there is no automated test).
3. Per file, worst first, with covered/total lines, so a regression is attributable.
4. About 20 s, including the instrumented build.
5. **Coverage at handoff: 94.2%, 1872 of 1988 lines.** The lowest `.cpp` files are Recovery.cpp
   (84.4%) and Stack.cpp (89.2%).

**Follow-ups:** it runs in CI's sim job (`python3 tools/coverage.py`), not in `make check`, whose
budget is a second.
