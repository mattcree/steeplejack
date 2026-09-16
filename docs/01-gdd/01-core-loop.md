# 01 — Core Loop

## The loops, nested

```
SESSION LOOP (45–90 min)
└── JOB LOOP (10–45 min)  ← the thing that must be fun
    ├── SIZE UP    (1–3 min)   read the structure, mark hazards, choose loadout
    ├── ASCENT     (5–20 min)  ← ANCHOR LOOP repeated
    │   └── ANCHOR LOOP (20–45 s)  ← the atomic unit of the game
    ├── THE WORK   (5–25 min)  ← MISSION LOOP, varies by job type
    ├── DESCENT    (2–6 min)   strike the ladders, recover gear, or abandon and run
    └── RECKONING  (1 min)     fee, bonuses, damages, reputation
└── HUB (2–5 min between jobs)
    ├── spend fee: ladders, dogs, rope, tool repair
    ├── the engine: pour money into a long restoration project
    └── take the next job
```

## The atomic unit: the Anchor Loop

Everything in the ascent is this, repeated, with escalating complication. It must be **20–45 seconds
of unbroken small decisions**. If it is ever a single button press, the game is dead.

```
1. READ      Where does the next ladder go? Scan the brickwork for a sound joint.
             → decision: straight up (safe, slow) or a longer reach (fast, riskier span)
2. TAP       Tap-test the joint with the hammer. Listen. Ring / dull / cracked.
             → decision: trust the tap, or waste 4 seconds testing a second joint
3. STANCE    Set your feet, decide whether to clip your safety line (costs 3s, saves your life)
             → decision: speed vs. survival
4. DOG IN    Hammer the steel dog into the joint. Swing rhythm, angle, depth. Skill expression.
             → outcome: Sound / Fair / Poor anchor, or a bent dog (wasted material)
5. HAUL      Pull the next ladder section up on the gin wheel. It swings. Steer it.
             → decision: haul fast (swings wide, can foul) or slow (burns daylight)
6. LASH      Rope the ladder to the dog. Wrap, tension, frap, tie off.
             → decision: full lashing (10s, solid) or a quick hitch (4s, drifts under load)
7. CLIMB     Transition onto the new section — the most dangerous moment. Grip cost.
```

**Where the decisions bite:** you have finite ladders, finite dogs, finite daylight and a nerve meter
that is draining. Every step above has a fast-and-worse option. The game is the accumulated
consequence of forty small "shall I cut this corner?" decisions, and the top three anchors in your
stack carry 80% of the load, so the corner you cut ten minutes ago is still up there holding you.

## The Ascent Beat Rule

> **A tall climb must present a new complication every 15–20 metres.**

This is the single most important level-design rule in the project. Twenty-eight identical anchor
loops is a chore; twenty-eight anchor loops with seven distinct complications is a journey. Each
chimney is therefore authored in **bands**, and each band changes one variable:

| Band type | What changes |
|---|---|
| **Plain shaft** | baseline — teaches or lets the player breathe |
| **Batter change** | the chimney narrows/steps in; ladders no longer sit flush, need packing |
| **Steel band** | an existing iron band to work around or hook onto (a gift — free anchor) |
| **Perished course** | 3m of rotten mortar; no sound joints, must span it or use a through-bolt |
| **Old fixtures** | a previous jack's rusted dogs. Free, but unrated — gamble |
| **Staging / platform** | a rest point. Nerve recovery, tea, a checkpoint that feels like relief |
| **Nesting ledge** | jackdaws. Startle → nerve hit. Nest blocks a joint |
| **Corbelled cap** | the top flares out — you must climb *underneath an overhang* (the crux) |
| **Lightning tape** | existing copper down the face; grabbing it is tempting and it will tear out |
| **Wind band** | above the shelter of the mill roof; gusts start |

Levels are specified as an ordered list of bands. See the level template.

## The Mission Loop

Whatever "the work" is, it obeys the same shape:

```
SET UP  →  the fiddly bit  →  a complication you didn't plan for  →  clear up
```

The **set-up phase** is where mission types differentiate: rigging a bosun's chair, building a
top scaffold, measuring a circumference, laying out props. It is slow and deliberate and it is
where the player commits to a plan. The **complication** is authored per level, not random: a bolt
shears, the wind turns, the flue jams, the crowd moves.

See [`05-mission-types.md`](05-mission-types.md).

## The Reckoning

End-of-job screen, styled as a handwritten invoice. This is the loop's payoff and its teaching tool.

```
JOB:  Alma Mill, re-banding                              AGREED FEE   £  620
      ────────────────────────────────────────────────────────────────────────
      Completed before dark                              BONUS        £   80
      No damage to third party property                  BONUS        £   50
      Ladders & dogs recovered (11/12 dogs)              MATERIALS    £    0
      One dog left in the wall                           DEDUCT       £  -  0.40
      Greenhouse, one pane                               DEDUCT       £  - 14
      ────────────────────────────────────────────────────────────────────────
                                                         TOTAL        £  735.60
      Reputation  ▲  +3      "Neat job. He'll do."
```

Every line item maps to a decision the player made. **No line item may be opaque.** If the player
loses money they must be able to point at the moment.

## Session shape

A session is 2–4 jobs plus hub time. Jobs are replayable for a better reckoning (and leaderboard-ish
personal bests), but the campaign is linear-ish: reputation gates the bigger stacks.

## What makes the player come back

- **Mastery curve on the verbs.** Your tenth lashing is visibly faster and neater than your first,
  because *you* got better, not because a skill tree unlocked.
- **The engine in the yard.** A long-term restoration project (see [`08-hub-and-meta.md`](08-hub-and-meta.md))
  that consumes money and gives nothing but the pleasure of it slowly becoming whole.
- **The next stack is taller.** The skybox is the progress bar.
