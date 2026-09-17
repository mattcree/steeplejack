using UnrealBuildTool;

public class SteeplejackGame : ModuleRules
{
	public SteeplejackGame(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

		// This module keeps its headers beside their sources (Player/, Structures/, ...) rather
		// than in a Public/Private split, so the module root has to be on the include path or
		// #include "Structures/ChimneyActor.h" does not resolve.
		PublicIncludePaths.Add(ModuleDirectory);

		// The sim throws (interfaces.md fixes Tuning and LevelData that way) and UBT compiles
		// non-editor targets with -fno-exceptions. Without this the packaged game target will not
		// build -- see CORE-016, which is the decision about whether this is the right answer.
		bEnableExceptions = true;

		PublicDependencyModuleNames.AddRange(new string[]
		{
			"Core", "CoreUObject", "Engine", "InputCore", "EnhancedInput",
			"SteeplejackSim",
			"GeometryCollectionEngine", "Chaos", "ChaosCloth",
			"ControlRig", "AnimGraphRuntime",
			"Niagara", "MetasoundEngine", "AudioMixer",
			"UMG", "Slate", "SlateCore",
			"ProceduralMeshComponent", "GeometryScriptingCore",
		});
	}
}
