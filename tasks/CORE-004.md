---
id: CORE-004
title: Sim data types
milestone: M0
discipline: [ENG]
estimate_days: 1
status: ready
assignee: null
depends_on: [CORE-001]
owns:
  - sim/types.gd
  - tests/unit/test_types.gd
spec:
  - docs/03-tech/interfaces.md#simtypesgd--core-004
  - docs/03-tech/adr/0003-determinism-and-testing.md#the-split
  - docs/03-tech/architecture.md#key-data-structures
verify: make test-unit FILTER=test_types && make check-conventions
editor_required: false
risk: null
---

## Goal
The plain data structs every other sim module shares, and the enums they use.

## Why
Contract-first: these types are what let eight agents implement eight sim modules in parallel without talking to each other.

## Context
All `RefCounted`, no `Node`. The convention checker (`make check-conventions`) will reject an engine node type here, so it is also the first real test of that gate.

## Interface
See `docs/03-tech/interfaces.md` section `sim/types.gd`. Copy the enums and classes exactly; do not add fields that no interface mentions.

## Acceptance
1. Every enum and class in the interfaces doc exists with exactly those fields and names.
2. `make check-conventions` passes (no Node, no engine calls, no magic numbers).
3. Every class is statically typed and the project compiles with `untyped_declaration` as an error.
4. A test constructs one of each and asserts default values.

## Out of scope
No behaviour. These are data. Logic lives in the modules that own it.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
