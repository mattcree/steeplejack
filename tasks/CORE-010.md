---
id: CORE-010
title: Git LFS and the Content size gate
milestone: M0
discipline: [ENG, PROD]
estimate_days: 0.5
status: done
assignee: null
depends_on: [CORE-001]
owns:
  - .gitattributes
  - tools/check_content_size.py
  - tools/test_content_size.py
spec:
  - docs/03-tech/adr/0004-engine-change-to-unreal.md#other-costs-accepted
  - docs/03-tech/performance-budget.md#scene-budgets
verify: make check-assets, and python3 tools/test_content_size.py
editor_required: false
risk: null
---

> **2026-09-19:** Unreal is removed from the project. This need does not depend on the engine, so the task stays open, but its `owns:` paths and any Unreal specifics predate ADR-0006. Retarget them to `godot/` before starting.

## Goal
Git LFS configured and enforced before the first binary asset lands, plus a nightly size gate.

## Why
`Content/` is binary and unmergeable. Retrofitting LFS after assets are committed means rewriting
history, which is painful and breaks everyone's clones. **This must land before ART-010 or ART-020.**

## Context
`.gitattributes` already declares the LFS patterns but LFS has never been initialised on the remote
and no asset has been through it. Verify the round-trip with a real test asset before trusting it.

Cap is 25 GB (see the performance budget). At photoreal fidelity with Megascans that is reachable,
so the gate needs to exist from the start rather than being added when it is already breached.

## Acceptance
1. `git lfs install` documented in the README.
2. Every binary in the tree is stored as an LFS pointer, and the gate proves it rather than assuming.
3. `tools/check_content_size.py` reports the binary total and fails over the cap.
4. It runs in `make check` and in CI, and warns before it fails.
5. The `fast` CI job still clones with `lfs: false` and stays under 30 s.

## Out of scope
No asset pipeline or import automation. Just the plumbing and the gate.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
Done, retargeted from Unreal to Godot as the 2026-09-19 note asked.

**The cap is 2 GB, not 25 GB.** The 25 came from ADR-0004 and a photoreal Unreal build with
Megascans. This is a grey-box Godot game whose audio is synthesised from envelopes and whose one
character is 236 KB built by a script; the tree is 8.9 MB today. A cap two hundred times the current
size is not a gate, it is a comment. 2 GB is where a fresh clone stops being something you do
without thinking about it, which is the thing actually worth protecting.

**LFS was already working and I nearly recorded that it was not.** The `.png`s in the working tree
are real PNG bytes, which looks exactly like a broken setup — but that is what a smudged LFS file
*should* look like, and `git cat-file -p HEAD:docs/shots/shot.png` shows the pointer. Checked before
claiming, which is the only reason this paragraph is right.

**What was actually broken:** `*.glb` was not in `.gitattributes`, so the character has been stored
raw since the Blender pipeline landed. Fixed, and that is now check 1 of 4, because it is the one
that fires — a binary extension nobody thought to declare.

The gate also checks the failure that is invisible until a clone gets slow: a file *declared* for
LFS but stored as its own bytes, which happens when the pattern arrives after the file or when
somebody's clone has no `git lfs install`. Writing the test for that found the same class of bug in
the test itself — the fixture was being cleaned by the global LFS filter and so asserted nothing
until it was told to pretend LFS was not installed.

Not done: history rewriting. The `.glb` is a pointer from here on; the raw blob stays in history,
which is the cost of catching this a day late rather than a year late.
