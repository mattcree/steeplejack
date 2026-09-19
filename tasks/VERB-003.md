---
id: VERB-003
title: Hammer: power, angle and depth
milestone: M1
discipline: [ENG]
estimate_days: 3
status: blocked
assignee: null
depends_on: [CORE-007, STRUCT-002]
owns:
  - Source/SteeplejackSim/Public/Verbs/Hammer.h
  - Source/SteeplejackSim/Private/Verbs/Hammer.cpp
  - tests/unit/test_hammer.cpp
spec:
  - docs/03-tech/interfaces.md#simverbshammergd--verb-003
  - docs/01-gdd/02-climbing-system.md#2-dogging-in--the-hammer
  - docs/01-gdd/04-tools-and-verbs.md#dog-in
verify: make test-unit FILTER=hammer
editor_required: false
risk: R1
---

## Goal
Resolve a single hammer strike from power, angle error, joint softness and tool condition.

## Why
MVP criterion 5 is whether the verbs have a mastery curve. The hammer is the most-repeated action in the game and carries most of that curve. If it has no skill ceiling, the project has a serious problem.

## Context
Three axes of skill, not a timing bar: power (arc length at release), angle (reticle offset, already wobble-affected by the caller), depth (persistent per-dog accumulation). The designed insight the player should discover is that 60-75% power with a clean angle beats 100% power — make sure the model actually produces that. Formulas are in the GDD section; implement them literally and tune from JSON.

## Interface
```cpp
class_name HammerVerb extends RefCounted
static func strike(joint: Joint, current_depth: float, power: float,
                   angle_error_deg: float, tool_condition: float,
                   tuning: Tuning) -> StrikeResult
```

## Acceptance
1. Five strikes at 0.7 power and under 4 deg error seat a dog from 0 to at least 80% depth in a Sound joint.
2. A property test proves 0.65-0.75 power outperforms 1.0 power across the angle-error range — the designed insight holds.
3. Soft (perished) mortar reaches depth in fewer strikes than sound mortar.
4. Full power at over 10 deg error bends the dog with high probability.
5. Over-driving a low-quality joint produces spall; spall reduces the eventual rating.
6. Pure function: no state, no RNG, deterministic for identical inputs.

## Out of scope
No swing state machine, no wobble computation, no animation, no audio — those belong to the caller, METER-003, ART-001 and AUD-002 respectively.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
**Question (acceptance 2 only):** "0.65–0.75 power outperforms 1.0 power across the
angle-error range". Per strike, it does not, and cannot while depth gain is linear in power. At a
Sound-ish joint (0.8), a clean blow drives further at full power (0.200 per strike against 0.140
at 0.7, at 0°). The moderate swing only wins past 6°, where full power bends the dog and gains
nothing. Is the criterion about one strike, or about play?

**What I found:** the GDD's lesson is "60–75% with a clean angle beats 100% with a poor one". In
play that comes from the *draw*: power builds at 1.6 a second while the aim drifts with wobble, so
a full draw is usually a worse angle than a three-quarter one. That is game-side
(`player.gd`'s draw and `_update_work`), not in `hammer::Strike`.

**Options:**

1. Restate acceptance 2 as a property of play: a strike released at 0.7 of a draw beats one
   released at 1.0 of the same draw, with wobble. Test it through the game's draw, or a small sim
   helper that models the draw.
2. Make the strike itself punish full power: for example, bend risk rising faster than linearly
   in power, so a slightly-off full swing bends. That is a tuning and design change to the
   GDD's formula.

**Recommendation:** option 1. The per-strike model already teaches "don't swing flat out when
you're off", and a test named "a full-power swing at a clean angle is safe — power is not the
enemy" says that was deliberate. Nothing else waits on this.

## Outcome
**What changed:** `Verbs/Hammer.h`/`Hammer.cpp` were built with the tap test. This handoff
adds one test per acceptance criterion to `tests/unit/test_hammer.cpp`, and a fix that criterion 1
exposed.

- **Acceptance 1 failed badly, and the game felt it.** The GDD's `jointSoftness = 1 − quality`,
  transcribed as written, meant the best Sound joints took **34 to 170** clean strikes and a
  perfect one could never be seated. The same document says sound mortar "needs 5–6 solid
  strikes", and acceptance 1 says five. The ascent bot once hammered one joint twenty times
  without seating it, which was this. Softness is now floored by a new tuning key,
  `hammerSoftnessFloor` 0.34, derived from the criterion's worst case: a perfect joint at 0.7
  power and 3.9° off seats in exactly five. Across the Sound band it is 3–5 strikes, perished
  mortar 2–3, so soft mortar is still the fast trap. The full climb got 26 s quicker.
- Acceptance 3 (soft seats faster), 4 (full power past 10° bends, every time, because there are
  no dice), 5 (over-driving spalls, and spall never improves a rating) and 6 (pure) are tested.
- Acceptance 2 is blocked (above), with a test that pins what the model actually does.

**Follow-ups:** answer the question above.
