# 08 — The Hub & The Meta Layer

## The yard

A small terraced house with a back yard in a mill town. It is the only place in the game at ground
level where nothing is trying to kill you, and that contrast is the point. Warm light, a fire,
a kettle, a whippet, a van, and — under a tarpaulin — a very large, very rusty traction engine.

The hub is **not** an open world. It's one small space with 5 interaction points. Total time per
visit: 2–5 minutes. It must never become a chore.

### 1. The Van — loadout
Choose what goes on the job. Constrained by the roof rack and the belt.

```
LADDERS     ▢▢▢▢▢▢▢▢▢▢▢▢   12 sections  (you own 14; 2 are cracked)
DOGS        ×40            (you own 62)
ROPE        ×3 coils
BELT        8 slots: [hammer][dogs][rope][gin wheel][bolster][____][____][____]
```

**This is the strategy layer.** The briefing tells you the chimney's height and the job type; you
decide. Bringing 12 ladders for a 55 m chimney assumes 4.6 m average spans — i.e. you're committing
to risky spans before you've even left the yard. Bring 16 and you'll spend an extra ten minutes
hauling. There is no "recommended loadout" button.

### 2. The Bench — tool maintenance
A list. Click to sharpen/re-shaft/splice/replace. Cheap in money, cheap in time. The interest is
entirely in whether the player bothers to look. A **kit check prompt** appears before departure and
can be dismissed.

### 3. The Board — jobs
Letters and postcards pinned to a board. Each is a hand-written briefing:

```
   Messrs. Holroyd & Sons, Alma Mill, Sowerby
   ─────────────────────────────────────────────
   Our chimney is cracked from the top and the
   insurance want three bands on it before winter.
   Height about 180 foot. We can pay £620.
   There's a greenhouse on the west side which
   my wife is very fond of.
                                     J. Holroyd
   ─────────────────────────────────────────────
   TYPE   Re-banding        HAZARD  Perished course
   HEIGHT 55 m              WEATHER Fair, wind 6 m/s
   FEE    £620              REP     ★★☆☆☆ required
```

Briefings are **the only tutorialisation for new mission types.** They tell you what's needed in the
voice of the client, not the voice of a tooltip. The hazard/weather line is the concession to
usability and it's small.

### 4. The Kettle — save, sleep, advance the day
Days pass. Weather changes day to day and is visible on the board. Some jobs have deadlines. Some
weather makes some jobs stupid. **Choosing to wait a day for better wind is a real decision** with a
real cost (deadlines, money).

### 5. The Tarpaulin — the engine

A 1912 traction engine, in pieces, in the yard. This is the game's long-term carrot and it has
**zero mechanical benefit**.

- ~40 parts, each bought with job money: boiler tubes £180, a new firebox £900, gears, a chimney,
  brasswork, paint, lining out, the nameplate.
- Each purchase **visibly changes the model in the yard**. It goes from a rusted heap to a
  magnificent green-and-red machine over the course of the campaign.
- Total cost across the campaign: **~£9,000**, against total career earnings of ~£16,000. So you can
  finish it, comfortably, if you do good work — and you can also blow the money on better ladders
  and never finish it.
- **The endgame:** when it's complete, you can steam it. The credits sequence is driving it, very
  slowly, out of the yard and through the town, past every chimney in the game — most of which are
  no longer there, because you took them down.

**Why this works:** the game's whole melancholy is that the job destroys the world it lives in. The
engine is the one thing you *build*. It is the emotional counterweight to twelve levels of
demolition, and it costs us one model with 40 progressive states and no new systems.

---

## Progression

### Reputation
0–100, shown as stars. Gates jobs.

| Change | Amount |
|---|---|
| Job completed | +3 |
| Job completed with all bonuses | +6 |
| Third-party damage | −2 to −15 by value |
| Fell wildly off line | −10 |
| Injured on a job | −4 |
| Refused/abandoned a job | −5 |

### There is no skill tree
The player gets better; the character does not. **Every mechanical improvement comes from equipment
and knowledge, never from XP.** This is a hard rule.

Equipment upgrades (all purchasable, all trade-offs):
| Item | Cost | Benefit | Cost |
|---|---|---|---|
| Alloy ladders | £340 | 40% lighter, faster haul | flex more; buckle span 6.5 m not 8 m |
| Forged dogs (better steel) | £0.90 ea | 60% less bend risk | more expensive |
| Good rope | £26 | no shock-fail chance | — |
| Proper bosun's chair | £75 | rig in 12 s not 20 s | — |
| Leather gloves | £6 | grip drain ×0.85 | tap-test −1 tier |
| A decent hammer | £18 | −30% angle error | — |
| A second flask | £2 | two brews per shift | belt slot |
| **A lad** (apprentice) | £8/day | hauls for you from the ground | he is not very good |

The apprentice deserves special mention: hiring him removes the haul verb from the game (he does it),
which is either a relief or a loss depending on the player. He also occasionally does something
wrong. He's optional, he's cheap, and he's funny.

---

## The difficulty settings

Three, chosen at the start and changeable at any time in the hub, with no judgement from the game:

| | **Assisted** | **Jack** (default) | **Owd Fred**† |
|---|---|---|---|
| Tap-test visual pip | on | off (toggleable) | off |
| Anchor rating shown | always | always | always (never hidden — core principle) |
| Nerve drain | ×0.6 | ×1.0 | ×1.4 |
| Slip-save window | 1400 ms | 900 ms | 650 ms |
| Slip-save cooldown | 30 s | 60 s | 120 s |
| Daylight | ×1.4 | ×1.0 | ×0.85 |
| Injuries persist | no | yes | yes, and worse |
| Fall = | resume at stack | resume at stack, lose fee | resume at stack, lose fee + 2 ladders |

† placeholder name — see [`../05-legal/ip-and-likeness.md`](../05-legal/ip-and-likeness.md), must not
reference a real person. Suggested: **"Owd Hand"**.

**Note the row that doesn't change.** Anchor ratings are always visible on every difficulty. Hiding
information is not difficulty; it's noise.
