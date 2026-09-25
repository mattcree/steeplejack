# 22 — The road to a finished game

> Written 2026-09-25, from this brief: *"there is no system really other than laddering... you've
> added features you don't even need to complete the game... Can we define the system? Where's the
> meta? ... it just needs to be a finished game or at least have a plan of how to get to a
> finished game."*
>
> [21-the-paid-game.md](21-the-paid-game.md) answered "what would someone pay for". This answers
> "what is actually missing", and it is a harder answer.

---

## 1. The diagnosis, and it is correct

**There is one system, and it is laddering.** Everything else is either a single verb bolted to one
archetype, or optional.

Every verb the player has, and whether any job in the game cannot be finished without it:

| Verb | What it does | Load-bearing? |
|---|---|---|
| **W / S** | climb | **Yes — every job.** This is the game. |
| **RMB** | drive a dog into a joint | **Yes — every job.** No dog, no stack. |
| **R** | lash a section to a dog | **Yes — every job.** |
| **F** | take gear; and the job verb for CONDUCTOR and STRAIGHTEN | **Yes**, but doing three unrelated things under one key. |
| **E** | sound a joint | **Only SURVEY.** Rewarded on TOP, ignorable everywhere else. |
| **LMB** | the topping stroke; the hammer draw in work mode | **Only TOP.** |
| **B** | pull a band bolt up | **Only BAND.** |
| **X** | dial the cut | **Only STRAIGHTEN.** |
| **Q** | change stance | **No.** Changes the grip drain. Pure optimisation. |
| **G** | rig the gin wheel and haul | **No.** Saves trips. Required only to clear a jammed flue on TOP. |
| **T / C / V** | brew up, a cigarette, look at the view | **No.** Nerve recovery. |

So: **four universal verbs, three archetype verbs used by one to four levels each, and four verbs
you can finish the entire campaign without ever pressing.** The designer's "you've added features
you don't even need to complete the game" is not a feeling, it is the table above.

### Why that is the actual problem

A trade game needs the *trade* to be the system. At the moment the trade is a costume over a
climbing game: you climb up, press the one key this level is about, and climb down. The verbs do
not combine, do not compound, and nothing you learn on job three changes how you play job nine
except that you are personally better at it.

Three specific structural gaps:

1. **Nothing persists between jobs except money and a number.** Reputation gates letters. Money
   buys ladders and gloves. Neither changes how a job *plays*.
2. **There are no other people.** No mate on the ground, no client on site, no competitor, no
   apprentice. For a game about a trade this is the biggest absence of all, and it is the reason
   the yard feels like a menu rather than a business.
3. **Content is hand-authored, one level at a time, and does not fan out.** Fifteen levels is
   fifteen levels. There is no generator, no variation, no reason to replay one.

---

## 2. What the game is actually about

Before any plan, the sentence it has to serve. From [00-vision.md](../00-vision.md):

> *"The fantasy is competence in a vanishing trade: you are a working man with a van, a dozen
> wooden ladders and forty years of knowing which mortar joint will hold. The power fantasy is
> knowledge, not strength."*

That is a good sentence and the game does not yet deliver the second half of it. Knowing which
joint will hold is currently one optional keypress with a chalk mark. **Knowledge has to become
the resource the game is played with.**

---

## 3. The game is historically inverted

Research into what the trade actually did, 2026-09-25, and the finding reframes everything:

> **The steeplejack's trade was overwhelmingly a MAINTENANCE trade, not a demolition trade.**
> Demolition was the exception that got photographed. Brick stacks needed near-constant upkeep
> because mortar fails under flue gas, rain and thermal cycling. The historical week was
> **pointing, painting and hanging ladders**.

Our fifteen levels are: three surveys, three conductor runs, two bandings, one straightening, two
toppings — and **four fellings**. Four of the six job types we model are dramatic one-offs. We
have built the photographs and skipped the trade.

That is not a historical quibble, it is why the game feels thin. A career made of set-pieces has
no texture between them, and set-pieces are the most expensive content per minute of play.

### The other absence the research names

Every job on the list had **a mate on the ground**. He ran the gin wheel, tended the rope, mixed
mortar and kept the public back. **The gin wheel is the only two-person verb in the kit** — which
means the cheapest possible way to put a second human being in this game is already half-built and
currently optional.

### And the clock the period gives us for free

The 1950s–60s cotton collapse meant stacks that had been maintained "would from now on require to
be demolished", and **there were large UK grants available for the work** — the state paid to
erase the trade's own customer base. One firm took down around sixty textile chimneys in the north
during the 1970s.

That is the game's spine and it is true: **a boom that eats the seed corn.** Good for a young man
starting out, terminal for the trade. Act one is maintenance, act three is demolition, and the
money gets better as the work gets sadder.

---

## 4. The content plan

Twelve candidate job types came out of the research. Ranked by what they add per unit of build
cost, against what we already have:

| Job | What you do | What it adds that we do not have | Cost |
|---|---|---|---|
| **Repointing** | Rake out perished joints in bands round the shaft, re-fill, iron off | **The first slow job.** Coverage over time rather than one decisive act — and progress is *visibly* a colour change on the brick, so the feedback is free | Low |
| **Hanging the ladders** | Chisel, peg, dog, lash, climb — the route IS the job | Turns our best system into an objective instead of a commute | Low |
| **Lightning conductor test** | Walk an existing run top to bottom, find the break, re-bond, test at the pit | A **diagnostic** job: the content is already-built geometry, read rather than made | Low |
| **Coating a stack** | One measured coat over the whole shell — 110 gallons, no gaps | Coverage with a **ration**. Running out is the fail state | Low |
| **Vegetation strip** | Cut buddleia and roots out of open joints on a derelict stack | Tutorial-weight, and teaches decay as a visible cause | Low |
| **Aircraft warning light** | Run cable the full height, fit and wire the fixture at the apex | An **electrical** verb; the summit is the objective, not a vantage | Low–Med |
| **Rebuilding a top** | Strip damaged courses, re-lay brick, set coping, replace capping bolts | **Construction**, not destruction — and it needs materials hoisted up, which needs the mate | Med |
| **Weathercock / finial** | Unstep it, lower it by rope, re-gild, refit and re-true | A take-down-and-**return-it** loop; a spire cannot take dogs, so it forces the bosun's chair | Med |
| **Internal flue cleaning** | Descend *inside* the shaft, break caked soot, gas-test, work off a hoist | **The hazard is not gravity.** Dark, enclosed, and the atmosphere can ignite — a real 2002 fatality had fumes burn through the hoist cables the men were standing on | Med–High |
| **Steel chimney dismantle** | Unbolt and cut flanged sections, lower them | Metal rather than masonry: different failure physics | Med |

Note what is at the top of that list. **The cheapest jobs are the ones we do not have**, because
they reuse the climb and change what you do when you get there — and three of them (repointing,
coating, vegetation) share one new mechanic: **coverage**. Do that once and you have three jobs.

### Two corrections from the research

- **"Gathering" is domestic fireplace vocabulary**, not industrial. The industrial equivalent is
  the base flue entry where the horizontal flue from the boiler house meets the shaft. Do not use
  the word.
- **Painted sign-writing on British stacks could not be corroborated** — mill names were more
  usually built in with contrasting glazed brick during construction. Treat as design licence if
  we want it.

---

## 5. The plan

*(Sections 6–9 — the system definition, the meta layer, the character and movement plan, and the
phased roadmap — are being written against research still landing. This file is committed as each
part arrives.)*
