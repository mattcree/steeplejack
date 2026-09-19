# STEEPLEJACK

> *A third-person climbing and industrial-demolition game about the last of the steeplejacks.*

You are a jobbing steeplejack in the industrial North of England, late 1970s. You have a flat cap, a
ladder on the van roof, a bag of steel dogs, a hammer, and a flask of tea. The mills are closing and
their chimneys are coming down — and somebody has to go up there and do it.

**The hook:** you don't *find* a route up the chimney. You **build** it, one ladder at a time, while
hanging off it. Then you do a day's fiddly, dangerous work 90 metres above a town, and climb back
down with your gear.

---

## Read this first

| If you are… | Start here |
|---|---|
| A designer | [`docs/00-vision.md`](docs/00-vision.md) → [`docs/01-gdd/02-climbing-system.md`](docs/01-gdd/02-climbing-system.md) |
| An engineer | [`docs/03-tech/architecture.md`](docs/03-tech/architecture.md) → [`docs/03-tech/adr/`](docs/03-tech/adr/) |
| A producer / lead | [`docs/04-production/mvp.md`](docs/04-production/mvp.md) → [`docs/04-production/work-breakdown.md`](docs/04-production/work-breakdown.md) |
| An artist | [`docs/01-gdd/13-art-direction.md`](docs/01-gdd/13-art-direction.md) |
| A level designer | [`docs/02-levels/LEVEL-TEMPLATE.md`](docs/02-levels/LEVEL-TEMPLATE.md) → [`docs/02-levels/level-index.md`](docs/02-levels/level-index.md) |
| An agent picking up work | [`AGENTS.md`](AGENTS.md) → `make ready` |
| Anyone, on how work actually flows | [`docs/06-workflow/`](docs/06-workflow/00-agent-workflow.md) |

## Status

**M1, the MVP ascent — playable.** The Grey Box (55 m, four bands) can be climbed from the field to
the top with every verb the MVP asks for, in Godot 4.7 over the engine-free sim
([ADR-0006](docs/03-tech/adr/0006-move-to-godot.md)). Grey-box art, a stand-in character, audio
synthesised from envelopes. See [what is and is not in](#what-is-in-the-build).

```bash
make godot-run                      # play it, in a window. Builds first.
make godot-run LEVEL=01-back-yard   # the 12 m tutorial stack instead
make shot                           # a screenshot, headless. See AGENTS.md for posing him.
make check                          # the sim's rules, ~1 s, no engine
make godot-test                     # the real scene, driven and asserted on, ~3 min
```

## How to play

**Get to the top. You can only climb as high as you have built.**

Walk to the **cradle** at the foot of the stack (the timber and the brazier) and take a ladder
section and a bag of dogs. Climb the standing ladder. Look at the brickwork: the joint you are
pointing at is outlined. **Sound it** to hear what it is worth, **drive a dog** into it, and **lash**
the section you are carrying to that dog. Climb what you built. Again.

| Key | On the ground | On the ladder |
|---|---|---|
| **WASD** | walk | W/S climb, A/D shuffle off sideways |
| **mouse** | look | look — and pick the joint you point at |
| **F** | take a ladder and dogs, at the cradle | |
| **E** | | tap the joint: listen, and chalk goes on the wall |
| **right mouse** | | drive a dog into it (right mouse again to back out) |
| &nbsp;&nbsp;**hold / release left mouse** | | draw the hammer / strike. The ring is your margin. |
| **R** | | lash the section you carry to your top dog — then **hold left mouse and go round in circles**; **R** again to tie off. 3 turns is a hitch that walks; 6 is a full lashing. **L** changes the input: circles, tapping, or holding |
| **G** | | lash a gin wheel to a dog in reach; **G** by it to haul a section up from the cradle — **hold W**, mouse against the swing |
| **Q** | | a better stance: leg hooked, clipped on, belted, the chair. Better stances take longer to rig |
| **T** | | brew up — needs both hands, so belt on first |
| **C** / hold **V** | | a cigarette (costs you the top of your nerve for the shift) / look at the view |
| **space** | jump | let go. When grip runs out and a hand comes off, **space** is the grab |
| **Esc** | release the mouse | |

**Grip** (the fast arc) drains while a hand is off the ladder — working, tapping, lashing, hauling —
and comes back when you hold on. At zero a hand comes off. **Nerve** (the slow arc) drains with
height and wind, and at zero you cannot make yourself climb. A stance, a brew, the view, or going down
gets it back.

**The span table is the game.** Dogs more than 4 m apart and the section flexes; more than 6 m and it
sways and hits its dogs harder; more than 8 m and it bows and fails in eight seconds under you. A dog
in bad mortar holds its share of you — until something above it lets go.

## What is in the build

Everything on the MVP's list except where noted: the joint grid from each band's own distribution,
with a visual tell that narrows a joint to about two tiers and a tap that settles it; the hammer's
three axes; lashing by rotation; the gin wheel's pendulum; the ladder stack with spans, flex,
buckling, load sharing and cascading failure; grip, nerve and wobble; all five stances; the slip-save,
the fall and resume-at-stack; wind and gusts with the 1.2 s tell; the climbing, working, hauling, top
and fall cameras; the HUD; fog and a town silhouette; the four tap sounds, the hammer, the wind and the
height mix.

**Not yet:** hand IK onto the rungs (CLIMB-005); the stack saved to disk (CLIMB-006); an options screen
for the accessibility toggles that exist (A11Y-001); the character (ART-020). Each is a task. And
LVL-001 — whether the Grey Box's four bands actually play as four experiences — is a judgement that
needs someone who did not build it to climb it twice.

## The three pillars

1. **Earned altitude** — every metre is something you built and can look back down on.
2. **Craft under pressure** — precise, physical work, done where precise is hard.
3. **Controlled catastrophe** — you spend forty minutes stopping a thing from falling, so you can
   make it fall exactly where you said it would.

## Quick start

```bash
make check                 # the sim: conventions, data, task graph, links, build, tests. ~1 s.
make godot-run             # the game. Needs Godot 4.7 at ~/.local/bin/godot; builds the sim into it.
make godot-test            # the game, headless, every verb driven and asserted on
make shot CMDS="climb 20"  # a rendered frame of him 20 m up. Needs xvfb-run.
```

**Unreal Engine 5.8**, with the gameplay layer split into `SteeplejackSim` — plain C++20 with no
Unreal dependency, which builds standalone under CMake so it can be tested in seconds without the
engine. See [`ADR-0004`](docs/03-tech/adr/0004-engine-change-to-unreal.md), which supersedes
[`ADR-0001`](docs/03-tech/adr/0001-engine-choice.md) (Godot).

Every design document in `docs/01-gdd/` and `docs/02-levels/` is engine-agnostic and survived that
change untouched. That was the point.

## Licence & likeness

This game is inspired by a real, documented trade and by techniques that are matters of public
record. It does **not** use any real person's name, likeness, voice or catchphrases.
See [`docs/05-legal/ip-and-likeness.md`](docs/05-legal/ip-and-likeness.md) — this is binding on all
content work.
