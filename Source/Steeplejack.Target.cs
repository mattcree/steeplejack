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

		// Pinned, not `Latest`. These were Latest while the engine was uninstalled and an
		// unknown Vn constant would have failed the build; UE 5.8.2 defines V7 and
		// Unreal5_8 as exactly what Latest resolves to today, so this is the same build
		// with the silent-change-on-upgrade removed.
		DefaultBuildSettings = BuildSettingsVersion.V7;
		IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_8;

		ExtraModuleNames.AddRange(new string[] { "SteeplejackSim", "SteeplejackGame" });
	}
}
