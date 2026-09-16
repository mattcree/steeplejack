# 12 — Audio Design

> Audio is not dressing in this game. It is a **mechanic** (the tap test, the give, the gust tell,
> the groan of a chimney about to go) and it is the **primary height cue**. Budget accordingly:
> audio is ~20% of the project's total craft effort, not 5%.

## Audio as mechanic

| Sound | Tells the player | Must be distinguishable on | Fallback |
|---|---|---|---|
| Tap test ×4 | mortar quality | laptop speakers, mono, low volume | reticle waveform pip |
| The "give" (prise) | release now | any | controller haptic + reticle flash |
| Gust pre-roll | brace / hold breath, 1.2 s warning | any | screen-edge wind streaks |
| Chimney groan (gob) | margin band | any | load diagram colour |
| Brick falling down flue | jam or clear | any | brick counter stalls |
| Anchor creak | that anchor is at >70% capacity | any | pip flickers |
| Rope creak under shock | you nearly lost it | any | — |
| Nut rounding off | stop turning | any | haptic |

**Every mechanical sound has a non-audio fallback.** That's not just accessibility — it's insurance
against players with bad speakers, which is most players.

### The four tap sounds (spec)
Design on envelope, not timbre:

| | Attack | Decay | Content |
|---|---|---|---|
| Sound | sharp, 2 ms | 120 ms | bright, 2–4 kHz emphasis, near-pitched |
| Fair | soft, 8 ms | 200 ms | mid-focused, some body |
| Perished | none, 20 ms | 400 ms | low-passed at 800 Hz, "dead" |
| Cracked | sharp + secondary transient at 40 ms | 250 ms | buzzy, inharmonic rattle |

Record these for real. A hammer, a brick, a bag of sand, a cracked paving slab. Forty minutes of
foley beats forty hours of synthesis.

## Audio as height

The **single most effective and cheapest** way to sell altitude.

```
As height increases (0 → 120 m):
  GROUND AMBIENCE     volume −18 dB, low-pass 20 kHz → 2.5 kHz, reverb wet 0 → 0.35
  WIND                volume −40 dB → 0 dB, spectrum shifts up
  YOUR OWN SOUNDS     unchanged, but reverb tail lengthens (nothing nearby to reflect)
  BIRDS               swifts and jackdaws replace sparrows above ~40 m
  SPATIAL WIDTH       narrows (everything is far away and below)
```

Ground ambience is a **layered bed keyed to the town**: a dog, a train, children in a schoolyard, a
mill hooter, a bus, someone hammering. At the top, these are tiny and beautiful. The player should be
able to *hear* how high they are with their eyes shut.

## Music

Sparse and deployed as punctuation, never as wallpaper.

| Cue | When | Instrumentation |
|---|---|---|
| **Yard** | hub | solo cornet, warm, slightly out of tune |
| **Setting off** | van drives to the job | full brass band, jaunty, 40 s |
| **The ascent** | nothing. Wind and work only. | — |
| **The top** | first time reaching the top of a level | brass, wide, held chords, 60 s |
| **Brew up** | every tea break | 12 s of solo flugelhorn. Same cue every time. It becomes a comfort. |
| **The gob** | act 3 of a felling | a low, slow, single pulsing note that rises in pitch with the margin band. Diegetic-adjacent, horrible, brilliant. |
| **The fall** | act 4 | **silence**, then the fall, then nothing for 6 s, then a single cornet line |
| **Credits** | steaming the engine | full band, the game's theme, finally complete |

The absence of music during the ascent is the most important decision in this table. The ascent is
wind, breathing, hammer, rope, and a distant town. Do not fill it.

## Voice

The character talks to himself. Dry, laconic, affectionate about masonry. Lines are **short, rare,
and never repeat within a session**. Categories:

- Observations on the brickwork ("Somebody's had a go at that and made a mess of it.")
- Reaching the top
- After a slip-save
- On the engine, in the yard
- On the reckoning
- Exactly one line about the chimney being shorter than his ladders (L5)

**Hard rules:** no catchphrases. No impersonation of any real person's voice or delivery. A Northern
English accent is a regional accent, not a likeness. See
[`../05-legal/ip-and-likeness.md`](../05-legal/ip-and-likeness.md).

## Mix

- Ducking: mechanical-signal sounds (tap, give, gust, groan) **always duck everything else by 6 dB**.
  They are information and must never be masked.
- A **"clarity" mix option** in accessibility that boosts these by a further 6 dB and lowers ambience.
- Full 7.1 / binaural support; the fall of a chimney is the only moment that needs it.
