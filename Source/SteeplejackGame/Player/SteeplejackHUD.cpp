#include "Player/SteeplejackHUD.h"

#include "Player/SteeplejackPawn.h"

#include "Engine/Canvas.h"
#include "Engine/Font.h"

namespace
{
	// Grip is red as it goes; nerve blues out. Placeholder until UI-001 — but the *thresholds*
	// are the sim's, not invented here, so what you see is what the rules say.
	void Bar(UCanvas* C, float X, float Y, float W, float H, float Fraction, FLinearColor Colour)
	{
		C->SetDrawColor(20, 20, 22, 180);
		C->DrawTile(C->DefaultTexture, X - 2, Y - 2, W + 4, H + 4, 0, 0, 1, 1);
		C->SetDrawColor(static_cast<uint8>(Colour.R * 255), static_cast<uint8>(Colour.G * 255),
		                static_cast<uint8>(Colour.B * 255), 235);
		C->DrawTile(C->DefaultTexture, X, Y, W * FMath::Clamp(Fraction, 0.0f, 1.0f), H, 0, 0, 1, 1);
	}
}

void ASteeplejackHUD::DrawHUD()
{
	Super::DrawHUD();

	ASteeplejackPawn* Jack = Cast<ASteeplejackPawn>(GetOwningPawn());
	if (!Jack || !Canvas)
	{
		return;
	}

	UFont* Font = GEngine->GetMediumFont();
	const float X = 40.0f;
	float Y = Canvas->SizeY - 150.0f;

	// Grip: reddens as it drops, so the tremor threshold is visible before it bites.
	const float GripFrac = Jack->GetGrip() / 100.0f;
	const FLinearColor GripColour = Jack->IsTremoring()
		? FLinearColor(0.85f, 0.20f, 0.15f)
		: FLinearColor::LerpUsingHSV(FLinearColor(0.85f, 0.35f, 0.15f),
		                             FLinearColor(0.55f, 0.75f, 0.35f), GripFrac);
	Bar(Canvas, X, Y, 320.0f, 16.0f, GripFrac, GripColour);
	Canvas->SetDrawColor(235, 235, 235, 255);
	Canvas->DrawText(Font, FString::Printf(TEXT("GRIP  %.0f    %s"), Jack->GetGrip(),
		Jack->IsTremoring() ? TEXT("— hands shaking") : TEXT("")), X + 330.0f, Y - 2.0f);

	Y += 26.0f;
	const float NerveFrac = Jack->GetNerveMax() > 0.0f ? Jack->GetNerve() / Jack->GetNerveMax() : 0.0f;
	static const TCHAR* BandWords[] = { TEXT("calm"), TEXT("uneasy"), TEXT("bad"), TEXT("gripped") };
	const int32 Band = FMath::Clamp(Jack->GetNerveBand(), 0, 3);
	Bar(Canvas, X, Y, 320.0f, 16.0f, NerveFrac, FLinearColor(0.35f, 0.55f, 0.80f));
	Canvas->SetDrawColor(235, 235, 235, 255);
	Canvas->DrawText(Font, FString::Printf(TEXT("NERVE %.0f    %s"), Jack->GetNerve(),
		BandWords[Band]), X + 330.0f, Y - 2.0f);

	// The state line: where you are, what you are stood on, what it is costing.
	Y += 34.0f;
	const float Left = Jack->GetSecondsOfWorkLeft();
	Canvas->SetDrawColor(205, 205, 210, 255);
	Canvas->DrawText(Font, FString::Printf(
		TEXT("%.0f m   %s   %s%s   %s"),
		Jack->GetHeightMetres(),
		Jack->IsOnLadder() ? TEXT("on the ladder") : TEXT("on the ground"),
		*Jack->GetStanceName(),
		Jack->IsWorking() ? TEXT(" — working") : TEXT(""),
		Left < 0.0f ? TEXT("") : *FString::Printf(TEXT("~%.0fs of work left"), Left)),
		X, Y);

	Y += 22.0f;
	if (!Jack->GetBandName().IsEmpty())
	{
		Canvas->SetDrawColor(170, 170, 175, 255);
		Canvas->DrawText(Font, FString::Printf(TEXT("band: %s"), *Jack->GetBandName()), X, Y);
	}

	Canvas->SetDrawColor(150, 150, 155, 255);
	Canvas->DrawText(Font, TEXT("WASD move / climb   mouse look   LMB work   Q stance"),
		X, Canvas->SizeY - 28.0f);
}
