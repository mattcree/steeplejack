# 17 — The long game, and the stages of a job

Written 2026-09-20, answering two questions from a playtest: *what is the long game — think Euro
Truck Simulator* and *once you get your ladder up, you're onto the next stage; what happens next?*

The short answer to the first is that **the long game is already designed, in detail, in
[`08-hub-and-meta.md`](08-hub-and-meta.md), and almost none of it is built.** So this document is
not a new design. It is an audit of the one we have against the game that exists, plus a
recommendation about the order to build it in and one genuinely missing stage.

---

## Part 1 — What Euro Truck actually does

It is worth being precise about the comparison, because ETS's long game is not "driving". Driving
is the short game. The long game is three engines running under it:

1. **A ledger that only goes up.** Every delivery adds to a number, and the number buys a thing you
   chose in advance and can see: your own truck, then a garage, then another garage.
2. **A clock you are always spending.** Fatigue, delivery windows, a calendar that advances whether
   you like it or not. You cannot do everything today, so every job is chosen *against* another job.
3. **A map that opens.** Regions gate behind progress, so the world gets bigger as you get better.

Steeplejack has an equivalent for each. Here is the honest state of them.

| ETS engine | Steeplejack's version | State |
|---|---|---|
| The ledger | Money in the tin, spent on the traction engine under the tarpaulin — ~40 parts, ~£9,000 against ~£16,000 of career earnings, each purchase visibly changing the model in the yard | **Designed. Not built.** No hub scene, no engine, no purchases |
| The clock | The kettle: days pass, weather changes day to day, jobs have deadlines | **Designed. Not built.** And see below — the *data* is already there |
| The opening map | Reputation, five stars, `reputationGate` per level; height and hazard rise across the twelve | **Built.** `Career` keeps money and reputation, the board reads the gate |

### The clock is closer than it looks

Every level file already authors `shiftMinutes` and `targetMinutes` — the daylight the job comes
with and what a good day looks like. `Level.h` says so itself: *"Authored in every level file since
the first one and read by nothing until FELL-006 priced a felling in shift."*

So a climb job currently has a daylight budget that it ignores. That is the same shape of bug as the
span multipliers found earlier this week: a number authored honestly, carried all the way to the
edge of the system, and then passed to nothing. **The shift clock is the cheapest large thing in
this document.**

### Where it must not be Euro Truck

ETS's long game is *accumulative*: one truck becomes a fleet, and eventually you hire drivers to do
the thing the game is about. Steeplejack must not go there, for two reasons.

- **The fiction forbids it.** The pillar is competence in a vanishing trade — one man, a van and
  forty years of knowing which joint will hold. A haulage empire is the opposite story.
- **The mechanics forbid it.** Every hire removes a verb from the player's hands. The GDD already
  senses this and gets it right: the apprentice is £8/day, he hauls for you, *"he is not very
  good"*, and he is a trade-off rather than an upgrade.

So the ledger is not accumulation. **It is restoration, against a world that shrinks as you work.**
Twelve jobs in, half the chimneys in the district are gone because you took them down, and the one
thing that got bigger is a traction engine in your back yard that does nothing. That is a better
long game than ETS's, and it is already written. It needs building, not inventing.

---

## Part 2 — The stages of a job

The archetype shape in [`05-mission-types.md`](05-mission-types.md) is
**SET UP → THE FIDDLY BIT → THE COMPLICATION → CLEAR UP**.

Measured against what runs today:

| Stage | What it should be | State |
|---|---|---|
| **0. The yard** | Load the van. Twelve ladders or sixteen? That decision is the strategy layer | Not built; `loadoutHint.ladders` fills the cradle for you |
| **1. Laddering** | Dog, lash, haul, climb, sound the joints | **Built, and it is the best thing in the game.** Leave it alone |
| **2. The work** | Nine archetypes: survey, conductor, gild, band, top, fell, mechanism, lattice, emergency | **Two exist** — the ascent itself, and felling with its strip-out Act 2. Seven are paper |
| **3. Striking** | Take it all down and bring it home | **Missing entirely.** The level ends when you reach the top |

### Stage 3 is the real hole

A job in this game currently has no ending. You climb to the cap and that is that — which means the
player never does the half of the trade that happens after the work is finished, and it is not a
small half. It is also, mechanically, the most interesting half, and it costs almost no new systems
because **it is the verbs we already have, run backwards, under conditions that have got worse.**

What makes it a stage worth playing rather than a victory lap:

- **The meters are already spent.** The ascent is done on full grip and nerve. The descent is done
  on whatever is left at the end of a shift, and the cold cap has long since lifted.
- **You descend past your own work.** Every rushed lashing on the way up is now the thing holding
  you on the way down. The stack's history becomes the descent's difficulty, for free.
- **Each section comes down on the gin wheel**, one at a time, lowered rather than dropped. A
  dropped ladder is damage and money. This is the same modulate-against-gravity feel the GILD
  level's lowering sequence is built on, and it would arrive first.
- **The dogs are drawn and the holes plugged.** The trade's own last act, per
  [`16-how-it-was-actually-done.md`](16-how-it-was-actually-done.md).

And one recommendation that ties stage 3 back to stage 0:

> **Gear left up there is gear you do not own next job.** A dog you could not be bothered to draw is
> a dog missing from the van on Thursday. That single rule turns the loadout screen from a menu into
> a running account, gives the descent a reason to be careful rather than fast, and costs one
> integer in `Career`.

That is a design decision, not an implementation one, so it is **recorded in `BLOCKED.md`** rather
than acted on.

### Which archetype to build second

**CONDUCTOR** ([`05-mission-types.md`](05-mission-types.md) §B), for four reasons:

1. It *is* the descent. Its fiddly bit is paying out copper and fixing a clip every 1.5 m on the way
   down, so building it builds stage 3 as a side effect.
2. It needs no new art beyond tape, clips and an earth pit.
3. Its clip-fixing action is the hammer verb the playtest singled out as the thing that makes this
   feel like a sim — reused, one-handed, in a worse position.
4. It has a natural home for the weather clock, which is the long game's missing engine.

---

## Part 3 — Heightening the height

The playtest asked for *"other senses that you would have in real life that you can't really
communicate"* — gauges. The wind rose landed today. What is still available, cheapest first:

- **Wind on the hands.** `MeterContext` carries `windSpeed`, and *only nerve reads it*. Grip reads
  carrying, wet, gloves, cold and span — not wind, and not height. So in the game as it stands a
  gale frightens him but never numbs his fingers, which is precisely backwards from the trade, where
  wind plus height is the whole reason grip is a resource at all. The input is already in the
  struct. (Tuning decision — `BLOCKED.md`.)
- **The ground going quiet.** Town noise attenuating with height is one curve and it is the single
  most convincing altitude cue available to a game that cannot make you feel exposed.
- **Looking down.** Pillar 1 says the best image the game has is your own stack receding below you.
  Nothing currently asks the player to look at it. The cigarette-and-view hold already exists as the
  place to put that beat.
- **The horizon opening.** At 15 m you can see the yard; at 55 m the next valley. Free with the
  skybox already in the scene.

---

## What this document decides

Nothing. Every ranked item above is a recommendation to a designer, and the ones that set numbers or
choose scope are in [`BLOCKED.md`](../../BLOCKED.md). What it does claim, and will defend, is the
audit: the long game exists on paper, its ledger and its clock are unbuilt, its map is built, and a
job in this game currently has no last act.
