# ADR-0006 — Move to Godot 4

- **Status:** Accepted
- **Date:** 2026-09-18
- **Supersedes:** [ADR-0004](0004-engine-change-to-unreal.md)
- **Follows:** [ADR-0005](0005-godot-reconsidered.md), which evaluated the question
- **Decision:** Godot 4.7, with `SteeplejackSim` unchanged behind a GDExtension
- **Deciders:** project lead

## Decision

Move to Godot 4.7. `SteeplejackSim` crosses unchanged. `Source/SteeplejackGame/`,
`tools/editor/*.py` and `Content/` are replaced.

## Why, in one paragraph

[ADR-0005](0005-godot-reconsidered.md) has the full argument. The short version is that ADR-0004
mitigated the loss of agent-executability with the sim/presentation split, and that split assigns
`Content/` and `Source/SteeplejackGame/` **to humans**. There is no human doing Unreal presentation
work on this project. The mitigation protected the logic layer and left uncovered the layer that was
actually failing. Two further points from the project lead compounded it: an agent's competence is
not engine-independent (Unreal's gameplay layer is conventionally authored in Blueprints, which are
binary and cannot appear in any text corpus), and Unreal offers many plausible-but-wrong paths where
Godot offers one — then reports success having done nothing, three separate times in a single
session.

## Why Godot rather than Unity

Unity was the stronger *graphics* answer: HDRP gets closer to Unreal than Godot does, and C# has a
large, readable corpus. Rejected anyway, on the same principle that decided against Unreal:

- **HDRP versus URP is exactly the high-stakes fork that keeps costing us.** Picking wrong is
  expensive and the failure is slow.
- **Unity scenes are GUID-keyed YAML.** Nominally text, not meaningfully reviewable. Godot's
  `.tscn` is a file you can read, write and diff — this ADR's scene file was hand-written.
- **Licensing history is a business risk** the project does not need to carry.

## What this costs, stated plainly

**The visual target changes.** ADR-0004 was right that Godot will not reach "a photographed-looking
brick chimney" without a rendering programmer we do not have. The art direction becomes **stylised
realism**: strong materials, strong light, atmosphere doing the work.
[`../../01-gdd/13-art-direction.md`](../../01-gdd/13-art-direction.md) is rewritten to match —
that is a task, not a footnote.

The mitigating fact, already noted in ADR-0004: this game's geometry is *procedural cylinders*
generated from JSON, and its look is almost entirely materials, lighting and atmosphere. That is the
part of the gap where Godot is adequate-to-good, not the part where it is weak — huge complex
scenes, film-grade GI, virtualised geometry, none of which this game needs.

**Four risks return to the register** and need owners: Chaos Geometry Collections for felling (R3),
Control Rig and Full Body IK for hand placement (R2), MetaSounds for the tap test (R6), and
Megascans for reading joint quality as a close-range material (R1).

## What it buys

- **R8 is retired, not mitigated.** `.tscn`, `.gd` and `project.godot` are text. An agent can write
  and review a scene.
- **Iteration.** GDScript reloads. No 3–4 minute rebuild, no editor-holds-the-module dance.
- **Louder failures.** Godot errors print. The specific pattern that cost most — Unreal reporting
  success having done nothing — is largely absent.
- **CORE-016 dissolves.** It was blocked because Unreal disables exceptions for non-editor targets
  and the sim throws. That constraint does not exist here.
- **No licence, no account gate, no 40 GB engine.** The editor is a 120 MB binary.

## The port, proven rather than assumed

Done before this ADR was written, because the decision depended on it:

| | |
|---|---|
| Engine | Godot 4.7.2 stable, `~/.local/bin/godot` |
| Bindings | godot-cpp `master`, API version 4.7, fetched to `.deps/` by `make godot-deps` |
| Extension | `Source/SteeplejackGodot/`, built by `make godot-build` into `godot/bin/` |
| Proof | `make godot-script SCRIPT=res://scripts/prove_sim.gd` |

The proof runs GDScript to GDExtension to `SteeplejackSim` to `data/tuning/*.json` and back: real
tuning values, the tuning hash that ADR-0003 stamps into replays, and CORE-007's guarantee that a
missing key refuses to answer rather than reading as zero. Nothing is mocked and the sim was not
edited.

`data/` stays at the repository root rather than moving under `res://`. The sim's own test suite
reads those files with no engine present, and two copies of the tuning would eventually be two
answers.

## Decisions taken while porting

- **`make check` is unchanged and still engine-free.** The GDExtension is behind
  `-DSTEEPLEJACK_GODOT=ON`, off by default, so a test edit still costs about a second.
- **Strict warnings moved from directory scope to target scope.** `-Werror -Wconversion` survives
  on our code; godot-cpp's include directories are marked `SYSTEM` because no third-party codebase
  survives those flags.
- **godot-cpp lives in `.deps/`, gitignored, not `third_party/`.** That directory is for vendored
  single-header libraries with no transitive dependencies, and says so.
- **Exceptions stop at the boundary.** The sim throws by design; an exception crossing a C ABI is
  undefined behaviour. Every bound method catches and converts.
- **`GODOTCPP_USE_STATIC_CPP=OFF` locally.** An immutable host has no static libstdc++; a shipping
  build turns it back on.

## Consequences

- ADR-0004 is superseded, not deleted. Its reasoning was correct for the staffing it assumed.
- ADR-0001's premise is live again, and its conclusion with it.
- ADR-0002 and ADR-0003 survive. Determinism, the fixed step and the replay hash are all in the
  sim, which did not move.
- `docs/03-tech/interfaces.md` survives — the signatures are the C++ ones and they did not change.
- Every design document outside art direction is unaffected. That was the point of keeping them
  engine-agnostic, and it has now paid out twice.
- Tasks touching `SteeplejackGame`, `Content/` or `tools/editor/` need re-scoping. The
  `editor_required` queue should mostly empty: scene work is text now.

## Reversal cost

Lower than last time and for the same reason: the sim is the game and it has never moved. If Godot
turns out to be the wrong call, what is lost is a presentation layer measured in days.

## Note — 2026-09-19, Unreal removed

The Unreal side was kept in the repository after this decision, and it cost more than keeping it
was worth. A session-start hook launched a headless Unreal editor for its MCP tools on every session
and every resume. The editor grew to 33 GB. Two sessions starting close together launched two of
them, and the machine ran out of memory and the kernel killed one.

So it is gone: `Source/SteeplejackGame/`, `Content/`, `Config/`, `Steeplejack.uproject`, the editor
tools, the MCP hook and `.mcp.json`, and every Unreal target in the Makefile. `make run` now plays
the Godot game. Unreal-only tasks are `cut`, each with a line saying why and, where the feature
exists in Godot, where. Convention rule 1 now also forbids Godot headers in `SteeplejackSim`, and
rule 18 (Blueprints) is retired.

Docs under `docs/03-tech/` other than the ADRs still describe the Unreal architecture in places
(the module table, performance budgets for Nanite and Lumen, save paths). Where they disagree with
this ADR and `AGENTS.md`, those two win.

