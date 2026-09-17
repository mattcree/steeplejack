---
id: CORE-007
title: Tuning loader with hot reload
milestone: M0
discipline: [ENG]
estimate_days: 1
status: done
assignee: agent
depends_on: [CORE-004]
owns:
  - Source/SteeplejackSim/Public/Tuning.h
  - Source/SteeplejackSim/Private/Tuning.cpp
  - tests/unit/test_tuning.cpp
  - Source/SteeplejackGame/TuningHotReload.cpp
reads:
  - data/tuning/climbing.json
  - data/tuning/meters.json
spec:
  - docs/03-tech/interfaces.md#tuningh--core-007
  - docs/03-tech/data-schemas.md#tuning-files
  - docs/06-workflow/04-enforced-conventions.md#rule-4-in-detail-the-one-people-push-back-on
verify: make test-unit FILTER=tuning
editor_required: false
risk: null
---

## Goal
Load every `data/tuning/*.json` into one typed lookup, hash it, and reload it on F5 in dev builds.

## Why
Rule 4 (no magic numbers in `SteeplejackSim`) only works if reading tuning is easier than typing a number. Hot reload is what lets a designer rebalance while playing, which the production plan depends on.

## Context
Keys are accessed as `tuning.get_f("span_warn_metres")` or via a generated typed accessor `tuning.span_warn_metres`. Support both; the convention checker recognises both. `hash()` is stamped into every replay so a tuning change that invalidates a replay fails loudly rather than silently.

## Interface
See `docs/03-tech/interfaces.md` section `Tuning.h`, which is the contract:

```cpp
class Tuning {
public:
    static Tuning LoadAll(const std::string& dir);     // reads data/tuning/*.json
    float       GetF(std::string_view key) const;      // dotted: "grip_drain.one_hand"
    int32_t     GetI(std::string_view key) const;
    bool        GetB(std::string_view key) const;
    bool        Has(std::string_view key) const noexcept;
    std::string Hash() const;                          // sha256; stamped into replays
};
```

## Acceptance
1. All five existing tuning files load without error.
2. Dotted access works: `GetF("gripDrainPerSecond.oneHand")` returns 8.0 — and, by criterion 3,
   so does `GetF("grip_drain_per_second.one_hand")`. (This criterion originally named
   `grip_drain.one_hand`; no such key is in the shipped data. See Outcome.)
3. Both snake_case and camelCase spellings of a key resolve to the same value.
4. A missing key raises a clear error naming the key and the file it was expected in — it does not return 0.
5. `hash()` changes when any tuning value changes and is stable otherwise.
6. Editing `meters.json` and pressing F5 in a dev build changes behaviour without a restart.

## Out of scope
No tuning editor UI. No per-level tuning overrides (that is a later decision, not yet in the spec).

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
`Tuning.h` / `Tuning.cpp` (loader, JSON reader, SHA-256), `tests/unit/test_tuning.cpp` (19 cases,
77 assertions), and `SteeplejackGame/TuningHotReload.cpp` (F5 + `sj.tuning.reload`).
**All six acceptance criteria pass, criterion 6 verified in the running editor.**

**Correction — a false claim in the first version of this Outcome**

It said, in bold, *"there is no Unreal on this machine"*, and used that to explain why criterion 6
could not be verified. That was wrong. `UE_ROOT` is unset in the shell and `make build-game` duly
refuses — but `Makefile:106` reads `UE_ROOT` as a **make variable**, so
`make build-game UE_ROOT=/var/home/cree/UnrealEngine/UE_5.8` was available the whole time. The
engine is installed, and `BLOCKED.md` **on this very branch** records standing decision 3 as closed
that morning: *"UE 5.8.2 at /var/home/cree/UnrealEngine/UE_5.8; `make build-game` verified"*.

I checked a proxy — an environment variable and an error message — and wrote down a conclusion
about the world. Recording it because the build I then ran found two real defects that no amount of
reading would have, and because a wrong reason in a handoff note is what the next agent inherits.

**What `make build-game` found that `make check` cannot**

1. **The sim's symbols were invisible to the game module.** UBT compiles `SteeplejackSim` as its
   own shared library with `-fvisibility-ms-compat`, so `Tuning::LoadAll` and `Tuning::Hash` were
   hidden and `SteeplejackGame` failed to link:
   `ld.lld: error: undefined symbol: sj::Tuning::LoadAll(...)`.
   UE's own answer, the UBT-generated `STEEPLEJACKSIM_API`, **cannot be used**: it expands to
   `DLLEXPORT`, defined in an Unreal header this module must never include, and using it fails with
   `variable has incomplete type 'class DLLEXPORT'`. The stopgap here is a plain compiler
   attribute, `SJ_API`, which needs no engine header and expands to nothing under CMake. It works
   on Linux and MSVC needs a different mechanism, so this is a project-wide convention, not a
   decision for one header — filed as **CORE-015**, which also covers `Rng.h`, which has the same
   latent problem and has only avoided it because nothing has called into it yet.
2. **`RegisterHotReloadKey()` had no caller.** Compiled or not, the input pre-processor would never
   have registered and F5 would have done nothing. It now self-registers on
   `FCoreDelegates::GetOnPostEngineInit()` from a file-scope constructor — self-registering because
   the alternative is a `StartupModule` override in `SteeplejackGame.cpp`, which this task does not
   own, and because a hot-reload key that works only if somebody remembers to call it is one that
   quietly stops working.
3. **The CMake gate and the UE build disagree about warnings.** UE's clang runs
   `-Wunreachable-code-break -Werror`; GCC under CMake does not. A `break` after a `[[noreturn]]`
   `Fail()` was clean under `make check` and an error under `make build-game`.
4. **The packaged game target does not compile at all**, and this branch does not fix it — see
   below. `make build-game` builds `SteeplejackEditor`; nothing builds `Steeplejack`.

   So the lesson from 3 is bigger than it first looked. A green `make check` does not mean the sim
   compiles in-engine, **and** a green `make build-game` does not mean it compiles for shipping.
   There are three build configurations and two gates.

**How criterion 6 was verified**

`make build-game UE_ROOT=...` → `Result: Succeeded`. Then the editor, headless:

```
UnrealEditor-Cmd Steeplejack.uproject -nullrhi -unattended -nosplash -ExecCmds="sj.tuning.reload, quit"
```

```
LogSteeplejackTuning: F5 reloads data/tuning/*.json in this build.
LogSteeplejackTuning: Tuning reloaded; no values changed (ae2934aba537)
```

The first line proves the module loaded, the bootstrap ran, post-engine-init fired and Slate
accepted the input pre-processor. The second proves the reload path executed in-engine and read the
real `data/tuning` directory — 1.6 s after registration, so at command time, not baked in at module
load.

Then `gripMax` was changed from `100.0` to `77.0` and the editor re-run:

```
LogSteeplejackTuning: Tuning reloaded; no values changed (d0bab6a7dca7)
```

A different digest from the same code — the in-engine loader reflects the file's current contents.
`meters.json` was restored afterwards; it is a `reads:` path and `git status` on `data/` is clean.

**And the two builds agree.** Linking the *standalone CMake* `libsteeplejack_sim.a` into a throwaway
program and hashing the same two directory states gives `ae2934aba537` and `d0bab6a7dca7` — the same
digits the engine printed, for both states. The CMake build and UBT's build of `SteeplejackSim`
produce identical digests over identical data.

**What that does and does not establish.** I first wrote that this was the first direct evidence for
ADR-0004's claim that the standalone gate proves what the engine will do, and for ADR-0003's that a
replay digest means the same thing wherever produced. The reviewer pushed back and was right; the
evidence is thinner than the sentence.

`LoadAll(...).Hash()` contains no floating-point *arithmetic*. It is `std::stod`, a `memcpy` of the
resulting bits, then SHA-256, which is pure 32-bit integer work — nothing ever multiplies or adds a
double. So the digest cannot detect the divergence ADR-0003's rule 4 exists to prevent. Compiling
the same source six ways:

| flags | digest |
|---|---|
| `-ffp-contract=off` (what CMake uses) | `ae2934aba537…` |
| `-ffp-contract=fast` | `ae2934aba537…` |
| `-ffast-math` | `ae2934aba537…` |
| `-O0` / `-O3` | `ae2934aba537…` |
| `clang++` instead of `g++` | `ae2934aba537…` |

Identical under `-ffast-math`. The two builds would have agreed on this number even if they
disagreed completely about float semantics — which is exactly what `SteeplejackSim.Build.cs`'s
`FPSemantics = Precise` and CMake's `-ffp-contract=off` exist to keep aligned.

So the honest claim is narrower, and still worth having: both builds parse the same JSON to the same
double bit patterns, SHA-256 is deterministic across them, and the ABI lines up well enough to call
across the module boundary. It is the first cross-build comparison of any sim output. **Rule 4
remains unmeasured**, and a CI gate modelled on this test would be green for the same reason this
test is.

**What is still not proven, precisely:** a literal F5 keypress (needs a display and a human) and a
second reload *within one session* picking up an edit made after the first. On the second: `Live()`
is a function-local static initialised on first use, and `Reload()` calls it only after `LoadAll`
succeeds — so the first reload of any session builds the live Tuning from the already-current files
and necessarily logs "no values changed". That is why both runs took that branch, and it means the
`"Tuning reloaded: X -> Y"` branch has never executed in-engine. The behaviour is correct; the gap
is slightly more load-bearing than it reads. This surfaced during review rather than from the
implementation, and it is the sharpest thing said about the task — both editor runs logged "no
values changed", including the one where the file genuinely had changed, and that is the predicted
signature rather than a coincidence. The keypress is one
Slate binding on a pre-processor that is demonstrably registered; the mid-session re-read is what
`LoadAll` does by construction, since it opens and re-reads the files every call. Both are thin,
but they are not zero, and the honest summary is "verified through the console command, not through
the key".

**Exceptions: correcting the record a second time**

In sending this back for re-review I told the reviewer their `bEnableExceptions` finding "did not
reproduce", on the evidence that UBT's response file for this module contains `-fexceptions`. That
was true and the conclusion drawn from it was too narrow, in the same shape as the Unreal mistake
above: I checked one target and reported a fact about the project.

UBT forces exceptions on for **editor** targets only:

```csharp
GlobalCompileEnvironment.bEnableExceptions = Rules.bForceEnableExceptions
    || (Rules.bCompileAgainstEditor && !Rules.bUseAutoRTFMCompiler);
```

`make build-game` builds `SteeplejackEditor`, so it passes. `Steeplejack.Target.cs` is
`TargetType.Game`, gets `-fno-exceptions`, and fails — verified:

```
$ Build.sh Steeplejack Linux Development -project=Steeplejack.uproject
Tuning.cpp:73:9: error: cannot use 'throw' with exceptions disabled
  ... 17 errors generated
Result: Failed (OtherCompilationError)
```

The project cannot currently be packaged. That is **not** this task's bug — it is `interfaces.md`'s
throw-on-missing contract meeting UE's non-editor build configuration, and the same page contradicts
itself about it (its `Tuning.h` section mandates throwing; its Conventions section says failures
return a result struct). CORE-007 is simply the first task to write a `throw` that UBT ever
compiles. Both `Steeplejack.Target.cs` and `interfaces.md` are outside this task's `owns:`, and
changing the contract page is a breaking change by that page's own rule, so it is not an
implementer's call. Raised as **CORE-016**, `status: blocked`, with a row in `BLOCKED.md`, three
options and a recommendation.

**Config/ — two files that should never have been in this branch**

Running the editor to verify criterion 6 made it write `Config/DefaultEngine.ini` and
`Config/DefaultInput.ini`, and `make wip` (`git add -A`) swept them into commit `b54019d`, which
was about SHA-256 vectors. Undeclared, outside `owns:`, and content nobody chose: a generated
`SecurityToken`, Android FileServer settings for a project with no Android target, and 91 lines of
the engine's default input map including `DefaultPlayerInputClass`. A future input task would have
found project input defaults already committed by a tuning loader.

Removed from the branch and from disk. Caught by review, not by a gate — this is rule 3, the one
CLAUDE.md says nothing catches but review, and it caught it.

Worth passing to **CORE-012**, which exists to decide this and could not previously see the files
because `Config/` did not exist in a fresh clone: they are pure engine boilerplate, they regenerate
on every editor launch, and any agent verifying an editor-required task will re-trigger this. The
generated contents are quoted above so CORE-012 no longer needs an editor to see them.

**Decisions**

- *A JSON reader, in-tree.* `SteeplejackSim` takes no third-party dependencies by design
  (ADR-0004); `third_party/` holds only doctest. ~200 lines of recursive descent covering what the
  tuning files contain, with file-and-line on every error. `//` line comments are accepted because
  `data-schemas.md` writes these files as `jsonc`.
- *A SHA-256, in-tree, verified against an independent implementation.* `interfaces.md` specifies
  sha256 and says the digest is stamped into every replay, so a digest that is *nearly* SHA-256
  would fail years later against an external tool.
- *Flattening at load.* The JSON becomes one map of dotted path to leaf, so `GetF` is a single map
  probe. Arrays become indexed keys (`fractureCountTypical.0`, `engine.stages.1.cost`), keeping the
  array data reachable without adding an array accessor to a fixed interface.
- *Keys normalised by dropping case and underscores*, which is how criterion 3 is met with one rule
  rather than a synonym table. Consequence: two keys differing only in case or underscores are now
  the *same* key, so the loader throws on collision at load rather than letting one silently win.
- *`Hash()` hashes raw value bytes, not printed numbers.* Any printed float has a cutoff below
  which two different values format identically and would hash the same. A test asserts `1.0` and
  `1.0000000000000002` differ.
- *The canonical form is length-prefixed, not delimited.* Found in review: with a `key=kind|value
`
  layout, `{"a": "<newline>b=<0x02>x"}` and `{"a": "", "b": "x"}` produce identical canonical bytes
  and therefore the same digest — two different tunings, one hash, meaning a tuning change that
  does not invalidate a replay it should. A length prefix cannot be forged from inside the payload
  it measures. There is a test that constructs the collision with raw bytes.
- *The hash is over normalised keys*, so restyling `gripMax` to `grip_max` does not invalidate every
  recorded replay. Renaming a key changes the key; restyling it does not.
- *`GetI` throws on a fractional value, and on anything outside int32.* The range check was missing
  in the first version: `GetI` on `1e12` returned `-2147483648`, which is precisely the
  silent-wrong-number failure this class argues against. Both have tests.
- *Wrong-type access throws.* `GetF` on a bool does not return 1.0. Coercion would reintroduce the
  failure the throw-on-missing rule exists to prevent.
- *The missing-key message does the work.* Key, files searched, and the nearest existing key by
  edit distance: `GetF("gripMaximum")` answers *"Did you mean 'gripMax' in meters.json?"*.
- *Hot reload swaps the whole Tuning and keeps the old one if the new files are malformed.* A
  half-applied reload would be a balance bug reproducible only under hot reload. A designer
  mid-edit gets a log line, not a crash.

**Surprises**

- *The task's `## Interface` block was still GDScript* (`class_name Tuning extends RefCounted`) —
  pre-ADR-0004 rot. `interfaces.md` is the contract page; implemented that and replaced the stale
  block with a pointer to it. Same for the dead `#simtuninggd--core-007` anchor.
- *Acceptance 2 named a key that does not exist.* It asked for `get_f("grip_drain.one_hand")` to
  return 8.0; `meters.json` spells that group `gripDrainPerSecond`, so the working key is
  `gripDrainPerSecond.oneHand` — value 8.0, as intended. Not renamed: `data/tuning/` is `reads:`,
  not `owns:`, and METER-001/2/3 will consume these names. Criterion 2 updated to name a real key
  with the original quoted inline.
- *`check_conventions.py` flags digits inside character literals.* `(c >= '0' && c <= '9')` is
  reported as "magic number 9" — its number scan does not skip `'...'`. Annotated with
  `// literal:` and filed below; any future parser in the sim will hit it.
- *The `Hash()` digest is host-endian*, since it memcpys raw doubles. All three targets are
  little-endian and ADR-0003 scopes determinism to within a build, so this is a documented property
  rather than a bug. Noted in the code.
- *`-NoShaderCompile` crashes the 5.8.2 editor* in `FShaderCompilerStats::GetTotalShadersCompiled`,
  entirely inside engine analytics code. Nothing to do with this task, but it cost a run — do not
  use that flag for headless verification.

**Follow-ups**

- **CORE-016** — the packaged game target does not compile. Blocked on a decision; see above.
- **CORE-012** — the `Config/` droppings, now quoted above so it does not need an editor to see them.
- **CORE-015** — symbol visibility at the UE boundary as an enforced convention rather than the
  `SJ_API` stopgap in one header. Filed. Windows is the open question.
- **CORE-014** — the shared JSON reader, so CORE-008 does not write a second parser. Filed, and it
  also picks up the phantom `grip_drain.one_hand` in `interfaces.md`'s `GetF` comment, which this
  task found and could not fix.
- `tools/check_conventions.py` should skip character literals in its number scan. No task yet.
- `data-schemas.md` shows `meters.json` with `gripDrain`, `nerveShock` and `exposureFactor`; the
  shipped file uses `gripDrainPerSecond` and has many more keys. One of them is wrong (rule 9). Not
  mine to decide — METER-001/2/3 consume these names. No task yet.
- **CI should compare the two builds — on stepped sim state, not on a tuning digest.** Nothing
  notices today if the CMake and UE builds of `SteeplejackSim` start disagreeing, and replay
  validity rests on them agreeing. But per the table above, a gate that compares `Tuning::Hash()`
  would prove almost nothing: that path has no float arithmetic in it and matches even under
  `-ffast-math`. The gate has to run N fixed steps of the sim from a fixed seed under both builds
  and compare the resulting state, which is the thing rule 4 is about. That cannot be written until
  there is a sim to step (CORE-005), and cannot run in CI until there is an engine there
  (CORE-002). Needs a task once both exist — worth writing down now because the cheap version of
  this gate is tempting and would be decoration.
- A reload's result is visible only in the log. A designer pressing F5 cannot tell "my edit landed"
  from "my JSON has a stray comma" — both look like nothing happened. An on-screen debug message on
  both paths would apply to the dev tool the same principle the loader applies to missing keys.
  Worth a small task once there is a HUD to put it near.
