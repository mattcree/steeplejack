#include "Player/SteeplejackPawn.h"

#include "Structures/ChimneyActor.h"
#include "TuningAccess.h"

#include "Camera/CameraComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "Components/StaticMeshComponent.h"
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
	constexpr float kClimbGraceMetres = 4.5f;   // how far off the face you can be and still be on

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

	Capsule = CreateDefaultSubobject<UCapsuleComponent>(TEXT("Capsule"));
	Capsule->InitCapsuleSize(34.0f, 90.0f);   // a person: 68cm across, 1.8m tall
	Capsule->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	SetRootComponent(Capsule);

	// The camera hangs off a boom so it can sit behind and to one side of the climber, which is the
	// shot that sells this game: a small figure on a very large chimney with a long way to fall.
	// The boom collides with the stack, so swinging round the face pulls the camera in rather than
	// putting it inside the brickwork.
	Boom = CreateDefaultSubobject<USpringArmComponent>(TEXT("Boom"));
	Boom->SetupAttachment(Capsule);
	Boom->SetRelativeLocation(FVector(0.0f, 0.0f, 55.0f));
	Boom->TargetArmLength = 280.0f;
	Boom->SocketOffset = FVector(0.0f, 55.0f, 35.0f);   // off one shoulder, a little above
	Boom->bUsePawnControlRotation = true;
	Boom->bEnableCameraLag = true;
	Boom->CameraLagSpeed = 9.0f;
	Boom->bEnableCameraRotationLag = true;
	Boom->CameraRotationLagSpeed = 14.0f;
	Boom->ProbeSize = 10.0f;

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
	Camera->SetupAttachment(Boom, USpringArmComponent::SocketName);
	Camera->SetFieldOfView(70.0f);   // 90 makes everything look far away and small

	// --- the blockout body ----------------------------------------------------------------------
	// Built from engine primitives and posed in code. Sized off a 1.8m man: the capsule's origin is
	// at his middle, so Body sits at his feet and everything below is measured up from there in
	// metres, which is the only way this stays readable.
	Body = CreateDefaultSubobject<USceneComponent>(TEXT("Body"));
	Body->SetupAttachment(Capsule);
	Body->SetRelativeLocation(FVector(0.0f, 0.0f, -90.0f));

	static ConstructorHelpers::FObjectFinder<UStaticMesh> CylinderMesh(
		TEXT("/Engine/BasicShapes/Cylinder.Cylinder"));
	static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMesh(
		TEXT("/Engine/BasicShapes/Cube.Cube"));
	static ConstructorHelpers::FObjectFinder<UStaticMesh> SphereMesh(
		TEXT("/Engine/BasicShapes/Sphere.Sphere"));

	auto Part = [&](const TCHAR* Name, UStaticMesh* Mesh) -> UStaticMeshComponent*
	{
		UStaticMeshComponent* C = CreateDefaultSubobject<UStaticMeshComponent>(Name);
		C->SetupAttachment(Body);
		if (Mesh) { C->SetStaticMesh(Mesh); }
		C->SetCollisionEnabled(ECollisionEnabled::NoCollision);
		C->SetCastShadow(true);
		return C;
	};

	// The engine's basic-shape material is a checkerboard, which turns the jack into a test pattern.
	// Reuse the stack's own material instances: dark for the man so he reads as a silhouette
	// against brick and sky, timber for the ladder on his shoulder.
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> DarkMat(
		TEXT("/Game/Materials/MI_Internal.MI_Internal"));
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> TimberMat(
		TEXT("/Game/Materials/MI_Timber.MI_Timber"));

	UStaticMesh* Cyl = CylinderMesh.Succeeded() ? CylinderMesh.Object : nullptr;
	Torso = Part(TEXT("Torso"), Cyl);
	Head  = Part(TEXT("Head"),  SphereMesh.Succeeded() ? SphereMesh.Object : nullptr);
	ArmL  = Part(TEXT("ArmL"),  Cyl);
	ArmR  = Part(TEXT("ArmR"),  Cyl);
	LegL  = Part(TEXT("LegL"),  Cyl);
	LegR  = Part(TEXT("LegR"),  Cyl);
	CarriedLadder = Part(TEXT("CarriedLadder"), CubeMesh.Succeeded() ? CubeMesh.Object : nullptr);
	CarriedLadder->SetVisibility(false);

	if (DarkMat.Succeeded())
	{
		for (UStaticMeshComponent* C : { Torso.Get(), Head.Get(), ArmL.Get(), ArmR.Get(),
		                                 LegL.Get(), LegR.Get() })
		{
			if (C) { C->SetMaterial(0, DarkMat.Object); }
		}
	}
	if (TimberMat.Succeeded() && CarriedLadder) { CarriedLadder->SetMaterial(0, TimberMat.Object); }

	// Engine primitives are 100uu across and 100uu tall, so a scale is just the size in metres.
	Torso->SetRelativeScale3D(FVector(0.34f, 0.24f, 0.62f));
	Head->SetRelativeScale3D(FVector(0.21f));
	ArmL->SetRelativeScale3D(FVector(0.11f, 0.11f, 0.62f));
	ArmR->SetRelativeScale3D(FVector(0.11f, 0.11f, 0.62f));
	LegL->SetRelativeScale3D(FVector(0.15f, 0.15f, 0.85f));
	LegR->SetRelativeScale3D(FVector(0.15f, 0.15f, 0.85f));
	CarriedLadder->SetRelativeScale3D(FVector(0.09f, 0.42f, 3.6f));

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
		BandName = bOnLadder ? Chimney->BandTypeAtHeight(HeightM) : FString();
	}

	// Move. On the ladder, forward climbs; on the ground, forward walks.
	FVector Delta = FVector::ZeroVector;
	if (bWorkMode)
	{
		// You are hooked into the ladder with both hands committed. You are not going anywhere.
	}
	else if (bOnLadder)
	{
		// Up at the tuned climb rate; down faster, because sliding a ladder is how it is done.
		const float Up = T.GetF("climbSpeedMetresPerSecond");
		const float Down = T.GetF("slideSpeedMetresPerSecond");
		const float Rate = InputForward >= 0.0f ? Up : Down;
		Delta.Z = InputForward * Rate * kUUPerMetre * DeltaSeconds;
		const FVector Right = FRotationMatrix(GetControlRotation()).GetScaledAxis(EAxis::Y);
		Delta += Right * InputRight * Up * kUUPerMetre * DeltaSeconds;
	}
	else
	{
		const FRotationMatrix Rot(FRotator(0.0f, GetControlRotation().Yaw, 0.0f));
		Delta += Rot.GetScaledAxis(EAxis::X) * InputForward * kWalkMetresPerSecond * kUUPerMetre * DeltaSeconds;
		Delta += Rot.GetScaledAxis(EAxis::Y) * InputRight * kWalkMetresPerSecond * kUUPerMetre * DeltaSeconds;
	}
	SetActorLocation(Location + Delta, false);

	// You cannot climb past the top of what you have lashed. This is the loop: every metre above
	// the ladder stack has to be built before it can be stood on.
	float NewHeightM = GetActorLocation().Z / kUUPerMetre;
	if (bOnLadder && NewHeightM > LadderTopM)
	{
		NewHeightM = LadderTopM;
		SetActorLocation(FVector(GetActorLocation().X, GetActorLocation().Y,
		                         LadderTopM * kUUPerMetre), false);
	}
	if (NewHeightM < 0.0f)
	{
		NewHeightM = 0.0f;
		SetActorLocation(FVector(GetActorLocation().X, GetActorLocation().Y, 0.0f), false);
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
	PoseBody(DeltaSeconds);
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
	P.X -= 0.55f * kUUPerMetre;   // a body's depth off the rungs
	P.Z  = Metres * kUUPerMetre;
	SetActorLocation(P, false, nullptr, ETeleportType::TeleportPhysics);
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
// Posed in code every frame from state that already exists. Nothing here decides anything: it reads
// stance, lean, swing power and whether a hand is off the ladder, and puts the limbs where those
// values say they are. If the pose and the sim ever disagree, the pose is wrong.

namespace
{
	/** Lay a primitive along a line, because a limb is a line with a thickness. */
	void SetLimb(UStaticMeshComponent* C, const FVector& From, const FVector& To, float Thickness)
	{
		if (!C) { return; }
		const FVector Dir = To - From;
		const float Len = FMath::Max(Dir.Size(), 1.0f);
		C->SetRelativeLocation((From + To) * 0.5f);
		C->SetRelativeRotation(FRotationMatrix::MakeFromZ(Dir).Rotator());
		C->SetRelativeScale3D(FVector(Thickness, Thickness, Len / 100.0f));
	}
}

void ASteeplejackPawn::PoseBody(float DeltaSeconds)
{
	if (!Body) { return; }

	// The camera first, because where it sits decides what the pose is for. Climbing wants the
	// figure against the drop; work mode wants to be close enough to see a hand on a dog.
	if (Boom)
	{
		// Far enough back to hold a 1.8 m man and the 3.4 m ladder on his shoulder in the same
		// frame, and off to one side so the brickwork he is working on is not behind his head.
		const float WantLength = !bThirdPerson ? 0.0f : (bWorkMode ? 260.0f : 430.0f);
		const FVector WantOffset = !bThirdPerson ? FVector(0.0f, 0.0f, 35.0f)
		                         : bWorkMode     ? FVector(0.0f, -125.0f, 30.0f)
		                                         : FVector(0.0f, -95.0f, 45.0f);
		Boom->TargetArmLength = FMath::FInterpTo(Boom->TargetArmLength, WantLength, DeltaSeconds, 6.0f);
		Boom->SocketOffset = FMath::VInterpTo(Boom->SocketOffset, WantOffset, DeltaSeconds, 6.0f);
	}
	// In first person you are inside the head, so the head has to go.
	Body->SetVisibility(bThirdPerson, true);
	if (CarriedLadder) { CarriedLadder->SetVisibility(bThirdPerson && bCarryingLadder, false); }
	if (!bThirdPerson) { return; }

	// The climb drives the stride, so the legs only move when you do. On the ground it is a walk;
	// on the ladder it is hand over hand and the same phase serves both.
	const float Speed = FMath::Abs(InputForward) + FMath::Abs(InputRight);
	StridePhase += DeltaSeconds * Speed * (bOnLadder ? 3.4f : 6.0f);
	const float Stride = FMath::Sin(StridePhase) * (bOnLadder ? 20.0f : 26.0f) * FMath::Min(Speed, 1.0f);

	// The tap reach decays on its own, so the arm comes back without anyone telling it to.
	TapReach = FMath::Max(0.0f, TapReach - DeltaSeconds * 2.4f);

	// Lean is a weight shift: the whole body goes with it, and it is the thing that costs you
	// steadiness, so it should be the thing you can see.
	Body->SetRelativeLocation(FVector(0.0f, Lean * 16.0f, -90.0f));
	Body->SetRelativeRotation(FRotator(0.0f, 0.0f, Lean * 9.0f));

	// Landmarks, in centimetres up from the feet. +X is the way he faces — into the brickwork when
	// he is on the ladder.
	const FVector ShoulderL(0.0f, -16.0f, 142.0f), ShoulderR(0.0f, 16.0f, 142.0f);
	const FVector HipL(0.0f, -10.0f, 88.0f),       HipR(0.0f, 10.0f, 88.0f);

	FVector HandL, HandR, FootL, FootR;
	float   TorsoLeanX = 0.0f;

	if (bOnLadder)
	{
		// Hanging on. Hands above the head on the rungs, feet close in under him, body tucked
		// toward the ladder — which is how you stay on one when your arms are tired.
		TorsoLeanX = 6.0f;
		HandL = FVector(26.0f, -18.0f, 186.0f + Stride);
		HandR = FVector(26.0f,  18.0f, 186.0f - Stride);
		FootL = FVector(22.0f, -11.0f,  12.0f - FMath::Min(Stride, 0.0f) * 0.9f);
		FootR = FVector(22.0f,  11.0f,  12.0f + FMath::Max(Stride, 0.0f) * 0.9f);

		if (bWorkMode)
		{
			// One hand holds, one works. That is the whole reason work mode is a commitment, and
			// the pose is where the player should be able to read it.
			HandL = FVector(24.0f, -18.0f, 190.0f);
			const float Draw = SwingPower;
			HandR = FVector(46.0f - Draw * 40.0f, 14.0f + Aim.X * 0.8f,
			                150.0f + Draw * 26.0f - Aim.Y * 0.8f);
		}
		else if (TapReach > 0.0f)
		{
			// Reaching out to sound the brickwork. A short jab and back.
			const float R = FMath::Sin(TapReach * PI);
			HandR = FVector(24.0f + R * 26.0f, 16.0f, 150.0f + R * 8.0f);
		}
	}
	else
	{
		// On the ground. Arms swing opposite the legs.
		HandL = FVector(Stride * 0.5f,  -20.0f, 100.0f);
		HandR = FVector(-Stride * 0.5f,  20.0f, 100.0f);
		FootL = FVector(Stride,  -10.0f, 8.0f);
		FootR = FVector(-Stride,  10.0f, 8.0f);
	}

	if (bCarryingLadder)
	{
		// A ladder is carried on one shoulder with one hand steadying it, which is exactly why it
		// costs grip: that hand is not available for anything else.
		HandR = FVector(-8.0f, 34.0f, 168.0f);
	}

	if (Torso)
	{
		Torso->SetRelativeLocation(FVector(TorsoLeanX * 0.5f, 0.0f, 115.0f));
		Torso->SetRelativeRotation(FRotator(-TorsoLeanX, 0.0f, 0.0f));
		Torso->SetRelativeScale3D(FVector(0.34f, 0.24f, 0.62f));
	}
	if (Head)
	{
		// Looking where the camera looks, within reason — a head that follows the mouse exactly
		// looks like it is on a stick.
		const float Pitch = GetControlRotation().Pitch;
		Head->SetRelativeLocation(FVector(TorsoLeanX + 2.0f, 0.0f, 158.0f));
		Head->SetRelativeRotation(FRotator(FMath::ClampAngle(Pitch, -35.0f, 35.0f) * 0.5f, 0.0f, 0.0f));
		Head->SetRelativeScale3D(FVector(0.21f));
	}

	SetLimb(ArmL, ShoulderL, HandL, 0.10f);
	SetLimb(ArmR, ShoulderR, HandR, 0.10f);
	SetLimb(LegL, HipL, FootL, 0.14f);
	SetLimb(LegR, HipR, FootR, 0.14f);

	if (CarriedLadder && bCarryingLadder)
	{
		// Upright and tight to his right side, which is the far side from the camera. A five-metre
		// section carried at any angle sweeps straight through the shot, and a ladder that hides
		// the man defeats the point of being able to see him.
		CarriedLadder->SetRelativeLocation(FVector(-14.0f, 34.0f, 150.0f));
		CarriedLadder->SetRelativeRotation(FRotator(8.0f, 0.0f, 0.0f));
		CarriedLadder->SetRelativeScale3D(FVector(0.05f, 0.32f, 3.0f));
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
	TapReach = 1.0f;
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
