# 10 — Failure, Difficulty & Fairness

## The fairness contract

Write this on the wall:

> **The player must always be able to say, in one sentence, why that went wrong.**

Every failure in this game is caused by either (a) information the player had and ignored, (b)
information the player could have got for a known cost and chose not to, or (c) a telegraph they
missed. Never by a dice roll they couldn't see.

| Failure | Was it fair? | Because |
|---|---|---|
| Anchor pulled | ✅ | its rating was Poor and shown on the pip |
| Ladder buckled | ✅ | the span was over 8 m and the HUD said so |
| Fell off | ✅ | grip hit zero; the meter was on screen and trembling |
| Chimney went the wrong way | ✅ | the lean was measurable and the load diagram was live |
| Brick snapped | ✅ | you released late; the give was audible |
| Gust blew you off | ⚠️ | **only** if the 1.2 s audio tell played. Otherwise it's a bug. |
| Rope failed | ⚠️ | only if condition was Frayed *and* shown at kit check |
| Prop split | ⚠️ | only if load was over 40 kN and the diagram showed it |

Anything marked ⚠️ has a **telegraph requirement**. Those telegraphs are features, not polish. Ship
them in the same task as the mechanic.

## Failure states, in order of severity

### 1. Wasted material
A bent dog, a snapped brick, a lost gold leaf. Costs pennies and a few seconds. **The most common
failure and it should stay common** — it keeps the verbs from being solved.

### 2. Wasted time
Re-seating a bolster, re-tying a slipping lashing, clearing a jammed flue, going back down for a
tool. Costs daylight. This is the main economy pressure.

### 3. Rework
A band that doesn't fit because you measured badly. A weathervane you have to re-plumb. A conductor
run that fails inspection. Costs a big chunk of the shift and stings.

### 4. The slip-save
Grip zero, or an anchor goes. 900 ms to react. One per 60 s. Survive it and you take nerve −25,
which is the real cost — the *next* task is measurably harder.

### 5. The fall
Covered in [`02-climbing-system.md`](02-climbing-system.md) §6. To restate the key decisions:
- **Never restart the level.** The ladder stack persists; you resume from it.
- **Lose the day's fee**, take reputation −4, and get an injury.
- **Injuries persist 2–3 jobs** and are the real punishment. A cracked rib (+25% grip drain) makes
  the next job genuinely harder. This gives a fall long-tail consequence without ever wiping progress.
- Maximum of **one injury carried at a time** — stacking them would spiral.

### 6. Job failure (rare)
Only three things fail a job outright:
- Dropping the weathercock and smashing it (L3).
- Hitting a CATASTROPHIC exclusion object with a felled chimney.
- Running out of days before a hard deadline.

All three are heavily telegraphed and all three are *recoverable at the campaign level* — you lose
the fee and reputation, you move on. **There is no game over.**

## Difficulty philosophy

Difficulty is **time pressure and margin**, never hidden information and never reflex.

| Dial | Used? | Notes |
|---|---|---|
| Shift length | ✅ primary | the main knob |
| Wind speed & gust frequency | ✅ primary | changes wobble and nerve |
| Brickwork quality distribution | ✅ | fewer Sound joints = harder routes |
| Exclusion object tightness (felling) | ✅ | pure design pressure |
| Height | ✅ | nerve factor scales with it |
| Anchor rating visibility | ❌ never | |
| Random failure chance | ❌ never | |
| Reflex windows | ⚠️ only slip-save, and it's tunable | |
| Enemy damage numbers | n/a | there are none |

## The onboarding curve

| Level | New thing | Safety net |
|---|---|---|
| 1 | dog, lash, climb, tap, grip | 12 m — you literally cannot die |
| 2 | nerve, haul, descent work, daylight | 30 m, generous shift, forgiving mortar |
| 3 | bosun's chair, precision verbs, wind | 45 m, one hard fail (the drop) heavily flagged |
| 4 | lateral traversal, heavy haul, measurement | 55 m, rework possible but recoverable |
| 5 | topping, staging, shrinking geometry | 60 m, only 15 m to remove |
| 6 | **felling, all four acts** | open field, 180° corridor, no twist |
| 7+ | no new verbs — only new pressure | — |

**After level 6 the game teaches nothing.** It only asks harder questions. This is the whole design
and it's why the verb set has to be right before M4.

## Accessibility is not a difficulty setting
See [`14-accessibility.md`](14-accessibility.md). Every assist must be available **at every
difficulty**, independently.
