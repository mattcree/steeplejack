# Architecture

> Read [`adr/0004`](adr/0004-engine-change-to-unreal.md) (which supersedes
> [`adr/0001`](adr/0001-engine-choice.md)), [`adr/0002`](adr/0002-physics-and-destruction.md) and
> [`adr/0003`](adr/0003-determinism-and-testing.md) first. This document is the shape that follows
> from them.
>
> **The one structural idea:** `SteeplejackSim` is plain C++20 with no Unreal dependency, and builds
> two ways — linked into the game as library code, and as a standalone library with a CMake test
> binary. That is what keeps the gameplay layer agent-executable and testable in seconds without a
> 40 GB engine install.
>
> It is **not** a loadable UE module and has no `IMPLEMENT_MODULE`: that would need
> `Modules/ModuleManager.h`, and rule 1 forbids Unreal headers anywhere under the module. UBT's
> `bRequiresImplementModule = false` covers exactly this case. See CORE-001.

## Repository layout

```
steeplejack/
├── Steeplejack.uproject
├── AGENTS.md                      ← how to work in this repo
├── CMakeLists.txt                 ← standalone build of the sim + its tests (no Unreal)
│
├── Source/
│   ├── SteeplejackSim/            ← PURE C++20. No UE types. 100% unit tested. AGENT-OWNED.
│   │   ├── Public/
│   │   │   ├── Rng.h  Types.h  Tuning.h  Level.h  Joints.h  Anchor.h
│   │   │   ├── Stack.h  Load.h  Meters.h  Wobble.h  Weather.h  Slip.h
│   │   │   ├── Gob.h  Fell.h  Topping.h  Scoring.h  Economy.h  Job.h
│   │   │   ├── Intent.h  Recorder.h  Replay.h  Clock.h  Reachability.h
│   │   │   └── Verbs/{Tap,Hammer,Lash,Haul,Prise,Bolt,Gild,Measure}.h
│   │   ├── Private/*.cpp
│   │   └── SteeplejackSim.Build.cs   ← the ONLY UE-aware file in this module
│   │
│   └── SteeplejackGame/           ← the UE module. HUMAN-OWNED (mostly).
│       ├── Player/                controller, camera, Control Rig glue, IK
│       ├── Structures/            procedural chimney/spire/lattice builders
│       ├── Destruction/           Chaos Geometry Collection driving
│       ├── VFX/  Audio/  UI/  Hub/
│       └── SteeplejackGame.Build.cs
│
├── Content/                       ← BINARY. Git LFS. Materials, meshes, Control Rig,
│                                     Niagara, MetaSounds, levels-as-shells. HUMAN-OWNED.
├── data/
│   ├── tuning/*.json              ← ALL balance numbers. Hot-reloadable.
│   ├── levels/*.json              ← 12 levels. No hand-placed geometry, anywhere.
│   ├── schemas/*.schema.json
│   └── replays/*.replay
├── tests/
│   ├── unit/                      ← doctest, runs via CMake in ~20s with no Unreal
│   ├── property/
│   ├── replay/
│   └── perf/
├── tools/                         ← Python. Validation, task graph, conventions, perf capture.
└── docs/
```

### Who owns what

| Layer | Owner | Format | Testable headlessly |
|---|---|---|---|
| `Source/SteeplejackSim/` | **agents** | text C++ | ✅ in ~20 s, no engine |
| `data/`, `tools/`, `tests/`, `docs/` | **agents** | text | ✅ in ~3 s |
| `Source/SteeplejackGame/` | agents + humans | text C++ | partially (UE automation) |
| `Content/` | **humans** | binary | ❌ visual review only |

Roughly 45% of the work and ~100% of the gameplay logic stays in the top two rows.

## The frame

```cpp
// ASteeplejackGameMode::Tick(float DeltaSeconds)
Accumulator += DeltaSeconds;
int Steps = 0;
while (Accumulator >= sj::kTick && Steps++ < sj::kMaxCatchUpSteps)   // 1/60, cap 5
{
    const sj::IntentBuffer Intents = InputMapper.Collect();   // presentation -> sim
    PrevState = Sim.Snapshot();
    Sim.Step(Intents, sj::kTick);                             // pure C++, no UE
    Recorder.Record(Tick++, Intents);                         // for replay
    Accumulator -= sj::kTick;
}

// rendering
const float Alpha = Accumulator / sj::kTick;
Presentation.Render(sj::Lerp(PrevState, Sim.State(), Alpha));
```

`Sim.Step` must complete in **< 0.5 ms** at all times. It is arithmetic over a few hundred plain
structs in C++; this is not ambitious, and it is measured on every commit in the standalone build.

## Key data structures

```cpp
// Source/SteeplejackSim/Public/Types.h
// Plain C++20. No FVector, no TArray, no UObject — the standalone CMake build depends on it.
namespace sj {

struct Vec2 { float x, y; };
struct Vec3 { float x, y, z; };                      // ours, not FVector

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
struct GobCell { int16_t seg, course; bool removed, propped; float strength; };
struct Prop    { int16_t seg; float loadKN; bool dud, burnt; };
struct FallPlan{ float hingeBearing, angularError;
                 std::vector<float> fractureHeights; std::vector<Vec2> debrisFan; };

class Stack {
public:
    std::vector<float>   LoadShare(int atSection, float totalKN, const Tuning&) const;
    std::vector<int32_t> CascadeFrom(int failedAnchor, const Tuning&) const;  // in failure order
    // ...
};

} // namespace sj
```

## Procedural structure generation

`Source/SteeplejackGame/Structures/ChimneyBuilder.cpp` takes a level's `structure` block and emits:
- a shaft mesh (lathe from a profile curve, with batter steps and bands)
- a **joint grid** (`sj::JointGrid`, sim data — never scene objects) — the gameplay surface
- a cell grid for topping, if the level tops
- a **Chaos Geometry Collection** (baked offline, loaded here), if the level fells
- per-instance parameters for the brick master material (soot gradient, salt bloom, erosion, cracking)

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
| `Sim.Step` | < 0.5 ms | plain C++ arithmetic; gob solver recomputed on change only |
| Chimney shaft | Nanite, 1 primitive | procedural mesh + the brick master material |
| Ladder sections | 1 ISM | instanced; flex via a per-instance custom data float |
| Interactive bricks | ≤ 3 draw calls | ISM per course; removal = zero-scale the instance |
| Town backdrop | ≤ 40 primitives | instanced kit, Nanite, silhouette LOD beyond 200 m |
| Fall (5 s) | ≤ 120 Chaos bodies | the only heavy moment; scalability drops applied |
| Dust column | 1 Niagara system | the whole particle budget lives here |

See [`performance-budget.md`](performance-budget.md).
