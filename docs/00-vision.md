# 00 — Vision

## One-liner

A third-person game about climbing tall industrial structures by building your own route up them,
then doing a hard day's craft work at the top — and occasionally demolishing the whole thing on
purpose.

## The fantasy

Not "I am a superhero who can climb." The fantasy is **competence in a vanishing trade**: you are a
working man with a van, a dozen wooden ladders and forty years of knowing which mortar joint will
hold. The power fantasy is *knowledge*, not strength. You look at a hundred-foot chimney, read it,
and know how to get up it.

The emotional arc of a single job:
1. **Sizing it up** — stand at the bottom, crane your neck, walk round it. A little dread.
2. **The grind up** — methodical, tactile, slowly more exposed. Concentration.
3. **The moment** — you reach the top, the wind changes, and the whole town is laid out below you.
   You brew a cup of tea on a ledge nine inches wide. Elation, vertigo, absurdity.
4. **The work** — fiddly, precise, and now the game is asking you to do fine motor work while your
   hands shake.
5. **Coming down** — either quietly satisfied, or running, because the chimney is on fire.

## Design pillars

### 1. Earned altitude
Height is the reward and it must never be free. No lifts, no magic climbing, no "hold up on a
surface". Every metre of the route exists because the player placed an anchor and lashed a ladder to
it. The consequence: **the player's progress is physically present in the world.** Looking down a
chimney at your own ladder stack, receding to the ground, is the single best image the game has.

### 2. Craft under pressure
Every job verb (hammering, tying, prising, bolting, gilding) is a real physical action with a skill
expression. None of them are hard on the ground. All of them become hard at 70 metres in a crosswind
with one hand on the ladder. **Difficulty comes from context, not from the task.** This is why we can
reuse a small verb set across twelve levels without it going stale.

### 3. Controlled catastrophe
The demolition levels invert the whole game. For an hour you've been an expert in making structures
safe. Now you use exactly the same knowledge to make one fall over, in a direction you nominated, in
front of a crowd. Long dread, short spectacle, immediate readable feedback on whether you were right.

## Anti-pillars (things we will not do)

- **No "press E to work."** If an interaction resolves without the player making a decision or an
  input that could have gone better, it is cut or redesigned.
- **No hidden dice.** Anchor quality, load, stability, wind — all surfaced honestly. The player
  should always be able to say *why* they fell. Randomness lives in the world's layout and weather,
  not in whether an action succeeds.
- **No combat, no enemies, no health bar.** The antagonist is gravity, weather, material fatigue and
  the clock.
- **No open world.** Discrete jobs from a hub. Every level is authored.
- **No gore.** Falls cut to black and a hospital ward. Grim, funny, not gruesome.
- **No stamina bar that just means "you may not run".** See [`03-meters-grip-nerve.md`](01-gdd/03-meters-grip-nerve.md).

## Tone

Warm, funny, filthy, proud. Brass bands and diesel. A whippet asleep in the yard. The humour is
deadpan and the danger is real. Think *Kes* crossed with an engineering documentary. The narrator —
your own character, muttering to himself — is affectionate about brickwork in a way that is both a
joke and completely sincere.

Setting: a fictionalised composite of Lancashire and West Yorkshire mill towns, 1976–1984. Mills
closing, chimneys coming down, the trade dying. That melancholy is the backbone: **every job you
complete successfully is a piece of the world being destroyed.** The game never says this out loud.

## Target player

Players of *Lethal Company*'s tension-without-combat, *Cook, Serve, Delicious*' verb-mastery,
*Powerwash Simulator*'s methodical satisfaction, *Jusant*'s vertical craft, and *Teardown*'s
"prepare, then unleash". Someone who enjoys being *good at a job*.

Reference points to steal from explicitly:
- **Jusant** — the feel of deliberate, effortful vertical movement.
- **Teardown** — the prepare/execute split and the joy of a planned collapse.
- **Return of the Obra Dinn** — the idea that the player's *knowledge* is the progression.
- **Papers, Please** — a shift-based loop with an end-of-day reckoning.

## Scope reality check

This is a small-team / agent-team project. It succeeds by being **narrow and deep**: one excellent
climbing system, six or seven excellent verbs, twelve handcrafted levels, stylised art. It fails if
it tries to be an open-world simulation, a physics sandbox, or photorealistic.

Non-negotiable scope guards:
- Twelve levels, authored, no procedural generation of level content.
- **One** character. No second hero asset, no customisation beyond hats.
- **No bespoke material authoring.** Everything is Megascans plus per-instance parameters. If Fab
  doesn't have it, we reconsider needing it. (See [`13-art-direction.md`](01-gdd/13-art-direction.md).)
- **All structure geometry is procedural, from JSON.** No hand-modelled chimneys, ever.
- Destruction is **pre-fractured and deterministic**, never a free rigid-body sandbox.

The art direction changed in [ADR-0004](03-tech/adr/0004-engine-change-to-unreal.md) from
flat-shaded stylisation to *photoreal where you look, stylised where you don't*. **The scope guards
did not relax — they got more specific**, because higher fidelity with no art team only works if
the geometry stays procedural and the materials stay bought.

## Definition of success

**M1 gate (the only one that really matters):** hand a stranger a grey-box chimney with no mission
and no art. If they climb to the top, look down, and say "bloody hell" — the game works. If they say
"is that it?" — the climbing system is wrong and everything downstream is wasted effort.

Do not build missions before passing that gate.
