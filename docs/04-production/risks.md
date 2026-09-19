# Risks

> **2026-09-19 — Unreal is removed from the project ([ADR-0006](../03-tech/adr/0006-move-to-godot.md)):** several risks below were written about Unreal. R8 (binary assets agents cannot author) is much smaller now: the game is text scenes and GDScript. Control Rig, Chaos, MetaSounds and MetaHuman are no longer available answers.

Ordered by expected damage. Each has an owner, a trigger to watch for, and a decided response —
**not** a vague "monitor".

---

## R1 — The climbing loop is boring 🔴 CRITICAL

**The project-ending risk.** Twenty-eight repetitions of one interaction.

| | |
|---|---|
| Probability | Medium |
| Impact | Fatal |
| Trigger | M1 playtest criteria 2 or 5 fail |
| Owner | Design lead |

**Mitigations, already in the design:**
- The Ascent Beat Rule (a complication every 15–20 m) is enforced by the level validator, not by
  good intentions.
- The anchor loop has seven sub-decisions, each with a fast-and-worse option.
- The M1 gate tests exactly this, before anything else is built.

**If it triggers:** cut the anchor loop from ~40 s to ~20 s by removing *seconds*, not steps. Then
re-test. If it fails again, the project stops. **This is why M1 is a real gate with a real kill
condition.**

---

## R2 — Hand IK on procedural ladders is harder than estimated 🟡 MEDIUM *(reduced by ADR-0004)*

CLIMB-005 is 4 ideal days in the plan and could easily be 15. It is also the thing that makes the
ladders feel real.

| | |
|---|---|
| Probability | **Medium** (was High) |
| Impact | Major (feel) |
| Trigger | CLIMB-005 exceeds 5 days |
| Owner | Engineering lead |

**Reduced by [ADR-0004](../03-tech/adr/0004-engine-change-to-unreal.md):** Control Rig + Full Body
IK is a solved problem in Unreal, where under Godot this was a bespoke solve. Estimate cut from 4
days to 2.5.

**Response:** fall back to a **two-pose contact system** — hands snap to the nearest rung at
fixed offsets with a short blend, no full IK solve. It looks 80% as good at 20% of the cost.
Decide by day 5, not day 12.

---

## R3 — The felling system is a research project 🟡 MEDIUM *(reduced by ADR-0004)*

A hinge-and-fracture solver that produces a *satisfying* and *predictable* fall is genuinely hard
to get right, and "it falls over" is not the same as "it falls over beautifully".

| | |
|---|---|
| Probability | Medium-high |
| Impact | Major (it's the marquee) |
| Trigger | FELL-008/009 exceed 1.5× estimate, or the fall doesn't read |
| Owner | Engineering + tech art |

**Mitigations:**
- ADR-0002 already removes the hardest part (no general rigid-body destruction).
- **Chaos Geometry Collections** now do the pre-fracture and the chunk simulation natively. ADR-0002
  was describing a first-class Unreal workflow without knowing it.
- Build a **standalone fall prototype in M3**, decoupled from the gob, so the risk is retired early.
- The fall is scripted and deterministic, so it can be *art-directed* rather than simulated.

**Response if it triggers:** hand-author the fracture points and the fall animation per level,
blending to physics only on impact. Twelve levels × 3 fellings = 3 authored falls. Entirely viable.

---

## R4 — The LATTICE movement set is a second game 🟠 HIGH

Level 11 needs a whole new locomotion system for one level.

| | |
|---|---|
| Probability | Medium |
| Impact | Moderate (one level) |
| Trigger | LAT-001 exceeds 12 days, or M5 is running late |
| Owner | Production |

**Response (pre-decided):** replace Level 11 with a second, taller lattice-free job — a 120 m
concrete stack variant of Level 10 without the storm, or a second constrained felling. The campaign
survives; the variety suffers. **Documented escape hatch; take it without agonising.**

---

## R5 — Twelve levels is too much content 🟠 HIGH

Twelve authored levels at 4 ideal days each is 48 days of design alone, plus art, plus audio.

| | |
|---|---|
| Probability | Medium |
| Impact | Moderate |
| Trigger | M5 tracking >20% over at the halfway point |
| Owner | Production |

**Mitigations:**
- Everything is procedural from JSON. A level designer goes idea → playable in under 30 minutes.
  **Protect that number; it is what makes 12 levels affordable.**
- No hand-placed geometry anywhere. No bespoke modelling per level.

**Response:** ship 9 levels and add 3 in a free update. Cut order: **09, 08, 11.** Never cut 1, 2, 6
or 12.

---

## R6 — Audio is treated as polish 🟡 MEDIUM *(tooling improved by ADR-0004)*

Four mechanics depend on audio being *good*, not merely present. Teams reflexively defer audio.

| | |
|---|---|
| Probability | **High** (this is the default failure mode of every project) |
| Impact | Major |
| Trigger | Any milestone reaching its gate without an audio pass |
| Owner | Production |

**MetaSounds** makes the procedural side of this much easier — the tap-test envelope spec, the
height mix and the gust pre-roll are all things it does natively. That reduces the *cost* but not
the *risk*: the risk was never technical, it was that audio gets deferred.

**Response:** audio is a **Definition of Done item per task**, and a milestone cannot pass its gate
without an audio pass. AUD-001 (the four tap sounds) is in M1, not M3, for exactly this reason.
Playtest M1 with the sound on or the test is invalid.

---

## R7 — Scope creep toward simulation 🟡 MEDIUM

The subject matter invites it. Every conversation about brickwork will produce a suggestion to
simulate something more accurately.

| | |
|---|---|
| Probability | High |
| Impact | Moderate |
| Trigger | any proposal to add a third meter, real statics, or per-brick physics |
| Owner | Design lead |

**Response:** the anti-pillars in [`../00-vision.md`](../00-vision.md) are binding. "Would this make
the game more accurate or more fun?" If the answer is "accurate", it's out. The design already
contains the specific defences: one wobble number, no third meter, no general destruction.

---

## R8 — Editor-driven work blocks the agent team 🔴 CRITICAL *(elevated by ADR-0004)*

| | |
|---|---|
| Probability | **High** (was Medium) |
| Impact | **Major** — it is the throughput ceiling for the whole project |
| Trigger | `make editor-queue` grows for two consecutive weeks |
| Owner | Production |

**Now the top risk on the register.** Unreal's asset formats (`.uasset`, `.umap`) are binary and
Blueprints are binary graphs — agents cannot read or write any of it. This was the known cost of
ADR-0004 and it is why that ADR exists as a written decision rather than a drift.

**Mitigations, already in place:**
- `SteeplejackSim` is a **non-Unreal C++ module** that builds standalone. ~45% of the work and 100%
  of the gameplay logic stays text, diffable and testable in 20 seconds with no engine.
- Levels are JSON; structures are procedural. No `.umap` holds level content.
- Blueprints are glue only — banned from holding gameplay decisions or ticking.
- `make editor-queue` makes the backlog visible instead of letting it silently block a wave.

**Response if it triggers:** move more presentation work into C++ (`SteeplejackGame`) and out of
Content — procedural materials over authored ones, C++ widgets over UMG graphs. Slower to iterate,
but it unblocks agents. If the queue is still growing after that, the honest answer is that the
project needs a second human, and that should be said out loud rather than absorbed.

---

## R11 — Photoreal fidelity with no art team 🟠 HIGH *(new, from ADR-0004)*

The visual target is the key art. There is no dedicated artist.

| | |
|---|---|
| Probability | Medium-high |
| Impact | Major — it is the reason for the engine change |
| Trigger | ART-010's blind sort test fails, or ART-020 slips past 3 weeks |
| Owner | Project lead |

**Why it might still work:** the geometry is procedural and simple, the materials are bought
(Megascans), the town is silhouette-and-fog, and 80% of the key art's impact is lighting and
composition rather than material fidelity. See
[`../01-gdd/13-art-direction.md`](../01-gdd/13-art-direction.md) — *photoreal where you look,
stylised where you don't*.

**The single point of failure is the character (ART-020).** Everything else is procedural, scanned
or instanced. At this fidelity a mediocre character beside a scanned brick wall looks *worse* than a
stylised one, because photoreal has no tolerance for inconsistency.

**Response:** MetaHuman first (fast, good, and a generated face carries no likeness risk). If that
is unacceptable, commission one — it is one asset and it is worth real money. If neither happens,
**fall back to a stylised-realist target across the board** rather than shipping an inconsistent
one. A consistent stylised game looks better than an inconsistent photoreal one, always.

---

## R9 — Vertigo / motion sickness excludes players 🟡 MEDIUM

The game is *about* being very high up.

| | |
|---|---|
| Probability | Medium |
| Impact | Moderate (audience size, reviews) |
| Trigger | M3 external playtest reports |
| Owner | Design + engineering |

**Response:** the accessibility doc already defaults camera sway and head bob to **off**, and
provides "reduce look-down" and a minimal fall camera. Add these to the M3 playtest survey
explicitly. If it's still a problem, add a "low-vertigo" preset that ships on by default with a
prompt on first launch.

---

## R10 — Likeness / IP complaint 🟡 MEDIUM *(elevated by ADR-0004)*

Raised from LOW: a photoreal character makes an accidental likeness far more consequential than a
stylised one would, and the denylist check is currently **inert** (no terms configured).

| | |
|---|---|
| Probability | Low-medium |
| Impact | Moderate (rework, reputational) |
| Trigger | any content review flagging a direct reference |
| Owner | Production |

**Response:** [`../05-legal/ip-and-likeness.md`](../05-legal/ip-and-likeness.md) is binding on all
content, is checked at every milestone gate, and is a blocking item in the DoD for VO and writing.

Two open actions:
1. **Populate `tools/likeness_denylist.local.txt`.** Rule 16 does nothing until this is done and
   reports itself as INERT on every run. Pre-M0, project lead.
2. **ART-020's likeness review is a blocking acceptance criterion**, and the source of the character
   design must be recorded. Briefed from a description, never from a photograph.

---

## Risk register summary

| | Risk | Level | Moved |
|---|---|---|---|
| R8 | Editor work blocks the agent team | 🔴 CRITICAL | ▲ from MEDIUM (ADR-0004) |
| R1 | The climbing loop is boring | 🔴 CRITICAL | — |
| R11 | Photoreal fidelity with no art team | 🟠 HIGH | new (ADR-0004) |
| R4 | The LATTICE movement set is a second game | 🟠 HIGH | — |
| R5 | Twelve levels is too much content | 🟠 HIGH | — |
| R2 | Hand IK is harder than estimated | 🟡 MEDIUM | ▼ from HIGH (ADR-0004) |
| R3 | The felling system is a research project | 🟡 MEDIUM | ▼ from HIGH (ADR-0004) |
| R6 | Audio treated as polish | 🟡 MEDIUM | — |
| R7 | Scope creep toward simulation | 🟡 MEDIUM | — |
| R9 | Vertigo / motion sickness | 🟡 MEDIUM | — |
| R10 | Likeness / IP complaint | 🟡 MEDIUM | ▲ from LOW (ADR-0004) |

**Net effect of the engine change: three risks down, two up, one new.** The ones that went down are
technical and the ones that went up are organisational — which is the honest shape of the trade.

## Risk review cadence

Reviewed at every milestone gate. A risk that hasn't been re-scored in two milestones is stale and
gets deleted or re-owned. **Do not let this document become decoration.**
