# ADR-0004 — Move to Unreal Engine 5

- **Status:** Superseded by [ADR-0006](0006-move-to-godot.md); Unreal removed from the repository 2026-09-19
- **Date:** 2026-09-16
- **Supersedes:** [ADR-0001](0001-engine-choice.md)
- **Decision:** Unreal Engine 5.5+, with the simulation layer as a **UE-independent C++ module**
- **Deciders:** project lead

## Note — 2026-09-17, the concrete version

The decision line above says "5.5+" and is unchanged. This records what "+" turned out to mean.

**The engine is Unreal 5.8.2.** Chosen during CORE-001 by the project lead: Epic's Linux download
page no longer leads with 5.5, nothing in the repo had ever been compiled so migration cost was
zero, and 5.5.4 is a March 2025 build. 5.8.2 is inside the accepted decision, not a revision of it.

**C++17 became C++20, and that was forced rather than chosen.** UE 5.8 removed
`CppStandardVersion.Cpp17` outright — UBT fails the build with "C++17 is no longer allowed", and
the engine's own shared PCH is `...Cpp20.h`. There is no configuration of 5.8 that keeps the sim
at C++17. Both builds moved together deliberately; see ADR-0003 rule 4, whose argument depends on
them not diverging.

**The sim is not a loadable UE module.** Every loadable module needs `IMPLEMENT_MODULE`, which
needs `Modules/ModuleManager.h`, which rule 1 forbids anywhere under `Source/SteeplejackSim/`.
Resolved with UBT's `bRequiresImplementModule = false` and removing the sim from the `.uproject`
module list: it is compiled and linked into the editor binary, just never registered with the
module manager. This is what the section heading below already said — "SteeplejackSim is *not* a
UE module" — and what the body text had contradicted.

## Context

ADR-0001 chose Godot 4 primarily for agent-executability: text scene files, headless testing, and a
fast feedback loop. The visual target at that point was flat-shaded, low-poly stylisation.

The visual target has changed. The project lead wants the game to look like the key art: a
photographed-looking brick chimney at close range, a mill town receding into haze, and a sunset.
"It just needs to look great."

That is a legitimate and decidable requirement, and Godot will not reach it without a rendering
programmer we do not have.

## What Unreal buys that is specific to this game

This is not "UE is prettier". Four named risks in [`../../04-production/risks.md`](../../04-production/risks.md)
are retired or materially reduced:

| Risk | What UE gives us |
|---|---|
| **R3** — the felling system is a research project | **Chaos Geometry Collections.** [ADR-0002](0002-physics-and-destruction.md)'s "pre-fractured chunks driven by a hinge solver" describes a first-class UE workflow. The marquee mechanic gets engine support instead of being bespoke. |
| **R2** — hand IK is harder than estimated, and is on the critical path | **Control Rig + Full Body IK.** CLIMB-005 goes from a 4-day research task to a predictable one. |
| **R6** — audio treated as polish | **MetaSounds.** The tap-test envelope spec, the height mix and the gust pre-roll are all procedural audio problems that MetaSounds solves natively. |
| **R1** — can the player read the brickwork? | **Fab / Megascans.** Joint quality is a close-range *material* read: crisp joint vs. sandy erosion vs. salt bloom vs. hairline crack. Scanned materials make that read legible almost for free. A flat-shaded look asked one procedural shader to carry it alone. |

The economics are also unusually favourable here. Photoreal is normally expensive because of bespoke
geometry and set dressing. **This game's geometry is procedural and simple** — cylinders of brick
generated from JSON — and its look is almost entirely materials, lighting and atmosphere. Megascans
makes materials nearly free, so photoreal costs less for this project than it usually does.

## What it costs, and the mitigation

**Agent-executability**, which was the entire basis of ADR-0001. `.uasset` and `.umap` are binary;
Blueprints are binary graphs. An agent cannot read or write any of it. Risk **R8** (editor work
blocks the agent team) moves from medium to the top of the register.

The mitigation already exists, because [ADR-0003](0003-determinism-and-testing.md) put every
gameplay decision in a pure simulation layer with zero engine dependency — explicitly as insurance
against this decision.

### The key structural move: `SteeplejackSim` is not a UE module

```
Source/
  SteeplejackSim/      pure C++20. No UE types. No FVector, no UObject, no TArray.
    Public/*.h         Builds TWO ways:
    Private/*.cpp        1. as library code linked into the game (NOT a loadable module)
    CMakeLists.txt       2. as a standalone static lib + test binary, via CMake
  SteeplejackGame/     the UE module. Actors, components, subsystems, rendering.
```

This is the whole answer to the agent problem:

- **`make test-unit` builds and runs the sim tests with CMake in about 20 seconds, with Unreal not
  installed.** CI never needs a 40 GB engine to verify the layer that holds all the logic.
- Agents own `Source/SteeplejackSim/`, `data/`, `tools/`, `tests/` and `docs/` — all text, all
  diffable, all testable, all fast. That is roughly 45% of the work and ~100% of the gameplay logic.
- Humans own `Content/` and `Source/SteeplejackGame/` — materials, lighting, Control Rig, Niagara,
  Chaos, scene assembly.

We deliberately forbid UE types in the sim (no `FVector`, `TArray`, `UObject`, `FMath`) so that the
standalone build stays possible. `check_conventions.py` enforces it.

### Other costs, accepted

- **Iteration speed.** C++ compiles, shader compilation, editor startup. Slower than GDScript. The
  standalone sim build claws most of this back for the layer that changes most often.
- **Repository size.** `Content/` is binary. Git LFS is mandatory from the first asset.
- **Steam Deck** moves from a target to a stretch goal. See the revised performance budget.
- **Blueprints are banned** except as thin glue over C++. A gameplay decision in a Blueprint is
  unreviewable and undiffable.

## The art direction that follows

Not full photoreal, and not flat-shaded. **Photoreal where you look, stylised where you don't** —
see the rewritten [`../../01-gdd/13-art-direction.md`](../../01-gdd/13-art-direction.md).

The single point of failure is the **character**, which cannot be procedural or scanned and is the
one asset that must be genuinely good. Budget for it explicitly (ART-020).

## Consequences

- ADR-0001 is superseded, not deleted. Its reasoning remains correct for the premise it was given.
- ADR-0002 and ADR-0003 survive **unchanged** and are now easier to satisfy, not harder.
- `docs/03-tech/interfaces.md` survives; the signatures translate from GDScript to C++ mechanically.
- Every design document in `docs/00-vision.md`, `docs/01-gdd/` (except art direction) and
  `docs/02-levels/` is unaffected. That was the point of keeping them engine-agnostic.
- ~18 of the 47 M0/M1 tasks change; 5 are added; 2 are cut.
- The `editor_required` queue grows from 2 tasks to roughly a third of the presentation work.
  `make editor-queue` exists to keep that visible.

## Reversal cost

| When | Cost |
|---|---|
| Now | ~2 days (nothing is built) |
| After M1 | ~3 weeks — the sim layer ports, the presentation layer does not |
| After M3 | do not |

The sim/presentation split means the reversal cost is bounded, permanently. That property is worth
protecting even though we do not expect to use it again.
