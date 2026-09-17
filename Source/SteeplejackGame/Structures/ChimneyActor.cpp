#include "Structures/ChimneyActor.h"

#include "Components/InstancedStaticMeshComponent.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Materials/MaterialInterface.h"
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
	const TCHAR* kCube = TEXT("/Engine/BasicShapes/Cube.Cube");
	const TCHAR* kBandMaterial = TEXT("/Game/Materials/M_Band.M_Band");
	const TCHAR* kBasicMaterial = TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial");

	// Material instance assets, built by tools/editor/make_materials.py. Loaded by name rather
	// than tinted at runtime: a dynamic instance created in Rebuild() does not survive the actor
	// being saved into a map and loaded back, and the symptom is a stack that logs "material=set"
	// for every band while rendering the colours from a previous build.
	UMaterialInterface* BandMaterial(const FString& Type)
	{
		FString Name = TEXT("Default");
		if (Type == TEXT("plain"))              { Name = TEXT("Plain"); }
		else if (Type == TEXT("ivy"))           { Name = TEXT("Ivy"); }
		else if (Type == TEXT("existing-band")) { Name = TEXT("ExistingBand"); }
		else if (Type == TEXT("wind-band"))     { Name = TEXT("WindBand"); }
		else if (Type == TEXT("internal"))      { Name = TEXT("Internal"); }
		else if (Type == TEXT("__timber"))      { Name = TEXT("Timber"); }
		else if (Type == TEXT("__plank"))       { Name = TEXT("Plank"); }

		const FString Path = FString::Printf(TEXT("/Game/Materials/MI_%s.MI_%s"), *Name, *Name);
		return Cast<UMaterialInterface>(
			StaticLoadObject(UMaterialInterface::StaticClass(), nullptr, *Path));
	}

	// Band colours. Not art direction — a legend. The level file says a band is ivy or a wind band
	// and until ART-010 there is no material that shows it, so the stack is striped by band type
	// instead. Looking at the thing and seeing the data is worth more right now than looking at the
	// thing and seeing grey.
	FLinearColor ColourForBand(const FString& Type)
	{
		if (Type == TEXT("plain"))         { return FLinearColor(0.23f, 0.11f, 0.07f); }  // soot-dulled red brick
		if (Type == TEXT("ivy"))           { return FLinearColor(0.07f, 0.14f, 0.05f); }  // ivy
		if (Type == TEXT("existing-band")) { return FLinearColor(0.13f, 0.09f, 0.08f); }  // iron banding, near black
		if (Type == TEXT("wind-band"))     { return FLinearColor(0.42f, 0.33f, 0.26f); }  // bleached by weather up top
		if (Type == TEXT("internal"))      { return FLinearColor(0.20f, 0.20f, 0.22f); }
		return FLinearColor(0.50f, 0.45f, 0.42f);
	}
}

AChimneyActor::AChimneyActor()
{
	PrimaryActorTick.bCanEverTick = false;

	Courses = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("Courses"));
	SetRootComponent(Courses);
	Courses->SetMobility(EComponentMobility::Movable);   // no lightmap build in a headless pass
	Courses->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);

	Ladders = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("Ladders"));
	Ladders->SetupAttachment(Courses);
	Ladders->SetMobility(EComponentMobility::Movable);

	DrivenDogs = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("DrivenDogs"));
	DrivenDogs->SetupAttachment(Courses);
	DrivenDogs->SetMobility(EComponentMobility::Movable);

	Staging = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("Staging"));
	Staging->SetupAttachment(Courses);
	Staging->SetMobility(EComponentMobility::Movable);

	for (int32 i = 0; i < kMaxBands; ++i)
	{
		UInstancedStaticMeshComponent* Band = CreateDefaultSubobject<UInstancedStaticMeshComponent>(
			*FString::Printf(TEXT("Band%d"), i));
		Band->SetupAttachment(Courses);
		Band->SetMobility(EComponentMobility::Movable);
		Band->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
		BandCourses.Add(Band);
	}

	static ConstructorHelpers::FObjectFinder<UStaticMesh> Mesh(kCylinder);
	if (Mesh.Succeeded())
	{
		Courses->SetStaticMesh(Mesh.Object);
		for (UInstancedStaticMeshComponent* Band : BandCourses)
		{
			Band->SetStaticMesh(Mesh.Object);
		}
	}
	static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMesh(kCube);
	if (CubeMesh.Succeeded())
	{
		Ladders->SetStaticMesh(CubeMesh.Object);
		DrivenDogs->SetStaticMesh(CubeMesh.Object);
		Staging->SetStaticMesh(CubeMesh.Object);
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
	for (UInstancedStaticMeshComponent* Comp : BandCourses)
	{
		if (Comp)
		{
			Comp->ClearInstances();
		}
	}
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

	Loaded = Level;
	bLoaded = true;

	const sj::StructureSpec& S = Level.Structure();
	const float HeightM = S.height;
	if (HeightM <= 0.0f)
	{
		UE_LOG(LogSteeplejackStructure, Error, TEXT("SJCHIMNEY: %s has no height"), *Full);
		return;
	}

	const int32 CourseCount = FMath::Max(1, FMath::RoundToInt(HeightM * CoursesPerMetre));
	const float CourseH = HeightM / static_cast<float>(CourseCount);

	// A component per band, so each can carry its own colour. Made here rather than in the
	// constructor because the number of bands is a property of the level file.
	// tools/editor/make_materials.py builds M_Band: a VectorParameter wired to Base Color. The
	// engine's BasicShapeMaterial does not expose base colour, which is why the first coloured
	// render came out pastel however dark the values were set.
	UMaterialInterface* Base = Cast<UMaterialInterface>(
		StaticLoadObject(UMaterialInterface::StaticClass(), nullptr, kBandMaterial));
	if (!Base)
	{
		UE_LOG(LogSteeplejackStructure, Warning,
			TEXT("SJCHIMNEY: %s missing — run `make materials`. Falling back to flat grey."),
			kBandMaterial);
		Base = Cast<UMaterialInterface>(
			StaticLoadObject(UMaterialInterface::StaticClass(), nullptr, kBasicMaterial));
	}

	const std::vector<sj::BandSpec>& Bands = Level.Bands();
	for (int32 b = 0; b < BandCourses.Num(); ++b)
	{
		UInstancedStaticMeshComponent* Comp = BandCourses[b];
		if (!Comp)
		{
			continue;
		}
		Comp->ClearInstances();
		if (b < static_cast<int32>(Bands.size()))
		{
			if (UMaterialInterface* M = BandMaterial(UTF8_TO_TCHAR(Bands[b].type.c_str())))
			{
				Comp->SetMaterial(0, M);
			}
		}
	}

	for (int32 i = 0; i < CourseCount; ++i)
	{
		// Radius interpolates base to top across the whole stack — the batter. Sampled at the
		// middle of each course so the silhouette is centred on the true taper rather than
		// consistently fat or thin.
		const float T = (static_cast<float>(i) + 0.5f) / static_cast<float>(CourseCount);
		const float Radius = FMath::Lerp(S.baseRadius, S.topRadius, T);
		const float MidM = static_cast<float>(i) * CourseH + CourseH * 0.5f;

		FTransform X;
		X.SetLocation(FVector(0.0f, 0.0f, MidM * kUUPerMetre));
		X.SetScale3D(FVector(Radius * 2.0f, Radius * 2.0f, CourseH));

		// Put the course in its band's component. BandAt throws above the structure; the middle of
		// a course is always inside it, so this cannot.
		int32 BandIndex = 0;
		for (int32 b = 0; b < static_cast<int32>(Bands.size()); ++b)
		{
			if (MidM >= Bands[b].from && MidM < Bands[b].to)
			{
				BandIndex = b;
				break;
			}
		}
		if (BandCourses.IsValidIndex(BandIndex) && BandCourses[BandIndex])
		{
			BandCourses[BandIndex]->AddInstance(X);
		}
		else
		{
			Courses->AddInstance(X);
		}
	}

	if (Ladders) { if (UMaterialInterface* M = BandMaterial(TEXT("__timber"))) { Ladders->SetMaterial(0, M); } }
	if (Staging) { if (UMaterialInterface* M = BandMaterial(TEXT("__plank"))) { Staging->SetMaterial(0, M); } }
	if (DrivenDogs) { if (UMaterialInterface* M = BandMaterial(TEXT("__timber"))) { DrivenDogs->SetMaterial(0, M); } }

	// Only the section already standing when the jack arrives. Everything above it is the
	// player's to lash, one ladder at a time, and BuildLaddersTo is what puts it there.
	if (DrivenDogs) { DrivenDogs->ClearInstances(); }
	BuiltHeightMetres = HeightM;   // BuildLaddersTo needs the radius, which needs this set
	BuildLaddersTo(5.0f);

	// Staging at the top: the platform a jack actually works from.
	if (Staging)
	{
		Staging->ClearInstances();
		const float TopRadius = S.topRadius;
		FTransform X;
		X.SetLocation(FVector(0.0f, 0.0f, (HeightM + 0.15f) * kUUPerMetre));
		X.SetScale3D(FVector((TopRadius + 1.2f) * 2.0f, (TopRadius + 1.2f) * 2.0f, 0.3f));
		Staging->AddInstance(X);
	}

	BuiltHeightMetres = HeightM;
	BuiltCourses = CourseCount;

	UE_LOG(LogSteeplejackStructure, Display,
		TEXT("SJCHIMNEY: built '%s' (%s) %.1fm in %d courses, %.2f->%.2fm radius, %d band(s), %d validation problem(s)"),
		UTF8_TO_TCHAR(Level.Id().c_str()), UTF8_TO_TCHAR(Level.Archetype().c_str()),
		HeightM, CourseCount, S.baseRadius, S.topRadius,
		static_cast<int32>(Level.Bands().size()), static_cast<int32>(Problems.size()));

	int32 Total = Courses->GetInstanceCount();
	for (int32 b = 0; b < BandCourses.Num(); ++b)
	{
		const int32 N = BandCourses[b] ? BandCourses[b]->GetInstanceCount() : -1;
		Total += FMath::Max(0, N);
		UE_LOG(LogSteeplejackStructure, Display,
			TEXT("SJCHIMNEY:   bandcomp %d instances=%d material=%s"), b, N,
			(BandCourses[b] && BandCourses[b]->GetMaterial(0)) ? TEXT("set") : TEXT("NONE"));
	}
	UE_LOG(LogSteeplejackStructure, Display,
		TEXT("SJCHIMNEY:   totals: banded=%d loose=%d ladders=%d staging=%d basemat=%s"),
		Total, Courses->GetInstanceCount(),
		Ladders ? Ladders->GetInstanceCount() : -1,
		Staging ? Staging->GetInstanceCount() : -1,
		Base ? TEXT("loaded") : TEXT("NULL"));

	for (const sj::BandSpec& Band : Level.Bands())
	{
		UE_LOG(LogSteeplejackStructure, Display, TEXT("SJCHIMNEY:   band %.0f-%.0fm %s"),
			Band.from, Band.to, UTF8_TO_TCHAR(Band.type.c_str()));
	}
}


FVector AChimneyActor::ClimbFaceOffset(float HeightMetres) const
{
	// One face, agreed on by everything that touches it: the ladders, the dogs, and the code that
	// puts the climber against the brickwork. If these ever disagree the jack climbs thin air.
	return FVector(-(RadiusAtHeightMetres(HeightMetres) + 0.25f) * kUUPerMetre, 0.0f, 0.0f);
}

void AChimneyActor::BuildLaddersTo(float TopM)
{
	if (!Ladders) { return; }
	Ladders->ClearInstances();

	TopM = FMath::Clamp(TopM, 0.0f, FMath::Max(BuiltHeightMetres, 1.0f));

	// Rails and rungs, both cubes, both instances. A single long box read as a plank rather than a
	// ladder, and in third person the difference is the whole silhouette.
	constexpr float kRailGapM  = 0.44f;   // outside to outside
	constexpr float kRungGapM  = 0.28f;
	constexpr float kRailThick = 0.07f;

	auto Box = [&](const FVector& CentreM, const FVector& SizeM)
	{
		FTransform X;
		X.SetLocation(CentreM * kUUPerMetre);
		X.SetScale3D(SizeM);
		Ladders->AddInstance(X);
	};

	const float Face = ClimbFaceOffset(TopM * 0.5f).X / kUUPerMetre;

	// Two rails running the whole lashed height. Sections overlap in the fiction; drawing them as
	// one continuous pair avoids a seam every five metres that would read as a break in the ladder.
	for (const float Side : { -kRailGapM * 0.5f, kRailGapM * 0.5f })
	{
		Box(FVector(Face, Side, TopM * 0.5f), FVector(kRailThick, kRailThick, TopM));
	}

	const int32 Rungs = FMath::Max(1, FMath::FloorToInt(TopM / kRungGapM));
	for (int32 i = 1; i <= Rungs; ++i)
	{
		Box(FVector(Face + 0.01f, 0.0f, i * kRungGapM),
		    FVector(kRailThick * 0.8f, kRailGapM, kRailThick * 0.8f));
	}
}

void AChimneyActor::AddDogMarker(float HeightMetres)
{
	if (!DrivenDogs) { return; }
	// A stub of iron standing proud of the face, on the side the ladder runs up. Small, because a
	// dog is small, and the point is that you can count them on the way down.
	FTransform X;
	X.SetLocation(ClimbFaceOffset(HeightMetres)
		+ FVector(0.18f * kUUPerMetre, 0.30f * kUUPerMetre, HeightMetres * kUUPerMetre));
	X.SetScale3D(FVector(0.34f, 0.07f, 0.07f));
	DrivenDogs->AddInstance(X);
}

float AChimneyActor::RadiusAtHeightMetres(float HeightMetres) const
{
	if (!bLoaded || BuiltHeightMetres <= 0.0f)
	{
		return 0.0f;
	}
	const sj::StructureSpec& S = Loaded.Structure();
	const float T = FMath::Clamp(HeightMetres / BuiltHeightMetres, 0.0f, 1.0f);
	return FMath::Lerp(S.baseRadius, S.topRadius, T);
}

FString AChimneyActor::BandTypeAtHeight(float HeightMetres) const
{
	if (!bLoaded)
	{
		return FString();
	}
	// BandAt throws above the structure — a height outside the stack is a caller bug there, but
	// here it is just a climber who has run out of chimney, so clamp rather than propagate.
	const float H = FMath::Clamp(HeightMetres, 0.0f, BuiltHeightMetres - 0.01f);
	return FString(UTF8_TO_TCHAR(Loaded.BandAt(H).type.c_str()));
}
