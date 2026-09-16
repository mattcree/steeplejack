---
id: PROD-001
title: Confirm the engine decision
milestone: M0
discipline: [PROD]
estimate_days: 0.5
status: done
assignee: project lead
depends_on: []
owns:
  - docs/03-tech/adr/0001-engine-choice.md
  - docs/03-tech/adr/0004-engine-change-to-unreal.md
spec:
  - docs/03-tech/adr/0004-engine-change-to-unreal.md#decision
verify: grep -q 'Status:\*\* Accepted' docs/03-tech/adr/0004-engine-change-to-unreal.md
editor_required: false
risk: null
---

## Goal
Get an explicit decision on the engine, and record it.

## Why
Every task in M0 assumes an engine. Reversal is cheap before M0 and expensive after M3.

## Acceptance
1. An ADR with `Status: Accepted` names the engine.
2. If it supersedes an earlier ADR, that ADR is marked Superseded rather than deleted.
3. The `Deciders:` line names a real person.

## Out of scope
Nothing.

## Plan
n/a

## Blocked
n/a

## Outcome
**Decision: Unreal Engine 5.5+.** [ADR-0004](../docs/03-tech/adr/0004-engine-change-to-unreal.md)
is Accepted and supersedes ADR-0001 (Godot), which is retained and marked Superseded.

**Why it changed:** the visual target moved. The project now targets photoreal materials at close
range (see the key art), which Godot cannot reach without a rendering programmer we do not have.

**What it bought:** four named risks retired or reduced — R3 (felling, via Chaos Geometry
Collections), R2 (hand IK, via Control Rig + FBIK), R6 (audio, via MetaSounds), and R1 (the
brickwork read, via Megascans materials).

**What it cost:** agent-executability. Mitigated by splitting `SteeplejackSim` into a UE-independent
C++ module that builds standalone under CMake, so the gameplay layer still tests in ~20 s with no
engine installed. Risk R8 (editor work blocks agents) is now the top of the register.

**Follow-ups created:** CORE-010 (Git LFS), ART-010 (brick master material, pulled forward from M3
because it is now the gameplay read), ART-020 (the character — the single point of failure),
ENV-010 (Lumen and volumetric baseline).
