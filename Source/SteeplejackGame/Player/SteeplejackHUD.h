// Two meters and nothing else. A third meter is an anti-pillar.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"

#include "SteeplejackHUD.generated.h"

UCLASS()
class ASteeplejackHUD : public AHUD
{
	GENERATED_BODY()

public:
	virtual void DrawHUD() override;
};
