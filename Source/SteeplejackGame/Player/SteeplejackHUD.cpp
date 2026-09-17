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

	// The ascent: what you have built, and what it cost you. Materials are the decision -- bring
	// too few and you do not reach the top.
	Y += 22.0f;
	Canvas->SetDrawColor(215, 205, 180, 255);
	Canvas->DrawText(Font, FString::Printf(
		TEXT("ladder tops out at %.0fm   %d ladders   %d dogs   %d anchors"),
		Jack->GetLadderTopMetres(), Jack->GetLaddersLeft(), Jack->GetDogsLeft(),
		Jack->GetAnchorCount()), X, Y);

	if (!Jack->GetSpanWarning().IsEmpty())
	{
		Y += 20.0f;
		const bool bBuckle = Jack->GetSpanWarning().Contains(TEXT("BUCKLE"));
		Canvas->SetDrawColor(bBuckle ? 235 : 225, bBuckle ? 70 : 170, 60, 255);
		Canvas->DrawText(Font, *Jack->GetSpanWarning(), X, Y);
	}

	if (!Jack->GetTapReading().IsEmpty())
	{
		Y += 20.0f;
		Canvas->SetDrawColor(200, 210, 220, 255);
		// The pip is a shape, never a colour (rule 8): a player who cannot hear the ring and a
		// player who cannot tell red from green must both be able to read the joint.
		static const TCHAR* Pips[] = { TEXT("(O)"), TEXT("[#]"), TEXT("/_\\"), TEXT(">|<") };
		const int32 Pip = Jack->GetTapPipShape();
		Canvas->DrawText(Font, FString::Printf(TEXT("%s  %s"),
			(Pip >= 0 && Pip < 4) ? Pips[Pip] : TEXT("   "), *Jack->GetTapReading()), X, Y);
	}

	if (!Jack->GetLastStrikeResult().IsEmpty() && !Jack->IsInWorkMode())
	{
		Y += 20.0f;
		Canvas->SetDrawColor(180, 180, 185, 255);
		Canvas->DrawText(Font, *Jack->GetLastStrikeResult(), X, Y);
	}

	Y += 22.0f;
	if (!Jack->GetBandName().IsEmpty())
	{
		Canvas->SetDrawColor(170, 170, 175, 255);
		Canvas->DrawText(Font, FString::Printf(TEXT("band: %s"), *Jack->GetBandName()), X, Y);
	}

	// --- work mode -----------------------------------------------------------------------------
	if (Jack->IsInWorkMode())
	{
		const float CX = Canvas->SizeX * 0.5f;
		const float CY = Canvas->SizeY * 0.42f;

		// The tolerance ring: inside it a strike is clean, outside it bends dogs. Drawn so the
		// player can see the wobble eating their margin rather than being told about it.
		const float PixelsPerDeg = 9.0f;
		const float Tolerance = 12.0f * PixelsPerDeg;   // hammerMaxAngleErrorDegrees
		Canvas->SetDrawColor(120, 120, 130, 120);
		Canvas->DrawTile(Canvas->DefaultTexture, CX - Tolerance, CY - 1, Tolerance * 2, 2, 0, 0, 1, 1);
		Canvas->DrawTile(Canvas->DefaultTexture, CX - 1, CY - Tolerance, 2, Tolerance * 2, 0, 0, 1, 1);

		// Where the hammer actually is: aim plus wobble.
		const float Err = Jack->GetAngleErrorDeg();
		const float R = Err * PixelsPerDeg;
		const bool bClean = Err < 12.0f * 0.35f;
		Canvas->SetDrawColor(bClean ? 120 : 220, bClean ? 220 : 110, 110, 255);
		Canvas->DrawTile(Canvas->DefaultTexture, CX + R - 5, CY - 5, 10, 10, 0, 0, 1, 1);

		// Draw strength. Release near the top for power, but only if the angle is clean.
		const float BarW = 220.0f;
		Bar(Canvas, CX - BarW * 0.5f, CY + Tolerance + 30.0f, BarW, 12.0f,
			Jack->GetSwingPower(), FLinearColor(0.85f, 0.70f, 0.30f));

		Canvas->SetDrawColor(235, 235, 235, 255);
		Canvas->DrawText(Font, FString::Printf(TEXT("dog %.0f%%   %.1f deg off   wobble %.1f deg%s"),
			Jack->GetDogDepth() * 100.0f, Err, Jack->GetWobbleDeg(),
			FMath::Abs(Jack->GetLean()) > 0.05f
				? *FString::Printf(TEXT("   leaning %.0f%%"), Jack->GetLean() * 100.0f)
				: TEXT("")),
			CX - BarW * 0.5f, CY + Tolerance + 50.0f);

		Canvas->SetDrawColor(200, 200, 205, 255);
		Canvas->DrawText(Font, *Jack->GetLastStrikeResult(), CX - BarW * 0.5f, CY + Tolerance + 70.0f);
	}

	Canvas->SetDrawColor(150, 150, 155, 255);
	Canvas->DrawText(Font, Jack->IsInWorkMode()
		? TEXT("mouse aims the hammer   A/D lean   hold LMB draw, release to strike   let go of RMB to stop")
		: TEXT("WASD climb   E tap the joint   RMB dog it in   R lash a ladder   Q stance"),
		X, Canvas->SizeY - 28.0f);
}
