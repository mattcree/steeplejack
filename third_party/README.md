# third_party/

Vendored, single-header, no transitive dependencies. Committed rather than fetched so that
`make check` works offline and in a cold CI container with no package step.

| Library | Version | Licence | Used for |
|---|---|---|---|
| [doctest](https://github.com/doctest/doctest) | 2.4.11 | MIT | the `SteeplejackSim` test suite |

Adding anything here needs an ADR. The standalone sim build has **no** third-party runtime
dependencies by design — see [ADR-0006](../docs/03-tech/adr/0006-move-to-godot.md).
doctest is test-only and never links into the shipping game.
