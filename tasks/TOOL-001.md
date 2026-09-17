---
id: TOOL-001
title: A terminal harness for watching the sim run
milestone: M0
discipline: [ENG]
estimate_days: 0.25
status: in_progress
assignee: agent
depends_on: [CORE-005, CORE-007, CORE-011, METER-001, TEST-003]
owns:
  - tools/sim_watch.cpp
  - Makefile
reads:
  - Source/SteeplejackSim/Public/Meters.h
  - Source/SteeplejackSim/Public/Clock.h
spec:
  - docs/06-workflow/03-verification.md
  - docs/01-gdd/03-meters-grip-nerve.md#grip--the-short-meter
verify: make watch
editor_required: false
risk: null
---

## Goal
`make watch` runs the simulation and prints what it is doing, so a human can see the game behave
without an engine, a GPU or a character model.

## Why
Two reasons, and the second is the one that keeps mattering.

**A designer can read a tuning change.** `meters.json` says one-handed drain is 8/s. What that
*means* is "about twelve seconds of work", and a table cannot show you that a belt round the stack
buys sixty-seven. `make watch` can, in one second, with no editor.

**A reviewer can reproduce a claim.** Both CORE-005 and METER-001 wrote "verified by running it"
into an Outcome citing a harness that lived in a scratch directory. A reviewer correctly called
that worth less than no claim: not committed, not reproducible, and in one case not even
arithmetically consistent. This makes that class of claim checkable.

## Context
It prints, so it cannot live in `SteeplejackSim` — rule 1 forbids stdout there, deliberately, and
that rule is not the obstacle here, it is the reason this is a separate tool. `tools/` is the right
home, built by the existing CMake test target or a small target of its own.

Keep it honest about time: the first draft of this harness reported "45.0 s simulated" while having
run 2703 steps, which is 45.05 s. It accumulated elapsed time by adding `kTick` in a loop rather
than deriving it from the step count — the same float-accumulation mistake CORE-005 exists to
remove, reproduced in the tool that demonstrates CORE-005. Derive elapsed from steps.

## Acceptance
1. `make watch` builds and runs with no engine and no arguments, and exits zero.
2. It steps the real `sj::SimClock` at a real frame rate and the real `grip::Step` — no
   reimplementation of either. A reader must be able to trust that what they see is the game.
3. It prints the tuning digest, so what was run is identifiable against a `Tuning::Hash()`.
4. Elapsed time is derived from the step count, not accumulated in a float. `steps / 60` and the
   printed seconds must agree exactly.
5. It shows the stance trade legibly: the same work under at least three stances, with the seconds
   of work each buys.
6. It shows the tremor telegraph arriving before the slip, with both timestamps.

## Out of scope
Not a game, not interactive, not a test. It asserts nothing and gates nothing — `make check` must
not depend on it. Do not add it to `make ci`.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
