// The jack. A capsule that walks the ground, climbs the stack, and gets tired doing it.
//
// Every rule it obeys lives in SteeplejackSim: grip and nerve are stepped by sj::grip and
// sj::nerve, the stance table comes from meters.json, and the structure it climbs comes from the
// level file. This class converts input into intent and reads sim state back out. It decides
// nothing (ADR-0004).

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"

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

	UPROPERTY() TObjectPtr<AChimneyActor> Chimney;
};
