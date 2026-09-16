---
id: CORE-013
title: Editor frame budget on an empty map
milestone: M0
discipline: [ENG]
estimate_days: 0.25
status: ready
assignee: null
depends_on: [CORE-001]
owns:
  - docs/03-tech/perf-history.csv
reads:
  - docs/03-tech/performance-budget.md
  - Steeplejack.uproject
spec:
  - docs/03-tech/performance-budget.md#targets
  - docs/03-tech/performance-budget.md#measurement
verify: a recorded frame time on the primary target, written into docs/03-tech/perf-history.csv
editor_required: true  # somebody has to watch a real GPU render a real frame
risk: R8
---

## Goal
A recorded, dated frame-time measurement for an empty map on the primary target, establishing
the baseline everything later is compared against.

## Why
This is **CORE-001's acceptance criterion 6**, split out because it was blocking the wrong
things. CORE-001 gates CORE-002, CORE-003, CORE-004, CORE-010 and ENV-010 — including
`SteeplejackSim`'s first module, which is pure C++ and needs no engine at all. Holding the
entire agent-executable layer behind a GPU measurement is risk **R8** ("editor work blocks
agents") doing exactly what ADR-0004's two-layer split exists to prevent.

The measurement still matters. It just does not belong on that critical path.

## Context
CORE-001 verified the other half of criterion 6 already: the editor **opens and fully
initialises** — 8.05 s, zero errors, `SteeplejackGame` loaded, all ten plugins resolved. That
run used `-nullrhi`, so nothing was rendered and no frame time exists. This task supplies the
rendering half and nothing else.

The engine is at `/var/home/cree/UnrealEngine/UE_5.8` (binary drop, UE 5.8.2). `UE_ROOT` must
point there; `make editor` launches it.

Target, from [`performance-budget.md`](../docs/03-tech/performance-budget.md#targets): the
**primary** row is RX 7800 XT / RTX 4070 class at **1440p, TSR Quality, 60 fps target, 50 fps
floor**. The authoring machine is an RX 7700/7800 XT, so this is a direct read on the named
primary target rather than an extrapolation — worth recording as such, because no later
measurement will be this unambiguous.

Steps that worked during CORE-001:

```
export UE_ROOT=/var/home/cree/UnrealEngine/UE_5.8
make editor
# File -> New Level -> Empty Level
# console (`):  r.AntiAliasingMethod 4      (4 = TSR)
#               r.ScreenPercentage 66.6     (Quality; Performance 50, Balanced 58)
#               stat fps
#               stat unit
# Play -> New Editor Window, sized 2560x1440
```

An empty map should sit far under budget. **If it does not, that is the finding** — a blank
scene that cannot hold 60 fps means something is wrong with the install, the RHI or Lumen
defaults, and it is much cheaper to learn now than after there is content to blame.

`tools/perf_capture.py` exists but drives Levels 01, 09 and 12, none of which are built. It
cannot serve this task. Measure by hand; automating it is CORE-002's runner work, not this.

## Interface
No code.

## Acceptance
1. FPS and `stat unit` (Frame / Game / Draw / GPU, in ms) recorded for an empty map at 1440p
   with TSR Quality on the primary target.
2. The result is written to `docs/03-tech/perf-history.csv` with the date, the GPU, the engine
   version and the settings used. Create the file if it does not exist — nothing else owns it.
3. A verdict stated plainly: is the empty-map baseline inside the 16.6 ms frame budget, and by
   how much headroom.
4. If the baseline is **outside** budget, a follow-up task is raised. Do not absorb it silently
   as "that is just what the machine does".

## Out of scope
No optimisation. No Lumen, Nanite or scalability tuning — this is a measurement, and tuning
before there is anything to render would be guesswork. No CI automation; that is CORE-002.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
