// The ONLY Unreal-aware file in this module.
//
// SteeplejackSim is plain C++17 and must compile standalone under CMake with no
// Unreal present (ADR-0004). This file exists solely to let the UE build system
// link the same sources into the game. Do not add Unreal dependencies here — if
// the sim needs something from the engine, the boundary is in the wrong place.

using UnrealBuildTool;

public class SteeplejackSim : ModuleRules
{
	public SteeplejackSim(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.NoPCHs;
		bUseUnity = false;
		CppStandard = CppStandardVersion.Cpp17;

		// Deliberately minimal. "Core" only, and only for the build glue.
		PublicDependencyModuleNames.AddRange(new string[] { "Core" });

		PublicIncludePaths.Add(ModuleDirectory + "/Public");
		PrivateIncludePaths.Add(ModuleDirectory + "/Private");
	}
}
