---
id: TEST-003
title: Make filtered test gates fail loudly on zero matches
milestone: M0
discipline: [ENG]
estimate_days: 0.5
status: in_progress
assignee: agent
depends_on: [CORE-003, SETUP-004, CORE-011]
owns:
  - Makefile
  - tools/check_verify.py
reads:
  - tasks/CORE-003.md
  - tools/tasks.py
spec:
  - docs/06-workflow/03-verification.md
verify: make check-verify
editor_required: false
risk: null
---

## Goal
No task's `verify:` command can report success while running zero tests.

## Why
`make test-unit FILTER=rng` reported `SUCCESS` against **0 of 23 test cases** during CORE-003,
because doctest's `--test-case` matches case *names* and none contained "rng". The task's own
stated verification passed without running anything.

That is not a one-off. About **25 tasks** carry a `FILTER=` in their `verify:`, and several name
a *file* rather than a plausible case name:

| Task | `verify:` filter | Likely case names |
|---|---|---|
| CORE-004 | `FILTER=test_types` | a file name, not a case name |
| CORE-008 | `FILTER=test_level` | a file name, not a case name |
| CORE-006 | `FILTER=replayroundtrip` | no spaces; unlikely to match |
| METER-004 | `FILTER=test_recovery` | a file name, not a case name |
| VERB-006 | `FILTER=lashinput` | no spaces; unlikely to match |

Every one of those is a task that can be implemented, handed off, reviewed and **landed** with its
stated verification never having executed. The reviewer's phrase for it is the right one: a suite
that rots into decoration.

## Context
**The repo already solved this and then did not apply it.** `Makefile:68-75` defines a `gate()`
helper whose own comment reads:

> A filtered gate that matches zero test cases must NOT report success — that is how a suite rots
> into decoration. `gate()` prints an explicit "not yet meaningful" instead.

It counts matching cases via `--list-test-cases` and prints `-- <name>: no such tests yet` rather
than a green tick. `test-levels`, `test-replay` and `test-determinism` all use it.

`test-unit` (`Makefile:63-65`) does not — and `test-unit` is the target nearly every task's
`verify:` runs through. The mechanism exists; it is wired to the wrong targets.

Note the distinction `gate()` draws, and keep it: a filter matching zero cases *before the module
exists* is expected and should print a note, not fail. A filter matching zero cases when the task
claiming it is at `review` is a broken verification. `make check` must stay green on a fresh
clone where most modules do not exist yet.

`tools/tasks.py` already parses every task's frontmatter, so the audit half of this is a loop over
`verify:` strings, not new parsing.

**Ownership note:** SETUP-004 and CORE-011 also own the `Makefile` (it wires `tools/test_wt.py` into
`test-tools`). It has already landed, so this dependency is satisfied — it is declared because the
task-graph validator rejects two tasks owning one path without one, and because whoever picks this
up should read SETUP-004's Outcome first: it is the other half of "the tooling was written but
never run".

## Interface
No C++. One Makefile target and one Python checker.

## Acceptance
1. `make test-unit FILTER=<something-that-matches-nothing>` does **not** print `SUCCESS`. It says
   plainly that the filter matched zero cases.
2. `make test-unit` with no filter is unchanged.
3. `make check` is still green on a fresh clone where most modules do not exist — the
   "not yet meaningful" path must stay distinguishable from failure.
4. `tools/check_verify.py` cross-checks every task's `verify:` filter against the case names the
   test binary actually exposes, and reports any task at `status: review` or `done` whose filter
   matches nothing.
5. The checker has its own tests (`tools/test_conventions.py` is the precedent — no untested
   rules).
6. The ~25 existing `FILTER=` values are audited. Fix the ones that cannot ever match, or record
   in this task's Outcome which are pending their module and therefore expected to match zero
   for now.

## Out of scope
Do not rename existing test cases in other tasks' files to make filters match — that is each
task's own business. Report them. Do not change what `test-unit` runs when unfiltered.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
