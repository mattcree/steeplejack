# Level 11 — The Pleasure Tower

## At a glance

| | |
|---|---|
| **Archetype** | LATTICE |
| **Height** | 120 m |
| **Structure** | Riveted steel lattice tower, seaside pleasure beach, 1894 |
| **Fee** | £2,200 |
| **Shift length** | 150 min |
| **Target completion** | 125 min |
| **Weather** | bright, sea wind 12 m/s constant, salt air |
| **Reputation gate** | ★★★★☆ |
| **New to the player** | the steel movement set; hot riveting |

## The one-line pitch
Take the ladders away. Put the player on the outside of a 120 m steel lattice above a funfair, and
make them miss the chimneys.

## Briefing

> *The Tower Company*
> *Our annual inspection has condemned a number of rivets in the upper structure and the gilding on
> the ball is gone entirely. The season opens in three weeks and the Tower must be open.*
> *We will not close the tower or the beach while you work. There will be people below you.*
> *£2,200.*

## Site layout

```
              ●  ← the ball, gilded, 120m
             ╱╲
            ╱  ╲     ← upper lattice (the work is here, 96–120m)
           ╱ ╲╱ ╲
          ╱ ╱╲╱╲ ╲
         ╱╲╱    ╲╱╲   ← a genuine 3D maze of angle iron
        ╱  ╲    ╱  ╲
   ════╧════╧══╧════╧════
     PROMENADE, BEACH, FUNFAIR — full of people, all day, loud
```

## The steel movement set

**No ladders, no dogs, no gin wheel from the ground.** A completely different locomotion system,
reusing grip and nerve unchanged.

| Verb | How |
|---|---|
| **Climb steel** | hand-over-hand on angle iron. Free-form, 3D, faster than ladders but always one-handed-ish — **grip drains constantly while climbing**, which inverts the chimney rule. |
| **Lanyard leapfrog** | two lanyards, always one clipped. Clip A to a new member, unclip B, move, clip B ahead. A deliberate two-input rhythm. Forget to clip and you are free-soloing — the game does not stop you. |
| **Rest** | brace into a corner of the lattice; grip recovers. Rest spots are *placed*, not universal — finding them is route knowledge. |
| **Local haul** | a small block and tackle you move up the tower with you |

**The maze:** the route up is not obvious. There are dead ends — members that lead nowhere, a
platform with no way off, a diagonal that looks climbable and isn't. The player must read the
structure. There is no marked path and no waypoint. It takes most people 15 minutes to find a good
route and 4 minutes the second time. That is the best possible shape for this.

## Ascent bands

| From | To | Band | What it asks |
|---|---|---|---|
| 0 | 34 m | **Internal lift shaft ladder** | free, caged, dull, quick |
| 34 | 58 m | **Lower lattice, wide** | generous members, learn the leapfrog, lots of rest spots |
| 58 | 78 m | **The pinch** | the lattice narrows; fewer rest spots; the first real grip management |
| 78 | 96 m | **Corroded members** | salt damage. Some members **will not take your weight** — read them (flaking, pitting, a dull ring). The tap test, one last time, on steel. |
| 96 | 112 m | **The work zone** | open, exposed, and above everything on the coast |
| 112 | 120 m | **The finial and the ball** | a single vertical member, a ring of rungs, and a gold ball |

## The work

### Set up
Rig a small working stage in the upper lattice — a plank and four clamps. Position matters: you'll
be reaching for rivets from it for forty minutes.

### The fiddly bit — hot riveting
Eighteen rivets to replace. Per rivet:
1. **Cut out the old one** — cold chisel the head off, punch it through (a prise-like resistance verb).
2. **Heat the new rivet** in a small portable brazier clamped to the lattice. **Rivets have a
   temperature window** — a colour you read off the metal (cherry red = right, orange = too hot and
   it'll burn, dull red = too cold and it won't head). This is a pure *read-the-material* skill, the
   same muscle as the tap test, in a new sense.
3. **Set it** — insert, hold against a dolly with one hand, and hammer the head with the other in a
   rhythm. It cools while you work: **you have about 9 seconds**, and the clock is the metal's colour.
4. Rate it: a clean head, a lopsided head, or a cold-worked one that has to come out again.

Hot riveting is normally a four-man job. Doing it solo, at 110 m, with a jig, is absurd, and the
character says so, and then does it anyway.

### The complication
**The tower is open and full of people.** All day. Music from the funfair. Screaming from a ride.
The lift running up the middle of the structure every four minutes, with a crowd in it, passing
within six metres of you, *and they look at you.* Nerve does not drain from being alone up here —
it drains from being watched. (Mechanically: a nerve modifier tied to lift proximity. Thematically:
the best joke in the game.)

Also: **a dropped tool is catastrophic here.** 120 m onto a promenade. The game does not simulate
casualties — it cuts to black and a newspaper headline, and the job is failed, and nobody says
anything else about it. One of only two hard fails in the back half.

### Clear up — gild the ball
Callback to Level 3, at 120 m instead of 45, in a 12 m/s sea wind, on a sphere, with nothing to
brace against but your own lanyards. Hold breath, place leaf, burnish. The hardest execution of the
easiest verb.

## Beats
1. Arriving on the promenade and looking up. Donkeys, chips, a brass band, and 120 m of Victorian
   steel.
2. Getting lost in the lattice.
3. The first leapfrog clip, and realising you can also just... not clip.
4. The corroded band: a member that flexes when you put weight on it.
5. **HERO BEAT:** the lift goes past. A carriage full of day-trippers, six metres away, and every
   one of them turns to look at you.
6. Gilding a gold ball at 120 m over the sea.
7. The descent, at speed, by a route you now know perfectly.

## Failure modes
| Failure | Telegraph | Consequence |
|---|---|---|
| Unclipped fall | you chose not to clip | fall, no safety line, full consequence |
| Corroded member | flaking, pitting, dull ring | it gives; slip-save |
| Burnt / cold rivet | the colour | redo, −90 s each |
| **Dropped tool** | you are over a promenade and the game has told you | **JOB FAILED** |
| Grip exhaustion between rest spots | the meter, and rest spots are visible | slip |

## Scoring
```
Base                              £2,200
18 rivets replaced                required
Rivet quality grade               A +£300 / B +£180 / C +£60
Ball gilded                       +£200
Nothing dropped                   required (hard fail)
Before the season / before dark   +£150
```

## Data
`data/levels/11-pleasure-tower.json`
