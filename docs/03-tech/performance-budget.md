# Performance Budget

> Godot 4.7, Forward+ renderer ([ADR-0006](adr/0006-move-to-godot.md)). Rewritten 2026-09-19 when
> Unreal was removed: the previous version budgeted Lumen, Nanite, Chaos and Niagara, none of which
> this build uses.

## Targets

| Platform | Resolution | Target | Floor |
|---|---|---|---|
| **Primary** — RX 7800 XT / RTX 4070 class | 1440p | 60 fps | 50 fps |
| **Minimum** — RX 6600 / RTX 3060 class | 1080p | 60 fps | 45 fps |
| **Steam Deck** | 800p | 30 fps | stretch goal |

**60 fps is the target, not 120.** This is a game about deliberate, careful movement; the frame
budget is better spent on light and atmosphere than on refresh rate.

## What is measured, and what is not

| | Budget | Measured |
|---|---|---|
| **Sim step** — one full tick: wind, meters, recovery, slip, a 28-section stack | **0.5 ms** | ✅ `make test-perf`, every run: about **2 µs** |
| Rendering, frame time on real GPUs | 16.6 ms | ❌ **nothing measures it yet** |

The sim budget is the one that cannot be recovered by a scalability setting, so it is the one that
is gated. The rendering budget is not measured at all: the headless suites have no renderer, and
`make shot` renders in software (llvmpipe), which says what a frame looks like and nothing about what
it costs. A frame-time capture on real hardware over the reference scenes below is a task that does
not exist yet.

## Scene budgets (what the current build is built to)

| | Limit | Today |
|---|---|---|
| The face in reach | ~12 draw calls | one MultiMesh per kind of mark, rebuilt only when he moves 0.25 m |
| The ladder stack | a few draw calls | rails, rungs and dogs as MultiMeshes |
| The chimney | one mesh per band | tapered cylinders + `brick.gdshader` |
| The town | 4 draw calls | three MultiMeshes, two props, per-bank materials |
| Audio | a handful of voices | every cue synthesised once at load from `data/audio/foley.json` |
| The character | ≤ 10k triangles | about 5,700, 21 bones, 3 clips — from `make character` |

## The two spikes (design intent; neither exists yet)

### 1. The fall (levels 6, 7, 12)

The only moment the budget may be deliberately blown, for about five seconds. The intended
mitigations for a window around impact: the town to its cheapest form, chunks converting to static
rubble a few seconds after first contact, a hard cap on concurrent dynamic chunks with the overflow
spawned pre-settled, and the whole particle budget given to the dust plume.

**Target: the fall spike stays under 33 ms (30 fps) on the primary target.** Dipping to 30 fps for
two seconds during a controlled demolition is acceptable. Stuttering is not.

### 2. Topping (levels 5, 9, 12)

Hundreds of individually removable bricks. **Never a node per brick.** One MultiMesh per course;
removing a brick zero-scales its instance. The wall below the working face is one mesh clipped by a
shader parameter. The whole topping surface stays at a few draw calls however many bricks remain.

## Things that will hurt if we let them

| Risk | Mitigation |
|---|---|
| A node per brick, or per joint | MultiMeshes; the joint grid is sim data and never scene objects |
| Rebuilding the face every frame | `face.gd` rebuilds only on movement or a change (`REBUILD_EVERY`) |
| `MultiMesh.use_colors` silently ignored | colour per material, per bank (found building the town) |
| Many simultaneous falling-brick sounds | one looping rush and a terminating thump |
| Binary assets growing unchecked | Git LFS and `make check-assets` — total, per-file, coverage and pointer integrity (CORE-010) |
