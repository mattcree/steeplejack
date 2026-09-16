# MVP

## The question the MVP answers

> **Is climbing a chimney, by building your own route up it, fun on its own — with no mission, no
> art, and no story?**

If the answer is yes, this game works and everything else is execution. If the answer is no, no
amount of felling, gilding or brass bands will save it. **So the MVP contains no missions.**

This is deliberately narrower than a normal vertical slice, and it is the correct narrowness.

---

## MVP scope — "The Ascent"

**One grey-box 55 m chimney in an empty field. Climb it. That's the whole build.**

### In scope

| System | Detail |
|---|---|
| Fixed-step sim core + intent recording | ADR-0003. Everything depends on it. |
| Procedural chimney from a level JSON | one profile (round), four band types |
| Joint grid + four quality tiers | with the four tap sounds |
| Tap-test verb | audio + reticle pip |
| Dog-in verb | full 3-axis hammer (power, angle, depth), ratings, bent dogs |
| Lash verb | quick hitch vs. full lashing |
| Haul verb | gin wheel, pendulum, swing/foul |
| Ladder stack | spans, flex shader, load sharing, cascade failure |
| Climb / slide-down | with hand IK |
| Grip + nerve + wobble | all three, fully tuned from JSON |
| Stances | all five |
| Slip-save + fall | fall cuts to black; restart resumes at the stack |
| Wind + one gust with its 1.2 s tell | |
| Camera set | climb, work, haul (looks down the rope), top, fall |
| Minimal HUD | grip/nerve arcs, anchor pips, material counts |
| Grey-box art | untextured, flat-shaded, **but with correct fog and a placeholder town silhouette** |
| Audio | taps ×4, hammer, rope, wind, height mix, breathing. **Not optional.** |
| Headless test harness | unit tests, replay regression, reachability validator |

### Explicitly out of scope

- Any mission (no conductor, no gilding, no banding, no topping, no **felling**)
- The hub, the van, the loadout screen, the engine, money, reputation
- Any other level
- Textures, character model detail, animation polish beyond hand IK
- Music, voice
- Options menus beyond the accessibility toggles needed to play
- Save/load beyond the in-progress stack

### The one piece of art we do build
**Fog and a town silhouette.** Because "is the height impressive?" is half the question being asked,
and grey-box-with-no-atmosphere would answer it dishonestly. One directional light, height fog, a
distance-faded block silhouette of a town, and correct audio falloff. Two days of work that make the
test valid.

---

## MVP success criteria

Hand it to **eight people who have never seen it**. Say nothing except "get to the top."

| # | Criterion | Pass condition |
|---|---|---|
| 1 | **The top means something** | ≥ 6 of 8 have a visible or audible reaction on reaching the top |
| 2 | **The loop holds** | ≥ 6 of 8 are still engaged at anchor #10 (measure: do they still tap-test?) |
| 3 | **Failures are legible** | 100% of falls are explained correctly by the player when asked "what happened?" |
| 4 | **Risk is tempting** | ≥ 4 of 8 voluntarily take a span in the 4–6 m warning band |
| 5 | **The verbs have a curve** | anchor #10 is placed measurably faster and better-rated than anchor #2, for ≥ 6 of 8 |
| 6 | **It feels like work, not chores** | ≥ 6 of 8 answer ≥ 4/5 to "did that feel satisfying?" |
| 7 | **Nobody is confused** | zero players need verbal help after the first two anchors |

### If we fail

| Failed criterion | Most likely cause | First thing to try |
|---|---|---|
| 1 | atmosphere, camera, or audio height mix | fix the top camera and the ground-ambience falloff before anything else |
| 2 | the anchor loop is too long | **cut seconds, not steps.** Target 20 s, not 45 s. |
| 3 | telegraphs missing | audit every failure against the fairness contract |
| 4 | the reward for speed is too weak | tighten shift pressure; it doesn't exist in MVP, so add a soft one |
| 5 | the hammer has no skill ceiling | this is the most dangerous failure; revisit the 3-axis model |
| 6 | the verbs don't feel physical | hammer impact frames, IK, audio transients — in that order |
| 7 | too many systems at once | delay hauling to after anchor #4 |

**Do not proceed to M2 without passing 1, 2, 3 and 5.** Criteria 4 and 6 can be fixed in M2. If 1 or
5 fails twice, stop the project and rethink.

---

## After the MVP: the "First Job" build (M2)

The second-smallest useful thing: **MVP + Level 02 (Sweeper's Row) end to end.** Conductor mission,
daylight clock, the storm, the reckoning screen, fall consequences. That is the first build that is
recognisably *the game*, and it is what goes to external playtest at M3.

## What the MVP is not

It is not a demo, it is not shippable, it has no story, and it should never be shown to anyone
outside the team as "the game". It is an experiment with a hypothesis and a pass/fail condition.
