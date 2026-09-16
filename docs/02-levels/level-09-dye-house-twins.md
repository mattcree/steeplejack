# Level 09 — The Dye House Twins

## At a glance

| | |
|---|---|
| **Archetype** | TOP ×2 (shared resources) |
| **Height** | 45 m ×2 |
| **Structure** | Two identical round brick chimneys, 14 m apart, linked by a horizontal flue |
| **Fee** | £1,400 |
| **Shift length** | 120 min |
| **Target completion** | 110 min |
| **Weather** | fair, 6 m/s |
| **Reputation gate** | ★★★★☆ |
| **New to the player** | nothing. A logistics problem. |

## The one-line pitch
Two jobs, one day, **one bag of dogs**. The level is a resource-allocation puzzle dressed up as a
demolition, and it is the only level where the loadout screen is the hardest part.

## Briefing

> *Both stacks to come down to twenty foot, ready for the demolition men next week. They cannot be
> dropped — the dye house is still working underneath and there is a gas main across the yard.*
> *Both in one day if you can manage it; we have the men off on Monday.*
> *£1,400 for the pair. £600 for one.*

**£1,400 for both, £600 for one.** Doing both is worth £200 more than twice doing one. The player
does the arithmetic themselves.

## Site layout

```
    ▓                    ▓        ← both 45m, both to come down to 20m
    ▓                    ▓
    ▓   ═══ flue ═══     ▓        ← horizontal flue at 4m, walkable ON TOP
    ▓                    ▓
  ┌─▓────────────────────▓─┐
  │  dye house (working)   │      gas main ═══ across the yard
  └────────────────────────┘      [van]
```

## The constraint

You own **14 ladders and 62 dogs.** Two 45 m chimneys need, at comfortable 4 m spans, 11 ladders and
11 anchors *each* — plus 8 staging dogs each. That's 22 ladders and 38 dogs. You have 14 ladders.

Options the player will find:
- **Do one, strike it, carry everything across, do the other.** Safe. Costs ~18 min of transfer time,
  which is most of your slack.
- **Split the kit:** 7 ladders each, 6.4 m average spans, both in the danger band. Fast, and every
  anchor is carrying more than it should.
- **Do one properly and one badly.**
- **Do one, take the £600, go home.** A legitimate, non-punished choice. The reckoning is polite
  about it.
- **Hire the lad (£8)** to ferry material between the two, which is the "correct" answer and which
  the game never mentions. He drops a ladder once.

There is no right answer, and that is the level.

## Ascent bands (both, identical — deliberately)

| From | To | Band | What it asks |
|---|---|---|---|
| 0 | 4 m | **Flue roof** | you start on top of the horizontal flue — free 4 m, and a route between the two stacks at height |
| 4 | 22 m | **Plain shaft** | routine |
| 22 | 34 m | **Salt bloom band** | white efflorescence makes every joint look perished; tap-testing is the only way to tell. The tap-test skill at its peak. |
| 34 | 45 m | **Sound top** | fine |

**Chimney B has one difference and the game does not point it out:** its 22–34 m band is genuinely
perished, not just bloomed. A player who assumes the two are identical will place bad anchors on B.
A player who taps will notice in four seconds. This is the level's one piece of cruelty and it is
entirely fair.

## The work
Standard TOP ×2. 25 m off each. ~500 interactive bricks each.

**The flue is the twist:** bricks dropped down chimney A land in the *horizontal flue*, which fills
up and then backs up into chimney A. The flue must be cleared from a hatch at ground level, twice.
It's the jam mechanic at a larger scale, and it applies across both stacks.

### The complication
At roughly 60% of the shift, **the dye house lights its boiler** (it's a working building — they
warned you in the letter if you read it properly). Chimney A is the live one. It gets warm, it
starts producing steam, and visibility at the top of A drops. Grip recovery ×0.5.

If the player has been sequencing sensibly — A first, B second — this never happens to them.
**The reward for planning is that the complication doesn't occur.** That is the best kind of reward
and the game should use it more than once.

## Beats
1. The loadout screen, and the arithmetic.
2. Walking along the top of a horizontal flue between two chimneys.
3. Salt bloom: the moment the player's visual read fails them completely and they fall back on sound.
4. **HERO BEAT:** standing on top of chimney B, looking across 14 m of air at chimney A — which you
   took 25 m off this morning — and seeing exactly how much work a day is.
5. The steam.

## Failure modes
| Failure | Telegraph | Consequence |
|---|---|---|
| Ran out of ladders mid-stack | the counter, from the loadout screen on | forced to strike from below and leapfrog (slow, and viable) |
| Over-long spans | span warning | buckle risk on every section |
| Anchors on B's perished band | tap-test | anchor failures, cascade risk |
| Both flues blocked | jam audio ×2 | carry-down mode, job likely unfinishable today |
| Only did one | — | £600, no penalty, a mildly disappointed letter |

## Scoring
```
Both stacks to 20 m           £1,400
One stack only                £600
Craftsmanship grade (avg)     A +£220 / B +£120 / C +£40
Materials recovered           +£60
Before dark                   +£80
```

## Data
`data/levels/09-dye-house-twins.json`
