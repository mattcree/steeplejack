---
id: CLIMB-001
title: Ladder stack: spans, flex bands, buckling
milestone: M1
discipline: [ENG]
estimate_days: 2
status: ready
assignee: null
depends_on: [VERB-005]
owns:
  - sim/stack.gd
  - tests/unit/test_stack.gd
spec:
  - docs/03-tech/interfaces.md#simstackgd--climb-001
  - docs/01-gdd/02-climbing-system.md#spans-and-flex
  - docs/01-gdd/02-climbing-system.md#3-ladders--the-resource
verify: make test-unit FILTER=test_stack
editor_required: false
risk: R1
---

## Goal
The ladder stack: sections, spans, the four span bands, and buckling as a timer.

## Why
The span table is the entire risk/reward economy of the ascent. MVP criterion 4 — do players voluntarily take the risky span — is measured directly against this module.

## Context
Span is measured anchor-to-anchor. Buckling is an 8 s timer under load, not an instant fail, so the player gets a warning they can act on — that is the fairness contract. The tuning table in `climbing.json` must be reproduced exactly; do not round or reinterpret it.

## Interface
```gdscript
class_name Stack extends RefCounted
enum SpanBand { RIGID, FLEX, SWAY, BUCKLE }
func add_anchor(a: Anchor) -> int
func add_section(lower: int, upper: int, lashing: Lashing) -> int
func span_of(i: int) -> float
func span_band(i: int, tuning: Tuning) -> SpanBand
func flex_deflection_m(i: int, load_kn: float, tuning: Tuning) -> float
func step(dt: float, loaded_section: int, tuning: Tuning) -> Array[int]
func top_height() -> float
```

## Acceptance
1. Span band boundaries match `climbing.json` exactly at 4.0, 6.0 and 8.0 m.
2. A section over 8 m under load buckles after `buckle_seconds_under_load`, not immediately.
3. Unloading a buckling section resets its timer.
4. Deflection at a 5 m span under 1.2 kN is 60-90 mm; at 3 m it is under 10 mm.
5. `top_height()` is correct for a 14-section stack.
6. A 28-section stack steps in under 0.1 ms.

## Out of scope
Load sharing and cascade are CLIMB-002. Serialisation is CLIMB-006. The flex shader is CLIMB-003.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
