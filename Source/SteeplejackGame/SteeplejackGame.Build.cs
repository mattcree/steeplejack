using UnrealBuildTool;

public class SteeplejackGame : ModuleRules
{
	public SteeplejackGame(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

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
