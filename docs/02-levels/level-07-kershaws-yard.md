# Level 07 — Kershaw's Yard

## At a glance

| | |
|---|---|
| **Archetype** | FELL (constrained) |
| **Height** | 65 m |
| **Structure** | Square-to-round brick chimney, tight urban yard |
| **Fee** | £1,250 |
| **Shift length** | 120 min |
| **Target completion** | 105 min |
| **Weather** | drizzle, 7 m/s, poor light |
| **Reputation gate** | ★★★☆☆ |
| **New to the player** | nothing. Only pressure. |

## The one-line pitch
The same job as Level 6 with **28 degrees of room instead of 180**, a lean pointing the wrong way,
and a prop that splits at the worst moment. This is where the player finds out whether they
understood the system or just got lucky.

## Briefing

> *Kershaw's Yard, Hebble Lane*
> *Chimney to be felled. I will not pretend it is an easy one. There is the Bethel chapel on the one
> side and Kershaw's own weaving shed on the other and about thirty foot of daylight between them.
> Three men have looked at it and two have said no.*
> *£1,250. The chapel is insured for eleven thousand pounds.*
> *H. Kershaw*

## Site layout

```
        ╔═══════════╗
        ║  BETHEL   ║  ← chapel. CATASTROPHIC. bearing 062°, 24m
        ║  CHAPEL   ║
        ╚═══════════╝
                ▓        ← 65m chimney, lean 1.4° toward 070° (TOWARD THE CHAPEL)
                ▓
   ┌────────────────────┐
   │  weaving shed      │  ← bearing 118°, 20m. £2,400 and it's the client's.
   └────────────────────┘
        ↓ the corridor: bearing 084°–112°, 28° wide, down the yard
        ↓ [rubble ground, old canal arm at 90m]
```

**The corridor is 28° wide. The lean is 1.4° toward 070°, which is 14° outside the corridor, and
lean pulls hard.** The player must *overcut* against the lean — cutting the gob asymmetrically so
the hinge resists the lean — which is the advanced technique the level exists to teach.

The game does not explain this. It gives the player a live predicted-accuracy readout and lets them
discover that moving the gob's centre off the fall line by ~10° corrects a 1.4° lean. Twenty minutes
of experimentation with a load diagram, which is exactly the fun.

## Ascent bands

| From | To | Band | What it asks |
|---|---|---|---|
| 0 | 12 m | **Square base** | four flat faces, dead corners |
| 12 | 20 m | **Square-to-round transition** | a 8 m band of chamfered, awkward geometry. Ladders don't sit. Heavy shimming. |
| 20 | 44 m | **Round shaft, wet** | drizzle: grip ×1.4, no sliding, joints read one tier worse than they are |
| 44 | 65 m | **Two bands + perished top** | strip-out targets |

## The work

### Act 1: Survey (10 min)
The hard survey. Both exclusion objects are close and valuable. The corridor must be found by
*walking* it. The lean must be measured properly — eyeballing it here will cost the job.

**Expert action strongly rewarded:** pacing the height tightens the debris fan from ±18° to ±11°,
which is the difference between "the chapel might catch some" and "it won't."

### Act 2: Strip Out (25 min)
Bands off, conductor off. **The briefing recommends taking 8 m off the top** to improve
predictability (accuracy improves ~1.5°/5 m → ~2.4°). At the rate
[the felling system](../01-gdd/06-felling-system.md) gives — 40 seconds a metre — that is **about
five and a half minutes** of shift.

> **Corrected 2026-09-20 ([FELL-006](../../tasks/FELL-006.md)).** This said "~12 minutes", which is 90 seconds a metre and
> disagrees with the system doc. The system doc wins: it is the spec for the system, and the 40
> seconds is the number the game quotes the player. Per AGENTS.md rule 9, one of them was a bug.
>
> That correction makes the trade *cheaper than it is supposed to be*, and worth saying plainly:
> **it is not yet a decision.** Act 2's climbing is not implemented, so nothing else is spending
> the shift, and taking the full allowance off the top is simply free accuracy. The trade becomes
> real when the strip-out and the ascent are priced against the same clock, and not before. The
> cap (`fellMaxHeightReductionM`, and 28% of the chimney) is what stands in for that until then.

### Act 3: The Gob (40 min)
- **Mortar asymmetry:** the south side is `strengthBias +0.35` — much harder to cut. Working the
  gob evenly takes longer on one side, and rushing it leaves an unbalanced support.
- 16 props. **Prop #9 is a dud** — it splits under load at roughly 70% completion, with a bang, and
  the margin drops from SAFE straight to CRITICAL in half a second.
  - The correct response: stop, back off, set two replacement props before continuing.
  - The panicked response: keep cutting. Which is how the chimney comes down on you.
  - Telegraph: prop #9 is **visibly knotty and split-ended if you look at it** when placing it, and
    the character mutters "that one's a bit shakey." Players who inspect their props are rewarded.
    Players who don't get the lesson the hard way. **Fair.**

### Act 4: Fire, Run, Watch (5 min)
Safe line at 100 m — which in this yard means going *out of the yard* and round a corner, so you
watch from a gap between two buildings. A completely different and more claustrophobic framing of
the game's best moment.

## Beats
1. Walking the 28° corridor and realising how narrow it is.
2. The plumb bob reading 070° and the sinking feeling.
3. The square-to-round transition — eight metres of the most annoying ladder work in the game.
4. Discovering, in the load diagram, that you can steer against the lean.
5. **HERO BEAT:** prop #9 splits. Bang, dust, the diagram goes red, and you are standing inside a
   65 m chimney that has just changed its mind.
6. Watching it go down a 28° corridor from behind a wall.

## Failure modes
All of Level 6's, plus:
| Failure | Telegraph | Consequence |
|---|---|---|
| Ignored the dud prop | visible split + a spoken line at placement | CRITICAL margin, 6 s to run |
| Undercorrected for lean | predicted accuracy readout | fall lands 8–14° off, likely chapel contact |
| Overcorrected | same readout | it goes into the weaving shed. Client's own building. Worse in a funnier way. |

## Scoring
```
Base                                  £1,250
Angular error ≤5°                     +£400
              ≤15°  (the corridor)    +£150
Clean break-up                        +£80
No collateral                         +£150
Before dark                           +£40
Weaving shed contact                  −£600 (capped)
CHAPEL CONTACT                        JOB FAILED, reputation −15
```

## Data
`data/levels/07-kershaws-yard.json`
