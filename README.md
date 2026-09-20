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
make godot-run                      # play it: the job board, and both halves from there
make godot-run LEVEL=01-back-yard   # straight onto the 12 m tutorial stack
make fell                           # straight into a felling, skipping the board
make shot                           # a screenshot, headless. See AGENTS.md for posing him.
make check                          # the sim's rules, ~1 s, no engine
make godot-test                     # the real scene, driven and asserted on, ~3 min
```

## The two halves

`make run` opens a **job board**: the letters that have come in, what each pays, and what anyone
thinks of you so far. Taking a job starts the half of the game it belongs to, and finishing it puts
money in the tin and moves your name. What you have earned decides which letters arrive.

* **SURVEY jobs — you climb it.** Get to the top. You can only climb as high as you have built.
* **FELL jobs — you take it down.** Walk the site, read the lean, cut a hole in one side of the
  base, prop it as you go, peg the line, pack it, light it and run.

## How to play: the climb

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
| **F1** | options — volume, and motion and vertigo: sway, head bob, FOV, look-down, shake, the fall | same |
| **Esc** | release the mouse | |

**Grip** (the fast arc) drains while a hand is off the ladder — working, tapping, lashing, hauling —
and comes back when you hold on. At zero a hand comes off. **Nerve** (the slow arc) drains with
height and wind, and at zero you cannot make yourself climb. A stance, a brew, the view, or going down
gets it back.

**The span table is the game.** Dogs more than 4 m apart and the section flexes; more than 6 m and it
sways and hits its dogs harder; more than 8 m and it bows and fails in eight seconds under you. A dog
in bad mortar holds its share of you — until something above it lets go.

**The joint you point at is captioned** with what the brick shows (clean, weathered, salt bloom,
cracked) and, once you have tapped it, what it sounded like. The eye can be wrong about a joint and
the tap is not: that is the point of tapping.

**Your stack is the save.** Quit halfway up and the ladders you lashed are still there next time,
with you at the foot of them and a fresh shift. Reaching the top clears it. To start a job over,
run with `-- --fresh`.

## How to play: the felling

**Drop it down the corridor, and do not hit the chapel.** `make fell`, or take one off the board.

| Key | |
|---|---|
| **WASD** | walk the site — hold **shift** to run |
| **mouse** | look; the crosshair picks the cell of brickwork you are pointing at |
| **B** | read the lean with the plumb bob. Twice, from at least 55° apart, or you are guessing |
| **P** / **R** | drive a peg where you stand (two of them make the fall line) / pull them up |
| **[** and **]** | take metres off the top by hand: a tighter cone, and less of your daylight |
| **left mouse** / **E** | cut the cell you are pointing at out of the ring |
| **right mouse** / **Q** | stand a prop at that segment — **before** the last course comes out |
| **hold F** | pack the gob with waste timber. A full one burns clean; a light one smoulders |
| **L** | strike a match. Put yourself between the wind and the gob or it will have it |
| **enter** / **esc** | back to the board |

It stands while its centre of gravity is inside what is still holding it up. The plan view bottom
right draws that polygon — the sim's own, not a picture of it — and the **margin** is the distance
from the weight to the nearest edge of it. Finish **UNEASY**, not SAFE: a chimney that feels safe
will not fall.

Brickwork arches over the hole, which is the only reason a 40 kN prop is any use under a thousand
tons. What a prop carries is the wall directly above it, about five metres of it. One unpropped
hole beside a prop takes it to 33 kN and it stands; two takes it to 44 and it splits, and its load
goes to the next one. **You may run one segment ahead of your props. You may not run two.**

## What is in the build

Everything on the MVP's list except where noted: the joint grid from each band's own distribution,
with a visual tell that narrows a joint to about two tiers and a tap that settles it; the hammer's
three axes; lashing by rotation; the gin wheel's pendulum; the ladder stack with spans, flex,
buckling, load sharing and cascading failure; grip, nerve and wobble; all five stances; the slip-save,
the fall and resume-at-stack; wind and gusts with the 1.2 s tell; the climbing, working, hauling, top
and fall cameras; the HUD; fog and a town silhouette; the four tap sounds, the hammer, the wind and the
height mix.

And the demolition half: the gob's statics, the fall, three felling levels (Waterside, Kershaw's
Yard, the Great Aire Chimney), the survey, the shift the job costs you, the fire-and-run, and a
career that carries money and reputation between jobs and decides which letters arrive.

**Not yet:** the character (ART-020), and the strip-out that should join the two halves — a felling
level has ascent bands and an Act 2 that you currently skip, which is the largest single gap in the
game. The CONDUCTOR, GILD, BAND and TOP jobs are designed and not built, so levels 2 to 5 and 8 to
11 have no data: there would be nothing to do on them but climb. LVL-001 — whether the Grey Box's
four bands actually play as four experiences — is a judgement that needs someone who did not build
it to climb it twice.

## The three pillars

1. **Earned altitude** — every metre is something you built and can look back down on.
2. **Craft under pressure** — precise, physical work, done where precise is hard.
3. **Controlled catastrophe** — you spend forty minutes stopping a thing from falling, so you can
   make it fall exactly where you said it would.

## Quick start

```bash
git lfs install            # once per machine. Binary assets are pointers without it.
make check                 # the sim: conventions, data, task graph, links, build, tests. ~1 s.
make run                   # the game — the job board. Needs Godot 4.7 at ~/.local/bin/godot.
make godot-test            # the game, headless, every verb driven and asserted on
make fell                  # the demolition mode: cut the gob, prop it, peg the line, light it
make shot CMDS="climb 20"  # a rendered frame of him 20 m up. Needs xvfb-run.
```

**Godot 4**, with the gameplay layer split into `SteeplejackSim`: plain C++20 with no engine
dependency, which builds standalone under CMake so it can be tested in seconds, and which the game
loads as a GDExtension. See [`ADR-0006`](docs/03-tech/adr/0006-move-to-godot.md). The project spent
a while on Unreal ([`ADR-0004`](docs/03-tech/adr/0004-engine-change-to-unreal.md)); that is over,
and the Unreal code is gone from the repository.

Every design document in `docs/01-gdd/` and `docs/02-levels/` is engine-agnostic and survived that
change untouched. That was the point.

## Licence & likeness

This game is inspired by a real, documented trade and by techniques that are matters of public
record. It does **not** use any real person's name, likeness, voice or catchphrases.
See [`docs/05-legal/ip-and-likeness.md`](docs/05-legal/ip-and-likeness.md) — this is binding on all
content work.
