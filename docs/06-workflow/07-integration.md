# Integration — parallel work without conflicts or lost work

> Two things go wrong when several agents work at once: **the merges get ugly**, and **work
> disappears**. This document is how this repo prevents both. Every mechanism here is verified —
> see [Proof](#proof) at the end.

## The model, in one line

> **Parallel generation, sequential merging.**

Agents generate simultaneously in isolated worktrees. Work integrates **one task at a time**, each
one rebased onto a trunk that is always green and fully re-verified before the next starts. This is
the 2026 consensus for multi-agent development, and it is what stops "six green branches that don't
work together".

```
   agent A ──[worktree]──┐
   agent B ──[worktree]──┼──► make land ──► verify ──► main ──► next
   agent C ──[worktree]──┤     (one at a       │        (always
   agent D ──[worktree]──┘      time, locked)  │         green)
                                               └─ fails? branch untouched,
                                                  backup already on origin
```

---

## Part 1 — Not getting conflicts

Conflicts are **prevented upstream**, not resolved downstream. Four layers, in order of when they
act:

### Layer 1: file ownership (prevention)

Every task declares `owns:` — the only paths it may write. `make validate-tasks` **refuses** two
tasks that could run concurrently and want the same file:

```
error ownership conflict: ZZZ-002 and ZZZ-003 both own
      'docs/scratch-integration-test.md' and neither depends on the other
```

Tasks linked by a dependency chain may overlap, because they cannot run at the same time.

**This is the layer that does the real work.** Most teams only have layers 2–4, which are recovery
mechanisms. This one means the conflict never happens.

### Layer 2: interface-first (prevention)

[`docs/03-tech/interfaces.md`](../03-tech/interfaces.md) fixes every signature **before** any
implementation starts. That is why `Stack.cpp` and `MetersGrip.cpp` can be written simultaneously by
two agents who never communicate: the contract between them was settled in advance.

Changing a signature while someone is implementing against it is an escalation, not a commit.

### Layer 3: worktree isolation (containment)

One worktree per task — same repository, separate working directory, separate branch. An agent
physically cannot touch another agent's files.

```bash
make wt-start ID=CORE-003     # ../sj-core-003 on branch core-003-seeded-rng
```

`git rerere` is enabled in every worktree, so a conflict resolved once is resolved forever.

### Layer 4: serialized merging (resolution)

When a conflict does happen, it is always **one branch against a known-good trunk** — never six
branches against each other. `make land` reports it and diagnoses the cause:

```
CONFLICT rebasing zzz-003-conflict-probe onto main. Rebase aborted; your branch is untouched.

Conflicted files:
  docs/scratch-integration-test.md

A conflict here means the ownership model was violated.
Two tasks wrote the same file without a dependency between them, or someone
worked outside their `owns:` globs.
```

**A conflict in this repo is a process bug, not a fact of life.** Treat it as a signal that layer 1
was bypassed, and say so in the PR.

### Overlap zones

A few files are read by nearly everything: `interfaces.md`, `Types.h`, `data/tuning/*.json`,
`Tuning.h`. A task that *owns* one of these serializes a large part of the graph behind it.

Rules:
- Land them early, alone, and fast.
- Never batch an interface change with an implementation change.
- A task owning an overlap-zone file gets a human review, always.

---

## Part 2 — Not losing work

Git loses work in exactly two ways, and only one of them is recoverable.

| | What causes it | Recoverable? |
|---|---|---|
| **Orphaned commits** | force-push, `branch -D`, `reset --hard` past a commit, worktree removal | From reflog — but the reflog is **local**, is **empty in a fresh clone**, and is **garbage-collected in ~30 days** |
| **Destroyed uncommitted edits** | `reset --hard`, `checkout -- .`, `restore`, `clean -fd`, worktree removal | **Never.** The reflog cannot bring these back. |

So the defences are ordered accordingly:

### Defence 1: the work leaves this disk immediately

`make wt-start` **pushes the branch the moment it is created.** From minute one, the work exists on
origin, where no local mistake can reach it.

### Defence 2: `make wip` — the panic button

```bash
make wip                    # commit everything, push, one command
make wip M="halfway through the span table"
```

Agents are instructed to run this constantly, and always before anything structural. It converts the
unrecoverable failure mode (uncommitted edits) into the recoverable one (commits), and then pushes
so even that doesn't matter.

### Defence 3: destructive commands are blocked, not discouraged

`.claude/hooks/git_guard.py` is a `PreToolUse` hook that **blocks** the commands that destroy work,
and names the safe alternative:

| Blocked | Because |
|---|---|
| `git reset --hard/--merge/--keep` | destroys uncommitted changes; reflog cannot recover them |
| `git checkout -- <path>` | same |
| `git restore` without `--staged` | same (`--staged` alone is allowed — it only unstages) |
| `git clean -f[dx]` | deletes untracked files, including ones you just wrote |
| `git worktree remove` | **takes unmerged branches and uncommitted edits with no warning** |
| `git push --force` | orphans commits on the remote (`--force-with-lease` is allowed) |
| `git branch -D` | deletes unmerged branches (`-d` is allowed — it refuses) |
| `git stash drop/clear` | discards stashed work |
| `git rebase` by hand | use `make land`, which backs up first |
| `git push origin main` | agents never push to trunk |
| `rm -rf .git` | — |

It is deliberately conservative: a false block costs ten seconds, a false allow costs a day.
**Being blocked means "commit first", not "find another way to run this."**

### Defence 4: `make wt-drop` refuses

The single most common way agent work is lost is `git worktree remove` on a worktree that still
holds something. `make wt-drop` checks three things and **refuses** rather than asking:

```
REFUSING to drop /var/home/cree/projects/sj-zzz-001

  ! branch 'zzz-001-...' is not merged into main

`git worktree remove` would take all of this with no warning.

  To keep it:  cd ... && make wip
  To land it:  make land ID=ZZZ-001
  To discard:  make wt-drop ID=ZZZ-001 FORCE=1   (takes a pushed backup first)
```

Even `FORCE=1` commits whatever is there and pushes a `backup/` branch before removing anything.

### Defence 5: backup refs, on origin, before every risky operation

`make land` pushes `backup/<task>-<timestamp>` **before** it rebases. If the rebase, the gate, or
the merge goes wrong, the pre-rebase state is already on the remote. Backups are branches, not
reflog entries, so they survive a fresh clone, a dead disk, and thirty days.

### Defence 6: `make doctor`

```bash
make doctor      # what exists only on this disk?
make wt-status   # per worktree: uncommitted? unpushed? at risk?
```

`wt-status` ends with one of two lines, and there is no third:

```
All work is pushed. Nothing would be lost if this disk died.
2 item(s) exist only on this disk. Run `make wip` in each affected worktree.
```

---

## The commands

```bash
make ready                   # what can I claim?
make wt-start ID=CORE-003    # isolated worktree + branch, pushed immediately
cd ../sj-core-003
#   ... work ...
make wip                     # commit + push. Constantly.
#   ... set status: review, hand to a reviewer ...
make land ID=CORE-003        # backup → rebase → full gate → fast-forward → push
make wt-drop ID=CORE-003     # refuses unless merged and pushed
```

## What `make land` actually does

```
 1. refuse unless the task is at status: review     (reviewed by a different agent)
 2. refuse if the worktree is dirty                 (never lose it here)
 3. acquire a lock                                  (one land at a time, always)
 4. push backup/<task>-<timestamp> to origin        (before anything risky)
 5. rebase onto origin/main, rerere enabled         (linear history, no merge commits)
       conflict? abort, branch untouched, diagnose, exit
 6. run `make ci` ON THE REBASED RESULT             (not on what the agent tested)
       fail? stop, branch untouched, backup safe, exit
 7. fast-forward main, push                         (trunk only ever advances)
 8. mark the task done
```

**Step 6 is the one people skip.** An agent verifies its branch in isolation; by the time it lands,
the trunk has moved. Verifying the *rebased* result is what makes "main is always green" true rather
than aspirational.

Step 7 is fast-forward only. The trunk is never merged into and never has a merge commit — history
stays linear and `git bisect` stays useful.

## Stacked work

Dependency chains (`CORE-004 → CORE-007 → CORE-005`) are naturally stacked. Land them **in
dependency order**, one at a time. `make waves` gives you the order; `make critical` gives you the
chain that matters.

Do not open the whole stack at once for review — review and land the base, then rebase the next.
Each land is verified against a trunk that already contains its dependency.

## Caps

| | Value | Why |
|---|---|---|
| Concurrent worktrees | **4** | 4–8 is the field's reliable range; above that you are bottlenecked on review, not on the agents |
| Unreviewed branches | 3 | more than that and `make board` is a queue, not a status |
| Concurrent `land` | **1** | enforced by a lock file. Non-negotiable — it is the whole model. |

## Proof

Every claim above was verified on this repository with scratch tasks, which were then deleted:

| Behaviour | Result |
|---|---|
| `wt-start` creates an isolated worktree and pushes the branch | ✅ |
| `wip` commits and pushes; `wt-status` reports "nothing would be lost" | ✅ |
| An uncommitted edit flips `wt-status` to `AT RISK` and names it | ✅ |
| `wt-drop` refuses an unmerged branch | ✅ |
| `land` rejected a task whose `## Outcome` was empty — the DoD, enforced at the gate | ✅ |
| `land` succeeded after the violation was fixed, fast-forwarding main | ✅ |
| **The validator caught two tasks owning the same file, before any work started** | ✅ |
| **A genuine conflict aborted the rebase, left the branch untouched, named the files, and diagnosed the cause** | ✅ |
| `FORCE=1` drop pushed a backup branch before removing anything | ✅ |
| The git guard: 25 cases, 0 mismatches (12 blocked, 13 allowed) | ✅ |

The one thing not yet proven: none of this has run under real load with four agents at once. The
mechanisms work; the caps are inherited from the field's experience, not from ours.
