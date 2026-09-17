// The frame — CORE-005.
//
// This is the only place the engine's variable frame rate meets the sim's fixed one. Unreal ticks
// whenever it ticks; sj::SimClock converts that into whole 1/60 s steps, and presentation draws
// between the last two of them. Per ADR-0004 nothing here decides anything about the game: it owns
// the loop, not the rules.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"

#include "Clock.h"

#include "SteeplejackGameMode.generated.h"

UCLASS()
class ASteeplejackGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	ASteeplejackGameMode();

	virtual void Tick(float DeltaSeconds) override;

	/** Render interpolation factor for the current frame, in [0, 1). Presentation lerps with this. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack|Sim")
	float GetSimAlpha() const;

	/** Sim steps run so far this session. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack|Sim")
	int32 GetSimTick() const { return SimTick; }

	/** Steps discarded to avoid a spiral of death. Nonzero means the frame rate could not keep up. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack|Sim")
	int32 GetDroppedSteps() const;

	/** Milliseconds spent inside the sim on the last frame. Budget is 0.5 ms per step. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack|Sim")
	float GetLastStepMilliseconds() const { return LastStepMs; }

private:
	void StepSim(float FixedDelta);

	sj::SimClock Clock;

	int32 SimTick = 0;
	float LastStepMs = 0.0f;

	/** Frames since the budget was last reported, so a slow sim logs once a second, not 60 times. */
	float SinceBudgetReport = 0.0f;
};
