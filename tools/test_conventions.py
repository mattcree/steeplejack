#!/usr/bin/env python3
"""Tests for the convention checkers.

docs/06-workflow/04-enforced-conventions.md says: "A rule with no test is not a rule;
it's a future false positive that someone will disable." This is that test.

Each case asserts BOTH that the checker catches the bad input AND that it leaves a
legitimate equivalent alone. The second half is what stops rules getting switched off.

    python3 tools/test_conventions.py
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIM_REL = os.path.join("Source", "SteeplejackSim", "Private")

failures: list[str] = []


def run_checker(snippet: str) -> str:
    """Drop a snippet into the sim tree, run the checker, clean up, return its output."""
    d = os.path.join(ROOT, SIM_REL)
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, "_ConventionTest.cpp")
    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write(snippet)
        r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "check_conventions.py")],
                           cwd=ROOT, capture_output=True, text=True, timeout=120)
        return r.stdout + r.stderr
    finally:
        if os.path.exists(path):
            os.remove(path)


def case(name: str, snippet: str, *, must_flag: str | None, must_not_flag: str | None = None):
    out = run_checker(snippet)
    flagged = "_ConventionTest.cpp" in out
    if must_flag and not flagged:
        failures.append(f"{name}: expected a violation ({must_flag}) but the checker passed")
    elif must_flag and must_flag.lower() not in out.lower():
        failures.append(f"{name}: flagged, but the message did not mention {must_flag!r}\n"
                        f"      got: {out.strip()[:200]}")
    if must_not_flag is not None and flagged:
        failures.append(f"{name}: FALSE POSITIVE — legitimate code was flagged\n"
                        f"      got: {out.strip()[:300]}")
    print(f"  {'ok  ' if not failures or failures[-1].split(':')[0] != name else 'FAIL'} {name}")


HEADER = "#include <cstdint>\n#include <vector>\nnamespace sj {\n"
FOOTER = "\n}  // namespace sj\n"


def main() -> int:
    print("rule 1 — no Unreal headers")
    case("unreal header caught", HEADER + '#include "CoreMinimal.h"' + FOOTER,
         must_flag="Unreal headers")
    case("std header allowed", HEADER + "int F() { return 0; }" + FOOTER,
         must_flag=None, must_not_flag="")

    print("rule 1 — no Unreal types")
    case("FVector caught", HEADER + "float F(const FVector& v) { return v.X; }" + FOOTER,
         must_flag="Unreal types")
    case("sj::Vec3 allowed", HEADER + "struct Vec3 { float x, y, z; };\n"
         "float F(const Vec3& v) { return v.x; }" + FOOTER, must_flag=None, must_not_flag="")
    case("TArray caught", HEADER + "TArray<int> F();" + FOOTER, must_flag="Unreal types")
    case("std::vector allowed", HEADER + "std::vector<int> F();" + FOOTER,
         must_flag=None, must_not_flag="")

    print("rule 19 — wobble is computed in Wobble.cpp and nowhere else")
    case("own wobble caught", HEADER + "class Tuning { public: float GetF(const char*) const; };\n"
         "float F(const Tuning& t) { return t.GetF(\"baseWobbleDegrees\") * 2.0f; }" + FOOTER,
         must_flag="wobble tuning read outside Wobble.cpp")
    case("calling the one wobble allowed", HEADER +
         "struct Meters; struct MeterContext; class Tuning;\n"
         "float WobbleAmplitudeDeg(const Meters&, const MeterContext&, float, const Tuning&);\n"
         "float F(const Meters& m, const MeterContext& c, const Tuning& t) "
         "{ return WobbleAmplitudeDeg(m, c, 0.0f, t) * 2.0f; }" + FOOTER,
         must_flag=None, must_not_flag="")

    print("rule 2 — no ambient RNG, no mutable statics")
    case("rand() caught", HEADER + "int F() { return rand(); }" + FOOTER, must_flag="ambient RNG")
    case("mt19937 caught", HEADER + "void F() { std::mt19937 g; (void)g; }" + FOOTER,
         must_flag="ambient RNG")
    case("mutable static caught", HEADER + "static float gCache = 0.0f;" + FOOTER,
         must_flag="mutable static")
    case("constexpr static allowed", HEADER + "static constexpr float kTick = 1.0f;" + FOOTER,
         must_flag=None, must_not_flag="")

    print("rule 3 — no clocks, no stdout")
    case("chrono caught", HEADER + "void F() { auto t = std::chrono::steady_clock::now(); (void)t; }"
         + FOOTER, must_flag="clock")
    case("printf caught", HEADER + 'void F() { printf("x"); }' + FOOTER, must_flag="stdout")
    case("float dt parameter allowed", HEADER + "void Step(float dt) { (void)dt; }" + FOOTER,
         must_flag=None, must_not_flag="")

    print("rule 4 — no magic numbers")
    case("magic float caught", HEADER + "float F(float g) { return g < 20.0f ? 2.5f : 0.0f; }"
         + FOOTER, must_flag="magic number")
    case("f-suffixed magic caught", HEADER + "float F() { return 3.7f; }" + FOOTER,
         must_flag="magic number")
    case("allowed literals pass", HEADER + "float F() { return 1.0f; }\n"
         "int G() { return 32; }" + FOOTER, must_flag=None, must_not_flag="")
    case("annotated literal passes", HEADER +
         "float F() { return 9.81f; }  // literal: standard gravity, not a balance value"
         + FOOTER, must_flag=None, must_not_flag="")
    case("constexpr declaration passes", HEADER + "constexpr float kGravity = 9.81f;" + FOOTER,
         must_flag=None, must_not_flag="")

    print("rule 10 — tuning keys must exist")
    case("unknown tuning key caught", HEADER +
         'float F(const Tuning& t) { return t.GetF("no_such_key_at_all"); }' + FOOTER,
         must_flag="not found in data/tuning")
    case("real tuning key passes", HEADER +
         'float F(const Tuning& t) { return t.GetF("grip_tremor_threshold"); }' + FOOTER,
         must_flag=None, must_not_flag="")

    print()
    for f in failures:
        print(f"\033[31mFAIL\033[0m {f}")
    print(f"{len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
