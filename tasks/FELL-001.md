---
id: FELL-001
title: The gob: the statics a felling is played against
milestone: M0
discipline: [ENG]
estimate_days: 1
status: done
assignee: null
depends_on: []
owns:
  - Source/SteeplejackSim/Public/Gob.h
  - Source/SteeplejackSim/Private/Gob.cpp
  - tests/unit/test_gob.cpp
  - data/tuning/felling.json
reads:
  - Source/SteeplejackSim/Public/Types.h
  - Source/SteeplejackSim/Public/Tuning.h
spec:
  - docs/01-gdd/06-felling-system.md
  - docs/03-tech/interfaces.md
verify: make test-unit FILTER=Gob:
editor_required: false
risk: null
---

## Goal
A ring of cells at the base of a chimney that you can cut out and prop, and one number - the margin - that says whether it is still standing.

## Why
Act 3 is the heart of a felling and it is all one rule: the centre of gravity inside the support polygon, with a margin. Everything the player does for twenty minutes moves that number.

## Context
Three things fell out of the design rather than being chosen, and they are the reason the
numbers are what they are:

* **The margin bands are the chord of the bare crescent.** Cut 160 degrees of a 3.2 m ring and the
  margin is 0.56 m, the middle of UNEASY, which is exactly where the design says a felling should
  finish. Cut 180 and it is zero. The authored bands (0.60 / 0.30 / 0.10) were not arbitrary.
* **Brickwork arches over the hole.** Waterside weighs 9,400 kN and fourteen props at 40 kN come to
  560 kN between them, so a prop cannot be carrying the column above it. It carries the wall
  directly above it up to the height the arch forms - `gobArchHeightM`, five metres, 22 kN.
* **That makes the design's loop arithmetic.** One unpropped hole beside a prop takes it to 33 kN
  and it stands; two takes it to 44 and it splits. You may run one segment ahead of your props.

A prop is also not worth the brick it replaced: brickwork resists the topple, timber in compression
only holds the weight up, so a prop contributes a support point drawn in towards the middle by what
it is carrying (`gobPropLeverFrac`). That is what keeps the cut arc, not the prop count, in charge.

## Interface
See [`docs/03-tech/interfaces.md`](../docs/03-tech/interfaces.md) — `Gob.h` (FELL-001) and `Fell.h`
(FELL-002) are written out there in full.

## Acceptance
1. Margin falls as cells come out and never improves by cutting.
2. A worked gob - the design's arc, propped - finishes in the UNEASY band.
3. A prop goes in behind the cut, one to a segment, and the level's budget is the limit.
4. A prop over `gobPropCapacityKN` splits and its load sheds to the nearest support each side.
5. Two unpropped segments beside a prop split it; one does not.

## Out of scope
The fall itself (FELL-002), anything Godot (FELL-003).

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
Built. 13 test cases.

The one thing worth knowing that is not in the design doc: **inside Waterside's prop budget the
props barely move the margin** - the budget is exactly the arc, so a correctly worked gob props
every hole it makes and the crescent is still what decides. What props buy there is the load path
and the cascade, not the statics. Going deeper is what props buy, and going deeper is what the
budget forbids. That is a good constraint, but it means a level that wants props to feel decisive
has to author more of them than the arc needs.

Also fixed on the way: the support polygon sampled segment *centres*, which lost half a segment of
wall off each end of the crescent - a whole segment of support, and at 32 segments that is the
difference between a gob that stands and one that does not.

**Since first handoff.** `SetMortarAsymmetry` had its sign inverted — the side every level doc
calls "much harder to cut" was the easy one. Invisible for as long as cutting was instant; the
first test that asked *how long a cell takes* found it in a minute. An earlier test of mine had
enshrined the mistake with a message calling 0.65 "harder mortar", which is how a wrong thing
stays green.
