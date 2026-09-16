# Launch — what "go" means

> This document turns a backlog into a running project. It is the answer to "we said go, now what?"

## Before the first "go" — the preflight

These are one-time, and **every one of them is the project lead's, not an agent's.**

| # | Check | Command / where | Status |
|---|---|---|---|
| 1 | `make check` is green on the machine agents will run on | `make check` | ✅ 0.4 s warm |
| 2 | Toolchain present: cmake, ninja, a C++17 compiler | `cmake --version` | ✅ |
| 3 | Convention checkers have their own tests | `python3 tools/test_conventions.py` | ✅ 20 cases |
| 4 | **Likeness denylist populated** | `tools/likeness_denylist.local.txt` | ⬜ **inert** |
| 5 | Git LFS enabled on the remote | CORE-010 | ⬜ |
| 6 | Unreal 5.5 installed somewhere, `UE_ROOT` set | for CORE-001's second half | ⬜ |
| 7 | A human named for the editor queue | `make human-queue` | ⬜ |
| 8 | You are reachable for escalations | `BLOCKED.md` | ⬜ |
| 9 | The git guard hook is active | `.claude/settings.json` → `hooks.PreToolUse` | ✅ 25 cases |
| 10 | `make doctor` reports nothing at risk | `make doctor` | ✅ |

**Items 4, 7 and 8 are not optional.** Without 4, rule 16 is decorative on the project's highest-IP-
risk task. Without 7, a third of the work has no owner. Without 8, the fleet stalls the first time
somebody needs a design decision — which will be within hours, not days.

Items 5 and 6 gate specific tasks, not the whole run.

## What a "go" actually starts

```bash
make ready
```

Two queues come back, and the split matters more than anything else in this document:

```
AGENT-CLAIMABLE (n)   — an agent can do these start to finish
NEEDS A HUMAN (m)     — Unreal editor, a recording, or a room full of testers
```

**Spawn agents only for the first queue.** The second is your personal backlog and it runs in
parallel with the fleet, not after it.

### The run loop

```
1.  make ready
2.  spawn one `implementer` agent per AGENT-CLAIMABLE task, capped at 4.
       each starts with:  make wt-start ID=<task>
3.  keep 1 `reviewer` free per 3 implementers
4.  as each agent reports:
       status: review   -> hand to a reviewer
       status: blocked  -> it has appended to BLOCKED.md. Answer it, or park it.
       PASS from review -> make land ID=<task>      (one at a time, lock-serialized)
                           make wt-drop ID=<task>
5.  make doctor                                      (is anything only on this disk?)
6.  goto 1
```

Integration is [`07-integration.md`](07-integration.md) and it is not optional: agents never merge
and never push to `main`.

### The caps, and why

| Cap | Value | Why |
|---|---|---|
| Concurrent implementers | **4** | not 6. Review is the bottleneck, and merge conflicts rise superlinearly even with `owns:` protection. |
| Reviewers | 1 per 3 implementers | a reviewer who is also implementing is not a reviewer |
| Unreviewed branches | 3 | if `make board` shows more than 3 in `review`, **stop claiming and start reviewing** |
| Open blocked tasks | 5 | past this the fleet is guessing or idling. Stop and clear `BLOCKED.md`. |

`owns:` makes parallel work *safe*; it does not make it *free*. Every extra agent costs you review
attention, which is the actual scarce resource.

## The three queues you are managing

```
    AGENT QUEUE            HUMAN QUEUE              BLOCKED QUEUE
    make ready             make human-queue         BLOCKED.md
    ────────────           ────────────             ────────────
    agents claim           you do these             you answer these
    4 at a time            in parallel              within a day
         │                      │                        │
         └──────────► make board ◄──────────────────────┘
```

If any one of the three stalls, the other two stall behind it within a day or two. The one that
stalls first, in practice, is **BLOCKED**, because it is the only one that needs a specific human
to have a specific opinion.

## Stopping conditions

A run stops — cleanly, not by running out of things to do — when **any** of these is true:

1. **A milestone gate is reached.** M1's gate (PT-001) is the only one that can kill the project,
   and it is a human activity with eight strangers in a room. Agents cannot pass it for you.
2. **`BLOCKED.md` has 5 or more open questions.** The fleet is now guessing or idling.
3. **The human queue exceeds 12 ideal days.** That is risk **R8** and it means the agents are
   outrunning the only person who can do editor work.
4. **Three consecutive tasks fail review on the same criterion.** Something upstream is wrong — a
   spec section, an interface, or a Definition-of-Ready failure. Fix the cause, not the tasks.
5. **You hit your budget.** Decide this in advance and write it down; it is much harder to decide
   at 2am with eleven branches open.

## What agents may not do, ever

Regardless of what a task says:

- **Merge their own work.** Review is a different agent, always.
- **Push to `main`.** Branches and PRs only.
- **Change `docs/03-tech/interfaces.md`** outside a task that owns it. Other agents are
  implementing against those signatures right now.
- **Answer their own escalation.** Blocked means blocked.
- **Touch `Content/`.** It is binary, it is human-owned, and it goes through Git LFS.
- **Populate the likeness denylist.** That is the project lead's, deliberately.

## The first run, concretely

At the time of writing, `make ready` gives:

```
AGENT-CLAIMABLE (2)
  CORE-001   Unreal project, two modules, and the standalone sim build   1.5d
  LVL-000    Grey-box MVP level (55 m, four bands)                       0.5d

NEEDS A HUMAN (4)                                       10.5 ideal days
  ART-020    The character                                               5d
  AUD-001    The four tap-test sounds                                    2d
  AUD-004    Rope, ladder, boot and breathing foley                      2d
  ENV-002    Town silhouette backdrop                                    1.5d
```

**So the first "go" starts two agents, not six** — and CORE-001 can only be half-verified until
someone installs Unreal. That is an honest picture of a project at day zero, and it widens fast:
CORE-001 unblocks four tasks, which unblock nine.

The rate limiter for the first week is **you**, not the fleet. Ten and a half days of human work is
already queued and nothing an agent does will reduce it. Start ART-020 and AUD-001 yourself, today,
in parallel with the first agents.
