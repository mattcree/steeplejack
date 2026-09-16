---
id: SETUP-005
title: Land must not depend on rerere's memory
milestone: M0
discipline: [ENG]
estimate_days: 0.25
status: review
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
`make land` completes on a branch with several commits touching its own task file, and does
not depend on which conflicts this particular disk has resolved before.

## Why
`land` stopped mid-rebase and refused to merge CORE-003:

```
STOPPED `git rebase --continue` failed with no conflicted paths.
```

Integration was blocked again, one task after SETUP-004 unblocked it.

**The cause is `rerere`, not an empty commit.** `wt-start` enables `rerere.enabled` and
`rerere.autoupdate` on every worktree, deliberately, so that a human solves a given conflict once.
But `land` resolves the task-file conflict *itself*, every time. On a second attempt rerere
recognised the conflict, replayed the remembered resolution and **auto-staged it** — leaving the
rebase stopped with **zero unmerged paths**. `land`'s loop assumes a stop means something is
unmerged, found nothing to resolve, and bailed.

Git said so plainly and the tool was discarding the message:

```
Staged 'tasks/CORE-003.md' using previous resolution.
Could not apply 4ba8355... CORE-003: set review on the branch
```

That also explains why it passed and then failed: the first land attempt had nothing remembered.

## Context
`tools/wt.py`, `_land`. Two things follow:

1. **Run the rebase with `rerere.enabled=false`.** A merge queue must do the same thing on every
   machine. Whether a land succeeds should not depend on which conflicts this particular disk has
   seen before — that is unreproducible by construction. `land` applies its own resolution
   deterministically, so rerere can only disagree with it.
2. **Keep rerere on for worktrees.** `wt-start` should not change. Solving a real conflict once is
   worth having; it is only inside `land`'s own automated resolution that it is harmful.

The stall path must also print git's message rather than a guess. It had all the evidence and
reported none of it — which is why the first diagnosis was wrong.

## Interface
No C++. `wt.py` only.

## Acceptance
1. A branch with several commits touching its own task file lands cleanly on a worktree with
   `rerere.autoupdate` enabled — i.e. on every worktree `wt-start` makes.
2. `land` still aborts with the branch untouched when the rebase stops for a reason it does not
   understand, and prints git's own message when it does.
3. The test fixture configures rerere the way `wt-start` does, so it exercises a real worktree.
4. `docs/06-workflow/07-integration.md` says the rebase runs with rerere disabled, and why.
5. `make check` and `make test-tools` pass.

## Out of scope
No other change to the merge queue. Do not widen what `land` resolves on its own authority —
SETUP-004's review concluded the narrowness is what makes it acceptable. Do not turn rerere off
for worktrees; it is only `land`'s own rebase that must not depend on it.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
`make land` no longer depends on what conflicts this disk has seen before. CORE-003 landed with
this build — it was the task the stall was blocking.

### What changed
- `tools/wt.py` — `_land`'s rebase and its `--continue` calls run with `rerere.enabled=false`.
  The no-unmerged-paths branch now continues if the rebase is merely stopped with the resolution
  already staged, and otherwise stalls **printing git's own message**.
- `tools/test_wt.py` — the origin fixture now sets `rerere.enabled`/`rerere.autoupdate` exactly as
  `wt-start` does, and its branch carries two commits touching the task file.
- `docs/06-workflow/07-integration.md` — records that the rebase runs with rerere off, and why.
- `tasks/SETUP-005.md` — rewritten; the original diagnosis was wrong. See below.
- `tasks/SETUP-006.md` — **new, outside `owns:`.** Raised for the `wt-start` surprise below.

### I diagnosed this wrong before measuring it, and the wrong fix would have destroyed work
I wrote this task asserting the cause was "a commit became empty once its conflict was resolved",
and specified `git rebase --skip` as the fix. **`--skip` discards a commit.** Had the fixture
reproduced my theory instead of the real fault, `land` would have silently dropped a commit from
every branch that tripped it, to fix a problem that did not exist.

What caught it was not care — it was that the fix did not work. Landing CORE-003 with it produced
"git does not report the commit as empty", which is the tool disagreeing with the task file. Only
then did I print git's actual stderr and find `Staged '...' using previous resolution`.

This is the fifth time today I have asserted a checkable claim about what git would do without
running the command that settles it, and the first where the wrong answer would have cost data
rather than credibility. The rule that would have prevented all five: **print what the tool said
before writing down what you think it meant.** The stall path now does exactly that.

### Surprises
- **`wt-start` makes an unusable worktree for a task that is not yet on `origin/main`.** It cuts
  the branch from `origin/main`, so a task created with `make new-task` and claimed immediately
  produces a branch with **no task file on it**. Hit while setting this task up. Agents cannot
  push main, so a freshly created task cannot be worked on until some other land pushes the trunk.
  Not fixed here — it needs a decision about where new tasks enter, which is integration-model
  territory. Recorded in follow-ups.
- **rerere is enabled precisely because conflicts here are repetitive**, which is also exactly why
  it broke the one conflict that is resolved automatically. The feature and the bug have the same
  cause.

### Follow-ups
- **SETUP-006** — `wt-start` on a task not yet on `origin/main` silently yields a branch without
  its own task file. Filed rather than left in prose: it is latent for *every* newly created task,
  and a follow-up buried in one task's Outcome is a follow-up nobody finds.
- **A direct test for the rerere-replay path is cheaper than I claimed.** I wrote that reproducing
  it needs more than the fixture can do; the reviewer built it in a sandbox in minutes — seed the
  fixture's `rr-cache` by running one conflicting rebase-and-resolve in the worktree, reset the
  branch back, then land. About ten lines. Not done here because with `rerere.enabled=false` the
  replay state is unreachable by construction, so the test would guard against someone deleting
  the `-c` flag rather than against a live fault. Worth having; not worth blocking on.

### Verification
| # | Criterion | Result |
|---|---|---|
| 1 | Multi-commit branch lands with rerere enabled | PASS — CORE-003 landed, four commits touching its own task file |
| 2 | Aborts untouched on an unrecognised stop, printing git's message | PASS — observed twice while diagnosing |
| 3 | Fixture configures rerere as `wt-start` does | PASS |
| 4 | `07-integration.md` records the rerere decision | PASS |
| 5 | `make check` and `make test-tools` pass | PASS |
