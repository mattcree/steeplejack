// Harness smoke test.
//
// This file deliberately tests NOTHING about the game. It exists to prove that the
// standalone toolchain works end to end — that SteeplejackSim compiles with no Unreal
// present, that doctest links, that the test binary runs, and that CI can see a failure.
//
// Delete this file once CORE-003 lands a real module with real tests. Until then it is
// what keeps `make check` honest rather than vacuously green.

#include "doctest.h"

#include <cstdint>
#include <string>
#include <vector>

TEST_CASE("Harness: doctest links and runs")
{
    CHECK(true);
    CHECK_FALSE(false);
}

TEST_CASE("Harness: the toolchain is C++17")
{
    // Structured bindings and if-init are C++17. If this file compiles, the standard
    // level set in CMakeLists.txt and SteeplejackSim.Build.cs agree.
    const std::vector<std::pair<int, std::string>> v{{1, "one"}};
    for (const auto& [n, name] : v)
    {
        CHECK(n == 1);
        CHECK(name == "one");
    }

    if (const std::size_t size = v.size(); true)
    {
        CHECK(size == 1u);
    }
}

TEST_CASE("Harness: fixed-width types are available without Unreal")
{
    // SteeplejackSim uses int32_t/uint8_t rather than int32/uint8 precisely because
    // it must not depend on Unreal's type aliases. See ADR-0004.
    const std::int32_t  a = -1;
    const std::uint8_t  b = 255u;
    CHECK(a < 0);
    CHECK(b == 255u);
}

TEST_CASE("Harness: floating point contraction is disabled")
{
    // -ffp-contract=off is required for the standalone and in-engine builds to agree.
    // This does not prove the flag is set, but it documents why it matters and will
    // be replaced by a real determinism test in CORE-003/CORE-006.
    const float a = 0.1f;
    const float b = 0.2f;
    const float c = a * b + a;
    CHECK(c == doctest::Approx(0.12f));
}

