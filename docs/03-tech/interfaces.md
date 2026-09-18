# Interfaces

> **Contract-first.** Every signature here is fixed *before* the implementations are written, so
> that several agents can implement several modules simultaneously without talking to each other.
>
> Changing anything on this page is a **breaking change**. Open a task, get it reviewed, and update
> the dependent task files in the same PR. Do not change a signature while someone is implementing
> against it — see [Escalation](../06-workflow/00-agent-workflow.md#escalation).

Scope: the modules needed for M0 and M1. M2+ interfaces are added at the start of their milestone.

## Conventions

Per [ADR-0004](adr/0004-engine-change-to-unreal.md), `SteeplejackSim` is **plain C++20 with no
Unreal dependency**, so that it builds standalone under CMake and its tests run in CI without the
engine. That constraint is enforced by `tools/check_conventions.py` and it is not negotiable.

- Namespace `sj`. Header-per-module in `Public/`, implementation in `Private/`.
- **No UE types.** No `FVector`, `TArray`, `FString`, `UObject`, `FMath`, `UE_LOG`, no `.generated.h`.
  Use `sj::Vec3`, `std::vector`, `std::string`, `<cmath>`.
- **No allocation in `Step()`.** Buffers are sized at construction. The sim runs 60×/s forever.
- Time is always an explicit `float dt` in seconds. Never a global clock.
- Randomness is always an injected `Rng&`. Never `rand()`, never a static.
- Tuning is always an injected `const Tuning&`. Never a constant in code.
- Angles are **degrees**; bearings degrees clockwise from north; distances **metres**; forces **kN**;
  mass **kg**.
- Functions that can fail return a result struct with an explicit outcome enum, never a null pointer.
- Everything that can be `const` and `noexcept` is.

```cpp
// Common vocabulary, Types.h
namespace sj {
struct Vec2 { float x, y; };
struct Vec3 { float x, y, z; };
constexpr float kTick = 1.0f / 60.0f;
constexpr int   kMaxCatchUpSteps = 5;
}
```

---

## `Rng.h` — CORE-003

```cpp
class Rng {
public:
    explicit Rng(uint64_t seed) noexcept;
    uint32_t NextU32() noexcept;                       // xorshift128+
    float    NextFloat() noexcept;                     // [0, 1)
    float    RangeFloat(float lo, float hi) noexcept;
    int32_t  RangeInt(int32_t lo, int32_t hi) noexcept;         // [lo, hi)
    int32_t  PickWeighted(const float* weights, int n) noexcept;
    Rng      Fork(uint32_t tag) const noexcept;        // independent substream
    std::array<uint64_t, 2> State() const noexcept;
    void     Restore(const std::array<uint64_t, 2>&) noexcept;
};
```

`Fork()` matters: each subsystem takes its own substream so that adding a call in one place doesn't
shift every other random value in the game and invalidate every recorded replay.

---

## `Types.h` — CORE-004

```cpp
enum class JointTier  : uint8_t { Cracked, Perished, Fair, Sound };
enum class AnchorRate : uint8_t { Failed, Poor, Fair, Sound };
enum class Stance     : uint8_t { OneHand, HookedLeg, Clipped, Belted, Chair };
enum class Lashing    : uint8_t { None, Hitch, Full };
enum class Exposure   : uint8_t { Platform, Ladder, Hanging, Overhang };
enum class SpanBand   : uint8_t { Rigid, Flex, Sway, Buckle };

struct Joint   { int32_t id{}; Vec3 pos{}, normal{}; float height{}, quality{};
                 JointTier tier{}; bool occupied{}; };

struct Anchor  { int32_t jointId{-1}; float height{}, depth{}, spall{};
                 AnchorRate rate{AnchorRate::Failed};
                 float capacityKN{}, loadKN{}; bool freeFixture{}; };

struct Section { int32_t lowerAnchor{-1}, upperAnchor{-1};
                 float span{}, condition{1.f}, buckleTimer{-1.f};
                 Lashing lashing{Lashing::None}; };

struct Meters  { float grip{}, nerve{}, nerveMax{};
                 Stance stance{}; Exposure exposure{}; };

struct MeterContext { float height{}, windSpeed{};
                      bool carryingLadder{}, wet{}, cold{}, gloves{};
                      const char* injury{""}; };   // "" | "cracked_rib" | "bad_ankle"

struct StrikeResult { float depthGain{}, spalled{}; bool bent{}, seated{}; };
```

Aggregate initialisation only. No constructors, no virtuals, no inheritance — these are data.

---

## `Json.h` — CORE-014

```cpp
class JsonError : public std::runtime_error { ... };   // carries origin and line

class JsonValue {
public:
    enum class Kind : uint8_t { Object, Array, Number, String, Bool, Null };

    static JsonValue Parse(const std::string& text, const std::string& origin);

    Kind               Type() const noexcept;
    const std::string& Origin() const noexcept;
    std::size_t        Line() const noexcept;          // where this value started

    bool             Has(std::string_view key) const noexcept;
    const JsonValue& At(std::string_view key) const;   // object member; throws if absent
    const JsonValue& At(std::size_t index) const;      // array element; throws if absent
    std::size_t      Size() const noexcept;            // members or elements

    double             AsNumber() const;               // throws unless Kind::Number
    const std::string& AsString() const;               // throws unless Kind::String
    bool               AsBool() const;                 // throws unless Kind::Bool

    // Object members and array elements, in FILE order. Order is part of the contract:
    // level bands are contiguous ranges and CORE-008 validates neighbours.
    const std::vector<std::pair<std::string, JsonValue>>& Members() const;
    const std::vector<JsonValue>&                         Elements() const;

    // Every leaf as (dotted.path, value) — the flat view Tuning is built on.
    void ForEachLeaf(const std::function<void(const std::string&, const JsonValue&)>&) const;
};
```

The one JSON reader in `SteeplejackSim`. `Tuning` (CORE-007) and `LevelData` (CORE-008) both read
through it; a second parser is how two parsers start disagreeing about what a number is.

Accepts the subset the data actually uses — objects, arrays, numbers, strings, booleans, and `//`
line comments, since `data-schemas.md` writes these files as `jsonc`. Rejects `\uXXXX` escapes
rather than decoding UTF-16 surrogate pairs wrongly in silence. `null` **parses** to `Kind::Null`;
whether a null is acceptable is the caller's policy, not the reader's — `Tuning` rejects one.

No third-party JSON library: `SteeplejackSim` must configure and build with nothing but a compiler
(ADR-0004).

---

## `Tuning.h` — CORE-007

```cpp
class Tuning {
public:
    static Tuning LoadAll(const std::string& dir);     // reads data/tuning/*.json
    float       GetF(std::string_view key) const;      // dotted: "gripDrainPerSecond.oneHand"
    int32_t     GetI(std::string_view key) const;
    bool        GetB(std::string_view key) const;
    bool        Has(std::string_view key) const noexcept;
    std::string Hash() const;                          // sha256; stamped into replays
};
```

A missing key **throws with the key name and the file it was expected in**. It never returns zero —
a silently-zero tuning value is the worst possible failure mode for a balance-driven game.

---

## `Clock.h` — CORE-005

```cpp
class SimClock {
public:
    explicit SimClock(float tick = kTick) noexcept;
    int   Advance(float realDelta) noexcept;   // steps to run, capped at kMaxCatchUpSteps
    float Alpha() const noexcept;              // [0, 1) render interpolation factor
};
```

---

## `Intent.h`, `Recorder.h`, `Replay.h` — CORE-006

```cpp
enum class IntentKind : uint8_t {
    Move, Look, Tap, HammerDraw, HammerRelease, LashWrap, LashTie,
    HaulPull, HaulSteer, Clip, Unclip, SetStance, Climb, Slide,
    SelectTool, Brew, Smoke, LookAtView, GrabSave
};

struct Intent { IntentKind kind{}; float a{}, b{}; int32_t target{-1}; };

using IntentBuffer = std::vector<Intent>;   // reused, never reallocated per tick

class Recorder {
public:
    Recorder(std::string levelId, uint64_t seed, std::string tuningHash);
    void        Record(int32_t tick, const IntentBuffer&);
    std::string ToJson() const;
};

class Replay {
public:
    static Replay FromJson(const std::string&);
    const std::string& LevelId() const noexcept;
    uint64_t Seed() const noexcept;
    const std::string& TuningHash() const noexcept;
    const IntentBuffer& IntentsAt(int32_t tick) const noexcept;   // empty, no allocation
    int32_t LengthTicks() const noexcept;
};
```

Intents are **semantic, not input events** — `HammerRelease(power, angleError)`, never `MouseUp`.
That keeps replays stable across input remapping and accessibility settings.

---

## `Level.h` — CORE-008

```cpp
class LevelData {
public:
    static LevelData LoadFrom(const std::string& path);
    const std::string& Id() const noexcept;
    const std::string& Archetype() const noexcept;
    float TotalHeight() const noexcept;
    const BandSpec& BandAt(float height) const;
    std::vector<std::string> Validate() const;   // same rules as tools/validate_data.py
    // Structure(), Site(), Mission(), Scoring() return parsed sub-structs
};
```

`Validate()` must implement the same rules as the Python validator. A test asserts the two agree on
every fixture — a divergence is a bug in whichever one is newer.

---

## `Joints.h` — STRUCT-002

```cpp
class JointGrid {
public:
    static JointGrid Generate(const LevelData&, Rng&, const Tuning&);
    void  AtHeight(float h, float tol, std::vector<int32_t>& out) const;  // no allocation
    const Joint& Nearest(Vec3 pos, float maxRange) const noexcept;        // null-object if none
    const Joint& ById(int32_t id) const noexcept;
    int32_t Count() const noexcept;
    const std::string& BandAt(float h) const noexcept;
};
```

Deterministic in `(level, seed)`. Tiers drawn from each band's distribution via a **forked** RNG
substream. `params.forcePerishedAt` / `forceCrackedAt` place authored joints exactly — Level 1
depends on this to put a Cracked joint on the obvious climbing line.

---

## `Verbs/Tap.h` — VERB-001

```cpp
struct TapResult { JointTier tier{}; float confidence{}; 
                   std::string_view soundId; int32_t pipShape{}; };

TapResult Tap(const Joint&, const Tuning&, bool wearingGloves) noexcept;
```

`pipShape` is a **shape** index, never a colour — the accessibility fallback must not rely on hue.

---

## `Verbs/Hammer.h` — VERB-003

```cpp
StrikeResult Strike(const Joint&, float currentDepth, float power,
                    float angleErrorDeg, float toolCondition,
                    const Tuning&) noexcept;
```

Pure. The caller owns the swing state machine and the wobble; this resolves one strike. Model in
[the climbing system](../01-gdd/02-climbing-system.md#2-dogging-in--the-hammer).

---

## `Anchor.h` — VERB-004

```cpp
AnchorRate Rate(const Joint&, float depth, float spall, const Tuning&) noexcept;
float      CapacityKN(AnchorRate, const Tuning&) noexcept;
Anchor     Make(const Joint&, float depth, float spall, const Tuning&) noexcept;
AnchorRate RateFreeFixture(const BandSpec&, Rng&, const Tuning&) noexcept;
```

---

## `Stack.h` — CLIMB-001

```cpp
class Stack {
public:
    int32_t AddAnchor(const Anchor&);
    int32_t AddSection(int32_t lower, int32_t upper, Lashing);
    float    SpanOf(int32_t section) const noexcept;
    SpanBand BandOf(int32_t section, const Tuning&) const noexcept;
    float    FlexDeflectionM(int32_t section, float loadKN, const Tuning&) const noexcept;
    void     Step(float dt, int32_t loadedSection, const Tuning&,
                  std::vector<int32_t>& buckledOut);
    float    TopHeight() const noexcept;

    std::string ToJson() const;                  // CLIMB-006
    static Stack FromJson(const std::string&);

    const std::vector<Anchor>&  Anchors() const noexcept;
    const std::vector<Section>& Sections() const noexcept;
};
```

---

## `Load.h` — CLIMB-002

```cpp
void LoadShare(const Stack&, int32_t atSection, float totalKN, const Tuning&,
               std::vector<float>& out) noexcept;
void ApplyLoad(Stack&, int32_t atSection, float totalKN, const Tuning&) noexcept;
void Cascade(Stack&, int32_t failedAnchor, const Tuning&,
             std::vector<int32_t>& failedInOrder) noexcept;
```

`Cascade` fills `failedInOrder` **in failure order**, so the HUD can burn anchors down the screen
like a fuse. Fully deterministic — no RNG in this module.

---

## `Meters.h`, `Wobble.h` — METER-001/2/3

```cpp
namespace grip {
    void  Step(Meters&, float dt, const MeterContext&, const Tuning&) noexcept;
    float DrainRate(Stance, const MeterContext&, const Tuning&) noexcept;
}
namespace nerve {
    void    Step(Meters&, float dt, const MeterContext&, const Tuning&) noexcept;
    void    Shock(Meters&, std::string_view event, const Tuning&) noexcept;
    int32_t Band(float nerve, const Tuning&) noexcept;   // 0 calm .. 3 bad
}

float WobbleAmplitudeDeg(const Meters&, const MeterContext&,
                         float gust, const Tuning&) noexcept;
```

> **`WobbleAmplitudeDeg` is the only place wobble is computed.** Every skill verb reads it. A verb
> that computes its own wobble is rejected in review — see the anti-pillars. A verb needing
> different behaviour takes a multiplier; it does not reimplement the function.

---

## `Weather.h` — ENV-003

```cpp
class Weather {
public:
    Weather(const LevelData&, Rng&, const Tuning&);
    void  Step(float dt, float shiftFraction) noexcept;
    float WindAt(float height) const noexcept;
    float GustNow() const noexcept;        // [0, 1]
    float GustIncoming() const noexcept;   // seconds until next gust, or -1
    const char* Precipitation() const noexcept;
};
```

`GustIncoming()` is a **promise**: once it returns a value below `gust_pre_roll_seconds`, the gust
*will* happen. Never surprise the player with a gust. This drives both the 1.2 s audio pre-roll and
its visual fallback.

---

## `Verbs/Haul.h` — VERB-007

```cpp
struct HaulState { float height{}, swingDeg{}, swingVel{}; bool fouled{}; };

void StepHaul(HaulState&, float dt, float pull, float steer,
              float wind, float loadKg, const Tuning&) noexcept;
```

A 2-DOF pendulum integrated at the fixed step. Not a rope simulation.
([ADR-0002](adr/0002-physics-and-destruction.md))

---

## `Verbs/Lash.h` — VERB-005

```cpp
struct LashState { int32_t wraps{}; float tension{}; bool tied{}, slipping{}; };

void    StepLash(LashState&, float dt, float rotationRate, const Tuning&) noexcept;
Lashing TieOff(LashState&, const Tuning&) noexcept;
float   DriftPerMinuteCm(Lashing, const Tuning&) noexcept;
```

---

## `Slip.h` — METER-005

```cpp
enum class SlipOutcome : uint8_t { None, Saved, Fell };
enum class Difficulty  : uint8_t { Assisted, Jack, OwdHand };

class SlipModel {
public:
    explicit SlipModel(Difficulty = Difficulty::Jack) noexcept;
    void  SetDifficulty(Difficulty) noexcept;

    float WindowSeconds(const Tuning&) const noexcept;
    float CooldownSeconds(const Tuning&) const noexcept;

    bool  CanSlipSave(float now, const Tuning&) const noexcept;
    float BeginSlip(float now, const Tuning&) noexcept;   // window, seconds; 0 = budget spent
    bool  InProgress() const noexcept;
    float WindowFractionLeft(float now) const noexcept;   // 1 → 0, the telegraph

    SlipOutcome Resolve(float now, bool grabbed, Meters&, const Tuning&) noexcept;
};

struct FallResult { bool caught{}, anchorFailed{}; float shockLoadKN{}, capacityKN{}; };

FallResult ResolveFall(Meters&, const Anchor& tiedTo, const Tuning&) noexcept;
```

**Three departures from the signature this document fixed before the module existed**, each
recorded here rather than made quietly in the implementation:

- **`Resolve` takes `now` and `grabbed` rather than a `grabbedAt`.** As fixed, a slip nobody
  grabbed at never resolved — there was no call that reported the fall, so the expiry would have
  been a timer in the presentation layer, which is where game rules are not allowed to live. One
  call per frame carrying the input has one call site and no way to forget the expiry.
- **`Resolve` takes `Meters&`.** The save costs grip and nerve. As fixed, the caller applied that
  cost, which is a rule outside the sim — and one every caller could get subtly different.
- **`Difficulty` is new.** `meters.json` has held the difficulty table since METER-002 and nothing
  could read it; acceptance 1 is that the window tracks it. It lives in `Slip.h` because this is
  the first module to need it, and belongs in `Types.h` as soon as a second one does.

`BeginSlip` returning **0 for a spent budget** is deliberate rather than a sentinel to branch on: a
budget you have already spent is a zero-length window, and `Resolve` falls you on the first call
for the same reason it falls you on any other closed window. There is no second code path.

---

## `Reachability.h` — CORE-009

```cpp
struct Route { std::vector<int32_t> anchors; int32_t sections{}; float maxSpan{}; bool valid{}; };

Route Solve(const JointGrid&, int32_t ladders, float maxSpan);
```

Used by the level validator. A level whose top cannot be reached at `maxSpan` with the authored
ladder allowance is a broken level, and this catches it in seconds rather than in playtest.

---

## The UE boundary

`SteeplejackGame` may call into `sj::` freely. **`sj::` may never call into UE.** There is exactly
one adapter layer:

```cpp
// Source/SteeplejackGame/SimBridge.h — the only place the two worlds meet
FVector  ToUE(sj::Vec3) noexcept;
sj::Vec3 ToSim(const FVector&) noexcept;
sj::IntentBuffer CollectIntents(const UEnhancedInputComponent&);
void ApplySimState(const sj::JobState&, ASteeplejackCharacter&, UHUDWidget&);
```

If you find yourself wanting a second adapter, the boundary is in the wrong place — escalate.

---

## Adding an interface

1. Open a task that owns this file.
2. Write the signature here first, with the owning task ID in the heading.
3. List every task that will consume it, and add this file to their `spec:` refs.
4. Only then write the implementation task(s).

The whole point is that step 2 happens before anyone starts typing C++.
