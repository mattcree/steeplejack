# tests/

```bash
godot --path . --headless -s tests/run_tests.gd
```

| Directory | Contains | Gate |
|---|---|---|
| `unit/` | one file per `sim/` module | must pass on every commit |
| `property/` | invariants (e.g. gob margin is monotonic in cells removed) | must pass |
| `replay/` | recorded expert runs from `data/replays/` replayed against `sim/` | must pass |
| `perf/` | frame-time capture on three reference scenes | nightly, warn |
| `validate_levels.gd` | schema + Ascent Beat Rule + reachability | must pass |

The replay regression is the most valuable test in the project: a balance change that breaks a level
shows up as a diff of two invoices. See
[`../docs/03-tech/adr/0003-determinism-and-testing.md`](../docs/03-tech/adr/0003-determinism-and-testing.md).
