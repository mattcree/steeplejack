# Playtest Plan

Playtesting is how this project's central question gets answered. It is scheduled work with named
owners, not something that happens if there's time.

## Principles

1. **Say nothing.** The facilitator's only line is the goal ("get to the top"). Every word of help
   is a data point about a missing telegraph.
2. **Watch hands and face, not the screen.** The screen is recorded; the reaction is not.
3. **Score numerically against pre-written criteria.** "It felt good" is not a result.
4. **Use the replay logs.** Every session ships a `.replay`. Watch the interesting ones back.
5. **Never playtest without audio.** Four mechanics live there.
6. **One question per test.** A test that asks five questions answers none.

## Schedule

| Test | Milestone | n | Length | The one question |
|---|---|---|---|---|
| PT-001 | M1 | 8 strangers | 30 min | **Is climbing fun on its own?** |
| PT-002 | M2 | 8 strangers | 45 min | Is a *job* better than a climb? |
| PT-003 | M3 | 15+ external | 90 min | Would you buy this? |
| PT-004 | M4 | 10 | 60 min | Does the fall land? |
| PT-005 | M5 | 8, full campaign | 8 hours over 2 sessions | Does it hold for eight hours? |
| PT-006 | M6 | 6, accessibility-focused | 60 min | Can everyone play it? |

---

## PT-001 — The one that matters

**Setup:** grey box, 55 m chimney, empty field, no mission, no UI beyond the HUD. Headphones,
mandatory. Screen + face + hands recorded. One facilitator, silent.

**Script:** *"This is a game about a steeplejack. Get to the top. I'm not going to help you."*

**Measure:**

| # | Criterion | How measured | Pass |
|---|---|---|---|
| 1 | The top means something | facilitator marks any audible/visible reaction at summit | ≥ 6/8 |
| 2 | The loop holds | count tap-tests at anchors 1–3 vs. 9–12 | rate does not fall > 40% |
| 3 | Failures are legible | after each fall: "what happened?" | 100% correct |
| 4 | Risk is tempting | replay log: any span in [4, 6] m | ≥ 4/8 |
| 5 | The verbs have a curve | replay log: time & rating of anchor 2 vs. anchor 10 | ≥ 6/8 improve on both |
| 6 | Satisfying | exit survey, 1–5 | ≥ 6/8 score ≥ 4 |
| 7 | Nobody is confused | count facilitator interventions after anchor 2 | 0 |

**Also record (uninstrumented but noted):**
- Time to first successful anchor
- Whether anyone discovers the stance system without being told
- Whether anyone looks down deliberately
- Whether anyone slides down for fun
- The exact words used at the top

**Exit survey (5 questions, no more):**
1. How satisfying was that, 1–5?
2. What were you thinking about while climbing?
3. Describe a moment you felt in danger.
4. If you fell: why did you fall?
5. Would you want to do a harder one?

Question 2 is the important one. If the answers are about *the brickwork, the spans, the ladders and
the weather*, the game works. If the answers are about *the buttons*, it doesn't.

---

## PT-003 — External, M3

Fifteen-plus players, 90 minutes, Levels 01–04, remote or in-person, recorded.

**Targets:** ≥ 70% complete all four levels · ≥ 60% "would buy" · ≥ 3 mention the tea break
unprompted · median session length ≥ 75 min · vertigo complaints ≤ 2/15.

**Add to the survey:** motion comfort (explicit), which level was best and why, what they thought
the game was "about".

---

## PT-004 — The fall, M4

Ten players, Level 06 only.

| Criterion | Pass |
|---|---|
| Player predicts the fall direction before lighting it | ≥ 8/10 within 15° |
| Player understands *why* their angular error was what it was | ≥ 8/10 |
| Audible reaction at the moment of collapse | ≥ 8/10 |
| Player wants to immediately do another one | ≥ 7/10 |
| Anyone killed by premature collapse without a run window | **0/10 — a blocker if it happens** |

---

## PT-006 — Accessibility, M6

Six players recruited specifically: at least one d/Deaf or hard-of-hearing, one with a motor
impairment, one colour-blind, one who reports motion sensitivity, one using a screen magnifier.

Not a survey — a **task completion test**. Can each player complete Level 02 with the assists they
need? Every failure is a bug with a task ID, not a "known limitation".

---

## Telemetry (from M3, opt-in, anonymous)

Small and purposeful. Every field must answer a design question someone actually has.

| Field | Answers |
|---|---|
| span distribution per level | is risk tempting? (R1) |
| anchor rating distribution | is the player reading the brickwork? |
| taps per anchor, over time | is the mastery curve real? |
| falls per level + cause | is difficulty where we think it is? |
| shift time remaining at completion | is the daylight pressure right? |
| tea breaks per shift | do people use the thing we love? |
| level abandonment point | where does it break? |
| angular error distribution (fellings) | is felling readable? |
| accessibility options enabled | which assists actually matter? |

**Not collected:** anything identifying, anything about the player's machine beyond a GPU tier
bucket, anything we don't have a specific question for.

## Writing it up

Each test produces one page in `docs/04-production/playtests/PT-NNN.md`:
criteria table with numbers, three things that surprised us, and **a list of task IDs created**.
A playtest that creates no tasks was not a playtest.
