#include "Player/SteeplejackHUD.h"

#include "Player/SteeplejackPawn.h"

#include "Engine/Canvas.h"
#include "Engine/Engine.h"
#include "Engine/Font.h"

// The HUD, to the spec in docs/01-gdd/03-meters-grip-nerve.md#hud:
//
//   "Minimal and diegetic-ish. Bottom-left, two thin arcs around the hand icon. Grip: a fast,
//    responsive arc. Flashes at 20. Nerve: a slow arc that visibly breathes. Neither is shown at
//    full value with no threat — they fade out above 85 and when idle. The rest of the HUD is
//    only: anchor rating pips, material counts (fade in when relevant), daylight bar. No minimap.
//    No objective marker. The objective is at the top; you can see it."
//
// Everything here follows from that. Nothing is permanent except the arcs, and even they leave
// when you are safe and idle — the screen is meant to be a chimney, not a dashboard. Anything that
// must be read against a bright sky gets a shadow rather than a panel, because a panel is a box
// between the player and the thing they climbed to see.

namespace
{
	// Bottom-left, per the spec. Everything else is positioned relative to this.
	constexpr float kHandX = 96.0f;
	constexpr float kHandYFromBottom = 104.0f;
	constexpr float kGripRadius = 44.0f;
	constexpr float kNerveRadius = 56.0f;
	constexpr float kArcThickness = 4.0f;

	// The arcs sweep the left side, opening away from the centre of the screen so they frame the
	// hand rather than pointing at the action.
	constexpr float kArcStartDeg = 128.0f;
	constexpr float kArcSweepDeg = 244.0f;
	constexpr int32 kArcSegments = 48;

	constexpr float kFadeAboveValue = 85.0f;   // the spec's "fade out above 85"
	constexpr float kTremorValue = 20.0f;      // "flashes at 20"

	FVector2D OnArc(const FVector2D& Centre, float Radius, float Degrees)
	{
		const float R = FMath::DegreesToRadians(Degrees);
		return Centre + FVector2D(FMath::Cos(R) * Radius, -FMath::Sin(R) * Radius);
	}

	void Arc(UCanvas* C, const FVector2D& Centre, float Radius, float Fraction, float Thickness,
	         const FLinearColor& Colour)
	{
		if (Fraction <= 0.0f || Colour.A <= 0.01f)
		{
			return;
		}
		const int32 Steps = FMath::Max(2, FMath::RoundToInt(kArcSegments * Fraction));
		const float Span = kArcSweepDeg * FMath::Clamp(Fraction, 0.0f, 1.0f);
		for (int32 i = 0; i < Steps; ++i)
		{
			const float A = kArcStartDeg - Span * (static_cast<float>(i) / Steps);
			const float B = kArcStartDeg - Span * (static_cast<float>(i + 1) / Steps);
			C->K2_DrawLine(OnArc(Centre, Radius, A), OnArc(Centre, Radius, B), Thickness, Colour);
		}
	}

	/** The unfilled remainder, so the arc reads as a gauge rather than a floating stroke. */
	void ArcTrack(UCanvas* C, const FVector2D& Centre, float Radius, float Alpha)
	{
		Arc(C, Centre, Radius, 1.0f, 1.5f, FLinearColor(0.0f, 0.0f, 0.0f, 0.35f * Alpha));
	}

	/** Text with a shadow rather than a panel: legible on sky without boxing the view in. */
	void Label(UCanvas* C, UFont* Font, const FString& Text, float X, float Y,
	           const FLinearColor& Colour)
	{
		if (Colour.A <= 0.01f)
		{
			return;
		}
		C->SetDrawColor(0, 0, 0, static_cast<uint8>(150 * Colour.A));
		C->DrawText(Font, Text, X + 1.0f, Y + 1.0f);
		C->SetDrawColor(static_cast<uint8>(Colour.R * 255), static_cast<uint8>(Colour.G * 255),
		                static_cast<uint8>(Colour.B * 255), static_cast<uint8>(Colour.A * 255));
		C->DrawText(Font, Text, X, Y);
	}

	/** Smooth 0→1 with a soft shoulder, for fades that do not pop. */
	float Ease(float T)
	{
		T = FMath::Clamp(T, 0.0f, 1.0f);
		return T * T * (3.0f - 2.0f * T);
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

	UFont* Small = GEngine->GetSmallFont();
	UFont* Font = GEngine->GetMediumFont();
	const float Now = GetWorld() ? GetWorld()->GetTimeSeconds() : 0.0f;
	const FVector2D Hand(kHandX, Canvas->SizeY - kHandYFromBottom);

	const float Grip = Jack->GetGrip();
	const float Nerve = Jack->GetNerve();
	const float NerveMax = FMath::Max(1.0f, Jack->GetNerveMax());
	const bool bBusy = Jack->IsWorking() || Jack->IsInWorkMode();

	// --- the two arcs --------------------------------------------------------------------------
	// Faded out when you are safe and idle, so a calm climb has almost no interface on it. This is
	// the spec's rule and it is also the reason the arcs mean something when they do appear.
	const float GripAlpha = FMath::Max(
		bBusy ? 1.0f : 0.0f, Ease((kFadeAboveValue - Grip) / 25.0f));
	const float NerveAlpha = FMath::Max(
		bBusy ? 0.85f : 0.0f, Ease((kFadeAboveValue - (Nerve / NerveMax) * 100.0f) / 25.0f));

	// Grip is the fast one. Below the tremor threshold it flashes — the telegraph, on screen.
	float GripPulse = 1.0f;
	if (Jack->IsTremoring())
	{
		GripPulse = 0.55f + 0.45f * FMath::Sin(Now * 9.0f);
	}
	const FLinearColor GripColour = Jack->IsTremoring()
		? FLinearColor(0.92f, 0.28f, 0.20f, GripAlpha * GripPulse)
		: FLinearColor(0.86f, 0.74f, 0.42f, GripAlpha);

	// Nerve is the slow one, and it breathes: a real, visible in-and-out at rest-breathing rate,
	// faster as the bands get worse. It is the character's chest, not a progress bar.
	const float BreathRate = 0.55f + 0.30f * Jack->GetNerveBand();
	const float Breath = 1.0f + 0.035f * FMath::Sin(Now * BreathRate * PI);
	const FLinearColor NerveColour(0.42f, 0.58f, 0.78f, NerveAlpha);

	ArcTrack(Canvas, Hand, kGripRadius, GripAlpha);
	ArcTrack(Canvas, Hand, kNerveRadius, NerveAlpha);
	Arc(Canvas, Hand, kGripRadius, Grip / 100.0f, kArcThickness, GripColour);
	Arc(Canvas, Hand, kNerveRadius * Breath, Nerve / NerveMax, kArcThickness - 1.0f, NerveColour);

	// The hand: a small mark the arcs wrap, so they read as belonging to a body. Abstract on
	// purpose — a proper glyph is UI-001's, and a placeholder that pretends otherwise would be
	// harder to replace than one that clearly does not.
	const float HandAlpha = FMath::Max(GripAlpha, NerveAlpha);
	if (HandAlpha > 0.01f)
	{
		Canvas->K2_DrawLine(Hand + FVector2D(-7, 4), Hand + FVector2D(0, -8), 2.5f,
			FLinearColor(0.85f, 0.80f, 0.72f, HandAlpha));
		Canvas->K2_DrawLine(Hand + FVector2D(0, -8), Hand + FVector2D(7, 4), 2.5f,
			FLinearColor(0.85f, 0.80f, 0.72f, HandAlpha));
		Canvas->K2_DrawLine(Hand + FVector2D(-5, 6), Hand + FVector2D(5, 6), 2.5f,
			FLinearColor(0.85f, 0.80f, 0.72f, HandAlpha));
	}

	// --- where you are -------------------------------------------------------------------------
	// One quiet line. Height is the only number that is always worth knowing, because it is the
	// thing the whole game is about.
	const float InfoX = kHandX + kNerveRadius + 26.0f;
	float Y = Canvas->SizeY - kHandYFromBottom - 26.0f;

	Label(Canvas, Font, FString::Printf(TEXT("%.0f m"), Jack->GetHeightMetres()), InfoX, Y,
		FLinearColor(0.94f, 0.92f, 0.88f, 0.92f));

	if (Jack->IsOnLadder())
	{
		Y += 20.0f;
		FString Where = Jack->GetStanceName();
		if (!Jack->GetBandName().IsEmpty())
		{
			Where += TEXT("  ·  ") + Jack->GetBandName();
		}
		Label(Canvas, Small, Where, InfoX, Y, FLinearColor(0.80f, 0.78f, 0.74f, 0.70f));
	}

	// --- material counts: "fade in when relevant" ----------------------------------------------
	// Relevant means you are working, or you are running out. Otherwise they are not on screen.
	const bool bLowStock = Jack->GetLaddersLeft() <= 3 || Jack->GetDogsLeft() <= 3;
	const float StockAlpha = (bBusy || bLowStock) ? (bLowStock ? 0.95f : 0.65f) : 0.0f;
	if (StockAlpha > 0.01f)
	{
		Label(Canvas, Small,
			FString::Printf(TEXT("%d ladders   %d dogs   top %.0fm"),
				Jack->GetLaddersLeft(), Jack->GetDogsLeft(), Jack->GetLadderTopMetres()),
			InfoX, Canvas->SizeY - kHandYFromBottom + 22.0f,
			bLowStock ? FLinearColor(0.92f, 0.62f, 0.32f, StockAlpha)
			          : FLinearColor(0.78f, 0.76f, 0.72f, StockAlpha));
	}

	// --- the span you are stood on --------------------------------------------------------------
	// Only when it is a problem. A rigid span says nothing, which is what makes a warning mean
	// something when it appears.
	if (!Jack->GetSpanWarning().IsEmpty())
	{
		const bool bBuckle = Jack->GetSpanWarning().Contains(TEXT("BUCKLE"));
		const float Pulse = bBuckle ? 0.6f + 0.4f * FMath::Sin(Now * 7.0f) : 1.0f;
		Label(Canvas, Font, Jack->GetSpanWarning(), InfoX, Canvas->SizeY - kHandYFromBottom + 44.0f,
			bBuckle ? FLinearColor(0.95f, 0.30f, 0.22f, Pulse)
			        : FLinearColor(0.92f, 0.70f, 0.35f, 0.90f));
	}

	// --- what the last thing you did told you ---------------------------------------------------
	// Centre-low, where the eye already is after a strike. One line, no history.
	const FString Message = Jack->IsInWorkMode() ? FString() : Jack->GetLastStrikeResult();
	if (!Message.IsEmpty())
	{
		float W = 0.0f, H = 0.0f;
		Canvas->TextSize(Font, Message, W, H);
		Label(Canvas, Font, Message, (Canvas->SizeX - W) * 0.5f, Canvas->SizeY * 0.70f,
			FLinearColor(0.90f, 0.88f, 0.84f, 0.88f));
	}

	// The tap reading sits with its shape pip, because rule 8 says the sound must have a visual
	// fallback and the fallback must not be a colour.
	if (!Jack->GetTapReading().IsEmpty() && !Jack->IsInWorkMode())
	{
		static const TCHAR* Pips[] = { TEXT("●"), TEXT("■"), TEXT("▲"), TEXT("✖") };
		const int32 Pip = Jack->GetTapPipShape();
		const FString Line = FString::Printf(TEXT("%s  %s"),
			(Pip >= 0 && Pip < 4) ? Pips[Pip] : TEXT(" "), *Jack->GetTapReading());
		float W = 0.0f, H = 0.0f;
		Canvas->TextSize(Font, Line, W, H);
		Label(Canvas, Font, Line, (Canvas->SizeX - W) * 0.5f, Canvas->SizeY * 0.70f - 24.0f,
			FLinearColor(0.86f, 0.90f, 0.94f, 0.92f));
	}

	// --- work mode ------------------------------------------------------------------------------
	// Everything above recedes; this is the whole screen for as long as you hold it.
	if (Jack->IsInWorkMode())
	{
		const FVector2D Eye(Canvas->SizeX * 0.5f, Canvas->SizeY * 0.44f);
		const float PxPerDeg = 10.0f;
		const float Tolerance = 12.0f * PxPerDeg;

		// The tolerance ring: inside it a strike is clean, outside it bends dogs. Drawn as a ring
		// so the player watches the wobble eat their margin rather than reading a number for it.
		for (int32 i = 0; i < 72; ++i)
		{
			const float A = i * 5.0f;
			const float B = A + 5.0f;
			Canvas->K2_DrawLine(OnArc(Eye, Tolerance, A), OnArc(Eye, Tolerance, B), 1.5f,
				FLinearColor(0.85f, 0.85f, 0.90f, 0.30f));
		}

		const float Err = Jack->GetAngleErrorDeg();
		const float Quality = FMath::Clamp(1.0f - Err / 12.0f, 0.0f, 1.0f);
		const FVector2D Tip = Eye + FVector2D(Err * PxPerDeg, 0.0f);
		const FLinearColor Mark = FLinearColor::LerpUsingHSV(
			FLinearColor(0.95f, 0.35f, 0.25f, 1.0f), FLinearColor(0.55f, 0.85f, 0.45f, 1.0f),
			Quality);

		Canvas->K2_DrawLine(Tip + FVector2D(-9, 0), Tip + FVector2D(9, 0), 2.0f, Mark);
		Canvas->K2_DrawLine(Tip + FVector2D(0, -9), Tip + FVector2D(0, 9), 2.0f, Mark);

		// Draw strength, as an arc under the ring so the eye never leaves the joint.
		const float Power = Jack->GetSwingPower();
		if (Power > 0.0f)
		{
			for (int32 i = 0; i < FMath::RoundToInt(40 * Power); ++i)
			{
				const float A = 250.0f - (i * 110.0f / 40.0f);
				const float B = A - 110.0f / 40.0f;
				Canvas->K2_DrawLine(OnArc(Eye, Tolerance + 22.0f, A),
					OnArc(Eye, Tolerance + 22.0f, B), 5.0f,
					FLinearColor(0.90f, 0.72f, 0.30f, 0.95f));
			}
		}

		// How far in the dog is, as a bar that fills toward seating.
		const float BarW = 180.0f;
		const float BarX = Eye.X - BarW * 0.5f;
		const float BarY = Eye.Y + Tolerance + 54.0f;
		Canvas->SetDrawColor(0, 0, 0, 120);
		Canvas->DrawTile(Canvas->DefaultTexture, BarX - 1, BarY - 1, BarW + 2, 8, 0, 0, 1, 1);
		Canvas->SetDrawColor(205, 180, 120, 240);
		Canvas->DrawTile(Canvas->DefaultTexture, BarX, BarY, BarW * Jack->GetDogDepth(), 6, 0, 0, 1, 1);

		const FString Work = FString::Printf(TEXT("dog %.0f%%   %.1f° off"),
			Jack->GetDogDepth() * 100.0f, Err);
		float W = 0.0f, H = 0.0f;
		Canvas->TextSize(Small, Work, W, H);
		Label(Canvas, Small, Work, Eye.X - W * 0.5f, BarY + 14.0f,
			FLinearColor(0.85f, 0.83f, 0.80f, 0.85f));

		if (!Jack->GetLastStrikeResult().IsEmpty())
		{
			Canvas->TextSize(Font, Jack->GetLastStrikeResult(), W, H);
			Label(Canvas, Font, Jack->GetLastStrikeResult(), Eye.X - W * 0.5f, BarY + 36.0f,
				FLinearColor(0.90f, 0.88f, 0.84f, 0.90f));
		}
	}

	// --- controls -------------------------------------------------------------------------------
	// Bottom-right, dim, and only a prototype affordance: a shipping build teaches these in the
	// first level rather than printing them.
	{
		const FString Keys = Jack->IsInWorkMode()
			? TEXT("mouse aims  ·  A/D lean  ·  hold LMB draw, release to strike")
			: TEXT("WASD climb  ·  E tap  ·  RMB dog in  ·  R lash  ·  Q stance");
		float W = 0.0f, H = 0.0f;
		Canvas->TextSize(Small, Keys, W, H);
		Label(Canvas, Small, Keys, Canvas->SizeX - W - 28.0f, Canvas->SizeY - 30.0f,
			FLinearColor(0.72f, 0.70f, 0.68f, 0.45f));
	}
}
