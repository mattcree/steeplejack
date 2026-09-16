---
id: CORE-007
title: Tuning loader with hot reload
milestone: M0
discipline: [ENG]
estimate_days: 1
status: ready
assignee: null
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
`Tuning.h` / `Tuning.cpp` (loader, JSON reader, SHA-256), `tests/unit/test_tuning.cpp` (17 cases),
and `SteeplejackGame/TuningHotReload.cpp` (F5 + `sj.tuning.reload`). Acceptance 1–5 pass.
**Acceptance 6 is implemented but unverified — there is no Unreal on this machine.** See below.

**What was built, and why it is more than a map lookup**

- *A JSON reader, in-tree.* `SteeplejackSim` takes no third-party dependencies by design
  (ADR-0004: it must configure and build with nothing but a compiler), and `third_party/` holds
  only doctest. ~200 lines of recursive descent covering what the tuning files actually contain,
  with file-and-line on every error. Line comments are accepted because `data-schemas.md` writes
  these files as `jsonc`.
- *A SHA-256, in-tree, checked against the published vectors.* `interfaces.md` specifies sha256
  and says the digest is stamped into every replay. A digest that is *nearly* SHA-256 would fail
  years later against an external tool, so it is verified against the FIPS 180-4 empty-string
  vector end to end rather than against itself.
- *Flattening at load.* The JSON becomes one map of dotted path to leaf, so `GetF` is a single
  map probe and nested and flat files are the same thing to a caller. Arrays become indexed keys
  (`fractureCountTypical.0`, `engine.stages.1.cost`), which keeps the array data in `economy.json`
  and `felling.json` reachable without adding an array accessor to a fixed interface.

**Decisions**

- *Keys are normalised by dropping case and underscores.* That is how criterion 3 is met, and it
  is one rule rather than a synonym table. Consequence worth stating: two keys that differ only
  in case or underscores are now the *same* key, so the loader throws on collision at load rather
  than letting one silently win. There is a test.
- *`Hash()` hashes raw value bytes, not printed numbers.* Any printed float has a cutoff below
  which two different values format identically and would hash the same. The digest guards replay
  validity, so "close enough" is not. A test asserts that `1.0` and `1.0000000000000002` hash
  differently — they do not with `%.15g`.
- *The hash is over normalised keys*, so re-spelling `gripMax` as `grip_max` does not invalidate
  every recorded replay. Renaming a key changes the key; restyling it does not.
- *`GetI` throws on a fractional value* rather than truncating. `900` and `6` come back as
  integers, `100.0` does too (it is a whole number), and `0.25` is an error naming the key. Silent
  truncation is the same class of bug as a silent zero.
- *Wrong-type access throws.* `GetF` on a bool does not return 1.0, `GetB` on a number does not
  return "truthy". Coercion here would reintroduce exactly the silent-wrong-number failure the
  throw-on-missing rule exists to prevent.
- *The missing-key message does the work.* It names the key, the files searched, and the nearest
  existing key by edit distance — `GetF("gripMaximum")` answers "Did you mean 'gripMax' in
  meters.json?". The interface doc asks for "the key name and the file it was expected in"; for a
  key that exists nowhere, the nearest real key is the closest honest answer to "where".
- *Hot reload swaps the whole Tuning, and keeps the old one if the new files are malformed.* A
  half-applied reload would be a balance bug reproducible only under hot reload. A designer
  mid-edit gets a log line, not a crash.
- *No `UCLASS` in `TuningHotReload.cpp`.* A UCLASS needs a paired header with `.generated.h`, and
  this task owns only the `.cpp`. F5 is caught with a Slate input pre-processor instead, which
  keeps the whole feature in one file and works regardless of which widget has focus.

**Acceptance 6 is not verified**

`make build-game` requires `UE_ROOT`; it is unset on this machine and the task is tagged
`editor_required: false`. So `TuningHotReload.cpp` is written but has **never been compiled**, and
"editing meters.json and pressing F5 changes behaviour without a restart" has never been observed.
Everything it depends on is verified — `LoadAll` re-reading from disk, the swap, the malformed-file
path and the hash comparison are all sim-side and covered by the unit tests — but the UE glue
itself is unproven. Do not read the green gate as covering it.

This looks like a mis-tag rather than a mistake in the work: acceptance 6 cannot be satisfied by
any agent without the engine. Recommendation in the follow-ups.

**Surprises**

- *The task's `## Interface` block was still GDScript* (`class_name Tuning extends RefCounted`) —
  pre-ADR-0004 rot. `interfaces.md` is the contract page and has the C++ signature; implemented
  that, and replaced the stale block in this task file with a pointer to it. Same for the dead
  `#simtuninggd--core-007` anchor in `spec:`.
- *Acceptance 2 named a key that does not exist.* It asks for `get_f("grip_drain.one_hand")` to
  return 8.0. The shipped `meters.json` spells that group `gripDrainPerSecond`, so the working
  key is `gripDrainPerSecond.oneHand` (or `grip_drain_per_second.one_hand`) — value 8.0, as the
  criterion intends. `data-schemas.md` shows `"gripDrain"` too, so the *data* is what moved. I did
  not rename the key: `data/tuning/` is in `reads:`, not `owns:`, and METER-001/2/3 will consume
  these names. Criterion 2 updated to name a real key, with the original recorded.
- *`check_conventions.py` flags digits inside character literals.* `(c >= '0' && c <= '9')` is
  reported as "magic number 9". Its number scan does not skip `'...'`. Annotated with
  `// literal:` and filed as a follow-up — any future parser in the sim will hit it.
- The SHA-256 constants are named (`kBlockBytes`, `kBytesPerWord`, `kHexDigitBits`) rather than
  annotated, since `constexpr` lines are exempt from rule 4 and named constants read better. Only
  the FIPS message-schedule offsets (`w[t-15]`, `w[t-2]`, `w[t-16]`, `w[t-7]`) kept a
  `// literal:` — they are the algorithm, and naming them would obscure rather than explain.

**Follow-ups**

- **Acceptance 6 needs an editor task.** Either re-tag CORE-007 `editor_required: true` and batch
  it, or open a small follow-up that compiles `SteeplejackGame` and observes an F5 reload. Until
  one of those happens, hot reload is written-but-unproven. This is R8's gauge moving.
- `tools/check_conventions.py` should skip character literals in its number scan.
- `data-schemas.md` shows `meters.json` with `gripDrain`, `nerveShock` and `exposureFactor` as the
  spelling; the shipped file uses `gripDrainPerSecond` and has many more keys. One of them is
  wrong (rule 9). Not mine to decide — the key names are consumed by METER-001/2/3.
