---
id: CORE-016
title: The packaged game target does not compile — exceptions are disabled outside the editor
milestone: M0
discipline: [ENG]
estimate_days: 0.25
status: blocked
assignee: null
depends_on: [CORE-007, CORE-014, CORE-015]
owns:
  - Source/Steeplejack.Target.cs
  - docs/03-tech/interfaces.md
  - Makefile
reads:
  - Source/SteeplejackSim/Public/Tuning.h
  - Source/SteeplejackSim/SteeplejackSim.Build.cs
spec:
  - docs/03-tech/interfaces.md#tuningh--core-007
  - docs/03-tech/adr/0004-engine-change-to-unreal.md
verify: make build-game-shipping
editor_required: false
risk: R8
---

## Goal
`Steeplejack` (the packaged game target) compiles, and a gate notices if it stops.

## Why
It does not compile today. Nothing has ever built it — `make build-game` builds
`SteeplejackEditor`, and there is no target for the game.

## Context
UBT forces exceptions **on** for editor targets and **off** for everything else
(`UEBuildTarget.cs`):

```csharp
GlobalCompileEnvironment.bEnableExceptions = Rules.bForceEnableExceptions
    || (Rules.bCompileAgainstEditor && !Rules.bUseAutoRTFMCompiler);
```

`bCompileAgainstEditor` defaults to `Type == TargetType.Editor`. `Steeplejack.Target.cs` is
`TargetType.Game` and does not set `bForceEnableExceptions`, so it gets `-fno-exceptions`:

```
$ Build.sh Steeplejack Linux Development -project=Steeplejack.uproject
Tuning.cpp:73:9: error: cannot use 'throw' with exceptions disabled
  ... 17 errors generated
TuningHotReload.cpp: error: cannot use 'try' with exceptions disabled
Result: Failed (OtherCompilationError)
```

This is **not CORE-007's bug**. It is `interfaces.md`'s error contract meeting UE's non-editor
build configuration. CORE-007 is only the first task to write a `throw` that UBT ever compiles, so
it is the first to expose it. Every sim module that follows the same contract will hit it.

`interfaces.md` is emphatic about the contract and right to be:

> A missing key **throws with the key name and the file it was expected in**. It never returns
> zero — a silently-zero tuning value is the worst possible failure mode for a balance-driven game.

But the same page's Conventions section says the opposite as a general rule: *"Functions that can
fail return a result struct with an explicit outcome enum, never a null pointer."* The two have
never been reconciled because nothing had failed yet.

## Blocked
**The question:** should `SteeplejackSim` use C++ exceptions, or not?

**What I tried.** Confirmed the editor target builds (`make build-game` → Succeeded, and its
response file carries `-fexceptions`), and that the game target does not, with the errors above.
Confirmed `bForceEnableExceptions` is an uninitialised auto-property on `TargetRules`, so nothing
sets it implicitly.

**Options.**

1. **`bForceEnableExceptions = true` in `Steeplejack.Target.cs`.** One line. Keeps the contract
   `interfaces.md` specifies and that CORE-007 implements and tests. Cost: exception tables and
   some inlining loss in shipping, project-wide, for a mechanism used only at load time.
2. **Change the contract to a result struct**, matching the Conventions section. Costs a breaking
   change to `interfaces.md` and a rewrite of `Tuning`'s error paths, and it puts the burden of
   checking on every caller — which is how a silently-zero tuning value gets back in, since an
   ignored result is easier to write than an ignored exception.
3. **Exceptions at load time only**, results at run time: keep `throw` for `LoadAll`/`Parse`, make
   the getters return results. Splits the rule into two rules, which is how rules stop being
   remembered.

**Recommendation: option 1.** The contract is deliberate, documented, tested, and the failure it
prevents — a silently-zero constant in a balance-driven game — is exactly the class of bug this
project spends the most effort on. The cost is real but it is paid once, at load, in code that runs
five times a session. Option 2 trades a compile-time guarantee for a convention, and this repo's
whole thesis is that conventions need enforcement.

**What I need:** a yes to option 1, or a decision to take 2 or 3. Both `Steeplejack.Target.cs` and
`interfaces.md` are outside CORE-007's `owns:`, and a change to the contract page is a breaking
change by the rules of that page, so this is not an implementer's call.

## Acceptance
1. `Steeplejack` (`TargetType.Game`) compiles for Linux Development.
2. Whichever way the decision goes, `interfaces.md`'s Conventions section and its `Tuning.h`
   section agree with each other and with the code.
3. A `make` target builds the game target, so this cannot silently rot again. `make build-game`
   builds only the editor today, which is why nobody noticed.
4. `make check` and `make build-game` stay green.

## Out of scope
Do not package a shipping build or set up cooking — this is about compiling, not shipping.

## Plan
<!-- Filled in by the implementer before building, if estimate_days > 1. -->

## Outcome
<!-- Filled in at handoff: what changed, decisions made, surprises, follow-ups. -->
