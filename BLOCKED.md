# Blocked — questions waiting on a human

> One place to look. Agents append here when they set a task to `status: blocked`; the project lead
> answers. **If this file has 5 or more open rows, stop claiming new work and clear it** — the fleet
> is either guessing or idling. See [the launch procedure](docs/06-workflow/06-launch.md).

Agents: append a row, keep the detail in your task's `## Blocked` section, and pick up nothing else
until the orchestrator assigns it.

Lead: answer in the task file's `## Blocked` under **Answer:**, set the task back to `ready`, and
move the row to Resolved with the date.

## Open

| Task | Raised | The question, in one line | Recommendation |
|---|---|---|---|
| — | — | *(nothing blocked)* | — |

## Standing decisions the lead owes the project

These are not agent escalations — they are preflight items that nothing can proceed past.
See [`docs/06-workflow/06-launch.md`](docs/06-workflow/06-launch.md).

| # | Decision | Blocks | Status |
|---|---|---|---|
| 1 | Populate `tools/likeness_denylist.local.txt` | rule 16 is inert; ART-020 is the highest-risk task for it | ⬜ open |
| 2 | Name a human for the editor queue (10.5 days already queued) | ART-020, AUD-001, AUD-004, ENV-002, and everything downstream | ⬜ open |
| 3 | ~~Install Unreal and set `UE_ROOT`~~ | CORE-001's second half, and all of `SteeplejackGame` | ✅ closed 2026-09-17 — UE **5.8.2** at `/var/home/cree/UnrealEngine/UE_5.8`; `make build-game` verified |
| 4 | Enable Git LFS on the remote (CORE-010) | must land **before** the first binary asset, or history gets rewritten | ⬜ open |
| 5 | Character approach: MetaHuman, commission, or marketplace | ART-020, and therefore the whole art direction's credibility | ⬜ open |
| 6 | Budget and stopping condition for the first run | knowing when to stop, decided while calm | ⬜ open |

## Resolved

| Task | Raised | Resolved | The question | The answer |
|---|---|---|---|---|
| PROD-001 | 2026-09-16 | 2026-09-16 | Which engine? | Unreal 5.5, with `SteeplejackSim` as a UE-independent C++ module. [ADR-0004](docs/03-tech/adr/0004-engine-change-to-unreal.md). *Concrete version later set to 5.8.2 during CORE-001; the answer as given on the day is left as it was.* |
| — | 2026-09-16 | 2026-09-16 | Photoreal or stylised, with no artist? | Photoreal where you look, stylised where you don't. Megascans for brick/timber/rope/metal, silhouette-and-fog for the town, one bespoke character. [Art direction](docs/01-gdd/13-art-direction.md). |
