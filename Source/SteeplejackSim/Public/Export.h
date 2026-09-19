#pragma once

// SJ_API — symbol visibility, for when SteeplejackSim is built as a shared library.
//
// Built with hidden visibility, a shared library hides a class's out-of-line members and a
// namespace's free functions unless they are exported, and whatever links against it fails at the
// *link* step with "undefined symbol" — which `make check` cannot see, because the CMake build has
// no library boundary to cross. This was learned under Unreal, which built the sim that way; the
// Godot binding links it too, and the macro costs nothing. It is the plain compiler attribute, so
// it needs no engine header.
//
// Mark anything the binding may call: classes with out-of-line members, and free functions.
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
