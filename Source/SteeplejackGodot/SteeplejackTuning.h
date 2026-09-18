// Tuning, reachable from GDScript.
//
// The first thing bound across the GDExtension boundary, chosen because it exercises the whole
// chain rather than a toy: it reads files from disk, parses JSON, throws on a missing key, and
// lives entirely in SteeplejackSim. If this works, the port works.
//
// Rule 4 still applies on the other side of the boundary — a number typed into a .gd file is the
// same magic number it would be in C++, and `data/tuning/*.json` is still the only place it
// belongs.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>

#include "Tuning.h"

#include <memory>

namespace steeplejack {

class SteeplejackTuning : public godot::RefCounted
{
	GDCLASS(SteeplejackTuning, godot::RefCounted)

public:
	SteeplejackTuning() = default;
	~SteeplejackTuning() override = default;

	/** Read every *.json under `dir`. False on failure; `get_last_error` says why. */
	bool load_all(const godot::String& dir);

	/** A tuned number by dotted key. Returns `fallback` if it is missing, and says so loudly. */
	double get_f(const godot::String& key, double fallback) const;

	/** Whether a key exists, for code that wants to ask rather than be told off. */
	bool has(const godot::String& key) const;

	/** Stamped into replays so a tuning change cannot silently invalidate one. See ADR-0003. */
	godot::String tuning_hash() const;

	godot::String get_last_error() const { return last_error; }

protected:
	static void _bind_methods();

private:
	std::unique_ptr<sj::Tuning> tuning;
	godot::String last_error;
};

}  // namespace steeplejack
