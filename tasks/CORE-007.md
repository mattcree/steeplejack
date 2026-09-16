---
id: CORE-007
title: Tuning loader with hot reload
milestone: M0
discipline: [ENG]
estimate_days: 1
status: in_progress
assignee: agent
depends_on: [CORE-004]
owns:
  - Source/SteeplejackSim/Public/Tuning.h
  - Source/SteeplejackSim/Private/Tuning.cpp
  - tests/unit/test_tuning.cpp
  - Source/SteeplejackGame/TuningHotReload.cpp
reads:
  - data/tuning/climbing.json
  - data/tuning/meters.json
spec:
  - docs/03-tech/interfaces.md#simtuninggd--core-007
  - docs/03-tech/data-schemas.md#tuning-files
  - docs/06-workflow/04-enforced-conventions.md#rule-4-in-detail-the-one-people-push-back-on
verify: make test-unit FILTER=tuning
editor_required: false
risk: null
---

## Goal
Load every `data/tuning/*.json` into one typed lookup, hash it, and reload it on F5 in dev builds.

## Why
Rule 4 (no magic numbers in `SteeplejackSim`) only works if reading tuning is easier than typing a number. Hot reload is what lets a designer rebalance while playing, which the production plan depends on.

## Context
Keys are accessed as `tuning.get_f("span_warn_metres")` or via a generated typed accessor `tuning.span_warn_metres`. Support both; the convention checker recognises both. `hash()` is stamped into every replay so a tuning change that invalidates a replay fails loudly rather than silently.

## Interface
```cpp
class_name Tuning extends RefCounted
static func load_all(dir: String) -> Tuning
func get_f(key: String) -> float
func get_i(key: String) -> int
func get_b(key: String) -> bool
func hash() -> String
func has(key: String) -> bool
```

## Acceptance
1. All five existing tuning files load without error.
2. Dotted access works: `get_f("grip_drain.one_hand")` returns 8.0.
3. Both snake_case and camelCase spellings of a key resolve to the same value.
4. A missing key raises a clear error naming the key and the file it was expected in — it does not return 0.
5. `hash()` changes when any tuning value changes and is stable otherwise.
6. Editing `meters.json` and pressing F5 in a dev build changes behaviour without a restart.

## Out of scope
No tuning editor UI. No per-level tuning overrides (that is a later decision, not yet in the spec).

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
