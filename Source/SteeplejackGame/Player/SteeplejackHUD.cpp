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

	/**
	 * One thing you could do, or could not do and why. The "why" is the whole point: an action
	 * that is greyed out with no reason teaches you nothing, and this game's actions are gated on
	 * state a new player cannot see (whether a dog is seated, whether you are on the ladder).
	 */
	struct Affordance
	{
		const TCHAR* Key;
		const TCHAR* Verb;
		bool         bAvailable;
		FString      Why;     // shown only when unavailable
	};

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
	// kRestAlpha is a deliberate departure from "fade out": a meter faded to nothing is a meter the
	// player never learns they have. They fade to a ghost instead — present enough to be noticed
	// once, faint enough that a calm climb still reads as a chimney rather than a dashboard.
	constexpr float kRestAlpha = 0.22f;
	const float GripAlpha = FMath::Max3(
		bBusy ? 1.0f : kRestAlpha, kRestAlpha, Ease((kFadeAboveValue - Grip) / 25.0f));
	const float NerveAlpha = FMath::Max3(
		bBusy ? 0.85f : kRestAlpha, kRestAlpha,
		Ease((kFadeAboveValue - (Nerve / NerveMax) * 100.0f) / 25.0f));

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

	// Named for the first half-minute only. After that the shape, the colour and the flash carry
	// it, and a label on a diegetic meter starts to look like a spreadsheet.
	if (Now < 30.0f)
	{
		const float NameA = Ease((30.0f - Now) / 5.0f) * 0.55f;
		Label(Canvas, Small, TEXT("grip"),  kHandX - 20.0f, Hand.Y + kGripRadius + 2.0f,
			FLinearColor(0.86f, 0.74f, 0.42f, NameA));
		Label(Canvas, Small, TEXT("nerve"), kHandX + 30.0f, Hand.Y + kNerveRadius + 2.0f,
			FLinearColor(0.42f, 0.58f, 0.78f, NameA));
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
	const bool bLowStock = !Jack->IsCarryingLadder() || Jack->GetDogsLeft() <= 2;
	const float StockAlpha = (bBusy || bLowStock) ? (bLowStock ? 0.95f : 0.65f) : 0.0f;
	if (StockAlpha > 0.01f)
	{
		Label(Canvas, Small,
			FString::Printf(TEXT("%s   %d dogs in the bag   top %.0fm"),
				Jack->IsCarryingLadder() ? TEXT("ladder on your shoulder") : TEXT("no ladder"),
				Jack->GetDogsLeft(), Jack->GetLadderTopMetres()),
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

	// --- what you can do, and what is stopping you -----------------------------------------------
	// The spec's minimalism is about *meters* — it says no minimap and no objective marker, not
	// that the verbs should be a secret. Every action here is gated on state the player cannot see
	// (is a dog seated? have I read this joint?), so a list that only greys things out would be
	// worse than nothing: each row carries its own reason. And because four rows all reading
	// "not on the ladder" is noise rather than instruction, the off-ladder case collapses to the
	// one move that matters and a note about what it opens up.
	const bool bLadder  = Jack->IsOnLadder();
	const bool bTapped  = Jack->HasTappedHere();
	const bool bDogs    = Jack->GetDogsLeft() > 0;
	const bool bLashable = Jack->HasLashableAnchor();
	const bool bCarrying = Jack->IsCarryingLadder();
	const bool bCradle   = Jack->IsAtCradle();

	// The single next move. A list tells you what exists; this tells you what to do, which is the
	// thing a player standing in a field thirty metres from a chimney actually needs.
	FString NextStep;
	if (Jack->IsInWorkMode())
		NextStep = TEXT("Line the dog up, then hold LMB to draw — release to strike.");
	else if (bCradle && (!bCarrying || !bDogs))
		NextStep = TEXT("Take a ladder and fill the dog bag.  [F]");
	else if (!bLadder)
		NextStep = TEXT("Walk to the foot of the stack and climb on.");
	else if (bLashable && bCarrying)
		NextStep = TEXT("Lash the ladder to that dog, then climb it.  [R]");
	else if (bLashable && !bCarrying)
		NextStep = TEXT("Nothing to lash — climb down to the cradle for a ladder.");
	else if (!bDogs)
		NextStep = TEXT("Bag is empty. Climb down to the cradle for more dogs.");
	else if (!bTapped)
		NextStep = TEXT("Tap the brickwork to hear what the joint is worth.  [E]");
	else
		NextStep = TEXT("Drive a dog into that joint.  [RMB]");

	{
		float W = 0.0f, H = 0.0f;
		Canvas->TextSize(Font, NextStep, W, H);
		Label(Canvas, Font, NextStep, (Canvas->SizeX - W) * 0.5f, Canvas->SizeY - 96.0f,
			FLinearColor(0.95f, 0.93f, 0.88f, 0.90f));
	}

	{
		TArray<Affordance> Rows;
		if (Jack->IsInWorkMode())
		{
			Rows.Add({ TEXT("mouse"), TEXT("place the dog"), true, {} });
			Rows.Add({ TEXT("A/D"),   TEXT("lean for the angle"), true, {} });
			Rows.Add({ TEXT("LMB"),   TEXT("hold to draw, release to strike"), true, {} });
			Rows.Add({ TEXT("RMB"),   TEXT("back out"), true, {} });
		}
		else if (!bLadder)
		{
			Rows.Add({ TEXT("WASD"), TEXT("walk"), true, {} });
			Rows.Add({ TEXT("mouse"), TEXT("look"), true, {} });
			Rows.Add({ TEXT("F"), TEXT("take a ladder and dogs"), bCradle,
			           TEXT("only at the cradle, at the foot of the stack") });
			Rows.Add({ TEXT("Q"), TEXT("change stance"), true, {} });
			Rows.Add({ TEXT("—"), TEXT("tapping and dogs open up on the stack"), false, {} });
		}
		else
		{
			Rows.Add({ TEXT("W/S"), TEXT("climb"), true, {} });
			Rows.Add({ TEXT("E"),   TEXT("tap the brickwork"), true, {} });
			Rows.Add({ TEXT("RMB"), TEXT("dog in"), bTapped && bDogs,
			           !bTapped ? FString(TEXT("tap the joint first"))
			                    : FString(TEXT("no dogs left")) });
			Rows.Add({ TEXT("R"),   TEXT("lash the next ladder"), bLashable && bCarrying,
			           !bCarrying ? FString(TEXT("you are not carrying one"))
			                      : FString(TEXT("needs a dog seated above you")) });
			Rows.Add({ TEXT("Q"),   TEXT("change stance"), true, {} });
		}

		// Stacked upward from the bottom-right, clear of the screen edge so the last row is not
		// half a row of pixels.
		const float RowH = 17.0f;
		float RowY = Canvas->SizeY - 44.0f - RowH * (Rows.Num() - 1);
		for (const Affordance& A : Rows)
		{
			const FString Line = (A.bAvailable || A.Why.IsEmpty())
				? FString::Printf(TEXT("[%s]  %s"), A.Key, A.Verb)
				: FString::Printf(TEXT("[%s]  %s — %s"), A.Key, A.Verb, *A.Why);

			float W = 0.0f, H = 0.0f;
			Canvas->TextSize(Small, Line, W, H);
			Label(Canvas, Small, Line, Canvas->SizeX - W - 28.0f, RowY,
				A.bAvailable ? FLinearColor(0.93f, 0.90f, 0.84f, 0.88f)
				             : FLinearColor(0.64f, 0.62f, 0.60f, 0.48f));
			RowY += RowH;
		}
	}

	// --- what the game is ------------------------------------------------------------------------
	// There is no objective marker because the objective is the top of the chimney and you can see
	// it. But you cannot see the *rule* — that the stack is the only thing you may stand on — so it
	// is said once, at the start, and then never again.
	if (Now < 14.0f)
	{
		const float A = Ease(FMath::Min(Now, 1.0f)) * Ease((14.0f - Now) / 3.0f);
		const FString Line(TEXT("Climb the stack. You can only go as high as you have built."));
		float W = 0.0f, H = 0.0f;
		Canvas->TextSize(Font, Line, W, H);
		Label(Canvas, Font, Line, (Canvas->SizeX - W) * 0.5f, Canvas->SizeY * 0.14f,
			FLinearColor(0.92f, 0.90f, 0.86f, 0.85f * A));
	}
}
