---
id: METER-003
title: Wobble — the one number every verb reads
milestone: M1
discipline: [ENG]
estimate_days: 0.5
status: blocked
assignee: null
depends_on: [METER-002]
owns:
  - Source/SteeplejackSim/Public/Wobble.h
  - Source/SteeplejackSim/Private/Wobble.cpp
  - tests/unit/test_wobble.cpp
spec:
  - docs/01-gdd/03-meters-grip-nerve.md#interaction-between-the-two
  - docs/00-vision.md#anti-pillars-things-we-will-not-do
verify: make test-unit FILTER=wobble
editor_required: false
risk: R7
---

## Goal
A single function that computes reticle wobble from grip, nerve, stance and wind gust.

## Why
Four systems push on one number and every skill verb reads it. Centralising it is what stops the game accumulating a third meter and a dozen special cases.

## Context
**This is the only place wobble may be computed.** A verb that computes its own wobble is rejected in review — see the anti-pillars. If a verb needs different wobble behaviour, it takes a multiplier, it does not reimplement the function.

## Interface
```cpp
class_name Wobble extends RefCounted
static func amplitude_deg(m: Meters, ctx: MeterContext, gust: float, tuning: Tuning) -> float
```

## Acceptance
1. Output matches the product of base, stance, grip, nerve and gust multipliers from `meters.json`.
2. Wobble is 1.0x base with full grip, calm nerve, belted stance and no gust.
3. Wobble reaches 6x base at zero grip, zero nerve, one-handed, in a gust.
4. A grep across `SteeplejackSim` finds no other wobble computation (asserted by a convention check added in this task).
5. Pure and deterministic.

## Out of scope
Do not add per-verb wobble behaviour here. Verbs scale the result.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
**Question:** acceptance 3 says wobble "reaches 6x base at zero grip, zero nerve, one-handed, in a
gust". The tuning gives **13.1x**: stance 1.6 (oneHand) × nerve 3.0 × grip 2.0 = 9.6x, plus a full
gust's 3.5° on a 1° base. Which number is the design?

**What I found:** the GDD formula (`03-meters-grip-nerve.md`, the wobble block) is grip ×2 at zero
and nerve ×3 at zero, and 2 × 3 is exactly 6. So "6x" looks like it was worked out from those two
factors alone, before a stance multiplier above 1.0 and a gust were in the data. Two smaller
mismatches are in the same place:

- The GDD multiplies a gust in (`* windGust(t)`). The code adds it, so a gust on steady hands
  shoves you without scaling your nerves. Acceptance 1 says "product".
- The GDD ramps nerve continuously. The code steps it in bands.

The code follows `meters.json` and the comments in `Wobble.cpp`. The spec and the data disagree,
not the code and the data.

**Options:**

1. Keep the data and restate acceptance 3 as "the product of each factor's worst". Also restate
   acceptance 1 as "product, with the gust added".
2. Retune to hit 6x. For example, oneHand 1.0 and gustWobbleDegrees 0. That removes both the
   stance's effect on aim and the gust's.

**Recommendation:** option 1. test_hammer.cpp already asserts the property the design actually
needs ("at its worst it exceeds the hammer's angle tolerance — that is the point"), and 6x would
not exceed it by much.

**Done meanwhile:** convention rule 19 (acceptance 4) with its two tests, and
`tests/unit/test_wobble.cpp` covering acceptance 1, 2 and 5 against the current data. Nothing is
waiting on the answer except one test for acceptance 3.

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
