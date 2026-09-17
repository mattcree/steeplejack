---
id: CORE-012
title: Decide whether Config/ is version-controlled
milestone: M0
discipline: [ENG]
estimate_days: 0.25
status: in_progress
assignee: agent
depends_on: [CORE-001]
owns:
  - Config/DefaultEngine.ini
  - Config/DefaultInput.ini
  - .gitignore
reads:
  - Steeplejack.uproject
  - tasks/CORE-001.md
spec:
  - docs/03-tech/architecture.md#repository-layout
verify: make check
editor_required: false
risk: null
---

## Goal
`Config/` is either committed with intent or ignored with intent, and `make wip` no longer
tries to sweep it into whatever branch happens to be open.

## Why
The first editor launch (during CORE-001) generated `Config/DefaultEngine.ini` and
`Config/DefaultInput.ini`. They are untracked and **not** gitignored, so `make wip` — which
runs `git add -A` — will commit them into the next task branch that touches anything. That
makes them arrive silently, in someone else's task, outside anyone's `owns:`. Whatever the
right answer is, that is the wrong way to get there.

## Context
CORE-001 left them untracked deliberately rather than guess. The two files are currently
**pure engine boilerplate**: Android FileServer defaults, a randomly generated `SecurityToken`,
and stock input bindings. Nothing in them is a project decision yet.

Standard UE practice is to version-control `Config/` — it is where rendering settings, the
default map, input mappings and plugin configuration live, and those are real project
decisions that must not differ per machine. The counter-argument is only about *these
particular* generated contents, not about the directory.

The likely right answer is: commit `Config/`, but strip the generated noise first — in
particular do not commit a `SecurityToken`, and do not commit Android settings for a project
with no Android target. Check `docs/03-tech/architecture.md#repository-layout`, which does not
currently list `Config/` at all; whichever way this goes, that tree needs the directory added
or explicitly noted as ignored.

`docs/03-tech/architecture.md`'s repository-layout tree does not list `Config/` at all. That
file is **owned by CORE-011**, not by this task, so do not edit it here — record the gap in
this task's `## Outcome` so whoever runs CORE-011 adds the directory to the tree.

Note that several settings the project already depends on belong here eventually — the
anti-aliasing method and screen percentage that
[`performance-budget.md`](../docs/03-tech/performance-budget.md) assumes (TSR Quality at 1440p)
are `Config/DefaultEngine.ini` values, not editor-session values.

## Interface
No code.

## Acceptance
1. `git status --short` is clean after an editor launch — `Config/` is either tracked or
   ignored, not floating.
2. If committed: no `SecurityToken` and no Android-platform settings are in the tracked files,
   and a one-line comment in the file says why each retained section is there.
3. If ignored: `.gitignore` carries a comment explaining the decision, so the next person does
   not silently re-add it.
4. `make check` passes.

## Out of scope
Do not set rendering or TSR values here — that is a performance task once there is something
to render. This task only decides tracked-vs-ignored and removes generated noise.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
