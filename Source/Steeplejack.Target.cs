// The packaged game target.
//
// Both modules are listed explicitly. SteeplejackGame already depends on SteeplejackSim
// (see SteeplejackGame.Build.cs), so naming the sim here is redundant to UBT — it is here
// to keep the two-module split from ADR-0004 visible at the target level rather than
// buried in a dependency list.

using UnrealBuildTool;
using System.Collections.Generic;

public class SteeplejackTarget : TargetRules
{
	public SteeplejackTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;

		// `Latest` rather than a pinned Vn, because this file is authored before the engine
		// is installed and an unknown Vn constant is a build failure. Pin it to the real
		// constant once UE 5.8.2 is in place — see CORE-001's Outcome.
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;

		ExtraModuleNames.AddRange(new string[] { "SteeplejackSim", "SteeplejackGame" });
	}
}
