// One live Tuning for the game, loaded once. CORE-007's hot reload swaps it on F5.
#pragma once

#include "Tuning.h"

namespace SteeplejackTuning
{
	const sj::Tuning& Get();
	bool Reload();
}
