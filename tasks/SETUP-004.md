---
id: SETUP-004
title: Worktree tooling: usable errors and status drift
milestone: M0
discipline: [ENG]
estimate_days: 0.5
status: review
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
Fixed both defects, plus a third found while fixing them that was considerably worse than
either: **`land` could never land anything.**

### The deadlock
`_land` read the task's status from the **trunk** checkout. `cmd_start` writes the claim
(`status: in_progress`) to the trunk, and the worktree branch is cut from `origin/main`
*before* that commit — so a handoff (`status: review`) can only ever be written on the branch.
`land` never looked there. Every task read back as `in_progress` and was refused:

```
$ make land ID=CORE-001
error CORE-001 is 'in_progress', not 'review'.
```

Both CORE-001 and LVL-000 were sitting at `review` on their branches and neither could merge.
This was not a reporting nuisance — integration was completely blocked, and the first attempt to
land anything in the project's history was the thing that surfaced it.

### What changed
- **`task_field_on(tid, field, branch)`** — reads a task field from a branch via `git show`,
  falling back to the trunk when there is no branch copy.
- **`_land`** now reads status from the branch, and its refusal names the branch it read and
  tells you how to check it yourself.
- **`cmd_status`** reports the branch's status, and where the trunk disagrees it shows both
  (`review <- in_progress on main`) instead of silently reporting the stale one.
- **`start` / `land` / `drop`** guard the missing-ID case with `die()` instead of an unguarded
  `args[0]`, which raised `IndexError` and a traceback.
- **`tools/test_wt.py`** — 19 cases. `wt.py` had no tests at all.
- **`Makefile`** — `test-tools` runs them, so they are inside `make check`.
- **`wt.py` module docstring** now states which source of truth is authoritative and why,
  which acceptance 4 asked for.

### Decisions
1. **The branch is authoritative for status; the trunk keeps the claim.** SETUP-004's Context
   offered three options. I took a combination of the first and third: `land` and `status` read
   the branch (option 1), and `status` additionally surfaces the divergence rather than hiding it
   (option 3). I did **not** take option 2 — writing the claim onto the branch as well — because
   it guarantees a conflict at `land` on the one line both sides changed, on every single task.
   The claim-on-trunk model is good and is not what was broken; only the reading of it was.
2. **`status` shows both values rather than just the right one.** The divergence is a real and
   permanent feature of the model, not an error state. Showing `review <- in_progress on main`
   teaches the reader where status lives; showing only `review` would leave the next person to
   rediscover the split the same way this task did.

### Surprises
- **The tool that gates integration had no tests**, while `check_conventions.py` has twenty. The
  rule "a rule with no test is not a rule" was applied to the conventions and not to the
  machinery enforcing the workflow around them.
- **The missing-ID traceback and the deadlock share a root cause**: `wt.py` was written but never
  run end to end, exactly like the C++ scaffold CORE-001 found. Nothing in this repo had been
  executed before today.

### Follow-ups
- `make wt-status` run from inside a worktree lists the trunk checkout as a row with task `?`.
  Harmless, pre-existing, cosmetic — not fixed here to keep this task to its stated scope.
- Nothing else. The `land` path beyond the status check (backup ref, rebase, gate on the rebased
  result, fast-forward) is untouched and was explicitly out of scope.

### Verification
| # | Criterion | Result |
|---|---|---|
| 1 | No-ID commands print a usable message, exit non-zero, no traceback | PASS — all three, verified by test and by hand |
| 2 | Tests for the no-argument path of all three | PASS — `tools/test_wt.py`, 19 cases, 0 failures |
| 3 | `wt-status` does not report a status contradicted by the branch | PASS — reads the branch, shows both on divergence |
| 4 | Authoritative source documented | PASS — `wt.py` module docstring |
| 5 | `make check` passes | PASS — 0 violations, 55 tasks, 0 errors, tests green |
