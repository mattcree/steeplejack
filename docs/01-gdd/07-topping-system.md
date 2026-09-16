# 07 — The Topping System (brick by brick)

> Taking a chimney down by hand, from the top, dropping the bricks down the inside.
> The novelty: **the level geometry shrinks under the player in real time.**

## Why by hand?

Because the level says you can't fell it — there's a chapel twenty feet away, or it's in a mill yard
with a live boiler house. The game establishes this in the job briefing so that "why not just blow
it up" is never a question.

## The shape of it

```
SET UP      build a staging round the top; lash it to your stack       3–5 min
COPING      remove the cap/corbel in the correct sequence              2–3 min
COURSES     the rhythm: prise, drop, prise, drop                       8–20 min
  ├─ every ~2 m: lower the staging, strike a ladder off your own stack
  ├─ every ~4 m: a complication (jam, nest, an iron tie, a soot fall)
CLEAR UP    descend, count bricks, clear the flue base                 2 min
```

## The staging

A small timber platform you build around the top of the shaft, lashed to your ladder stack and to
dogs driven around the circumference. Four putlogs, four boards, eight lashings. It is the only
place in the game you can **walk around freely at height**, and it is glorious — standing on a
1.2 m-wide ring of scaffold boards, ninety metres up, with a hole in the middle.

Building it is the level's first act and is a pure application of dog-in + lash, done eight times,
laterally. It teaches by repetition without feeling like a tutorial because the payoff is obvious.

**The staging must be lowered as the chimney shrinks.** Every ~2 m of demolition: unlash, re-dog
lower, re-lash, re-board. This is the rhythm-breaker that stops the course work becoming monotonous,
and it's a moment of real exposure (you're standing on a chimney top with no staging).

## Removing the coping

The cap of a mill chimney is a corbelled, oversailing course — it holds itself up by
interlocking. **Remove it in the wrong order and the top course peels off in a slab**, taking your
footing (and possibly you) with it.

- The correct order is readable: look at which bricks overlap which. It's a small, genuine,
  ten-second spatial puzzle, and it's different on each chimney.
- Get it wrong → a slab goes, nerve −30, and if you were standing on it, a slip-save.
- Chalk marks from a previous jack sometimes give you a hint. (Reward for looking.)

## The course rhythm — the PRISE verb in anger

This is the loop, ~1.5–2.5 s per brick:

```
1. AIM     at a mortar joint on a brick's exposed edge
2. SEAT    tap the bolster in (short hold)
3. LEVER   push into resistance — a resistance curve builds
4. GIVE    at the release point there is an audio+haptic "tick"
           release at the give  → brick comes free CLEAN     (salvage +1, 1.5 s)
           release early        → nothing, re-seat            (2.5 s wasted)
           release late         → brick SNAPS                 (rubble, 1.2 s, jam risk +)
5. DROP    toss it down the flue (a short arc; missing the flue = it goes over the side
           = a hazard on the ground = £ if it hits something)
```

### Where the skill is
The **give point varies with the mortar strength of that specific brick**, which the player can
pre-read with a tap-test — but tapping every brick costs 0.8 s each, which destroys your rate. So
the real skill is **learning to read a course at a glance and only tapping the ambiguous ones.**
That's a lovely, legible mastery curve: a new player taps everything, an expert taps one in eight.

### Rate and pacing (critical tuning)
A real chimney has ~800 bricks per metre. We are not simulating that.

- **Interactive bricks: 18–24 per metre of height.** The rest of each course auto-resolves visually
  once its interactive bricks are gone (the wall visibly drops a course, with dust).
- At ~1.8 s/brick that's **~40 s per metre**. A 15 m top-down = ~10 min of coring + ~5 min of
  staging moves and complications = **a 15–20 minute level**. Correct.
- **Do not exceed 24 interactive bricks/metre.** If playtest says it drags, cut to 14 before you
  touch anything else.

### Salvage
Clean bricks are worth **2p each** and they stack up: a 15 m job is ~300 interactive bricks, so
~£6 — trivial. **Salvage is not about money.** It's a *rate* score: `clean / total` is shown on the
reckoning as a craftsmanship grade, and the fee bonus is for the grade, not the bricks. The money
is a joke the game makes deliberately: "Two hundred and eighty bricks. Six pound. Mind, they're
lovely bricks."

## The jam

Every 60–120 dropped bricks (authored, not random), the flue jams. You hear it: the falling-brick
sound stops being a long descending rush and becomes a short clatter.

- Clear it by dropping a **heavy weight** on a rope down the flue and pulling it back up — a haul
  verb, inverted.
- Or ignore it and keep working. The flue fills, and once full you must **carry bricks down** instead
  of dropping them, which destroys your rate. (A viable but miserable choice — good.)

## Complications (authored per level)

| Complication | Effect |
|---|---|
| **Jackdaw nest** | a metre of packed twigs in the flue; must be pulled out; birds startle (nerve −8) |
| **Iron tie bar** | a wrought-iron ring cast into the brickwork; must be cut with a cold chisel (30 s) |
| **Soot fall** | opening a flue section dumps decades of soot; 4 s blind, grip −30 |
| **Perished band** | 2 m of courses where every brick snaps regardless; salvage rate tanks, rate rises |
| **Leaning section** | the shaft above a crack is out of plumb; removing one side accelerates it |
| **Your own stack** | the ladders now stick up above the chimney and are in the way; strike them |

Rule: **one complication per 4 m**, never two within 90 seconds.

## The thing that makes it special

Halfway through, the player realises that the chimney they spent twenty minutes climbing is now
shorter than their own ladder stack. They have to dismantle their route down while standing on what's
left. The world they built is being eaten from the top by the work they're doing. **Make sure the
camera gives them a clear look at this at least twice**, and have the character remark on it once,
drily, and never again.

## Tuning block

```jsonc
{
  "interactiveBricksPerMetre": 20,
  "prisePerBrickSeconds": 1.8,
  "giveWindowMs": { "base": 120, "sharpBolster": 160, "bluntBolster": 80 },
  "snapChance": { "onLateRelease": 1.0, "perishedBand": 1.0 },
  "salvageValuePence": 2,
  "stagingMoveIntervalMetres": 2.0,
  "jamIntervalBricks": [60, 120],
  "complicationIntervalMetres": 4.0
}
```
