# 15 — Working the Face

How the verbs look and feel **on the wall**. The mechanics are specified elsewhere —
[§1 of the climbing system](02-climbing-system.md#1-reading-the-brickwork) for joints,
[`04-tools-and-verbs.md`](04-tools-and-verbs.md) for tap, dog-in and lash,
[`11-camera-controls-feel.md`](11-camera-controls-feel.md) for the hammer's feel. This document is the
connective tissue between them: what the player is pointing at, how they know, and where every
result lands.

It exists because the first playable build got all the rules right and none of this. Pressing the
tap key changed a number and printed a line of text; nothing on screen happened at the joint, no
joint could be seen, and the reticle for driving a dog floated in the middle of the screen attached
to nothing. Every verb was correct and invisible.

## The principle

> **Every verb acts on a thing you can see, and its result stays on that thing.**

Not in a HUD panel, not in a message line. On the brick.

## 1. You can see the joints

The working face — a band of brickwork around the player, about 3 m tall and 2.5 m either side of
the ladder — is drawn as **courses of brick with their mortar joints**, and every candidate joint
shows its **visual tell**:

| Tier | What it looks like |
|---|---|
| Sound | a crisp, thin, even joint, flush with the face |
| Fair | a slightly wider joint, darker, a little eroded |
| Perished | recessed and sandy, with a pale salt bloom around it |
| Cracked | a hairline running out of the joint into the brick either side |

**The tell is a reading, not the answer.** It is drawn from the joint's quality *plus a fixed
per-joint error*, sized so that from a working position the player can narrow a joint to about two
tiers — exactly the uncertainty §1 asks for ("from 3 m the player can narrow it to two tiers; only
the tap test disambiguates"). The error is deterministic: the same joint always looks the same, so
looking again is not a reroll. It lives in the sim, because it decides what information the player
had, and the [fairness contract](10-failure-and-difficulty.md#the-fairness-contract) is written in
terms of exactly that.

Brick elsewhere on the stack is not drawn joint by joint. From 2 m you read mortar; from 20 m you
read bands.

## 2. You are always pointing at one joint

While on the ladder, **one joint is targeted**: the candidate joint within reach
(`tapTestMaxRangeMetres`) nearest to where the camera is looking. It is outlined on the wall, in
place. Moving the mouse moves the target; there is no mode to enter to aim.

Everything acts on the targeted joint:

- **E** taps it.
- **Right mouse** starts driving a dog into it.
- The reticle for the hammer is drawn **on it**, in world space, not in the middle of the screen.

No joint in reach — you are between courses, or the ones near you are all occupied — means no
target, and the affordance row says so.

## 3. Tapping

The hammer taps the joint. What the player gets, in order, inside 0.8 s:

1. **His arm moves.** A short wrist strike at the joint. Snappy — this is the action they will do
   hundreds of times.
2. **A puff of mortar dust** at the joint, on contact.
3. **The sound** — the mechanic itself ([`12-audio-design.md`](12-audio-design.md)).
4. **The pip**, drawn at the joint on screen: one of four shapes, never a colour
   ([accessibility](14-accessibility.md)).
5. **A chalk mark** on the brick beside the joint, which stays.

The chalk mark is the part that makes tapping a *skill* rather than a lookup. Tapped joints keep
their mark for the rest of the shift, in the one accent colour the art direction reserves for the
player's own work — chalk white-blue `#DCE8F0`, "the player's intentions remain the only bright
thing in the world" ([`13-art-direction.md`](13-art-direction.md)). A tick for sound, a stroke for
fair, a cross for perished or cracked. The marks are *shapes*, for the same reason the pip is. The
player reads their own survey of the face as they climb it, and the stack below them ends up
annotated with every decision they made.

## 4. Driving a dog

Right mouse on a targeted joint. The camera pulls in to 1.4 m and settles on the joint — the only
time the game takes the camera, and it gives it back on exit (camera rule 1: never move it
mid-verb, so it moves *before* the verb, not during).

- The **dog is visible at the joint** from the first blow, and **sinks** with each one. The depth bar
  is a fallback; the dog in the wall is the reading.
- The hammer reticle is drawn over the joint and drifts with wobble (the one number both meters
  feed).
- Drawing back raises the hammer; releasing brings it down. Contact gets the feel list from
  [camera and feel §3](11-camera-controls-feel.md#feel--the-non-negotiables): a hard impact frame, a
  2 px screen impulse, a dust puff, the transient.
- A **bent** dog stays in the wall, visibly bent, for the rest of the shift. Wasted material should be
  something you can look at.
- A **seated** dog stays as a fixture with its lug proud of the face, and its rating is marked in
  chalk beside it the same way a tap is: you can count your good anchors on the way down.

## 5. What is deliberately not here

- **No highlight of good joints.** The target outline is the same for every tier. The game shows you
  where you are pointing, never what you should pick.
- **No text on the wall.** Chalk marks are shapes. Numbers belong in the HUD, and even there they are
  a fallback.
- **No auto-targeting to the best joint in reach.** Choosing is the skill.

## Open

- Chalk marks and glove resolution: gloves cost a tier of resolution on the tap
  ([VERB-001](../../tasks/VERB-001.md)). Should the chalk mark then record the *coarser* reading? It
  should — a mark records what the player learned, not what is true — but that is a design call and
  it is written down here rather than decided.
