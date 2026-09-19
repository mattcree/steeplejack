# 13 — Art Direction

> **2026-09-19 — Unreal is removed from the project ([ADR-0006](../03-tech/adr/0006-move-to-godot.md)):** this was written for Unreal (Lumen, Megascans, MetaHuman). The look it describes is still the target; how it is reached in Godot, and with what assets, is open.

> Rewritten following [ADR-0004](../03-tech/adr/0004-engine-change-to-unreal.md). The previous
> version targeted flat-shaded low-poly. This one targets the key art.

## The pitch in one line

**A photographed brick chimney at arm's length, and an industrial North of England dissolving into
haze behind it, at golden hour.** Photoreal where you look, stylised where you don't.

## The governing principle

> **Spend fidelity where the gameplay needs it. Stylise where you'd otherwise need an artist.**

This is not a compromise — it is how the project reaches the key art without an art team, and it
happens to align exactly with where the player's attention is.

| Distance | Treatment | Why |
|---|---|---|
| **0–3 m — the brickwork** | Full photoreal. Scanned Megascans materials, parallax occlusion, real displacement on mortar joints. | **This is where gameplay information lives.** Joint quality is read here. It must be legible. |
| **3–30 m — the structure, ladders, staging, tools** | Photoreal materials on simple procedural geometry. | The player's hands and work happen here. |
| **30 m–horizon — the town** | Silhouette, atmospheric haze, emissive windows, minimal geometry. | It is already 90% fog in the key art. Nearly free, and it's what sells height. |
| **The sky and the light** | The biggest spend after the brickwork. | 80% of why the key art works is lighting and atmosphere, not material fidelity. |
| **The character** | The one bespoke hero asset. | Cannot be procedural or scanned. See "The single point of failure". |

## Materials — where the look comes from

Fab / Megascans, used directly, no bespoke authoring:

| Surface | Source | Gameplay job |
|---|---|---|
| Fired brick, ×6 weathering states | Megascans | **carries the four joint tiers** |
| Lime mortar, sound / eroded / perished | Megascans + a blend mask | the tap-test read, visually |
| Salt efflorescence | overlay layer | the salt-bloom band — mortar that *looks* perished and isn't |
| Soot | vertical gradient overlay | the chimney is dirtiest at the bottom |
| Gritstone (spire levels) | Megascans | |
| Weathered timber (ladders, props, staging) | Megascans | |
| Hemp rope | Megascans + a bespoke normal | |
| Wrought iron, rusted | Megascans | bands, dogs, tie rings |
| Concrete, spalled and delaminated | Megascans | Level 10 |

**The brick master material is the single most important asset in the project.** It is one layered
material with per-instance parameters for weathering, soot gradient, salt bloom, erosion and
cracking, driven from the level JSON's `weathering` block and from per-joint quality. It is both the
look *and* the gameplay read, and it deserves a dedicated look-dev task (ART-010).

## Lighting and atmosphere

This is where "big graphics" actually comes from, and it is cheap.

- **Lumen** global illumination and reflections. The bounce light off a brick face into the
  character's underside is most of what makes the key art feel photographed.
- **One key light** (the sun), a sky light, and nothing else in most scenes. The industrial North
  is an overcast-or-golden-hour place; both are single-source.
- **Volumetric fog**, layered, with a controllable **inversion layer** you can climb through. The
  break-out-of-the-fog-into-sunlight moment is a designed set-piece for two levels and it is a
  volumetric fog parameter, not an art asset.
- **Atmospheric perspective is a gameplay system.** Fog density is per-level and per-weather, driven
  from data, because it is how the player reads their own altitude.
- Smoke from working chimneys: Niagara, one system, instanced. The key art's chimney forest is
  mostly this.
- Time of day is a **two-key lerp across the shift**, not a full cycle.

## Geometry

Simple, procedural, and almost entirely generated from JSON. This is what keeps twelve levels
affordable at this fidelity.

| Asset | Tris | Source |
|---|---|---|
| Chimney (100 m, intact) | 25k | procedural from a profile curve |
| Chimney (pre-fractured, 80 chunks) | 120k | Chaos Geometry Collection, baked offline |
| Ladder section | 1.5k | one mesh, instanced |
| Staging / props / tools | 1–4k each | ~20 assets total |
| Town building kit | 2k each | ~40 pieces, heavily instanced, LOD to silhouette by 200 m |
| Character | 60k | the hero asset |
| Traction engine (complete) | 120k | the second hero asset, and it is worth it |

Nanite on the structures and the town; it is close to free for static geometry at this scale and it
removes the LOD authoring burden entirely — which matters a lot when there is no artist.

## The town

Instanced kit pieces, placed procedurally from a seed, resolving to silhouette-plus-emissive-windows
beyond ~200 m. Canal, railway, viaduct, and **other chimneys** — the chimney forest is the game's
signature image and it costs one instanced mesh and a Niagara smoke system.

> **Chimneys you have already demolished do not appear in later levels' skylines.**

Still the best storytelling in the game, still costs a boolean per level.

## The single point of failure: the character

Everything else here is procedural, scanned, or instanced. The character is none of those.

At this fidelity a mediocre character standing next to a scanned brick wall looks *worse* than a
stylised one, because photoreal has no tolerance for inconsistency. So the character must be
genuinely good, and it is the one place to spend real money or real weeks.

Options, in order of preference:
1. **MetaHuman**, customised. Fast, high quality, integrates with Control Rig, and — relevant here —
   a generated face carries no likeness risk. See [the IP policy](../05-legal/ip-and-likeness.md).
2. **A commissioned character**, ~£500–2,000 and 3–4 weeks.
3. Marketplace base mesh, heavily retextured. Last resort.

Brief: a Northern English steeplejack in his sixties. Flat cap, collarless shirt, waistcoat or
overalls, heavy boots, a leather tool belt, rope over one shoulder. Readable in silhouette at 4 m
and at 400 m. **Briefed from a description, never from a photograph of a real person.**

Clothing needs to move — Chaos Cloth on the jacket and cap. Wind is a mechanic and the character is
how the player sees it.

## Palette

Unchanged from the original direction; it survives the fidelity change intact because it was always
about light, not shading.

| Family | Use | Values |
|---|---|---|
| **Brick** | the structures | `#8C4A32` `#A35C3D` `#6B3626` `#C08466` |
| **Soot** | shadow, grime, smoke | `#2B2724` `#403A35` `#1A1715` — never pure black |
| **Sky** | mood and time of day | `#B9C9D4` flat grey · `#E8A86B` late sun · `#7A8FA6` rain · `#2E3B4E` dusk |
| **Sodium** | town at dusk, fire, engine paint | `#F2A03D` `#D9412E` `#3E6B4A` |

**One accent, used only for the player's own work:** chalk white-blue `#DCE8F0` for chalk marks,
sight lines, survey pegs and the load diagram. The player's intentions remain the only bright thing
in the world.

## What we are explicitly not doing

- **No bespoke material authoring.** If Megascans doesn't have it, we reconsider needing it.
- **No unique texturing.** Everything is tiling materials plus per-instance parameters.
- **No hand-placed level geometry.** Still true, still non-negotiable — it is what makes 12 levels
  affordable. See [`../../AGENTS.md`](../../AGENTS.md).
- **No second hero character.** The client, the crowd and the lad are distant, small, or offscreen.
- **No interiors** beyond the two tower levels' stairwells.
- **No ray-traced path tracing mode.** Lumen is the ceiling.
- **No destruction beyond the authored pre-fracture.** [ADR-0002](../03-tech/adr/0002-physics-and-destruction.md)
  is unchanged and is now easier to satisfy, not harder.
