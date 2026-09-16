# Level 02 — Sweeper's Row

## At a glance

| | |
|---|---|
| **Archetype** | CONDUCTOR |
| **Height** | 30 m |
| **Structure** | Round brick chimney, small laundry, hemmed in by terraced houses |
| **Fee** | £180 |
| **Shift length** | 90 min (very generous for the work) |
| **Target completion** | 35 min |
| **Weather** | overcast, 5 m/s, **storm front arriving in the last 25%** |
| **Reputation gate** | — |
| **New to the player** | nerve, the gin wheel, working while descending, the daylight bar |

## The one-line pitch
The first real job: introduce **nerve** and **hauling** at a height where they bite but don't kill,
and make the descent — usually the dull part — into the main event.

## Briefing

> *Dear Sir,*
> *We had the lightning down our chimney in August and it took the top three courses off and gave
> Mrs. Ackroyd at number 14 a turn. The insurance say we must have a proper conductor fitted before
> they will look at us again. It is about a hundred foot. We can manage £180 and a dinner.*
> *Yours faithfully, A. Pilling (Pilling's Laundry)*

## Site layout

```
   ══ Sweeper's Row ══════════════════
   [12][14][16][18]   ← terraced houses, 8m, slate roofs
   ────────yard wall──────────────────
        ▓▓  ← 30m round chimney          [van]
        ▓▓         [boiler house, 6m]
        ▓▓   ○ earth pit site (marked with a peg)
   ═══════════════════════════════════
```

Tight site. **The houses are 9 m from the chimney.** Anything you drop lands on somebody's slates
(£12 a pane, £30 a slate, and the game will have a neighbour come out and look at you).

## Ascent bands

| From | To | Band | What it asks |
|---|---|---|---|
| 0 | 8 m | **Plain shaft** | the loop, now unprompted |
| 8 | 16 m | **Sooted band** | joints are black and all look the same; **tapping is mandatory** |
| 16 | 24 m | **Wind band** | you clear the roofline; first gust, first real nerve drain |
| 24 | 30 m | **Damaged top** | the lightning-struck courses. Loose brick, 2 m of Cracked joints. Must span it (5.5 m span — the first time the game asks for a *warning*-band span) |

## The work

### Set up
1. Haul the copper tape reel and the air terminal up on the gin wheel. **First haul in the game.**
   The reel is light and forgiving; it's a teaching haul.
2. Fix the air terminal to the top: four dogs, a clamp, four bolts. Grip endurance test #1 — the
   player will run out of grip here and learn the stance system by necessity.

### The fiddly bit
**Descend while working.** Pay out the tape, fix a clip every 1.5 m. Twenty clips over 30 m.

- No sliding (you're holding the tape).
- Each clip is aim → drive → 1.2 s, done one-handed. Grip cycles constantly.
- The run must stay **taut and within 15° of vertical**. A wandering run is shown live as a
  chalk-line ghost on the brickwork; deviation is visible and correctable.
- Tape is finite: **34 m of tape for a 30 m run.** Slack costs you. A player who lets it sag will
  run out at 4 m from the ground and have to go back up for a joint sleeve (rework, −15 min).

### The complication
**The storm.** At 75% of the shift, the sky changes, the light drops, and the wind goes from 5 to
11 m/s over ninety seconds with an audible front approaching. The game does not say "hurry up." It
just gets darker and louder.

If the player is still on the chimney holding a copper cable when the storm arrives: nothing
supernatural happens, but nerve drain doubles, gusts begin, and the character says one very dry line
about it. If they're down — they watch the storm hit the chimney they just protected, and the
conductor does its job. **Both outcomes are good. Neither is a fail.**

### Clear up
Dig and connect the earth pit at the base. Test with a continuity meter: a needle swings, a buzzer
sounds, the character grunts approvingly. Strike the ladders.

## Beats

1. First haul — watching a reel of copper rise out of a back yard.
2. Clearing the roofline at 16 m: the wind arrives, the town opens up, **nerve appears on screen for
   the first time** with no explanation. The player works out what it is from the shaking hands.
3. Running out of grip while bolting the terminal, 30 m up, and discovering the stance menu.
4. **HERO BEAT:** the descent. Twenty clips, going down, slowly, while a storm comes in over the
   moors behind you. It's the first time the game is genuinely tense and it's caused by *weather and
   a rope*, not by a threat.
5. The continuity buzzer. A small, perfect, satisfying full stop.

## Failure modes available here

| Failure | Telegraph | Consequence |
|---|---|---|
| Dropped tool onto the terrace | you're over a roof; the game shows the shadow | £12–30, neighbour appears, nerve −10 |
| Ran out of tape | the tape counter, and the visible sag | rework: climb, fit a sleeve, −15 min |
| Buckled span at the damaged top | span warning at 5.5 m + flex animation | ladder drops, slip-save |
| Storm-caught | 90 s of audiovisual front | doubled nerve drain, gusts |
| Fall | grip / nerve | **first real fall consequence in the game**: hospital, lose the £180, injury |

## Scoring

```
Base                                 £180
Conductor passes inspection (taut, vertical, earthed)   required
Completed before the storm           +£40
No damage to the terrace             +£35
Materials recovered                  +£0 (but you keep them)
Broken slate                         −£30 each
```

## Data
`data/levels/02-sweepers-row.json`
