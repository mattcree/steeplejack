---
id: CORE-001
title: Unreal project, two modules, and the standalone sim build
milestone: M0
discipline: [ENG]
estimate_days: 1.5
status: ready
assignee: null
depends_on: [PROD-001]
owns:
  - Steeplejack.uproject
  - CMakeLists.txt
  - Source/SteeplejackSim/SteeplejackSim.Build.cs
  - Source/SteeplejackGame/SteeplejackGame.Build.cs
  - Source/SteeplejackGame/SteeplejackGame.cpp
  - Source/Steeplejack.Target.cs
  - Source/SteeplejackEditor.Target.cs
reads:
  - docs/03-tech/architecture.md
spec:
  - docs/03-tech/adr/0004-engine-change-to-unreal.md#the-key-structural-move-steeplejacksim-is-not-a-ue-module
  - docs/03-tech/architecture.md#repository-layout
  - docs/03-tech/performance-budget.md#targets
verify: make build-sim && make build-game
editor_required: false
risk: R8
---

## Goal
A UE 5.5 project with two modules, where `SteeplejackSim` **also** builds standalone under CMake
with no Unreal installed.

## Why
The dual build is the entire mitigation for the cost of ADR-0004. If `SteeplejackSim` ever stops
building standalone, the gameplay layer stops being agent-executable and CI stops being fast.

## Context
The scaffold already exists (`Steeplejack.uproject`, `CMakeLists.txt`, both `.Build.cs` files) but
has never been compiled — `cmake` and Unreal are not installed on the authoring machine. This task
is the first real verification of it.

`SteeplejackSim.Build.cs` depends only on `Core`, and that is for build glue, not for types.
Do not add engine dependencies to it; if the sim appears to need one, the boundary is wrong.

## Interface
No new sim interfaces. Creates the two `.Target.cs` files and the game module entry point.

## Acceptance
1. `make build-game` compiles the editor target on a machine with UE 5.5.
2. `make build-sim` compiles `SteeplejackSim` with **no Unreal installed** — verify in a container.
3. `-Wall -Wextra -Werror` is on for the standalone build and the module compiles clean.
4. The plugin list in the `.uproject` matches ADR-0004 (Chaos, GeometryCollection, ControlRig,
   FullBodyIK, MetaSound, Niagara, EnhancedInput).
5. `make check-conventions` passes against the module.
6. The editor opens and runs an empty map at the primary target's frame budget.

## Out of scope
No gameplay. No content. The fixed-step driver is CORE-005.

## Plan
- **Verify the scaffold before changing it.** Done: `make build-sim` compiles clean under
  `-Wall -Wextra -Werror -Wshadow -Wconversion` (GCC 16.2.1) with no Unreal installed, and
  `make check` is green (0 violations, 4/4 tests). Acceptance 2, 3 and 5 are met by the
  scaffold as it stood — this task's first job was proving it, and it holds.
- **Create the three missing `owns:` files**: `Source/Steeplejack.Target.cs` (game target),
  `Source/SteeplejackEditor.Target.cs` (editor target), and
  `Source/SteeplejackGame/SteeplejackGame.cpp` (the primary game module entry point).
  No gameplay in any of them — the fixed-step driver is CORE-005.
- **Reconcile `.uproject` to the engine actually being installed.** `EngineAssociation` moves
  `5.5` -> `5.8`; the plugin list is checked name-by-name against ADR-0004 (acceptance 4).
  ADR-0004's decision line reads "5.5+", so this is inside the accepted decision, not a
  reversal of it.
- **Blocked on the engine for acceptance 1 and 6.** `make build-game` and "the editor opens an
  empty map at the primary target's frame budget" cannot run until UE 5.8.2 is unpacked and
  `UE_ROOT` is set. Everything else lands first so the engine-gated half is the only thing
  waiting.
- **Raise follow-ups rather than widening scope**: the ~15 files outside `owns:` that pin "5.5"
  in prose, and this task's own `editor_required: false` tag, which contradicts acceptance 6.

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
