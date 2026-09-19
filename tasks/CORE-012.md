---
id: CORE-012
title: Decide whether Config/ is version-controlled
milestone: M0
discipline: [ENG]
estimate_days: 0.25
status: cut
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
**Decision: `Config/` is version-controlled, with exactly one file excluded, and the exclusion is
forced rather than chosen.** `Config/DefaultInput.ini` is committed. `Config/DefaultEngine.ini` is
gitignored with a comment saying why and naming the fix. `git status` is clean after an editor
launch.

**The evidence, because this task is a decision and a decision needs one**

The task could not previously be done as written: `Config/` does not exist in a fresh clone, so
there was nothing to inspect. It appears only after the project has been *built* and the editor
run — an editor launch in a worktree with no `Binaries/` boots and exits without writing it at all.
Generating it, then measuring:

| | |
|---|---|
| `DefaultInput.ini`, two launches, same worktree | **byte-identical** |
| `DefaultInput.ini`, a different worktree entirely | **byte-identical** |
| `DefaultEngine.ini`, different worktrees | differs in **one line**: `SecurityToken` |
| `DefaultEngine.ini`, block deleted, editor relaunched | **block returns, new token again** |

Three tokens observed: `…3BD676D3…`, `…C9B63A74…`, `…CD8EB47B…`. One per launch.

So `DefaultEngine.ini` cannot be both committed and clean. Its only content today is a
`[/Script/AndroidFileServerEditor.AndroidFileServerRuntimeSettings]` block — an **engine plugin the
project never enabled**; it is not in `Steeplejack.uproject`'s plugin list and is on by default —
which regenerates a secret-shaped value every time the editor starts. Committing it means either a
permanently dirty tree or a generated token in git history, and since `make wip` runs `git add -A`
the second happens by accident. **It already did**, in CORE-007, in a commit about SHA-256 vectors.

`DefaultInput.ini` is the opposite case: deterministic, and it carries a real project decision —
`DefaultPlayerInputClass=/Script/EnhancedInput.EnhancedPlayerInput`, which ADR-0004's module list
depends on. The other 89 lines are the engine restating its own defaults in its own preferred
spelling (`Exponent=1.f` becoming `Exponent=1.000000`), which is noise but *stable* noise, and
stripping it would only invite the editor to write it back.

**Acceptance**

1. ✅ `git status --short` is clean after an editor launch. Verified by running one.
2. ✅ No `SecurityToken`, no Android settings in any tracked file.
3. ✅ `.gitignore` carries the reasoning, not just the path — including that this is interim.
4. ✅ `make check` green.

**This is the interim answer, not the right one**

The right answer is to disable `AndroidFileServer` in `Steeplejack.uproject` and then commit
`DefaultEngine.ini` like any other project setting. That is one line, and it is outside this task's
`owns:` — the `.uproject` belongs to no task yet. Filed as **CORE-018**, and it matters sooner than
it looks: `performance-budget.md` assumes TSR Quality at 1440p, and those are `DefaultEngine.ini`
values with nowhere to live until this is resolved.

**Surprises**

- *`Config/` requires a built project to appear.* An editor launched in a worktree with no compiled
  binaries boots to `LogExit: Exiting` and writes nothing. That is why CORE-001 saw these files and
  a fresh clone does not, and why this task looked impossible until the project was built.
- *`-NoShaderCompile` crashes the 5.8.2 editor* in `FShaderCompilerStats::GetTotalShadersCompiled`,
  inside engine analytics. Unrelated to this project; noted so the next person does not lose a run.
- *The architecture doc's repository-layout tree still does not list `Config/` at all.* The task
  predicted this and said to record it rather than edit, since CORE-011 owns that file. Recorded:
  whoever next touches `architecture.md` should add `Config/` and note that one file in it is
  ignored and why.

**Follow-ups**

- **CORE-018** — disable `AndroidFileServer`, commit `DefaultEngine.ini`, drop the ignore rule.
- `docs/03-tech/architecture.md#repository-layout` needs a `Config/` row (CORE-011 owns it).

**Cut, 2026-09-19: Unreal is removed from the project** (ADR-0006, then the removal itself). This task was about whether Unreal's Config/ is version-controlled, and there is nothing left for it to act on.
