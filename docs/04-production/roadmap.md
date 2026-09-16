# Roadmap

Seven milestones. Each has a **gate** — a question that must be answered before the next begins.
Durations assume a small team (2–4 people or an agent team of equivalent throughput) and are
deliberately not padded; treat them as ordering and relative weight, not commitments.

---

## M0 — Foundations (2 weeks)

Build the skeleton that everything else hangs on. No gameplay.

- Godot project, CI, lint/format, GUT harness
- **Fixed-step sim driver + intent recording + replay playback** (ADR-0003)
- `sim/` module skeleton with typed structs and a seeded RNG
- Tuning JSON loader with hot reload
- Level JSON schema + validator + reachability solver stub
- Procedural chimney builder (round profile only) + joint grid generation
- Capsule character, basic camera, grey-box field

**Gate:** a headless test can load a level JSON, generate a joint grid, step the sim 10,000 times,
and produce identical results twice. Plus: `godot --headless -s tests/run_tests.gd` is green in CI.

---

## M1 — The Ascent (4 weeks) ← **THE CRITICAL MILESTONE**

The MVP. See [`mvp.md`](mvp.md).

**Gate:** the seven MVP criteria, tested on eight strangers. **This is the only gate that can kill
the project, and it should be allowed to.**

---

## M2 — First Job (4 weeks)

Turn a climb into a job.

- CONDUCTOR mission system (tape, clips, taut/vertical check, earth pit, continuity test)
- Daylight/shift clock; the weather ramp and the storm
- The reckoning screen (fully itemised)
- Fall consequences: hospital, lost fee, persistent injuries, resume-at-stack
- Level 01 and Level 02, playable start to finish
- HUD complete; first-pass accessibility toggles
- Hub stub: the van/loadout screen only

**Gate:** a stranger plays Level 01 → Level 02 unaided, understands the reckoning without
explanation, and wants to play Level 03.

---

## M3 — Vertical Slice (6 weeks)

The build that goes to external playtest and, if wanted, to a publisher.

- GILD mission (bosun's chair, fine-motor verbs, the controlled lower)
- BAND mission (lateral traversal, heavy haul, measurement & rework)
- Levels 01–04 complete
- Hub complete: the yard, the job board, the bench, the kettle, **the engine**
- Economy, reputation, upgrades
- **Art pass on levels 01–04** — brick shader, fog, town kit, character model, animation
- **Audio pass** — the full tap bank, height mix, music cues, first voice lines
- Options menus + accessibility complete

**Gate:** external playtest, 15+ players, 90-minute sessions. Target: ≥ 70% complete all four levels;
≥ 60% say they would buy it; the tea break is mentioned unprompted by ≥ 3 players.

---

## M4 — The Marquee (8 weeks)

The two big systems.

- **TOP system**: staging, coping interlock, prise verb, cell grid, jams, complications
- **FELL system**: survey, gob solver, props, fire, hinge/fracture solver, the fall, scoring
- Levels 05, 06, 07
- Pre-fracture pipeline and the fall perf work
- Dust and destruction VFX

**Gate:** all three fellings pass the determinism regression test 100 times. A playtester correctly
predicts the fall direction of Level 06 before lighting it. The Level 06 fall makes somebody swear.

---

## M5 — Content Complete (10 weeks)

- MECHANISM mission + Level 08
- Levels 09, 10
- **LATTICE movement set** + Level 11 (the biggest single content risk — see risks)
- Level 12
- Progression tuning end to end; the engine's 40 states; both endings
- Full voice recording
- All 12 replay regressions recorded and green

**Gate:** a player can complete the campaign start to finish with no blockers, on all three
difficulties, on all three platform targets.

---

## M6 — Polish & Ship (4 weeks + buffer)

- Performance to budget on all three targets
- Bug burn-down
- Accessibility audit against [`../01-gdd/14-accessibility.md`](../01-gdd/14-accessibility.md)
- Localisation extraction (strings only; VO stays English)
- Store page, trailer (**the Level 06 fall is the trailer**), demo build (Levels 01–02)

**Gate:** ship.

---

## Total: ~38 weeks of milestone work

Add 25% buffer. Plan for **48 weeks**.

## Ordering rules

1. **Nothing from M2 onward starts before M1's gate passes.** This is the whole point.
2. TOP (M4) must land before FELL, because FELL's act 2 uses it.
3. The LATTICE movement set (M5) is the one item that could slip to a post-launch update without
   breaking the campaign — Level 11 could become a second lattice-free job. **Keep that escape
   hatch documented and don't take it unless you must.**
4. Art and audio passes are per-milestone, never deferred to the end. A milestone with no audio has
   not been tested.
