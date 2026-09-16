# 06 — The Felling System

> The marquee mechanic. A spatial-planning puzzle with a forty-minute dread curve and a ten-second
> payoff. Build it at M4, not before — it depends on the topping system and on the climbing system
> being proven.

## The real technique (which is already a good game)

You do not blow a chimney up. You **cut a hole in one side of it at the base**, replacing the
brickwork you remove with timber props as you go, until the chimney is standing on a crescent of
brick at the back and a row of wooden legs at the front. Then you pack the hole with waste timber,
set fire to it, and walk away. The props burn through, the front support vanishes, and the chimney
hinges over the remaining crescent and falls — in the direction you chose, because you chose where
to put the hole.

Everything a designer wants is already in that: an irreversible commitment, a visible progress
meter that is also a danger meter, a reason to be careful, and a spectacular payoff.

---

## Act 1 — The Survey (ground level, 3–6 min)

The player walks the site with the plumb bob and a bag of pegs. No climbing, no danger, pure planning.

**What the player must establish:**

1. **The existing lean.** Chimneys are never plumb. Read it with the plumb bob from two orthogonal
   positions. The lean is displayed as a bearing + degrees, e.g. `lean 0.8° toward 118°`.
   **The chimney wants to fall along its lean.** Fighting it costs you accuracy.
2. **The exclusion objects.** Each level authors 2–5 of them, with a "value" (the chapel: catastrophic;
   the greenhouse: £14; the pub: the game will never let you hear the end of it).
3. **The drop zone.** A felled chimney doesn't land as a stick — it **breaks up and throws debris**.
   The game shows a predicted debris fan: a cone of `±18°` and `1.15 × height` in length, with a
   scatter halo. Getting the *length* right matters as much as the bearing.
4. **The fall line.** The player drives in two pegs. This is their public commitment and the thing
   they are scored against.

**Design note:** the survey is a *map-reading* activity in first person, with no overlay map. The
player must physically walk to the chapel and look back to judge the angle. There is a chalk-and-tape
**sight line** tool: stand at a peg, look at the chimney, and the game draws the line. Cheap, tactile,
and it makes the player move around the site, which is how they discover the hazards they'd otherwise
miss.

**Optional expert move:** measure the chimney's height by shadow or by pacing the sight angle. Doing
it properly tightens the predicted debris fan on the HUD. Doing it by eye leaves the fan fuzzy. A
nice reward for players who engage.

---

## Act 2 — Strip Out (climbing, 8–20 min)

Standard ascent, then:
- Remove the lightning conductor (CONDUCTOR verbs, in reverse).
- Cut the steel bands off (spanner / cold chisel).
- **Reduce the height by hand** using the TOP system if the level requires it. Shorter = more
  predictable = safer, but every metre taken by hand is 40 seconds of your daylight.
  **This is a real strategic choice and it should be presented as one at the survey:** the game tells
  you your predicted accuracy improves by ~1.5° per 5 m removed.

Act 2 exists so that a felling level is not "a puzzle with no climbing in it". It's also where the
player's relationship with the chimney becomes personal — you've been all over it before you kill it.

---

## Act 3 — The Gob (ground level, 10–20 min)

The heart of it.

### The model
The chimney base is a **ring of 32 segments × 4 courses = 128 removable cells** (angular resolution
11.25°). Each cell has:
- `mortarStrength` 0–1 (authored per level; **asymmetric on purpose**)
- `bearing` — how much vertical load it carries
- `removed` / `propped` state

Live physics readout, presented as a diegetic chalk diagram the player draws on the ground and which
the HUD then keeps updated:

```
     N
     ·                     BEARING RING
  ·     ·                  ███ intact brick
·    ✚    ·   ← CoG        ░░░ removed
  ·  ▓▓▓  ·                ▓▓▓ propped (timber)
     ▓▓▓                   ✚   centre of gravity
   FALL LINE               ○   support polygon centroid
```

### The rule the player is fighting
The chimney stands as long as the **centre of gravity stays inside the support polygon** formed by
the remaining bearing cells *plus* the props, with a safety margin.

```
margin = distance(CoG, nearest edge of supportPolygon)
SAFE     margin > 0.60 m     quiet
UNEASY   0.30–0.60 m         dust falls, low groan, mortar ticks
CRITICAL 0.10–0.30 m         loud cracking, visible movement, screen shake, debris
COLLAPSE margin < 0.10 m     it goes. Now. Wherever it wants.
```

A premature collapse while the player is *in the gob* is the game's hardest fail. It is telegraphed
for a full **6–9 seconds** by escalating audio and dust. Nobody should ever die to it without having
had time to run. (Instrument this in playtest: if anyone dies without a run window, extend it.)

### Props
- Each timber prop carries **40 kN** and counts as a bearing cell at its position.
- Props go in *behind* you as you cut: the loop is `cut two cells → set a prop → cut two cells`.
- Props can **split** under load if overloaded (>40 kN), with a bang and an instant margin drop.
  Levels can author a dud prop.
- Props are the reason you can remove far more brick than statics alone would allow — and they are
  the fuse. **Everything you rest on, you are about to set fire to.**

### The goal state
You want, at the moment of firing:
- The gob cut through the full wall thickness across an arc of **~120–160°** centred on your fall line.
- A crescent of intact brick opposite, and props across the front.
- CoG margin in the UNEASY band (that's *correct* — a chimney that feels totally safe won't fall).

The game evaluates the final state and reports a **predicted accuracy** before you light it, so the
player can keep cutting or stop. This is not hand-holding; it's the real judgement a jack makes, and
it converts the puzzle from "guess" into "optimise".

### Why this is fun
- It's a **destructive** puzzle where the pieces don't go back.
- The feedback (groaning, dust, ticking mortar) is continuous and analogue — you can *feel* the
  structure's mood.
- It has the best kind of tension: not reflex tension, but "am I sure?" tension. Players will stand
  back, look at it, come back, take two more bricks out.

---

## Act 4 — Fire, Run, Watch (2 min)

1. **Pack** the gob with waste timber and straw (a placement action — poor packing = slow burn = the
   chimney drops before the props are fully gone = worse accuracy).
2. **Light it.** Wind can kill the match; shelter it with your body.
3. **RUN.** A hard sprint to the safe line, `1.5 × height` away. The timer is the burn, 45–90 s
   depending on packing. The player has plenty of time — but the game does not tell them that, and
   the camera stays behind them. This is the only running in the game and it should be exhilarating.
4. **Watch.** Camera control is returned to the player. They can stand anywhere outside the line.

### The fall itself

**Not a free rigid-body sim.** Deterministic, pre-fractured, hinge-driven — see
[`../03-tech/adr/0002-physics-and-destruction.md`](../03-tech/adr/0002-physics-and-destruction.md).

```
1. Props burn through in sequence (authored burn order + packing quality)
2. Support polygon collapses to the rear crescent
3. Chimney begins a HINGE rotation about the crescent's centroid
   - hinge axis = perpendicular to the actual resultant of (fall line × cut, existing lean, wind)
4. Bending stress accumulates along the shaft as it rotates
   σ(h) ∝ rotationRate² × h
5. When σ(h) exceeds the authored fracture threshold at a joint band, the shaft BREAKS there
   → typically 2–4 breaks, upper section overtakes and lands beyond the base of the fall
6. On ground contact, each chunk spawns a short-lived debris burst + dust column
7. Dust plume persists ~40 s and rolls outward. Do not cheap out on the dust.
```

**Sound design is 70% of this moment.** Ten seconds of near silence, then a crack, then a long
rushing roar, then a ground thump you feel in the subwoofer, then bricks raining, then dust, then
birds, then — after four or five seconds — a distant cheer from the crowd. Then nothing. Then the
character says something modest.

### Scoring

```
Angular error  ≤ 5°           PERFECT       +£400 bonus
               ≤ 15°          GOOD          +£150
               ≤ 30°          ACCEPTABLE     £0
               > 30°          WILD          −reputation
Debris overrun  within fan                  £0
                beyond fan                  −£ per object struck
Collateral      each exclusion object hit   −£value, −reputation, possible job failure
Break-up        clean (3–4 chunks)          +£80 "she broke up nicely"
                one piece / cartwheel       −£ (harder to clear)
Salvage         bricks recovered from L5-style hand work
```

---

## Authoring a felling level

A level author sets:
```jsonc
{
  "lean": { "degrees": 0.8, "bearing": 118 },
  "mortarAsymmetry": { "bearing": 200, "strengthBias": 0.35 },  // one side is tougher
  "exclusions": [
    { "id": "chapel", "bearing": 74, "distance": 22, "value": "CATASTROPHIC" },
    { "id": "greenhouse", "bearing": 300, "distance": 40, "value": 14 }
  ],
  "propCount": 14,
  "dudPropIndex": 9,          // optional authored failure
  "requiredHeightReduction": 0,
  "safeLineDistance": 105
}
```

That is the entire per-level authoring surface for a felling. Everything else is systemic.

## The three fellings must differ

| | L6 Waterside | L7 Kershaw's Yard | L12 Great Aire |
|---|---|---|---|
| Height | 70 m | 65 m | 110 m |
| Fall corridor | 180° of open field | **28°** — chapel one side, mill the other | 40°, railway + gasholder |
| Lean | negligible | 1.4° *away* from the only safe corridor | 2.1°, and it's cracked |
| Strip-out | none | remove bands | **take 18 m off by hand first** |
| Authored twist | none — this is the tutorial felling | a prop splits at 70% | crowd control; a train timetable you must fell between |
| Feeling | "I did it!" | "I *just* did it." | "I earned that." |
