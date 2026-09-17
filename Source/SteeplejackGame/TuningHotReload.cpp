// F5 reloads data/tuning/*.json without restarting — CORE-007.
//
// Why this is worth a file of its own: rule 4 pushes every constant in the game into
// data/tuning/, which only pays for itself if a designer can change one and see the result. A
// restart per change is a thirty-second loop; F5 is a one-second loop, and that difference is
// what the production plan's balancing pass assumes.
//
// Everything here is UE-side on purpose. `sj::Tuning` knows how to read JSON and nothing about
// when; the decision to re-read is input and file I/O, which per ADR-0004 never lives in
// SteeplejackSim. This module may call into sj::; sj:: may never call back.
//
// The live Tuning is swapped whole rather than mutated in place. A half-applied reload — some
// values from the old file, some from the new — would be a balance bug that reproduces only
// under hot reload, which is the worst kind to be handed. If the new files are malformed the
// old Tuning is kept and the error is logged, so a stray comma cannot take the session down.

#include "CoreMinimal.h"
#include "HAL/IConsoleManager.h"
#include "Misc/CoreDelegates.h"
#include "Misc/Paths.h"

#include "TuningAccess.h"
#include "Tuning.h"

#include <string>

#if !UE_BUILD_SHIPPING
#include "Framework/Application/IInputProcessor.h"
#include "Framework/Application/SlateApplication.h"
#endif

DEFINE_LOG_CATEGORY_STATIC(LogSteeplejackTuning, Log, All);

namespace SteeplejackTuning
{

namespace
{
	FString TuningDirectory()
	{
		return FPaths::Combine(FPaths::ProjectDir(), TEXT("data"), TEXT("tuning"));
	}

	/** The one live Tuning. Function-local so it cannot be read before it is built. */
	sj::Tuning& Live()
	{
		static sj::Tuning Instance = sj::Tuning::LoadAll(
			std::string(TCHAR_TO_UTF8(*TuningDirectory())));
		return Instance;
	}
}

/**
 * The live tuning. Every consumer in SteeplejackGame reads through this rather than caching a
 * copy — a cached copy is a value that silently survives a reload, which defeats the point.
 */
const sj::Tuning& Get()
{
	return Live();
}

/**
 * Re-read every tuning file. Returns true if the live Tuning was replaced.
 *
 * On a malformed file the old Tuning is kept: a designer mid-edit should get a log line and a
 * game that still runs, not a crash. The hash is logged because it is what gets stamped into
 * replay files, so a changed hash is the signal that recorded runs are now stale.
 */
bool Reload()
{
	const FString Dir = TuningDirectory();
	try
	{
		sj::Tuning Fresh = sj::Tuning::LoadAll(std::string(TCHAR_TO_UTF8(*Dir)));
		const FString WasHash = UTF8_TO_TCHAR(Live().Hash().c_str());
		const FString NowHash = UTF8_TO_TCHAR(Fresh.Hash().c_str());

		Live() = MoveTemp(Fresh);

		if (WasHash == NowHash)
		{
			UE_LOG(LogSteeplejackTuning, Log, TEXT("Tuning reloaded; no values changed (%s)"),
				*NowHash.Left(12));
		}
		else
		{
			UE_LOG(LogSteeplejackTuning, Display,
				TEXT("Tuning reloaded: %s -> %s. Recorded replays stamped with the old hash will "
					 "no longer reproduce."),
				*WasHash.Left(12), *NowHash.Left(12));
		}
		return true;
	}
	catch (const sj::TuningError& Error)
	{
		UE_LOG(LogSteeplejackTuning, Error,
			TEXT("Tuning reload failed, keeping the previous values: %s"),
			UTF8_TO_TCHAR(Error.what()));
		return false;
	}
}

static FAutoConsoleCommand GReloadTuningCommand(
	TEXT("sj.tuning.reload"),
	TEXT("Re-read data/tuning/*.json. Same as F5 in a non-shipping build."),
	FConsoleCommandDelegate::CreateStatic(
		[]() { Reload(); }));

#if !UE_BUILD_SHIPPING

/**
 * F5, wherever focus happens to be.
 *
 * A Slate input pre-processor rather than a player-controller binding because a designer presses
 * F5 while looking at the level, not while thinking about which widget has focus — and because it
 * keeps the whole feature in this one file, with no UCLASS and no header, so nothing in the module
 * has to know it exists.
 */
class FTuningHotReloadInput : public IInputProcessor
{
public:
	virtual void Tick(const float, FSlateApplication&, TSharedRef<ICursor>) override {}

	virtual bool HandleKeyDownEvent(FSlateApplication&, const FKeyEvent& Event) override
	{
		if (Event.GetKey() == EKeys::F5)
		{
			Reload();
			return true;   // consume it, so F5 cannot also mean something else
		}
		return false;
	}

	virtual const TCHAR* GetDebugName() const override { return TEXT("SteeplejackTuningHotReload"); }
};

static TSharedPtr<FTuningHotReloadInput> GHotReloadInput;

void RegisterHotReloadKey()
{
	if (!GHotReloadInput.IsValid() && FSlateApplication::IsInitialized())
	{
		GHotReloadInput = MakeShared<FTuningHotReloadInput>();
		FSlateApplication::Get().RegisterInputPreProcessor(GHotReloadInput);
		UE_LOG(LogSteeplejackTuning, Log, TEXT("F5 reloads data/tuning/*.json in this build."));
	}
}

void UnregisterHotReloadKey()
{
	if (GHotReloadInput.IsValid() && FSlateApplication::IsInitialized())
	{
		FSlateApplication::Get().UnregisterInputPreProcessor(GHotReloadInput);
		GHotReloadInput.Reset();
	}
}

/**
 * Register on post-engine-init, from a file-scope constructor.
 *
 * Self-registering because the alternative is a StartupModule override in SteeplejackGame.cpp,
 * which this task does not own — and because a hot-reload key that only works if someone
 * remembers to call it is a hot-reload key that quietly stops working. Post-engine-init rather
 * than static-init because Slate does not exist yet at static-init time.
 */
struct FTuningHotReloadBootstrap
{
	FTuningHotReloadBootstrap()
	{
		FCoreDelegates::GetOnPostEngineInit().AddStatic(&RegisterHotReloadKey);
		FCoreDelegates::OnEnginePreExit.AddStatic(&UnregisterHotReloadKey);
	}
};

static FTuningHotReloadBootstrap GTuningHotReloadBootstrap;

#else

// Shipping builds read the tuning once at startup and never again. There is no designer at the
// keyboard, and a shipped build that can be re-tuned from loose JSON on disk is a different
// product with a different set of problems.
void RegisterHotReloadKey() {}
void UnregisterHotReloadKey() {}

#endif  // !UE_BUILD_SHIPPING

}  // namespace SteeplejackTuning
