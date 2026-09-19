---
id: CORE-018
title: Disable AndroidFileServer so Config/DefaultEngine.ini can be committed
milestone: M0
discipline: [ENG]
estimate_days: 0.25
status: cut
assignee: null
depends_on: [CORE-012]
owns:
  - Steeplejack.uproject
  - Config/DefaultEngine.ini
  - .gitignore
reads:
  - tasks/CORE-012.md
  - docs/03-tech/performance-budget.md
spec:
  - docs/03-tech/performance-budget.md#scene-budgets
verify: make check
editor_required: false
risk: null
---

## Goal
`Config/DefaultEngine.ini` is version-controlled like every other project setting, and the
`.gitignore` exception CORE-012 had to add is deleted.

## Why
CORE-012 committed `Config/DefaultInput.ini` and was forced to ignore `Config/DefaultEngine.ini`,
because the `AndroidFileServer` engine plugin rewrites that file **with a freshly generated
`SecurityToken` on every editor launch**. Three launches, three tokens. Committing it means either a
permanently dirty tree or a generated secret in git history — and since `make wip` runs
`git add -A`, the second happens by accident. It already did once, in CORE-007, in a commit about
SHA-256 test vectors.

That is a workaround, and it has a cost with a date on it: `performance-budget.md` assumes TSR
Quality at 1440p, and those are `DefaultEngine.ini` values. Until this lands they have nowhere to
live.

## Context
`AndroidFileServer` is an **engine** plugin, enabled by default. It is not in
`Steeplejack.uproject`'s `Plugins` array — nothing in this project asked for it, and this project
has no Android target (`Steeplejack.Target.cs` is `TargetType.Game`, and `TargetPlatforms` is
unset). Disabling it is one entry:

```jsonc
{ "Name": "AndroidFileServer", "Enabled": false }
```

Then launch the editor, confirm the `[/Script/AndroidFileServerEditor...]` block does not come
back, commit the resulting file, and delete the `Config/DefaultEngine.ini` line from `.gitignore`
along with the comment block explaining it.

**Do not skip the relaunch.** CORE-012 established that this file's behaviour cannot be reasoned
about, only measured: deleting the block and relaunching brought it back with a new token, and an
editor launched in a worktree with no compiled `Binaries/` writes no `Config/` at all. Build the
project first, then launch, then look.

## Acceptance
1. `AndroidFileServer` is disabled in `Steeplejack.uproject`.
2. After a build and two editor launches, `Config/DefaultEngine.ini` is unchanged between them and
   contains no `SecurityToken` and no Android settings. Show both launches in the Outcome.
3. `Config/DefaultEngine.ini` is tracked; the `.gitignore` exception and its comment are gone.
4. `git status --short` is clean after an editor launch.
5. `make check` passes, and `make build-game UE_ROOT=<install>` still succeeds — disabling a plugin
   is exactly the kind of change that quietly breaks a module dependency.

## Out of scope
Do not set TSR, anti-aliasing or any rendering values — that is a performance task once there is
something to render. This task only makes the file committable.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
**Cut, 2026-09-19: Unreal is removed from the project** (ADR-0006, then the removal itself). This task was about an Unreal engine .ini setting, and there is nothing left for it to act on.
