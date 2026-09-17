#include "Structures/ChimneyActor.h"

#include "Components/InstancedStaticMeshComponent.h"
#include "Misc/Paths.h"
#include "UObject/ConstructorHelpers.h"

DEFINE_LOG_CATEGORY_STATIC(LogSteeplejackStructure, Log, All);

namespace
{
	// Unreal works in centimetres; everything in data/ and in SteeplejackSim is metres. One place
	// to convert, so the boundary is visible rather than scattered through the maths.
	constexpr float kUUPerMetre = 100.0f;

	// The engine cylinder is a 100cm-diameter, 100cm-tall unit, so a scale of 1 is one metre.
	const TCHAR* kCylinder = TEXT("/Engine/BasicShapes/Cylinder.Cylinder");
}

AChimneyActor::AChimneyActor()
{
	PrimaryActorTick.bCanEverTick = false;

	Courses = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("Courses"));
	SetRootComponent(Courses);
	Courses->SetMobility(EComponentMobility::Movable);   // no lightmap build in a headless pass
	Courses->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);

	static ConstructorHelpers::FObjectFinder<UStaticMesh> Mesh(kCylinder);
	if (Mesh.Succeeded())
	{
		Courses->SetStaticMesh(Mesh.Object);
	}
}

void AChimneyActor::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	Rebuild();
}

void AChimneyActor::BeginPlay()
{
	Super::BeginPlay();
	if (BuiltCourses == 0)
	{
		Rebuild();
	}
}

void AChimneyActor::Rebuild()
{
	if (Courses == nullptr)
	{
		return;
	}
	Courses->ClearInstances();
	BuiltHeightMetres = 0.0f;
	BuiltCourses = 0;

	const FString Full = FPaths::Combine(FPaths::ProjectDir(), LevelPath);

	sj::LevelData Level;
	try
	{
		Level = sj::LevelData::LoadFrom(TCHAR_TO_UTF8(*Full));
	}
	catch (const std::exception& Error)
	{
		// A level that will not load must say so and leave an empty stack, not half a chimney.
		UE_LOG(LogSteeplejackStructure, Error, TEXT("SJCHIMNEY: cannot load %s: %s"),
			*Full, UTF8_TO_TCHAR(Error.what()));
		return;
	}

	const std::vector<std::string> Problems = Level.Validate();
	for (const std::string& Problem : Problems)
	{
		UE_LOG(LogSteeplejackStructure, Warning, TEXT("SJCHIMNEY: %s"), UTF8_TO_TCHAR(Problem.c_str()));
	}

	const sj::StructureSpec& S = Level.Structure();
	const float HeightM = S.height;
	if (HeightM <= 0.0f)
	{
		UE_LOG(LogSteeplejackStructure, Error, TEXT("SJCHIMNEY: %s has no height"), *Full);
		return;
	}

	const int32 CourseCount = FMath::Max(1, FMath::RoundToInt(HeightM * CoursesPerMetre));
	const float CourseH = HeightM / static_cast<float>(CourseCount);

	for (int32 i = 0; i < CourseCount; ++i)
	{
		// Radius interpolates base to top across the whole stack — the batter. Sampled at the
		// middle of each course so the silhouette is centred on the true taper rather than
		// consistently fat or thin.
		const float T = (static_cast<float>(i) + 0.5f) / static_cast<float>(CourseCount);
		const float Radius = FMath::Lerp(S.baseRadius, S.topRadius, T);
		const float CentreZ = (static_cast<float>(i) * CourseH + CourseH * 0.5f) * kUUPerMetre;

		FTransform X;
		X.SetLocation(FVector(0.0f, 0.0f, CentreZ));
		X.SetScale3D(FVector(Radius * 2.0f, Radius * 2.0f, CourseH));
		Courses->AddInstance(X);
	}

	BuiltHeightMetres = HeightM;
	BuiltCourses = CourseCount;

	UE_LOG(LogSteeplejackStructure, Display,
		TEXT("SJCHIMNEY: built '%s' (%s) %.1fm in %d courses, %.2f->%.2fm radius, %d band(s), %d validation problem(s)"),
		UTF8_TO_TCHAR(Level.Id().c_str()), UTF8_TO_TCHAR(Level.Archetype().c_str()),
		HeightM, CourseCount, S.baseRadius, S.topRadius,
		static_cast<int32>(Level.Bands().size()), static_cast<int32>(Problems.size()));

	for (const sj::BandSpec& Band : Level.Bands())
	{
		UE_LOG(LogSteeplejackStructure, Display, TEXT("SJCHIMNEY:   band %.0f-%.0fm %s"),
			Band.from, Band.to, UTF8_TO_TCHAR(Band.type.c_str()));
	}
}
