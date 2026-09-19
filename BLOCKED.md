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
| [GDD-001](tasks/GDD-001.md) | 2026-09-17 | Two nerve questions the data answers and no document does: (a) is `bellStrike` at -35 meant to be the worst shock in the game, worse than an anchor failing under you; (b) at a belted stance at the height and wind caps, nerve drains 3x faster than grip and freezes in 30 s — is nerve still the slow meter? | (a) keep the data, document the three missing shocks; (b) needs a designer — the formula and data are the GDD's own and faithfully implemented |
| [CLIMB-002](tasks/CLIMB-002.md) | 2026-09-19 | `loadShareFalloff` 0.55 puts **83.4%** of the load on the top three anchors of a 12-section stack; acceptance 2 says 78-82% and the context says 0.55 gives "about 80%". Which number is the design? | Widen the acceptance: the GDD's formula and the data agree with each other, only the range is off. If 80% is the target, 0.585 gives 80.1%. Built with 0.55 as written; nothing waits on this |
| [VERB-003](tasks/VERB-003.md) | 2026-09-19 | Acceptance 2 wants 0.65–0.75 power to beat full power at every angle error. Per strike, full power drives further below 6° (0.200 vs 0.140) and only loses past 6°, when it bends. The GDD's lesson comes from the draw (power builds while aim drifts), not the strike. Is the criterion about one strike or about play? | Restate it as a property of the draw, and test it there; the strike model is already the GDD's |
| [METER-003](tasks/METER-003.md) | 2026-09-19 | Acceptance 3 says worst-case wobble is **6x** base; the tuning gives **13.1x** (one-hand 1.6 × nerve 3 × grip 2, plus the gust). 6 is exactly grip × nerve from the GDD formula, so it looks like it predates the stance and gust terms. Which is the target? | Keep the data and restate the acceptance; the hammer test already asserts the real intent (worst wobble beats the angle tolerance) |

## Standing decisions the lead owes the project

These are not agent escalations — they are preflight items that nothing can proceed past.
See [`docs/06-workflow/06-launch.md`](docs/06-workflow/06-launch.md).

| # | Decision | Blocks | Status |
|---|---|---|---|
| 1 | Populate `tools/likeness_denylist.local.txt` | rule 16 is inert; ART-020 is the highest-risk task for it | ⬜ open |
| 2 | Name a human for the editor queue (10.5 days already queued) | ART-020, AUD-001, AUD-004, ENV-002, and everything downstream | ⬜ open |
| 3 | ~~Install Unreal and set `UE_ROOT`~~ | CORE-001's second half, and all of `SteeplejackGame` | ✅ closed 2026-09-17; **moot 2026-09-19** — Unreal removed from the project (ADR-0006 moved the game to Godot) |
| 4 | Enable Git LFS on the remote (CORE-010) | must land **before** the first binary asset, or history gets rewritten | ⬜ open |
| 5 | Character approach: commission, marketplace, or something built for Godot (MetaHuman went with Unreal) | ART-020, and therefore the whole art direction's credibility | ⬜ open |
| 6 | Budget and stopping condition for the first run | knowing when to stop, decided while calm | ⬜ open |

## Resolved

| Task | Raised | Resolved | The question | The answer |
|---|---|---|---|---|
| CORE-016 | 2026-09-17 | 2026-09-19 | Should `SteeplejackSim` use C++ exceptions, given the packaged Unreal target would not compile with them? | Moot: Unreal is removed. The sim keeps its throw-on-missing contract; the Godot binding catches at every entry point. |
| PROD-001 | 2026-09-16 | 2026-09-16 | Which engine? | ~~Unreal 5.5~~, with `SteeplejackSim` as a UE-independent C++ module. [ADR-0004](docs/03-tech/adr/0004-engine-change-to-unreal.md). *Concrete version later set to 5.8.2 during CORE-001; the answer as given on the day is left as it was.* |
| — | 2026-09-16 | 2026-09-16 | Photoreal or stylised, with no artist? | Photoreal where you look, stylised where you don't. Megascans for brick/timber/rope/metal, silhouette-and-fog for the town, one bespoke character. [Art direction](docs/01-gdd/13-art-direction.md). |
