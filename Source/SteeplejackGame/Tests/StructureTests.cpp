// In-engine tests. `make test-automation`.
//
// These are not a second copy of the sim's unit tests — those run under CMake in a second with no
// engine, and that is the right place for rules. These test the things only the engine can tell
// you: that the sim's types survive being called from inside Unreal, that an actor built from a
// level file actually contains the geometry that file describes, and (below) that a level which
// should fail validation does fail it in the game rather than only on the command line.
//
// The failure mode this defends against is a sim that is perfectly correct and a game that does
// not use it.

#include "Misc/AutomationTest.h"

#include "Structures/ChimneyActor.h"
#include "Level.h"
#include "Tuning.h"
#include "Meters.h"
#include "Clock.h"

#include "Components/InstancedStaticMeshComponent.h"
#include "Engine/World.h"
#include "Misc/Paths.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace
{
	std::string ProjectFile(const TCHAR* Relative)
	{
		return std::string(TCHAR_TO_UTF8(*FPaths::Combine(FPaths::ProjectDir(), Relative)));
	}

	constexpr EAutomationTestFlags kFlags = EAutomationTestFlags::EditorContext |
	                         EAutomationTestFlags::ClientContext |
	                         EAutomationTestFlags::EngineFilter;
}

// ---------------------------------------------------------------------------------------------
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FSJLevelLoadsInEngine,
	"Steeplejack.Sim.LevelLoadsInEngine", kFlags)

bool FSJLevelLoadsInEngine::RunTest(const FString&)
{
	sj::LevelData Level = sj::LevelData::LoadFrom(ProjectFile(TEXT("data/levels/06-waterside.json")));

	TestEqual(TEXT("id"), FString(UTF8_TO_TCHAR(Level.Id().c_str())), FString("06-waterside"));
	TestEqual(TEXT("height"), Level.TotalHeight(), 70.0f);
	TestEqual(TEXT("bands"), static_cast<int32>(Level.Bands().size()), 4);

	// Validate() in the engine must agree with validate_data.py on the command line. If these ever
	// disagree, a level ships that the pre-commit hook passed and the game rejects, or worse.
	TestEqual(TEXT("validates clean in-engine"),
		static_cast<int32>(Level.Validate().size()), 0);

	// The band the climber is standing in at 37 m. This is the lookup every verb will use.
	TestEqual(TEXT("band at 37m"), FString(UTF8_TO_TCHAR(Level.BandAt(37.0f).type.c_str())),
		FString("existing-band"));
	return true;
}

// ---------------------------------------------------------------------------------------------
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FSJBrokenLevelIsRejectedInEngine,
	"Steeplejack.Sim.BrokenLevelIsRejectedInEngine", kFlags)

bool FSJBrokenLevelIsRejectedInEngine::RunTest(const FString&)
{
	// The Ascent Beat Rule defends risk R1. A level that breaks it must be caught in the game too,
	// not only by the Python validator, because the Python one does not run on a player's machine.
	sj::LevelData Bad =
		sj::LevelData::LoadFrom(ProjectFile(TEXT("tests/fixtures/levels/plain-band-too-long.json")));

	const std::vector<std::string> Problems = Bad.Validate();
	TestEqual(TEXT("one problem"), static_cast<int32>(Problems.size()), 1);
	if (!Problems.empty())
	{
		TestTrue(TEXT("names the Ascent Beat Rule"),
			FString(UTF8_TO_TCHAR(Problems[0].c_str())).Contains(TEXT("Ascent Beat Rule")));
	}
	return true;
}

// ---------------------------------------------------------------------------------------------
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FSJTuningLoadsInEngine,
	"Steeplejack.Sim.TuningLoadsInEngine", kFlags)

bool FSJTuningLoadsInEngine::RunTest(const FString&)
{
	const sj::Tuning T = sj::Tuning::LoadAll(ProjectFile(TEXT("data/tuning")));

	TestEqual(TEXT("gripMax"), T.GetF("gripMax"), 100.0f);
	TestEqual(TEXT("one-handed drain"), T.GetF("gripDrainPerSecond.oneHand"), 8.0f);
	TestEqual(TEXT("digest length"), static_cast<int32>(T.Hash().size()), 64);

	// The grip meter, stepped in-engine. Twelve seconds of one-handed work, then a slip — the
	// claim the whole climbing design rests on, asserted where the game will actually run it.
	sj::Meters M{};
	M.grip = T.GetF("gripMax");
	M.stance = sj::Stance::OneHand;
	sj::MeterContext Ctx{};
	Ctx.working = true;

	int32 Steps = 0;
	while (!sj::grip::Slipping(M) && Steps < 60 * 60)
	{
		sj::grip::Step(M, sj::kTick, Ctx, T);
		++Steps;
	}
	const float Seconds = static_cast<float>(Steps) * sj::kTick;
	TestTrue(TEXT("one-handed window is 10-15s"), Seconds > 10.0f && Seconds < 15.0f);
	return true;
}

// ---------------------------------------------------------------------------------------------
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FSJChimneyBuildsFromLevel,
	"Steeplejack.Structure.ChimneyBuildsFromLevel", kFlags)

bool FSJChimneyBuildsFromLevel::RunTest(const FString&)
{
	UWorld* World = UWorld::CreateWorld(EWorldType::Game, false);
	if (!TestNotNull(TEXT("transient world"), World))
	{
		return false;
	}

	AChimneyActor* Chimney = World->SpawnActor<AChimneyActor>();
	if (!TestNotNull(TEXT("chimney spawned"), Chimney))
	{
		World->DestroyWorld(false);
		return false;
	}

	Chimney->Rebuild();

	// The numbers come from 06-waterside.json. If someone edits that file, this test changes with
	// it — which is correct: it is asserting that the actor reflects the data, not that the data
	// has particular values.
	sj::LevelData Level = sj::LevelData::LoadFrom(ProjectFile(TEXT("data/levels/06-waterside.json")));
	TestEqual(TEXT("built height matches the level file"),
		Chimney->GetBuiltHeightMetres(), Level.TotalHeight());
	TestTrue(TEXT("built some courses"), Chimney->GetCourseCount() > 0);
	TestEqual(TEXT("instance count matches course count"),
		Chimney->Courses->GetInstanceCount(), Chimney->GetCourseCount());

	// The stack must actually occupy the height it claims: bottom instance near the ground, top
	// instance near the top. A chimney of the right course count in the wrong place renders as a
	// perfectly plausible screenshot.
	FTransform First, Last;
	Chimney->Courses->GetInstanceTransform(0, First);
	Chimney->Courses->GetInstanceTransform(Chimney->GetCourseCount() - 1, Last);
	const float TopZMetres = Last.GetLocation().Z / 100.0f;
	TestTrue(TEXT("bottom course is near the ground"), First.GetLocation().Z < 500.0f);
	TestTrue(TEXT("top course reaches the stated height"),
		TopZMetres > Level.TotalHeight() * 0.9f && TopZMetres <= Level.TotalHeight());

	World->DestroyWorld(false);
	return true;
}

// ---------------------------------------------------------------------------------------------
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FSJFixedStepClockInEngine,
	"Steeplejack.Sim.FixedStepClockInEngine", kFlags)

bool FSJFixedStepClockInEngine::RunTest(const FString&)
{
	// 60 steps per second of wall time at any frame rate. Checked here as well as under CMake
	// because it is the property every recorded replay depends on, and because the engine build
	// uses a different compiler and different float flags from the CMake one.
	for (const int32 Fps : {30, 60, 75, 144})
	{
		sj::SimClock Clock;
		int32 Total = 0;
		for (int32 i = 0; i < Fps; ++i)
		{
			Total += Clock.Advance(1.0f / static_cast<float>(Fps));
		}
		TestEqual(*FString::Printf(TEXT("60 steps at %d fps"), Fps), Total, 60);
	}
	return true;
}

#endif  // WITH_DEV_AUTOMATION_TESTS
