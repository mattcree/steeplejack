---
id: SETUP-004
title: Worktree tooling: usable errors and status drift
milestone: M0
discipline: [ENG]
estimate_days: 0.5
status: in_progress
assignee: agent
depends_on: []
owns:
  - tools/wt.py
  - tools/test_wt.py
  - Makefile
reads:
  - AGENTS.md
  - docs/06-workflow/07-integration.md
spec:
  - docs/06-workflow/07-integration.md
verify: make land / make wt-start / make wt-drop with no ID each print a usable message and exit non-zero
editor_required: false
risk: null
---

## Goal
`wt.py` tells you what you did wrong instead of printing a Python traceback, and stops reporting
a task's status from a file that cannot be right.

## Why
Both defects below were hit in real use during CORE-001 and LVL-000 — one by the integrator, one
by two different agents independently. Neither costs correctness, but this is the tooling that is
supposed to make the workflow safe to run fast, and a tool that tracebacks or lies is one people
stop trusting and then stop using.

## Context

### 1. Missing `ID` is an unguarded `args[0]`
`tools/wt.py:378-396`. `start`, `land` and `drop` all do `args[0].upper()` with no length check,
so `make land` with no `ID=` raises:

```
IndexError: list index out of range
make: *** [Makefile:139: land] Error 1
```

`main()` already guards `len(sys.argv) < 2` and prints `__doc__`, and `die()` exists and prints a
message plus a hint. The three ID-taking commands just never use either. `make land` is the
command the integrator runs most, and it is the one that fails worst.

### 2. `wt-status` reports a status that cannot be correct
`cmd_start` writes the claim to **`ROOT`** (main) while the worktree branch is cut from
`origin/main` — i.e. from *before* that claim. That split is deliberate and good: the claim is a
registry update so two agents cannot claim the same task, while the work happens on the branch.

The problem is that `cmd_status` then reads each task's status from `ROOT` too. So a branch whose
task file says `review` is reported as `in_progress`, and a task handed off cleanly looks
unfinished. Both CORE-001 and LVL-000 showed `in_progress` at handoff while their branches said
`review`.

The same split has a sharper edge for anyone editing a task file **on a branch**: the file there
still says `status: ready`, because the claim never reached it. A find-and-replace for
`in_progress` silently matches nothing and the status is never set. That happened on both tasks in
the same session and was caught in review, not by the tooling.

Decide which source is authoritative and make the tool say so. Options, with the trade-off:
- **Report the branch's status** in `cmd_status` — most accurate, costs a `git show <branch>:<path>`
  per worktree.
- **Have `cmd_start` also write the claim onto the branch** — makes the branch self-describing, at
  the cost of a second commit and a near-certain conflict at `land` on the one line both sides
  changed.
- **Leave the model alone and warn** when a branch's task status differs from `ROOT`'s, in
  `cmd_status` and `cmd_save`.

The third is the cheapest and catches the silent-no-op case. Pick with the integration model in
mind — [`07-integration.md`](../docs/06-workflow/07-integration.md) is the spec — and write down
which source is authoritative once it is decided, because right now nothing says.

## Interface
No C++ and no signature changes. `wt.py` only.

## Acceptance
1. `make land`, `make wt-start` and `make wt-drop` with no `ID=` each print a usable message
   naming what is missing, and exit non-zero. No traceback.
2. `tools/test_conventions.py`-style coverage, or equivalent, for the no-argument path of all
   three — AGENTS.md's rule is no untested rules, and this file currently has no tests at all.
3. `make wt-status` does not report a status contradicted by the branch, by whichever of the three
   routes is chosen.
4. Whichever source of truth is chosen is documented in `07-integration.md` or in `wt.py`'s
   module docstring, so the next person does not have to infer it.
5. `make check` passes.

## Out of scope
No change to the claim-on-main model itself unless option 2 is deliberately chosen — this task is
about the tool reporting honestly, not about redesigning integration. No change to `land`'s rebase
or backup behaviour, which works.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
