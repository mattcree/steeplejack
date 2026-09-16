// The ONLY Unreal-aware file in this module.
//
// SteeplejackSim is plain C++20 and must compile standalone under CMake with no
// Unreal present (ADR-0004). This file exists solely to let the UE build system
// link the same sources into the game. Do not add Unreal dependencies here — if
// the sim needs something from the engine, the boundary is in the wrong place.

using UnrealBuildTool;

public class SteeplejackSim : ModuleRules
{
	public SteeplejackSim(ReadOnlyTargetRules Target) : base(Target)
	{
		// SteeplejackSim is library code, not a loadable UE module: it has no IMPLEMENT_MODULE
		// and cannot have one, because that needs Modules/ModuleManager.h and rule 1 forbids
		// Unreal headers anywhere under this directory. UBT supports exactly this case.
		bRequiresImplementModule = false;

		PCHUsage = PCHUsageMode.NoPCHs;
		bUseUnity = false;
		// C++20, not 17: UE 5.8 removed Cpp17 outright (UBT refuses the build, it is not a
		// warning). CMakeLists.txt is held at the same standard deliberately — the two builds
		// compile the same sources and ADR-0003's identical-floats guarantee depends on them
		// not diverging.
		CppStandard = CppStandardVersion.Cpp20;

		// Deliberately minimal. "Core" only, and only for the build glue.
		PublicDependencyModuleNames.AddRange(new string[] { "Core" });

		PublicIncludePaths.Add(ModuleDirectory + "/Public");
		PrivateIncludePaths.Add(ModuleDirectory + "/Private");
	}
}
