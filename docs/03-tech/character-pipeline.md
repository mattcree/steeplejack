# The character pipeline — what we have, what it cannot do, and what to buy

> Written 2026-09-24, answering: *"for the model + animation we clearly need to draw on more
> knowledge than you have in your model — can you figure out what we need to reach out to?
> Definitely using Blender was an upgrade but I wonder if we can start from an almost finished
> base to help."*

## Where we are

`tools/blender/build_character.py` builds the whole man from primitives — ellipsoids, boxes and
tapered tubes — welded into 21 parts, weighted to a 21-bone rig by distance, and exported as a
`.glb`. 9,960 triangles. Three clips, plus the climbing poses that `climb_clip.gd` bakes at
runtime.

**The principle it exists to protect** is in its own docstring: *"Nothing here is hand-modelled, so
a change to the character is a diff someone can read, and it can be rebuilt from nothing."* That
has been worth a great deal — the rig, the proportions, the gait and the clothing have all been
changed dozens of times by editing numbers, and every change is reviewable.

**It has hit its ceiling, and the ceiling is topology.** A body assembled from separate primitives
has no continuous surface: shoulders are spheres that read as ball joints, hands are mitts with
tube fingers, the head is a sphere with a nose stuck to it. Materials fixed the *surface* (see
`godot/shaders/worn.gdshader`) and they cannot fix the *form*. Adding more primitives makes it
lumpier, not more human — that was tried twice, 5,696 → 9,128 → 9,960 triangles, and the verdict
from play each time was "just shapes".

## The constraint that decides the answer

`make character` runs Blender with **`--factory-startup`**. That is deliberate: it means the model
builds identically on any machine regardless of what add-ons the operator happens to have. It also
means **any add-on-based generator is out** — MPFB2 (MakeHuman for Blender) is the obvious
candidate and it cannot be loaded under `--factory-startup` without either dropping the flag or
vendoring the add-on into the repo and importing it as a module.

So the realistic options are: a **base mesh file committed as an asset**, or a **person**.

## Option 1 — a CC0 base mesh, committed, fitted by the script

The script keeps doing the rig, the weights, the clothing, the proportions and all three clips. It
gains one input: a body.

| Source | Licence | Shape | Notes |
|---|---|---|---|
| **Blender Studio Human Base Meshes** | CC0 | male/female, clean quad topology, built for sculpting and rigging | The best fit. From the people who make the tool, no account needed for the CC0 bundle, and the edge flow is made for exactly this. |
| **MakeHuman** output | CC0 (assets since 1.1) | parametric, any build | Generate once in the GUI, export, commit. The parameters are not a diff, but the output is stable. |
| **Mixamo** | Adobe account; redistribution terms are not clean | rigged + a large clip library | Fine to prototype with, not to ship without reading the terms. |
| **Quaternius / Kenney** | CC0 | stylised, low-poly | Wrong register for this game. |

**What it costs us:** the body stops being a readable diff and becomes a binary asset, like the
`.glb` already is. Everything else stays script-driven. I think that is the right trade now — the
principle was protecting something we can no longer get.

**What it does not solve:** a base mesh is a *neutral* body. He still needs a face that is a
particular sixty-year-old man, hands that are a bricklayer's, and clothing that drapes. That is
sculpting, and it is the next paragraph.

## Option 2 — a person, which is what the question was really asking

This is one commission, not a team. What to ask for, in the order it matters:

1. **A sculpted, retopologised, textured character.** ~8–12k triangles, one material set, hand-
   painted or baked albedo/normal/roughness. Brief: a Northern English steeplejack in his sixties,
   flat cap, collarless shirt, waistcoat, moleskin trousers, heavy boots, leather belt. He must
   read in silhouette from 40 m. **Designed from that description, not from photographs of a real
   person** — see `docs/05-legal/ip-and-likeness.md`.
2. **Rigged to our bone names**, which are fixed and documented in `build_character.py`'s docstring
   and in `docs/03-tech/interfaces.md`. `rung_grip.gd` solves four IK chains by those names and
   `climb_clip.gd` aims the hammer arm at them; a rig with different names breaks the game.
3. **Clips**: idle, walk, run, and — the one nobody has — a **climb**. We bake the climb from
   poses at runtime because the model has never had one.

**Where to look:** ArtStation's hiring boards, Polycount, and Blender Artists' paid-work forum. A
character artist who lists "game-ready character + rig" is the search. Expect a real quote; this is
a week or two of somebody's time, and it is the single largest quality jump available to the
project.

**What to send them:** this file, `docs/01-gdd/13-art-direction.md`, the bone contract, and
`docs/shots/` so they can see the world he stands in.

## Animation, separately

Even with a good rig, the climb is the hard part and it is not a clip — `rung_grip.gd` plants
hands and feet on real rungs with IK and moves the body between them, which is why it looks like
climbing rather than swimming. **That system should be kept.** What a commissioned animator would
add is the *between*: the reach arcs, the weight shift, the settle. Mocap is not much help here —
climbing a ladder that only exists in our geometry is not something you can capture generically.

For the ground clips, the free **CMU Motion Capture Database** (BVH, unrestricted) has walks and
carries that retarget adequately and would beat hand-keying.

## My recommendation

Do both, in this order:

1. **Commission the character** (option 2). It is the bottleneck, it is a known quantity, and
   everything else in the project is further along than he is.
2. While that is out, **do not chase photorealism in the environment.** A half-photoreal world
   with a primitive man in it looks worse than a coherently stylised one, and the gap is exactly
   where the eye lands. This is recorded in `BLOCKED.md`.
3. Keep `build_character.py` for the **clothing, the rig and the clips** whatever happens to the
   body. It has earned its place and it is how the gait got fixed.
