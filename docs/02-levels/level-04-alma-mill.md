# Level 04 — Alma Mill

## At a glance

| | |
|---|---|
| **Archetype** | BAND |
| **Height** | 55 m |
| **Structure** | Octagonal brick chimney, working spinning mill |
| **Fee** | £620 |
| **Shift length** | 90 min |
| **Target completion** | 65 min |
| **Weather** | fair, 6 m/s, hazy |
| **Reputation gate** | ★★☆☆☆ |
| **New to the player** | lateral traversal, measurement & rework, the heaviest haul yet |

## The one-line pitch
Teach the player that **sideways is scarier than up** — leaving the safety of your own vertical stack
to crab around a chimney on two anchors — and introduce a failure that costs a *trip*, not a life.

## Briefing

> *Alma Mill, Sowerby Bridge*
> *Our chimney is cracked from about halfway up and the insurance company will not renew until it is
> banded. Three bands, they say. We are still spinning so she must stay lit — you will find her warm.*
> *Height about a hundred and eighty foot. £620 agreed.*
> *There is a greenhouse on the west side which my wife is very fond of.*
> *J. Holroyd*

## Site layout

```
    ▓▓▓▓▓  ← 55m octagonal chimney, LIT (smoke, and she is warm)
    ▓▓▓▓▓
    ▓▓▓▓▓      ← crack runs from 50m down to 27m on the SE face
  ┌─▓▓▓▓▓─────────────────┐
  │  boiler house         │   🏠 greenhouse (W, 18m away, £14 a pane, 9 panes)
  └───────────────────────┘
      mill (4 storeys)        [van]     canal
```

**She's lit.** The chimney is warm to the touch (a lovely, unusual detail), heat haze distorts the
air above it, and the top 5 m is hot enough that grip recovery is halved. A small, memorable, purely
atmospheric-turned-mechanical touch.

## Ascent bands

| From | To | Band | What it asks |
|---|---|---|---|
| 0 | 14 m | **Plain octagonal** | corners! Ladders sit in the flats; corners are dead ground. Route planning around eight faces. |
| 14 | 27 m | **Existing iron band** | a gift — a free, rated Sound anchor at 14 m. Teaches the player to *look for* free fixtures. |
| 27 | 42 m | **The crack** | 15 m of Cracked joints on the SE face. **You cannot anchor on this face at all.** Must route up an adjacent flat, which puts you on the wrong side for the work. |
| 42 | 50 m | **Perished band** | the exact height band #3 must go. No sound joints for 4 m. |
| 50 | 55 m | **Hot top** | grip recovery ×0.5, heat shimmer |

## The work

### Set up — measure (15 min)
Three circumferences, at 20 m, 34 m and 48 m. Each measurement means:
1. Climbing to that height.
2. **Traversing laterally** all the way around the octagon with the tape, re-dogging as you go —
   about 5 anchors per circuit on a 3 m-radius chimney.
3. Reading the tape and writing it in the book.

**Measure badly and the bands don't fit.** The game does not tell you you've measured badly. You
find out in the second act, at 48 m, holding 90 kg of steel that is 40 mm too short. That is a real
rework: down, re-measure, order a shim plate, back up, −20 min.

*This is the single best "the player's care is the mechanic" moment in the first half of the game.*
Telegraph it honestly: the tape has visible slack when you're sloppy, and the character mutters.

### The fiddly bit — fit and tension
Per band, three times:
1. **Haul** the four steel segments (90 kg each — the swing meter is brutal; haul greedily and it
   swings into the brickwork, damaging it and shedding brick onto the yard).
2. **Bolt** the segments around the shaft — which means traversing the full circumference again,
   bolting as you go, on two anchors, with a spanner, one-handed.
3. **Tension** in the correct star sequence (opposite pairs, three passes). Wrong sequence → the band
   goes oval and won't seat; you have to slacken everything and start again (−6 min).

### The complication
**Band #3 sits in the perished band at 48 m.** There is nowhere to put a dog. The solution the game
expects the player to find (and never states): rig the **bosun's chair** from sound brickwork at
50 m, and work band #3 hanging *below* your anchors rather than standing on them. It's a direct
application of Level 3's lesson in a completely different context — the first time the game asks the
player to transfer knowledge rather than learn something.

### Clear up
Repoint the crack (a simple, satisfying, low-stakes coverage verb — the game's cooldown), strike
the ladders, recover dogs. The mill's hooter goes as you reach the ground.

## Beats

1. Touching the chimney and finding it warm.
2. Finding the old iron band at 14 m and realising it's a free anchor.
3. The first lateral circuit. **You go round the corner and your ladder stack disappears from view.**
   Nothing has changed mechanically. It is much worse.
4. **HERO BEAT:** hauling a 90 kg steel segment 48 m up a live chimney while it swings, with a
   greenhouse below you.
5. Working band #3 hanging in the chair, over a mill yard, at 48 m, with heat shimmer above you.
6. The hooter, and the mill emptying out into the street as you're coiling rope.

## Failure modes available here

| Failure | Telegraph | Consequence |
|---|---|---|
| Bad measurement | visible tape slack + a muttered line | rework, −20 min |
| Wrong tension sequence | the band visibly distorts | −6 min |
| Haul swing into brickwork | swing meter red | brick falls; greenhouse at risk |
| **Greenhouse** | it's right there, west side, and the letter told you | −£14/pane, reputation −2 |
| Anchoring on the crack | the joints read Cracked; the tap rattles | anchor fails immediately |
| Fall | standard | standard |

## Scoring

```
Base                                  £620
All three bands fitted & tensioned    required
First-time fit (no rework)            +£80
No damage to third-party property     +£50
Before dark                           +£50
Crack repointed                       +£50
Greenhouse panes                      −£14 each
```

## Data
`data/levels/04-alma-mill.json`
