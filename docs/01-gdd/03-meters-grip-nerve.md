# 03 — Grip & Nerve

Two meters. No health bar. Both are **about the body**, and both feed the same place: the precision
of your hands, which is what every job verb is measured on.

---

## GRIP — the short meter

**What it models:** your forearms. Seconds-to-minutes timescale.

- Range 0–100. Starts full each shift.
- **Drains** whenever a hand is off the ladder. Rate set by stance (see climbing doc table).
- **Recovers** at 25/s when standing on a rung with both hands on. Full recovery from empty ≈ 4 s.
- Below **20**: hands visibly tremble; reticle wobble ×2.
- At **0**: slip (see falling).

**Design intent:** grip is a *window*, not a resource. It says "you have about twelve seconds of
one-handed work before you must stop and hold on." It creates the rhythm of the whole game —
work, hold on, work, hold on — which is both accurate to the trade and naturally paced.

**Why it isn't a stamina bar:** a stamina bar restricts movement. Grip restricts *work*, and the
player can always buy more of it by spending time on a better stance. It converts a limit into a
decision.

### Grip modifiers
| Condition | Effect |
|---|---|
| Carrying a ladder section | drain ×1.5 |
| Wet brickwork (rain) | drain ×1.4, and slide-down disabled |
| Cold (winter levels) | max grip capped at 80 until you've worked 2 min |
| Cracked rib (injury) | drain ×1.25 for 3 jobs |
| Gloves (equipment) | drain ×0.85, but tap-test resolution -1 tier |

That last one is a lovely trade and should be in from M2.

---

## NERVE — the long meter

**What it models:** the psychological cost of exposure. Minutes-to-hours timescale. This is the meter
that makes height *mechanically* frightening instead of just visually impressive.

- Range 0–100. Starts at **90** (not 100 — you're always slightly on edge).
- Passive drain:

```
nerveDrain = BASE * heightFactor * windFactor * exposureFactor
BASE = 0.15 /s
heightFactor   = clamp(heightAboveGround / 40, 0.25, 3.0)
windFactor     = 1 + (windSpeed / 15)              // windSpeed m/s
exposureFactor = 1.0 standing on a platform
               | 1.4 on a ladder
               | 1.8 hanging free / bosun's chair
               | 2.2 out over an overhang
```

- **Shock events** (instant): dropped tool −10, near-miss/slip-save −25, anchor failure −30,
  jackdaw startle −8, a haul load swinging into you −20, seeing something fall past you −15.

### Low-nerve effects (this is the whole point)
| Nerve | Effect |
|---|---|
| 100–70 | nothing |
| 69–40 | reticle wobble ×2; hammer angle error harder to control |
| 39–20 | + camera breathing sway; audio narrows (high frequencies roll off); breathing audible |
| 19–1 | + wobble ×3, tunnel vignette, **the climb-up input occasionally hesitates** (0.3 s stall) |
| 0 | **Froze.** You cannot move up. You can only descend, or recover nerve in place. |

Nerve **never kills you directly.** It makes you worse at the job, which kills you. That's better.

### Recovery
| Action | Recovery | Cost | Requirement |
|---|---|---|---|
| Stand still on a platform | +2/s | time | a staging or the top |
| **Brew up** (tea) | +40 over 12 s | 12 s of daylight, 1 brew | stable stance, hands free |
| Cigarette | +18 over 6 s | **−5 max nerve for the rest of the shift** | any stance |
| Descend below 20 m | +1.5/s | the height you gave up | — |
| Look at the view deliberately (`hold V`) | +12 over 8 s | 8 s | must be facing outward, high up |

**The tea break is a designed set-piece, not a health potion.** It takes twelve seconds, you must be
properly stanced, the camera settles, the wind noise drops, the brass band cue comes in, and the
character says something. It is the single most characterful thing in the game and it should be worth
sitting through every time. Players will do it when they don't need it. Good.

The cigarette is the *bad* option that is always tempting: fast, works anywhere, permanently lowers
your ceiling for the shift. Classic.

The "look at the view" action is deliberately a **reward for the thing we want the player to do
anyway.** It costs time and gives nerve, and it's how we get people to actually appreciate the
vista they built a route to reach.

---

## Interaction between the two

They are deliberately orthogonal:

- **Grip** is tactical: it paces the next thirty seconds.
- **Nerve** is strategic: it paces the whole shift and punishes accumulated recklessness.

They intersect at **reticle wobble**, which is the single number that both meters feed and which
every skill-based verb reads:

```
wobbleAmplitude = BASE_WOBBLE
                * stanceMultiplier
                * gripMultiplier(grip)      // 1.0 above 20, ramps to 2.0 at 0
                * nerveMultiplier(nerve)    // 1.0 above 70, ramps to 3.0 at 0
                * windGust(t)
```

One number, four inputs, visible on screen as the literal movement of your hands. Every system in the
game pushes on it. **Do not add a third meter.**

---

## HUD

Minimal and diegetic-ish. Bottom-left, two thin arcs around the hand icon:
- Grip: a fast, responsive arc. Flashes at 20.
- Nerve: a slow arc that visibly *breathes* with the character's breathing.
- Neither is shown at full value with no threat — they fade out above 85 and when idle.

**The rest of the HUD is only:** anchor rating pips on the stack (in-world, not screen-space),
material counts (fade in when relevant), daylight bar (top edge, thin, only after 60% of the day).

No minimap. No objective marker. The objective is at the top; you can see it.
