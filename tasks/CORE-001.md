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
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
