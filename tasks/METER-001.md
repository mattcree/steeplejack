---
id: METER-001
title: Grip meter and the five stances
milestone: M1
discipline: [ENG]
estimate_days: 1.5
status: review
assignee: agent
depends_on: [CORE-004, CORE-007, CORE-011]
owns:
  - Source/SteeplejackSim/Public/Meters.h
  - Source/SteeplejackSim/Private/MetersGrip.cpp
  - tests/unit/test_grip.cpp
  - Source/SteeplejackSim/Public/Types.h
spec:
  - docs/03-tech/interfaces.md#simmeters_gripgd-simmeters_nervegd-simwobblegd--meter-0123
  - docs/01-gdd/03-meters-grip-nerve.md#grip--the-short-meter
  - docs/01-gdd/02-climbing-system.md#5-grip-and-why-climbing-is-free-but-working-is-not
verify: make test-unit FILTER=grip
editor_required: false
risk: null
---

## Goal
Grip as a 12-second window on one-handed work, with five stances that trade set-up time for drain rate.

## Why
Grip is not a stamina bar — it converts a limit into a decision. The stance table is the difficulty dial for the entire game.

## Context
Drains only when a hand is off the ladder. Recovers at 25/s with both hands on. Every modifier in `meters.json` must be implemented: ladder carry, wet, cold, cracked rib, gloves. The cold cap (max grip 80 until two minutes of work) matters for the winter levels later.

## Acceptance
1. Drain rates for all five stances match `meters.json` exactly.
2. Full recovery from zero takes about 4 s.
3. All five modifiers are implemented and unit tested.
4. Below 20 the tremor flag is set.
5. At zero, the model reports a slip condition (it does not resolve it — that is METER-005).
6. A property test: grip never exceeds max or drops below zero.

## Out of scope
Nerve is METER-002. Wobble is METER-003. Slip resolution is METER-005.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
`Meters.h`, `MetersGrip.cpp`, `tests/unit/test_grip.cpp` (11 cases, 64k assertions), and two new
fields on `MeterContext`. All six acceptance criteria pass.

**The interface could not express the mechanic, so this task extended it**

`grip::Step(Meters&, float dt, const MeterContext&, const Tuning&)` is fixed in `interfaces.md`, and
the GDD says grip "drains whenever a hand is off the ladder" and "recovers at 25/s with both hands
on". Nothing in `Meters` or `MeterContext` said whether a hand was off. `Stance` describes how you
are *secured while working*; it has no "resting" value and should not get one. So as the contract
stood, grip could only ever drain and never recover, and acceptance 2 was unimplementable.

Added to `MeterContext` (declared: this task owns `Types.h`, with `depends_on: CORE-004`):

- `bool working{}` — a hand is off the ladder. Defaults false, so a zero-initialised context is
  someone holding on. A default meaning "working" would drain a climber nobody is moving.
- `float workedSeconds{}` — seconds of work this shift. Only the cold cap reads it, and the cold
  cap is specified in `meters.json` as `coldWarmupSeconds`, so without it that modifier was also
  unimplementable.

This is rule 9: the doc and the design disagreed, and the doc was the thinner of the two.

**`interfaces.md` is NOT updated, and that is a gap this task could not close.** Four tasks already
own that file (CORE-014, CORE-015, CORE-016, plus CORE-011 which is done), and CORE-016 is
`status: blocked` — depending on it to satisfy the ownership validator would have blocked this task
behind a question about exception handling. The additions needed are the two `MeterContext` fields
and the four `grip::` helpers below. Folded into CORE-015's acceptance, which owns the file and is
ready. Until that lands, `interfaces.md`'s `Types.h` and `Meters.h` blocks are stale.

**Decisions**

- *Four helpers beyond the two signatures in the doc.* `MaxGrip`, `RecoverRate`, `Tremor`,
  `Slipping` and `SecondsOfWorkLeft` are additive — no existing signature changed. `Tremor` and
  `Slipping` exist because acceptance 4 and 5 ask the model to *report* those conditions and
  `Meters` has no flag for either; putting the threshold comparison in one place stops five verbs
  each inventing their own. `SecondsOfWorkLeft` is what the twelve seconds in the design doc
  actually is, and a HUD cannot show the cost of a stance without it.
- *Every number reads from `meters.json`, and so does every test.* The tests assert
  `DrainRate(OneHand) == GetF("gripDrainPerSecond.oneHand")` rather than `== 8.0f`. A designer
  moving the dial moves the game and does not break the suite; code that stops reading tuning
  breaks it immediately. That is the distinction rule 4 is for.
- *One test asserts the table's ordering, not its values* — `OneHand > HookedLeg >= Clipped >
  Belted > Chair`. If a tuning edit inverts that, twenty seconds of rigging a chair buys nothing
  and the central trade of the game is broken, without any single drain value looking wrong.
- *Modifiers multiply and compound.* Wet and carrying a ladder together is ×1.4 ×1.5, tested. A
  chair drains nothing, so no modifier can make it drain — correct: the point of rigging is that
  the weather stops mattering.
- *The injury string is compared, not merely checked for being non-empty.* `"bad_ankle"` leaves the
  drain rate alone; only `"cracked_rib"` multiplies it. A truthiness test would have made every
  injury a grip injury.
- *`Slipping()` reports and does not resolve.* Grip stays pinned at zero and keeps reporting; the
  slip window, the grab input and the fall are METER-005's. There is a test that steps five more
  seconds at zero and checks nothing else happens, so the meter cannot quietly grow a second
  responsibility.

**The fairness contract**

Rule 7 says every failure has a telegraph shipped in the same task. Grip's failure is the slip, and
its telegraph is the tremor. A test asserts the tremor is set *before* the slip, that they are not
simultaneous, and that there is real time between them — at one-handed drain, the warning arrives
about 2.5 s before grip reaches zero. Verified in a run of the whole meter:
`hands start to shake at t=36.0s`, `GRIP GONE at t=38.5s`.

**Verified by running it, not only by testing it**

A terminal harness stepping the real `SimClock` at 60 Hz through a six-phase shift reproduces the
design's central claim: one hand buys about 12 seconds of work, a belt round the stack buys about
67, and recovery from 28 to full takes a little under 3 s. That is the difficulty dial behaving as
the GDD describes. The harness is scratchpad-only; making it a committed tool is a follow-up.

**Surprises**

- *`check_conventions.py` skips `constexpr` but not `static constexpr`* (found in CORE-005, same
  session). Not hit here, but the same checker gap.
- The cold cap is the one modifier that changes the *ceiling* rather than the rate, so recovery
  stops short of full rather than slowing. That reads exactly like cold hands and is worth keeping.

**Follow-ups**

- **CORE-015** must add the two `MeterContext` fields and the five `grip::` helpers to
  `interfaces.md`. Added to its acceptance. Until then the contract page is stale.
- METER-002 (nerve) and METER-003 (wobble) share `Meters.h`; both are unblocked by this.
- A committed demo tool, so the sim can be watched without a scratch build. No task yet.
