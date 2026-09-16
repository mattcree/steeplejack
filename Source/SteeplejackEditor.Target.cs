// The editor target. Identical to the game target but for TargetType.Editor —
// this is what `make build-game` compiles and what CORE-002's self-hosted runner builds.

using UnrealBuildTool;
using System.Collections.Generic;

public class SteeplejackEditorTarget : TargetRules
{
	public SteeplejackEditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;

		// See the note in Steeplejack.Target.cs on why this is `Latest` and not a pinned Vn.
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;

		ExtraModuleNames.AddRange(new string[] { "SteeplejackSim", "SteeplejackGame" });
	}
}
