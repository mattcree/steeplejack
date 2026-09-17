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
	TObjectPtr<UCameraComponent> Camera;

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
	UFUNCTION(BlueprintPure, Category = "Steeplejack") int32 GetLaddersLeft() const { return LaddersLeft; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") int32 GetDogsLeft() const { return DogsLeft; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") int32 GetAnchorCount() const { return Anchors.Num(); }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") FString GetTapReading() const { return TapReading; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") int32 GetTapPipShape() const { return TapPipShape; }
	UFUNCTION(BlueprintPure, Category = "Steeplejack") FString GetSpanWarning() const { return SpanWarning; }

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
	int32   LaddersLeft = 12;
	int32   DogsLeft = 14;
	FString TapReading;
	int32   TapPipShape = -1;
	FString SpanWarning;

	UPROPERTY() TObjectPtr<AChimneyActor> Chimney;
};
