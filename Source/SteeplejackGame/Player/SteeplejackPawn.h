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

private:
	void MoveForward(float Value);
	void MoveRight(float Value);
	void Turn(float Value);
	void LookUp(float Value);
	void StartWorking();
	void StopWorking();
	void CycleStance();

	AChimneyActor* FindChimney() const;

	sj::Meters       Meters{};
	sj::MeterContext Context{};

	float InputForward = 0.0f;
	float InputRight = 0.0f;
	bool  bWorking = false;
	bool  bOnLadder = false;
	FString BandName;

	UPROPERTY() TObjectPtr<AChimneyActor> Chimney;
};
