# SteeplejackSim — the pure simulation layer

**Plain C++20. No Unreal. This module must compile standalone under CMake with no engine
installed.** That is not a style preference — it is what keeps the gameplay layer testable in
~20 seconds and editable by agents. See [ADR-0004](../../docs/03-tech/adr/0004-engine-change-to-unreal.md).

## Forbidden here (CI-enforced)

- Unreal headers: `CoreMinimal.h`, `Engine/*`, `GameFramework/*`, `Chaos/*`, …
- Unreal types: `FVector`, `TArray`, `FString`, `UObject`, `FMath`, `UE_LOG`, `.generated.h`
- Ambient randomness: `rand()`, `std::random_device`, `std::mt19937` — take an `sj::Rng&`
- Clocks: `std::chrono`, `time()` — time is an explicit `float dt`
- stdout: `printf`, `std::cout` — return values, don't log
- Mutable statics — they break determinism and therefore every replay
- Numeric literals that belong in `data/tuning/*.json` — annotate genuine exceptions with
  `// literal: <reason>`

`make check-conventions` fails the build on all of these.

## Build and test without Unreal

```bash
make test-unit                 # cmake configure + build + doctest, ~20s
make test-unit FILTER=Stack    # one module
```

## Planned modules (M0–M1)

| Header | Task | Purpose |
|---|---|---|
| `Rng.h` | CORE-003 | seeded xorshift128+, forkable substreams |
| `Types.h` | CORE-004 | Joint, Anchor, Section, Meters, GobCell, Prop, FallPlan |
| `Tuning.h` | CORE-007 | all balance numbers, loaded from JSON, hashed |
| `Clock.h` | CORE-005 | fixed-step accumulator |
| `Intent.h` `Recorder.h` `Replay.h` | CORE-006 | record and reproduce a whole job |
| `Level.h` | CORE-008 | level JSON → typed data, plus `Validate()` |
| `Joints.h` | STRUCT-002 | the joint grid — the gameplay surface of every structure |
| `Reachability.h` | CORE-009 | prove a level's top can be reached |
| `Verbs/Tap.h` | VERB-001 | the game's signature action |
| `Verbs/Hammer.h` | VERB-003 | power / angle / depth |
| `Anchor.h` | VERB-004 | ratings and capacity |
| `Verbs/Lash.h` | VERB-005 | wraps and tension |
| `Verbs/Haul.h` | VERB-007 | 2-DOF pendulum |
| `Stack.h` | CLIMB-001 | spans, flex bands, buckling |
| `Load.h` | CLIMB-002 | load sharing and cascade failure |
| `Meters.h` | METER-001/2 | grip and nerve |
| `Wobble.h` | METER-003 | **the one number every verb reads** |
| `Weather.h` | ENV-003 | wind, gusts, the 1.2 s tell |
| `Slip.h` | METER-005 | the grab window |

Full signatures: [`docs/03-tech/interfaces.md`](../../docs/03-tech/interfaces.md).
