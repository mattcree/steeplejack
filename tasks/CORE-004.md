---
id: CORE-004
title: Sim data types
milestone: M0
discipline: [ENG]
estimate_days: 1
status: review
assignee: agent
depends_on: [CORE-001]
owns:
  - Source/SteeplejackSim/Public/Types.h
  - tests/unit/test_types.cpp
spec:
  - docs/03-tech/interfaces.md#typesh--core-004
  - docs/03-tech/adr/0003-determinism-and-testing.md#the-split
  - docs/03-tech/architecture.md#key-data-structures
verify: make test-unit FILTER=types && make check-conventions
editor_required: false
risk: null
---

## Goal
The plain data structs every other sim module shares, and the enums they use.

## Why
Contract-first: these types are what let eight agents implement eight sim modules in parallel without talking to each other.

## Context
All a plain struct, no `Node`. The convention checker (`make check-conventions`) will reject an engine node type here, so it is also the first real test of that gate.

## Interface
See `docs/03-tech/interfaces.md` section `Types.h`. Copy the enums and classes exactly; do not add fields that no interface mentions.

## Acceptance
1. Every enum and class in the interfaces doc exists with exactly those fields and names.
2. `make check-conventions` passes (no Node, no engine calls, no magic numbers).
3. Every class is statically typed and the project compiles with `-Werror` as an error.
4. A test constructs one of each and asserts default values.

## Out of scope
No behaviour. These are data. Logic lives in the modules that own it.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
`Source/SteeplejackSim/Public/Types.h` and `tests/unit/test_types.cpp`. Every enum and struct in
`interfaces.md#typesh--core-004` exists with exactly those fields, names and order, plus `Vec2`,
`Vec3`, `kTick` and `kMaxCatchUpSteps` from the Conventions block of the same doc. No behaviour.

**Decisions**

- *Spelling of two defaults changed, values unchanged.* The doc writes `condition{1.f}` and
  `buckleTimer{-1.f}`. `tools/check_conventions.py` reads `1.f` as the literal `1.` and rejects it;
  `1.0f` and `-1.0f` are on its allowed list. Written as `1.0f` / `-1.0f`. Same values, and I did
  not touch the interfaces doc for it — `1.f` and `1.0f` are the same literal, so this is not a
  contract change.
- *Added `static_assert`s, not fields.* The doc says "aggregate initialisation only, no
  constructors, no virtuals, no inheritance". That was a comment; it is now checked at compile
  time for all eight structs (`is_aggregate`, `is_trivially_copyable`, `is_standard_layout`).
  Replay frames and the determinism gate compare these byte-for-byte, so a constructor or a base
  class sneaking in later would break both quietly.
- *Defaults tested, not just written.* The tests pin `Anchor::jointId{-1}`/`AnchorRate::Failed`
  and `Section::buckleTimer{-1.0f}` specifically, because those are the three places where a
  zero-initialised struct would otherwise read as a *usable* anchor or a *buckling* section.
- *Enum order is treated as contract.* Every graded enum runs worst-to-best and its zero value is
  its safest state, so `tier >= JointTier::Fair` reads the way the words do. A reorder would
  invert such comparisons without failing to compile, so there is a test for it.

**Surprises**

- The `verify:` line was wrong and silently green. It said `FILTER=test_types`, which doctest
  expands to `--test-case=*test_types*` and matches **zero** test cases — the file name, not the
  test-case prefix. Every other task uses the bare module name (`FILTER=rng`, `clock`, `tuning`,
  `stack`), matching the `Rng: ...` test-case prefix. Corrected to `FILTER=types` (9 cases, 98
  assertions). This is exactly the rot **TEST-003** exists to make loud, and it was already in the
  repo before this task.
- `tasks/CORE-008.md` has the same bug: `FILTER=test_level` against test cases that will be named
  `Level: ...`. Not mine to edit — flagged here for whoever claims it.
- `architecture.md#key-data-structures` disagrees with `interfaces.md` in three ways: it omits
  `Exposure` from its enum list while using it in `Meters`, omits `MeterContext` and
  `StrikeResult`, and adds `GobCell`, `Prop` and `FallPlan`. Per rule 9 one of them is a bug, and
  it is architecture.md: interfaces.md is the contract page, and those three extra structs are
  demolition types scoped to M2 ("M2+ interfaces are added at the start of their milestone").
  Implemented interfaces.md exactly. architecture.md is outside this task's `owns:` and was not
  touched — see follow-ups.

**Follow-ups**

- Reconcile `docs/03-tech/architecture.md#key-data-structures` with `interfaces.md`: drop the M2
  demolition sketch or mark it as such, and add the two missing structs. Needs a task.
- `tasks/CORE-008.md` `verify:` filter, as above.
