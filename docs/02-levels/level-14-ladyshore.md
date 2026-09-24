# Level 14 — Ladyshore

**Archetype:** TOP · **Height:** 38 m, taken down to 4 m · **Fee:** £1,560 · **Gate:** ★★★
**Order:** 9 — the second half of act two.

---

## Why a second topping job

[21-the-paid-game.md](../01-gdd/21-the-paid-game.md) sets the rule that no archetype may appear
twice before act three, and topping is the one that earns two because the *reason* for topping a
chimney is the interesting part and there are two entirely different ones.

[Shawclough](level-13-shawclough.md) is a **shortening**: twelve metres off a sound stack whose top
has gone, and the course you stop at is the one thing you must not damage. The skill is picking the
joints that will hold in brickwork that is half sand.

Ladyshore is a **hand-demolition**, and it is the real reason the trade tops chimneys out rather
than felling them: **there is nowhere for her to go.** An infants' school nine metres off her on
the east, the canal on the west, the coal road between. Two men have already looked at her and
both said the same thing. So all thirty-eight metres come down by hand, a brick at a time, and
nothing goes over the side.

## What makes it hard, and what does not

**Not the brickwork.** She is a good chimney, well laid, and there is nothing wrong with her. That
is stated in the level file in as many words and it is the point: she is coming down because of
where she is standing, and the player should feel slightly sorry about it. The anchors will hold;
sounding them is a habit here rather than a lifeline.

**The clock.** Nine hours, and a target of seven. Thirty-four metres at a few courses an hour is
the whole day and there is no shortcut in the verb — you cannot hurry a prise without snapping the
brick, and the client is paying you by what comes out whole.

**The flue.** On Shawclough the flue is a convenience. Here it is the *only* route, because of the
school, so when it packs there is no second option: it gets cleared, and that is the afternoon
gone. A player who ignores the flue meter on Shawclough loses an hour once. A player who ignores
it here loses the job.

## The shape of the day

| Height | What it is | What it does to you |
|---|---|---|
| 32–38 m | The corbelled oversail — four courses stepping out | It comes off first and it comes off **outwards**: the one place on this job where a brick does not go down the middle. |
| 24–32 m | Jackdaws in the oversail | They have been there longer than the Council has owned her. |
| 12–24 m | Good brick, well laid | Nothing wrong with her. That is the difficulty. |
| 0–12 m | Ivy to the first twelve metres | Under it the brick is perfectly sound. Eleven years shut and nobody near her. |

## Open, and it matters

**Nothing enforces "nothing over the side" yet.** The sim's `Top::Drop(downTheFlue)` takes the
choice and the comment says over the side is "somebody else's problem and the level decides what
they hit" — but no level decides anything, and the Godot side drops down the flue automatically
unless it is jammed, in which case it silently goes over instead. On this chimney that is a brick
into a school playground.

This level is playable without it and the letter carries the intent, but the job is only really
*about* something when the site can refuse. That wants an exclusion in `site` that the drop reads,
and it is the natural next piece of work on this archetype.
