// The jack. A capsule that walks the ground, climbs the stack, and gets tired doing it.
//
// Every rule it obeys lives in SteeplejackSim: grip and nerve are stepped by sj::grip and
// sj::nerve, the stance table comes from meters.json, and the structure it climbs comes from the
// level file. This class converts input into intent and reads sim state back out. It decides
// nothing (ADR-0004).

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"

#include "Anchor.h"
#include "Types.h"

#include "SteeplejackPawn.generated.h"

class AChimneyActor;
class UCameraComponent;
class UCapsuleComponent;
class USpringArmComponent;
class UStaticMeshComponent;

UCLASS()
class ASteeplejackPawn : public APawn
{
	GENERATED_BODY()

public:
	ASteeplejackPawn();

	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;
	virtual void SetupPlayerInputComponent(UInputComponent* Input) override;

	UPROPERTY(VisibleAnywhere, Category = "Steeplejack")
	TObjectPtr<UCapsuleComponent> Capsule;

	UPROPERTY(VisibleAnywhere, Category = "Steeplejack")
	TObjectPtr<USpringArmComponent> Boom;

	UPROPERTY(VisibleAnywhere, Category = "Steeplejack")
	TObjectPtr<UCameraComponent> Camera;

	// The climber's body. Third person, because the things this game is about are things a body
	// does: which hand is on the rung, how far you have leaned out, a ladder over one shoulder,
	// the arm coming back for a strike. In first person all of that was text on a HUD.
	//
	// A blockout of primitives, not a character. There is no rig and no animator, and a placeholder
	// that pretended to be a person would be harder to replace than one that plainly is not.
	UPROPERTY(VisibleAnywhere, Category = "Steeplejack") TObjectPtr<USceneComponent> Body;
	UPROPERTY(VisibleAnywhere, Category = "Steeplejack") TObjectPtr<UStaticMeshComponent> Torso;
	UPROPERTY(VisibleAnywhere, Category = "Steeplejack") TObjectPtr<UStaticMeshComponent> Head;
	UPROPERTY(VisibleAnywhere, Category = "Steeplejack") TObjectPtr<UStaticMeshComponent> ArmL;
	UPROPERTY(VisibleAnywhere, Category = "Steeplejack") TObjectPtr<UStaticMeshComponent> ArmR;
	UPROPERTY(VisibleAnywhere, Category = "Steeplejack") TObjectPtr<UStaticMeshComponent> LegL;
	UPROPERTY(VisibleAnywhere, Category = "Steeplejack") TObjectPtr<UStaticMeshComponent> LegR;
	UPROPERTY(VisibleAnywhere, Category = "Steeplejack") TObjectPtr<UStaticMeshComponent> CarriedLadder;

	// --- what the HUD reads -------------------------------------------------------------------
	UFUNCTION(BlueprintPure, Category = "Steeplejack") float GetGrip() const { return Meters.grip; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") float GetNerve() const { return Meters.nerve; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") float GetNerveMax() const { return Meters.nerveMax; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") float GetHeightMetres() const;
	UFUNCTION(BlueprintPure, Category = "Steeplejack") bool IsOnLadder() const { return bOnLadder; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") bool IsWorking() const { return bWorking; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") bool IsTremoring() const;
	UFUNCTION(BlueprintPure, Category = "Steeplejack") bool IsSlipping() const;
	UFUNCTION(BlueprintPure, Category = "Steeplejack") int32 GetNerveBand() const;
	UFUNCTION(BlueprintPure, Category = "Steeplejack") FString GetStanceName() const;
	UFUNCTION(BlueprintPure, Category = "Steeplejack") FString GetBandName() const { return BandName; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") float GetSecondsOfWorkLeft() const;

	// --- work mode ----------------------------------------------------------------------------
	// Holding on with your hands and driving a dog are mutually exclusive: one hand holds the dog,
	// one swings the hammer, so nothing is left for the ladder. Entering work mode is therefore a
	// commitment, and the controls change to say so — the camera settles on the face, the mouse
	// stops steering your head and starts steering the hammer, and WASD stops moving you and starts
	// shifting your weight.
	UFUNCTION(BlueprintPure, Category = "Steeplejack") bool IsInWorkMode() const { return bWorkMode; }

	/** Reticle offset from the dog's head, in degrees. What the strike is judged on. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack") float GetAngleErrorDeg() const;

	/** Current wobble, degrees. METER-003 computes it; nothing here does. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack") float GetWobbleDeg() const;

	/** 0-1 while the hammer is drawn back. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack") float GetSwingPower() const { return SwingPower; }

	/** How far into the joint this dog is, 0-1. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack") float GetDogDepth() const { return DogDepth; }

	/** How far you have leaned out to reach, -1 to 1. Costs steadiness. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack") float GetLean() const { return Lean; }

	UFUNCTION(BlueprintPure, Category = "Steeplejack") FString GetLastStrikeResult() const { return LastStrike; }

	// --- the ascent ---------------------------------------------------------------------------
	// You can only climb as high as you have built. Every metre above the topmost lashed ladder
	// has to be earned: tap a joint, drive a dog, lash the next section. That is the loop, and the
	// resources are finite so it is also the decision.
	UFUNCTION(BlueprintPure, Category = "Steeplejack") float GetLadderTopMetres() const { return LadderTopM; }
	// Ladders and dogs are objects, not a score. A ladder is one man's awkward load — you carry one
	// at a time, and it costs you grip the whole way up. The stock sits in the cradle at the foot
	// of the stack, so running out forty metres up means going down for another. That trip is the
	// price of the ascent and it is meant to be felt, not abstracted into a counter.
	UFUNCTION(BlueprintPure, Category = "Steeplejack") bool  IsCarryingLadder() const { return bCarryingLadder; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") int32 GetLaddersLeft() const { return bCarryingLadder ? 1 : 0; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") int32 GetDogsLeft() const { return DogsCarried; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") int32 GetLaddersAtBase() const { return LaddersAtBase; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") int32 GetDogsAtBase() const { return DogsAtBase; }

	/** Within reach of the cradle at the foot of the stack, where the materials are. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack") bool IsAtCradle() const;
	UFUNCTION(BlueprintPure, Category = "Steeplejack") int32 GetAnchorCount() const { return Anchors.Num(); }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") FString GetTapReading() const { return TapReading; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") int32 GetTapPipShape() const { return TapPipShape; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") FString GetSpanWarning() const { return SpanWarning; }

	// Dev commands, typed at the console. Not guarded by a #if because UHT rejects a UFUNCTION
	// inside a preprocessor block; they are cheap and harmless, and the day this ships is the day
	// to strip them. Nothing above the ground floor can be tested — not the HUD's gating, not wobble,
	// not the span economy — without a way to put the climber where the test needs them, and
	// climbing there by hand is not something an automated run can do.
	/** Put the climber on the ladder at a height, building enough stack under them to stand on. */
	UFUNCTION(Exec) void SJClimb(float Metres);
	/** Seat a dog of a given rating at a height, as though it had been driven cleanly. */
	UFUNCTION(Exec) void SJDog(float Metres);
	/** Drain grip and nerve to a value, to see the meters and their telegraphs. */
	UFUNCTION(Exec) void SJStrain(float GripValue, float NerveValue);
	/** Toggle between watching the climber and looking through their eyes. */
	UFUNCTION(Exec) void SJCam();
	/** Put a ladder on your shoulder and dogs in the bag without the trip down. */
	UFUNCTION(Exec) void SJCarry();
	/**
	 * Screenshot after a settle. `shot` fires the instant the map opens, which catches the camera
	 * lag mid-interpolation and smears the frame — every automated capture was coming out blurred
	 * and none of them were showing what the game looks like.
	 */
	UFUNCTION(Exec) void SJShot(float AfterSeconds);
	/** Sound the brickwork after a delay, so a capture can catch the arm mid-reach. */
	UFUNCTION(Exec) void SJTap(float AfterSeconds);

	/** Is there a dog in at or above head height that a ladder could be lashed to? */
	UFUNCTION(BlueprintPure, Category = "Steeplejack") bool HasLashableAnchor() const;

	/** Are you standing at the top of what you have built, with nowhere further up? */
	UFUNCTION(BlueprintPure, Category = "Steeplejack") bool IsAtLadderTop() const;

	/** Have you read the joint at this height yet? */
	UFUNCTION(BlueprintPure, Category = "Steeplejack") bool HasTappedHere() const;

private:
	void MoveForward(float Value);
	void MoveRight(float Value);
	void Turn(float Value);
	void LookUp(float Value);
	void StartWorking();
	void StopWorking();
	void CycleStance();
	void EnterWorkMode();
	void LeaveWorkMode();
	void ResolveStrike();
	void TapJoint();
	void LashLadder();
	void PickUpMaterials();
	void PoseBody(float DeltaSeconds);
	void SeatAnchor();

	AChimneyActor* FindChimney() const;

	sj::Meters       Meters{};
	sj::MeterContext Context{};

	float InputForward = 0.0f;
	float InputRight = 0.0f;
	bool  bWorking = false;
	bool  bOnLadder = false;
	FString BandName;

	bool    bWorkMode = false;
	FVector2D Aim = FVector2D::ZeroVector;   // degrees, the hand
	FVector2D Drift = FVector2D::ZeroVector; // degrees, the wobble
	float   DriftPhase = 0.0f;
	float   SwingPower = 0.0f;
	bool    bDrawing = false;
	float   DogDepth = 0.0f;
	float   Lean = 0.0f;
	float   StrikeCooldown = 0.0f;
	FString LastStrike;
	sj::Joint WorkJoint{};

	// The stack you have built. Anchors are where dogs went in; LadderTopM is how high the
	// topmost lashed section reaches, and therefore how high you may climb.
	TArray<sj::Anchor> Anchors;
	float   LadderTopM = 5.0f;    // the first section stands off the ground
	bool    bCarryingLadder = false;
	int32   DogsCarried = 0;
	int32   LaddersAtBase = 12;
	int32   DogsAtBase = 14;

	bool    bThirdPerson = true;
	float   TapReach = 0.0f;      // 0-1, the working arm going out to the brick and back
	float   StridePhase = 0.0f;   // drives the climb, so the legs move when you do
	FString TapReading;
	int32   TapPipShape = -1;
	float   TappedAtM = -100.0f;
	FString SpanWarning;

	UPROPERTY() TObjectPtr<AChimneyActor> Chimney;
};
