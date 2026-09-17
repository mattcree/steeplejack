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

	/** One instanced component per band, so each band can carry its own colour.
	 *
	 *  A fixed set, created in the constructor. An earlier version made these with NewObject at
	 *  runtime — which works, until the actor is saved into a map: the saved components come back
	 *  on load carrying their old materials, and the freshly made ones render on top of them. The
	 *  result was a stack that reported "material=set" for every band and rendered in the previous
	 *  build's colours. Default subobjects serialise predictably and cannot double up.
	 */
	static constexpr int32 kMaxBands = 8;

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

	/** Outer radius of the stack at a given height, in metres. The batter. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack")
	float RadiusAtHeightMetres(float HeightMetres) const;

	/** The band type at a height, e.g. "ivy". Empty above the structure. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack")
	FString BandTypeAtHeight(float HeightMetres) const;

	/** Height of the structure last built, in metres. 0 if nothing loaded. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack")
	float GetBuiltHeightMetres() const { return BuiltHeightMetres; }

	/** How many courses were placed. */
	UFUNCTION(BlueprintPure, Category = "Steeplejack")
	int32 GetCourseCount() const { return BuiltCourses; }

	virtual void OnConstruction(const FTransform& Transform) override;
	virtual void BeginPlay() override;

private:
	sj::LevelData Loaded;
	bool bLoaded = false;
	float BuiltHeightMetres = 0.0f;
	int32 BuiltCourses = 0;
};
