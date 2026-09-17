// The editor, as tools an agent can call.
//
// UE 5.8 ships Epic's experimental Model Context Protocol plugin: an MCP server running inside the
// editor process, at http://localhost:8000/mcp. It is a framework rather than a toolbox — Epic
// provides the transport and a registry, and you register what your project needs.
//
// This is what this project needs. It exists because the alternative, which is how the first night
// of work was done, is to cold-start the editor for every change: three minutes of shader
// compilation, a stale lock if the last one has not exited, and a screenshot read back off disk
// that may predate the build you think you are looking at. Every one of those cost real time.
//
// With these, the editor stays up and an agent pokes it.

#pragma once

#include "ToolsetRegistry/ToolsetDefinition.h"

#include "SteeplejackToolset.generated.h"

UCLASS()
class USteeplejackToolset : public UToolsetDefinition
{
	GENERATED_BODY()

public:
	/** Rebuild the stack in the open level from a level JSON, and describe what was built. */
	UFUNCTION(meta = (AICallable))
	static FString RebuildStack(const FString& LevelPath);

	/** Height, course count, radii and every band of the stack currently in the level. */
	UFUNCTION(meta = (AICallable))
	static FString DescribeStack();

	/** Retint one band type live, without rebuilding the map. Values are 0-1 linear. */
	UFUNCTION(meta = (AICallable))
	static FString SetBandColour(const FString& BandType, float R, float G, float B);

	/** Move the play camera. Metres and degrees; looks at the stack at LookAtHeightMetres. */
	UFUNCTION(meta = (AICallable))
	static FString SetViewpoint(float XMetres, float YMetres, float ZMetres, float LookAtHeightMetres);

	/** Write a screenshot and return its absolute path. */
	UFUNCTION(meta = (AICallable))
	static FString Screenshot(int32 Width, int32 Height);

	/** Run the grip meter headless for a stance and report when it runs out. Answers questions
	 *  like "what does a hooked leg actually buy me" without launching anything. */
	UFUNCTION(meta = (AICallable))
	static FString SimulateGrip(const FString& Stance, bool bWet, bool bCarryingLadder);

	/** Every tuning key matching a substring, with its value. For checking what a change did. */
	UFUNCTION(meta = (AICallable))
	static FString ReadTuning(const FString& KeySubstring);
};
