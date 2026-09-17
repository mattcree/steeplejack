#include "Player/SteeplejackPawn.h"

#include "Structures/ChimneyActor.h"
#include "TuningAccess.h"

#include "Camera/CameraComponent.h"
#include "Components/CapsuleComponent.h"
#include "EngineUtils.h"
#include "Meters.h"

DEFINE_LOG_CATEGORY_STATIC(LogSteeplejackPawn, Log, All);

namespace
{
	constexpr float kUUPerMetre = 100.0f;

	// Movement is deliberately crude. CLIMB-004 and PLAYER-001 own the real controller; this is
	// enough to stand at the foot of a stack, walk to the ladder and go up it, which is what makes
	// the meters mean anything.
	constexpr float kWalkMetresPerSecond = 4.0f;
	constexpr float kClimbGraceMetres = 3.5f;   // how far off the face you can be and still be on
}

ASteeplejackPawn::ASteeplejackPawn()
{
	PrimaryActorTick.bCanEverTick = true;

	Capsule = CreateDefaultSubobject<UCapsuleComponent>(TEXT("Capsule"));
	Capsule->InitCapsuleSize(34.0f, 90.0f);   // a person: 68cm across, 1.8m tall
	Capsule->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	SetRootComponent(Capsule);

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
	Camera->SetupAttachment(Capsule);
	Camera->SetRelativeLocation(FVector(0.0f, 0.0f, 70.0f));   // eye height
	Camera->bUsePawnControlRotation = true;

	bUseControllerRotationYaw = true;
	AutoPossessPlayer = EAutoReceiveInput::Player0;
}

AChimneyActor* ASteeplejackPawn::FindChimney() const
{
	TActorIterator<AChimneyActor> It(GetWorld());
	return It ? *It : nullptr;
}

void ASteeplejackPawn::BeginPlay()
{
	Super::BeginPlay();
	Chimney = FindChimney();

	const sj::Tuning& T = SteeplejackTuning::Get();
	Meters = sj::nerve::FreshShift(T);
	Meters.stance = sj::Stance::OneHand;
	Meters.exposure = sj::Exposure::Platform;

	UE_LOG(LogSteeplejackPawn, Display,
		TEXT("SJPAWN: shift starts. grip %.0f nerve %.0f/%.0f. chimney=%s"),
		Meters.grip, Meters.nerve, Meters.nerveMax,
		Chimney ? TEXT("found") : TEXT("NONE"));
}

float ASteeplejackPawn::GetHeightMetres() const
{
	return GetActorLocation().Z / kUUPerMetre;
}

void ASteeplejackPawn::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	const sj::Tuning& T = SteeplejackTuning::Get();
	const FVector Location = GetActorLocation();
	const float HeightM = Location.Z / kUUPerMetre;

	// Are we on the ladder? Near enough to the face, and the face still exists at this height.
	bOnLadder = false;
	if (Chimney && Chimney->GetBuiltHeightMetres() > 0.0f)
	{
		const float RadiusM = Chimney->RadiusAtHeightMetres(HeightM);
		const FVector Axis = Chimney->GetActorLocation();
		const float FlatDistM =
			FVector::Dist2D(Location, Axis) / kUUPerMetre;
		bOnLadder = FlatDistM < RadiusM + kClimbGraceMetres &&
		            HeightM < Chimney->GetBuiltHeightMetres();
		BandName = Chimney->BandTypeAtHeight(HeightM);
	}

	// Move. On the ladder, forward climbs; on the ground, forward walks.
	FVector Delta = FVector::ZeroVector;
	if (bOnLadder)
	{
		Delta.Z = InputForward * kWalkMetresPerSecond * kUUPerMetre * DeltaSeconds;
		const FVector Right = FRotationMatrix(GetControlRotation()).GetScaledAxis(EAxis::Y);
		Delta += Right * InputRight * kWalkMetresPerSecond * 0.4f * kUUPerMetre * DeltaSeconds;
	}
	else
	{
		const FRotationMatrix Rot(FRotator(0.0f, GetControlRotation().Yaw, 0.0f));
		Delta += Rot.GetScaledAxis(EAxis::X) * InputForward * kWalkMetresPerSecond * kUUPerMetre * DeltaSeconds;
		Delta += Rot.GetScaledAxis(EAxis::Y) * InputRight * kWalkMetresPerSecond * kUUPerMetre * DeltaSeconds;
	}
	SetActorLocation(Location + Delta, false);

	const float NewHeightM = GetActorLocation().Z / kUUPerMetre;
	if (NewHeightM < 0.0f)
	{
		SetActorLocation(FVector(GetActorLocation().X, GetActorLocation().Y, 0.0f), false);
	}

	// Feed the sim. Exposure and height are what nerve reads; `working` is what grip reads.
	Context.height = FMath::Max(0.0f, NewHeightM);
	Context.windSpeed = 9.0f;          // ENV-003 owns real weather; a steady breeze until then
	Context.working = bWorking;
	Meters.exposure = bOnLadder ? sj::Exposure::Ladder : sj::Exposure::Platform;

	// The caller owns this accumulator — see METER-001. This is that caller.
	if (bWorking)
	{
		Context.workedSeconds += DeltaSeconds;
	}

	sj::grip::Step(Meters, DeltaSeconds, Context, T);
	sj::nerve::Step(Meters, DeltaSeconds, Context, T);

	// Grip gone: you come off. METER-005 owns the slip-save window; until it exists, falling is
	// simply what happens, which is at least honest about the stakes.
	if (sj::grip::Slipping(Meters) && bOnLadder)
	{
		bWorking = false;
		SetActorLocation(FVector(GetActorLocation().X, GetActorLocation().Y, 0.0f), false);
		sj::nerve::Shock(Meters, "slipSave", T);
		UE_LOG(LogSteeplejackPawn, Warning,
			TEXT("SJPAWN: grip gone at %.1fm — down you come. nerve now %.0f"),
			NewHeightM, Meters.nerve);
	}
}

bool ASteeplejackPawn::IsTremoring() const
{
	return sj::grip::Tremor(Meters, SteeplejackTuning::Get());
}

bool ASteeplejackPawn::IsSlipping() const
{
	return sj::grip::Slipping(Meters);
}

int32 ASteeplejackPawn::GetNerveBand() const
{
	return sj::nerve::Band(Meters.nerve, SteeplejackTuning::Get());
}

float ASteeplejackPawn::GetSecondsOfWorkLeft() const
{
	return sj::grip::SecondsOfWorkLeft(Meters, Context, SteeplejackTuning::Get());
}

FString ASteeplejackPawn::GetStanceName() const
{
	switch (Meters.stance)
	{
	case sj::Stance::OneHand:   return TEXT("one hand on rung");
	case sj::Stance::HookedLeg: return TEXT("hooked leg");
	case sj::Stance::Clipped:   return TEXT("clipped on");
	case sj::Stance::Belted:    return TEXT("belted on");
	case sj::Stance::Chair:     return TEXT("bosun's chair");
	}
	return TEXT("?");
}

void ASteeplejackPawn::MoveForward(float Value) { InputForward = Value; }
void ASteeplejackPawn::MoveRight(float Value) { InputRight = Value; }
void ASteeplejackPawn::Turn(float Value) { AddControllerYawInput(Value); }
void ASteeplejackPawn::LookUp(float Value) { AddControllerPitchInput(Value); }
void ASteeplejackPawn::StartWorking() { bWorking = true; }
void ASteeplejackPawn::StopWorking() { bWorking = false; }

void ASteeplejackPawn::CycleStance()
{
	// The whole trade in one key: a better stance drains less and costs time to rig. The time cost
	// is CLIMB-003's; this is here so the drain difference can be felt.
	const int32 Next = (static_cast<int32>(Meters.stance) + 1) % 5;
	Meters.stance = static_cast<sj::Stance>(Next);
	UE_LOG(LogSteeplejackPawn, Display, TEXT("SJPAWN: stance -> %s (%.1f grip/s)"),
		*GetStanceName(),
		sj::grip::DrainRate(Meters.stance, Context, SteeplejackTuning::Get()));
}

void ASteeplejackPawn::SetupPlayerInputComponent(UInputComponent* Input)
{
	Super::SetupPlayerInputComponent(Input);
	if (!Input)
	{
		return;
	}
	Input->BindAxis(TEXT("MoveForward"), this, &ASteeplejackPawn::MoveForward);
	Input->BindAxis(TEXT("MoveRight"), this, &ASteeplejackPawn::MoveRight);
	Input->BindAxis(TEXT("Turn"), this, &ASteeplejackPawn::Turn);
	Input->BindAxis(TEXT("LookUp"), this, &ASteeplejackPawn::LookUp);
	Input->BindAction(TEXT("Work"), IE_Pressed, this, &ASteeplejackPawn::StartWorking);
	Input->BindAction(TEXT("Work"), IE_Released, this, &ASteeplejackPawn::StopWorking);
	Input->BindAction(TEXT("Stance"), IE_Pressed, this, &ASteeplejackPawn::CycleStance);
}
