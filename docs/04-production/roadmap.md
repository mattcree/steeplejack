# Roadmap

> **2026-09-19 — Unreal is removed from the project ([ADR-0006](../03-tech/adr/0006-move-to-godot.md)):** the milestone plans below name Unreal work (the two-module project, Nanite, Chaos, Niagara, a self-hosted UE runner). The game is Godot now; read those items for their intent, not their tools.

Seven milestones. Each has a **gate** — a question that must be answered before the next begins.
Durations assume a small team (2–4 people or an agent team of equivalent throughput) and are
deliberately not padded; treat them as ordering and relative weight, not commitments.

---

## M0 — Foundations (2 weeks)

Build the skeleton that everything else hangs on. No gameplay.

- Unreal 5.8 project with **two modules**; `SteeplejackSim` building standalone under CMake
- CI: the fast job group and the sim job group, both without Unreal installed
- Git LFS and the `Content/` size gate, before the first binary asset
- **Fixed-step sim driver + intent recording + replay playback** (ADR-0003)
- `SteeplejackSim` skeleton: typed structs, seeded RNG, tuning loader, level loader
- Procedural chimney builder (round profile, Nanite) + joint grid generation
- Capsule character, basic camera, grey-box field
- A self-hosted runner with UE 5.8, and the `game` CI job enabled

**Gate:** `make ci` is green on a GitHub-hosted runner **with no Unreal installed** — the sim loads
a level JSON, generates a joint grid, steps 10,000 times and produces identical results twice. Plus
`make build-game` compiles on the self-hosted runner.

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
- **Art pass on levels 01–04** — town kit, hub, set dressing (the brick material, lighting and
  character already landed in M1, because they became gameplay dependencies under ADR-0004)
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
- **Chaos Geometry Collection** pre-fracture pipeline and the fall perf work
- Niagara dust and destruction VFX

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

## What ADR-0004 changed about this plan

The engine change did not move the milestone structure, but it moved three things inside M1:

- **ART-010 (brick master material)** and **ENV-010 (lighting baseline)** moved from M3 to M1.
  Under the old art direction they were polish; under the new one the material *is* the
  joint-quality read, so they are gameplay dependencies of the MVP test.
- **ART-020 (the character)** is new in M1 and is the art direction's single point of failure.
- **CLIMB-005 (hand IK)** left the critical path, because Control Rig made it cheaper. The critical
  path is now the sim chain: `CORE-004 → CORE-008 → STRUCT-002 → VERB-003 → VERB-004 → VERB-005 →
  CLIMB-001 → CLIMB-002 → CLIMB-006 → METER-005`. That chain is entirely agent-executable and needs
  no engine, which is a good property for the schedule to have.

M1 grew from 63 to ~78 ideal days. The M1 gate is unchanged and still the only one that can kill
the project.

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
