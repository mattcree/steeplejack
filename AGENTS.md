# Working in this repo

For anyone — human or agent — picking up work. Read this before your first commit.
The long form is [`docs/06-workflow/`](docs/06-workflow/00-agent-workflow.md).

## Start here

```bash
make ready                   # tasks you can claim right now
make wt-start ID=CORE-003    # isolated worktree + branch, pushed immediately
cd ../sj-core-003
make wip                     # commit + push. Run this constantly. It is the panic button.
make check                   # the gate (no Unreal needed). Green before handoff.
```

You need `cmake`, `ninja` and a C++17 compiler for `make check`. You need **Unreal 5.5 and
`UE_ROOT` set** only for tasks that touch `SteeplejackGame` or `Content/` — most tasks don't.

Then open `tasks/<ID>.md` for the task you claimed. **It is self-contained.** Read it, read the
`spec:` sections it names, and nothing else. If it doesn't give you what you need, that's a bug in
the task — fix the task file and say so in the PR.

## The loop

```
CLAIM → CONTEXT → PLAN → BUILD → VERIFY → HANDOFF → REVIEW → MERGE
```

1. **Claim** — edit your own task file: `status: in_progress`, set `assignee`. Commit that alone.
   One file per task, so claiming never conflicts with anyone.
2. **Context** — the task file and its `spec:` refs. Not the whole repo.
3. **Plan** — if `estimate_days > 1`, write 3–8 bullets into `## Plan` and commit before coding.
4. **Build** — **only in your task's `owns:` paths**, in the worktree `wt-start` made for you.
   Run `make wip` constantly: it commits and pushes in one command, so your work exists off this
   disk from the first minute. See [integration](docs/06-workflow/07-integration.md).
5. **Verify** — your task's `verify:` command, then `make check`, then the applicable sections of
   [`definition-of-done.md`](docs/04-production/definition-of-done.md).
6. **Handoff** — fill in `## Outcome`: what changed, decisions you made, what surprised you,
   follow-up task IDs. Set `status: review`.
7. **Review** — a *different* agent, against the acceptance criteria. Not against taste.
8. **Merge** — **you do not merge.** The integrator runs `make land ID=<your-task>`, which backs up
   your branch, rebases it onto main, re-runs the full gate on the *rebased* result, and
   fast-forwards. One task at a time. If it conflicts, your branch is left untouched.

## Orientation (first time only)

1. [`docs/00-vision.md`](docs/00-vision.md) — pillars and **anti-pillars**
2. [`docs/01-gdd/01-core-loop.md`](docs/01-gdd/01-core-loop.md) — the loop
3. [`docs/01-gdd/02-climbing-system.md`](docs/01-gdd/02-climbing-system.md) — the spine
4. [`docs/03-tech/interfaces.md`](docs/03-tech/interfaces.md) — every signature is already fixed
5. [`docs/03-tech/adr/`](docs/03-tech/adr/) — **ADR-0004 first** (it supersedes 0001), then 0002
   and 0003. Non-negotiable.
6. [`docs/04-production/glossary.md`](docs/04-production/glossary.md) — use these words

## The two-layer split — read this before anything else

Per [ADR-0004](docs/03-tech/adr/0004-engine-change-to-unreal.md), this is an Unreal 5 project whose
gameplay layer **is not an Unreal module**:

| Layer | Owner | Format | Verified |
|---|---|---|---|
| `Source/SteeplejackSim/` | **agents** | plain C++17, no Unreal | ✅ CMake + doctest, ~20 s, **no engine needed** |
| `data/` `tools/` `tests/` `docs/` | **agents** | text | ✅ ~3 s |
| `Source/SteeplejackGame/` | agents + humans | C++ with Unreal | partially (UE automation) |
| `Content/` | **humans** | binary, Git LFS | ❌ visual review only |

**`SteeplejackSim` must compile standalone under CMake with no Unreal installed.** That is not a
style rule — it is what keeps the gameplay layer fast to test and editable by agents on an engine
whose asset formats are binary. `make build-sim` proves it on every commit.

If a task needs the editor, it is tagged `editor_required: true` and batched. `make editor-queue`
keeps that visible; if that queue grows faster than it is cleared, that is risk **R8**.

## Rules that are actually enforced

`make check-conventions` fails the build on all of these. Full list and rationale in
[`04-enforced-conventions.md`](docs/06-workflow/04-enforced-conventions.md).

1. **`SteeplejackSim` is pure.** No Unreal headers, no `FVector`/`TArray`/`UObject`/`FMath`, no
   `.generated.h`, no `std::chrono`, no `rand()`, no mutable statics, no `printf`.
2. **No magic numbers in `SteeplejackSim`.** Constants live in `data/tuning/*.json`. Annotate a
   genuine exception with `// literal: <reason>`.
3. **No hand-placed level geometry.** Levels are JSON; structures are generated at runtime. A
   `.umap` holds lighting, sky and spawn points — nothing else.
4. **Blueprints are glue only.** No Blueprint may tick or contain a gameplay decision. If it has an
   `if` about game rules, it belongs in `SteeplejackSim`.
5. **Ascent Beat Rule** — no `plain` band over 20 m. The validator enforces it.
6. **No real person's name anywhere**, including commit messages. See
   [the IP policy](docs/05-legal/ip-and-likeness.md).
7. **Every failure has a telegraph, shipped in the same task.** See the
   [fairness contract](docs/01-gdd/10-failure-and-difficulty.md#the-fairness-contract).
8. **Every audio cue has a visual fallback.** See [accessibility](docs/01-gdd/14-accessibility.md).
9. **The docs are the spec.** If your code and a doc disagree, one is a bug — decide which, fix it,
   and say which in the PR.

## Never lose work

Two commands and one rule:

```bash
make wip        # commit + push. Before anything structural, and whenever you pause.
make doctor     # what exists only on this disk?
```

**The rule:** if `.claude/hooks/git_guard.py` blocks a command, that means *commit first* — not
*find another way to run it*. It blocks `reset --hard`, `checkout -- .`, `restore`, `clean -fd`,
`worktree remove`, `push --force`, `branch -D` and bare `rebase`, because those destroy work that
the reflog cannot recover. Every one of them has a safe alternative in the block message.

Never `git worktree remove`. Use `make wt-drop`, which refuses if anything would be lost.

## Guess vs. escalate

**Guess freely:** naming, file layout inside your owned paths, test structure, private helpers,
formatting, log messages.

**Never guess:** game design, tuning targets, whether a failure needs a telegraph, whether code
belongs in `sim/` or `game/`, scope.

When blocked: set `status: blocked`, fill in `## Blocked` with *the question, what you tried, the
options, and your recommendation*, commit, and pick up another ready task. Don't sit on it and
don't invent an answer.

## Adding things

**A level** — copy [`docs/02-levels/LEVEL-TEMPLATE.md`](docs/02-levels/LEVEL-TEMPLATE.md), fill in
every heading, write `data/levels/NN-slug.json`, `make validate`, play it, record an expert replay,
update the status table in [`level-index.md`](docs/02-levels/level-index.md).
**Target: idea → playable in under thirty minutes.** If that stops being true, stop and fix the
tooling — it's what makes twelve levels affordable.

**A band type** — exactly two places: a generator in `SteeplejackSim/Private/Joints.cpp`, and a
parameter on the brick master material. Plus the enum in the schema and a row in
[`data-schemas.md`](docs/03-tech/data-schemas.md).

**A task** — `make new-task ID=CLIMB-012 TITLE="..."`. Discovered work becomes a task, never a
scope expansion.

**An interface** — write the signature into
[`interfaces.md`](docs/03-tech/interfaces.md) *first*, then the implementation tasks. Never change a
signature while someone is implementing against it.

**A material or an asset** — that is `Content/`, it is binary, it is human-owned, and it goes
through Git LFS. Agents brief it; they do not author it.

## Things that get a PR rejected

- An Unreal include, an Unreal type, or a magic number in `SteeplejackSim`
- A gameplay decision in a Blueprint, or a ticking Blueprint
- A binary asset committed without Git LFS
- Files changed outside the task's `owns:` (undeclared)
- A gameplay decision made in `SteeplejackGame` instead of `SteeplejackSim`
- A new mechanic with no telegraph, or an audio cue with no visual fallback
- A third meter (see the anti-pillars)
- An empty `## Outcome`
- "Press E to work" — any interaction the player cannot perform better or worse
- A real person's name, anywhere

## If you disagree with the design

Good. Say so in the task's `## Blocked` or an issue, and argue it against the pillars and
anti-pillars. The design is written down precisely so it can be argued with. What you must not do
is quietly implement something different.
