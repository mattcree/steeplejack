#include "SteeplejackTuning.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace steeplejack {

void SteeplejackTuning::_bind_methods()
{
	ClassDB::bind_method(D_METHOD("load_all", "dir"), &SteeplejackTuning::load_all);
	ClassDB::bind_method(D_METHOD("get_f", "key", "fallback"), &SteeplejackTuning::get_f, DEFVAL(0.0));
	ClassDB::bind_method(D_METHOD("has", "key"), &SteeplejackTuning::has);
	// Not "hash": Object already has one, and shadowing it would be a silent override.
	ClassDB::bind_method(D_METHOD("tuning_hash"), &SteeplejackTuning::tuning_hash);
	ClassDB::bind_method(D_METHOD("get_last_error"), &SteeplejackTuning::get_last_error);
}

bool SteeplejackTuning::load_all(const String& dir)
{
	// The sim throws, and an exception crossing back into the engine through a C ABI is undefined
	// behaviour, not an error message. Every entry point here is a firebreak: the sim keeps its
	// loud failures, Godot gets a bool and a reason.
	try
	{
		tuning = std::make_unique<sj::Tuning>(sj::Tuning::LoadAll(dir.utf8().get_data()));
		last_error = String();
		return true;
	}
	catch (const std::exception& e)
	{
		tuning.reset();
		last_error = String(e.what());
		UtilityFunctions::push_error("tuning: ", last_error);
		return false;
	}
}

double SteeplejackTuning::get_f(const String& key, double fallback) const
{
	if (!tuning)
	{
		UtilityFunctions::push_error("tuning: get_f before a successful load_all");
		return fallback;
	}
	try
	{
		return static_cast<double>(tuning->GetF(key.utf8().get_data()));
	}
	catch (const std::exception& e)
	{
		// CORE-007 made a missing key throw precisely so it could never read as zero. Returning a
		// fallback would reintroduce that, so the error is pushed where a caller will see it —
		// the exception already names the key and the nearest one that does exist.
		UtilityFunctions::push_error("tuning: ", String(e.what()));
		return fallback;
	}
}

bool SteeplejackTuning::has(const String& key) const
{
	if (!tuning) { return false; }
	try
	{
		(void)tuning->GetF(key.utf8().get_data());
		return true;
	}
	catch (const std::exception&)
	{
		return false;
	}
}

String SteeplejackTuning::tuning_hash() const
{
	return tuning ? String(tuning->Hash().c_str()) : String();
}

}  // namespace steeplejack
