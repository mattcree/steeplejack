---
id: SETUP-001
title: Standalone test harness — doctest, CMake, and honest gates
milestone: M0
discipline: [ENG]
estimate_days: 1
status: done
assignee: project lead
depends_on: []
owns:
  - third_party/**
  - CMakeLists.txt
  - tests/main.cpp
  - tests/unit/test_harness.cpp
  - Makefile
spec:
  - docs/06-workflow/03-verification.md#the-ladder
  - docs/03-tech/adr/0004-engine-change-to-unreal.md#the-key-structural-move-steeplejacksim-is-not-a-ue-module
verify: make check
human_required: true
editor_required: false
risk: null
---

## Goal
Make `make check` actually work: vendor doctest, always build the test binary, and make empty gates
report honestly instead of passing.

## Why
`make check` is the command every agent is told to run before every PR. It did not work — no
doctest, no test files, and `CMakeLists.txt` only built tests if sim sources existed. The gate was
unverified fiction.

## Acceptance
1. `make check` is green and runs in under a second warm.
2. A deliberately failing test fails the gate.
3. The test binary builds with **zero** sim modules present.
4. Gates that filter by test name report "no such tests yet" rather than exiting zero.
5. `-ffp-contract=off` is set, per ADR-0003 on determinism.

## Out of scope
No gameplay modules. The harness test deliberately tests nothing about the game.

## Plan
n/a

## Blocked
n/a

## Outcome
**What changed:** doctest 2.4.11 vendored to `third_party/` (single header, committed rather than
fetched so `make check` works offline and in a cold container). `CMakeLists.txt` now always builds
`sim_tests`, synthesising an empty translation unit so `steeplejack_sim` links before the first
module lands. `tests/unit/test_harness.cpp` proves the toolchain end to end without touching a
single game concept — C++17 features compile, fixed-width types work without Unreal's aliases, and
doctest links.

**Decisions made:** the three filtered gates (`test-levels`, `test-replay`, `test-determinism`)
counted zero matching test cases and printed `SUCCESS`. That is a green gate that checks nothing.
They now count matches first via `--list-test-cases` and print
`-- replay regression: no such tests yet (lands in CORE-006/TEST-002)`. Verified all three states:
runs when tests exist, fails when they fail, reports honestly when empty.

**Surprises:** the first attempt at counting test cases used `grep -c '^  '`, which silently matched
nothing — the gate reported "no such tests" even with a matching test present. A gate that lies in
the *other* direction is just as bad. Caught by probing with a real test rather than trusting it.

**Follow-ups:** none. CORE-003 replaces `test_harness.cpp` with real tests.
