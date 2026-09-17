// The stack, built at runtime from a level file.
//
// Rule 3: no hand-placed level geometry. A .umap holds lighting, sky and spawn points; the
// structure is generated. This is the actor that does the generating, and it reads the same
// data/levels/*.json that `make validate` checks and that sj::LevelData parses — so what you see
// in the viewport is what the sim thinks the level is, not a second copy of it in a map file.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"

#include "Level.h"

#include "ChimneyActor.generated.h"

class UInstancedStaticMeshComponent;

UCLASS()
class AChimneyActor : public AActor
{
	GENERATED_BODY()

public:
	AChimneyActor();

	/** Level file to build, relative to the project directory. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Steeplejack")
	FString LevelPath = TEXT("data/levels/06-waterside.json");

	/** Courses per metre of height. The real joint grid is STRUCT-002; this is the coarse shell. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Steeplejack")
	float CoursesPerMetre = 0.4f;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Steeplejack")
	TObjectPtr<UInstancedStaticMeshComponent> Courses;

	/** One instanced component per band, so each band can carry its own colour. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Steeplejack")
	TArray<TObjectPtr<UInstancedStaticMeshComponent>> BandCourses;

	/** Ladder sections lashed up the side, and the staging they land on. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Steeplejack")
	TObjectPtr<UInstancedStaticMeshComponent> Ladders;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Steeplejack")
	TObjectPtr<UInstancedStaticMeshComponent> Staging;

	/** Rebuild from the level file. Safe to call again; clears first. */
	UFUNCTION(BlueprintCallable, CallInEditor, Category = "Steeplejack")
	void Rebuild();

	/** Height of the structure last built, in metres. 0 if nothing loaded. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack")
	float GetBuiltHeightMetres() const { return BuiltHeightMetres; }

	/** How many courses were placed. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack")
	int32 GetCourseCount() const { return BuiltCourses; }

	virtual void OnConstruction(const FTransform& Transform) override;
	virtual void BeginPlay() override;

private:
	float BuiltHeightMetres = 0.0f;
	int32 BuiltCourses = 0;
};
