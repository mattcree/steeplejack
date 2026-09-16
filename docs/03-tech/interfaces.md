# Interfaces

> **Contract-first.** Every signature here is fixed *before* the implementations are written, so
> that eight agents can implement eight modules simultaneously without talking to each other.
>
> Changing anything on this page is a **breaking change**. Open a task, get it reviewed, and update
> the dependent task files in the same PR. Do not change a signature while someone is implementing
> against it — see [Escalation](../06-workflow/00-agent-workflow.md#escalation).

Scope: the modules needed for M0 and M1. M2+ interfaces are added at the start of their milestone.

## Conventions

- All of `sim/` is `RefCounted` or plain classes. Never `Node`. ([ADR-0003](adr/0003-determinism-and-testing.md))
- Time is always an explicit `dt: float` parameter in seconds.
- Randomness is always an injected `Rng`.
- Tuning is always an injected `Tuning`.
- Angles are **degrees**; bearings are degrees clockwise from north. Distances are **metres**.
  Forces are **kN**. Mass is **kg**.
- Functions that can fail return a result struct with an explicit outcome enum, never `null`.
- Static typing is mandatory. `sim/` must compile with `untyped_declaration` as an error.

---

## `sim/rng.gd` — CORE-003

```gdscript
class_name Rng extends RefCounted

func _init(seed: int) -> void
func next_u32() -> int                         # xorshift128; deterministic across a build
func next_float() -> float                     # [0.0, 1.0)
func range_float(lo: float, hi: float) -> float
func range_int(lo: int, hi: int) -> int        # inclusive lo, exclusive hi
func pick_weighted(weights: Array[float]) -> int
func fork(tag: int) -> Rng                     # independent substream; same tag = same stream
func state() -> PackedInt64Array               # for save/replay
func restore(s: PackedInt64Array) -> void
```

`fork()` matters: each subsystem takes its own substream so that adding a call in one place doesn't
shift every other random value in the game and invalidate every replay.

---

## `sim/types.gd` — CORE-004

```gdscript
enum JointTier  { CRACKED, PERISHED, FAIR, SOUND }
enum AnchorRate { FAILED, POOR, FAIR, SOUND }
enum Stance     { ONE_HAND, HOOKED_LEG, CLIPPED, BELTED, CHAIR }
enum Lashing    { NONE, HITCH, FULL }
enum Exposure   { PLATFORM, LADDER, HANGING, OVERHANG }

class Joint extends RefCounted:
    var id: int
    var pos: Vector3            # world, metres
    var normal: Vector3
    var height: float           # metres above the structure base
    var quality: float          # [0,1], hidden from the player until tapped
    var tier: JointTier         # derived from quality via tuning thresholds
    var occupied: bool

class Anchor extends RefCounted:
    var joint_id: int
    var height: float
    var depth: float            # [0,1]; seated at >= tuning.dog_seat_depth_fraction
    var spall: float            # [0,1] brick damage from over-driving
    var rate: AnchorRate
    var capacity_kn: float
    var load_kn: float          # updated by LoadModel
    var is_free_fixture: bool   # an existing iron band / old dog; unrated until tapped

class Section extends RefCounted:
    var lower_anchor: int       # index into Stack.anchors
    var upper_anchor: int
    var span: float             # metres, anchor to anchor
    var lashing: Lashing
    var condition: float        # [0,1]; persists across jobs
    var buckle_timer: float     # seconds under load beyond the buckle span; -1 if not buckling

class Meters extends RefCounted:
    var grip: float
    var nerve: float
    var nerve_max: float
    var stance: Stance
    var exposure: Exposure

class StrikeResult extends RefCounted:
    var depth_gain: float
    var bent: bool
    var spalled: float
    var seated: bool
```

---

## `sim/tuning.gd` — CORE-007

```gdscript
class_name Tuning extends RefCounted

static func load_all(dir: String) -> Tuning    # reads data/tuning/*.json
func get_f(key: String) -> float               # flat or dotted, e.g. "grip_drain.one_hand"
func get_i(key: String) -> int
func get_b(key: String) -> bool
func hash() -> String                          # sha256; stamped into replays
func has(key: String) -> bool
```

Keys are accessed as `tuning.get_f("span_warn_metres")`, or via generated typed accessors
(`tuning.span_warn_metres`) — the convention checker recognises both forms.

---

## `sim/clock.gd` — CORE-005

```gdscript
class_name SimClock extends RefCounted

const TICK: float = 1.0 / 60.0

func _init(tick: float = TICK) -> void
func advance(real_delta: float) -> int          # returns how many fixed steps to run
func alpha() -> float                           # [0,1) interpolation factor for rendering
```

---

## `sim/intent.gd`, `sim/recorder.gd`, `sim/replay.gd` — CORE-006

```gdscript
enum IntentKind {
    MOVE, LOOK, TAP, HAMMER_DRAW, HAMMER_RELEASE, LASH_WRAP, LASH_TIE,
    HAUL_PULL, HAUL_STEER, CLIP, UNCLIP, SET_STANCE, CLIMB, SLIDE,
    SELECT_TOOL, BREW, SMOKE, LOOK_AT_VIEW, GRAB_SAVE
}

class Intent extends RefCounted:
    var kind: IntentKind
    var a: float        # meaning is per-kind; documented in the enum comment
    var b: float
    var target: int     # joint id / anchor index / -1

class Recorder extends RefCounted:
    func _init(level_id: String, seed: int, tuning_hash: String) -> void
    func record(tick: int, intents: Array[Intent]) -> void
    func to_json() -> String
    static func from_json(s: String) -> Replay

class Replay extends RefCounted:
    var level_id: String
    var seed: int
    var tuning_hash: String
    var expected_invoice: Dictionary
    func intents_at(tick: int) -> Array[Intent]
    func length_ticks() -> int
```

---

## `sim/joints.gd` — STRUCT-002

```gdscript
class_name JointGrid extends RefCounted

static func generate(level: LevelData, rng: Rng, tuning: Tuning) -> JointGrid

func at_height(h: float, tolerance: float) -> Array[Joint]
func nearest(pos: Vector3, max_range: float) -> Joint    # null-object Joint if none
func by_id(id: int) -> Joint
func count() -> int
func band_at(h: float) -> String                         # band type name
```

Generation is deterministic in `(level, rng seed)`. Joint tiers are drawn from each band's
`quality` distribution; `params.forcePerishedAt` / `forceCrackedAt` place authored joints exactly.

---

## `sim/verbs/tap.gd` — VERB-001

```gdscript
class_name TapVerb extends RefCounted

class TapResult extends RefCounted:
    var tier: JointTier
    var confidence: float     # 1.0 bare-handed; reduced by gloves (tuning.gloves.tap_tier_penalty)
    var sound_id: String      # audio bank key
    var pip_shape: int        # 0-3; SHAPE not colour (accessibility)

static func tap(joint: Joint, tuning: Tuning, wearing_gloves: bool) -> TapResult
```

---

## `sim/verbs/hammer.gd` — VERB-003

```gdscript
class_name HammerVerb extends RefCounted

static func strike(
    joint: Joint,
    current_depth: float,
    power: float,             # [0,1] arc length at release
    angle_error_deg: float,   # reticle offset at release, already wobble-affected
    tool_condition: float,    # [0,1]
    tuning: Tuning
) -> StrikeResult
```

Pure. The caller owns the swing state machine and the wobble; this function resolves one strike.
See [the climbing system](../01-gdd/02-climbing-system.md#2-dogging-in--the-hammer) for the model.

---

## `sim/anchor.gd` — VERB-004

```gdscript
class_name AnchorModel extends RefCounted

static func rate(joint: Joint, depth: float, spall: float, tuning: Tuning) -> AnchorRate
static func capacity_kn(rate: AnchorRate, tuning: Tuning) -> float
static func make(joint: Joint, depth: float, spall: float, tuning: Tuning) -> Anchor
static func rate_free_fixture(band_params: Dictionary, rng: Rng, tuning: Tuning) -> AnchorRate
```

---

## `sim/stack.gd` — CLIMB-001

```gdscript
class_name Stack extends RefCounted

enum SpanBand { RIGID, FLEX, SWAY, BUCKLE }

var anchors: Array[Anchor]
var sections: Array[Section]

func add_anchor(a: Anchor) -> int
func add_section(lower: int, upper: int, lashing: Lashing) -> int
func span_of(section_index: int) -> float
func span_band(section_index: int, tuning: Tuning) -> SpanBand
func flex_deflection_m(section_index: int, load_kn: float, tuning: Tuning) -> float
func step(dt: float, loaded_section: int, tuning: Tuning) -> Array[int]   # sections that buckled
func top_height() -> float
func to_dict() -> Dictionary        # CLIMB-006 serialisation
static func from_dict(d: Dictionary) -> Stack
```

---

## `sim/load.gd` — CLIMB-002

```gdscript
class_name LoadModel extends RefCounted

static func share(stack: Stack, at_section: int, total_kn: float, tuning: Tuning) -> Array[float]
static func apply(stack: Stack, at_section: int, total_kn: float, tuning: Tuning) -> void
static func cascade(stack: Stack, failed_anchor: int, tuning: Tuning) -> Array[int]
```

`cascade` returns the anchor indices that fail, **in failure order**, so the HUD can burn them down
the screen like a fuse. Deterministic — no RNG.

---

## `sim/meters_grip.gd`, `sim/meters_nerve.gd`, `sim/wobble.gd` — METER-001/2/3

```gdscript
class_name GripModel extends RefCounted
static func step(m: Meters, dt: float, ctx: MeterContext, tuning: Tuning) -> void
static func drain_rate(stance: Stance, ctx: MeterContext, tuning: Tuning) -> float

class_name NerveModel extends RefCounted
static func step(m: Meters, dt: float, ctx: MeterContext, tuning: Tuning) -> void
static func shock(m: Meters, event: String, tuning: Tuning) -> void
static func band(nerve: float, tuning: Tuning) -> int    # 0 calm .. 3 bad

class_name MeterContext extends RefCounted:
    var height: float
    var wind_speed: float
    var carrying_ladder: bool
    var wet: bool
    var cold: bool
    var injury: String          # "" | "cracked_rib" | "bad_ankle"
    var gloves: bool

class_name Wobble extends RefCounted
static func amplitude_deg(m: Meters, ctx: MeterContext, gust: float, tuning: Tuning) -> float
```

> **`Wobble.amplitude_deg` is the only place wobble is computed.** Every skill verb reads it.
> A verb that computes its own wobble will be rejected in review — see the anti-pillars.

---

## `sim/weather.gd` — ENV-003

```gdscript
class_name Weather extends RefCounted

func _init(level: LevelData, rng: Rng, tuning: Tuning) -> void
func step(dt: float, shift_fraction: float) -> void
func wind_at(height: float) -> float                 # m/s
func gust_now() -> float                             # [0,1] current gust intensity
func gust_incoming() -> float                        # seconds until the next gust, or -1
func precipitation() -> String
```

`gust_incoming()` is what drives the **1.2 s audio pre-roll** and its visual fallback. It is a
promise: once it returns a value below `tuning.gust_pre_roll_seconds`, the gust *will* happen.
Never surprise the player with a gust.

---

## `sim/verbs/haul.gd` — VERB-007

```gdscript
class_name HaulVerb extends RefCounted

class HaulState extends RefCounted:
    var height: float
    var swing_deg: float
    var swing_vel: float
    var fouled: bool

static func step(s: HaulState, dt: float, pull: float, steer: float,
                 wind: float, load_kg: float, tuning: Tuning) -> void
```

A 2-DOF pendulum integrated at the fixed step. Not a rope simulation.
([ADR-0002](adr/0002-physics-and-destruction.md))

---

## `sim/verbs/lash.gd` — VERB-005

```gdscript
class_name LashVerb extends RefCounted

class LashState extends RefCounted:
    var wraps: int
    var tension: float          # [0,1], decays if the player pauses
    var tied: bool
    var slipping: bool

static func step(s: LashState, dt: float, rotation_rate: float, tuning: Tuning) -> void
static func tie_off(s: LashState, tuning: Tuning) -> Lashing
static func drift_per_minute_cm(l: Lashing, tuning: Tuning) -> float
```

---

## `sim/slip.gd` — METER-005

```gdscript
class_name SlipModel extends RefCounted

enum SlipOutcome { NONE, SAVED, FELL }

func can_slip_save(now: float, tuning: Tuning) -> bool
func begin_slip(now: float, tuning: Tuning) -> float        # window in seconds
func resolve(grabbed_at: float, tuning: Tuning) -> SlipOutcome
```

---

## `sim/level.gd` — CORE-008

```gdscript
class_name LevelData extends RefCounted

static func load_from(path: String) -> LevelData
var id: String
var archetype: String
var structure: Dictionary
var bands: Array[Dictionary]
var weather_spec: Dictionary
var site: Dictionary
var mission: Dictionary
var scoring: Dictionary

func band_at(height: float) -> Dictionary
func total_height() -> float
func validate() -> Array[String]       # same rules as tools/validate_data.py
```

`validate()` must implement the same rules as the Python validator. They are checked against each
other by a test — a divergence between the two is a bug in whichever one is newer.

---

## `sim/reachability.gd` — CORE-009

```gdscript
class_name Reachability extends RefCounted

class Route extends RefCounted:
    var anchors: Array[int]
    var sections: int
    var max_span: float

static func solve(grid: JointGrid, ladders: int, max_span: float) -> Route   # null if unreachable
```

Used by the level validator. A level whose top cannot be reached at `max_span` with the authored
ladder allowance is a broken level, and this catches it in seconds rather than in playtest.

---

## Adding an interface

1. Open a task that owns this file.
2. Write the signature here first, with the owning task ID in the heading.
3. List every task that will consume it, and add this file to their `spec:` refs.
4. Only then write the implementation task(s).

The whole point is that step 2 happens before anyone starts typing GDScript.
