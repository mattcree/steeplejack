# How it was actually done

Notes taken from period sources on the real trade, and what they say about this game. Gathered
2026-09-20 after a playtest note asked two fair questions: *can I build the ladder wrong?* and
*where did the mortar checking come from?*

**Sources.** A 1979 television documentary in which a working Lancashire steeplejack ladders a mill
chimney and narrates every step (captions pulled with `yt-dlp`); a long first-hand account of the
Lancashire trade published on a local-history forum; the National Science and Media Museum's
steeplejack collection notes; and the inquest reporting on the 1882 Newlands Mill collapse.

> **Names.** Rule 16 — no real person's name anywhere in this repo. The people in these sources were
> real and are not named here. What is recorded is the trade, which belongs to nobody.

---

## The laddering procedure, as narrated

1. **Pack the ladder off the wall.** A block of wood is tied to the ladder — with string, *under the
   third rung* — so the ladder stands proud of the brickwork. The reason given is exact: *"so
   there's room for your boots to go through on the rungs."*

   String rather than a bolted iron band, and the reason is economics: when the ladder is hauled up
   the side of a chimney it bangs on things, and *"string is cheaper than brand new ladders."*

2. **Drill a hole, plug it, drive the dog.** The hole goes in the brickwork; a **wooden plug** goes
   in the hole; the **dog** is driven into the plug. Of the depth: *"it don't go in very far, but
   it's quite far enough."*

3. **The lashing** is a rope **about five feet long with a loop spliced on one end**.

4. **Stand the first ladder up and climb it** — *"as though you were going up to clean the bedroom
   window."*

5. **About five feet from the top of that ladder, drill the next hole** — and the instruction is
   explicit: ***"plumb straight above the one below as you can get it."***

6. **Lash the ladder to the bottom dog.** The wrap is described turn by turn: round one cheek of the
   ladder, under the rung, round the dog, round the other cheek, round the rung, back round the rung
   below, and a hitch on. *"That's got it fast, it will not come off."*

   Use up all the rope: in a gale a loose end whips about and the whipping comes off it.

7. **Lash the same ladder to the top dog as well.** Every ladder is held at **two** dogs.

8. **Climb to the top of the ladder, stand on the top rung, reach up and drill the next hole** —
   about five feet above the top of the ladder. The **pulley wheel** is hung on that dog.

9. **Haul the next ladder up** on the pulley, tied on **about nine rungs from the top** — roughly
   midway, which costs about half a ladder of overlap.

10. **Two lashings on the arriving ladder**, and the second is explicitly a **safety redundancy**:
    if the dog carrying the pulley came out, *"I'd still be in with a chance — the ladder would
    still be connected."* Spare dogs ride in the belt; a spare lashing round the neck.

11. Once it is lashed to the dog five feet above the lower ladder, **about six rungs stand in free
    space** above that, unconnected to the chimney.

12. **Move the pulley up** — carried up the *back* of the ladder — and repeat.

### Two things the narration says that are not procedure

- **On depth:** *"as you get a bit higher up, the holes have a tendency to get a bit deeper. I think
  it's called fear."* The man drives them deeper when he is frightened, and knows he does.
- **On wind:** three-quarters of the way up, with the wind trying to snap a loose ladder sideways,
  is called *"quite exciting."*

### And one on craft

Keeping the stack **straight** is part of the job, not an accident of it. Wander to one side on the
way up and *"you've got one ladder that's maybe two foot gone a bit sideways and the other's gone
the other way — it looks rather an erratic effort at the top, everything's out of line and out of
square."*

---

## What this says about the build

### Fixed on the strength of it

**Dogs were driven off to one side of the ladder they hold up.** `face.under_ladder()` excluded
joints by how far round the face they were and never by height, so a joint on the climbing line was
hidden at *every* height — including above the top of the ladder, which is the one place a dog
actually goes. Every dog in the game was therefore pushed 0.3–0.5 m sideways from the ladder it was
about to be lashed to. Measured after the fix: 49 joints offerable above the ladder top, minimum
lateral offset 0.00 m. Dogs go plumb now, as the trade says they must.

### Open, and design's to decide — not implementation's

| | The trade | The game |
|---|---|---|
| **Dog spacing** | **five feet** (1.5 m), every time | `next_dog_band()` suggests 2.5–6.0 m; `spanWarnMetres` 6.0 |
| **Lashings per ladder** | **two** — bottom dog and top dog, and one dog splices two ladders | one |
| **Getting the ladder up** | **always the pulley**, leapfrogged up the stack | carried on the back; the gin wheel is optional |
| **The dog itself** | hole → **wooden plug** → dog driven into the plug | dog driven straight into the mortar |
| **Packing** | a block under the third rung holds the ladder off the wall *so boots fit on the rungs* | not modelled — though the drawn body's standoff is doing the same job by accident |
| **Redundancy** | a **second lashing** explicitly in case the first dog pulls | none; one dog failing is the cascade |

The spacing gap is the big one. At five feet a 55 m chimney wants ~36 dogs; the game's own
reachability gate assumes far fewer, and the whole span economy — Rigid / Flex / Sway / Buckle at
4 / 6 / 8 m — is built around spans the trade would never take. **That is a design decision, not a
bug**: a faithful 1.5 m spacing would make the ascent four times as many actions, and whether that
is tedium or texture is a judgement nobody here should make alone. Recorded in `BLOCKED.md`.

---

## Where the mortar checking came from

The playtest note asked. It came with the project: the tap test is in `bef6e24`, the **initial
design documentation** commit, and is specified in
[`02-climbing-system.md`](02-climbing-system.md) with its four tiers, its four sounds and its chalk
marks. Nothing about it was invented later.

**Is it true?** Partly, and the parts are worth separating.

- **Sounding masonry by tapping it is a real and current technique.** A hollow or dead note means a
  void, a debonded face or perished mortar. Surveyors still do it with a hammer.
- **Judging a fixing by the material you are driving into is real**, and the narration shows it:
  the hole is chosen in the brickwork, plugged, and the dog driven — a man who found soft mortar
  would move.
- **The 1882 Newlands Mill inquest** records the most direct version of the test there is. Men
  inspecting the bulge before it fell found that stones in one part *could be pulled out by hand*
  while another was too tight to move. That is a hand test on a structure about to kill fifty-four
  people.
- **What is invented** is the resolution: four crisp tiers, a chalk mark per joint, and a sound that
  reliably distinguishes them. A real jack forms a judgement, not a reading. The game makes the
  judgement legible because a player cannot feel a hammer — the same compromise the plumb bob and
  the margin readout make.

So: the mechanic is a fair abstraction of a real practice, and the game is honest about being an
abstraction. What it should probably also model, and does not, is the **wooden plug** — because in
the trade the dog's hold comes from the plug as much as from the mortar, and that is a second thing
to get right or wrong.
