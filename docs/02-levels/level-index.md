# Level Index

Twelve levels. Nine mission archetypes. One verb set, taught by level 6, never added to after.

| # | Level | Height | Archetype | New thing | Fee | Shift | Ascent bands |
|---|---|---|---|---|---|---|---|
| 1 | [The Back Yard](level-01-back-yard.md) | 12 m | SURVEY | dog, lash, climb, tap, grip | — | none | 2 |
| 2 | [Sweeper's Row](level-02-sweepers-row.md) | 30 m | CONDUCTOR | nerve, haul, working descent, daylight | £180 | 90 | 2 |
| 3 | [St Chad's Steeple](level-03-st-chads.md) | 45 m | GILD | bosun's chair, fine motor, wind, controlled lower | £420 | 90 | 3 |
| 4 | [Alma Mill](level-04-alma-mill.md) | 55 m | BAND | lateral traversal, heavy haul, measurement | £620 | 90 | 4 |
| 5 | [The Crooked Stack](level-05-crooked-stack.md) | 60 m | TOP | staging, prise, shrinking geometry | £540 | 90 | 4 |
| 6 | [Waterside Bleachworks](level-06-waterside.md) | 70 m | **FELL** | survey, gob, props, fire — all four acts | £1,100 | 120 | 4 |
| 7 | [Kershaw's Yard](level-07-kershaws-yard.md) | 65 m | FELL (tight) | precision under constraint; a prop splits | £1,250 | 120 | 4 |
| 8 | [The Borough Clock](level-08-borough-clock.md) | 50 m | MECHANISM | heavy objects at height; the bell | £700 | 120 | 3 |
| 9 | [The Dye House Twins](level-09-dye-house-twins.md) | 45 m ×2 | TOP ×2 | shared material budget across two stacks | £1,400 | 120 | 3+3 |
| 10 | [Hartford Power Station](level-10-hartford.md) | 90 m | CONDUCTOR + EMERGENCY | storm, gusts, concrete instead of brick | £1,600 | 150 | 5 |
| 11 | [The Pleasure Tower](level-11-pleasure-tower.md) | 120 m | LATTICE | steel movement set, riveting, 3D route | £2,200 | 150 | 6 |
| 12 | [The Great Aire Chimney](level-12-great-aire.md) | 110 m | TOP → FELL | everything, in two acts | £3,400 | 150 | 6 |

**Outside the sequence:** [Level 00 — The Grey Box](level-00-greybox.md), 55 m, four bands, no
mission. Not a campaign level — it is the rig "The Ascent" is built and judged on
([`mvp.md`](../04-production/mvp.md#mvp-scope--the-ascent)). It carries `order: 99` only because
the schema has no way to express "unordered".

## Sequencing rules (enforced)

1. Never two of the same archetype back to back. (9 sits between the two TOP-heavy runs; 7 follows 6
   deliberately as the *hard* version of a thing just learned — the only permitted repeat, and it is
   the point of the pairing.)
2. Every archetype is taught at low stakes before being used at high stakes.
3. Difficulty curve is driven by **shift slack** and **wind**, not by new mechanics.
4. Levels 8 and 9 are deliberate downshifts in altitude to make 10–12 feel taller.

## Side jobs (post-MVP, optional)

| Job | Archetype | Purpose |
|---|---|---|
| Any-level SURVEY re-runs | SURVEY | low-stress money, replayable |
| **The Shaft** | descent + shoring | inverts the whole game; a garden mine shaft. Unlocked after L9. |
| Church repointing | BAND-lite | filler, teaches nothing, relaxing |

## Content status

| | Design | Data | Grey box | Art | Audio | Playable |
|---|---|---|---|---|---|---|
| **L0 grey box** | ✅ spec complete | ✅ | ⬜ | n/a — grey box | ⬜ | ⬜ |
| L1–L4 | ✅ spec complete | 🟡 L1 only | ⬜ | ⬜ | ⬜ | ⬜ |
| L5–L7 | ✅ spec complete | 🟡 L6, L7 | ⬜ | ⬜ | ⬜ | 🟡 L6, L7 felling only |
| L8–L12 | ✅ spec complete | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |

## The three fellings, and how they differ

The design says they must. `godot/scripts/test_kershaws.gd` is where "must differ" stops being a
sentence and becomes something a machine checks: that Kershaw's corridor is 28 degrees and not 180,
that its lean points outside that corridor, that cutting straight down the yard goes 9 degrees wide,
that overcutting about 8 degrees against the lean is what corrects it, and that the authored dud
prop is the tenth one in and takes the margin down with it.

| | L6 Waterside | L7 Kershaw's Yard | L12 Great Aire |
|---|---|---|---|
| Data | ✅ | ✅ | ⬜ |
| Corridor | 70° of open field | **28°**, chapel one side, the client's own shed the other | 40°, railway + gasholder |
| Lean | 0.3°, negligible | 1.4°, **28° outside the corridor** | 2.1°, and it is cracked |
| Props | 14, exactly the arc | 16, and **#9 is a dud** | — |
| Mortar | even | south side +0.35, harder to cut | — |
| Teaches | the loop | steering against a lean | everything, in two acts |
