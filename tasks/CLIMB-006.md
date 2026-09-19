---
id: CLIMB-006
title: Stack serialisation (the checkpoint)
milestone: M1
discipline: [ENG]
estimate_days: 1
status: review
assignee: null
depends_on: [CLIMB-002]
owns:
  - Source/SteeplejackSim/Private/StackSerialise.cpp
  - tests/unit/test_save.cpp
spec:
  - docs/01-gdd/02-climbing-system.md#the-ladder-stack-is-the-checkpoint
  - docs/03-tech/architecture.md#save-data
  - docs/01-gdd/10-failure-and-difficulty.md#5-the-fall
verify: make test-unit FILTER=save
editor_required: false
risk: null
---

## Goal
Serialise and restore the ladder stack, because the stack is the game's only checkpoint.

## Why
No save points, no flags — progress is the structure the player built. This unifies mechanic and system, and it means checkpointing costs the player material and time.

## Context
Serialise the stack, not the player. On resume the player starts at the bottom of their own ladders with the shift reset. Version the format from day one; a save that cannot be migrated is a bug report you cannot reproduce.

## Acceptance
1. A 14-section stack round-trips with identical anchors, spans, lashings and conditions.
2. The format carries a version field and an unknown version fails with a clear message.
3. Round-trip is byte-identical on a second save.
4. Serialising a 28-section stack produces under 20 KB.
5. Restoring a stack whose level JSON has changed fails loudly rather than producing a corrupt route.

## Out of scope
No career save (money, reputation, the engine) — that is M3.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
**What changed:** `Source/SteeplejackSim/Private/StackSerialise.cpp` implements
`save::SerialiseStack`, `save::RestoreStack` and `save::LevelFingerprint`. They are declared at
the foot of `Stack.h`, together with a `Stack::Restore` factory (the failed flags, drift and
buckle timers are private). **`Stack.h` and `Stack.cpp` are outside this task's `owns`**, and are
declared here: the factory is eleven lines and changes nothing else.
`tests/unit/test_save.cpp` has one test per acceptance criterion, plus one for checkpoints that
do not hang together.

**Decisions made:**

- The format is positional arrays per anchor and per section, with the field order fixed by the
  version. A 28-section stack is about 2 KB against a 20 KB budget.
- The level is identified by its id and an FNV-1a fingerprint of the level file's bytes, so any
  edit to the level refuses the old stack (acceptance 5). The error names both fingerprints and
  says why it matters: the dogs may no longer be in joints that exist.
- Floats round-trip to the bit, the same way the replay format does it (CORE-006).
- The anchors' current `loadKN` is saved. It is transient, but acceptance 1 says "identical
  anchors".

**Surprises:** the first round-trip test used a stack that had never been loaded, so it proved
only the easy half. The fixture is now "lived in": twenty seconds of a climber on a quick hitch,
so the hitch walks, then a shock that pulls a dog. A control asserts that history is really
there, and after restoring, the two stacks are stepped side by side for ten seconds and must
produce the same events.

**In the game (added the same night):** `Jack.save_stack`/`restore_stack`/`stack_sections`. The
player autosaves to `user://checkpoint-<level>.json`: it compares every 2 s and writes only on a
change, and it also writes on quit. It restores on start, and redraws the rope coils, the cradle
count and the ladder top. Reaching the top clears the save, and `--fresh` ignores it. A checkpoint
for an edited level is refused with a message and **not deleted**, because it is someone's climb.
Tests and shots never checkpoint: only the running main scene does, or a test that names its own
path. `godot/scripts/test_checkpoint.gd` covers all of it and is in `make godot-test`.

**Follow-ups:** none.
