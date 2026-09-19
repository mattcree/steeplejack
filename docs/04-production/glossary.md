# Glossary

Shared vocabulary. Use these words in code, docs, commits and conversation. If you need a new one,
add it here in the same PR.

## The trade

| Term | Meaning |
|---|---|
| **Steeplejack** | someone who climbs and repairs tall structures without scaffolding |
| **Dog** | a forged steel spike with a lug, driven into a mortar joint. The game's anchor. |
| **Dogging in** | driving a dog |
| **Lashing** | rope binding a ladder to a dog. A *frapping turn* tightens it. |
| **Gin wheel** | a simple pulley for hauling material up |
| **Bosun's chair** | a plank on ropes you sit in to work suspended |
| **Gob** | the hole cut in the base of a chimney before felling |
| **Prop** | a timber post supporting the chimney over the gob. Burns. |
| **Felling** | bringing a chimney down in one piece by burning the props |
| **Topping** | taking a chimney down by hand from the top |
| **Coping / cap** | the (usually corbelled, oversailing) top courses of a chimney |
| **Batter** | the taper of a chimney; a *batter change* is a step in the profile |
| **Course** | one horizontal layer of bricks |
| **Perished** | mortar that has gone soft and sandy |
| **Spalling** | brick faces splitting off |
| **Efflorescence / salt bloom** | white salt deposits; makes sound mortar look perished |
| **Repointing** | raking out and replacing mortar in joints |
| **Putlog** | a horizontal scaffold member |
| **Staging** | the timber platform built round a chimney top |
| **Flue** | the shaft up the middle. Bricks go down it. |
| **Air terminal** | the spike at the top of a lightning conductor |
| **Star drill** | a hand drill for masonry, struck and rotated |

## The game

| Term | Meaning |
|---|---|
| **Anchor loop** | the 20–45 s atomic unit: read, tap, stance, dog in, haul, lash, climb |
| **Ascent Beat Rule** | a new complication every 15–20 m. Enforced by the level validator. |
| **Band** | a height range of a structure with a distinct character (`plain`, `perished`, `ivy`…) |
| **Span** | the distance between consecutive anchors. The core risk/reward number. |
| **Stack** | the player's ladder route. Also the checkpoint. |
| **Grip** | the short meter. Your forearms. Seconds. |
| **Nerve** | the long meter. Exposure. Minutes to hours. |
| **Wobble** | the one number every skill verb reads. Fed by grip, nerve, stance and wind. |
| **Stance** | how you're holding on. Five of them. The difficulty dial. |
| **Slip-save** | a 900 ms window to catch yourself. One per 60 s. |
| **The give** | the release point in the prise verb. Audible, not visual. |
| **Tap test** | striking a joint and listening. The game's signature action. |
| **Tell** | a telegraph. The gust's 1.2 s audio pre-roll is *the* tell. |
| **The reckoning** | the end-of-job itemised invoice |
| **Margin** | distance from the centre of gravity to the edge of the support polygon |
| **Fall line** | the direction the player pegs out before felling |
| **Debris fan** | the predicted spread of rubble |
| **Brew up** | the tea break. A 12 s nerve-recovery set-piece. |
| **The engine** | the traction engine in the yard. The money sink. The point. |
| **The lad** | an optional apprentice who hauls for you and isn't very good |

## Engineering

| Term | Meaning |
|---|---|
| **sim / presentation split** | ADR-0003. `SteeplejackSim` is pure C++ with no engine; the Godot game (`godot/`, through the `Jack` binding) renders it. |
| **Intent** | a player action sent from presentation into the sim |
| **Replay** | seed + tuning hash + intent log. Reproduces a whole job. |
| **Tick** | one fixed sim step, 1/60 s |
| **Reachability solver** | headless check that a level's top can actually be reached |
| **The standalone build** | `SteeplejackSim` compiled by CMake with no engine present. The thing that keeps the gameplay layer fast and agent-editable. |
| **The editor queue** | `editor_required` tasks a human must do in an art or animation tool. Risk R8's gauge. |
| **Pre-fracture** | baked chunk decomposition for a fellable structure (planned; the Godot mechanism is not chosen yet) |
| **Hinge solver** | `Fell.h` — the deterministic fall |
| **Cell** | one removable unit of the gob or topping grid |
| **Cascade** | progressive anchor failure down the stack |

## Words we don't use

| Don't say | Say |
|---|---|
| health / damage | grip, nerve, injury |
| stamina | grip |
| XP / skill tree / levelling up | (there isn't one — equipment and knowledge only) |
| enemy / hazard | there are no enemies. Gravity, weather, material, clock. |
| checkpoint | the stack |
| quest / objective marker | job, briefing |
| minigame | verb |
| the real person's name | see `docs/05-legal/ip-and-likeness.md` |
