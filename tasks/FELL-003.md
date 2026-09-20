---
id: FELL-003
title: The felling mode, playable
milestone: M0
discipline: [ENG]
estimate_days: 1
status: done
assignee: null
depends_on: [FELL-002]
owns:
  - godot/scenes/felling.tscn
  - godot/scripts/felling.gd
  - godot/scripts/gob_ring.gd
  - godot/scripts/fell_hud.gd
  - godot/scripts/fell_fall.gd
  - godot/scripts/fell_shot.gd
  - godot/scripts/test_felling.gd
reads:
  - Source/SteeplejackGodot/Jack.h
  - godot/scripts/chimney.gd
spec:
  - docs/01-gdd/06-felling-system.md
verify: make godot-script SCRIPT=res://scripts/test_felling.gd
editor_required: false
risk: null
---

## Goal
A scene you can play: stand at the base, cut the gob cell by cell, prop behind you, peg the line, light it and watch it go.

## Why
The sim can decide everything about a felling and none of it is a game until you can point at a brick and take it out.

## Context
The HUD is the instrument and it draws the sim's own support polygon rather than a drawing of
its own that happens to agree. Two plan panels, not one: the site is 160 m across and the gob is 6,
and a single plan that fits the debris fan makes the gob four pixels wide.

Four things only a rendered frame caught, all of them invisible to the headless suite:

* the camera faced away from the chimney (Godot's -Z is already "backwards" in bearing terms, so
  yaw *is* the bearing; adding a half turn put your back to the thing the scene is about)
* the shaft was drawn through the gob, so the hole you cut was behind a solid wall
* the hinge transform composed in the wrong order and laid the chimney flat sideways across a field
* the scorecard came up over the middle of the screen the instant the match was lit

`make fell` plays it; `make fell-shot CMDS="..."` photographs it.

## Interface
See [`docs/03-tech/interfaces.md`](../docs/03-tech/interfaces.md) — `Gob.h` (FELL-001) and `Fell.h`
(FELL-002) are written out there in full.

## Acceptance
1. A bot can work a gob from the first brick to the verdict headlessly.
2. Every rule the mode shows is read back from `Jack`; no GDScript decides anything.
3. Each margin band ticks, groans and shakes harder than the one before (rule 7), and every cue has a visual (rule 8).
4. The verdict waits for the ground thump, the dust and the cheer.

## Out of scope
Act 2's strip-out, which needs the climb. Packing and lighting the gob as an action.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
Built. `make godot-test` runs the bot as its fifteenth suite.

**Since first handoff.** Act 4 is a sequence rather than a keypress (FELL-006), Act 2 gates it
(the bar will not go in until she is stripped), cutting a cell is a held verb whose length comes
from the mortar, the jack is in the scene and the run is shot from behind him, and the whole thing
is reachable from a job board that carries money and reputation between jobs (CAREER-001).

Four layout numbers were written down and were right when typed and wrong one edit later — the
step list, the state panel, the verdict panel and the left-hand scrim. All four derive their size
from their contents now. It is the single most repeated mistake in this file's history.
