# Standalone build of SteeplejackSim and its tests.
#
# This exists so the gameplay layer can be built and tested WITHOUT Unreal installed —
# about 20 seconds in CI instead of a 40 GB engine download. It is what keeps the layer
# agents own fast to iterate on. See docs/03-tech/adr/0004-engine-change-to-unreal.md.
#
#   make check        # conventions, data, task graph, links, build, tests
#   make test-unit    # just the build and tests
#
# If this build breaks, SteeplejackSim has probably acquired an Unreal dependency and
# tools/check_conventions.py should have caught it. Fix the dependency, not this file.

cmake_minimum_required(VERSION 3.20)
project(SteeplejackSim CXX)

# C++20 to match SteeplejackSim.Build.cs. UE 5.8 removed C++17 support; these two must
# stay equal or the standalone gate stops proving what the engine will do.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(MSVC)
  add_compile_options(/W4 /WX /permissive- /fp:precise)
else()
  add_compile_options(-Wall -Wextra -Werror -Wshadow -Wconversion)
  # Required for the standalone and in-engine builds to produce identical floats.
  # See ADR-0003 on determinism.
  add_compile_options(-ffp-contract=off)
endif()

# ---------------------------------------------------------------- the sim
# Globbed so that adding a module is just adding a file. Reconfigure is automatic
# via CONFIGURE_DEPENDS.
file(GLOB_RECURSE SIM_SOURCES CONFIGURE_DEPENDS Source/SteeplejackSim/Private/*.cpp)

add_library(steeplejack_sim STATIC ${SIM_SOURCES})
target_include_directories(steeplejack_sim PUBLIC Source/SteeplejackSim/Public)
if(NOT SIM_SOURCES)
  # No modules yet (pre-CORE-003). Keep the target valid so the test binary still links.
  target_sources(steeplejack_sim PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/empty.cpp)
  file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/empty.cpp
       "// Placeholder so steeplejack_sim links before the first module lands (CORE-003).\n")
  message(STATUS "SteeplejackSim has no modules yet — building the harness only.")
endif()

# ---------------------------------------------------------------- the tests
# ALWAYS built, even with no sim modules. tests/unit/test_harness.cpp proves the
# toolchain works end to end, so `make check` is never vacuously green.
file(GLOB_RECURSE TEST_SOURCES CONFIGURE_DEPENDS tests/*.cpp)

add_executable(sim_tests ${TEST_SOURCES})
target_link_libraries(sim_tests PRIVATE steeplejack_sim)
target_include_directories(sim_tests PRIVATE third_party/doctest)

enable_testing()
add_test(NAME sim COMMAND sim_tests)
