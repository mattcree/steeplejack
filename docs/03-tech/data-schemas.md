# Data Schemas

Everything that can be data, is data. A level designer never opens a code file; an engineer never
edits a balance number.

JSON Schema files live in `data/schemas/` and are validated in CI by `tests/validate_levels.gd`.

## Level file

`data/levels/NN-slug.json`

```jsonc
{
  "$schema": "../schemas/level.schema.json",
  "id": "06-waterside",
  "name": "Waterside Bleachworks",
  "order": 6,
  "archetype": "FELL",                    // SURVEY CONDUCTOR GILD BAND TOP FELL MECHANISM LATTICE
  "reputationGate": 3,
  "fee": 1100,
  "shiftMinutes": 120,
  "targetMinutes": 95,

  "structure": {
    "type": "chimney",                    // chimney | spire | tower | lattice | concrete
    "height": 70.0,
    "baseRadius": 3.2,
    "topRadius": 1.9,
    "profile": "round",                   // round | octagonal | square | square-to-round
    "batter": [ { "at": 0.0, "step": 0.0 } ],
    "bands":  [ { "at": 36, "type": "iron" }, { "at": 48, "type": "iron" } ],
    "cap": "corbelled-oversail",
    "leanDegrees": 0.3,
    "leanBearing": 284,
    "jointGrid": { "courseHeight": 0.075, "brickLength": 0.225, "candidateDensity": 4.0 },
    "weathering": { "sootTo": 0.25, "bleachFrom": 0.75, "seed": 4471 }
  },

  // ORDERED, ground to top. Enforces the Ascent Beat Rule.
  "bands": [
    { "from": 0,  "to": 18, "type": "plain",        "quality": { "sound": 0.6, "fair": 0.3, "perished": 0.1, "cracked": 0.0 } },
    { "from": 18, "to": 36, "type": "ivy",          "quality": { "sound": 0.5, "fair": 0.4, "perished": 0.1, "cracked": 0.0 },
      "params": { "clearTimeSeconds": 3.0 } },
    { "from": 36, "to": 52, "type": "existing-band","quality": { "sound": 0.6, "fair": 0.3, "perished": 0.1, "cracked": 0.0 },
      "params": { "freeAnchors": [36.0, 48.0], "freeAnchorRating": 3 } },
    { "from": 52, "to": 70, "type": "plain",        "quality": { "sound": 0.55, "fair": 0.35, "perished": 0.1, "cracked": 0.0 } }
  ],

  "weather": {
    "windBase": 4.0,
    "windAtHeight": [ [0, 1.0], [40, 1.6], [70, 2.1] ],   // multiplier curve
    "gustIntervalSeconds": null,
    "precipitation": "none",
    "ramp": null            // or { "startPct": 0.7, "windTo": 18.0, "precipitationTo": "rain" }
  },

  "site": {
    "safeLineDistance": 105,
    "exclusions": [
      { "id": "pump_house",   "bearing": 92,  "distance": 30, "value": 180, "catastrophic": false },
      { "id": "boundary_wall","bearing": 138, "distance": 45, "value": 60,  "catastrophic": false }
    ],
    "corridor": { "fromBearing": 250, "toBearing": 320 },
    "crowd": null,
    "backdrop": "mill-town-river"
  },

  "mission": {
    "type": "FELL",
    "requiredHeightReduction": 0,
    "stripOut": ["bands", "conductor"],
    "gob": {
      "segments": 32, "courses": 4,
      "mortarAsymmetry": null,
      "props": 14,
      "dudPropIndex": null,
      "packingQualityMatters": true
    }
  },

  "complications": [
    { "at": "gob:0.6", "type": "groan-intensify" }
  ],

  "scoring": {
    "bonuses": [
      { "id": "accuracy_5",  "condition": "angularError<=5",  "amount": 400 },
      { "id": "accuracy_15", "condition": "angularError<=15", "amount": 150 },
      { "id": "clean_break", "condition": "fractureCount>=3 and fractureCount<=4", "amount": 80 },
      { "id": "no_collateral", "condition": "collateralValue==0", "amount": 120 },
      { "id": "before_dark", "condition": "shiftRemaining>0", "amount": 50 }
    ],
    "hardFailConditions": []
  },

  "loadoutHint": { "ladders": 18, "dogs": 40 },
  "replay": "data/replays/06-waterside-expert.replay"
}
```

### Band types (enum)
`plain` `batter-change` `existing-band` `perished` `old-fixtures` `staging` `nesting-ledge`
`corbelled-cap` `lightning-tape` `wind-band` `ivy` `salt-bloom` `crack` `hot` `internal`
`delaminated` `corroded-steel` `lattice-open` `lattice-pinch`

Each band type maps to a generator in `sim/joints.gd` and a visual treatment in the brick shader.
**Adding a band type is a pull request that touches exactly two files.**

### Validation rules (enforced in CI)
1. Bands must be contiguous and cover `[0, height]` with no gaps or overlaps.
2. **Ascent Beat Rule:** no `plain` band may exceed 20 m.
3. Quality distributions must sum to 1.0.
4. **Reachability:** a headless solver must find a route to the top using ≤ `loadoutHint.ladders`
   sections at spans ≤ 6.0 m.
5. `exclusions[].bearing` must not fall inside `corridor` (that would be an unwinnable felling).
6. Every `scoring.bonuses[].condition` must parse and reference only known job-record fields.
7. `replay` must exist and must produce a passing invoice.

## Tuning files

`data/tuning/climbing.json`, `meters.json`, `topping.json`, `felling.json`, `economy.json`.

Flat key/value only. Every constant referenced in `docs/01-gdd/` appears here. Hot-reloaded in
dev builds with `F5` so a designer can rebalance while playing.

```jsonc
// data/tuning/meters.json
{
  "gripMax": 100.0,
  "gripRecoverPerSecond": 25.0,
  "gripDrain": { "oneHand": 8.0, "hookedLeg": 4.0, "clipped": 4.0, "belted": 1.0, "chair": 0.0 },
  "gripTremorThreshold": 20.0,
  "nerveStart": 90.0,
  "nerveBaseDrainPerSecond": 0.15,
  "nerveHeightRef": 40.0, "nerveHeightMin": 0.25, "nerveHeightMax": 3.0,
  "nerveWindRef": 15.0,
  "exposureFactor": { "platform": 1.0, "ladder": 1.4, "hanging": 1.8, "overhang": 2.2 },
  "nerveShock": { "droppedTool": -10, "slipSave": -25, "anchorFail": -30, "startle": -8, "haulHit": -20 },
  "teaRecover": 40.0, "teaSeconds": 12.0,
  "cigaretteRecover": 18.0, "cigaretteSeconds": 6.0, "cigaretteMaxPenalty": -5.0,
  "viewRecover": 12.0, "viewSeconds": 8.0
}
```

## Replay file

```jsonc
{
  "version": 1,
  "level": "06-waterside",
  "seed": 88121,
  "tuningHash": "sha256:...",     // fails loudly if tuning changed
  "ticks": [
    [0,   "MOVE",  [0.0, 1.0]],
    [14,  "TAP",   [12, 3]],       // joint grid coords
    [31,  "HAMMER_DRAW", []],
    [48,  "HAMMER_RELEASE", [0.68, 0.02]],   // power, angleError
    ...
  ],
  "expectedInvoice": { "total": 1730, "angularError": 3.1, "shiftRemaining": 22 }
}
```

When a tuning change legitimately alters a replay's outcome, the replay is **re-recorded and the diff
is reviewed** — the diff of two invoices is the clearest possible summary of what a balance change
actually did.
