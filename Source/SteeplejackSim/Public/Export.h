#pragma once

// SJ_API — symbol visibility at the UE boundary.
//
// UBT builds SteeplejackSim as its own shared library with `-fvisibility-ms-compat`, which hides a
// class's out-of-line members and a namespace's free functions unless they are explicitly
// exported. SteeplejackGame then fails to link against them, and it fails at the *link* step with
// "undefined symbol", long after every other gate has gone green — `make check` cannot see this at
// all, because the CMake build has no module boundary to cross.
//
// UE's own answer is the UBT-generated STEEPLEJACKSIM_API macro. It cannot be used here: it
// expands to DLLEXPORT, which is defined in an Unreal header, and rule 1 forbids Unreal headers
// anywhere under this module (ADR-0004). So: the plain compiler attribute, which needs no engine
// header and expands to nothing when the compiler has no such thing. The standalone CMake build is
// unaffected either way.
//
// Mark anything SteeplejackGame may call: classes with out-of-line members, and free functions.
// Header-only aggregates like those in Types.h neither need it nor should have it.
//
// Known gap: MSVC has no visibility attribute — Windows needs dllexport when building the module
// and dllimport when consuming it, which cannot come from one macro defined inside the module's
// own header. It needs a define supplied by the build. The project builds on Linux today.

#if defined(__GNUC__) || defined(__clang__)
#define SJ_API __attribute__((visibility("default")))
#else
#define SJ_API
#endif
