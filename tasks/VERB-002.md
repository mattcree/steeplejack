---
id: VERB-002
title: Reticle tap pip (audio-to-visual fallback)
milestone: M1
discipline: [ENG]
estimate_days: 1
status: cut
assignee: null
depends_on: [VERB-001, AUD-001]
owns:
  - Source/SteeplejackGame/UI/ReticleWidget.h
  - Source/SteeplejackGame/UI/ReticleWidget.cpp
  - Content/UI/WBP_Reticle.uasset
spec:
  - docs/01-gdd/14-accessibility.md#audio-dependent-mechanics
  - docs/01-gdd/02-climbing-system.md#audio-is-a-mechanic-not-a-garnish
  - docs/01-gdd/14-accessibility.md#visual
verify: Play the grey-box level muted and reach the top. Record in the PR that all four tiers were distinguishable.
editor_required: false
risk: null
---

## Goal
A reticle pip that shows the tap result as one of four distinct shapes.

## Why
The tap test is a mechanic that lives in audio. Without a visual equivalent the game is unplayable deaf, and also unplayable on bad speakers, which is most players.

## Context
Shapes, never colours — the accessibility doc is explicit. On by default at Assisted, toggleable at any difficulty. This is the first instance of the audio-to-visual cue system that A11Y-002 generalises at M2; keep the registration shape reusable.

## Acceptance
1. Four visually distinct shapes, distinguishable in greyscale at 720p.
2. Visible for 0.6 s after a tap, then fades.
3. Toggle exists and works at every difficulty.
4. A player completes the grey-box level muted and can identify all four tiers.
5. Reticle shape, size and colour are all settable per the accessibility doc.

## Out of scope
Do not build the full cue registry — that is A11Y-002 at M2. Register this one cue in a way that generalises.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
**Cut, 2026-09-19: Unreal is removed from the project.** The Unreal implementation this task describes will not be built. The feature exists in the Godot game instead: godot/scripts/hud.gd draws the tap pip at the joint. **That version has not been checked against the acceptance criteria above.** If they still matter, they belong in a new task written against the Godot files.
