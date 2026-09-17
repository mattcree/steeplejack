---
id: METER-002
title: Nerve meter: height, wind, exposure and shocks
milestone: M1
discipline: [ENG]
estimate_days: 1.5
status: review
assignee: agent
depends_on: [METER-001]
owns:
  - Source/SteeplejackSim/Private/MetersNerve.cpp
  - tests/unit/test_nerve.cpp
  - Source/SteeplejackSim/Public/Meters.h
spec:
  - docs/01-gdd/03-meters-grip-nerve.md#nerve--the-long-meter
  - docs/01-gdd/03-meters-grip-nerve.md#low-nerve-effects-this-is-the-whole-point
verify: make test-unit FILTER=nerve
editor_required: false
risk: R1
---

## Goal
Nerve as the slow meter that makes height mechanically frightening rather than just visually impressive.

## Why
Without nerve, a 110 m chimney plays exactly like a 12 m one. Nerve is what converts altitude into difficulty.

## Context
Nerve never kills the player directly — it makes them worse at the job, which kills them. Implement the four effect bands as reported state; the presentation layer decides what to do with them. The height factor formula and all shock values are in `meters.json`.

## Acceptance
1. The drain formula matches the GDD exactly for height, wind and exposure factors.
2. Height factor clamps to [0.25, 3.0].
3. All nine shock events are implemented with the tuned values.
4. `band()` returns the four bands at the tuned thresholds.
5. Nerve starts at 90, not 100.
6. Max nerve can be reduced (the cigarette penalty) and current nerve clamps to it.

## Out of scope
Recovery actions are METER-004. Visual and audio effects are UI-001 and AUD-003.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
`MetersNerve.cpp`, `tests/unit/test_nerve.cpp` (15 cases, 72,956 assertions), and the `nerve::`
block added to `Meters.h`. All six acceptance criteria pass. 90 test cases green overall.

**The design claim, made testable**

"Without nerve, a 110 m chimney plays exactly like a 12 m one." That is now a test: a minute at
110 m costs **eleven times** the nerve a minute at 10 m does — the ratio of the two height factors
(2.75 against the 0.25 floor), because nothing else differs between the runs. If someone flattens
the height curve, that test says so in the terms the GDD uses.

Measured ratio is 10.97, 0.25% under the analytic 11.0, and a reviewer confirmed the error lives
entirely in the low-magnitude run — subtracting 0.000875 per step from a float near 90 is about 115
ulps and biased. The 1% epsilon leaves 4× headroom over that and would not hide a wrong factor,
which would move it by 10% or more. (The helper runs 3599 steps rather than 3600, since
`60.0f / kTick` truncates; both runs use the same count so the ratio is unaffected, but an earlier
draft of this Outcome said 3600.)

**The timescale separation is narrower than the GDD implies, and I overstated it.** The first draft
of this Outcome said the two meters differ "by an order of magnitude" and repeated the GDD's
"minutes-to-hours". Measured:

| operating point | grip | nerve | ratio |
|---|---|---|---|
| hanging at 110 m, 12 m/s wind, one-handed | 8.0/s | 1.34/s | 6.0× |
| at the height and wind caps, overhang | 8.0/s | 2.97/s | 2.7× |
| at the caps, **belted** | 1.0/s | 2.97/s | **nerve is 3× faster** |

Time from a fresh 90 to frozen: 600 s at 40 m on a platform in still air; 156 s at 110 m on a
ladder; **67 s** hanging at 110 m in a 12 m/s wind; **30 s** at the caps. "Minutes-to-hours" is true
of the bottom of the range only.

This is the GDD's formula and the GDD's data transcribed faithfully, so it is not a defect in this
task and I have not changed a tuned value. But the sentence would have been inherited and built on,
and at a belted stance high on a stack nerve is genuinely the meter that runs out first — which may
be the intent (the chair is safe for your hands and terrifying) or may be a number nobody checked.
It belongs with the `bellStrike` question in **GDD-001**.

The structural test remains, with its claim narrowed to what it measures: at a realistic exposed
working point grip is about six times faster, and the comment now says that separation is a property
of where you are standing rather than a law.

**Decisions**

- *The formula is transcribed term by term, and each term is exposed.* `HeightFactor`,
  `WindFactor`, `ExposureFactor` and `DrainRate` are all public, so the tests assert the formula
  rather than a precomputed total — a failure names which term moved. A HUD needs them too.
- *Ordering is tested, not just values.* Exposure runs platform < ladder < hanging < overhang, and
  `Band()` is asserted monotonic across the whole range in 0.5 steps. If an ordering inverts, the
  meter tells the player the opposite of the truth while every individual number still matches
  `meters.json`.
- *Thresholds are floors.* At exactly 70 you are still calm. Written `>=` so a designer moving a
  boundary moves it to the value they typed rather than to one less than it.
- *`Step` clamps to `m.nerveMax`, not to the tuned `nerveMax`.* The cigarette lowers the ceiling
  for the rest of the shift, and nerve must not drift back above it. Tested by stepping after the
  reduction.
- *`ReduceMax` takes the tuned sign.* `meters.json` stores `recover.cigaretteMaxNervePenalty` as
  **−5.0**, so `ReduceMax(m, t.GetF("recover.cigaretteMaxNervePenalty"), t)` — the obvious call,
  and the one METER-004 will write — does the obvious thing. An earlier version took a positive
  magnitude and clamped negatives to zero, which made that exact line a **silent no-op**: a sign
  error converted into no effect, in the module that spends a page explaining why silent failures
  are unacceptable. Caught in review. The test now reads the key rather than hardcoding `5.0f`,
  which is what would have caught it.
- *`Frozen()` reports and does not enforce.* Nerve never kills the player; it makes them worse at
  the job, which kills them. Stepping ten more seconds at zero does nothing further — there is a
  test for that, the same shape as METER-001's `Slipping()` test, because the temptation to let a
  meter grow a second responsibility is the same one.
- *`FreshShift()` exists* so no caller has to remember that nerve starts at 90 and grip at 100.
  A default-constructed `Meters` is nerve 0 and `nerveMax` 0, which is a frozen climber who can
  never recover — the same defaults hazard METER-001 flagged for `Slipping`.

**The one silent failure, and why it is there**

`interfaces.md` fixes `nerve::Shock(Meters&, std::string_view, const Tuning&)` as **`noexcept`**.
`Tuning::GetF` throws on an unknown key — deliberately, that is CORE-007's central design. Inside a
`noexcept` function a throw is `std::terminate`. So an unknown event name **does nothing, silently**,
which is exactly the failure mode this project spends the most effort eliminating.

I did not change the signature: `interfaces.md` is owned by four tasks, one of them blocked, and
changing a fixed signature mid-flight is forbidden outright. Instead the silence is bounded:

- `IsKnownShock()` and `ShockAmount()` let any caller or test check, without throwing.
- **The test reads the shock names out of the tuning data** rather than listing them, and asserts
  each costs nerve rather than granting it.

  A reviewer was right that I oversold what this proves. `IsKnownShock(e)` *is*
  `Tuning::Has("nerveShock." + e)`, and the names come from `Tuning::Keys()`, so that half of the
  loop cannot fail for any key in the data — it is close to a tautology. What it genuinely proves
  is that key construction round-trips and that every shock is negative; the "a tenth shock nobody
  fires" case is caught only by `REQUIRE(found.size() == 9)`. And the failure that will actually
  cost someone — a typo'd event name at a call site — is not catchable here at all, because no
  caller exists yet. Worth knowing before writing the first one.

If the contract is ever reopened, an enum would remove the class of error entirely. Worth doing;
not worth blocking a meter on.

**Surprises**

- *The GDD lists six shocks; `meters.json` has nine.* `copingPeel` (−30), `bellStrike` (−35) and
  `sitIntoChair` (−20) are in the data and absent from the table in
  `03-meters-grip-nerve.md`. Acceptance 3 says "all nine", so the task and the data agree and the
  GDD table is the stale one (rule 9). Implemented all nine. `bellStrike` at −35 is the largest
  shock in the game, larger than an anchor failure, and nothing in the design docs explains it —
  worth a designer's eye before M1.
- *A near-miss test was over-specified and I loosened it rather than chase it.* Comparing two sums
  of 3599 float subtractions taken at very different magnitudes to doctest's default relative
  epsilon fails at 0.25%. That is float accumulation, not a logic error, and asserting it to the
  last bit would have been a test being precious. Now checked to 1% with the reason written down.
- *`check_conventions.py` flagged `return 3;`* — the band index, which `interfaces.md` fixes as
  0..3. Annotated. Third instance this session of the magic-number rule catching a structural
  constant rather than a tunable.

**Follow-ups**

- **GDD-001** — filed, `status: blocked`, with a row in `BLOCKED.md`. It carries two questions: the
  three undocumented shocks and whether `bellStrike` should outrank `anchorFail`; and the timescale
  finding above, as question 2 with the measurements and its own acceptance criterion.

  Worth recording how close that came to being a lie. An earlier draft of this Outcome said GDD-001
  covered the timescale question when it did not — I filed the task before making that correction,
  then asserted the cross-reference here *and* in a message to the reviewer without reopening the
  file. A reviewer grepped it and found nothing. Same habit as the test-count and the "no Unreal"
  claims, one level up: not a wrong measurement this time, but a wrong claim about the state of a
  document I had written myself.
- `tools/check_conventions.py` rule 10 only matches literal `.GetF("...")`, so the four
  `exposureFactor.*` keys reached through `ExposureKeyFor()` are invisible to it. A rename in
  `meters.json` would be `std::terminate` inside a `noexcept` function at runtime rather than a
  check failure. Covered in practice only because the tests assert all four against literal keys —
  coverage by luck of test shape, not by the gate. Raised in review; no task yet.
- `nerve::Shock` should take an enum rather than a string if `interfaces.md` is reopened — see
  above. Natural fit for whoever resolves the `interfaces.md` ownership contention flagged in
  CORE-015.
- METER-003 (wobble) and METER-004 (recovery) are both unblocked by this. `nerveWobbleMultiplier`
  and the hesitation keys in `meters.json` are deliberately untouched here — they are METER-003's.
- TOOL-001's `make watch` shows grip only. Extending it to show nerve alongside is where the
  two-meter interaction becomes visible; noted in that task's follow-ups too.
