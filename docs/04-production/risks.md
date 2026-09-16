# Risks

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

## R2 — Hand IK on procedural ladders is harder than estimated 🟠 HIGH

CLIMB-005 is 4 ideal days in the plan and could easily be 15. It is also the thing that makes the
ladders feel real.

| | |
|---|---|
| Probability | High |
| Impact | Major (feel) |
| Trigger | CLIMB-005 exceeds 8 days |
| Owner | Engineering lead |

**Response:** fall back to a **two-pose contact system** — hands snap to the nearest rung at
fixed offsets with a short blend, no full IK solve. It looks 80% as good at 20% of the cost.
Decide by day 8, not day 20.

---

## R3 — The felling system is a research project 🟠 HIGH

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

## R6 — Audio is treated as polish 🟡 MEDIUM

Four mechanics depend on audio being *good*, not merely present. Teams reflexively defer audio.

| | |
|---|---|
| Probability | **High** (this is the default failure mode of every project) |
| Impact | Major |
| Trigger | Any milestone reaching its gate without an audio pass |
| Owner | Production |

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

## R8 — Godot's editor-driven work blocks an agent team 🟡 MEDIUM

| | |
|---|---|
| Probability | Medium |
| Impact | Moderate (throughput) |
| Trigger | `EDITOR-` tagged tasks accumulate faster than a human can clear them |
| Owner | Engineering lead |

**Response:** the code-first discipline in ADR-0001 already confines editor work to the animation
tree, four shaders, and the hub scene. If it creeps, build scenes from GDScript at runtime instead
of authoring `.tscn` files — slower to iterate, but unblocks agents completely.

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

## R10 — Likeness / IP complaint 🟢 LOW

| | |
|---|---|
| Probability | Low |
| Impact | Moderate (rework, reputational) |
| Trigger | any content review flagging a direct reference |
| Owner | Production |

**Response:** [`../05-legal/ip-and-likeness.md`](../05-legal/ip-and-likeness.md) is binding on all
content, is checked at every milestone gate, and is a blocking item in the DoD for VO and writing.

---

## Risk review cadence

Reviewed at every milestone gate. A risk that hasn't been re-scored in two milestones is stale and
gets deleted or re-owned. **Do not let this document become decoration.**
