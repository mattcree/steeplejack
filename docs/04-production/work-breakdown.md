# Work Breakdown

Task IDs are stable and referenced from commits (`CLIMB-004: seat the dog`). Estimates are in
**ideal days** for one competent worker.

**Discipline tags:** `ENG` engineering · `DES` design · `ART` art · `AUD` audio · `TECH-ART` ·
`PROD` production · `EDITOR` requires a human in the Godot editor

Status legend: ⬜ not started · 🟡 in progress · ✅ done · ⛔ blocked

---

## M0 — Foundations (2 weeks)

| ID | Task | Disc | Est | Depends on | Acceptance |
|---|---|---|---|---|---|
| ⬜ CORE-001 | Godot project, folder structure, `.gitignore`, `project.godot` settings | ENG | 0.5 | — | project opens; Forward+ renderer; 60 Hz physics tick |
| ⬜ CORE-002 | CI: `gdlint`, `gdformat --check`, headless GUT run | ENG | 1 | CORE-001 | green on an empty test |
| ⬜ CORE-003 | `sim/rng.gd` seeded xorshift + tests | ENG | 0.5 | CORE-001 | same seed → same 10k sequence, twice |
| ⬜ CORE-004 | `sim/types.gd` plain structs (Joint, Anchor, Section, Stack, Meters…) | ENG | 1 | CORE-003 | no `Node` anywhere in `sim/` (CI lint rule) |
| ⬜ CORE-005 | Fixed-step driver with accumulator + render interpolation | ENG | 1.5 | CORE-004 | sim steps exactly 60×/s at 30 and 144 fps |
| ⬜ CORE-006 | Intent recorder + replay playback | ENG | 2 | CORE-005 | record 60 s, replay, states identical tick-for-tick |
| ⬜ CORE-007 | Tuning JSON loader + hot reload (F5) | ENG | 1 | CORE-004 | editing `meters.json` changes behaviour without restart |
| ⬜ CORE-008 | Level JSON schema + loader + CI validator | ENG | 1.5 | CORE-007 | a malformed level fails CI with a useful message |
| ⬜ CORE-009 | Reachability solver (can a route to the top exist?) | ENG | 2 | CORE-008 | a deliberately unwinnable test level fails validation |
| ⬜ STRUCT-001 | Procedural chimney builder: round profile, batter, bands, cap | ENG/TECH-ART | 3 | CORE-008 | 55 m chimney from JSON, 1 draw call, correct UVs |
| ⬜ STRUCT-002 | Joint grid generation from band definitions | ENG | 2 | STRUCT-001 | quality distributions match the JSON within 2% |
| ⬜ PLAYER-001 | Capsule character controller, walk/climb states | ENG | 2 | CORE-005 | can walk the field and mount a placed ladder |
| ⬜ CAM-001 | Camera rig: climb + work + top modes | ENG | 2 | PLAYER-001 | no clipping through the chimney at any angle |
| ⬜ PROD-001 | Confirm **ADR-0001** (engine) with the project lead | PROD | 0.5 | — | ADR status → Accepted |

**M0 total: ~20 ideal days.**

---

## M1 — The Ascent / MVP (4 weeks)

### Verbs

| ID | Task | Disc | Est | Depends on | Acceptance |
|---|---|---|---|---|---|
| ⬜ VERB-001 | Tap-test: aim, 0.8 s action, four outcomes | ENG | 1 | STRUCT-002 | tier returned matches the joint's hidden quality |
| ⬜ AUD-001 | **The four tap sounds** (record real foley) | AUD | 2 | — | 8/8 testers distinguish all four on laptop speakers |
| ⬜ VERB-002 | Reticle waveform pip (accessibility fallback) | ENG/ART | 1 | VERB-001 | four distinct **shapes**, not colours |
| ⬜ VERB-003 | Hammer: draw/release, power arc, angle error, depth accumulation | ENG | 3 | CORE-007 | the tuning table in `climbing.json` fully drives it |
| ⬜ VERB-004 | Bent dogs, spalled brick, anchor rating computation + tests | ENG | 1.5 | VERB-003 | unit tests cover all four rating outcomes |
| ⬜ ART-001 | Hammer animation: anticipation, arc, **2-frame impact hold** | ART/EDITOR | 2 | VERB-003 | "spend a week on the hammer" — see camera/feel doc |
| ⬜ AUD-002 | Hammer impact bank (by joint tier), dust puff, screen impulse | AUD/ENG | 1.5 | ART-001 | transient is audible over wind at 90 m |
| ⬜ VERB-005 | Lash: stick rotation → wraps, tension arc, hitch vs. full | ENG | 2 | VERB-004 | 3-wrap lashing measurably drifts under load over 60 s |
| ⬜ VERB-006 | Lash accessibility alternatives (mash / hold-only) | ENG | 0.5 | VERB-005 | all three inputs produce identical outcomes |
| ⬜ VERB-007 | Haul: gin wheel, 2-DOF pendulum ODE, steer-to-damp, foul | ENG | 2.5 | CORE-005 | swing damping is learnable; foul triggers correctly |

### The stack

| ID | Task | Disc | Est | Depends on | Acceptance |
|---|---|---|---|---|---|
| ⬜ CLIMB-001 | `sim/stack.gd`: sections, spans, span bands, buckle | ENG | 2 | VERB-005 | the span table in the GDD is reproduced exactly |
| ⬜ CLIMB-002 | Load sharing (0.55 falloff) + cascade failure | ENG | 2 | CLIMB-001 | a cascade from anchor 8 fails 7,6,5 in order, deterministically |
| ⬜ CLIMB-003 | Ladder MultiMesh + **flex vertex shader** driven by span & load | TECH-ART | 2 | CLIMB-001 | visible bend at 5 m span; none at 3 m |
| ⬜ CLIMB-004 | Climb/transition states + slide-down | ENG | 2 | PLAYER-001 | transition onto a new section costs grip and feels deliberate |
| ⬜ CLIMB-005 | **Hand & foot IK onto rungs** | ENG/ART/EDITOR | 4 | CLIMB-004 | hands land on actual rungs at every span and lean |
| ⬜ CLIMB-006 | Stack serialisation (the checkpoint) | ENG | 1 | CLIMB-002 | quit mid-climb, reload, stack is identical |

### Meters

| ID | Task | Disc | Est | Depends on | Acceptance |
|---|---|---|---|---|---|
| ⬜ METER-001 | `sim/meters.gd`: grip, all five stances, tremor | ENG | 1.5 | CORE-007 | matches `meters.json` exactly; unit tested |
| ⬜ METER-002 | Nerve: height/wind/exposure factors, shocks, thresholds | ENG | 1.5 | METER-001 | the four low-nerve effect bands trigger at spec values |
| ⬜ METER-003 | `sim/wobble.gd` — the one number | ENG | 0.5 | METER-002 | every verb reads it; no verb computes its own wobble |
| ⬜ METER-004 | Recovery actions: stand, **brew up**, cigarette, look at view | ENG/ART | 2 | METER-002 | tea is a 12 s camera-locked set-piece |
| ⬜ METER-005 | Slip-save + fall + resume-at-stack | ENG | 2 | CLIMB-006 | slip-save budget of 1/60 s enforced |
| ⬜ UI-001 | HUD: grip/nerve arcs, anchor pips (in-world), material counts | ENG/ART | 2 | METER-003 | fades out when idle; readable at 720p |

### World & feel

| ID | Task | Disc | Est | Depends on | Acceptance |
|---|---|---|---|---|---|
| ⬜ ENV-001 | Height fog + distance fog, tuned | TECH-ART | 1.5 | STRUCT-001 | the town goes blue with distance; break-through-fog works |
| ⬜ ENV-002 | Town silhouette backdrop (grey box, instanced) | ART | 1.5 | ENV-001 | ≤ 12 draw calls |
| ⬜ ENV-003 | Wind: speed curve by height, gusts, **1.2 s audio pre-roll** | ENG/AUD | 2 | METER-002 | the tell is learnable; screen-edge streaks as fallback |
| ⬜ AUD-003 | **Height mix**: ground ambience falloff, reverb, wind ramp | AUD/ENG | 2.5 | ENV-002 | a blindfolded tester can estimate height within 20 m |
| ⬜ AUD-004 | Rope, ladder, boot, breathing foley | AUD | 2 | — | — |
| ⬜ CAM-002 | Haul camera (looks down the rope), fall camera, top camera | ENG | 1.5 | CAM-001 | the haul shot sells the height |
| ⬜ A11Y-001 | Motion options (sway, bob, shake, FOV, fall camera) | ENG | 1 | CAM-002 | all default-safe per the accessibility doc |
| ⬜ LVL-000 | Grey-box MVP level JSON (55 m, 4 bands) | DES | 0.5 | CORE-008 | passes the reachability validator |

### Verification

| ID | Task | Disc | Est | Depends on | Acceptance |
|---|---|---|---|---|---|
| ⬜ TEST-001 | Unit tests for every `sim/` module | ENG | 3 | all sim | ≥ 90% line coverage in `sim/` |
| ⬜ TEST-002 | Replay regression harness + one recorded expert run | ENG | 1 | CORE-006 | CI fails if the run's outcome changes |
| ⬜ PT-001 | **MVP playtest with 8 strangers** | PROD/DES | 2 | everything | the seven MVP criteria, scored and written up |

**M1 total: ~63 ideal days.**

---

## M2 — First Job (4 weeks)

| ID | Task | Disc | Est | Depends on | Acceptance |
|---|---|---|---|---|---|
| ⬜ MISS-001 | Mission state machine (SET UP → FIDDLY → COMPLICATION → CLEAR UP) | ENG | 2 | M1 | drives from level JSON |
| ⬜ MISS-002 | CONDUCTOR: tape reel, clips, taut/vertical check, routing | ENG | 3 | MISS-001 | a wandering run visibly fails inspection |
| ⬜ MISS-003 | Earth pit + continuity test (the payoff beat) | ENG/ART/AUD | 1 | MISS-002 | needle + buzzer, satisfying |
| ⬜ SHIFT-001 | Daylight clock, the top-edge bar, end-of-shift handling | ENG/UI | 1.5 | M1 | bar appears only after 60% elapsed |
| ⬜ WEATH-001 | Weather ramp (the storm), precipitation, wet-grip modifier | ENG/TECH-ART | 2.5 | ENV-003 | 90 s audiovisual front; no cliff edge |
| ⬜ SCORE-001 | `sim/scoring.gd` + the reckoning screen (handwritten invoice) | ENG/ART | 3 | MISS-001 | every line item traces to a player action |
| ⬜ FAIL-001 | Fall consequences: hospital beat, lost fee, **persistent injuries** | ENG/ART | 2 | METER-005 | max one injury carried; 2–3 job duration |
| ⬜ HUB-001 | Van / loadout screen | ENG/UI | 2 | SCORE-001 | no "recommended loadout" button |
| ⬜ LVL-001 | Level 01 — The Back Yard (full) | DES | 2 | MISS-001 | including the Great Aire reveal |
| ⬜ LVL-002 | Level 02 — Sweeper's Row (full) | DES | 3 | MISS-002, WEATH-001 | |
| ⬜ VERB-008 | Lateral traversal (re-dogging sideways) | ENG | 1.5 | CLIMB-004 | needed by L01's fourth defect |
| ⬜ MISS-004 | SURVEY: defect finding + chalk marking | ENG | 1.5 | MISS-001 | four defect types |
| ⬜ A11Y-002 | Audio→visual cue system (master toggle + per-cue) | ENG | 2 | all cues | game fully playable muted |
| ⬜ TEST-003 | Replay regressions for L01 and L02 | ENG | 1 | TEST-002 | |
| ⬜ PT-002 | Playtest: L01→L02 unaided, 8 people | PROD/DES | 2 | all | see M2 gate |

**M2 total: ~30 ideal days.**

---

## M3 — Vertical Slice (6 weeks) — summary

| ID | Task | Disc | Est |
|---|---|---|---|
| ⬜ MISS-010 | Bosun's chair rig/unrig + chair stance | ENG | 3 |
| ⬜ MISS-011 | GILD: seized nut, penetrating oil, rounding | ENG | 2 |
| ⬜ MISS-012 | **Controlled lower** (the 90 s rope descent) | ENG/CAM/AUD | 3 |
| ⬜ MISS-013 | Gilding verb: size / leaf / burnish + hold-breath | ENG | 3 |
| ⬜ MISS-014 | MEASURE verb: tape circumference, plumb bob | ENG | 2 |
| ⬜ MISS-015 | BAND: haul heavy segments, bolt sequence, star tensioning, rework | ENG | 4 |
| ⬜ VERB-009 | BOLT verb incl. seizure and rounding | ENG | 1.5 |
| ⬜ STRUCT-003 | Spire + octagonal + square-to-round profiles | ENG/TECH-ART | 3 |
| ⬜ STRUCT-004 | Internal routes (tower stairs, caged ladders) | ENG/ART | 2 |
| ⬜ HUB-002 | The yard: bench, board, kettle, whippet | ART/ENG | 5 |
| ⬜ HUB-003 | **The engine**: 40 progressive states, purchase flow | ART/ENG | 6 |
| ⬜ ECON-001 | Money, reputation, upgrades, tool condition, the lad | ENG | 3 |
| ⬜ ART-010 | **Brick shader** (procedural, weathering, quality read) | TECH-ART | 5 |
| ⬜ ART-011 | Character model + rig + animation set | ART | 8 |
| ⬜ ART-012 | Town building kit (40 pieces) + canal + railway | ART | 6 |
| ⬜ AUD-010 | Music cues (yard, setting off, the top, brew up) | AUD | 5 |
| ⬜ AUD-011 | First voice session | AUD | 3 |
| ⬜ UI-010 | Options + full accessibility UI | ENG/UI | 4 |
| ⬜ LVL-003 | Level 03 — St Chad's | DES | 4 |
| ⬜ LVL-004 | Level 04 — Alma Mill | DES | 4 |
| ⬜ PT-003 | **External playtest, 15+ players** | PROD/DES | 4 |

**M3 total: ~80 ideal days.**

---

## M4 — The Marquee (8 weeks) — summary

| ID | Task | Disc | Est |
|---|---|---|---|
| ⬜ TOP-001 | Cell grid, course auto-resolve shader clipping | ENG/TECH-ART | 4 |
| ⬜ TOP-002 | Staging: build, step onto, **lower every 2 m** | ENG/ART | 4 |
| ⬜ TOP-003 | Coping interlock puzzle + peel failure | ENG/DES | 2 |
| ⬜ TOP-004 | PRISE verb: seat/drive/lever, the give, snap | ENG/AUD | 3 |
| ⬜ TOP-005 | Flue drop: **the falling-brick sound**, jams, clearing, fill | ENG/AUD | 3 |
| ⬜ TOP-006 | Strike-your-own-stack handling | ENG | 2 |
| ⬜ TOP-007 | Complications: nest, tie bar, soot fall, perished band | ENG/ART | 3 |
| ⬜ FELL-001 | Survey mode: plumb bob, pacing, pegs, sight lines, fan overlay | ENG/UI | 4 |
| ⬜ FELL-002 | `sim/gob.gd`: cells, support polygon, CoG, margin bands | ENG | 3 |
| ⬜ FELL-003 | Props: placement, load, splitting, the dud | ENG | 2 |
| ⬜ FELL-004 | Chalk load diagram (diegetic + HUD) | ENG/ART | 3 |
| ⬜ FELL-005 | Escalating groan/dust audio-visual dread system | AUD/TECH-ART | 3 |
| ⬜ FELL-006 | Pack, light (wind vs. match), **run** | ENG | 2 |
| ⬜ FELL-007 | Pre-fracture pipeline (60–90 chunks from the builder) | TECH-ART | 4 |
| ⬜ FELL-008 | `sim/fell.gd`: hinge solver, bending fracture, angular error | ENG | 5 |
| ⬜ FELL-009 | Impact, rubble freeze, **the dust column** | TECH-ART | 5 |
| ⬜ FELL-010 | Fall audio: silence, crack, roar, thump, rain, birds, cheer | AUD | 4 |
| ⬜ FELL-011 | Fall perf work (LOD drop, body cap, 33 ms ceiling) | ENG | 3 |
| ⬜ LVL-005/6/7 | Levels 05, 06, 07 | DES | 12 |
| ⬜ TEST-010 | Fell determinism ×100 + 3 replay regressions | ENG | 2 |
| ⬜ PT-004 | Playtest the fellings | PROD/DES | 3 |

**M4 total: ~80 ideal days.**

---

## M5 — Content Complete (10 weeks) — summary

| ID | Task | Disc | Est |
|---|---|---|---|
| ⬜ MECH-001 | MECHANISM: hand removal/fitting, clock gearing puzzle, the bell | ENG/ART/AUD | 6 |
| ⬜ LAT-001 | **Steel movement set**: climb steel, lanyard leapfrog, rest spots | ENG/ART | 8 |
| ⬜ LAT-002 | Lattice structure builder + the 3D maze with dead ends | ENG/TECH-ART | 5 |
| ⬜ LAT-003 | Hot riveting (temperature colour read, 9 s window) | ENG/ART/AUD | 4 |
| ⬜ LAT-004 | Corroded members, the lift, the crowd nerve modifier | ENG | 3 |
| ⬜ CONC-001 | Concrete: expansion bolts, star drill, void tap signatures | ENG/AUD | 3 |
| ⬜ LVL-008..012 | Levels 08, 09, 10, 11, 12 | DES | 25 |
| ⬜ ECON-002 | Full progression tune across 12 levels | DES | 4 |
| ⬜ HUB-004 | The engine's completion + both endings + credits | ART/ENG | 5 |
| ⬜ AUD-020 | Full VO recording and implementation | AUD | 8 |
| ⬜ TEST-020 | All 12 replay regressions recorded and green | ENG | 3 |

**M5 total: ~74 ideal days.**

---

## M6 — Polish & Ship (4 weeks) — summary

| ID | Task | Disc | Est |
|---|---|---|---|
| ⬜ PERF-001 | Hit budget on all three platform targets | ENG | 8 |
| ⬜ A11Y-010 | Full accessibility audit + fixes | ENG/PROD | 5 |
| ⬜ BUG-001 | Bug burn-down | all | 15 |
| ⬜ LOC-001 | String extraction + pseudo-loc | ENG | 3 |
| ⬜ SHIP-001 | Store page, trailer (the L06 fall), demo build (L01–02) | PROD/ART | 6 |

---

## Critical path

```
CORE-005 → CORE-006 → [all sim work]
STRUCT-002 → VERB-001/003 → CLIMB-001 → CLIMB-002 → CLIMB-005 → PT-001  ← THE GATE
                                                          ↓
                                              MISS-001 → everything else
                                                          ↓
                                              TOP-00x → FELL-00x → LVL-006
```

**CLIMB-005 (hand IK) is the longest single task before the M1 gate and the highest-value piece of
animation work in the project. Start it early and give it to your best person.**
