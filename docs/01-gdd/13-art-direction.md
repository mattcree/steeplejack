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


## The rule: if it happens, it happens where you can see it

> "Basically everything you have to do should be visually happening, not just a status change,
> because otherwise it isn't very sim-like." — the designer, 23 September 2026

This is the standard every verb is held to, and it is the one this project keeps failing. The
pattern is always the same and it is never noticed by a test:

| The verb | What the sim did | What the screen showed |
|---|---|---|
| Banding | tracked twelve bolt tensions | a ring in the corner, and nothing on the chimney |
| Conductor | metered the tape, judged the wander | a number, and no tape |
| Straighten | 1.1° out of plumb, coming back over 36 hours | a perfectly upright chimney |
| Lashing | counted turns of rope | a hoop growing in diameter |
| Stance | changed the grip drain | a word in the corner |
| Profile / cap | the level said square, octagonal, finial | one round tube, every time |

A sim is not a spreadsheet with a viewport attached. The player's belief that they are doing a
real job comes from watching the job happen — the rope going round, the leg hooking through the
rungs, the shaft coming back onto itself. **A status change is not an event. If the only evidence
that something occurred is a number changing, it did not occur as far as the player is concerned.**

Three practical tests, to apply before calling a verb finished:

1. **Name the noun in the instruction.** "Stand level with a band" — is there a band? "Run the
   tape down" — is there a tape? "Hook your leg through" — does a leg hook through?
2. **Cover the HUD with your hand.** Can you still tell what just happened? If not, the verb lives
   in the HUD and not in the world.
3. **Render a frame of it.** Not of the level it is in — of the verb, mid-action. See
   [`make shot`](../06-workflow/03-verification.md) and `make ui-shot`.

## Built, September 2026 — what the surfaces actually are

Everything here is procedural and in text, for the reason the brick shader's own header gives:
binary is the half of this project agents cannot author or review.

**Brick** (`godot/shaders/brick.gdshader`). Courses and running bond off the level's own
`jointGrid`, per-brick colour, soot at the foot and bleach at the head. It now has relief as well
as colour: joints struck 5 mm deep, bricks sitting up to 2 mm proud of one another, a pitted face.
The normal is perturbed in a basis built from the interpolated normal rather than through
`NORMAL_MAP`, because the wall is unrolled by hand — the horizontal axis is distance *around* the
stack, which no UV on a tapered cylinder agrees with.

Every one of those features fades out as it drops under a pixel, at the same rate the mortar
already did. Relief that does not fade is a field of sparkle at twenty metres, which reads as a
rendering fault rather than as distance.

**Ground** (`godot/shaders/ground.gdshader`). Setts round the base, cinder over the yard, rough
grass past the wall, blended by distance from the stack with a wandering edge. The setts are
crowned and jointed, with the same relief treatment.

One octave of it is thirty metres across and never fades. That is deliberate and it is the whole
lesson of this surface: every metre-scale feature disappears by the time you are on the cap, and
the cap is the shot the game is built towards. Without a feature bigger than the view, fifty-seven
metres up you are looking at one flat olive plane — which is exactly the fault the town was added
to fix, arriving back by a different door.

**The town** (`godot/scripts/town.gd`). Terraces on a grid at the town's own angle: parallel rows,
back-to-back, 33 m from one street to the next. They used to be scattered on a random bearing,
which is fine from the ground — you see three of them — and from the cap is a heap of bricks
dropped on a field. A mill town from the air is stripes.

The index into the bank picks the slot; the generator only decides what stands in it. Placing
purely at random puts two rows through each other often enough to see.

**Timber** (`godot/shaders/wood.gdshader`). The ladder is in every frame of the climbing half of
the game and a stile is four inches from the camera for two hours at a time, and it was one flat
value of brown. Grain now, weathered towards silver, with the hard bands standing proud the way
softwood left out in a Pennine winter does.

It is drawn in the *piece's* own space, not the world's: a ladder section is a sawn length and its
grain runs down it, not down the chimney. The instance's scale comes out of `MODEL_MATRIX`'s column
lengths, so `VERTEX * scale` is the position within that piece in metres, and grain along local Y
means grain along the length of a stile and along the length of a rung from one material.

Rungs are round — a separate MultiMesh with a cylinder — and stiles are planks on edge rather than
square sections. One mesh for both had the man climbing a lattice of square sticks.

**Fixtures** (`godot/scripts/face.gd`). A dog was a 5 cm box with a smaller box across the end.
It is the object the player handles most in the whole game — every one is chosen, sounded, drilled,
driven, and later drawn — and it was a cuboid.

It is forged now: six-sided and tapered, thicker at the head where the hammer lands than at the
point, because a dog is drawn down under a hammer on an anvil and a square extrusion is the one
shape it cannot be. The lug stands up from the head rather than across it — an L, which is the
shape the rope is described as going round in
[16-how-it-was-actually-done.md](16-how-it-was-actually-done.md).

And the **wooden plug** is drawn, which it never was. That document gives the sequence as hole,
plug, dog, and says the hold comes from the plug as much as from the mortar. The game has said so
in text since the research landed and every dog in the world still appeared to be driven straight
into brick.

The rotation is baked into the mesh at build time rather than applied per instance: `CylinderMesh`
runs along Y, every fixture on this wall is placed along Z, and one `append_from` is cheaper and
harder to get wrong than a rotation on each of a hundred and thirty transforms.

**Iron bands** (`Chimney.set_bands`). A banding job is: go up, stand level with a band, pull its
bolts up in a star until she is round again. It shipped with a checklist, a ring in the HUD, a bolt
count and a verdict, and **nothing on the chimney at all**. The player was told to stand level with
a band that did not exist and tighten bolts they could not see.

Each band is now a strap round her with a bolt standing out at every lug, and **how far a bolt
stands out is how slack it is** — pulled home it is a stub, untouched it is a finger's length of
thread. That is the trick `Face.set_work` uses for a dog going in, for the same reason: a length
you can see beats a bar you have to read. The consequence is that the thing the archetype is
*about* — working round the ring pulls her oval, working across it does not — finally happens
somewhere the player can see it, as a shape on the chimney rather than a number in a corner.

The strap keeps a little sheen. Cold iron on sooty brick is two dark things, and the first thing
the checklist asks is that you *find* a band.

**The conductor run** (`Chimney.set_run`). Terminal at the apex, copper tape down the face, a
holdfast at every clip, an earth plate in a pit at the foot. Like the bands, none of it existed:
the player set a terminal that did not appear, ran a tape that was not there, and clipped it to a
wall that never showed a single holdfast.

The thing that most needed to be on the screen is the **wander**. The 1881 Code's rule is that the
run between two points may be no longer than one and a half times the straight line, and keeping
it straight is the craft — so the tape is drawn through the clips where they actually went,
laterally as well as vertically. A run that wandered looks like a run that wandered, from the
ground, for ever.

**The lean** (`Chimney.lean_offset`). Pitchcombe Mill is 1.1° over and the whole job is bringing
her back. The level file has said `leanDegrees: 1.1` since it was written and nothing read it, so
the chimney the player was sent to straighten stood perfectly plumb. The defining fact of the
level, invisible — and worse than the bands, because you judge a lean from the ground before you
ever touch her.

It is a **shear**, not a rotation of the node. Every axis stays vertical and every height stays a
height, so `chimney.global_position + chimney.face_point(h)` — which the player, the tests and
five other scripts use to find the wall — keeps working untouched. At 1.1° the difference between
shearing a shaft and tilting it is under a millimetre anywhere on it. `set_lean` moves it without
a rebuild, so she comes back onto herself while you stand and watch, which is the whole archetype.

**The site** — the works the chimney was built to draw for: a boiler house at its foot, the mill,
a saw-tooth weaving shed, a yard wall. Nothing is built across the walk in, and the gate is
wherever the walk in crosses the wall, which is the only place a gate could honestly be.

**Light.** The sky came down (its horizon was at 0.78 luminance and the HUD could not be read
against it). Ambient here is the sky, so taking the sky down takes the fill light with it, and the
first pass put the shaded face of the stack at black — half the game is spent looking at that face.
The sky stays down; the ambient energy makes the difference back up. HUD contrast is the scrim's
job, not the scene's.
