# Enforced Conventions

A convention that lives only in a document is a convention that will be broken by the third agent
on a Tuesday. Everything below is a script that fails the build.

Run them all: `make check-conventions`

## The rules

| # | Rule | Enforced by | Rationale |
|---|---|---|---|
| 1 | No engine headers or types (Godot or Unreal) in `SteeplejackSim` | `tools/check_conventions.py:sim_purity` | [ADR-0006](../03-tech/adr/0006-move-to-godot.md) — it must build standalone |
| 2 | No ambient RNG (`rand`, `mt19937`) or mutable statics in `SteeplejackSim` | same | determinism, and therefore replay |
| 3 | No clocks, no stdout in `SteeplejackSim` | same | time is a `float dt` parameter |
| 4 | No unexplained numeric literals in `SteeplejackSim` | same | tuning is data, not code |
| 5 | Every `data/levels/*.json` validates against the schema | `tools/validate_data.py` | |
| 6 | Band coverage is contiguous and complete | same | broken levels are easy to author |
| 7 | Quality distributions sum to 1.0 | same | |
| 8 | **Ascent Beat Rule**: no `plain` band over 20 m | same | the anti-tedium rule (risk R1) |
| 9 | Exclusion bearings never fall inside a fall corridor | same | an unwinnable felling |
| 10 | Every tuning key referenced by `SteeplejackSim` exists in `data/tuning/` | same | |
| 11 | Task frontmatter is valid and complete | `tools/tasks.py validate` | Definition of Ready |
| 12 | Task dependency graph is acyclic and all IDs resolve | same | |
| 13 | No file-ownership conflict between concurrent tasks | same | parallel safety |
| 14 | Every `spec:` reference resolves to a real file | same | self-contained work items |
| 15 | No broken internal doc links | `tools/check_links.py` | |
| 16 | **No real person's name anywhere in the repo** | `tools/check_conventions.py:likeness` | [IP policy](../05-legal/ip-and-likeness.md) |
| 17 | C++ compiles clean at `-Wall -Wextra -Werror -Wconversion` | the CMake build | |
| 18 | ~~No gameplay decision in a Blueprint~~ — retired 2026-09-19 with Unreal. Its successor, "no game rule in GDScript", is enforced by review | — | there are no Blueprints |
| 19 | Wobble tuning is read only in `Wobble.cpp`; everything else calls `WobbleAmplitudeDeg` | `tools/check_conventions.py:wobble_home` | METER-003 — two wobbles tell the player two stories about the same hands |

Rules 1–4 and 16 are the ones that exist specifically because agents will otherwise break them
confidently and silently.

## Rule 4 in detail (the one people push back on)

`SteeplejackSim` may not contain a numeric literal outside this allowlist:

```
0, 1, -1, 2, 0.0, 1.0, 0.5, 100.0  (with or without an f suffix)
8, 16, 32, 64, 17                  bit widths and the C++ standard
array indices and loop bounds
constexpr / const / #define / enum / static_assert / template declarations
any line annotated  // literal: <reason>
```

Everything else must come from `data/tuning/*.json`. So this fails:

```cpp
if (grip < 20.0f) {                                    // ✗
    ApplyTremor();
}
```

and these pass:

```cpp
if (grip < tuning.GetF("grip_tremor_threshold")) {     // ✓
    ApplyTremor();
}
constexpr float kGravity = 9.81f;    // literal: standard gravity, not a balance value  ✓
```

**Why it's worth the friction:** it's what makes rebalancing the whole game a JSON edit plus
`make test-replay`, with no engineer in the loop. That property is load-bearing for the production
plan (12 levels, small team) and it evaporates the moment constants start living in code.

## Rule 16 in detail

`tools/check_conventions.py` greps the working tree **and the commit history** for a configured
list of real names associated with the subject matter.

The tracked `tools/likeness_denylist.txt` is **deliberately empty**: writing the terms into a public
repository would publish the very association the policy exists to avoid, and would make the repo a
search hit for them. The real list lives in `tools/likeness_denylist.local.txt`, which is gitignored.
The checker reads both and concatenates them.

**Until the local file is populated, rule 16 is inert and says so on every run.** Populating it is a
pre-M0 task for the project lead.

It is not a joke check. See [the IP policy](../05-legal/ip-and-likeness.md) — this is a blocking
gate at every milestone, and catching it in CI is much cheaper than catching it in a VO session.

## Adding a rule

Every time an agent makes the same mistake twice, that's a missing rule. Add it:

1. Write the check in `tools/check_conventions.py`.
2. Add a row to the table above.
3. Add a test in `tools/test_conventions.py` proving it catches the bad case **and** doesn't catch
   a legitimate one.
4. Fix all existing violations in the same PR, or add an explicit, dated allowlist entry.

A rule with no test is not a rule; it's a future false positive that someone will disable.
