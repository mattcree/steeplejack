# Standalone build of SteeplejackSim and its tests.
#
# This exists so the gameplay layer can be built and tested with no engine installed, in
# seconds. It is what keeps the layer agents own fast to iterate on. The Godot game links the
# same sources through Source/SteeplejackGodot (ADR-0006).
#
#   make check        # conventions, data, task graph, links, build, tests
#   make test-unit    # just the build and tests
#
# If this build breaks, SteeplejackSim has probably acquired an engine dependency and
# tools/check_conventions.py should have caught it. Fix the dependency, not this file.

cmake_minimum_required(VERSION 3.20)
project(SteeplejackSim CXX)

# C++20 to match SteeplejackSim.Build.cs. UE 5.8 removed C++17 support; these two must
# stay equal or the standalone gate stops proving what the engine will do.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Held in a variable and applied per target rather than to the whole directory. godot-cpp is
# added as a subdirectory below and would inherit -Werror -Wconversion, which no third-party
# codebase survives. Our code keeps every one of these.
if(MSVC)
  set(SJ_FLAGS /W4 /WX /permissive- /fp:precise)
else()
  # -ffp-contract=off is not a warning setting: the standalone and in-engine builds must produce
  # identical floats. See ADR-0003 on determinism.
  set(SJ_FLAGS -Wall -Wextra -Werror -Wshadow -Wconversion -ffp-contract=off)
endif()

# ---------------------------------------------------------------- the sim
# Globbed so that adding a module is just adding a file. Reconfigure is automatic
# via CONFIGURE_DEPENDS.
file(GLOB_RECURSE SIM_SOURCES CONFIGURE_DEPENDS Source/SteeplejackSim/Private/*.cpp)

add_library(steeplejack_sim STATIC ${SIM_SOURCES})
target_include_directories(steeplejack_sim PUBLIC Source/SteeplejackSim/Public)
target_compile_options(steeplejack_sim PRIVATE ${SJ_FLAGS})
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
target_compile_options(sim_tests PRIVATE ${SJ_FLAGS})
target_include_directories(sim_tests PRIVATE third_party/doctest)

enable_testing()
add_test(NAME sim COMMAND sim_tests)

# ---------------------------------------------------------------- the Godot extension
# Off by default, and deliberately so: `make check` must stay the fast, engine-free gate it has
# always been. Turning this on pulls in godot-cpp, which is a minute of compiling we do not want
# between a test edit and a test result.
#
#   make godot-deps      # fetch godot-cpp into .deps/ (gitignored, not vendored — see
#                        # third_party/README.md, which is for single-header libraries)
#   make godot-build     # this target
option(STEEPLEJACK_GODOT "Build the Godot GDExtension" OFF)

if(STEEPLEJACK_GODOT)
  if(NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/.deps/godot-cpp/CMakeLists.txt)
    message(FATAL_ERROR "godot-cpp is missing — run `make godot-deps`")
  endif()
  add_subdirectory(.deps/godot-cpp godot-cpp EXCLUDE_FROM_ALL)

  # The sim is a static library being linked into a shared object, so it has to be built
  # position-independent. Without this the link fails with a relocation error that names an
  # object file rather than the cause.
  set_target_properties(steeplejack_sim PROPERTIES POSITION_INDEPENDENT_CODE ON)

  # godot-cpp's headers do not survive -Wconversion -Werror, and they are our headers' problem the
  # moment we include them. Marking its include directories SYSTEM silences warnings from inside
  # them while keeping every one of those flags pointed at our own code, which is the point.
  get_target_property(GODOT_CPP_INCLUDES godot-cpp INTERFACE_INCLUDE_DIRECTORIES)
  set_target_properties(godot-cpp PROPERTIES
    INTERFACE_SYSTEM_INCLUDE_DIRECTORIES "${GODOT_CPP_INCLUDES}")

  file(GLOB_RECURSE GD_SOURCES CONFIGURE_DEPENDS Source/SteeplejackGodot/*.cpp)
  add_library(steeplejack_gd SHARED ${GD_SOURCES})
  target_compile_options(steeplejack_gd PRIVATE ${SJ_FLAGS})
  target_link_libraries(steeplejack_gd PRIVATE steeplejack_sim godot::cpp)

  # Land it where the .gdextension file says it is.
  set_target_properties(steeplejack_gd PROPERTIES
    OUTPUT_NAME "steeplejack"
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/godot/bin)
endif()
