#include "Tools/SteeplejackToolset.h"

#include "Structures/ChimneyActor.h"
#include "Player/SteeplejackPawn.h"
#include "TuningAccess.h"

#include "Components/InstancedStaticMeshComponent.h"
#include "Engine/Engine.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "Kismet/GameplayStatics.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Meters.h"
#include "Misc/Paths.h"
#include "UnrealClient.h"

namespace
{
	UWorld* PlayWorld()
	{
		if (!GEngine)
		{
			return nullptr;
		}
		for (const FWorldContext& Context : GEngine->GetWorldContexts())
		{
			if (Context.World() && (Context.WorldType == EWorldType::PIE ||
			                        Context.WorldType == EWorldType::Game ||
			                        Context.WorldType == EWorldType::Editor))
			{
				return Context.World();
			}
		}
		return nullptr;
	}

	AChimneyActor* FindStack()
	{
		UWorld* World = PlayWorld();
		if (!World)
		{
			return nullptr;
		}
		TActorIterator<AChimneyActor> It(World);
		return It ? *It : nullptr;
	}
}

FString USteeplejackToolset::RebuildStack(const FString& LevelPath)
{
	AChimneyActor* Stack = FindStack();
	if (!Stack)
	{
		return TEXT("no AChimneyActor in the open level");
	}
	if (!LevelPath.IsEmpty())
	{
		Stack->LevelPath = LevelPath;
	}
	Stack->Rebuild();
	return DescribeStack();
}

FString USteeplejackToolset::DescribeStack()
{
	AChimneyActor* Stack = FindStack();
	if (!Stack)
	{
		return TEXT("no AChimneyActor in the open level");
	}

	FString Out = FString::Printf(TEXT("%s: %.1fm in %d courses"),
		*Stack->LevelPath, Stack->GetBuiltHeightMetres(), Stack->GetCourseCount());

	const float H = Stack->GetBuiltHeightMetres();
	if (H > 0.0f)
	{
		Out += FString::Printf(TEXT(", radius %.2fm at the base -> %.2fm at the top"),
			Stack->RadiusAtHeightMetres(0.0f), Stack->RadiusAtHeightMetres(H));
		for (float Z = 0.0f; Z < H; Z += 2.0f)
		{
			const FString Band = Stack->BandTypeAtHeight(Z);
			if (Z == 0.0f || Band != Stack->BandTypeAtHeight(Z - 2.0f))
			{
				Out += FString::Printf(TEXT("\n  from %.0fm: %s"), Z, *Band);
			}
		}
	}
	for (int32 i = 0; i < Stack->BandCourses.Num(); ++i)
	{
		if (Stack->BandCourses[i] && Stack->BandCourses[i]->GetInstanceCount() > 0)
		{
			Out += FString::Printf(TEXT("\n  band component %d: %d courses, material %s"), i,
				Stack->BandCourses[i]->GetInstanceCount(),
				Stack->BandCourses[i]->GetMaterial(0)
					? *Stack->BandCourses[i]->GetMaterial(0)->GetName() : TEXT("NONE"));
		}
	}
	return Out;
}

FString USteeplejackToolset::SetBandColour(const FString& BandType, float R, float G, float B)
{
	AChimneyActor* Stack = FindStack();
	if (!Stack)
	{
		return TEXT("no AChimneyActor in the open level");
	}

	int32 Changed = 0;
	const float H = Stack->GetBuiltHeightMetres();
	for (int32 i = 0; i < Stack->BandCourses.Num(); ++i)
	{
		UInstancedStaticMeshComponent* Comp = Stack->BandCourses[i];
		if (!Comp || Comp->GetInstanceCount() == 0)
		{
			continue;
		}
		// Which band is this component? Ask the first instance where it sits.
		FTransform X;
		Comp->GetInstanceTransform(0, X);
		const FString Type = Stack->BandTypeAtHeight(
			FMath::Clamp(static_cast<float>(X.GetLocation().Z) / 100.0f, 0.0f, H));
		if (Type != BandType)
		{
			continue;
		}
		if (UMaterialInterface* Current = Comp->GetMaterial(0))
		{
			UMaterialInstanceDynamic* Mid = UMaterialInstanceDynamic::Create(Current, Comp);
			Mid->SetVectorParameterValue(TEXT("Color"), FLinearColor(R, G, B));
			Comp->SetMaterial(0, Mid);
			Comp->MarkRenderStateDirty();
			++Changed;
		}
	}
	return Changed > 0
		? FString::Printf(TEXT("retinted %d component(s) of band '%s' to (%.2f %.2f %.2f)"),
			Changed, *BandType, R, G, B)
		: FString::Printf(TEXT("no band matched '%s'"), *BandType);
}

FString USteeplejackToolset::SetViewpoint(float XMetres, float YMetres, float ZMetres,
                                          float LookAtHeightMetres)
{
	UWorld* World = PlayWorld();
	APlayerController* PC = World ? UGameplayStatics::GetPlayerController(World, 0) : nullptr;
	APawn* Jack = PC ? PC->GetPawn() : nullptr;
	if (!Jack)
	{
		return TEXT("no player pawn — is the game running?");
	}

	const FVector Eye(XMetres * 100.0f, YMetres * 100.0f, ZMetres * 100.0f);
	const FVector Look(0.0f, 0.0f, LookAtHeightMetres * 100.0f);
	Jack->SetActorLocation(Eye, false);
	PC->SetControlRotation((Look - Eye).Rotation());
	return FString::Printf(TEXT("camera at %.0f,%.0f,%.0fm looking at %.0fm"),
		XMetres, YMetres, ZMetres, LookAtHeightMetres);
}

FString USteeplejackToolset::Screenshot(int32 Width, int32 Height)
{
	const FString Dir = FPaths::Combine(FPaths::ProjectSavedDir(), TEXT("Screenshots"));
	FScreenshotRequest::RequestScreenshot(false);
	return FString::Printf(
		TEXT("screenshot requested (%dx%d is the viewport's size, not a crop). Look in %s"),
		Width, Height, *Dir);
}

FString USteeplejackToolset::SimulateGrip(const FString& Stance, bool bWet, bool bCarryingLadder)
{
	const sj::Tuning& T = SteeplejackTuning::Get();

	sj::Stance S = sj::Stance::OneHand;
	if (Stance == TEXT("hookedLeg")) { S = sj::Stance::HookedLeg; }
	else if (Stance == TEXT("clipped")) { S = sj::Stance::Clipped; }
	else if (Stance == TEXT("belted")) { S = sj::Stance::Belted; }
	else if (Stance == TEXT("chair")) { S = sj::Stance::Chair; }

	sj::Meters M{};
	M.grip = T.GetF("gripMax");
	M.stance = S;

	sj::MeterContext C{};
	C.working = true;
	C.wet = bWet;
	C.carryingLadder = bCarryingLadder;

	const float Rate = sj::grip::DrainRate(S, C, T);
	if (Rate <= 0.0f)
	{
		return FString::Printf(TEXT("%s drains nothing — work as long as you like"), *Stance);
	}

	int32 Steps = 0;
	float TremorAt = -1.0f;
	while (!sj::grip::Slipping(M) && Steps < 60 * 600)
	{
		sj::grip::Step(M, sj::kTick, C, T);
		++Steps;
		if (TremorAt < 0.0f && sj::grip::Tremor(M, T))
		{
			TremorAt = static_cast<float>(Steps) * sj::kTick;
		}
	}
	const float Gone = static_cast<float>(Steps) * sj::kTick;
	return FString::Printf(
		TEXT("%s%s%s: %.1f grip/s, hands shake at %.1fs, grip gone at %.1fs (%.1fs of warning)"),
		*Stance, bWet ? TEXT(" wet") : TEXT(""),
		bCarryingLadder ? TEXT(" carrying a ladder") : TEXT(""),
		Rate, TremorAt, Gone, Gone - TremorAt);
}

FString USteeplejackToolset::ReadTuning(const FString& KeySubstring)
{
	const sj::Tuning& T = SteeplejackTuning::Get();
	FString Out;
	int32 Shown = 0;
	for (const std::string& Key : T.Keys())
	{
		const FString K = UTF8_TO_TCHAR(Key.c_str());
		if (!KeySubstring.IsEmpty() && !K.Contains(KeySubstring))
		{
			continue;
		}
		if (++Shown > 40)
		{
			Out += TEXT("\n  ...");
			break;
		}
		Out += FString::Printf(TEXT("\n  %s = %g"), *K, T.GetF(Key));
	}
	if (Shown == 0)
	{
		return FString::Printf(TEXT("no tuning key matching '%s'"), *KeySubstring);
	}
	const FString Digest = UTF8_TO_TCHAR(T.Hash().substr(0, 12).c_str());
	return FString::Printf(TEXT("tuning %s:%s"), *Digest, *Out);
}
