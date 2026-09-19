---
id: METER-004
title: Nerve recovery: stand, brew up, cigarette, look at the view
milestone: M1
discipline: [ENG, ART]
estimate_days: 2
status: review
assignee: null
depends_on: [METER-002]
owns:
  - Source/SteeplejackSim/Public/Recovery.h
  - Source/SteeplejackSim/Private/Recovery.cpp
  - tests/unit/test_recovery.cpp
  - Source/SteeplejackGame/Player/States/TeaState.cpp
spec:
  - docs/01-gdd/03-meters-grip-nerve.md#recovery
  - docs/01-gdd/12-audio-design.md#music
  - docs/01-gdd/11-camera-controls-feel.md#camera
verify: make test-unit FILTER=recovery
editor_required: false
risk: null
---

## Goal
Four nerve recovery actions, with the tea break built as a proper twelve-second set-piece.

## Why
The brew-up is the most characterful thing in the game. Players will do it when they do not need to, which is exactly the point — and it is one of the things the M3 playtest measures.

## Context
Tea: 12 s, camera locks to a slow fixed framing, wind noise drops, a flugelhorn cue plays, the character says something. Same cue every time so it becomes a comfort. The cigarette is the tempting bad option: fast, works anywhere, permanently lowers your ceiling for the shift. 'Look at the view' is a reward for the thing we want the player to do anyway.

## Acceptance
1. All four actions restore the tuned amounts over the tuned durations.
2. The cigarette reduces max nerve by 5 for the rest of the shift and this persists.
3. Tea requires a stable stance and both hands free; it is refused otherwise with a clear reason.
4. Interrupting tea part-way grants proportional recovery, not zero.
5. 'Look at the view' requires facing outward above 20 m.
6. The tea camera framing, audio duck and duration match the spec. **Verified manually**, since
   no command can check framing: attach a screen capture of one uninterrupted tea break to the
   handoff, and have one reviewer confirm the framing, the duck and the twelve seconds against
   `11-camera-controls-feel.md#camera`. Acceptance 1–5 are covered by `make test-unit
   FILTER=recovery`.

## Out of scope
The music cue itself is an M3 audio task; use a placeholder. No flask inventory (M3).

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
**What changed:** `Source/SteeplejackSim/Public/Recovery.h` and `Private/Recovery.cpp`
model the four actions (stand, brew up, cigarette, look at the view), with durations and amounts
from tuning. `tests/unit/test_recovery.cpp` covers acceptance 1–5 as named tests, plus "nothing
recovers past the ceiling" and passive recovery on a platform or low down. The Unreal
`TeaState.cpp` is replaced under ADR-0006 by `_recover()` in `godot/scripts/player.gd`. That code
does the slow fixed framing out over the town, the tea line, and the camera that takes its time.

**Decisions made:** `recover.descendBelowMetres` and `recover.viewAboveMetres` are tuning keys, not
literals. Tea is refused below the belted stance, and the refusal says why ("you need both hands —
belt on first"). The HUD shows that reason next to the key before the player presses it.

**Acceptance 6 is not verified.** It needs a human by design: a screen capture of one uninterrupted
tea break, checked against `11-camera-controls-feel.md#camera` for framing, the audio duck and
the twelve seconds. `make shot CMDS="climb 20,tea,wait 3,shot tea"` gives a still
of the framing. It does not show the duck or the duration.

**Follow-ups:** the capture for acceptance 6.
