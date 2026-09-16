# Level 10 — Hartford Power Station

## At a glance

| | |
|---|---|
| **Archetype** | CONDUCTOR + EMERGENCY |
| **Height** | 90 m |
| **Structure** | Reinforced concrete chimney, 1950s, smooth, with an internal steel ladder that stops |
| **Fee** | £1,600 |
| **Shift length** | 150 min |
| **Target completion** | 130 min |
| **Weather** | **storm, building through the level.** 9 → 18 m/s, rain, poor visibility |
| **Reputation gate** | ★★★★☆ |
| **New to the player** | nothing. Everything, harder, in the rain. |

## The one-line pitch
The difficulty spike. Concrete instead of brick (your whole anchor toolkit is wrong), a storm, gusts
with a 1.2 s tell, and a job that has to be done *today*.

## Briefing

> *CEGB — Hartford Generating Station*
> *URGENT. Lightning protection on No. 2 stack was found defective at inspection and the forecast is
> poor. We cannot take the set off load. The internal ladder is condemned above 58 metres.*
> *We require the conductor made good today. £1,600. Our own safety man will be present.*

## Site layout

```
          ╽  ← 90m concrete stack, 5.2m dia at base, 3.1m at top
          ║
          ║   ← internal steel ladder: 0–58m, CONDEMNED above that
          ║
          ║      ⚡ storm front approaching from the west
     ┌────╨────┐
     │ turbine │   [cooling towers, 4, in the background — they are enormous
     │  hall   │    and they are the game's best establishing shot]
     └─────────┘
```

## The concrete problem

**You cannot dog into concrete.** Everything the player has learned about mortar joints is useless.
Instead:

- **Expansion bolts.** Drill a hole (a new *application* of the hammer verb — a star drill, struck
  and rotated, 8–14 s per hole, much slower than a dog), insert, expand.
- **Tap-testing still works** — but it's now reading for **voids and delamination** in concrete
  rather than mortar quality, and the sound signatures are different. The player has to re-learn
  their best skill, which is a *great* thing to do to someone at level 10.
- **Existing fixtures:** the condemned internal ladder's brackets are still sound above 58 m even
  though the ladder isn't. Free anchors, if the player thinks to use them.

## Ascent bands

| From | To | Band | What it asks |
|---|---|---|---|
| 0 | 58 m | **Internal ladder** | free but *awful*: dark, enclosed, echoing, wet, and it goes on for a very long time. A deliberate endurance beat with no mechanics at all. Nerve drains from claustrophobia instead of exposure. |
| 58 | 66 m | **The condemned section** | you emerge from a hatch into the weather at 58 m with no warning and full wind |
| 66 | 74 m | **Delaminated band** | concrete spalling; tap-test reads void; no bolts will hold. Must span it using the old ladder brackets. |
| 74 | 84 m | **Gust band** | above the cooling towers' shelter. Gusts every 25–40 s, each with the 1.2 s tell. |
| 84 | 90 m | **The top** | a steel platform, a handrail, and a view of four cooling towers in a storm |

## The work
Standard CONDUCTOR, at 90 m, in a storm, on concrete.
- Air terminal at the top: 4 expansion bolts, in gusts.
- 96 m of copper tape, clipped every 1.5 m on the descent — **each clip now requires a drilled hole**,
  so the descent is three times slower than Level 2's and the storm is getting worse the whole time.
- The tape must route around the condemned ladder brackets.

### The complication
**The storm arrives properly at 70%.** Wind 18 m/s, horizontal rain, grip ×1.4, gusts every 15 s.
The safety man on the radio tells you to come down. **You can.** The job fails, you get £400 for
the day, and nobody thinks badly of you — the game is explicit about this and the character says
so. Or you finish it.

**This is the game's only real moral/nerve choice and it is not scored.** The reckoning does not
give a bonus for staying. It just records what you did.

## Beats
1. The cooling towers. Four of them, in a line, in the rain. Establishing shot.
2. Fifty-eight metres of dark internal ladder. It is boring on purpose and it is only boring once.
3. The hatch. Dark → grey → wind → 58 m of nothing below you, instantly.
4. Re-learning the tap test on concrete.
5. **HERO BEAT:** the gust band. You hear it coming across the cooling towers — a rushing sound,
   1.2 seconds — and you have exactly that long to stop what you're doing and hold on.
6. The radio call.

## Failure modes
| Failure | Telegraph | Consequence |
|---|---|---|
| Bolt in delaminated concrete | tap-test void signature | pulls under load |
| Caught mid-verb by a gust | 1.2 s audio + screen-edge streaks | tool dropped, nerve −20, possible slip |
| Ran out of tape | counter + sag | rework in a storm. Grim. |
| Stayed too long | the radio, twice | the storm peaks; gusts every 8 s |
| Came down | — | £400, no penalty, a line of dialogue |

## Scoring
```
Base                              £1,600
Conductor made good               required
Came down early (partial)         £400
No tools dropped                  +£120
Before dark / before the peak     +£160
Nothing damaged below             +£200
```

## Data
`data/levels/10-hartford.json`
