# 04 — Tools & Verbs

Small verb set, deep contexts. **The game introduces no new verb after Level 4.** Everything later is
a new *situation* for a verb the player already owns.

## The tool belt

Eight slots, radial-selected. Loadout chosen at the van; you cannot go back down for a forgotten tool
without losing the daylight (which is a real and painful choice — leave a slot for the unexpected).

| Tool | Verb | Used in | Condition matters? |
|---|---|---|---|
| **Claw hammer** | tap-test, dog-in, general persuasion | everything | yes — a loose head adds angle error |
| **Bag of dogs** | anchors | everything | no (consumable) |
| **Rope & lashings** | lash, safety line, lower | everything | yes — frayed rope has a fail chance under shock |
| **Gin wheel** | haul | everything | no |
| **Bolster & lump hammer** | prise brick | topping, felling | yes — a blunt bolster doubles snap chance |
| **Spanner roll** | bolts, bands, clock gears | banding, repair, lattice | no |
| **Bosun's chair** | free-hands stance | gilding, banding, repair | yes — webbing wear |
| **Plumb bob & tape** | measure, verify vertical | banding, gilding, felling survey | no |
| **Gilding kit** | gold leaf, size, burnisher | gilding only | consumable |
| **Copper tape & clips** | conductor runs | conductor only | consumable |
| **Matches & waste** | fire the props | felling only | consumable |
| **Flask** | brew up | everywhere | refilled at the hub |

Twelve items, eight slots, four are mission-specific. **The loadout puzzle is real**: on a felling
job you must carry the bolster, the props kit, the plumb bob, the matches, plus hammer/dogs/rope/gin
wheel — that's the whole belt, no flask. Do you drop the plumb bob and eyeball the fall line?

## Verb specifications

### TAP-TEST
- Input: tap `T` while aiming at a joint within 2.5 m.
- 0.8 s. Plays one of four sounds; shows a 0.6 s waveform pip on the reticle.
- **Cheap on purpose.** Players should tap constantly. Make the animation snappy and the sound
  gorgeous. This is the game's ASMR.

### DOG-IN
Fully specified in [`02-climbing-system.md`](02-climbing-system.md) §2.

### LASH
- Input: hold RT; rotate the right stick (or mouse in circles) to wrap. Each full rotation = one wrap.
- A **tension arc** fills with each wrap and decays if you pause.
- 3 wraps = quick hitch (holds, but the ladder drifts 2–4 cm under load per minute — over a long job
  it walks off the anchor). 6 wraps = proper lashing + frapping turns, immovable.
- Tie off with a button press; mistiming leaves a slipping knot (visible, fixable).
- **Skill expression:** smooth continuous rotation is much faster than jerky. Feels physical.

### HAUL
Fully specified in [`02-climbing-system.md`](02-climbing-system.md) §4.

### PRISE (bolster & lump hammer)
The topping/felling verb. See [`07-topping-system.md`](07-topping-system.md).
- Two-stage: **seat** the bolster in a joint (aim), then **drive** it (rhythm), then **lever** it
  (a resistance meter: push into resistance, release at *the give*).
- The give is a haptic/audio event, not a visual one. You learn to feel it. Release early: nothing
  happens, wasted 1.5 s. Release late: **the brick snaps** — rubble instead of a saleable brick, and
  a chance the fragment jams the flue.

### BOLT (spanner roll)
- Aim at a nut, hold to turn. Nuts have **seizure**: rusted nuts need shock (a hammer tap first) or
  they round off. A rounded nut is a permanent obstacle requiring a workaround (cut it, or re-route).
- Long bolting sequences at height are a grip endurance test: 6 bolts × 4 s each = you must stance.

### MEASURE (plumb bob & tape)
- Roll the tape round a chimney: walk laterally with the tape held, on ladders, all the way round.
  This is how re-banding forces **circumferential traversal** — you re-dog sideways, which is slower
  and scarier than going up because you're moving away from your own stack.
- Plumb bob: hold still and let it settle (nerve/wind make it swing). Reads out-of-vertical in degrees.
  Used to verify a re-seated weathervane, or to confirm the lean of a chimney before felling.

### GILD
- Three sub-steps, all fine-motor, all wobble-sensitive:
  1. **Size** — brush adhesive evenly (coverage meter; over-application runs and ruins).
  2. **Leaf** — gold leaf is weightless and the wind will take it. **Hold breath** (`hold LB`) to
     freeze wobble for 3 s at a cost of grip; place the leaf in that window.
  3. **Burnish** — rub in small circles, coverage meter again.
- Deliberately the fiddliest thing in the game, performed at the highest, most exposed point, with a
  finite supply of leaf. Each wasted leaf is money.

### FIRE
- Lay waste timber, strike a match (wind can blow it out — shelter it with your body by positioning),
  confirm. Then **run**. Distance-to-safety is a real sprint with a real timer.

---

## Tool condition & the hub

Tools degrade with use. Condition 0–100, shown as a simple worn/serviceable/sharp state.

| Tool | Degrades on | At poor condition |
|---|---|---|
| Hammer | every strike | +40% angle error |
| Bolster | every prise | +100% snap chance |
| Rope | every lash & every shock load | 8% fail chance under shock |
| Bosun's chair | time spent hanging | webbing creaks; 2% catastrophic |

Maintenance is a hub activity: sharpen, re-shaft, splice, replace. It's cheap in money and cheap in
time, but the player must *notice*. A pre-job **kit check** screen surfaces it (and can be skipped,
which is the point).

**Do not make maintenance a minigame.** It's a click. The interest is in whether you bothered.
