#include "Player/SteeplejackPawn.h"

#include "Structures/ChimneyActor.h"
#include "TuningAccess.h"

#include "Camera/CameraComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Animation/AnimSequence.h"
#include "UObject/ConstructorHelpers.h"
#include "UnrealClient.h"
#include "TimerManager.h"
#include "Components/CapsuleComponent.h"
#include "EngineUtils.h"
#include "Meters.h"
#include "Anchor.h"
#include "Verbs/Hammer.h"
#include "Verbs/Tap.h"
#include "Wobble.h"
#include "Rng.h"

DEFINE_LOG_CATEGORY_STATIC(LogSteeplejackPawn, Log, All);

namespace
{
	constexpr float kUUPerMetre = 100.0f;

	// Movement is deliberately crude. CLIMB-004 and PLAYER-001 own the real controller; this is
	// enough to stand at the foot of a stack, walk to the ladder and go up it, which is what makes
	// the meters mean anything.
	// Walking is not the game, so it should not be slow: you cross the yard and start climbing.
	// Climbing IS the game, and its rate is tuned (climbing.json), not invented here.
	constexpr float kWalkMetresPerSecond = 9.0f;
	/**
	 * How close to the ladder you have to be to be on it — arm's length, not a postcode.
	 *
	 * This used to be 4.5 m measured from the chimney's *axis*, which meant you started climbing
	 * while still standing in the field, on whichever side of the stack you happened to be, with
	 * the ladder nowhere near you. You are on a ladder when you can hold it.
	 */
	constexpr float kLadderReachMetres = 1.1f;
	/** How far his chest sits off the rungs when he is holding on. */
	constexpr float kBodyOffLadderMetres = 0.42f;

	// Work mode. The mouse drives the hammer rather than the head, so it needs its own sensitivity
	// and its own limit: you can only reach so far without letting go of the ladder.
	constexpr float kAimDegreesPerMouseUnit = 2.2f;
	constexpr float kAimLimitDeg = 18.0f;
	constexpr float kLeanRate = 1.8f;       // per second, -1..1
	constexpr float kLeanReturn = 2.5f;     // springs back when you stop pushing
	constexpr float kLeanWobbleScale = 0.6f;  // leaning out costs steadiness
	constexpr float kDrawRate = 1.6f;       // how fast the hammer arc builds, per second
}

ASteeplejackPawn::ASteeplejackPawn()
{
	PrimaryActorTick.bCanEverTick = true;

	// Straight off the Third Person template: a 1.8 m capsule, the mesh dropped to stand on the
	// bottom of it and turned to face along +X, and CharacterMovement doing the walking. None of
	// this is ours and none of it should be — the interesting part of this game starts above the
	// ground, and a man who walks wrong on the ground never gets believed above it.
	GetCapsuleComponent()->InitCapsuleSize(34.0f, 90.0f);

	GetMesh()->SetRelativeLocation(FVector(0.0f, 0.0f, -90.0f));
	GetMesh()->SetRelativeRotation(FRotator(0.0f, -90.0f, 0.0f));
	static ConstructorHelpers::FObjectFinder<USkeletalMesh> JackMesh(
		TEXT("/MoverExamples/Characters/Mannequins/Meshes/SKM_Manny_Simple.SKM_Manny_Simple"));
	// A missing mesh is not an error at this level — the character simply renders as nothing, and
	// an empty frame looks identical to a camera pointed the wrong way. Say so.
	if (JackMesh.Succeeded()) { GetMesh()->SetSkeletalMesh(JackMesh.Object); }
	else { UE_LOG(LogTemp, Error, TEXT("no climber mesh — check the MoverExamples plugin is enabled")); }

	// Epic's own clips, played one at a time. An animation blueprint would be the next step up and
	// there is nothing yet for it to decide between: walking, standing and hanging on is the whole
	// vocabulary until a climb is animated.
	static ConstructorHelpers::FObjectFinder<UAnimSequence> IdleAnim(
		TEXT("/MoverExamples/Characters/Mannequins/Animations/Manny/MM_Idle.MM_Idle"));
	static ConstructorHelpers::FObjectFinder<UAnimSequence> WalkAnim(
		TEXT("/MoverExamples/Characters/Mannequins/Animations/Manny/MM_Walk_InPlace.MM_Walk_InPlace"));
	Idle = IdleAnim.Succeeded() ? IdleAnim.Object : nullptr;
	Walk = WalkAnim.Succeeded() ? WalkAnim.Object : nullptr;

	UCharacterMovementComponent* Move = GetCharacterMovement();
	Move->MaxWalkSpeed = kWalkMetresPerSecond * kUUPerMetre;
	Move->BrakingDecelerationWalking = 2000.0f;
	Move->RotationRate = FRotator(0.0f, 540.0f, 0.0f);
	Move->MaxFlySpeed = 400.0f;

	// The camera hangs off a boom behind and to one side: the shot that sells this game is a small
	// figure on a very large chimney with a long way to fall.
	Boom = CreateDefaultSubobject<USpringArmComponent>(TEXT("Boom"));
	Boom->SetupAttachment(GetCapsuleComponent());
	Boom->SetRelativeLocation(FVector(0.0f, 0.0f, 55.0f));
	Boom->TargetArmLength = 430.0f;
	Boom->SocketOffset = FVector(0.0f, -95.0f, 45.0f);
	Boom->bUsePawnControlRotation = true;
	Boom->bEnableCameraLag = true;
	Boom->CameraLagSpeed = 9.0f;
	Boom->bEnableCameraRotationLag = true;
	Boom->CameraRotationLagSpeed = 14.0f;
	Boom->ProbeSize = 10.0f;

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
	Camera->SetupAttachment(Boom, USpringArmComponent::SocketName);
	Camera->SetFieldOfView(70.0f);

	static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMesh(
		TEXT("/Engine/BasicShapes/Cube.Cube"));
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> TimberMat(
		TEXT("/Game/Materials/MI_Timber.MI_Timber"));

	CarriedLadder = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("CarriedLadder"));
	CarriedLadder->SetupAttachment(GetCapsuleComponent());
	if (CubeMesh.Succeeded()) { CarriedLadder->SetStaticMesh(CubeMesh.Object); }
	if (TimberMat.Succeeded()) { CarriedLadder->SetMaterial(0, TimberMat.Object); }
	CarriedLadder->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	CarriedLadder->SetVisibility(false);

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
	if (Chimney) { Chimney->BuildLaddersTo(LadderTopM); }

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
	// His feet, not his belt buckle. The capsule's origin is at his middle, and every number in
	// this game — the span, the anchors, the level file — is a height off the ground.
	return (GetActorLocation().Z - GetCapsuleComponent()->GetScaledCapsuleHalfHeight()) / kUUPerMetre;
}

void ASteeplejackPawn::SetHeightMetres(float Metres)
{
	FVector P = GetActorLocation();
	P.Z = Metres * kUUPerMetre + GetCapsuleComponent()->GetScaledCapsuleHalfHeight();
	SetActorLocation(P, false, nullptr, ETeleportType::TeleportPhysics);
}

void ASteeplejackPawn::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	const sj::Tuning& T = SteeplejackTuning::Get();
	const FVector Location = GetActorLocation();
	const float HeightM = Location.Z / kUUPerMetre;

	// Are we on the ladder? Near enough to the face, and the face still exists at this height.
	// Are we on the ladder? Near enough to *the ladder* to have hold of it — it runs up one face,
	// so standing at the back of the stack is standing at the back of the stack.
	bOnLadder = false;
	FVector LadderWorld = FVector::ZeroVector;
	if (Chimney && Chimney->GetBuiltHeightMetres() > 0.0f)
	{
		LadderWorld = Chimney->GetActorLocation() + Chimney->ClimbFaceOffset(HeightM);
		LadderWorld.Z = Location.Z;
		const float ToLadderM = FVector::Dist2D(Location, LadderWorld) / kUUPerMetre;
		bOnLadder = ToLadderM < kLadderReachMetres && HeightM < Chimney->GetBuiltHeightMetres();
		BandName = bOnLadder ? Chimney->BandTypeAtHeight(HeightM) : FString();
	}

	// Move. On the ladder, forward climbs; on the ground, CharacterMovement walks.
	// Set the mode only when it changes. Assigning MOVE_Walking every tick pins him in walking
	// mode, so the component never transitions to falling and he stands in mid air — which is
	// exactly what "he is floating" looked like.
	UCharacterMovementComponent* Move = GetCharacterMovement();
	const bool bWantFlying = bWorkMode || bOnLadder;
	if (bWantFlying && Move->MovementMode != MOVE_Flying)
	{
		Move->SetMovementMode(MOVE_Flying);
	}
	else if (!bWantFlying && Move->MovementMode == MOVE_Flying)
	{
		Move->SetMovementMode(MOVE_Walking);
	}

	if (bWorkMode)
	{
		Move->StopMovementImmediately();
	}
	else if (bOnLadder)
	{
		// Flying is the honest mode for a man held on by his hands: gravity is not acting on him,
		// the ladder is.
		Move->StopMovementImmediately();
		const float Up = T.GetF("climbSpeedMetresPerSecond");
		const float Down = T.GetF("slideSpeedMetresPerSecond");
		const float Rate = InputForward >= 0.0f ? Up : Down;
		SetHeightMetres(HeightM + InputForward * Rate * DeltaSeconds);
	}
	else
	{
		const FRotationMatrix Yaw(FRotator(0.0f, GetControlRotation().Yaw, 0.0f));
		AddMovementInput(Yaw.GetScaledAxis(EAxis::X), InputForward);
		AddMovementInput(Yaw.GetScaledAxis(EAxis::Y), InputRight);
	}

	// You cannot climb past the top of what you have lashed. This is the loop: every metre above
	// the ladder stack has to be built before it can be stood on.
	float NewHeightM = GetHeightMetres();
	if (bOnLadder && NewHeightM > LadderTopM)
	{
		NewHeightM = LadderTopM;
		SetHeightMetres(LadderTopM);
	}
	if (NewHeightM < 0.0f)
	{
		NewHeightM = 0.0f;
		SetHeightMetres(0.0f);
	}

	// Holding on. Once off the ground the ladder has his body and the only thing he controls is how
	// far up it he is; below waist height he can still walk away from it.
	if (bOnLadder && NewHeightM > 0.9f && Chimney)
	{
		FVector Held = LadderWorld;
		Held.Z = GetActorLocation().Z;
		const FVector OutFromFace =
			(Held - Chimney->GetActorLocation()).GetSafeNormal2D() * kBodyOffLadderMetres * kUUPerMetre;
		SetActorLocation(Held + OutFromFace, false, nullptr, ETeleportType::TeleportPhysics);
	}

	// The span you are standing on: distance from the highest anchor below you to the ladder top.
	// It is what decides how much the section flexes, and it feeds straight back into the meters.
	{
		float Below = 0.0f;
		for (const sj::Anchor& A : Anchors)
		{
			if (A.height <= NewHeightM + 0.01f)
			{
				Below = FMath::Max(Below, A.height);
			}
		}
		const float Span = FMath::Max(0.0f, NewHeightM - Below);
		const sj::SpanBand Band = sj::anchor::ClassifySpan(Span, T);
		switch (Band)
		{
		case sj::SpanBand::Rigid:  SpanWarning.Reset(); break;
		case sj::SpanBand::Flex:
			SpanWarning = FString::Printf(TEXT("%.1fm span — the ladder is flexing"), Span); break;
		case sj::SpanBand::Sway:
			SpanWarning = FString::Printf(TEXT("%.1fm span — heavy sway"), Span); break;
		case sj::SpanBand::Buckle:
			SpanWarning = FString::Printf(TEXT("%.1fm span — THIS WILL BUCKLE"), Span); break;
		}
	}

	// Feed the sim. Exposure and height are what nerve reads; `working` is what grip reads.
	Context.height = FMath::Max(0.0f, NewHeightM);
	Context.carryingLadder = bCarryingLadder;
	Context.windSpeed = 9.0f;          // ENV-003 owns real weather; a steady breeze until then
	Context.working = bWorking;
	Meters.exposure = bOnLadder ? sj::Exposure::Ladder : sj::Exposure::Platform;

	// The caller owns this accumulator — see METER-001. This is that caller.
	if (bWorking)
	{
		Context.workedSeconds += DeltaSeconds;
	}

	// --- work mode: the hand, not the head ----------------------------------------------------
	StrikeCooldown = FMath::Max(0.0f, StrikeCooldown - DeltaSeconds);

	if (bWorkMode)
	{
		// Lean. Holding A/D shifts your weight to reach across the face; let go and you come back.
		// It buys reach and costs steadiness, which is the trade the whole posture is about.
		if (FMath::Abs(InputRight) > 0.01f)
		{
			Lean = FMath::Clamp(Lean + InputRight * kLeanRate * DeltaSeconds, -1.0f, 1.0f);
		}
		else
		{
			Lean = FMath::FInterpTo(Lean, 0.0f, DeltaSeconds, kLeanReturn);
		}

		// Wobble. METER-003 owns the amplitude; this only turns it into motion. Two sine terms at
		// unrelated rates so it never settles into a rhythm the player can simply wait out.
		const float Amplitude =
			sj::WobbleAmplitudeDeg(Meters, Context, 0.0f, T) *
			(1.0f + FMath::Abs(Lean) * kLeanWobbleScale);
		DriftPhase += DeltaSeconds;
		Drift.X = Amplitude * 0.6f * FMath::Sin(DriftPhase * 2.3f) +
		          Amplitude * 0.4f * FMath::Sin(DriftPhase * 5.7f + 1.1f);
		Drift.Y = Amplitude * 0.6f * FMath::Sin(DriftPhase * 1.9f + 0.7f) +
		          Amplitude * 0.4f * FMath::Sin(DriftPhase * 4.3f + 2.2f);

		// Drawing the hammer back. Both hands are committed while you hold, so grip drains.
		if (bDrawing)
		{
			SwingPower = FMath::Min(1.0f, SwingPower + kDrawRate * DeltaSeconds);
		}
		Context.working = true;
	}
	else
	{
		Lean = FMath::FInterpTo(Lean, 0.0f, DeltaSeconds, kLeanReturn);
		Drift = FVector2D::ZeroVector;
		Context.working = bWorking;
	}

	// A flexing span makes you grip harder; a swaying one frightens you. The multipliers are the
	// span table's, applied by stepping the meters for a longer slice of time rather than by
	// reaching inside them — the meters stay the only place their own rules live.
	{
		float Below = 0.0f;
		for (const sj::Anchor& A : Anchors)
		{
			if (A.height <= NewHeightM + 0.01f) { Below = FMath::Max(Below, A.height); }
		}
		const sj::SpanBand Band =
			sj::anchor::ClassifySpan(FMath::Max(0.0f, NewHeightM - Below), T);
		sj::grip::Step(Meters, DeltaSeconds * sj::anchor::GripDrainMultiplier(Band, T), Context, T);
		sj::nerve::Step(Meters, DeltaSeconds * sj::anchor::NerveDrainMultiplier(Band, T), Context, T);
	}

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

	// Last, so the body reflects the state this frame ended in rather than the one it began in.
	UpdateBodyAndCamera(DeltaSeconds);
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

float ASteeplejackPawn::GetAngleErrorDeg() const
{
	return FVector2D(Aim + Drift).Size();
}

float ASteeplejackPawn::GetWobbleDeg() const
{
	return sj::WobbleAmplitudeDeg(Meters, Context, 0.0f, SteeplejackTuning::Get()) *
	       (1.0f + FMath::Abs(Lean) * kLeanWobbleScale);
}

void ASteeplejackPawn::EnterWorkMode()
{
	if (!bOnLadder)
	{
		LastStrike = TEXT("you need to be on the brickwork to work");
		return;
	}
	if (DogsCarried <= 0)
	{
		LastStrike = TEXT("out of dogs");
		return;
	}
	bWorkMode = true;
	Aim = FVector2D::ZeroVector;
	SwingPower = 0.0f;

	// The joint you are working. STRUCT-002 generates the real grid; until then the band's quality
	// distribution stands in, so the brickwork you hit still varies the way the level file says.
	if (Chimney)
	{
		const FString Band = Chimney->BandTypeAtHeight(GetHeightMetres());
		WorkJoint = sj::Joint{};
		// Quality from the band, deterministically per height, so the same joint is the same joint.
		sj::Rng Rng(static_cast<uint64_t>(GetHeightMetres() * 100.0f) ^ 0x5D3Bu);
		WorkJoint.quality = Rng.RangeFloat(0.2f, 0.95f);
		WorkJoint.height = GetHeightMetres();
	}
	DogDepth = 0.0f;
	LastStrike = TEXT("hammer up. mouse aims, A/D leans, hold LMB to draw");
}

void ASteeplejackPawn::LeaveWorkMode()
{
	bWorkMode = false;
	bDrawing = false;
	SwingPower = 0.0f;
	Aim = FVector2D::ZeroVector;
	Drift = FVector2D::ZeroVector;
}

void ASteeplejackPawn::ResolveStrike()
{
	const sj::Tuning& T = SteeplejackTuning::Get();
	if (StrikeCooldown > 0.0f)
	{
		return;
	}
	StrikeCooldown = T.GetF("hammerStrikeCooldownSeconds");

	const float Power = SwingPower;
	const float AngleErr = GetAngleErrorDeg();
	SwingPower = 0.0f;

	const sj::StrikeResult R =
		sj::hammer::Strike(WorkJoint, DogDepth, Power, AngleErr, 1.0f, T);

	if (R.bent)
	{
		LastStrike = FString::Printf(
			TEXT("bent the dog — %.0f%% power at %.1f deg off. that one is scrap"),
			Power * 100.0f, AngleErr);
		sj::nerve::Shock(Meters, "droppedTool", T);
		DogDepth = 0.0f;
		return;
	}

	DogDepth = FMath::Clamp(DogDepth + R.depthGain, 0.0f, 1.0f);

	if (R.seated)
	{
		SeatAnchor();
		LeaveWorkMode();
	}
	else
	{
		LastStrike = FString::Printf(TEXT("%.0f%% power, %.1f deg off — dog at %.0f%%%s"),
			Power * 100.0f, AngleErr, DogDepth * 100.0f,
			R.spalled > 0.15f ? TEXT(", brick spalling") : TEXT(""));
	}
}

void ASteeplejackPawn::SJClimb(float Metres)
{
	// bOnLadder is recomputed from position every tick, so setting the flag is not enough — the
	// climber has to actually be at the face, and there has to be stack built up to here.
	LadderTopM = FMath::Max(LadderTopM, Metres + 0.5f);
	if (!Chimney)
	{
		UE_LOG(LogTemp, Warning, TEXT("SJClimb: no chimney in the level"));
		return;
	}
	FVector P = Chimney->GetActorLocation() + Chimney->ClimbFaceOffset(Metres);
	P.X -= kBodyOffLadderMetres * kUUPerMetre;
	P.Z  = GetActorLocation().Z;
	SetActorLocation(P, false, nullptr, ETeleportType::TeleportPhysics);
	SetHeightMetres(Metres);
	if (AController* C = GetController())
	{
		C->SetControlRotation(FRotator(-8.0f, 0.0f, 0.0f));   // facing the brickwork
	}
	Chimney->BuildLaddersTo(LadderTopM);   // a dev jump still has to leave a world that makes sense
	UE_LOG(LogTemp, Display, TEXT("SJClimb: at the face at %.1f m, top %.1f m, built %.1f m"),
		Metres, LadderTopM, Chimney->GetBuiltHeightMetres());
}

void ASteeplejackPawn::SJDog(float Metres)
{
	sj::Joint J{};
	J.height  = Metres;
	J.quality = 0.85f;
	J.tier    = sj::JointTier::Sound;
	Anchors.Add(sj::anchor::Make(J, 1.0f, 0.0f, SteeplejackTuning::Get()));
	UE_LOG(LogTemp, Display, TEXT("SJDog: dog seated at %.1f m (%d total)"), Metres, Anchors.Num());
}

void ASteeplejackPawn::SJStrain(float GripValue, float NerveValue)
{
	Meters.grip = FMath::Clamp(GripValue, 0.0f, 100.0f);
	Meters.nerve = FMath::Clamp(NerveValue, 0.0f, GetNerveMax());
	UE_LOG(LogTemp, Display, TEXT("SJStrain: grip %.0f nerve %.0f"), Meters.grip, Meters.nerve);
}


// --- the body ------------------------------------------------------------------------------------
// Pick a clip and place the camera. That is all.
//
// This replaced a hand-written pose that set bone rotations every frame from sim state. It was the
// wrong idea twice over: the legs came out backwards because six bones on this skeleton have their
// X axis running up the limb rather than down it, and even with that fixed the result was a mannequin
// held in a shape rather than a man moving. Epic's clips were right there the whole time.

void ASteeplejackPawn::UpdateBodyAndCamera(float DeltaSeconds)
{
	// Where the camera sits decides what you can read. Climbing wants the figure against the drop;
	// work mode wants to be close enough to see a hand on a dog.
	if (Boom)
	{
		const float WantLength = !bThirdPerson ? 0.0f : (bWorkMode ? 260.0f : 430.0f);
		const FVector WantOffset = !bThirdPerson ? FVector(0.0f, 0.0f, 35.0f)
		                         : bWorkMode     ? FVector(0.0f, -125.0f, 30.0f)
		                                         : FVector(0.0f, -95.0f, 45.0f);
		Boom->TargetArmLength = FMath::FInterpTo(Boom->TargetArmLength, WantLength, DeltaSeconds, 6.0f);
		Boom->SocketOffset = FMath::VInterpTo(Boom->SocketOffset, WantOffset, DeltaSeconds, 6.0f);
	}
	if (USkeletalMeshComponent* M = GetMesh())
	{
		M->SetVisibility(bThirdPerson, true);   // in first person you are inside his head
	}
	if (CarriedLadder)
	{
		CarriedLadder->SetVisibility(bThirdPerson && bCarryingLadder, false);
		if (bCarryingLadder)
		{
			// Upright against his right side, the far side from the camera. A five-metre section
			// carried at any angle sweeps straight through the shot.
			CarriedLadder->SetRelativeLocation(FVector(-14.0f, 34.0f, 60.0f));
			CarriedLadder->SetRelativeRotation(FRotator(8.0f, 0.0f, 0.0f));
			CarriedLadder->SetRelativeScale3D(FVector(0.05f, 0.32f, 3.0f));
		}
	}

	// The clip. Speed comes from the movement component rather than from the input, so he keeps
	// walking while he slows down instead of snapping to a standstill on key release.
	USkeletalMeshComponent* Mesh = GetMesh();
	if (!Mesh || !Mesh->GetSkinnedAsset()) { return; }

	// There is no climbing clip and a falling one is a lie — it reads as a man dropping off the
	// stack. Walking in place, seen from behind on a ladder, reads as climbing well enough to judge
	// the rest of the game by. A real climb cycle is CHAR-002's.
	const bool bMoving = bOnLadder ? FMath::Abs(InputForward) > 0.01f : GetVelocity().Size2D() > 20.0f;
	UAnimSequence* Want = bMoving ? Walk : Idle;
	if (!Want) { Want = Idle; }

	// PlayAnimation restarts the clip from frame zero, so calling it every tick freezes him on the
	// first pose — which looked exactly like the broken hand-posing it replaced.
	if (Want && Want != Playing)
	{
		Mesh->SetAnimationMode(EAnimationMode::AnimationSingleNode);
		Mesh->PlayAnimation(Want, true);
		Playing = Want;
	}
}

bool ASteeplejackPawn::IsAtCradle() const
{
	if (!Chimney) { return false; }
	const float FlatM = FVector::Dist2D(GetActorLocation(), Chimney->GetActorLocation()) / kUUPerMetre;
	return GetHeightMetres() < 2.0f
	    && FlatM < Chimney->RadiusAtHeightMetres(0.0f) + 8.0f;
}

void ASteeplejackPawn::PickUpMaterials()
{
	if (!IsAtCradle())
	{
		LastStrike = TEXT("the materials are in the cradle at the foot of the stack");
		return;
	}

	constexpr int32 kDogBag = 6;   // what fits in the bag on your hip
	int32 TookDogs = 0;
	while (DogsCarried < kDogBag && DogsAtBase > 0) { ++DogsCarried; --DogsAtBase; ++TookDogs; }

	bool bTookLadder = false;
	if (!bCarryingLadder && LaddersAtBase > 0)
	{
		bCarryingLadder = true;
		--LaddersAtBase;
		bTookLadder = true;
	}

	if (!bTookLadder && TookDogs == 0)
	{
		LastStrike = bCarryingLadder
			? TEXT("you already have a ladder on your shoulder and a full bag")
			: TEXT("the cradle is empty");
		return;
	}
	LastStrike = FString::Printf(TEXT("%s%s%d dogs in the bag, %d ladders left in the cradle"),
		bTookLadder ? TEXT("ladder on your shoulder — ") : TEXT(""),
		(bTookLadder || TookDogs) ? TEXT("") : TEXT(""),
		DogsCarried, LaddersAtBase);
}

void ASteeplejackPawn::SJShot(float AfterSeconds)
{
	const float Wait = AfterSeconds > 0.0f ? AfterSeconds : 1.5f;
	FTimerHandle H;
	GetWorldTimerManager().SetTimer(H, FTimerDelegate::CreateWeakLambda(this, [this]()
	{
		FScreenshotRequest::RequestScreenshot(false);
		UE_LOG(LogTemp, Display, TEXT("SJShot: taken at %.1f m"), GetHeightMetres());
	}), Wait, false);
}

void ASteeplejackPawn::SJTap(float AfterSeconds)
{
	FTimerHandle H;
	GetWorldTimerManager().SetTimer(H, FTimerDelegate::CreateWeakLambda(this, [this]()
	{
		TapJoint();
	}), FMath::Max(AfterSeconds, 0.01f), false);
}

void ASteeplejackPawn::SJView(float Yaw, float Pitch)
{
	// Orbit the boom, not the man. Setting control rotation turns the pawn with it — the body
	// follows the controller's yaw — so a "side view" quietly spun the climber before photographing
	// him, and every pose read as broken when it was the camera that was wrong.
	if (!Boom) { return; }
	Boom->bUsePawnControlRotation = false;
	Boom->SetWorldRotation(FRotator(Pitch, Yaw, 0.0f));
}

void ASteeplejackPawn::SJCam()
{
	bThirdPerson = !bThirdPerson;
	UE_LOG(LogTemp, Display, TEXT("SJCam: %s"), bThirdPerson ? TEXT("third person") : TEXT("first person"));
}

void ASteeplejackPawn::SJCarry()
{
	bCarryingLadder = LaddersAtBase > 0;
	if (bCarryingLadder) { --LaddersAtBase; }
	while (DogsCarried < 6 && DogsAtBase > 0) { ++DogsCarried; --DogsAtBase; }
	UE_LOG(LogTemp, Display, TEXT("SJCarry: ladder %d, dogs %d"), bCarryingLadder ? 1 : 0, DogsCarried);
}

bool ASteeplejackPawn::HasLashableAnchor() const
{
	for (const sj::Anchor& A : Anchors)
	{
		if (A.rate != sj::AnchorRate::Failed && A.height >= GetHeightMetres() - 1.0f &&
		    A.height + 0.1f > LadderTopM - (SteeplejackTuning::Get().GetF("ladderLengthMetres") -
		                                    SteeplejackTuning::Get().GetF("ladderMinOverlapMetres")))
		{
			return true;
		}
	}
	return false;
}

bool ASteeplejackPawn::IsAtLadderTop() const
{
	return bOnLadder && GetHeightMetres() >= LadderTopM - 0.6f;
}

bool ASteeplejackPawn::HasTappedHere() const
{
	return TapPipShape >= 0 && FMath::Abs(TappedAtM - GetHeightMetres()) < 1.5f;
}

void ASteeplejackPawn::TapJoint()
{
	if (!bOnLadder)
	{
		TapReading = TEXT("nothing to tap down here");
		return;
	}
	const sj::Tuning& T = SteeplejackTuning::Get();

	// The joint at this height. Same seed as EnterWorkMode, so what you tap is what you drive.
	sj::Joint J{};
	sj::Rng Rng(static_cast<uint64_t>(GetHeightMetres() * 100.0f) ^ 0x5D3Bu);
	J.quality = Rng.RangeFloat(0.2f, 0.95f);
	J.height = GetHeightMetres();

	const sj::TapResult R = sj::tap::Tap(J, T, Context.gloves);
	TapPipShape = R.pipShape;

	static const TCHAR* Words[] = { TEXT("cracked — it rattles"), TEXT("perished — dull thud"),
	                                TEXT("fair — firm"), TEXT("sound — it rings") };
	TappedAtM = GetHeightMetres();
	TapReading = FString::Printf(TEXT("%s%s"),
		Words[FMath::Clamp(static_cast<int32>(R.tier), 0, 3)],
		R.confidence < 1.0f ? TEXT("  (gloves — hard to tell)") : TEXT(""));

	// Tapping costs grip: a hand is off the ladder to hold the hammer.
	Context.working = true;
}

void ASteeplejackPawn::SeatAnchor()
{
	const sj::Tuning& T = SteeplejackTuning::Get();
	const sj::Anchor A = sj::anchor::Make(WorkJoint, DogDepth, 0.0f, T);
	Anchors.Add(A);
	--DogsCarried;
	if (Chimney) { Chimney->AddDogMarker(A.height); }

	static const TCHAR* Rated[] = { TEXT("FAILED"), TEXT("poor"), TEXT("fair"), TEXT("sound") };
	LastStrike = FString::Printf(TEXT("dog in at %.0fm — %s anchor, %.1f kN. %d dogs left"),
		A.height, Rated[FMath::Clamp(static_cast<int32>(A.rate), 0, 3)], A.capacityKN, DogsCarried);
}

void ASteeplejackPawn::LashLadder()
{
	const sj::Tuning& T = SteeplejackTuning::Get();

	if (!bCarryingLadder)
	{
		LastStrike = LaddersAtBase > 0
			? TEXT("you are not carrying a ladder — go down to the cradle for one")
			: TEXT("no ladder sections left — that is as high as this goes");
		return;
	}
	// You lash to an anchor, so there has to be one at or above where you are standing.
	float Best = -1.0f;
	for (const sj::Anchor& A : Anchors)
	{
		if (A.rate != sj::AnchorRate::Failed && A.height >= GetHeightMetres() - 1.0f)
		{
			Best = FMath::Max(Best, A.height);
		}
	}
	if (Best < 0.0f)
	{
		LastStrike = TEXT("nothing to lash to — get a dog in first");
		return;
	}

	const float Rise = T.GetF("ladderLengthMetres") - T.GetF("ladderMinOverlapMetres");
	LadderTopM = FMath::Min(Best + Rise,
		Chimney ? Chimney->GetBuiltHeightMetres() : LadderTopM + Rise);
	bCarryingLadder = false;
	if (Chimney) { Chimney->BuildLaddersTo(LadderTopM); }
	LastStrike = FString::Printf(
		TEXT("lashed to the dog at %.0fm — ladder tops out at %.0fm. %d left in the cradle"),
		Best, LadderTopM, LaddersAtBase);
}

void ASteeplejackPawn::MoveForward(float Value) { InputForward = Value; }
void ASteeplejackPawn::MoveRight(float Value) { InputRight = Value; }
void ASteeplejackPawn::Turn(float Value)
{
	// In work mode the mouse is your hand, not your head. This is the whole point: your eyes stay
	// on the joint while the hammer moves, which is what it is like to work at arm's length on a
	// ladder you are hooked into.
	if (bWorkMode)
	{
		Aim.X = FMath::Clamp(Aim.X + Value * kAimDegreesPerMouseUnit, -kAimLimitDeg, kAimLimitDeg);
		return;
	}
	AddControllerYawInput(Value);
}

void ASteeplejackPawn::LookUp(float Value)
{
	if (bWorkMode)
	{
		Aim.Y = FMath::Clamp(Aim.Y + Value * kAimDegreesPerMouseUnit, -kAimLimitDeg, kAimLimitDeg);
		return;
	}
	AddControllerPitchInput(Value);
}

void ASteeplejackPawn::StartWorking()
{
	if (bWorkMode)
	{
		bDrawing = true;      // draw the hammer back
		return;
	}
	bWorking = true;
}

void ASteeplejackPawn::StopWorking()
{
	if (bWorkMode && bDrawing)
	{
		bDrawing = false;
		ResolveStrike();      // release is the strike
		return;
	}
	bWorking = false;
}

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
	Input->BindAction(TEXT("WorkMode"), IE_Pressed, this, &ASteeplejackPawn::EnterWorkMode);
	Input->BindAction(TEXT("WorkMode"), IE_Released, this, &ASteeplejackPawn::LeaveWorkMode);
	Input->BindAction(TEXT("Tap"), IE_Pressed, this, &ASteeplejackPawn::TapJoint);
	Input->BindAction(TEXT("Lash"), IE_Pressed, this, &ASteeplejackPawn::LashLadder);
}
