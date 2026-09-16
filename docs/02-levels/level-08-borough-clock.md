# Level 08 — The Borough Clock

## At a glance

| | |
|---|---|
| **Archetype** | MECHANISM |
| **Height** | 50 m (tower), work at 38 m |
| **Structure** | Gothic municipal clock tower, gritstone |
| **Fee** | £700 |
| **Shift length** | 120 min |
| **Target completion** | 80 min |
| **Weather** | clear, cold, still, 2 m/s |
| **Reputation gate** | ★★★☆☆ |
| **New to the player** | nothing. A change of texture. |

## The one-line pitch
A deliberate downshift after two fellings: low altitude, high fiddliness, a puzzle, a joke, and one
enormous bell.

## Briefing

> *Borough of Crossley — Works Dept.*
> *The Town Hall clock has stopped and the minute hand of the north dial came off in the gale and is
> currently in the Mayor's parlour. The clockmakers in Leeds want £2,000 and a scaffold. We are
> told you can do it off ladders. £700.*
> *The clock still strikes. We cannot stop it striking without a man in the chamber, and we have not
> got a man.*

That last line is the level. **The player is told, in writing, that the bell will go off.**

## Site layout

```
         ╱▔▔╲
        │ ◷  │  ← north dial, centre at 38m, 3.2m diameter
        │    │
        ├────┤  ← belfry: THE BELL (2.4 tonnes) at 32m, open louvres
        │    │
        │    │  ← internal stair to 30m
   ┌────┴────┴────┐
   │  Town Hall   │   [market square, busy, people below]
   └──────────────┘
```

The market square is **full of people**, all day. Anything dropped is a serious matter.

## Ascent bands

| From | To | Band | What it asks |
|---|---|---|---|
| 0 | 30 m | **Internal stair** | free, dark, atmospheric. A long climb past the clock movement itself (which you can inspect — worth doing, see below). |
| 30 | 38 m | **External ledge + ladder** | out of a louvre onto a 40 cm ledge. The scariest 40 cm in the game *because it's only 38 m and it doesn't feel like it should be scary.* |
| 38 | 50 m | **Optional: the finial** | not required. There is a very good view and one collectible hat. |

## The work

### Set up
- Haul the repaired minute hand (2.4 m, 40 kg, flat as a sail) up the outside of the tower.
- Rig a small working platform off the dial surround.

### The fiddly bit — a real puzzle
1. **Stop the clock.** Inside, in the movement room. There's a maintenance lever; finding it means
   looking at the machine. (The game's only "find the thing" moment, and it's 20 seconds.)
2. **Remove the old hand collar** from the centre boss — four bolts, seized, on a square taper,
   done from a ledge.
3. **Seat the new hand.** The taper is square: it only goes on four ways. You must set it to the
   correct minute. But the minute hand and the hour hand are geared together, so you must
   **set the clock to a known time first, then fit the hand to match.** A small, clean, genuinely
   satisfying mechanical puzzle that takes about ninety seconds once you see it.
4. **Restart the clock**, and set it to the real time by ear from the church down the road.

### The complication — the bell
At a fixed, foreshadowed in-fiction time (visible on the *other three dials*, which are still
running), **the clock strikes.** You are 6 m above and 4 m to the side of a 2.4-tonne bell, in the
open, on a ledge.

- Nerve −35, instant.
- Massive audio event; the mix ducks everything, the world rings for eight seconds.
- If you were mid-verb, you drop the tool (which falls into a market square, £, and a very long
  beat of silence afterward).

**It is completely fair.** The briefing says it. Three dials show the time. There is a low hum from
the movement 30 seconds before. A player who pays attention will be holding on with both hands and
grinning. A player who doesn't will levitate.

### Clear up
Descend. In the square, the clock chimes the correct hour for the first time in a year, and about
forty people look up at it.

## Beats
1. The dark internal stair, the smell of oil, the clock movement turning in a room by itself.
2. Stepping out of a louvre onto a ledge.
3. Solving the hand/gear puzzle.
4. **HERO BEAT:** the strike.
5. The square, the right time, and people noticing.

## Failure modes
| Failure | Telegraph | Consequence |
|---|---|---|
| Dropped tool into the square | you're over a market | −£, reputation −4, an awful silence |
| Hand fitted 15 min out | the other dials disagree, visibly | rework, −10 min |
| Rounded a seized bolt | resistance + grinding | −8 min, drill it out |
| Caught by the strike mid-task | 3 dials + a 30 s hum | nerve −35, dropped tool |

## Scoring
```
Base                          £700
Clock running and correct     required
Nothing dropped               +£100
Hand fitted first time        +£60
Before dark                   +£60
Collectible: the tower hat    —
```

## Data
`data/levels/08-borough-clock.json`
