# Level 00 — The Grey Box

> Not a campaign level. This is the MVP test rig: the chimney "The Ascent" is built and judged on.
> See [`mvp.md`](../04-production/mvp.md#mvp-scope--the-ascent).

## At a glance

| | |
|---|---|
| **Archetype** | SURVEY |
| **Height** | 55 m |
| **Structure** | round brick chimney |
| **Fee** | £250 |
| **Shift length** | none — `shiftMinutes: null`, no clock |
| **Target completion** | 25 minutes (reference only, nothing enforces it) |
| **Weather** | 3.0 m/s base rising to 1.8× at the top, gusts every 50–95 s, no precipitation |
| **Reputation gate** | ★0 |
| **New to the player** | everything — this is the only level that exists |

## The one-line pitch
Twenty-eight anchors of nothing but the climb, so that when someone asks *"is this still
interesting at anchor twelve?"* there is a real answer and nothing else to credit it to.

## Briefing (the job letter)
None. The hub, the job board and the mission system are all out of MVP scope, so the level loads
straight into the field with no framing. The `mission` block is `{ "type": "SURVEY" }` — the
minimum the schema will accept — and carries no objectives.

This is deliberate: a briefing would tutorialise, and the MVP question is whether the *verbs*
teach themselves.

## Site layout
An empty field. No exclusions, no corridor, no crowd, nothing to drop anything on. The safe line
sits at 90 m, comfortably beyond the 82.5 m that 1.5× height would ask for, because there is
nothing for it to protect.

```
                  N
                  |
                  |
        . . . . . . . . . . . .      <- town silhouette, distant (ENV-002)
                  |
                  |
             [ chimney ]              55 m, round, no lean
                  |
             van  |                   ~25 m, south
                  |
        - - - - - - - - - - - -       safe line, 90 m
```

The backdrop key is `open-field`. Fog and the distance-faded town silhouette are what make the
height read honestly rather than as a grey tube in a void — see the MVP's "the one piece of art
we do build".

## Ascent bands

Four bands, one complication each. No band is longer than 16 m, so the Ascent Beat Rule's
15–20 m cadence holds all the way up.

| From | To | Band | What it asks of the player |
|---|---|---|---|
| 0 m | 16 m | **plain** | Nothing yet. Learn tap → dog → lash → climb on joints that mostly reward the obvious read. Under the 20 m ceiling on purpose: long enough to settle, short enough not to bore. |
| 16 m | 30 m | **salt-bloom** | Efflorescence whitens the face and the visual read stops working. Tapping becomes the only way to know. The distribution behind the bloom is genuinely mixed, so guessing is punished. |
| 30 m | 42 m | **old-fixtures** | Nine rusted dogs from a previous jack, unrated. Take one and skip the hammer work, or place your own and lose the time. Speed for uncertainty. |
| 42 m | 55 m | **perished** | Sound joints are scarce and clustered. Spans get short exactly when the cap is in sight and the player wants to hurry. |

## The work
There is no mission, so the SET UP → FIDDLY BIT → COMPLICATION → CLEAR UP shape is carried
entirely by the ascent itself.

### Set up
Unload, read the stack from the ground, commit to a line up the face. The first three anchors are
routine and exist to make the fourth one felt.

### The fiddly bit
The salt-bloom band. The verb the whole game rests on stops being optional and becomes the only
instrument the player has.

### The complication (authored, not random)
The old-fixtures band, at 30 m — the first point where the fast option and the safe option differ
and the game refuses to say which is which.

### Clear up
There is none, and that is a known gap. The player reaches the cap and the level simply ends.
See Open questions.

## Beats
1. First tap — the four tones are distinguishable, or the game does not work.
2. First dog driven badly and felt to be bad, before anything punishes it.
3. **Hero beat:** first tap into salt bloom at ~17 m, when the eyes stop being useful and the
   player realises the ear has been the instrument all along.
4. First free fixture taken at ~31 m, and the small silence afterwards waiting to find out.
5. The wind becoming audible somewhere past 35 m without ever being announced.
6. A short, ugly, correct span in the perished top because the alternative was worse.
7. The cap, and looking down.

## Failure modes available here
Per the fairness contract, every one ships with its telegraph.

| Failure | Telegraph |
|---|---|
| Dog pulls from a perished joint | tap tone is dull and short before it is ever driven |
| Ladder span too long | span warning on the placement preview; flex visible under load |
| Slip from a gust | 1.2 s gust tell — audible pre-roll and visible dust/ivy movement |
| Nerve collapse at height | grip and nerve arcs degrade visibly and audibly (breathing) well before |
| Unrated fixture fails | rust is visible at close range; the fixture is *unrated*, never mislabelled |

No failure here is instant or unsignalled. Falls cut to black and resume at the stack.

## Scoring
Base fee £250, no bonuses, no hard-fail conditions. `scoring.bonuses` is an empty array.

Scoring is deliberately inert: the MVP question is whether the climb holds attention, and a bonus
structure would supply a different reason to keep going and contaminate the answer.

## Data
[`data/levels/00-greybox.json`](../../data/levels/00-greybox.json). Validated by `make validate`.

Two notes on the data:

- **`order: 99` is a sentinel.** This level is not in the campaign sequence, but the schema
  requires `order` to be an integer of at least 1, so there is no way to say "unordered". 99 is
  the least misleading value available. The schema should probably allow `0` or `null`.
- **Band `params` keys are provisional.** `visualReadReliability`, `bloomCoverage`,
  `fixtureCount`, `fixtureSpacingMetres`, `fixtureRated` and `soundJointClustering` describe
  intent, not a settled interface. The band generators in `SteeplejackSim/Private/Joints.cpp` do
  not exist yet; whoever writes them should treat these as a proposal and rename freely.

## Open questions
- **What happens at the top?** There is no topping mission and no end state — the player reaches
  the cap and nothing happens. Acceptable for a climb test, but somebody has to decide whether
  the MVP needs an ending or whether "you are at the top, look down" is the ending.
- **Is 14 ladders right?** It gives a 3.93 m average span against a 4.0 m comfortable figure —
  deliberately just inside comfort, so span risk is always a choice. Untested with hands on it.
- **Does the perished top actually produce short spans,** or does joint clustering let a careful
  player sail through it? Depends entirely on the generator, which does not exist yet.
