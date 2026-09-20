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
| **3. Striking** | Take it all down and bring it home | **Missing entirely.** The level ends when you reach the top. The trade laddered up in 2-2.5 hours and stripped back down in about **30 minutes** |

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
- **The way down is not the way up reversed.** This is the trade's own rule, and it is the best
  argument for the whole stage: ATLAS requires that a strip be re-assessed rather than assumed,
  *because the work you did on the job may have put an obstruction where there was none on the way
  up*. A game that has just made you band, gild or strip a chimney has, by construction, changed the
  route you have to come down.
- **Stand-offs work loose during removal**, and are checked *before* the lashings come off. Once a
  ladder is off its anchors **nobody goes back on it**. Nothing is dropped: anchors come down tied
  to the ladders or lowered in a container.
- **And the dogs stay in, or they do not.** This was written here first as "the dogs are drawn and
  the holes plugged — the trade's own last act". That was wrong. Across two book-length memoirs and
  some 2,600 forum posts there is **no first-hand account of drawing a dog or plugging a hole**, and
  there is direct evidence the other way: *"Some jacks with a regular contact used to leave dogs in
  place on stacks"*, and a later crew on such a stack *"had used the old dog holes and it wandered a
  bit"*. See [`18-the-trade-on-record.md`](18-the-trade-on-record.md).

  The true version is the better mechanic, because it is **a decision with a cost either way**.
  Leave them: you keep the daylight, and you leave corroding iron in someone's chimney and a set of
  holes that will pull the next man's line out of plumb. Draw them: you get your gear back, and it
  costs you the end of a shift you have already spent. The trade also knew gear does not always
  survive the trip — fixings *"have been known to break on removal (but not during use)"*.

And one recommendation that ties stage 3 back to stage 0:

> **Gear left up there is gear you do not own next job.** A dog you could not be bothered to draw is
> a dog missing from the van on Thursday. That single rule turns the loadout screen from a menu into
> a running account, gives the descent a reason to be careful rather than fast, and costs one
> integer in `Career`.

That is a design decision, not an implementation one, so it is **recorded in `BLOCKED.md`** rather
than acted on — and note it is a *game* rule, not a trade one. The trade's usual answer was to leave
them in. A faithful game prices that convenience against the state it leaves the stack in.

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

## Part 4 — What pulls, as opposed to what is hard

Raised 2026-09-20, second pass: *"what would drive you to continue completing the objectives versus
the challenge?"* — along with a well-placed doubt about whether the traction engine is really the
answer, and a note that some **lighter RPG progression** might give the game more meat without
turning it into an RPG.

### Challenge is the weakest driver this game has

Worth saying plainly, because it changes what to build. The gripping thing about being on a ladder
at 50 m is not *can I do this*. It is **exposure** — you are very high up and something might go
wrong. That is not difficulty and it does not improve by being made harder. It is renewed by the
*site*: a worse structure, a longer drop, a nastier day, less margin. Which is what
[`05-mission-types.md`](05-mission-types.md) already says when it insists difficulty comes from
context rather than from the task.

So the progression to build is not a difficulty curve. It is three things the game already half has
and does not use.

### 1. The district remembers you — the strongest idea available

Today `Career` persists money, reputation, and per job `{id, paidGbp, errorDegrees, failed}`. It
remembers **what you were paid and whether you failed**. It remembers nothing about what you
learned or what you left behind, and every joint you sounded is thrown away when the level ends.

Make the district persistent instead, and several loose threads tie together at once:

- **Your dogs are still in it.** The research says this is exactly what happened: jacks with a
  standing contract left the dogs in. Come back to Kershaw's two jobs later and there is your own
  ironwork, a bit more corroded than you left it. That makes the striking decision in Part 2 a real
  one with a *deferred* consequence rather than an immediate fee.
- **And so are your holes.** *"They had used the old dog holes and it wandered a bit"* — a stack you
  laddered badly is a stack that is harder to ladder next time, and it is your own fault, visibly,
  two hours of play later.
- **Your chalk is still on the joints you sounded.** Knowledge, made physical, in the place you
  learned it.
- **Repeat work becomes interesting rather than cheap.** `replayFeeFraction` currently just pays you
  less for a job you have done — a penalty for replaying, not a reason. A chimney you know is a
  chimney you can ladder faster, and that is a better reward than money.

This is also the trade's actual business model — the *regular contact* — and it costs one persisted
structure per level.

### 2. The work comes to you, instead of you going to find it

The best-attested progression in the whole record, and the job board is already built to carry it.

Early career, the sources are unambiguous: you go looking. Riding on the top deck of the bus
because *"he could see the chimneys better from an upstairs bus seat and he could look out for a
dodgy lightening conductor rod or broken band"*; roaming the district with binoculars; a boy of
fourteen set to **writing letters to every mill locally by hand**, and bringing in work by them.

Late career, it inverts. *"Letters from all quarters"* arrive — and one addressed simply **"To
Steeplejack, Somewhere in England"** reached its man.

That is the arc, and it is the answer to *what pulls*. Not a number going up: **becoming the one
they send for.** It is visible every time the board is opened, it needs no new system, and it is
the exact emotional shape of "competence in a vanishing trade".

### 3. The world shrinks, and the game never shows you

Already true and never surfaced. Twelve jobs in, the district has fewer chimneys because of you.
Nothing in the game says so. The credits drive past them; nothing before the credits does.

### On the traction engine

The doubt is well placed, and it is worth naming *why*: as designed it is a progress bar with a
model attached. It is bought rather than earned, and it has no connection to the skill the player
is actually building. The shape is right — the economy wants a sink, and a thing you pour money
into that does nothing useful is a very good 1970s working-man's obsession — but it is doing one
job where it could do two.

**Recommendation: keep the engine as the money sink, and let the yard fill with salvage beside it.**
A finial off a spire. A weathervane you re-gilded. A dog out of a stack that is not there any more.
None of it bought; all of it carried home from jobs you did. The engine is what you *buy*; the
salvage is what you *remember*, and it makes the shrinking world tangible in the one place in the
game where nothing is trying to kill you.

If only one of the two gets built, build the salvage.

### Where the RPG goes, and where it must not

`08-hub-and-meta.md` has a hard rule — **no skill tree; the player gets better, the character does
not** — and it should stay. But there is a lot of room between "no skill tree" and "no progression",
and a trade career is naturally RPG-shaped without a single stat:

| Progresses | How | State |
|---|---|---|
| **Who will hire you** | Reputation, stars, `reputationGate` | Built |
| **What you are carrying** | Kit, with trade-offs, never strict upgrades | Designed |
| **What you know about this district** | Persistent stacks, your own chalk and ironwork | **Not built — the big one** |
| **Who you are to people** | The board's letters changing character | **Not built — the cheap one** |
| **What you can physically do** | — | **Nothing. Keep it that way** |

The line to hold: the moment there is a dialogue tree or a number that makes his hands steadier, the
game is asking the player to roleplay someone competent instead of *being* competent. The fantasy is
knowledge, and knowledge is the one thing a player can actually acquire.

**Undecided, and recorded as such.** None of the above is a decision; the engine question in
particular was raised as a doubt, not settled. See [`BLOCKED.md`](../../BLOCKED.md).

---

## What this document decides

Nothing. Every ranked item above is a recommendation to a designer, and the ones that set numbers or
choose scope are in [`BLOCKED.md`](../../BLOCKED.md). What it does claim, and will defend, is the
audit: the long game exists on paper, its ledger and its clock are unbuilt, its map is built, and a
job in this game currently has no last act.
