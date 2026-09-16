---
id: SETUP-005
title: Land must skip commits its own resolution empties
milestone: M0
discipline: [ENG]
estimate_days: 0.25
status: in_progress
assignee: agent
depends_on: [SETUP-004]
owns:
  - tools/wt.py
  - tools/test_wt.py
reads:
  - docs/06-workflow/07-integration.md
spec:
  - docs/06-workflow/07-integration.md
verify: make test-tools
editor_required: false
risk: null
---

## Goal
`make land` completes when resolving the task's own file leaves a commit with nothing in it.

## Why
SETUP-004 taught `land` to resolve `tasks/<ID>.md` to the branch's copy. When a branch has
several commits touching its own task file — which is normal: claim, plan, handoff, review
fixes — resolving an earlier one can leave a later one with no changes at all. Git then refuses
`rebase --continue` with *"The previous cherry-pick is now empty"* and asks for `--skip`.

`land` does not skip. It stops:

```
STOPPED `git rebase --continue` failed with no conflicted paths.
```

Hit on the first attempt to land CORE-003, which has five commits touching its own task file.
SETUP-004 predicted this path and guarded it so it reports honestly instead of blaming the
ownership model — but guarding is not handling, and integration is blocked again until it is.

## Context
`tools/wt.py`, in `_land`'s auto-resolve loop. The loop currently treats "no conflicted paths"
as a stall and aborts. The correct response is narrower than that: if `rebase --continue` fails
**and** nothing is conflicted **and** git reports the commit as empty, run `git rebase --skip`
and carry on. Anything else still aborts.

Be careful not to widen the blast radius. `--skip` discards a commit. That is right only when
the commit is empty *because this tool's own resolution made it so*, and wrong in every other
case. Check git's own signal rather than inferring it — `git status` during a stopped rebase
reports the empty-commit state explicitly.

`make_repo_with_origin` in `tools/test_wt.py` already builds the fixture this needs; it wants
one more commit on the branch touching the task file so the second one empties out.

SETUP-004 owns `tools/wt.py` and has landed, hence the dependency.

## Interface
No C++. `wt.py` only.

## Acceptance
1. A branch with two or more commits touching its own task file lands cleanly.
2. `land` still aborts, untouched, when `rebase --continue` fails for any reason other than an
   empty commit.
3. A test covers the multi-commit case on the existing origin fixture, and is verified to fail
   without the fix.
4. `docs/06-workflow/07-integration.md` describes the skip, since it silently drops a commit.
5. `make check` and `make test-tools` pass.

## Out of scope
No other change to the merge queue. Do not widen what `land` resolves on its own authority —
SETUP-004's review concluded the narrowness is what makes it acceptable.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
