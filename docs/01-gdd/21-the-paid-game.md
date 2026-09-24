# 21 — The Paid Game

> Written 2026-09-24, after a play session where the designer's verdict was: *"There are lots and
> lots of controls about jigs and all this other stuff and bands. None of it made any sense to me
> when I was playing the game. I couldn't quite understand what I was supposed to be doing."*
>
> That is the whole problem statement. Everything below is downstream of it.

This document answers three questions that had not been asked directly: what is actually built
versus designed, what a £15–20 Steam game owes its buyer, and what would make somebody think about
this game on the bus.

---

## 1. The honest inventory

The gap is not where it feels like it is. The engine is far ahead of the content.

| Archetype | Sim built | Levels using it |
|---|---|---|
| SURVEY | yes | 3 |
| CONDUCTOR | yes | 3 |
| BAND | yes | 2 |
| FELL | yes | **4** |
| STRAIGHTEN | yes | 1 |
| **TOP** | **yes, fully, with tests** | **0** |
| GILD | no | 0 |
| MECHANISM | no | 0 |
| LATTICE | no | 0 |
| EMERGENCY | no | 0 |

**`Top.h` is the finding.** Taking a chimney down brick by brick — seat the bolster, lever until
the joint gives, release in the window, drop it down the flue and clear the jam when it blocks — is
implemented, tuned and under test, and not one level in the game points at it. The most
characterful verb in the design is dead code.

And four of thirteen levels are fellings. **The repetition the designer felt is in the level data,
not the engine.** That is the cheapest variety win this project will ever get.

---

## 2. What £15–20 actually buys, in this genre

The comparison set is not other climbing games. It is the "competent trade, satisfying process"
shelf: *Hardspace: Shipbreaker*, *PowerWash Simulator*, *House Flipper*, *Lawn Mowing Simulator*.
That shelf sells at £16–25 and the reviews are strikingly consistent about what earns a thumbs-up:

1. **A signature image.** One thing the game does that no other game does, which players screenshot
   unprompted. Steeplejack already has it and it is not the climbing — it is **looking down your
   own ladder stack**. Every metre of that route exists because you put it there. Nothing else on
   the shelf has a progress bar you can fall off.
2. **Felt competence growth with no XP.** Players reward the feeling that *they* got better. The
   GDD already forbids a skill tree, which is the right call and happens to be the thing that shelf
   is praised for.
3. **No filler.** The single most common negative review on this shelf is "it gets repetitive
   around hour six". Four fellings in thirteen levels is exactly that failure.
4. **It respects your evening.** Bounded sessions with a visible next step.

What that shelf does **not** require, and we should not pay for: open world, combat, voice acting,
multiplayer, a story with characters.

### The realistic shape

- **£15–18**, ~10–14 hours to finish the career, plus a reason to keep the save.
- Twelve to sixteen jobs, **no archetype used more than twice** before the last act.
- One genuine set-piece per act.

---

## 3. Mission variety — the plan

Rule: **an archetype may not appear twice in a row, and no more than twice before act three.**
Variety is not more verbs, it is better spacing of the verbs we have.

### Act one — learning to read a chimney (jobs 1–4)
SURVEY, CONDUCTOR, BAND, SURVEY. Low, forgiving, and each one teaches exactly one noun.

### Act two — the trade proper (jobs 5–9)
**TOP** (new, and it is the act's centrepiece), FELL, BAND, **TOP**, STRAIGHTEN. Topping is where
the game stops being about getting up and starts being about the work at the top, which is the
promise the vision makes and the game currently does not keep.

### Act three — jobs nobody sane takes (jobs 10–13)
FELL, CONDUCTOR (in weather), **EMERGENCY**, FELL (the Great Aire).

### The two new archetypes worth building, in order

1. **EMERGENCY** — a chimney that is already going. A fixed clock, no survey, no choice of route,
   and the only job in the game you are allowed to fail well. It reuses FELL's collapse and the
   slip model wholesale. Highest drama per line of new code in the project.
2. **GILD** — fine motor work at the very top with no structural stakes at all. It exists to be
   the opposite of everything else: quiet, slow, and about a steady hand. The GDD already has it.

MECHANISM and LATTICE stay unbuilt. They are different *structures*, not different *work*, and a
new structure is a lot of art for one job.

---

## 4. The meta layer — what is there, and the one thing missing

The designer asked for "Metal Gear Solid bases". **That design already exists in
[08-hub-and-meta.md](08-hub-and-meta.md) and most of it is built:** the yard, the shed, the board,
the kettle, the day cycle, and the traction engine under the tarpaulin at 41 parts.

The engine is the right answer and it is *already the right answer for the reason the designer is
asking about.* From the existing doc: it has **zero mechanical benefit**, it visibly changes in the
yard with every part, and finishing it costs about £9,000 against £16,000 of career earnings — so
it is a real choice against better ladders.

What is missing is not a system. It is **visibility**:

- The engine is a grey shape under a tarpaulin behind a menu. It should be the thing you walk past
  every single morning, changing.
- **The skyline should be the save file.** The chimneys behind the yard are the ones still
  standing; a stump with a chalk cross is one you took down. The game's melancholy is that the job
  destroys the world it lives in, and right now that is a line in a design document instead of the
  first thing you see each day.

### Why this is the right loop and not a cynical one

The literature people reach for here is variable-ratio reinforcement — slot-machine scheduling. It
is not what this game needs and it would poison it. The honest mechanisms are:

- **Competence and autonomy** (Ryan & Deci, self-determination theory). Intrinsic motivation
  survives when a player feels they are getting better at something real and choosing how. That is
  the vision's stated pillar already: *"the power fantasy is knowledge, not strength."*
- **The Zeigarnik effect** — unfinished work occupies the mind more than finished work. A traction
  engine sitting at 11 of 41 parts, visible, cheap to resume, is the whole mechanism. It needs no
  timers, no streaks and no daily login.
- **A bounded session with a visible next step.** The kettle already does this: one job, one day,
  and tomorrow the wind drops to 3 m/s. That is a reason to come back that costs us nothing and
  insults nobody.

**No timers, no streaks, no daily rewards, no currency you can buy.** A game about a vanishing
craft cannot have a battle pass.

---

## 5. The thing that blocks all of it

None of the above matters while the designer's actual sentence stands: *none of it made any sense
to me when I was playing.*

**Standing rule, alongside "a status change is not an event":**

> **Do not assume for one minute that any of this will make sense to anybody playing it.** A
> steeplejack's yard is an alien world. Every noun — dog, bolster, span, lashing, band, gin wheel,
> sounding, perished — has to be taught in the world, at the moment it first matters.

Three mechanisms, none of which is a tutorial level:

1. **The letter teaches the job.** The client asks for the work in their own words, and the board
   carries a short trade note in ours: *"the bolts in the band are what squeeze the chimney, so a
   loose band does nothing at all."* Two sentences, before you leave the yard.
2. **The instrument teaches the rule.** The band goes visibly oval as you work round it, drawn
   against the circle it is meant to be — not a number labelled "ovality". You learn the star
   sequence the first time you get it wrong, from the shape, without being told.
3. **Refusal teaches the constraint.** The control list shows only what you can do; press a key it
   has not offered and it tells you why. That is now built.

---

## 6. Order of work

1. **Wire TOP to a level.** An entire tested archetype for the cost of a level file and its
   geometry. Biggest variety-per-hour in the project.
2. **Re-space the campaign** so no archetype repeats back to back.
3. **The "what this is" panel on the board.** Two sentences per archetype, in the trade's voice.
4. **The skyline as the save file**, and the engine where you can see it.
5. **EMERGENCY**, then **GILD**.

Everything above 4 is content and copy over systems that already exist and are already tested. That
is the good news, and it is why this is a £15 game with about a month in it rather than a rewrite.
