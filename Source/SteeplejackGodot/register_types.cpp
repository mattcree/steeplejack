// The GDExtension entry point.
//
// Godot loads godot/bin/libsteeplejack.so and calls steeplejack_library_init, which is the only
// symbol the engine knows about. Everything the game can reach from GDScript is registered here.

#include "Jack.h"
#include "SteeplejackTuning.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

namespace {

void initialize_steeplejack(ModuleInitializationLevel level)
{
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE)
	{
		return;
	}
	GDREGISTER_CLASS(steeplejack::SteeplejackTuning);
	GDREGISTER_CLASS(steeplejack::Jack);
}

void uninitialize_steeplejack(ModuleInitializationLevel)
{
}

}  // namespace

extern "C" GDExtensionBool GDE_EXPORT steeplejack_library_init(
	GDExtensionInterfaceGetProcAddress get_proc_address,
	const GDExtensionClassLibraryPtr library,
	GDExtensionInitialization* initialization)
{
	GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
	init.register_initializer(initialize_steeplejack);
	init.register_terminator(uninitialize_steeplejack);
	init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init.init();
}
