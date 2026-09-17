---
id: CORE-014
title: Shared JSON reader for SteeplejackSim
milestone: M0
discipline: [ENG]
estimate_days: 0.5
status: ready
assignee: null
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
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
