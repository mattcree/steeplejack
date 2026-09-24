# Blocked — questions waiting on a human

> One place to look. Agents append here when they set a task to `status: blocked`; the project lead
> answers. **If this file has 5 or more open rows, stop claiming new work and clear it** — the fleet
> is either guessing or idling. See [the launch procedure](docs/06-workflow/06-launch.md).

Agents: append a row, keep the detail in your task's `## Blocked` section, and pick up nothing else
until the orchestrator assigns it.

Lead: answer in the task file's `## Blocked` under **Answer:**, set the task back to `ready`, and
move the row to Resolved with the date.

## Open

| Task | Raised | The question, in one line | Recommendation |
|---|---|---|---|
| [GDD-001](tasks/GDD-001.md) | 2026-09-17 | Two nerve questions the data answers and no document does: (a) is `bellStrike` at -35 meant to be the worst shock in the game, worse than an anchor failing under you; (b) at a belted stance at the height and wind caps, nerve drains 3x faster than grip and freezes in 30 s — is nerve still the slow meter? | (a) keep the data, document the three missing shocks; (b) needs a designer — the formula and data are the GDD's own and faithfully implemented |
| [CLIMB-002](tasks/CLIMB-002.md) | 2026-09-19 | `loadShareFalloff` 0.55 puts **83.4%** of the load on the top three anchors of a 12-section stack; acceptance 2 says 78-82% and the context says 0.55 gives "about 80%". Which number is the design? | Widen the acceptance: the GDD's formula and the data agree with each other, only the range is off. If 80% is the target, 0.585 gives 80.1%. Built with 0.55 as written; nothing waits on this |
| [VERB-003](tasks/VERB-003.md) | 2026-09-19 | Acceptance 2 wants 0.65–0.75 power to beat full power at every angle error. Per strike, full power drives further below 6° (0.200 vs 0.140) and only loses past 6°, when it bends. The GDD's lesson comes from the draw (power builds while aim drifts), not the strike. Is the criterion about one strike or about play? | Restate it as a property of the draw, and test it there; the strike model is already the GDD's |
| [METER-003](tasks/METER-003.md) | 2026-09-19 | Acceptance 3 says worst-case wobble is **6x** base; the tuning gives **13.1x** (one-hand 1.6 × nerve 3 × grip 2, plus the gust). 6 is exactly grip × nerve from the GDD formula, so it looks like it predates the stance and gust terms. Which is the target? | Keep the data and restate the acceptance; the hammer test already asserts the real intent (worst wobble beats the angle tolerance) |

## Design questions raised 2026-09-20, none of them blocking

Building the felling out end to end turned up four places where a document and the arithmetic
disagree. All four are **decided and implemented** in the direction named below, with the reasoning
written where the decision lives, so nothing is waiting — but each is a design call somebody other
than the implementer should look at.

| Where | The disagreement | What was done, and why |
|---|---|---|
| [level-07](docs/02-levels/level-07-kershaws-yard.md) | The felling system doc says 40 seconds a metre for taking height off by hand; level-07 says eight metres costs twelve minutes, which is ninety seconds a metre | The system doc wins — it is the spec for the system, and 40 s is the number the game quotes the player. level-07 corrected to five and a half minutes |
| [level-07](docs/02-levels/level-07-kershaws-yard.md) | With Act 2 unpriced, taking the full allowance off the top is free accuracy, so "most of the level's strategy" is not yet a decision | Said so in the level doc rather than faking the tension. It becomes a decision when the strip-out and the ascent are priced against the same clock |
| [level-12](docs/02-levels/level-12-great-aire.md) | The failure table promises ±4° with the height reduction and ±9° without; measured through `Fell::Predict` it is **±8.0° and ±14.9°** | The model wins. Both numbers forgot that the fall line is fought through ninety-six degrees of lean, which is four degrees of cone on its own. The job is more dangerous than advertised, which is the right way round |
| The shift, across all three fellings | The most a felling can spend is 58–75 minutes of a 120–150 minute shift, so **the daylight cannot run out**, the before-dark bonus is always paid and the "the light went before you did" line is unreachable | Left as it is, and said so. Closing it means pricing Act 2's climb into the same clock, and that needs a number nobody has decided: the gob costs 28 shift-seconds a cell for 1.4 seconds of play, a fiction multiplier of about twenty, while a climb would be roughly 1:1. **How long is a game minute** is a design question, not an implementation one |
| `economy.json` vs the level set | Every felling is gated at three stars or more; doing all five levels that have data, perfectly, comes to two. The demolition half was unreachable | Kept the gates, and taught the career to tell "not earned" from "not buildable yet" (`Career::StarsAfter`). Gates above what the content can reach are marked and let through, and start enforcing themselves the moment the levels between land |

## Raised 2026-09-20 by research into the real trade

Period sources on how a chimney is actually laddered, written up in
[`16-how-it-was-actually-done.md`](docs/01-gdd/16-how-it-was-actually-done.md). One of the gaps was
a bug and is fixed (dogs were being driven 0.3-0.5 m to one side of the ladder they hold up). The
rest are design calls, and the first is large.

| The gap | The trade | The game | Recommendation |
|---|---|---|---|
| **Dog spacing** | **five feet**, every time, stated outright and never varied. **Now corroborated independently**: the modern trade standard sets a **maximum 1.55 m vertical anchor interval** and **four anchors minimum per ladder** on brick and stone. 1.55 m is five feet | 2.5-6.0 m suggested, `spanWarnMetres` 6.0, and the entire Rigid/Flex/Sway/Buckle economy built on spans the trade would not take | **Needs a designer.** Faithful spacing is ~36 dogs on the Grey Box instead of ~11: four times the actions for the same height. That is either the texture of the job or a chore, and it also invalidates the reachability gate and every level's ladder allowance. I would not change it without you. The evidence against our number is now two independent sources, a century apart, rather than one documentary |
| **Two lashings per ladder** | every ladder held at **two** dogs, and one dog splices the top of one ladder to the bottom of the next | one lashing, one dog per section | Worth doing — it is where the trade's redundancy lives, and the game's cascade is harsher than reality partly because of it |
| **The wooden plug** | hole → **wooden plug** → dog driven into the plug | dog driven straight into mortar | Worth doing: it is a second thing to get right or wrong, and it is what the dog's hold actually comes from |
| **The pulley** | **every** ladder goes up on it, leapfrogged up the stack | he carries sections on his back; the gin wheel is optional | A real change to the ascent loop. Raise as its own task if wanted |

## Raised 2026-09-20 by the long-game audit

From [`17-the-long-game.md`](docs/01-gdd/17-the-long-game.md), which audited the designed meta layer
against the built game. None of these are implementation questions; all four set scope or numbers.

| The question | Why it is yours | Recommendation |
|---|---|---|
| **Does a job have a last act?** Today the level ends when he reaches the cap. The trade laddered up in 2-2.5 hours and struck back down in about **30 minutes**, and its own standard says the strip *"is not necessarily the opposite of the installation method"* because the job you just did may have put an obstruction where there was none on the way up | It is a whole stage of every level, and it changes how long a job takes | **Build it.** It reuses every verb already shipped, run backwards on spent meters, past lashings the player rushed on the way up. Nothing else in the backlog gives that much for that little |
| **Is gear left up there gear you lose?** A dog you did not draw is a dog missing from the van on Thursday | It converts the loadout screen into a running account across the campaign, which is an economy decision | **Yes, and it is the reason striking is worth playing** — but note this is a *game* rule, not a trade one. The record has **no account of drawing a dog or plugging a hole**, and clear evidence jacks left them in on contract stacks. The authentic cost of leaving them is not to you but to the next man: corroded iron, and reused dog holes that pull his line out of plumb. Which of those two costs the game charges is your call |
| **Does wind drain grip, or only nerve?** `MeterContext` carries `windSpeed` and only `MetersNerve` reads it. Grip reads carrying, wet, gloves, cold and span — not wind, not height | It is a tuning number on the meter the whole game rests on | **It should.** In the trade, wind plus height *is* why grip is a resource. The input is already in the struct; it wants a multiplier in `climbing.json` and a number from you |
| **Which archetype is built second?** Seven of nine in [`05-mission-types.md`](docs/01-gdd/05-mission-types.md) are paper | It sets the next month of work | **CONDUCTOR.** Its fiddly bit *is* the descent, so it builds the missing last act as a side effect; it needs almost no new art; and it reuses the hammer verb the playtest singled out as the thing that feels like a sim |

One thing in the same audit is **not** a question and is worth stating plainly: every level file has
authored `shiftMinutes` and `targetMinutes` since the first one, and nothing in the climb reads
either. The day clock the meta layer needs already has its data.

### Added the same day, on progression

Raised as *"what would drive you to continue completing the objectives versus the challenge?"*, with
a doubt about the traction engine and an interest in lighter RPG-style progression. Written up in
[`17-the-long-game.md`](docs/01-gdd/17-the-long-game.md) Part 4.

| The question | Why it is yours | Recommendation |
|---|---|---|
| **Does the district persist between jobs?** `Career` remembers money, reputation and what each job paid. It remembers nothing you learned and nothing you left on the chimney; every sounded joint is discarded when the level ends | It is the difference between twelve levels and one district, and it decides what a repeat job is for | **The strongest idea on the table.** Your own dogs still in the stack, your own chalk on the joints, your own bad line making the next ascent harder. It makes striking a deferred decision, makes repeat work interesting instead of just cheaper, and is the trade's real business model — the standing contract |
| **Does the work start coming to you?** Early, a jack rode the top deck of the bus with binoculars and wrote letters to every mill. Late, letters arrived addressed to *"Steeplejack, Somewhere in England"* | It sets what the job board *is*, and the board is already built | **Do it.** Best-attested progression in the record, needs no new system, and it is the answer to what pulls: not a rising number but becoming the one they send for |
| **Is the traction engine the right carrot?** Raised as a doubt, not settled | It is the campaign's money sink and its emotional counterweight | **Keep the shape, add salvage beside it.** As designed it is a progress bar with a model on it — bought, not earned, and disconnected from the trade. A yard filling with a finial, a weathervane, a dog out of a stack that is gone costs nothing to buy and makes the shrinking world tangible. If only one gets built, build the salvage |
| **How far do the RPG mechanics go?** | `08-hub-and-meta.md` forbids a skill tree, and should keep forbidding it | **Progress standing, kit and knowledge; never ability.** The moment a number makes his hands steadier, the player is roleplaying competence instead of having it |

### Added 2026-09-21, from the production push

| The question | Why it is yours | Recommendation |
|---|---|---|
| **When does a job settle?** Reaching the cap pays you today, and `test_job_done` asserts it. Striking the stack now exists as a real stage, so a player can be paid and then spend twenty minutes bringing their gear home for no money | It decides the shape of a job, and it changes a contract the career tests already hold | **Move it to the ground**, and let what you carried home be part of what you are paid. Not done: it is scope, and the test that asserts the current behaviour is asserting a design decision rather than an accident |
| **Does the campaign get the twelve jobs in [`19-the-complete-game.md`](docs/01-gdd/19-the-complete-game.md)?** Four exist and three of those are the same archetype | It is most of the remaining content, and the order carries the whole arc | **Yes, and in that order.** The placement that matters is STRAIGHTEN at eleven — the one job where you are called to save a chimney, after ten of killing them |
| **Is STRAIGHTEN a tenth archetype?** It is real, documented and mechanically the inverse of felling | It is a new mission type, which is a month of work | **Yes.** Nothing else in the set makes the campaign mean anything different at the end than it did at the start |
| **A character modelled on a real person.** The visual push wants reference for the jack himself | Rule 16 forbids the name anywhere in this repo, and BLOCKED item 5 has the character approach open since 2026-09-16 | **Not without you.** Locations, chimneys, mills and streets are safe and are now measured up in [`20-building-the-world.md`](docs/01-gdd/20-building-the-world.md) — a trade belongs to nobody. A likeness does not, and that is a decision with a legal edge on it |

### Raised 2026-09-21 by the campaign arithmetic

**The headline one: the fifth star has never been reachable by anybody.**

Five stars wants 80 reputation. A job pays `jobCompleted` 3; `jobPerfect` 6 is paid only by a
felling graded Perfect, and a climbing job has no perfect grade at all — it always pays 3. So the
designed twelve-level campaign tops out at **3 fellings x 6 + 9 climbs x 3 = 45**, and even twelve
flawless fellings would only make **72**. The top 20% of the reputation scale is dead, every
five-star gate in the level set is unreachable by arithmetic rather than by content, and the
hundred-per-cent in [`19-the-complete-game.md`](docs/01-gdd/19-the-complete-game.md) cannot be
completed by anyone.

`test_career.cpp` now pins those figures so the numbers are visible in the suite rather than
rediscovered in a year. It deliberately does NOT assert that the fifth star is unreachable, because
that would be codifying the bug.

| The fix | What it costs |
|---|---|
| **Lower `starThresholds[4]` to about 40** | Cheapest, and keeps the five-star scale meaning "did nearly everything well". With 45 available, 40 is a real target and 80 is not |
| **Give climbing jobs a perfect grade** | Truer to the design — every archetype has a "done well" the fee does not pay for — but it is a new grading rule per archetype |
| **Raise `jobCompleted` and `jobPerfect`** | Blunt, and it makes early jobs feel cheap relative to late ones |

My recommendation is the first now and the second later: drop the threshold so the scale works
today, and give the archetypes their own perfect grades as they get built. **Not done** — it is a
number about how the whole campaign feels, and that is yours.

---

Found by asking whether the game can actually be finished, which nothing had asked before.

| The question | The numbers | Recommendation |
|---|---|---|
| **The engine is £14 clear of being unaffordable.** It costs £8,980; the nine levels that exist pay £8,994 in fees | Balanced for twelve jobs; nine shipped. Felling bonuses are the only headroom, and any damages eat it | **Build jobs 9, 10 and 11**, which is also what the fifth star needs. Failing that, `economy.json`'s `totalCost` wants dropping to about £6,500 for the content that exists — but that is a decision about how long the campaign should feel, not a number to quietly change |
| **Great Aire's five-star gate cannot be earned.** Every job that exists comes to four | The board handles it honestly — a gate nothing can reach is reported as a gap with the reason on the card, and the player is let through — so it is not a lock. But the five-star axis of a hundred per cent is unreachable | **Leave the gate at five.** It is the right number for the twelve-job campaign it was written for, and the board is already telling the truth about it. Lowering it would hide the gap rather than close it |
| **Three levels run on an archetype they were not designed for.** St Anne's ships as a conductor rather than a gild, the Corn Mill as a banding rather than a mechanism, Hollin Bank as a survey rather than a topping | They are real jobs of real types and they are not empty placeholders — but the campaign's variety is three archetypes thinner than the table says | **Fine for now, and marked as such in the table.** Each becomes its designed archetype when that archetype is built |
| **Packing** | a block under the third rung holds the ladder off the wall *so boots fit on the rungs* | not modelled; the drawn body's standoff does the same job by accident | Cosmetic but cheap, and it explains on screen why the body hangs back |

## Raised 2026-09-24, by a night on the interface and the topping archetype

Three calls the implementer should not make. Nothing is waiting on any of them — the work below
them is built and gated — but each one decides what the next month of art and feel is spent on.

| Where | The question | Recommendation |
|---|---|---|
| **The font** | The game has none. Every screen is `ThemeDB.fallback_font`, and that is most of what still makes the menus read as generic whatever else is done to them. It wants two faces: a condensed grotesque for the trade's own lettering — enamel works signage, stencil on a crate, paint on a van door — and a typewriter for the clients' letters, so the moment you see one you know somebody outside the trade is talking to you. | Pick two and put the files in the repo. I did not fetch them: shipping a typeface is a licensing decision and it is yours. Anything under the SIL OFL is safe. This is the single cheapest visual upgrade left in the project. |
| **Photoreal, or not** | The designer asked whether the game could edge towards photorealism. The environment can go a good way — the brickwork already proves it. **The character cannot**, not without a sculpt and painted maps; he is spheres, boxes and tubes with good materials on them, and materials are as far as that goes. | Do not chase it. A half-photoreal world with a primitive man in it looks worse than a coherently stylised one, and the gap between them is exactly where the eye lands. If the answer is to chase it anyway, the character has to be bought or sculpted **first**, not last. |
| **How fast he walks** | `WALK_SPEED` is 4.2 m/s — 15 km/h, a sprint, and on a **keyboard** it is the only ground speed there is, because a key is binary and `wish` is only normalised above length 1. So a sixty-year-old crosses a works yard with a five-metre ladder at a dead run. *Partly answered since this was written*: the climb now reads the left stick, so a controller gives him any pace between a stroll and that sprint, and the walk cycle built for 1.36 m/s is reachable and looks right. On a keyboard it still is not. | The top speed is game feel and it is yours. What is not a design question is that a keyboard should be able to ask for less than everything — a walk modifier, or ramping the top speed with how long you have held the key. I have not added either: a new binding is a control-scheme decision and you have said before that keyboard must not be the only way to do a thing. |

## Standing decisions the lead owes the project

These are not agent escalations — they are preflight items that nothing can proceed past.
See [`docs/06-workflow/06-launch.md`](docs/06-workflow/06-launch.md).

| # | Decision | Blocks | Status |
|---|---|---|---|
| 1 | Populate `tools/likeness_denylist.local.txt` | rule 16 is inert; ART-020 is the highest-risk task for it | ⬜ open |
| 2 | Name a human for the editor queue (10.5 days already queued) | ART-020, AUD-001, AUD-004, ENV-002, and everything downstream | ⬜ open |
| 3 | ~~Install Unreal and set `UE_ROOT`~~ | CORE-001's second half, and all of `SteeplejackGame` | ✅ closed 2026-09-17; **moot 2026-09-19** — Unreal removed from the project (ADR-0006 moved the game to Godot) |
| 4 | Enable Git LFS on the remote (CORE-010) | must land **before** the first binary asset, or history gets rewritten | 🟡 **local side done 2026-09-20.** LFS is working in the clone and `make check-assets` enforces coverage, integrity and size. The remote half is still yours: turn LFS on for the GitHub repo before pushing, or the pointers push and the objects do not |
| 5 | Character approach: commission, marketplace, or something built for Godot (MetaHuman went with Unreal) | ART-020, and therefore the whole art direction's credibility | ⬜ open |
| 6 | Budget and stopping condition for the first run | knowing when to stop, decided while calm | ⬜ open |

## Resolved

| Task | Raised | Resolved | The question | The answer |
|---|---|---|---|---|
| CORE-016 | 2026-09-17 | 2026-09-19 | Should `SteeplejackSim` use C++ exceptions, given the packaged Unreal target would not compile with them? | Moot: Unreal is removed. The sim keeps its throw-on-missing contract; the Godot binding catches at every entry point. |
| PROD-001 | 2026-09-16 | 2026-09-16 | Which engine? | ~~Unreal 5.5~~, with `SteeplejackSim` as a UE-independent C++ module. [ADR-0004](docs/03-tech/adr/0004-engine-change-to-unreal.md). *Concrete version later set to 5.8.2 during CORE-001; the answer as given on the day is left as it was.* |
| — | 2026-09-16 | 2026-09-16 | Photoreal or stylised, with no artist? | Photoreal where you look, stylised where you don't. Megascans for brick/timber/rope/metal, silhouette-and-fog for the town, one bespoke character. [Art direction](docs/01-gdd/13-art-direction.md). |
