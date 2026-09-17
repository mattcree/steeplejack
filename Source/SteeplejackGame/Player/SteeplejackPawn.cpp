#include "Player/SteeplejackPawn.h"

#include "Structures/ChimneyActor.h"
#include "TuningAccess.h"

#include "Camera/CameraComponent.h"
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

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
	Camera->SetupAttachment(Capsule);
	Camera->SetRelativeLocation(FVector(0.0f, 0.0f, 70.0f));   // eye height
	Camera->bUsePawnControlRotation = true;
	Camera->SetFieldOfView(70.0f);   // 90 makes everything look far away and small

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
	if (DogsLeft <= 0)
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
	--DogsLeft;

	static const TCHAR* Rated[] = { TEXT("FAILED"), TEXT("poor"), TEXT("fair"), TEXT("sound") };
	LastStrike = FString::Printf(TEXT("dog in at %.0fm — %s anchor, %.1f kN. %d dogs left"),
		A.height, Rated[FMath::Clamp(static_cast<int32>(A.rate), 0, 3)], A.capacityKN, DogsLeft);
}

void ASteeplejackPawn::LashLadder()
{
	const sj::Tuning& T = SteeplejackTuning::Get();

	if (LaddersLeft <= 0)
	{
		LastStrike = TEXT("no ladder sections left — that is as high as this goes");
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
	--LaddersLeft;
	LastStrike = FString::Printf(TEXT("lashed to the dog at %.0fm — ladder tops out at %.0fm. %d left"),
		Best, LadderTopM, LaddersLeft);
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
