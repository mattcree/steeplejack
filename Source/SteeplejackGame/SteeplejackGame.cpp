// The primary game module entry point. Nothing else belongs in this file.
//
// No gameplay here, and no startup logic: the fixed-step driver that actually runs the
// simulation is CORE-005. Per ADR-0004 every gameplay decision lives in SteeplejackSim,
// which this module depends on but never reaches around.

#include "CoreMinimal.h"
#include "Modules/ModuleManager.h"

IMPLEMENT_PRIMARY_GAME_MODULE(FDefaultGameModuleImpl, SteeplejackGame, "SteeplejackGame");
