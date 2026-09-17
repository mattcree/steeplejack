---
id: TOOL-001
title: A terminal harness for watching the sim run
milestone: M0
discipline: [ENG]
estimate_days: 0.25
status: review
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
`tools/sim_watch.cpp` and a `make watch` target. All six acceptance criteria pass.

**What it shows, and why that is more than a demo**

It opens with the stance table *computed* — drain rate and seconds-of-work for all five stances,
derived from `meters.json` through `grip::DrainRate` and `grip::SecondsOfWorkLeft`:

```
  one hand on rung         8.0 grip/s   12s of work
  hooked leg               4.0 grip/s   25s of work
  belt round the stack     1.0 grip/s   100s of work
  bosun's chair            0.0 grip/s   works indefinitely
```

That is the game's answer, not the design document's. `02-climbing-system.md` states the same table
by hand; if the two ever disagree, this is the one that is true, and now anyone can see it in a
second without an engine. It is the difficulty dial made legible.

Then a six-phase shift, and the fairness contract as a timestamp rather than an assertion:

```
  telegraph: hands began to shake at t=36.00s; grip gone at t=38.50s.
             2.50s of warning

  2700 steps = 45.00s simulated, 0 dropped, alpha 0.000
```

**Decisions**

- *It drives the real classes.* `sj::SimClock::Advance` decides how many steps a frame owes; the
  loop never assumes 1. `sj::grip::Step` does the work. Nothing here reimplements a rule, because a
  demonstration that shows a different game from the one that ships has exactly one failure mode
  and that is it.
- *Elapsed time is derived from the step count, never accumulated.* `SecondsFor(steps)`, once. The
  first draft added `kTick` in a loop and reported "45.0 s" after 2703 steps — which is 45.05 s.
  That is the float-accumulation mistake CORE-005 exists to remove, reproduced inside the tool that
  demonstrates CORE-005. It now prints `2700 steps = 45.00s`, and acceptance 4 exists specifically
  so nobody reintroduces it.
- *It lives in `tools/`, not in the sim.* Rule 1 forbids stdout in `SteeplejackSim`, and that rule
  is the reason this is a separate tool rather than an obstacle to it.
- *It is not wired into `make check` or `make ci`.* It asserts nothing and gates nothing. A demo in
  the gate would be a gate that cannot fail — the decoration TEST-003 spent a task removing.
- *It prints the tuning digest*, so what you watched is identifiable against a `Tuning::Hash()`.

**Why this task exists at all**

CORE-005 and METER-001 both wrote "verified by running it" into an Outcome citing a harness in a
scratch directory. A reviewer called it correctly: not committed, not reproducible, and in
CORE-005's case not arithmetically self-consistent — an unreproducible "verified" is worth less
than no claim. Rather than delete those sentences and move on, the harness is now a committed tool,
so the next such claim is checkable by running one command.

**Caught in review: the tool printed a number that never happened**

The telegraph interval latched the *first tremor of the session* rather than the tremor that
preceded the slip. Grip recovers, so the shake clears and comes back — and with
`gripTremorThreshold` raised from 20 to 45, the tool confidently reported **28.62 s of warning**
when the real figure was 5.62 s. Its own trace above showed the tremor clearing and grip returning
to full in between.

That is the worst possible bug for this tool specifically. Its entire purpose is that a designer
edits `meters.json` and reads the behaviour, and the telegraph interval is the single number a
reader would quote — into a task file, most likely, where it would then be inherited. It now clears
the latch when the tremor clears, and reports 5.62 s for that mutation, which is exactly
`45 / 8` = threshold over drain rate.

Found by a reviewer mutating the tuning rather than reading the code. Worth noting that the tool
passed all six acceptance criteria while carrying it: nothing in the criteria asked what happens
when a telegraph is interrupted.

**Also from review:** the `watch` recipe compiled with no warning flags at all, which is why a
`-Wconversion` warning and a `%lld`-against-`int64_t` format mismatch went unseen in a repo whose
library builds at `-Werror`. It now compiles at `-Wall -Wextra -Wconversion -Werror` like
everything else.

**Surprises**

- *Clipped and hooked-leg have identical drain rates* (4.0/s), so the table shows both buying 25 s.
  The GDD distinguishes them by set-up time (1.5 s vs 3 s) and wobble (×1.3 vs ×1.2), neither of
  which grip models. Not a bug — but the stance trade is only half visible until METER-003 and the
  set-up timings land, and someone reading this output today could reasonably ask why you would
  ever clip in. Worth knowing before it is shown to a playtester.
- `ctx.workedSeconds` is advanced *by this tool*, because nothing in the sim does — see METER-001.
  An earlier draft of this Outcome said that made it "the only thing in the repo that feeds the
  cold cap". It does not: `ctx.cold` is left false, so `MaxGrip` returns `gripMax` and the cap
  never engages in this run. The cold cap remains entirely inert everywhere. Corrected after
  review; the distinction matters because the first version made a known hole sound half-closed.
- The worktree for this task was cut from `origin/main`, which did not yet carry this task's own
  file: `make land` pushes the trunk, but a task file committed directly to local `main` is not
  pushed until the next land.

**Two task files in this branch that are not this task's**

Declared rather than left for review to find, since rule 3 is about declaring and not about intent:

- `tasks/TOOL-001.md` — this task's own file, copied in for the reason above.
- `tasks/CORE-016.md` — copied in because `BLOCKED.md` on this branch links to it and
  `make check-links` fails without it. Byte-identical to main's copy, so it lands as a no-op. I
  removed it first and put it back when the link check caught me; the link check is doing exactly
  its job.

`make land` resolves `tasks/TOOL-001.md` to the branch by design; the other is net-zero.

**Follow-ups**

- Extend it once METER-002 (nerve) and METER-003 (wobble) land; this shift is grip-only, and nerve
  is what makes height mechanically frightening.
- The set-up cost of a stance is modelled nowhere yet, so the table shows what a stance buys and
  not what it costs. That is the other half of the trade.
