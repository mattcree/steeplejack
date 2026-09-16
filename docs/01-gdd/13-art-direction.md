# 13 — Art Direction

## The pitch in one line

**A 1970s British industrial postcard, hand-tinted.** Stylised, flat-shaded, low-poly, with
enormous atmospheric depth and a colour palette built out of soot, brick, sodium light and rain.

## Why stylised (a scope decision, and a good one)

Photorealism is out of reach and would actively hurt us: a photoreal 110 m chimney is a grey tube.
Stylisation lets us **exaggerate the things that carry meaning** — the height, the weather, the
silhouette of a town full of chimneys — and spend nothing on the things that don't.

Reference: *Firewatch*'s flat colour planes and layered fog; *Jusant*'s clean, readable geometry;
*Kentucky Route Zero*'s use of a single light source in a dark scene; British Rail and Shell travel
posters of the 1930s–50s for the colour blocking.

## Palette

Built from four families. Everything in the game is a member of one of them.

| Family | Use | Values |
|---|---|---|
| **Brick** | the structures | `#8C4A32` `#A35C3D` `#6B3626` `#C08466` — warm, sooted at the base, bleached at the top |
| **Soot** | shadow, grime, smoke | `#2B2724` `#403A35` `#1A1715` — never pure black |
| **Sky** | mood and time of day | `#B9C9D4` (flat grey day) `#E8A86B` (late sun) `#7A8FA6` (rain) `#2E3B4E` (dusk) |
| **Sodium** | the town at dusk, the fire, the engine's paint | `#F2A03D` `#D9412E` `#3E6B4A` (engine green) |

**One accent colour, used sparingly and only for the player's own work**: a **chalk white/blue**
(`#DCE8F0`) for chalk marks, chalk lines, the survey pegs, and the load diagram. The player's
intentions are the only bright thing in the world.

## Rendering approach

- **Flat/toon shading** with a 2–3 band ramp. No PBR. No normal-mapped micro-detail.
- **Vertex colour** for brick variation; no unique-texturing of chimneys (they're 100 m tall — that
  way lies a texture budget disaster).
- **Tri-planar-ish brick pattern** via a cheap procedural fragment shader, with a per-instance seed
  for weathering, salt bloom, and soot gradient. **The brickwork must carry the joint-quality read
  visually** — this shader is a gameplay feature, and it is the single highest-value shader in the
  project.
- **Fog is the star.** Exponential height fog + distance fog, tuned per level per weather. Layered,
  slightly animated, with a visible inversion layer on cold mornings that you climb *through*. The
  moment you break out of the fog into sunlight at 60 m is a designed set-piece and it must be in
  at least two levels.
- **One directional light + one ambient gradient.** No baked GI, no lightmaps on the chimneys (they
  get destroyed). Shadows: cascaded, near-field only.
- **Dust and smoke** are the only heavy particle systems. They get the whole particle budget.

## Geometry budgets

| Asset | Tris | Notes |
|---|---|---|
| Player character | 12k | plus a 3k LOD |
| Chimney (100 m, intact) | 8k | procedurally generated from a profile curve + band list |
| Chimney (pre-fractured, 80 chunks) | 40k | only instantiated for FELL levels |
| Ladder section | 400 | instanced heavily |
| Town building (background) | 300–1,200 | ~40 unique, heavily instanced |
| Traction engine (complete) | 30k | the game's hero asset; worth it |
| Total scene | ≤ 900k tris | see performance budget |

## Procedural chimney generation

Chimneys are **generated from data, not modelled**. This is the key production decision — it means
a level designer can author a new chimney in a JSON file in ten minutes.

```jsonc
{
  "height": 70, "baseRadius": 3.2, "topRadius": 1.9,
  "profile": "octagonal",             // round | octagonal | square | square-to-round
  "batter": [{ "at": 0.0, "step": 0 }, { "at": 0.45, "step": 0.15 }],
  "bands": [{ "at": 22, "type": "iron" }, { "at": 48, "type": "iron" }],
  "cap": "corbelled-oversail",
  "weathering": { "sootTo": 0.3, "bleachFrom": 0.7, "saltBloomSeed": 41 },
  "jointGrid": { "courseHeight": 0.075, "brickLength": 0.225 }
}
```

The visual variety across 12 levels comes from profile, batter, cap type, band count and weathering
— not from bespoke modelling. **A square-to-round chimney and a plain round one look and play
completely differently** and cost the same.

## The town

Each level's backdrop is a mill town seen from increasing height. Built from ~40 instanced building
kits, a canal, a railway, and **other chimneys**. Critically:

> **Chimneys you have already demolished do not appear in later levels' skylines.**

This costs a boolean per level and it is the best storytelling in the game.

## Character

Flat cap, waistcoat, collarless shirt, heavy boots, a leather belt of tools. Silhouette must be
readable at 4 m and at 400 m. Hats are the only customisation and they are earned, not bought.

Animation priorities, in order:
1. Hand IK to rungs (highest value in the project)
2. Hammer swing (most-repeated action)
3. Weight shift / lean with wind and nerve
4. Ladder-carry gait
5. Everything else

## What we are explicitly not doing

- No character face detail (he's mostly seen from behind, at distance, in a cap)
- No unique textures on background buildings
- No PBR, no baked GI, no screen-space reflections
- No destruction beyond the authored pre-fracture
- No day/night cycle *within* a level (light changes only via the shift's daylight ramp, which is a
  simple two-key lerp)
