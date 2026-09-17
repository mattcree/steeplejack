// The primary game module entry point.
//
// No gameplay here. Per ADR-0004 every gameplay decision lives in SteeplejackSim, which this
// module depends on but never reaches around. What it does own is registration: telling the
// engine about the things this project adds to the editor.

#include "CoreMinimal.h"
#include "Modules/ModuleManager.h"

#include "Misc/CoreDelegates.h"
#include "ToolsetRegistry/UToolsetRegistry.h"
#include "Tools/SteeplejackToolset.h"

DEFINE_LOG_CATEGORY_STATIC(LogSteeplejackModule, Log, All);

class FSteeplejackGameModule : public FDefaultGameModuleImpl
{
public:
	virtual void StartupModule() override
	{
		FDefaultGameModuleImpl::StartupModule();

		// Register this project's MCP toolset once the engine is up. Toolsets are registered
		// explicitly — the registry does not scan for UToolsetDefinition subclasses — so without
		// this the class compiles, links, and is simply never offered to an agent.
		FCoreDelegates::GetOnPostEngineInit().AddLambda([]
		{
			UToolsetRegistry::RegisterToolsetClass(USteeplejackToolset::StaticClass());
			UE_LOG(LogSteeplejackModule, Display,
				TEXT("SJTOOLS: registered USteeplejackToolset with the MCP toolset registry"));
		});
	}
};

IMPLEMENT_PRIMARY_GAME_MODULE(FSteeplejackGameModule, SteeplejackGame, "SteeplejackGame");
