# tests/

doctest, compiled into `sim_tests` by the standalone CMake build. **No Unreal required.**

```bash
make test-unit                 # everything, ~20s
make test-unit FILTER=Stack    # one module
```

| Directory | Contains | Gate |
|---|---|---|
| `unit/` | one file per `SteeplejackSim` module | every commit |
| `property/` | invariants (e.g. gob margin is monotonic in cells removed) | every commit |
| `replay/` | recorded expert runs replayed against the sim | every commit |
| `perf/` | asserts `Sim::Step` stays under 0.5 ms | every commit |

The replay regression is the most valuable test in the project: a balance change that breaks a level
shows up as a diff of two outcomes. See
[`../docs/03-tech/adr/0003-determinism-and-testing.md`](../docs/03-tech/adr/0003-determinism-and-testing.md).

Presentation-layer tests live in the UE automation framework and run via `make test-automation`
on a runner that has the engine. They are not part of the fast gate.
