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
  - docs/06-workflow/07-integration.md
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

### Two more defects, found by actually landing something
The first two fixes made `land` *run*. Running it then exposed two more, both of which had made
integration impossible and neither of which was visible from reading the code:

**3. `land` rebased onto `origin/TRUNK` but fast-forwarded the LOCAL trunk.** Those are not the
same ref. `start` commits every claim to the local trunk, and `.claude/hooks/git_guard.py` stops
agents pushing it — so the local trunk sits ahead of origin as soon as a single task is claimed,
which is always. The merge died with `fatal: Not possible to fast-forward, aborting` after the
gate had already passed. Now the trunk is brought up to date first and the branch rebases onto
the local trunk.

**4. A task's own file conflicts on every land, by construction.** `start` writes
`status: in_progress` to the trunk copy; the branch writes `status: review` plus its Plan and
Outcome to the same file. Same line, every task, guaranteed. `land` treated it as a generic
conflict and printed *"A conflict here means the ownership model was violated"* — which is
exactly wrong, and would send whoever hit it hunting for a nonexistent `owns:` overlap. `land`
now resolves that one file to the branch's copy (the branch holds the handoff) and continues;
any other conflicted path still aborts untouched with the original message.

This also corrects decision 1 below. I rejected option 2 — writing the claim onto the branch too
— on the grounds that it would "guarantee a conflict at land on the one line both sides changed".
That conflict exists anyway. It is inherent to claim-on-trunk, not a cost of option 2.

### What changed
- **`task_field_on(tid, field, branch)`** — reads a task field from a branch via `git show`,
  falling back to the trunk when there is no branch copy.
- **`_land`** now reads status from the branch, and its refusal names the branch it read and
  tells you how to check it yourself.
- **`cmd_status`** reports the branch's status, and where the trunk disagrees it shows both
  (`review <- in_progress on main`) instead of silently reporting the stale one.
- **`start` / `land` / `drop`** guard the missing-ID case with `die()` instead of an unguarded
  `args[0]`, which raised `IndexError` and a traceback.
- **`tools/test_wt.py`** — 24 cases. `wt.py` had no tests at all.
- **`Makefile`** — `test-tools` runs them. That target is in `make ci`, **not** `make check`
  (`check` is conventions, validate, links, unit tests). That is the right place: it is where
  `test_conventions.py` already sat, and `land` gates on `make ci`, so these run on every merge.
- **`wt.py` module docstring** now states which source of truth is authoritative and why,
  which acceptance 4 asked for.
- **`_land`** pulls the trunk first and rebases onto the local trunk, not `origin/TRUNK`.
- **`_land`** auto-resolves a conflict in the task's own file to the branch copy, bounded to 50
  rebase stops, and still aborts on anything else. It reports how many trunk-side lines the
  whole-file resolution discards, because task files *do* get edited on main directly — this
  session edited two — and a silent drop there would lose real work.
- **`_land`'s fall-throughs** no longer print the ownership lecture for the one file the tool just
  tried to resolve itself. Hitting the bound, `rebase --continue` failing with nothing conflicted
  (usually a commit that became empty), and `checkout --theirs` failing all abort with an accurate
  message. The last one mattered most: it previously ran `git add` unconditionally afterwards,
  which would have staged the **trunk's** side — the exact inverse resolution — silently.
- **`docs/06-workflow/07-integration.md`** — the `make land` step list now matches the code, and
  gained two sections explaining why status is read from the branch and why `land` resolves one
  conflict itself.

### Decisions
1. **The branch is authoritative for status; the trunk keeps the claim.** SETUP-004's Context
   offered three options. I took a combination of the first and third: `land` and `status` read
   the branch (option 1), and `status` additionally surfaces the divergence rather than hiding it
   (option 3).

   I rejected option 2 — mirroring the claim onto the branch — and **got the reason wrong twice
   before the reviewer built both models and measured it.** The record, because the reasoning is
   what the next person inherits:

   - *My first claim:* option 2 would conflict at `land` on every task. **Backwards.** It is the
     *absence* of option 2 that guarantees that conflict.
   - *My correction:* the conflict is inherent to claim-on-trunk and happens either way.
     **Also wrong.** Under option 2 the duplicate claim commit becomes empty and is dropped on
     replay, which realigns the merge base for the handoff hunk from `ready` to `in_progress`, so
     `in_progress -> review` applies cleanly against a trunk already at `in_progress`. Measured,
     not argued: `'T-1: claim (branch copy too)' -> became EMPTY, dropped` then
     `'T-1: handoff + Outcome' -> clean`.
   - *The actual reason the conclusion survives:* **option 2 does not fix the deadlock.** The
     handoff is written only on the branch under either model, so a `land` that reads the trunk
     still never sees `review`. `task_field_on` is necessary regardless, and option 1 was
     required.

   **What that cost:** option 2 was the one-commit structural removal of defect 4, and instead
   defect 4 got ~40 lines of conflict auto-resolution inside the merge queue — the only place
   this tool resolves anything on its own authority. The task's own Out of scope explicitly
   permitted option 2 ("unless option 2 is deliberately chosen"), so it was never scope creep.
   It is not being reversed now: `land` works, two tasks landed on it, and the auto-resolve path
   is tested against a real rebase. But a future task that wants to simplify the merge queue
   should start here, with the evidence above rather than with my first two explanations of it.

   Option 3 alone — the route the task itself proposed as cheapest — would have left `land`
   broken. The task's author did not know about the deadlock when writing those options.
2. **I widened this task's `owns:` three times, deliberately, and this is the declaration.**
   Added `tools/test_wt.py` (acceptance 2 demands tests), `Makefile` (one line inside the existing
   `test-tools` target, so the tests run under the gate) and `docs/06-workflow/07-integration.md`
   (the DoD requires the doc to match changed behaviour, and `land`'s documented steps described
   the old rebase target and said nothing about auto-resolution).
   `SETUP-001` owns the Makefile and `SETUP-002` owns `test_conventions.py`, but both are `done`
   and `tools/tasks.py` skips completed tasks when computing ownership conflicts, so no live task
   contests either path. CORE-011 *did* contest the Makefile and has since ceded it and taken a
   dependency on this task.
3. **`status` shows both values rather than just the right one.** The divergence is a real and
   permanent feature of the model, not an error state. Showing `review <- in_progress on main`
   teaches the reader where status lives; showing only `review` would leave the next person to
   rediscover the split the same way this task did.

### Proven on real merges, not just tests
CORE-001 and LVL-000 were both landed with this build of `wt.py` — the first two merges in the
project's history. LVL-000's run shows the conflict path working:

```
rebasing lvl-000-grey-box-mvp-level-55-m-four onto main...
  tasks/LVL-000.md: taking the branch's copy (it holds the handoff)
verifying rebased result...
landed  LVL-000 is on main and marked done
```

The gate also did its job on the way: landing CORE-001 surfaced a real ownership conflict
(CORE-011 and SETUP-004 both owning `Makefile`) that existed on **neither branch alone** and only
appeared on the rebased result. That is the merge queue working exactly as designed, and it is
the argument for verifying the rebase rather than the branch.

### Surprises
- **The tool that gates integration had no tests**, while `check_conventions.py` has twenty. The
  rule "a rule with no test is not a rule" was applied to the conventions and not to the
  machinery enforcing the workflow around them.
- **All four defects share one root cause**: `wt.py` was written but never run end to end,
  exactly like the C++ scaffold CORE-001 found. Nothing in this repo had been executed before
  today. Defects 3 and 4 in particular could not have been found by reading — only by trying to
  merge something.
- **This task committed a `.pyc` and nearly shipped the disease it was curing.**
  `tools/test_wt.py` imports `wt` in a subprocess, which wrote `tools/__pycache__/`, which
  `make wip`'s `git add -A` then committed. Because it was tracked and regenerated on every
  `make ci`, every tree would have gone dirty straight after the gate — and a dirty tree is
  exactly what makes `land` refuse and `wt-status` report AT RISK. A task whose whole purpose is
  making the worktree tooling trustworthy would have handed every future agent a permanent false
  AT RISK. Caught in review. Fixed by running the subprocesses with `python3 -B` so no bytecode is
  written at all, which keeps the fix inside this task's `owns:` and needs no `.gitignore` change.
- **The first test suite did not test the bug it was written for.** All three `land` cases were
  negative — they asserted refusals — so reintroducing the deadlock left the suite green. The
  reviewer proved it by reverting one line. The missing case asserts the *absence* of the status
  refusal: branch at `review`, trunk at `in_progress`, `land` must get past the status check and
  fail later on the missing worktree. Verified by reintroducing the bug: 2 failures, specific
  message. A negative test that passes both with and without the fix is not a test.
- **Each fix revealed the next.** Fixing the status read let `land` reach the rebase, which
  exposed the wrong rebase target, which let it reach the conflict, which exposed the
  misdiagnosed task-file collision. A tool this central needed an end-to-end test on its first
  day, not on the day of the first merge.

### Follow-ups
- `make wt-status` run from inside a worktree lists the trunk checkout as a row with task `?`.
  Harmless, pre-existing, cosmetic — not fixed here to keep this task to its stated scope.
- Nothing else. The `land` path beyond the status check (backup ref, rebase, gate on the rebased
  result, fast-forward) is untouched and was explicitly out of scope.

### Verification
| # | Criterion | Result |
|---|---|---|
| 1 | No-ID commands print a usable message, exit non-zero, no traceback | PASS — all three, verified by test and by hand |
| 2 | Tests for the no-argument path of all three | PASS — `tools/test_wt.py`, 24 cases, 0 failures |
| 3 | `wt-status` does not report a status contradicted by the branch | PASS — reads the branch, shows both on divergence |
| 4 | Authoritative source documented | PASS — `wt.py` module docstring |
| 5 | `make check` passes | PASS — 0 violations, 0 errors; `make ci` also passes, which is what `land` gates on |
| — | *(beyond scope, proven in use)* | CORE-001 and LVL-000 both landed on main with this build |
