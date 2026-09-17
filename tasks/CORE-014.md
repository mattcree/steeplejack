---
id: CORE-014
title: Shared JSON reader for SteeplejackSim
milestone: M0
discipline: [ENG]
estimate_days: 0.5
status: review
assignee: agent
depends_on: [CORE-007, CORE-011]
owns:
  - Source/SteeplejackSim/Public/Json.h
  - Source/SteeplejackSim/Private/Json.cpp
  - tests/unit/test_json.cpp
  - Source/SteeplejackSim/Public/Tuning.h
  - Source/SteeplejackSim/Private/Tuning.cpp
  - docs/03-tech/interfaces.md
reads:
  - tests/unit/test_tuning.cpp
  - data/levels/06-waterside.json
spec:
  - docs/03-tech/interfaces.md#tuningh--core-007
  - docs/03-tech/adr/0004-engine-change-to-unreal.md
verify: make test-unit FILTER=json && make test-unit FILTER=tuning
editor_required: false
risk: null
---

## Goal
One JSON reader in `SteeplejackSim`, used by both the tuning loader and the level loader.

## Why
`SteeplejackSim` takes no third-party dependencies by design (ADR-0004), so it needs its own JSON
reader. CORE-007 wrote one inside `Private/Tuning.cpp` because nothing else needed it yet. CORE-008
needs one too, and a second copy is how two parsers start disagreeing about what a number is.

## Context
The reader in `Tuning.cpp` (anonymous namespace, `JsonReader`) **flattens** as it parses: it emits
`(dotted.path, leaf)` pairs and never builds a tree. That is right for tuning, where every access
is a key lookup, and wrong for levels, where `Validate()` has to walk `bands[]` in order and check
contiguity between neighbours.

So this is not a move — it is a small redesign. Provide a value tree, and keep the flattening as a
thin helper on top of it so `Tuning` does not change shape.

Do not add a third-party JSON library. `third_party/` holds doctest and nothing else, and ADR-0004
is why.

The existing reader already handles what the data contains: objects, arrays, numbers, strings,
booleans, `//` line comments (the data-schemas doc writes these files as `jsonc`), `\uXXXX`
rejected explicitly, `null` rejected explicitly, and errors carrying file and line. Keep all of
that behaviour and its tests — `tests/unit/test_tuning.cpp` covers it today and must still pass
unchanged.

**Ownership note:** this task owns `Tuning.h` and `Tuning.cpp`, which CORE-007 also owns, and
`interfaces.md`, which CORE-011 also owns. Both are `done` and both are in `depends_on`, which is
the condition the task-graph validator requires.

## Interface
Write the signature into `docs/03-tech/interfaces.md` first, under a `Json.h — CORE-014` heading,
per the "Adding an interface" rule. Sketch:

```cpp
class JsonValue {
public:
    enum class Kind : uint8_t { Object, Array, Number, String, Bool };
    static JsonValue Parse(const std::string& text, const std::string& origin);

    Kind Kind() const noexcept;
    bool Has(std::string_view key) const noexcept;
    const JsonValue& At(std::string_view key) const;    // object member; throws if absent
    const JsonValue& At(std::size_t index) const;      // array element; throws if absent
    std::size_t Size() const noexcept;                         // array/object element count

    double             AsNumber() const;
    const std::string& AsString() const;
    bool               AsBool() const;

    // The flat view Tuning is built on: emits every leaf as (dotted.path, value).
    void ForEachLeaf(const std::function<void(const std::string&, const JsonValue&)>&) const;
};
```

`JsonError` carries origin, line and what was expected — the existing messages are the bar.

Named `At()` rather than a subscript operator, for a reason worth knowing before you change it
back: `tools/check_links.py` does not skip fenced code blocks, so an empty subscript followed by a
parenthesised parameter list parses as a markdown link with an empty label and fails
`make check-links`. Fixing the checker is a follow-up; until then, keep square brackets
immediately followed by a parenthesis out of code samples in any `.md` file.

## Acceptance
1. `Json.h`/`Json.cpp` exist and `tests/unit/test_json.cpp` covers objects, arrays, nesting,
   numbers, strings, booleans, comments, and every rejection the tuning reader already rejects.
2. `Tuning.cpp` no longer contains a JSON parser and reads through `JsonValue`.
3. `tests/unit/test_tuning.cpp` passes **unchanged** — no test edited to accommodate the move.
4. Every error message still names the origin file and the line.
5. `06-waterside.json` parses into a tree whose `bands` array has 4 elements in file order, proving
   the tree API is adequate for CORE-008 before CORE-008 is written against it.
6. The signature is in `interfaces.md` under its own heading before the implementation.
7. While in `interfaces.md`: the `Tuning.h` block's comment on `GetF` still reads
   `// dotted: "grip_drain.one_hand"`. No such key exists in `data/tuning/meters.json`, which
   spells the group `gripDrainPerSecond` — CORE-007 found this and could not fix it, since it does
   not own the file. Correct the comment to a key that exists. Rule 9: say which of the two was
   wrong, and it is the doc.

## Out of scope
Do not add a JSON *writer*. Do not add a schema validator — `tools/validate_data.py` and
`LevelData::Validate()` (CORE-008) own the rules. Do not touch the SHA-256 in `Tuning.cpp`.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Blocked
<!-- Only if blocked. Question / what I tried / options / recommendation. -->

## Outcome
`Json.h` / `Json.cpp` (one reader: a tree, with the flat view built on it), `tests/unit/test_json.cpp`
(**13 cases**), `Tuning.cpp` reading through it, and the `Json.h` contract written into
`interfaces.md` before the implementation.

A first draft of this line said "13 cases, 62 assertions" when the file held 11. `make test-unit
FILTER=json` reports 13 because doctest's filter is case-insensitive and also matches two cases in
`test_tuning.cpp`. I read a number off a tool and attributed it to the file. It is 13 now because a
reviewer's coverage finding added two more — but it was 11 when I wrote 13.

**The headline: `tests/unit/test_tuning.cpp` passes unchanged** — `git diff` against main shows no
edit to it. That is acceptance 3, and it is the whole safety argument for the extraction. It matters
more than it sounds: that file pins three SHA-256 digests over the flattened tuning data, so if a
single dotted path, value kind or map ordering had shifted, the digests would move and the tests
would fail. They do not. The flattening is behaviourally identical, proved by a hash rather than by
reading the diff.

**Two behaviour deltas, both deliberate, neither previously written down**

A reviewer ran a 50-input differential probe against main — every key list and every hash identical,
and exactly two outputs differ:

1. `{"a":null, "b": }` reported the null on main and now reports the syntax error. The reader parses
   the whole document before `Tuning` inspects any leaf, so a later syntax error wins. A direct
   consequence of the null-policy decision below, but a consequence I had not stated.
2. The `\u` rejection message lost the words "in tuning files", because this reader now serves level
   files too.

Both are defensible; neither was in the first draft of this Outcome, and `Json.cpp`'s own header
comment claimed "same rejections" without qualification. The header now names both.

**Acceptance 7 — and which document was wrong**

`interfaces.md`'s `Tuning.h` block documented `GetF` as `// dotted: "grip_drain.one_hand"`. No such
key exists in any tuning file; `meters.json` spells that group `gripDrainPerSecond`. Corrected to
`gripDrainPerSecond.oneHand`.

Per rule 9: **the doc was the wrong one.** The data has been `gripDrainPerSecond` since it was
written, METER-001 now reads it under that name, and `data-schemas.md`'s example uses a third
spelling again (`gripDrain`). CORE-007 found this and could not fix it — it does not own
`interfaces.md` — and the first draft of this Outcome fixed the comment without saying which side
was wrong, which is the half of rule 9 that actually matters.

**Decisions**

- *A tree, with the flat view on top — not a move.* CORE-007's reader never built a tree; it emitted
  `(dotted.path, leaf)` pairs as it parsed. Right for tuning, where every access is a key lookup;
  useless for CORE-008, which walks `bands[]` in order and checks each band against its neighbour.
- *File order is contract.* `Members()` and `Elements()` return vectors in file order. Bands are
  contiguous height ranges validated pairwise, which is meaningless if the order is whatever a hash
  map decided. A test asserts `zebra, apple, mango` come back in that order, so a future switch to a
  sorted container fails loudly instead of silently reordering CORE-008's input.
- *`null` parses; refusing it is the caller's policy.* CORE-007's reader made `null` a hard parse
  error reading "null is not a tuning value" — a tuning rule in a JSON reader's clothes. `JsonValue`
  now yields `Kind::Null` and `Tuning` rejects it, keeping the message and its test.
- *`JsonError` becomes `TuningError` at the `Tuning::Parse` boundary.* Callers of `Tuning` should not
  have to know JSON is how tuning happens to be stored, and `interfaces.md` says Tuning fails with
  `TuningError`. Origin and line pass through, which is why the existing error tests pass untouched.
- *`Type()`, not `Kind()`.* The sketch in this task said `Kind Kind() const`, which does not compile:
  a member function cannot share a name with the nested type it returns. Renamed here and in
  `interfaces.md`.
- *No `SJ_API` on `JsonValue` yet.* `Tuning.h` does not include `Json.h`, so the type never crosses
  the module boundary. CORE-015 owns `Json.h` and will fold it into one export rule rather than have
  this task invent a second.

**Acceptance 5, which is why this happened before CORE-008 rather than during it**

`06-waterside.json` parses and its `bands` array has 4 elements in file order. The test goes past the
criterion: it checks contiguity (`bands[i].from == bands[i-1].to`) and that the top band reaches
`structure.height`. Both are rules `LevelData::Validate()` must re-implement, so expressing them here
proves the tree API fits its second caller before that caller is written against it. A shared reader
that turns out not to fit is worse than two readers, because the second caller bends around it.

**Surprises**

- *A universal character name is folded inside a raw string literal.* The test for rejecting the
  four-hex-digit escape was written as a raw string, and the compiler turned it into the character
  `A` before the reader ever saw it — so the test passed against the wrong input. It is now assembled
  at runtime from `char(92)`, with a comment, because the obvious spelling tests nothing.
- *`tools/check_links.py` does not skip fenced code blocks*, so a subscript operator followed by a
  parameter list in a `.md` file reads as a markdown link and fails `make check-links`. It shaped the
  `At()` naming. Still worth fixing; no task yet.

**Follow-ups**

- **CORE-008** is unblocked and should use `JsonValue`; its `## Interface` and `depends_on` already say so.
- **CORE-015** should add `Json.h` to the export rule; it already owns the file.
- `tools/check_links.py` should skip fenced code blocks. No task yet.
- `data-schemas.md` still shows `meters.json` with `gripDrain`, a third spelling of the key that
  `interfaces.md` and the data now agree on. Same rule-9 divergence, one document further along; no
  task owns that file.
- `JsonValue` will need `SJ_API` the moment CORE-008 puts one in a public header. CORE-015 owns
  `Json.h` and its acceptance already covers it.
