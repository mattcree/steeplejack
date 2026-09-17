// The frame — CORE-005. See SteeplejackGameMode.h.

#include "SteeplejackGameMode.h"

#include "HAL/PlatformTime.h"
#include "Stats/Stats.h"

DEFINE_LOG_CATEGORY_STATIC(LogSteeplejackSim, Log, All);

// Shows up in `stat Steeplejack` alongside the engine's own counters, so the sim's cost is visible
// next to everything it competes with rather than only in a log line.
DECLARE_CYCLE_STAT(TEXT("Steeplejack Sim Step"), STAT_SteeplejackSimStep, STATGROUP_Game);

namespace
{
	// architecture.md: "Sim.Step must complete in < 0.5 ms at all times." Reported, not enforced —
	// a hitching sim should tell you, not stop.
	constexpr double kStepBudgetMs = 0.5;

	// Complain at most this often, so a sim that is over budget every frame produces one line a
	// second rather than sixty.
	constexpr float kBudgetReportIntervalSeconds = 1.0f;
}

ASteeplejackGameMode::ASteeplejackGameMode()
{
	PrimaryActorTick.bCanEverTick = true;
	// The sim must advance before anything reads it. Tick as late as possible in the frame so
	// input collected this frame is consumed this frame.
	PrimaryActorTick.TickGroup = TG_PrePhysics;
}

void ASteeplejackGameMode::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	const int32 Steps = Clock.Advance(DeltaSeconds);
	if (Steps <= 0)
	{
		// A frame shorter than a tick. Presentation still moves, because Alpha advanced.
		return;
	}

	const double Started = FPlatformTime::Seconds();
	{
		SCOPE_CYCLE_COUNTER(STAT_SteeplejackSimStep);
		for (int32 i = 0; i < Steps; ++i)
		{
			StepSim(sj::kTick);
			++SimTick;
		}
	}
	LastStepMs = static_cast<float>((FPlatformTime::Seconds() - Started) * 1000.0);

	// Report the budget per *step*, not per frame: a frame that ran five catch-up steps is
	// expected to cost five times as much, and flagging that as a budget breach would cry wolf
	// exactly when the game is already struggling.
	const double PerStepMs = static_cast<double>(LastStepMs) / static_cast<double>(Steps);
	SinceBudgetReport += DeltaSeconds;
	if (PerStepMs > kStepBudgetMs && SinceBudgetReport >= kBudgetReportIntervalSeconds)
	{
		SinceBudgetReport = 0.0f;
		UE_LOG(LogSteeplejackSim, Warning,
			TEXT("Sim step %.3f ms, over the %.1f ms budget (%d step(s) this frame, tick %d)"),
			PerStepMs, kStepBudgetMs, Steps, SimTick);
	}

	if (const int64 Dropped = Clock.DroppedSteps(); Dropped > 0 && Steps == sj::kMaxCatchUpSteps)
	{
		UE_LOG(LogSteeplejackSim, Warning,
			TEXT("Frame rate cannot keep up: %lld sim step(s) discarded so far this session."),
			Dropped);
	}
}

void ASteeplejackGameMode::StepSim(float FixedDelta)
{
	// Deliberately empty. The simulation this drives does not exist yet: intent collection is
	// CORE-006, the job state is CLIMB-001 onward. What this task owns is that whatever goes here
	// is called exactly 60 times per second of wall time and never at any other rate.
	//
	// When the sim lands, this becomes the three lines from architecture.md's "The frame":
	//     const sj::IntentBuffer Intents = InputMapper.Collect();
	//     PrevState = Sim.Snapshot();
	//     Sim.Step(Intents, FixedDelta);
	(void)FixedDelta;
}

float ASteeplejackGameMode::GetSimAlpha() const
{
	return Clock.Alpha();
}

int32 ASteeplejackGameMode::GetDroppedSteps() const
{
	return static_cast<int32>(FMath::Min<int64>(Clock.DroppedSteps(), MAX_int32));
}
