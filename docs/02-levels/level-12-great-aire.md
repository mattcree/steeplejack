# Level 12 — The Great Aire Chimney

## At a glance

| | |
|---|---|
| **Archetype** | TOP → FELL (two acts, one day) |
| **Height** | 110 m |
| **Structure** | Round brick chimney, 1867, the tallest in the district. Cracked. |
| **Fee** | £3,400 |
| **Shift length** | 150 min |
| **Target completion** | 145 min |
| **Weather** | cold, clear, still at ground, 9 m/s at height |
| **Reputation gate** | ★★★★★ |
| **New to the player** | nothing at all |

## The one-line pitch
The chimney you saw from your own back yard in level one. Take eighteen metres off it by hand, then
drop the rest between a railway and a gasholder, in front of the whole town.

## Briefing

> *Sir,*
> *The Aire Street chimney is to come down. You will know it — everyone knows it. It is three hundred
> and sixty foot and it is cracked from the cap to about halfway and the Borough Engineer will not
> allow it to be felled at its present height.*
> *There is the main line on the east, which we cannot close for more than twenty minutes, and the
> gasholder on the south, which I need not explain.*
> *£3,400. There will be a crowd. There is nothing we can do about the crowd.*
> *Borough Engineer's Dept.*

## Site layout

```
                          ▓  ← 110m. lean 2.1° toward 156° (toward the gasholder)
                          ▓     crack from 110m down to ~55m
                          ▓
                          ▓
    ══════════════════════▓══════════  ← MAIN LINE RAILWAY, east, 55m.
         (trains: a timetable you can read)
                          ▓
   ┌──────────────────────▓───────┐
   │   derelict mill              │
   └──────────────────────────────┘
                  ○ GASHOLDER, south, 70m.  CATASTROPHIC.
       ← corridor: bearing 232°–272°, 40° wide, over the derelict mill
                  [crowd behind barriers at 130m]
                  [safe line 165m]
```

## Ascent bands — six, the longest climb in the game

| From | To | Band | What it asks |
|---|---|---|---|
| 0 | 20 m | **Massive base** | 4.6 m radius. Everything is bigger. Lateral traversal takes twice as long. |
| 20 | 42 m | **Plain shaft** | the long, confident, routine middle. Let the player enjoy being good. |
| 42 | 55 m | **Three iron bands** | free anchors, and all three must come off in the strip-out |
| 55 | 76 m | **The crack begins** | one face unusable for 20 m; forced route change; heavy shimming |
| 76 | 96 m | **Perished + wind** | worst mortar, worst wind, no free anchors. **The crux of the game.** Short spans, slow going, and the player's material is running low. |
| 96 | 110 m | **Corbelled cap over an overhang** | the last 3 m require climbing *out and under* an oversailing cap — an overhang move, exposureFactor 2.2, at 108 m, at the end of a long day. |

## Act 1: The Top (55 min)
Take **18 m** off by hand, because the Borough Engineer says so and because the crack makes the
upper shaft unpredictable in a fall.

- Full staging build at 108 m.
- ~360 interactive bricks, down the flue, 110 m, with the longest and best falling-brick sound in
  the game.
- Nine staging lowers.
- Strike your own ladders from the top down as you go.
- Complications: a soot fall at ~14 m remaining; the crack's edge courses all snap regardless
  (salvage rate collapses and the player has to accept it); an iron tie at ~6 m.

Ending act 1 at 92 m, with the light going, is the game's most earned cup of tea.

## Act 2: The Fell (85 min)

### Survey
Done at the start of the day, before the climb — so the player commits to a fall line *before*
they've spent three hours on the chimney. A deliberately uncomfortable ordering.

- Lean **2.1° toward 156°** — pointing at the gasholder. The strongest lean in the game.
- Corridor **40°**, wider than Level 7, but the lean is 76° outside it and the chimney is 110 m,
  so a 1° error is a 1.9 m error at the tip.
- **The railway timetable is on a board at the site office.** Trains every ~18 minutes.
  The fall must happen in a gap. Reading the board is optional and the game never mentions it;
  a train arriving during the collapse is a −£1,200 "delay to service" and a very bad look.

### The gob
- 32 × 5 courses (the wall is thicker here — 128 cells becomes 160).
- Mortar asymmetry: the 1867 lime mortar on the north is significantly harder.
- 22 props. No dud — **the player has earned a clean run.**
- Overcut required against a 2.1° lean, which is roughly a 16° gob offset. Everything the player
  learned at Kershaw's Yard, doubled.
- The groan of a 110 m chimney at CRITICAL margin is the single loudest, most frightening sound in
  the game.

### Fire, run, watch
- Safe line at **165 m**. The longest run.
- **The crowd.** Hundreds of people behind barriers. They go quiet when you light it.
- Burn: 90 seconds. A very long 90 seconds.

### The fall
Ninety-two metres of 1867 brickwork. It hinges, it holds for a moment, it breaks into four pieces in
the air, and it comes down across a derelict mill with a sound like nothing else in the game. The
dust column goes up 60 m and rolls out for a full minute.

Then: a cheer. A long one.

Then the dust clears and there is a gap in the skyline where a chimney has been since 1867.

## Note on the data (added 2026-09-20 with `data/levels/12-great-aire.json`)

**The derelict mill is not an exclusion.** The corridor runs over it — "over the derelict mill" is
how this page describes the only line the chimney can take — and `tools/validate_data.py` refuses a
level with something valuable standing in its own fall corridor, which is right. The mill is scenery
you are meant to drop it across, and it is derelict, so it has no value to lose. The gasholder and
the railway are the exclusions.

**The failure table's ±4° / ±9° pair is wrong, and the real numbers are worse.** Measured through
`Fell::Predict` on this level's own data (`godot/scripts/test_great_aire.gd`):

| | cone |
|---|---|
| eighteen metres off, as the Engineer requires | **±8.0°** |
| left at its full height | **±14.9°** |

The ±4 was arrived at — including once, here, by me — by adding up the height and height-reduction
terms and forgetting the one this level is *about*. Great Aire leans 2.1° toward 156° and the only
corridor is 232–272°, so the fall line is being fought through ninety-six degrees, and fighting a
lean costs 3.5° of cone per degree of it. That is four degrees of the eight, and no amount of
taking the top off buys it back; only the overcut does.

So the Engineer's condition buys **6.9 degrees**, which is more than the table claimed, and the job
without it is a great deal more dangerous than ±9 suggests. The mechanic is under-sold rather than
over-sold, which is the right way round, but the row should say 8.0 and 14.9 when someone next
edits it — and the model should not be bent to meet a pair of numbers nobody derived.

## Beats
1. The survey, in the morning, with the crowd already gathering.
2. The 76–96 m crux: cold, low on dogs, bad mortar, high wind, and a long way to go.
3. The overhang under the cap at 108 m.
4. Tea at 108 m, on a staging, at the end of act 1, looking at the whole district.
5. Bricks down a 110 m flue.
6. The gob, the groan, the crowd going quiet.
7. **HERO BEAT:** the fall.
8. **THE LAST BEAT:** back in the yard that evening. The character stands at the wall with a cup of
   tea and looks toward where the Great Aire chimney was — the exact shot from Level 1, reversed.
   It isn't there. He doesn't say anything. Cut to the engine under its tarpaulin.

## Failure modes
Everything the game has. Plus:
| Failure | Telegraph | Consequence |
|---|---|---|
| **Gasholder contact** | registered, fan overlay, the letter | **JOB FAILED**, and the game handles it seriously |
| Railway strike | the timetable board, if you read it | −£1,200, reputation −8 |
| Didn't take 18 m off | the Engineer's condition is stated | fall accuracy ±9° instead of ±4°; likely gasholder |
| Ran out of material at 90 m | counters, all day | you cannot finish; come back tomorrow; the crowd goes home |

## Scoring
```
Base                              £3,400
18 m removed + chimney down       required
Angular error ≤5°                 +£600
              ≤15°                +£250
Clean break-up                    +£150
No collateral                     +£250
Railway not obstructed            +£100
Craftsmanship grade (act 1)       A +£200 / B +£120
Gasholder                         JOB FAILED
```

## Data
`data/levels/12-great-aire.json`

## Note on the ending

There is no boss, no twist, and no epilogue mission. The game ends with a man, a cup of tea, and a
gap in the sky. If the engine is finished, the credits are him driving it out of the yard. If it
isn't, the credits are the tarpaulin. **Both endings are fine and the game does not comment.**
