# Level 01 — The Back Yard

## At a glance

| | |
|---|---|
| **Archetype** | SURVEY |
| **Height** | 12 m |
| **Structure** | Square brick chimney, the old dye-works next to the house |
| **Fee** | — (it's your own yard) |
| **Shift length** | none |
| **Target completion** | 8 min |
| **Weather** | still, bright, 1 m/s |
| **Reputation gate** | — |
| **New to the player** | tap-test, dog-in, lash, climb, grip, the belt |

## The one-line pitch
Teach the whole anchor loop in a place where **falling is physically impossible**, so the player can
be bad at it without being punished, and arrive at level 2 already competent.

## Briefing
No letter. The game opens on the character in his yard with a cup of tea, looking at the old
dye-works chimney over the wall. A hand-written note on the bench:

> *Dennis — that stack next door wants looking at before somebody's insurance gets funny about it.
> Have a walk up it and tell us what's what. — R.H.*

## Site layout

```
   ┌──────────────────────────────┐
   │  back yard                   │
   │   [ENGINE under tarp]  [WC]  │
   │   [bench: tools]             │        ▓ 12m chimney
   │   [kettle]      [van]        │        ▓ (square, 1.2m side)
   │ ──────────wall───────────────┤        ▓
   │  dye-works yard              │        ▓
   │                          ▓▓▓▓▓▓▓▓▓▓▓▓▓▓
   └──────────────────────────────┘
```

Hay bales and a midden heap surround the chimney base. **At 12 m with soft ground, a fall here
injures nothing but pride** — the game explicitly tells you this once, in the character's voice, and
then never mentions safety nets again.

## Ascent bands

| From | To | Band | What it asks |
|---|---|---|---|
| 0 | 6 m | **Plain shaft, generous joints** | the full loop, twice, with prompts |
| 6 | 12 m | **Mixed joints** | one Perished and one Cracked joint deliberately placed on the obvious line; the player must tap, reject, and go around |

Three ladder sections. Three anchors. That's it.

## The work

### Set up
None. Climb.

### The fiddly bit
Find and chalk **four defects**:
1. A cracked course at 7 m (visible; teaches *look*)
2. A perished band of mortar at 9 m (invisible; teaches *tap*)
3. A jackdaw's nest in the flue (visible from the top only; teaches *get all the way up*)
4. A missing lightning clip on the north face (teaches *go round*, and sets up Level 2)

Each is chalked with a single button press once identified. The character comments on each.

### The complication
Defect 4 is on the face you didn't climb. The player must **traverse laterally** — two extra dogs,
sideways — to reach it. This is the one moment of genuine instruction in the level and it plants
the seed for Level 4.

### Clear up
Slide down (taught here — it's fun and it's safe), strike the ladders, put the kettle on.

## Beats

1. The opening shot: the yard, the tarp, the kettle, the chimney over the wall.
2. First dog driven in. **Get the hammer feel right here or nowhere.**
3. First tap-test that returns a *dull thud* — the player learns the sound means "no".
4. **HERO BEAT:** standing on top of a 12 m chimney, which is not high, and the game frames it like
   it is — wide camera, held for two seconds, distant town, the character says
   *"Aye. Not much of a view, this one."* Then the camera tilts up and we see, three miles off,
   the **Great Aire chimney** (Level 12). It is enormous. He looks at it for a second and says
   nothing. **This is the game's entire promise, delivered in level one, in four seconds.**
5. The first slide down.

## Failure modes available here

| Failure | Telegraph | Consequence |
|---|---|---|
| Bent dog | swing power/angle feedback | lose a dog (you have 40) |
| Poor anchor | rating pip | ladder wobbles noticeably |
| Fall | grip meter | land in the midden. Comedy. Nerve −10, get up, continue. |

**Nothing here can end the level.**

## Scoring
Defects found / 4. No money. The reckoning screen appears with mostly empty lines — teaching the
player to read it before it matters.

## Data
`data/levels/01-back-yard.json`

## Open questions
- Should the Great Aire reveal be interactive (player must look) or forced? **Lean: forced, once,
  very briefly.** A missed promise is worse than a mild railroad.
