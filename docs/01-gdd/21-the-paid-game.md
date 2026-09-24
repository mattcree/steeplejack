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
| **TOP** | yes | **2** — Shawclough, Ladyshore *(wired 2026-09-24)* |
| GILD | no | 0 |
| MECHANISM | no | 0 |
| LATTICE | no | 0 |
| EMERGENCY | no | 0 |

**`Top.h` was the finding.** Taking a chimney down brick by brick — seat the bolster, lever until
the joint gives, release in the window, drop it down the flue and clear the jam when it blocks —
was implemented, tuned and under test, with **no bindings on Jack at all and no level naming the
archetype.** The most characterful verb in the design was dead code. It is wired now, with an
instrument, its own checklist, a settlement that pays on what came down whole, and two levels.

And four of thirteen levels were fellings, two of them back to back. **The repetition the designer
felt was in the level data, not the engine**, and it was the cheapest variety win this project will
ever get. Fifteen levels now, and no archetype follows itself anywhere on the board.

`test_levels.gd` asserts the mapping in **both** directions since 2026-09-24 — a level may not name
an archetype the game cannot run, and nothing the game can run may go unasked-for by the district.
The old check could only ever have caught the first.

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

### Act two — the trade proper (jobs 6–10) — **built**
**TOP** (Shawclough, the act's centrepiece), FELL, SURVEY, **TOP** (Ladyshore), FELL. Topping is
where the game stops being about getting up and starts being about the work at the top, which is
the promise the vision makes and the game did not keep until this was wired.

The two topping jobs are deliberately not the same job. Shawclough is a **shortening** — twelve
metres off a sound stack whose top has gone — and Ladyshore is a **hand-demolition**, all
thirty-eight metres of her, because there is an infants' school nine metres away and there is
nowhere for her to go.

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

What was missing was not a system. It was **visibility**, and both halves are built:

- **The engine** was a rectangle, two circles and a stick — a diagram of a reward rather than one.
  She is an engine now, through the six part-bearing stages: spoked wheels on their hornplates, the
  boiler with its smokebox and firebox, the flywheel and the rod to the crosshead, the steam dome
  and the safety valve, the canopy and the chimney and the red lining out, and finally her plate.
  The caption goes from "under restoration · <stage>" to "**in steam**".
- **The skyline is the save file.** The chimneys behind the yard are the ones still standing, a
  stump with a chalk cross and its spoil is one you felled, and one you topped is still there and
  shorter with no cap on her.

Both of those counted *every completed job* as a demolition when they were first written, so a
season of conductor runs flattened the town. The ending had the identical bug independently. The
answer lives in `District` now and nowhere else.

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

1. ~~**Wire TOP to a level.**~~ Done 2026-09-24: bindings, two levels, the stroke instrument, its
   own checklist, a settlement that pays on how much of her came down and how much came down
   whole, and the flue audible through the floor.
2. ~~**Re-space the campaign.**~~ Done. Fifteen levels, no archetype following itself, gates
   untouched and still monotonic.
3. ~~**The "what this is" panel on the board.**~~ Done, keyed on archetype so a level cannot ship
   without one, and guarded by a test.
4. ~~**The skyline as the save file**, and the engine where you can see it.~~ Done, and the same
   bug was found a second time in the ending — both now ask `District`. The engine is drawn as an
   engine through six stages rather than as three shapes.
5. **EMERGENCY**, then **GILD**. Not started.

### Still open, in rough order of value

- **The game has no font.** Every screen is Godot's fallback, which is most of what makes the menus
  read as generic whatever else is done to them. It wants a condensed grotesque for the trade's own
  lettering and a typewriter for the clients' letters, and that is a file somebody has to choose
  and put in the repo.
- **The character.** He is primitives with good materials on them now; he will not go further
  without a sculpt and painted maps. See the honest note in `worn.gdshader`. The open question is
  whether the environment should chase photoreal without him — a half-photoreal world with a
  primitive man in it looks worse than a coherently stylised one.
- **The climb cycle in motion.** The gait is rebuilt on the six determinants and the stride now
  matches the ground speed, but it has only been judged from a six-frame strip.
- **EMERGENCY** — a chimney that is already going. Reuses FELL's collapse and the slip model; the
  highest drama per line of new code left in the project.
- **Keycaps on the felling screen**, which still writes "[B]" and "[P]" inline.

Everything in 1 to 4 was content and copy over systems that already existed and were already
tested. That is the good news, and it is why this is a £15 game with about a month in it rather
than a rewrite.
