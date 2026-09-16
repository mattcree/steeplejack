# Architecture

> Read [`adr/0001`](adr/0001-engine-choice.md), [`adr/0002`](adr/0002-physics-and-destruction.md) and
> [`adr/0003`](adr/0003-determinism-and-testing.md) first. This document is the shape that follows
> from them.

## Repository layout

```
steeplejack/
├── project.godot
├── AGENTS.md                    ← how to work in this repo
├── data/
│   ├── tuning/                  ← ALL balance numbers. Hot-reloadable.
│   │   ├── climbing.json
│   │   ├── meters.json
│   │   ├── topping.json
│   │   ├── felling.json
│   │   └── economy.json
│   ├── levels/*.json            ← 12 levels + side jobs. No hand-placed geometry anywhere.
│   ├── schemas/*.schema.json    ← JSON Schema for the above. CI validates.
│   └── replays/*.replay         ← recorded expert runs, used as regression tests
├── sim/                         ← PURE. No Node. No engine calls. 100% unit tested.
│   ├── rng.gd                   seeded xorshift
│   ├── types.gd                 plain data structs
│   ├── joints.gd                joint grid generation + quality
│   ├── anchor.gd                dog-in resolution, ratings
│   ├── stack.gd                 the ladder stack: spans, flex, load sharing, cascade
│   ├── meters.gd                grip, nerve, wobble
│   ├── wobble.gd                the single number every verb reads
│   ├── verbs/                   hammer.gd lash.gd haul.gd prise.gd bolt.gd gild.gd measure.gd
│   ├── gob.gd                   support polygon, CoG, margin
│   ├── fell.gd                  hinge solver, fracture, angular error
│   ├── topping.gd               cell grid, coping interlock, jams
│   ├── weather.gd               wind, gusts, the storm ramp
│   ├── shift.gd                 daylight clock
│   ├── scoring.gd               the invoice
│   ├── economy.gd               money, reputation, the engine
│   └── job.gd                   the job state machine; owns everything above
├── game/                        ← PRESENTATION (Godot nodes)
│   ├── main.gd                  fixed-step driver + interpolation
│   ├── player/                  controller, camera, IK, animation
│   ├── structures/              procedural chimney/spire/lattice builders
│   ├── vfx/                     dust, smoke, debris, weather
│   ├── audio/                   buses, height mix, the tap bank, gust pre-roll
│   ├── ui/                      HUD, reckoning, hub screens, options
│   └── hub/
├── tests/
│   ├── unit/                    one file per sim module
│   ├── property/
│   ├── replay/                  runs data/replays against sim
│   └── validate_levels.gd       schema + reachability
└── docs/
```

## The frame

```
_physics_process(delta):
    accumulator += delta
    while accumulator >= TICK (1/60):
        intents = InputMapper.collect()        # presentation → sim
        prev_state = sim.state.snapshot()
        sim.step(intents, TICK)                # pure
        recorder.record(tick, intents)         # for replay
        accumulator -= TICK

_process(delta):
    alpha = accumulator / TICK
    presentation.render(lerp(prev_state, sim.state, alpha))
```

`sim.step` must complete in **< 1.0 ms** at all times. It is arithmetic over a few hundred structs;
this is not ambitious.

## Key data structures

```gdscript
# sim/types.gd  — all plain Dictionaries/Arrays or RefCounted structs, no Nodes

class Joint:      var pos: Vector3; var quality: float; var tier: int; var used: bool
class Anchor:     var joint: Joint; var depth: float; var spall: float
                  var rating: int      # 0 failed 1 poor 2 fair 3 sound
                  var capacity_kn: float; var current_load_kn: float
class Section:    var bottom: Anchor; var top: Anchor; var span: float
                  var condition: float; var lashing: int   # 0 none 1 hitch 2 full
class Stack:      var sections: Array[Section]
                  func load_share(total_kn) -> Array[float]
                  func cascade_from(index) -> Array[int]   # which anchors fail, in order
class Meters:     var grip: float; var nerve: float; var max_nerve: float
class GobCell:    var seg: int; var course: int; var removed: bool; var strength: float
class Prop:       var seg: int; var load_kn: float; var dud: bool; var burnt: bool
class FallPlan:   var hinge_bearing: float; var fracture_heights: Array[float]
                  var angular_error: float; var debris_fan: Array[Vector2]
```

## Procedural structure generation

`game/structures/chimney_builder.gd` takes a level's `structure` block and emits:
- a shaft mesh (lathe from a profile curve, with batter steps and bands)
- a **joint grid** (`sim/joints.gd`) — the gameplay data
- a cell grid for topping, if the level tops
- a pre-fractured chunk set, if the level fells
- per-instance weathering parameters for the brick shader

Nothing about a chimney is hand-modelled. Adding a level is: write a JSON file, run the validator,
play it. **A level designer must be able to go from idea to playable in under thirty minutes.** If
that stops being true, fix it immediately — it is the production system that makes 12 levels
affordable.

## Save data

```jsonc
{
  "version": 1,
  "career": { "day": 34, "money": 4180, "reputation": 62, "injury": null },
  "inventory": { "ladders": [{"id":0,"condition":0.8}, ...], "dogs": 41, "rope": 2, "upgrades": ["good_hammer"] },
  "engine": { "parts_owned": ["wheels","axles","tubes"] },
  "jobs": { "06-waterside": { "completed": true, "best_invoice": {...} } },
  "in_progress": {            // set only if a shift ended badly
     "level": "10-hartford",
     "stack": [ ... serialised Stack ... ],
     "materials_remaining": {...}
  }
}
```

**The in-progress stack is the checkpoint.** Nothing else about mid-level state is saved — the
player resumes at the bottom of their own ladders with the shift reset.

## Performance-critical paths

| Path | Budget | Approach |
|---|---|---|
| `sim.step` | < 1.0 ms | plain arithmetic; gob solver recomputed on change only |
| Chimney shaft render | 1 draw call | single mesh + procedural brick fragment shader |
| Ladder sections | 1 draw call | `MultiMeshInstance3D`, flex via per-instance uniform |
| Interactive bricks | 1 draw call | MultiMesh, hidden by setting instance scale to 0 |
| Town backdrop | ≤ 12 draw calls | instanced kits + aggressive LOD + fog culling |
| Fall (4 s) | ≤ 90 bodies | the only heavy moment; drop town LOD during it |
| Dust column | 1 GPU particle system | the whole particle budget lives here |

See [`performance-budget.md`](performance-budget.md).
