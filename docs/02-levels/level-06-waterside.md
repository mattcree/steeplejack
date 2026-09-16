# Level 06 — Waterside Bleachworks

## At a glance

| | |
|---|---|
| **Archetype** | **FELL** (all four acts, taught) |
| **Height** | 70 m |
| **Structure** | Round brick chimney, derelict bleachworks, open field on three sides |
| **Fee** | £1,100 |
| **Shift length** | 120 min |
| **Target completion** | 95 min |
| **Weather** | clear, cold, 4 m/s, still air at ground level |
| **Reputation gate** | ★★★☆☆ |
| **New to the player** | the survey, the gob, props, fire — the entire felling system |

## The one-line pitch
The marquee mechanic, taught on the most forgiving site in the game: 180° of open field, negligible
lean, no authored twist. **This level's job is to make the player feel like a genius.** Level 7 will
take that away.

## Briefing

> *Waterside Bleachworks (in liquidation)*
> *The chimney is to come down. The works are derelict and the land is sold for housing. There is
> nothing within two hundred feet on the river side. Drop it that way and there is £1,100 in it.*
> *Please note the boundary wall and the pump house on the east.*
> *Marsden & Coe, Receivers*

## Site layout

```
              river
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   ← 200m of open field, N/NW/W
              ·  ·  ·
            OPEN FIELD (the obvious answer)
                 ▓  ← 70m chimney
                 ▓
    ┌────────────▓────────┐
    │ derelict works      │  ▤ pump house (E, 30m, £180)
    └─────────────────────┘  ═══ boundary wall (SE, 45m, £60)
              [van]  [safe line at 105m]
```

The correct answer is obvious and the game wants it to be. The *interesting* part is whether the
player trusts themselves to execute it.

## Ascent bands

| From | To | Band | What it asks |
|---|---|---|---|
| 0 | 18 m | **Plain shaft** | routine |
| 18 | 36 m | **Ivy** | thirty years of ivy over the joints. Must be cleared before tapping (a slow, free, mildly annoying action). Teaches: sometimes the chimney hides itself. |
| 36 | 52 m | **Two iron bands** | free anchors, and they must come **off** as part of the strip-out |
| 52 | 70 m | **Sound but tall** | the highest the player has been; nerve factor 1.75 |

## The work — four acts

### Act 1: The Survey (8 min, ground level)
1. **Plumb the chimney** from two orthogonal positions. Result: `lean 0.3° toward 284°` — i.e. it
   already wants to go the way you want it to go. The game is being kind, once.
2. **Walk the site.** Find and register the pump house (E, £180) and the boundary wall (SE, £60).
3. **Pace the height** (optional expert action) to tighten the predicted debris fan.
4. **Drive the pegs.** Commit to a fall line. The game draws it in chalk-blue across the field, and
   overlays the predicted debris fan: `±18°, 80 m long`.

The tutorialisation here is the character talking himself through it out loud, once, and never again.

### Act 2: Strip Out (30 min)
Climb. Remove the two iron bands (spanner + cold chisel, at height, lateral traversal). Remove the
lightning conductor. No height reduction required on this level — the game tells you it would improve
accuracy by ~1.5° per 5 m and lets you do it if you want, which most players won't, and that's the
right answer here.

### Act 3: The Gob (35 min, ground level)
**The heart of the game.**

- 32 segments × 4 courses at the base. Mortar strength uniform (no asymmetry on this level).
- 14 props available.
- Cut → prop → cut → prop, working outward from the fall line.
- The chalk load diagram updates live: support polygon, centre of gravity, margin.
- Target: a ~140° gob on the river side, propped, with a crescent of brick at the back.
- Audio escalates: quiet → dust falls → mortar ticks → a low groan. By the end the chimney is
  *talking*, and the player is working inside it.

Predicted accuracy is shown before firing. On a clean job it reads **±4°**. The player can keep
cutting to improve it — and the closer they cut, the more likely a premature collapse. Perfect.

### Act 4: Fire, Run, Watch (5 min)
Pack with waste timber. Light it (shelter the match). **Run 105 m.** Turn around.

Then: silence. Smoke. A long minute. A crack. And seventy metres of Victorian brickwork comes over,
breaks into three pieces in mid-air, and lands in an open field with a noise like the end of the
world, followed by a dust column that rolls out across the grass for forty seconds.

Then a distant cheer from the twenty people who came to watch.

## Beats

1. Clearing ivy off a chimney with a hammer.
2. Driving the pegs — the moment of public commitment.
3. The first prop going in, and the diagram shifting.
4. The first groan. Most players will step back from the screen.
5. **HERO BEAT:** the fall. Everything in the game so far exists to make these eight seconds land.
6. The dust clearing, and a 70 m chimney being a 90 m line of rubble in a field.
7. The reckoning, with `ANGULAR ERROR: 3°` at the top of it.

## Failure modes available here

| Failure | Telegraph | Consequence |
|---|---|---|
| Premature collapse while in the gob | 6–9 s of escalating groan/dust | **fall/injury equivalent**, job failed, chimney down wherever it liked |
| Cut too little | predicted-accuracy readout + "she'll not go" | you light it and nothing happens; recut, −20 min |
| Bad fall line | the pegs are yours; the lean was measurable | angular error penalty |
| Hit the pump house | it's registered and the fan overlay showed it | −£180, reputation −5 |
| Match blown out | wind + the shelter prompt | −10 s, mild embarrassment |
| Poor packing | visible gaps in the timber | slow burn → the chimney drops before the props go → +6° error |

## Scoring

```
Base                                            £1,100
Chimney down                                    required
Angular error ≤5°                               +£400
              ≤15°                              +£150
Broke up cleanly (3–4 pieces)                   +£80
No collateral                                   +£120
Before dark                                     +£50
Pump house                                      −£180
Boundary wall                                   −£60
```

## Data
`data/levels/06-waterside.json`

## Open questions
- Should act 2 (strip out) be skippable? **No.** A felling level with no climbing in it is a
  different game. But it can be shortened if playtest says the level is too long — cut the conductor
  removal first.
