---
id: SETUP-006
title: wt-start must not make a branch without its own task file
milestone: M0
discipline: [ENG]
estimate_days: 0.25
status: in_progress
assignee: agent
depends_on: [SETUP-005]
owns:
  - tools/wt.py
  - tools/test_wt.py
reads:
  - docs/06-workflow/07-integration.md
  - .claude/hooks/git_guard.py
spec:
  - docs/06-workflow/07-integration.md
verify: make test-tools
editor_required: false
risk: null
---

## Goal
`make new-task` followed immediately by `make wt-start` produces a usable worktree, or refuses
with a message that says what to do instead.

## Why
It currently produces a branch **with no task file on it**, silently.

`cmd_start` cuts the branch from `origin/main`. `make new-task` writes the file into the local
working tree, and the claim commit also goes to the *local* trunk. `.claude/hooks/git_guard.py`
blocks agents from pushing main. So a task that exists only on local main is **absent from the
branch cut for it** — the agent lands in a worktree where its own task file does not exist, with
no error and nothing to read.

Hit twice while setting up SETUP-004 and SETUP-005. Both times the fix was to notice and hand-copy
the file onto the branch, which is not a thing anyone should have to know.

## Context
The trunk only reaches `origin` when some *other* task lands, because `land` pushes it. So a newly
created task is unworkable until an unrelated merge happens to flush the trunk — which is an
ordering dependency nobody declared and nothing reports.

Options, in rough order of preference:

1. **Branch from the local trunk when the task exists there but not on `origin/TRUNK`.** Matches
   what `land` already does — SETUP-005 moved the rebase target to the local trunk for the same
   underlying reason, that the local trunk is routinely ahead and agents cannot push it.
2. **Refuse, with a message naming the fix** ("`{tid}` is not on origin/{TRUNK} yet; it will be
   after the next land"). Honest, but leaves the workflow blocked on unrelated work.
3. Let `wt-start` push the trunk. **Rejected** — the git guard forbids exactly this, deliberately,
   and integration is meant to be serialised through `land`.

Option 1 is consistent with the rest of the tool. Whichever is chosen, `wt-start` must not
silently hand back a worktree missing the one file the agent is told to read first.

## Interface
No C++. `wt.py` only.

## Acceptance
1. `make new-task ID=X` then `make wt-start ID=X` yields a worktree containing `tasks/X.md`, or
   fails with a message naming what to do.
2. `wt-start` behaves unchanged for a task already on `origin/TRUNK`.
3. A test covers the not-yet-on-origin case on the existing bare-origin fixture in
   `tools/test_wt.py`, and is verified to fail without the fix.
4. If option 1 is taken, `land` is unaffected — it already rebases onto the local trunk.
5. `make check` and `make test-tools` pass.

## Out of scope
No change to the git guard, and no change to where the claim commit goes. The claim-on-trunk model
is deliberate — see SETUP-004 — and this task is only about the branch being cut without the file.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
