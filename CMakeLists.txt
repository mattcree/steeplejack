# Standalone build of SteeplejackSim and its tests.
#
# This exists so the gameplay layer can be built and tested WITHOUT Unreal
# installed — ~20 seconds in CI instead of a 40 GB engine download. It is what
# keeps the layer agents own fast to iterate on. See ADR-0004.
#
#   cmake -B build -DCMAKE_BUILD_TYPE=Release
#   cmake --build build -j
#   ./build/sim_tests
#
# If this build breaks, SteeplejackSim has acquired an Unreal dependency and
# tools/check_conventions.py should have caught it. Fix the dependency, not this file.

cmake_minimum_required(VERSION 3.20)
project(SteeplejackSim CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(MSVC)
  add_compile_options(/W4 /WX /permissive-)
else()
  add_compile_options(-Wall -Wextra -Werror -Wshadow -Wconversion)
endif()

file(GLOB_RECURSE SIM_SOURCES CONFIGURE_DEPENDS Source/SteeplejackSim/Private/*.cpp)
file(GLOB_RECURSE SIM_HEADERS CONFIGURE_DEPENDS Source/SteeplejackSim/Public/*.h)

if(SIM_SOURCES)
  add_library(steeplejack_sim STATIC ${SIM_SOURCES})
  target_include_directories(steeplejack_sim PUBLIC Source/SteeplejackSim/Public)

  file(GLOB_RECURSE TEST_SOURCES CONFIGURE_DEPENDS tests/*.cpp)
  if(TEST_SOURCES)
    add_executable(sim_tests ${TEST_SOURCES})
    target_link_libraries(sim_tests PRIVATE steeplejack_sim)
    target_include_directories(sim_tests PRIVATE third_party/doctest)
    enable_testing()
    add_test(NAME sim COMMAND sim_tests)
  endif()
else()
  message(STATUS "No sim sources yet — nothing to build. Start with CORE-003/CORE-004.")
endif()
