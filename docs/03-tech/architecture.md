# Architecture

> Read [`adr/0006`](adr/0006-move-to-godot.md) (which supersedes [`adr/0004`](adr/0004-engine-change-to-unreal.md)
> and [`adr/0001`](adr/0001-engine-choice.md)), [`adr/0002`](adr/0002-physics-and-destruction.md) and
> [`adr/0003`](adr/0003-determinism-and-testing.md) first. This document is the shape that follows
> from them.
>
> **The one structural idea:** `SteeplejackSim` is plain C++20 with no engine dependency, and builds
> two ways — as a standalone library with a CMake test binary, and linked into a Godot GDExtension
> that the game loads. Every rule of the game lives there. That is what keeps the gameplay layer
> agent-executable and testable in seconds, and it is why the engine could be changed twice without
> the game changing.
>
> *Rewritten 2026-09-19, when Unreal was removed. The Unreal version of this page described a
> `SteeplejackGame` module, Nanite, Chaos and instanced static meshes; none of that exists now.*

## Repository layout

```
steeplejack/
├── AGENTS.md                      ← how to work in this repo
├── CMakeLists.txt                 ← standalone build of the sim + its tests (no engine)
├── Makefile                       ← every command; `make help`
│
├── Source/
│   ├── SteeplejackSim/            ← PURE C++20. No engine types. The game's rules. AGENT-OWNED.
│   │   ├── Public/
│   │   │   ├── Types.h  Rng.h  Clock.h  Json.h  Tuning.h  Level.h  JointGrid.h
│   │   │   ├── Anchor.h  Stack.h (+ the checkpoint)  Meters.h  Wobble.h  Wind.h
│   │   │   ├── Slip.h  Recovery.h  Reachability.h  Intent.h  Recorder.h  Replay.h
│   │   │   └── Verbs/{Tap,Hammer,Lash,Haul}.h
│   │   └── Private/*.cpp
│   │
│   └── SteeplejackGodot/          ← the GDExtension binding: `Jack`, one class, the only place
│                                     sim and engine meet. Every method catches exceptions.
│
├── godot/                         ← the game. Text scenes and GDScript. AGENT-OWNED.
│   ├── project.godot
│   ├── scenes/steeplejack.tscn
│   ├── scripts/                   ← player, chimney, face, hud, town, foley, climb_clip, settings
│   │                                 + test_*.gd (headless suites) and shot.gd (rendered frames)
│   ├── shaders/brick.gdshader
│   └── assets/characters/         ← steeplejack.glb, built by tools/blender/build_character.py
│
├── data/
│   ├── tuning/*.json              ← ALL balance numbers. Hashed into every replay.
│   ├── levels/*.json              ← No hand-placed geometry, anywhere.
│   ├── audio/foley.json           ← every sound, as envelopes; synthesised at load
│   ├── schemas/*.schema.json
│   └── replays/                   ← the recorded Grey Box climb (TEST-002)
├── tests/
│   ├── unit/                      ← doctest, runs via CMake in seconds with no engine
│   ├── replay/                    ← the replay format's round trip
│   ├── perf/                      ← the sim-step budget
│   └── fixtures/
├── tools/                         ← Python. Validation, task graph, conventions, coverage.
└── docs/
```

### Who owns what

| Layer | Owner | Format | Testable headlessly |
|---|---|---|---|
| `Source/SteeplejackSim/` | **agents** | text C++ | ✅ `make check`, seconds, no engine |
| `data/`, `tools/`, `tests/`, `docs/` | **agents** | text | ✅ `make check` |
| `Source/SteeplejackGodot/`, `godot/` | **agents** | text C++, GDScript, text scenes | ✅ `make godot-test`; frames with `make shot` |
| `godot/assets/` | **humans** | binary (LFS pending, CORE-010) | ❌ visual review only |

Almost everything is text an agent can author and review, including the character: his model, rig and
clips are a Blender script (`tools/blender/build_character.py`, `make character`), and the `.glb` is
its output. The project prefers what can be generated: the town is built from a seed, the chimney
from its level file, the foley from envelopes and the man from primitives.

## The frame

Godot's physics tick *is* the fixed step: the project runs physics at 60 Hz, and the player advances
the sim once per tick from `_physics_process`.

```gdscript
# godot/scripts/player.gd — once per physics tick (1/60 s)
func _physics_process(dt):
    ...                      # read input into intents: climb, tap, strike, lash, haul
    jack.set_context(...)    # height, wind, what he is carrying, whether a hand is off
    jack.step(dt)            # meters, slip, wind, recovery — pure C++, no engine
    stack_info = jack.stack_step(dt, height_m(), on_ladder)   # load, buckling, cascades
    _animate(); _update_lean(dt); _update_gear(); _update_checkpoint(dt)
```

`--fixed-fps 60` runs the same ticks unpaced, which is how the headless suites play fifteen minutes
of game time in under a minute and why their results are deterministic.

The orchestration of the verbs — which key starts a tap, when a blow lands — lives in `player.gd`.
The rules those verbs apply live in the sim. That split is why ADR-0003's full intent replay is not
yet possible: the intents are formed in GDScript. `Recorder`/`Replay` exist and round-trip to the bit
(CORE-006); what is missing is a sim-side step that applies intents to the verbs.

## Key data structures

```cpp
// Source/SteeplejackSim/Public/Types.h — plain C++20; no engine types anywhere in the module.
namespace sj {

struct Vec2 { float x, y; };
struct Vec3 { float x, y, z; };                      // ours; converted once, in the binding

enum class JointTier  : uint8_t { Cracked, Perished, Fair, Sound };
enum class AnchorRate : uint8_t { Failed, Poor, Fair, Sound };
enum class Stance     : uint8_t { OneHand, HookedLeg, Clipped, Belted, Chair };
enum class Lashing    : uint8_t { None, Hitch, Full };
enum class SpanBand   : uint8_t { Rigid, Flex, Sway, Buckle };

struct Joint   { int32_t id; Vec3 pos, normal; float height, quality;
                 JointTier tier; bool occupied; };
struct Anchor  { int32_t jointId; float height, depth, spall;
                 AnchorRate rate; float capacityKN, loadKN; bool freeFixture; };
struct Section { int32_t lowerAnchor, upperAnchor;
                 float span, condition, buckleTimer; Lashing lashing; };
struct Meters  { float grip, nerve, nerveMax; Stance stance; Exposure exposure; };

} // namespace sj
```

`Stack` (anchors, sections, load sharing, cascades, buckling, hitch drift) and `JointGrid` (the
face, generated from a level's bands) are the two big ones; see [`interfaces.md`](interfaces.md).

**Planned, not built:** the demolition side of the game — gob cells, props and the fall plan for
felling (`GobCell`, `Prop`, `FallPlan`), topping, scoring and the economy. Their signatures are in
`interfaces.md`; nothing implements them yet.

## Procedural structure generation

Nothing about a chimney is hand-modelled. From a level's `structure` and `bands`:

- the **sim** generates the joint grid (`JointGrid::Generate`) — the gameplay surface, sim data,
  never scene objects — and the old fixtures in it;
- **`chimney.gd`** builds the shaft as one tapered cylinder per band, with `brick.gdshader` drawing
  the brick, the band colours and the soot; the cap and flue; the ladder stack as MultiMeshes (with
  the bow of an over-long section); the cradle and brazier at the foot;
- **`face.gd`** draws the patch of wall within reach joint by joint — the visual tells, salt bloom,
  cracks, chalk, dogs, rope coils, anchor pips — as a dozen MultiMesh banks;
- **`town.gd`** builds the town from a seed: three MultiMeshes and two moving props.

Adding a level is: write a JSON file, `make validate`, `make test-levels` (which proves it can be
climbed with its own loadout — CORE-009), play it. **A level designer must be able to go from idea
to playable in under thirty minutes.**

## Save data

What exists:

- **The checkpoint** — `user://checkpoint-<level>.json`, the serialised stack (CLIMB-006). Written
  when the stack changes and on quit, restored on start, cleared at the top. Versioned, and
  fingerprinted against the level file so an edited level refuses an old stack.
- **Settings** — `user://settings.cfg`, the motion and vertigo options (A11Y-001).

**The in-progress stack is the checkpoint.** Nothing else about mid-level state is saved — the
player resumes at the foot of their own ladders with the shift reset.

Planned for the career (M3):

```jsonc
{
  "version": 1,
  "career": { "day": 34, "money": 4180, "reputation": 62, "injury": null },
  "inventory": { "ladders": [{"id":0,"condition":0.8}, ...], "dogs": 41, "rope": 2, "upgrades": ["good_hammer"] },
  "engine": { "parts_owned": ["wheels","axles","tubes"] },
  "jobs": { "06-waterside": { "completed": true, "best_invoice": {...} } }
}
```

## Performance-critical paths

| Path | Budget | Approach |
|---|---|---|
| Sim step | < 0.5 ms | plain C++ arithmetic; `make test-perf` times a full tick with a 28-section stack — about 2 µs |
| Chimney shaft | one mesh per band | tapered cylinders + `brick.gdshader` |
| Ladder stack | a few MultiMeshes | rails, rungs and dogs instanced; the bow is geometry, not a shader |
| The face in reach | ~12 draw calls | one MultiMesh per kind of mark, rebuilt only when he moves 0.25 m |
| Town | 4 draw calls | three MultiMeshes and two props, per-bank materials |

See [`performance-budget.md`](performance-budget.md).
