# Level 13 — Shawclough Mill

**Archetype:** TOP · **Height:** 46 m, taken down to 34 m · **Fee:** £1,040 · **Gate:** ★★★
**Order:** 6 — the first job of act two.

> Written 2026-09-24. The TOP sim (`Source/SteeplejackSim/Public/Top.h`) had been finished, tuned
> and under test since TOP-001, and **no level in the game had ever named the archetype and there
> were no Godot bindings for it at all.** The most characterful verb in the design was dead code.
> This is the level that turns it on.

---

## Why this job exists

The vision promises "a hard day's **craft work** at the top". Up to now the game has kept the first
half of that sentence and not the second: you climb beautifully and then you fasten something.
Topping is the one job where the climb is the commute and the work is the point.

It is also the archetype that best answers the repetition problem. Four of thirteen levels were
fellings — a felling is a morning of preparation and then eight seconds of spectacle. Topping is
its exact opposite: four hours of small, careful, repeated decisions where the drama is entirely
in your own hands and nothing dramatic ever happens. The campaign needs both.

## The job

The mill has a new boiler. The old stack over-draws for it and the top of her is perished anyway,
so twelve metres come off and a new cap goes on what is left. **She is not being demolished. She
is being shortened**, which changes everything about how you treat her: the course at 34 m is the
one the new cap will sit on, and damaging it is the one thing that cannot be undone.

The client pays by what comes out whole, because he has a buyer for the brick. That is the level's
scoring and it is also its whole argument: *hurrying costs you money in a way you can see.*

## The verb, and the thing it is actually about

Bolster in the joint, lean on the bar, and let go at the moment the mortar gives.

The give point is a **fact about the brick**, fixed by the seed before you touch it — not a dice
roll at the moment of the stroke. Sounding the joint first tells you where it is and widens the
window from `giveWindowMs.base` to `giveWindowMs.sharpBolster`. So the skill is not reflex, it is
**read-ahead**: the players who do well are the ones who sound before they lever, and the game
never says so.

Past the give point the load keeps building. That is the design's best detail and it should be
felt before it is explained: holding on a fraction too long is not a miss, it is a **snap**, because
you have stopped loading the joint and started loading the brick.

## The shape of the day

| Height | What it is | What it does to you |
|---|---|---|
| 0–12 m | Sound brick, nothing happening | The commute. Eleven sections gets you started. |
| 12–22 m | **Old fixtures** — a previous jack's dogs, forty years in the wall | The first real decision. A rusted dog is a free anchor or a fall, and sounding it is how you find out. |
| 22–34 m | Sound brick. **The finish line.** | Everything above this is coming off; this course must not be damaged. |
| 34–42 m | Perished — the mortar is sand | Levering is *easy* here, which is the trap: easy to prise is also nothing to stand on. |
| 42–46 m | All but gone | The manager said you could pull this out by hand. He is right, and that is the problem: **there is nothing up here to lash to.** You have to build your own security out of the thing you are dismantling. |

That last row is the level's idea. You work downwards, and the material you are standing on is the
material you are removing. The dogs you seat at 40 m are seated in mortar you have already been
told is sand.

## The flue

Bricks go down the flue — she is disconnected, so there is nothing to spoil. The flue packs at
`flueCapacityBricks` and then it **jams**, and clearing a jam costs you a gin wheel, a weight and a
chunk of the afternoon. A player who never looks at the flue meter will lose an hour to it once and
never lose it again. That is the right kind of lesson and it needs no text.

## Teaching

Per [21-the-paid-game.md](../01-gdd/21-the-paid-game.md), the letter does the teaching and the
instrument does the rest:

- **The letter** says he has a buyer for the brick and that breakages are yours to explain. That is
  the scoring rule, in the client's voice, before you leave the yard.
- **The board's "what this is" note** must say the one non-obvious thing: *sound the joint before
  you lever it, and let go the instant she gives — hold on and you are loading the brick, not the
  mortar.*
- **The instrument** shows the load climbing against the give point once the joint is sounded, and
  shows nothing but the load when it is not. The difference between those two readouts is the
  entire argument for sounding, and it is made without a sentence.

## What it must not become

A rhythm game. There is no perfect-timing streak, no combo, no escalating tempo. The interest is in
*which* bricks you sound and how much daylight that costs you — a resource decision spread over
four hours — not in hitting a moving bar. If playtesting shows people mashing without sounding and
still scoring well, the fix is to widen the gap between the two windows, never to speed anything up.

## Open

- **The new cap.** The job is not done when she is at 34 m; she needs capping. That is currently
  out of scope and the level ends at the height. It should probably not.
- No replay recorded yet.
