---
id: TEST-003
title: Make filtered test gates fail loudly on zero matches
milestone: M0
discipline: [ENG]
estimate_days: 0.5
status: done
assignee: agent
depends_on: [CORE-003, SETUP-004, CORE-011]
owns:
  - Makefile
  - tools/check_verify.py
  - tools/test_check_verify.py
  - docs/06-workflow/03-verification.md
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
Three changes: `test-unit` now fails on a zero-match filter, `tools/check_verify.py` audits every
task's filter repo-wide, and `docs/06-workflow/03-verification.md` no longer teaches the bug.

**What changed**

- `Makefile` — `test-unit` with a `FILTER` that matches no test case prints `FAILED ... matched 0
  of N test cases — nothing ran` and **exits 1**. Unfiltered runs go down the original code path
  untouched. New `check-verify` target, wired into `make ci`; `test-check_verify` added to
  `test-tools`.
- `tools/check_verify.py` — cross-checks every task's `verify:` filter against the case names the
  built binary actually exposes. Errors on `review`/`done` with zero matches; notes the rest.
- `tools/test_check_verify.py` — 14 cases, each asserting the verdict rather than just the exit
  code (acceptance 5 / the enforced-conventions rule "a rule with no test is not a rule"). The
  harness counts the cases it actually ran and fails if that is zero — see the review note below.
- `docs/06-workflow/03-verification.md` — see the ownership note below.

**Decisions**

- *`test-unit` exits non-zero; the three `gate()` targets keep their note.* The task asks to keep
  gate()'s distinction, and this is that distinction, drawn where it actually lives. `test-levels`
  and friends run on every CI build of a fresh clone, where missing tests are correct — a note.
  `test-unit FILTER=` is only ever run by a task's own `verify:`, to assert that task *was*
  verified; there, zero matches means the verification did not happen. The Goal says a verify
  command must not "report success" while running nothing, and a command reports success by
  exiting zero, so a note alone would not have satisfied it. `make check` passes no `FILTER`, so
  acceptance 2 and 3 are untouched — confirmed by running both.
- *The failure message teaches the actual mistake.* It states that doctest matches TEST_CASE
  *names*, not file names, and lists the name prefixes currently in the binary. Every filter in
  the task's table is the same error made five times; the fix is worth more if the message
  prevents the sixth.
- *"Cannot read the test binary" is an error, not an empty list.* `check_verify.py` returns `None`
  rather than `[]` when the binary is missing and refuses to report green. A checker for this bug
  that reported success while checking nothing would be the same bug wearing the costume of its
  own fix. There is a test for it.
- *File-shaped filters are a warning, not an error.* A filter starting `test_` cannot match a
  `<Module>: <sentence>` case name, whatever module lands later — but it cannot be *proven* wrong
  until that module exists, so it warns (`??`) rather than fails. It flags exactly the three the
  task's table names.
- *`test-automation` filters are reported as unchecked, not as passes.* They run inside Unreal and
  this checker cannot see them. Counting them as green would be the original bug again.

**Audit of the 26 existing filters** (acceptance 6) — `make check-verify` prints this live:

| Verdict | Count | Which |
|---|---|---|
| runs real tests | 1 | CORE-003 `rng` (19 cases) |
| **names a file, can never match** | 3 | CORE-004 `test_types`, CORE-008 `test_level`, METER-004 `test_recovery` |
| pending its module | 19 | CLIMB-001/2/6, CORE-005/6/7, ENV-003, METER-001/2/3/5, STRUCT-002, VERB-001/3/4/5/6/7, TASK-TEMPLATE |
| not checkable here | 3 | CAM-001, CLIMB-004, PLAYER-001 — `make test-automation`, needs the engine |

Not fixed in this task's files, per **Out of scope** ("Report them") and because `tasks/*.md` are
not in this task's `owns:`. Three of them need a human decision or their own task:

- **CORE-004** `test_types` → `types`. Already fixed on branch `core-004-sim-data-types`, which is
  at `review`; it lands with that task.
- **CORE-008** `test_level` → `level`. Unclaimed. Whoever claims it will now be told by the
  Makefile at handoff instead of discovering it never ran.
- **METER-004** `verify:` is not a runnable command at all: `make test-unit FILTER=test_recovery,
  plus a video of the tea break for review.` The prose is appended to the shell line. Two problems
  in one line — the filter, and the fact that a `verify:` field must be a single command per
  `03-verification.md`. Needs its own task or an integrator fix.
- **CORE-006** `replayroundtrip` and **VERB-006** `lashinput` are flagged in the task's table as
  unlikely to match. They are *possible* (a case named `ReplayRoundTrip: ...` would match), so the
  checker cannot call them wrong and neither can I. They are now self-correcting: they will fail
  at handoff instead of passing silently.

**Ownership note**

`docs/06-workflow/03-verification.md` was added to `owns:`. It was in `spec:` only, but it is the
document that *taught* this bug: its "Writing a verify command" section gave
`make test-unit FILTER=test_stack_spans` as the recommended example — file-shaped, matches nothing.
Fixing the Makefile while leaving that example in place would have kept minting broken filters for
the next twenty tasks. CORE-011 owns the same file and is `done` and already in this task's
`depends_on`, which is the condition the task-graph validator requires for shared ownership; `make
validate` passes. The doc now documents both mechanisms, the exit-code difference between them and
why, and adds `check-verify` to the ladder.

**Surprises**

- The repo had already written the fix and wired it to the wrong targets, exactly as the task
  says. What the task does not say is that the *documentation* had the bug too, in the one section
  that tells agents how to write the field this task is about.
- CORE-003 is the only task whose `verify:` currently runs anything at all. 25 of 26 filters match
  zero test cases today. That is expected — the modules are unwritten — but it means this gate was
  protecting one task, and `make check-verify` is what will keep it honest as the other 25 land.

**Caught in review**

The first version of `test_check_verify.py` printed `15/15 cases passed` from a hardcoded `n = 15`
while running 14. Deleting a case left it still reporting 15/15 and exiting zero — a test harness
reporting a total it had not measured, which is this task's own bug one level up, inside the fix
for it. It now counts cases as they run and fails if none did. Worth recording rather than
quietly fixing: the failure mode is attractive enough to have been written by someone who had
just spent a day removing it.

**Follow-ups**

- METER-004's malformed `verify:` line (above). Needs a task.
- CORE-008's filter (above). Cheap; worth doing before someone claims it.
