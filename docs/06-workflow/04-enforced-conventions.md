# Enforced Conventions

A convention that lives only in a document is a convention that will be broken by the third agent
on a Tuesday. Everything below is a script that fails the build.

Run them all: `make check-conventions`

## The rules

| # | Rule | Enforced by | Rationale |
|---|---|---|---|
| 1 | No Godot node types in `sim/` | `tools/check_conventions.py:sim_purity` | [ADR-0003](../03-tech/adr/0003-determinism-and-testing.md) |
| 2 | No `randi()`/`randf()`/`randomize()` in `sim/` | same | determinism |
| 3 | No engine `delta` / `Engine.*` / `OS.*` in `sim/` | same | time is a parameter |
| 4 | No unexplained numeric literals in `sim/` | same | tuning is data, not code |
| 5 | Every `data/levels/*.json` validates against the schema | `tools/validate_data.py` | |
| 6 | Band coverage is contiguous and complete | same | broken levels are easy to author |
| 7 | Quality distributions sum to 1.0 | same | |
| 8 | **Ascent Beat Rule**: no `plain` band over 20 m | same | the anti-tedium rule (risk R1) |
| 9 | Exclusion bearings never fall inside a fall corridor | same | an unwinnable felling |
| 10 | Every tuning key referenced by `sim/` exists in `data/tuning/` | same | |
| 11 | Task frontmatter is valid and complete | `tools/tasks.py validate` | Definition of Ready |
| 12 | Task dependency graph is acyclic and all IDs resolve | same | |
| 13 | No file-ownership conflict between concurrent tasks | same | parallel safety |
| 14 | Every `spec:` reference resolves to a real file | same | self-contained work items |
| 15 | No broken internal doc links | `tools/check_links.py` | |
| 16 | **No real person's name anywhere in the repo** | `tools/check_conventions.py:likeness` | [IP policy](../05-legal/ip-and-likeness.md) |
| 17 | Godot formatting and lint | `gdformat --check`, `gdlint` | |

Rules 1–4 and 16 are the ones that exist specifically because agents will otherwise break them
confidently and silently.

## Rule 4 in detail (the one people push back on)

`sim/` may not contain a numeric literal outside this allowlist:

```
0, 1, -1, 2, 0.0, 1.0, 0.5, 100.0        structural / trivially obvious
array indices and loop bounds
values on a line ending in  # literal: <reason>
```

Everything else must come from `data/tuning/*.json`. So this fails:

```gdscript
if grip < 20.0:                       # ✗
    apply_tremor()
```

and this passes:

```gdscript
if grip < tuning.grip_tremor_threshold:     # ✓
    apply_tremor()
```

**Why it's worth the friction:** it's what makes rebalancing the whole game a JSON edit plus
`make test-replay`, with no engineer in the loop. That property is load-bearing for the production
plan (12 levels, small team) and it evaporates the moment constants start living in code.

## Rule 16 in detail

`tools/check_conventions.py` greps the working tree **and the commit history** for a configured
list of real names associated with the subject matter. The list lives in
`tools/likeness_denylist.txt`.

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
