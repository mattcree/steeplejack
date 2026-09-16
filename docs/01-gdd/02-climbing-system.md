# 02 — The Climbing System

> This is the spine of the game. If this document is wrong, nothing else matters.
> Budget: 40% of all engineering effort. Prototype it first, in grey box, with no mission attached.

## Design problem

Climbing a 90-metre chimney is, mechanically, one action repeated twenty-five times. Every climbing
game solves this by making the *surface* interesting (handholds, routes, puzzles). We can't: a
chimney is a smooth featureless cylinder of brick. That looks like a disaster.

It is actually the opportunity. **The route is not in the world. The player brings it.** The
steeplejack's real technique — hammering steel dogs into mortar joints and lashing wooden ladders to
them, one at a time, standing on the last one — is already a better climbing mechanic than most
games invent from scratch. It is construction, resource management, material-reading and nerve, all
performed in the most exposed place imaginable.

## The verbs

| Verb | Input | Duration | Cost | Skill expression |
|---|---|---|---|---|
| **Climb** | hold forward on an existing ladder | fast (1.6 m/s) | grip trickle | none — deliberately free |
| **Slide down** | hold back + crouch | very fast (6 m/s) | heat, risk | releasing before the join |
| **Tap-test** | tap `T` at an aimed joint | 0.8 s | nothing | interpreting the sound |
| **Dog in** | hold-and-release hammer swings ×3–5 | 6–12 s | 1 dog, grip | rhythm + angle + depth |
| **Haul** | hold, steer with stick | 8–20 s | daylight | swing control |
| **Lash** | rotate stick, hold tension | 4–12 s | rope | wrap count vs. time |
| **Clip on** | tap, at a rated anchor | 3 s | nothing | remembering to |
| **Pack / shim** | place a wedge behind a ladder foot | 4 s | 1 shim | reading the batter |
| **Traverse** | sideways re-dogging | per anchor | double dogs | route planning |

Nine verbs. All of them are used from level 1. The game never adds a verb after level 4 — it adds
*contexts*.

---

## 1. Reading the brickwork

### Joint quality
Every chimney face is authored as a grid of **mortar joints** (roughly one candidate joint per
0.25 m² of face). Each joint has a hidden `quality` in `[0,1]` and a visible `condition` tier:

| Tier | quality | Visual tell | Tap sound | Anchor result |
|---|---|---|---|---|
| **Sound** | 0.70–1.00 | crisp joint, even colour | sharp *ring*, short decay | Sound anchor likely |
| **Fair** | 0.40–0.69 | slight erosion, dark staining | flatter *knock* | Fair anchor likely |
| **Perished** | 0.15–0.39 | sandy, recessed, moss, white salt bloom | dull *thud*, long dead decay | Poor anchor |
| **Cracked** | 0.00–0.14 | hairline through the brick, spalled face | *rattle* / buzz | never anchor — always fails |

**The visual tell is deliberately unreliable at distance.** From 3 m the player can narrow it to two
tiers; only the tap test disambiguates. This is the core "read the material" skill and it is why
the tap test must be a fast, cheap, satisfying action the player does *constantly* — a little
percussive punctuation to the whole ascent. Make it feel good. It is the game's signature sound.

### Audio is a mechanic, not a garnish
The four tap sounds must be distinguishable **on laptop speakers, in mono, at low volume**. Design
them on the attack and decay envelope, not on timbre alone:
- Sound: bright transient, ~120 ms decay
- Fair: softer transient, ~200 ms
- Perished: no transient, ~400 ms, low-passed
- Cracked: transient plus a secondary rattle at ~40 ms

A colour-blind-safe and deaf-accessible **visual waveform pip** appears on the reticle for players
who need it (on by default at Assisted difficulty, toggleable at any difficulty — see
[`14-accessibility.md`](14-accessibility.md)).

---

## 2. Dogging in — the hammer

A **dog** is a forged steel spike with a lug. You drive it into a mortar joint; the ladder lashes to
the lug.

### The interaction
Not a timing bar. A **swing rhythm with three axes of skill**:

1. **Power** — hold LMB to draw the hammer back; a pendulum arc builds. Release to strike. Power is
   the arc length at release (0–100%).
2. **Angle** — the reticle drifts while you hold (nerve/grip-dependent wobble). Angle error is the
   reticle's offset from the dog's head at the moment of release.
3. **Depth** — a persistent per-dog value 0→100%. The dog is seated at ≥80%.

Each strike resolves:

```
strikeQuality = clamp(1 - angleError/MAX_ANGLE, 0, 1)
depthGain     = power * strikeQuality * jointSoftness   // soft mortar takes the dog faster
bendRisk      = power * (1 - strikeQuality)             // hard swing, bad angle = bent dog
spallRisk     = power * (1 - jointQuality) * depth      // over-driving a weak joint splits the brick
```

Outcomes the player learns to feel:
- **Soft mortar takes the dog easily but holds it badly.** Fast to seat, Poor rating. The trap.
- **Sound mortar resists.** Needs 5–6 solid strikes. Slow but gives you a Sound anchor.
- **Full-power swings are wrong most of the time.** 60–75% power with a clean angle out-performs
  100% power. Discovering this is the first real "I'm good at this now" moment.
- **A bent dog is gone.** Costs material, costs time, and costs nerve (-5).

### Anchor rating
On seating, the anchor gets a rating computed from joint quality, final depth, and spall damage:

| Rating | Static capacity | Behaviour |
|---|---|---|
| **Sound** | 5.0 kN | Holds everything. Green pip. |
| **Fair** | 2.5 kN | Holds static load. Fails under repeated shock. Amber pip. |
| **Poor** | 1.0 kN | Holds *you standing still*. Fails when you step up hard. Red pip. |
| **Failed** | — | pulls immediately, ladder drops |

Player + gear static load ≈ **1.2 kN**. A hard step-up or a slip is a **×2.5 dynamic factor**.
So: a Poor anchor is a coin-flip every time you move on it, a Fair anchor is fine if you're gentle,
a Sound anchor is forgotten about. **The player is always told the rating.** No hidden dice.

### Load sharing — why old mistakes matter
Load distributes down the stack with an exponential falloff. The top 3 anchors take ~80%:

```
share(n) = 0.55 ^ n     // n = anchors below the top, normalised
```

Consequence: the Poor anchor you accepted at 20 m is nearly unloaded once you're at 60 m — but if an
anchor *above* it fails, the shock redistributes downward and that old sin can cascade. **Progressive
stack failure is the game's most dramatic event** and the player should always be able to trace it.
On a cascade, the HUD flashes each anchor as it goes, bottom of screen, like a fuse burning.

---

## 3. Ladders — the resource

- Section length **5.0 m**, minimum overlap **1.0 m** → **4.0 m effective rise per section.**
- A section weighs 18 kg. You carry **one** on your back while climbing (slows you 30%, blocks
  sliding). Everything else comes up on the gin wheel.
- Loadout is chosen at the van. Bring too few and you don't reach the top. Bring too many and you
  spend the morning hauling.

### Spans and flex
Distance between consecutive anchors is the **span**. Longer spans = fewer anchors = faster and
cheaper, but the ladder flexes.

| Span | Effect |
|---|---|
| ≤ 4.0 m | rigid, no penalty |
| 4.0–6.0 m | visible flex, ladder bounces as you climb, grip drain +30% |
| 6.0–8.0 m | heavy sway, nerve drain ×2, anchors see ×1.4 dynamic load |
| > 8.0 m | **buckle** — the section bows and fails within ~8 seconds of being loaded |

This one table is the entire risk/reward economy of the ascent. It is tuned in one place
(`data/tuning/climbing.json`) and it should be the first thing playtested.

### Ladder condition
Sections take wear. A cracked stile shows a visible split and halves the buckle threshold. You can
**inspect** a section in the hub and repair it for £4 — or take it up and find out. Wear is
persistent across jobs. This gives the hub something real to do.

---

## 4. Hauling — the gin wheel

A pulley lashed to your top anchor. Rope to the ground. Everything heavy comes up this way: ladder
sections, steel bands, tool bags, the weathercock.

- Hold to haul. A **swing meter** shows the load's pendulum amplitude.
- Hauling faster adds amplitude. Amplitude past a threshold and the load **fouls** — snags on a
  band, swings into the brickwork (damage), or hits you (nerve -20, grip -40).
- Steer with the stick to damp the swing, in antiphase. It is a small, physical, learnable skill and
  it is the game's quiet moment — you're standing still, 60 m up, gently pulling a rope, watching
  something heavy rise out of the yard.
- **The haul is where the camera does its work.** Default camera during a haul looks *down the rope*.
  This is the shot that sells the height, and it's free because the player isn't moving.

## 5. Grip, and why climbing is free but working is not

Climbing existing ladders costs almost nothing. The moment you take a hand off to do a job, the
**grip** meter starts draining. Every task therefore has a natural window, and the player's real
choice is: *do I rush this one-handed, or spend 8 seconds rigging a proper stance?*

Stances, from worst to best:

| Stance | Set-up | Grip drain | Wobble | Notes |
|---|---|---|---|---|
| **One hand on rung** | 0 s | 8 /s | ×1.6 | the default; reckless |
| **Hooked leg** | 1.5 s | 4 /s | ×1.3 | free, needs a rung gap |
| **Clipped safety line** | 3 s | 4 /s | ×1.2 | you survive a slip |
| **Belt round the stack** | 5 s | 1 /s | ×1.0 | both hands free; can't move |
| **Bosun's chair** | 20 s rig | 0 /s | ×0.8 | full freedom, can be raised/lowered, only worth it for long jobs |

**This table is the difficulty dial for the entire game.** Level design controls difficulty by
controlling how much time pressure the player is under, which controls which stance they can afford.

See [`03-meters-grip-nerve.md`](03-meters-grip-nerve.md) for the full meter spec.

---

## 6. Falling

The player *will* fall. It must be readable, survivable-feeling, and never a save-scum.

### The slip-save
When grip hits zero, or an anchor fails under you, you get a **slip**: one hand catches, camera
lurches, a 0.9-second window to mash the grab input. Success → you're hanging one-handed, grip at
15%, nerve -25. Failure → fall.

The slip-save budget is **one per 60 seconds** of in-level time. This prevents it being a crutch and
makes the second slip genuinely terrifying.

### The fall
- If **clipped on**: you drop to the end of the safety line, shock-load that anchor (×2.5 — it may
  itself fail, which is the grimmest moment in the game), swing, nerve -50, and climb back on.
  This is what the safety line is *for* and it should feel like a reprieve you earned by spending 3s.
- If **not clipped**: you fall. Camera goes wide, time dilates ~40%, the ladder stack you built
  streaks past you in reverse, and it cuts to black before impact.

### The consequence
**Not a restart.** The shift ends. You wake in a hospital ward, an ironic voice-over line, and:

- The job is **unfinished but not undone** — your ladder stack is still up there.
- You lose the day's fee and take a reputation hit.
- You return the next in-game day and resume **from your existing stack**, with whatever material you
  had left on the ground.
- **Injuries are persistent for 2–3 jobs**: a cracked rib raises grip drain 25%; a bad ankle removes
  the slide-down. Stacking injuries is the real punishment.

### The ladder stack is the checkpoint
No save points. No flags. **Your progress is the structure you built.** This unifies mechanic and
system perfectly, it's readable without any UI, and it means "checkpointing" costs the player
material and time — exactly the pressure we want. Serialise the stack, not the player.

---

## 7. Alternative movement sets

Two levels break the ladder loop entirely so that returning to it feels fresh:

- **Steel lattice** (Level 11): you climb the structure directly — hand-over-hand on angle iron,
  with a `lanyard leapfrog` (two clips, always one attached). Fast, three-dimensional, and the
  danger is *not* the route, it's the ninety metres of nothing underneath it.
- **Shaft descent** (Level 12b / side job): you go *down*, on a rope, shoring the sides as you go.
  Inverts nerve (darkness instead of exposure), inverts hauling (you send spoil up).

Both reuse grip/nerve/tools unchanged. Neither gets new UI.

---

## 8. Tuning targets (first playtest values)

```jsonc
{
  "climbSpeed": 1.6,           // m/s on an existing ladder
  "slideSpeed": 6.0,
  "ladderLength": 5.0,
  "ladderOverlap": 1.0,
  "spanSoft": 4.0, "spanWarn": 6.0, "spanDanger": 8.0, "spanBuckle": 8.0,
  "playerLoadKN": 1.2, "dynamicFactor": 2.5,
  "anchorKN": { "sound": 5.0, "fair": 2.5, "poor": 1.0 },
  "loadShareFalloff": 0.55,
  "dogSeatDepth": 0.8,
  "hammerMaxAngleErrDeg": 12,
  "slipSaveWindowMs": 900, "slipSaveCooldownS": 60
}
```

## 9. What we must prove at the M1 gate

1. Does a 55 m ascent, with no mission, played by a stranger, produce a *reaction* at the top?
2. Is the anchor loop still interesting at anchor #12? (If not: bands are not varied enough, or the
   loop is too long — cut seconds, not steps.)
3. Can a player articulate *why* they fell, every single time?
4. Does anyone voluntarily take the risky span?

If (4) is no, the reward for speed is too weak and the whole economy needs re-tuning before we build
anything else.
