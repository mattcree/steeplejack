---
id: METER-005
title: Slip-save, falling, and resume-at-stack
milestone: M1
discipline: [ENG]
estimate_days: 2
status: done
assignee: null
depends_on: [METER-003, CLIMB-006]
owns:
  - Source/SteeplejackSim/Public/Slip.h
  - Source/SteeplejackSim/Private/Slip.cpp
  - tests/unit/test_slip.cpp
  - godot/scripts/test_slip.gd
spec:
  - docs/01-gdd/02-climbing-system.md#6-falling
  - docs/01-gdd/10-failure-and-difficulty.md#4-the-slip-save
  - docs/01-gdd/10-failure-and-difficulty.md#5-the-fall
  - docs/01-gdd/14-accessibility.md#motion--vertigo
verify: make test-unit FILTER=slip
editor_required: false
risk: R9
---

## Goal
A 900 ms grab window once per minute; failing it falls, and falling resumes from the ladder stack.

## Why
The player will fall. It must be readable, survivable-feeling, and never a save-scum. The stack-as-checkpoint is what makes a fall sting without wiping twenty-five minutes.

## Context
Clipped on: you drop to the safety line and shock-load that anchor at 2.5x — which may itself fail, and that is the grimmest moment in the game. Not clipped: camera goes wide, time dilates to 0.6, the stack streaks past, cut to black before impact. The slip-save budget of one per 60 s is what makes the second slip terrifying.

## Acceptance
1. The window is 900 ms on Jack difficulty and tracks the difficulty table.
2. The cooldown is enforced: a second slip within 60 s cannot be saved.
3. A successful save leaves grip at 15% and applies nerve -25.
4. Clipped falls shock-load the safety anchor at 2.5x and can cascade.
5. An unclipped fall serialises the stack and returns the player to its base on resume.
6. Time dilation and the fall camera respect the accessibility motion settings, including the 'minimal' option.

## Out of scope
Injuries, lost fees and the hospital beat are FAIL-001 at M2. This task ends the shift and resumes.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome

Grip drained, the arc went red, it reached zero and nothing happened. Both meters decided nothing.
They decide something now.

**The sim** is `Slip.h`/`Slip.cpp`: the window from the difficulty table, the one-save-per-minute
budget, what a save costs, and what a fall finds. **The game** is the binding plus `player.gd` and
`hud.gd`: the window opens and closes inside `Jack::step` so no script can leave it hanging, the
grab is latched from `_input` so a keypress between two physics frames is not lost, and the HUD
dims everything else behind a closing ring that shrinks both round and inwards.

### Decisions

- **`interfaces.md`'s signature did not survive contact**, in three ways, all written into that
  document with reasons rather than changed quietly: a slip nobody grabbed at never resolved, so
  the expiry would have been a timer in the presentation layer; the save's cost would have been
  applied by the caller, which is a game rule outside the sim; and `Difficulty` had to exist at all
  for acceptance 1, because the table has sat in `meters.json` since METER-002 with nothing able to
  read it.
- **Two tuning values the GDD states and the files never held**: `slipSaveGripFraction` 0.15 and
  `nerveShock.caughtByLine` −50. Transcribed, not invented — both are in
  `02-climbing-system.md` §6.
- **`climbing.json`'s loose `slipSaveWindowMs`/`slipSaveCooldownSeconds` are the default; the
  difficulty table is authoritative.** Two files held one answer and would eventually have held
  two. A test asserts they agree.
- **A fall is a new shift, not a reload.** `Jack::new_shift` puts the meters back and leaves the
  level, the dogs and the lashed ladder exactly where they were. The clock keeps running, because a
  slip budget that reset on every fall would reward falling.

### Surprises

- **A slip had to become an edge rather than a level.** A fall leaves the climber at zero grip,
  which is the same condition that slipped him — so the next step slipped him again, spent the
  budget he had just been handed, and fell him again, for ever. `HandBackOn` is the other half.
- **A spent budget is a zero-length window, and a zero-length window satisfied "you grabbed before
  it closed" on the step it opened.** Anyone already holding the key saved the slip that exists
  specifically to be unsaveable.
- **The window closed a step late on a shift that had been running a while.** `now - began >=
  window` is not the same comparison at t=0 and at t=743; the end is stored absolutely now.
- **A GDScript parse error hangs the headless suite for ever** instead of failing it — the scene
  never loads, so the test script never reaches its `quit()`. `make godot-test` is bounded now and
  says what a timeout usually means.
- `hud.gd` asked for `strikeMaxAngleDeg`, which does not exist; the key is
  `hammerMaxAngleErrorDegrees` and `tuning_f`'s fallback swallowed it. Fixed in passing. That
  fallback is the silently-defaulted constant the sim's loader refuses to hand out, reintroduced
  one layer up, and it is worth a look at every other call.

### Acceptance, honestly

1. **Window is 900 ms on Jack and tracks the table** — ✅
2. **A second slip within 60 s cannot be saved** — ✅
3. **A save leaves grip at 15% and nerve −25** — ✅
4. **Clipped falls shock-load at 2.5× and can cascade** — ⚠️ **half.** The shock load, the rating
   comparison and the anchor failing are in and tested: 3 kN against a table where Sound holds 5
   and Fair holds 2.5. The **cascade** is not — a failed anchor does not pass its load to the one
   below, because that needs the load-sharing model, which is CLIMB-002's and does not exist. Today
   a failed anchor is a fall to the ground.
5. **An unclipped fall serialises the stack and resumes at its base** — ⚠️ **in-session only.** The
   stack survives a fall intact and he resumes at the cradle; `test_slip.gd` asserts `ladder_top`
   and every driven dog across a fall. Serialising it *to disk* is CLIMB-006 and is not done.
6. **Time dilation and the fall camera respect the motion settings** — ❌ **not started.** There is
   no fall camera and no time dilation; both are CAM-002's, and the toggles are A11Y-001's. Nothing
   in the sim depends on either, which is the property that makes them safe to add later: turn all
   of it off and the same grab at the same moment still saves you.

### Follow-ups

- CLIMB-002 closes the cascade half of acceptance 4. `ResolveFall` says where it goes in.
- CLIMB-006 closes acceptance 5's on-disk half.
- CAM-002 and A11Y-001 close acceptance 6.
- Nerve does not recover after a fall, because METER-004 does not exist. A player who falls twice
  is playing the rest of the shift on whatever nerve he has left, which is harsher than the design
  intends.
- The `tuning_f(key, fallback)` pattern in `hud.gd` can hide a wrong key. Worth a sweep.
