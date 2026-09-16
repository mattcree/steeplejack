# 14 — Accessibility

**Principle: every assist is available at every difficulty, independently, with no penalty and no
comment from the game.** Difficulty and accessibility are orthogonal axes.

This matters more than usual here because the core mechanics deliberately use audio cues, fine motor
timing, and height — all of which exclude people if we're careless.

## Motion & vertigo

The game is about being very high up. This will make some people feel genuinely unwell. Take it
seriously.

| Option | Default | Effect |
|---|---|---|
| Camera sway (nerve) | **off** | the breathing/sway layer at low nerve |
| Head bob | off | |
| Time dilation on fall | on | off = instant cut to black |
| FOV | 75° | 60–100° slider |
| Vignette on low nerve | on | off |
| Reduce look-down | off | clamps pitch to −60°, softens ground parallax |
| Screen shake | 100% | 0–100% slider |
| Fall camera | cinematic | "minimal" = static camera, immediate cut |

## Audio-dependent mechanics

Every one has a visual equivalent, toggleable independently:

| Mechanic | Visual assist |
|---|---|
| Tap test | waveform pip on reticle showing the 4 tiers as distinct shapes (not colours) |
| The give (prise) | a converging bracket on the reticle; release when they meet |
| Gust pre-roll | screen-edge wind streaks 1.2 s before the gust |
| Chimney groan | the load-diagram border pulses at the margin band's rate |
| Anchor creak | the anchor pip flickers |
| Flue jam | the brick counter turns amber |

Plus a global **"Visual cues for all audio signals"** master toggle that enables the lot.

## Motor

| Option | Effect |
|---|---|
| Lash input | rotate-stick **or** button-mash **or** hold-only (auto-wraps at a fixed rate) |
| Hold-to-press → toggle | for every hold input (haul, hammer draw, hold breath, view) |
| Slip-save | window 900 ms → up to 2500 ms; or "auto-save the slip" |
| Hammer | full swing control, or "assisted angle" (removes the aim axis, keeps power+rhythm) |
| Aim assist | none / light / strong magnetism to joints |
| Sprint | hold or toggle |
| Full remapping | all inputs, both devices, including stick/button swap |

**Note:** "assisted angle" on the hammer removes one of three skill axes. It is a real assist and a
real simplification, and the game will not mention it once it's on.

## Visual

| Option | Effect |
|---|---|
| Colour-blind modes | deuteranopia / protanopia / tritanopia LUTs; **anchor ratings use shape + text, never colour alone** |
| High-contrast mode | flattens fog, brightens the player, outlines interactables |
| UI scale | 75–200% |
| Reticle | 6 shapes, 4 sizes, custom colour |
| Subtitles | on by default, size/background/speaker-name options |
| Text size | independent from UI scale |
| Font | default + OpenDyslexic |

## Cognitive

| Option | Effect |
|---|---|
| Objective reminder | a `hold` button that speaks + shows the current task |
| Load diagram always-on | for felling, rather than toggled |
| No shift timer | removes daylight pressure entirely (disables "before dark" bonus only) |
| Briefing replay | re-read the job letter at any time from the belt |
| Slow mode | global 0.5–1.0× time scale slider |

## Baseline commitments

- Fully playable with **no audio**.
- Fully playable with **one hand** (via remapping + toggles + assisted lash).
- Fully playable with **all motion options off**.
- Nothing is gated behind a reflex window that cannot be extended.
- **No flashing above 3 Hz anywhere**, including the fire and the fall.

## Testing

Accessibility is a **Definition of Done item on every gameplay task**, not a milestone at the end.
See [`../04-production/definition-of-done.md`](../04-production/definition-of-done.md).
