# 11 — Camera, Controls & Feel

## Camera

Third person, close. The character is always visible because **the character's body language is the
nerve meter**. At low nerve he hugs the ladder, moves in shorter reaches, and glances down.

| Context | Camera |
|---|---|
| Climbing | over-shoulder, 2.2 m back, 15° above, tight to the wall |
| Working (one-handed verbs) | pulls in to 1.4 m, focuses the hands, slight DoF |
| Hauling | **rotates to look down the rope.** The money shot. Free, because the player is static |
| Standing on a staging / at the top | pulls out to 4 m and drops to eye level; wide FOV |
| Tea break | locks to a slow, fixed, cinematic framing outward over the town |
| Look at the view (`hold V`) | free-look, FOV widens 8°, wind audio comes forward |
| Falling | snaps wide, time ×0.6, character centred, stack streaks past |
| The fell (act 4) | returned fully to the player. **Never take the fall away from them.** |
| The gob (act 3) | third person + a chalk load-diagram overlay on the ground |

**Camera rules:**
1. Never auto-rotate while the player is mid-verb.
2. Never clip through the chimney — always push out, never cut in.
3. The horizon must stay visible whenever the player is above 20 m. It's the height cue.
4. One optional **head-bob / breathing** layer tied to nerve, off by default for motion sensitivity.

### Selling height
Height is sold by four things, in order of effectiveness:
1. **Parallax against ground detail.** Cars, people, washing lines, a canal. Small moving things.
2. **Atmospheric perspective.** Fog density ramps with distance; the town goes blue.
3. **Audio distance.** Ground sounds get further away and more reverberant as you climb. This is the
   strongest and cheapest cue we have — see [`12-audio-design.md`](12-audio-design.md).
4. **The stack below you.** Your own ladders, receding. Make sure the camera shows this on every
   transition to a new section.

## Controls

Designed for gamepad first, fully remappable, full keyboard/mouse parity.

| Action | Gamepad | KB/M |
|---|---|---|
| Move / climb | Left stick | WASD |
| Camera | Right stick | Mouse |
| Slide down | LS down + B (hold) | S + Ctrl (hold) |
| Tool wheel | LB (hold) | Q (hold) / 1–8 |
| Primary verb (hammer, prise, haul) | RT (hold/release) | LMB |
| Secondary (tap-test, seat bolster) | RB | RMB |
| Lash (rotate) | RT hold + RS circles | LMB hold + mouse circles |
| Clip on / off | Y | F |
| Hold breath | LT | Shift |
| Look at view | D-pad up (hold) | V (hold) |
| Brew up | D-pad right | T |
| Interact / confirm | A | E |
| Load diagram (felling) | Back | Tab |

**Design note on the lash:** rotating a stick in circles is unusual and it is chosen deliberately —
it is the only input in the game that is *continuous and physical*, and it makes tying a rope feel
like tying a rope. Provide a **button-mash alternative** in accessibility options (same timing, no
rotation).

## Feel — the non-negotiables

These are the things that make or break the game and they are all cheap:

1. **Weight.** The character accelerates and decelerates. A ladder section on his back changes his
   silhouette and his gait. Nothing snaps instantly to a new state.
2. **Hand contact.** IK the hands to actual rungs. This is the highest-value animation work in the
   project — it's what makes the ladders feel real. Budget for it.
3. **The hammer.** The single most-repeated action in the game. It needs: anticipation, a real arc, a
   hard impact frame, a 2-frame hold on contact, screen-space impulse of 2–3 px, dust puff, and a
   sound with a genuine transient. Spend a week on the hammer. It's worth it.
4. **Ladder flex.** Ladders visibly bend under load, proportional to span. It's a vertex shader and
   a spring, it costs nothing, and it communicates the single most important risk number in the game
   without any UI.
5. **Wind.** Cloth on the character, a wobble in the reticle, a visible sway on long spans, and audio.
   Gusts have a **1.2 s audio pre-roll** — a rushing sound approaching across the rooftops. Learning
   this tell is one of the game's real skills.
6. **The slide down.** Fast, loud, a rush of wind, a satisfying thump at the bottom, and a small
   nerve cost. Players should love doing it. It's the reward for the climb.

## Input feel targets

| | Target |
|---|---|
| Input → visible response | ≤ 50 ms |
| Frame time (mid-range PC, 1080p) | ≤ 8.3 ms (120 fps) |
| Frame time (integrated GPU, 1080p) | ≤ 16.6 ms (60 fps) |
| Camera turn rate | 180°/s at full stick, configurable |
| Climb acceleration to full speed | 0.25 s |

See [`../03-tech/performance-budget.md`](../03-tech/performance-budget.md).
