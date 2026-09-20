#pragma once

// A level, as data — CORE-008.
//
// Levels are JSON, not scenes. There is no hand-placed geometry anywhere in this project: a `.umap`
// holds lighting, sky and spawn points and nothing else, and the structure is generated at runtime
// from what is loaded here. That is rule 3, and it is what makes "idea to playable in under thirty
// minutes" possible — which is in turn what makes twelve levels affordable.
//
// So this loader is the only path from a designer's file to something playable, and `Validate()` is
// the second line of defence against a broken level reaching a playtest. It re-implements the same
// rules as `tools/validate_data.py`: the Python one runs in a pre-commit hook without a compiler,
// this one runs in the game. A divergence between them is a bug in whichever is newer, and there is
// a test that runs both over the same fixtures and compares.

#include "Export.h"
#include "Types.h"

#include <cstdint>
#include <string>
#include <vector>

namespace sj {

class JsonValue;


// How the joints in a height range behave. `type` is open — a band type is added by writing a
// generator, not by extending an enum here — but `from`/`to`/`quality` are universal.
struct BandSpec
{
    float       from{}, to{};
    std::string type;

    // The distribution of joint quality tiers in this band. Sums to 1.0; the validator enforces it,
    // because a band that sums to 1.35 is a band that is silently 35% more generous than written.
    float sound{}, fair{}, perished{}, cracked{};

    // The band's mechanical params, from `params` in the level file. Defaulted to "a plain band",
    // so a band that does not mention one behaves like every other band on that axis.
    //
    // How much of a joint's truth survives into how it looks. 1 is the default read; 0 is the Grey
    // Box's salt-bloom band, where the bloom covers everything and only the tap test works.
    float visualReadReliability{1.0f};
    // 0 scatters sound joints at random; towards 1 they gather into patches, so that finding one is
    // a clue to where the next is. The Grey Box's perished band uses it to reward reading the face.
    float soundJointClustering{0.0f};
    // Authored joints, as heights. Placed on the climbing line, because the only reason to author a
    // joint is to put it where the player is certain to meet it — level 1's cracked joint at 7 m.
    std::vector<float> forcePerishedAt, forceCrackedAt;
    // Dogs a previous jack left in the wall. The Grey Box's old-fixtures band has nine, 1.4 m
    // apart, unrated: free to lash to, and nobody can tell you what they will hold.
    int32_t fixtureCount{0};
    float   fixtureSpacingMetres{0.0f};
    bool    fixtureRated{true};

    float Span() const noexcept { return to - from; }
    bool  Contains(float height) const noexcept { return height >= from && height < to; }
};

struct StructureSpec
{
    std::string type;
    float       height{}, baseRadius{}, topRadius{};
    std::string profile, cap;
    float       leanDegrees{};
    int32_t     leanBearing{};
    float       courseHeight{}, brickLength{}, candidateDensity{};
    uint64_t    weatherSeed{};
};

struct ExclusionSpec
{
    std::string id;
    int32_t     bearing{}, distance{};
};

// The weather, which until now was the one block of every level file that nothing read.
//
// Wind matters mechanically rather than decoratively: it is a term in the nerve drain and a term in
// wobble, so a level's wind profile is a difficulty dial the designer already has and the game was
// ignoring — the presentation layer passed a hard-coded 9 m/s at every height of every level.
struct WeatherSpec
{
    float windBase{};

    // Multiplier against height, as authored: [[0, 1.0], [40, 1.6], [70, 2.1]]. Interpolated
    // linearly between points and held flat outside them, so a level need only give the corners.
    std::vector<Vec2> windAtHeight;

    // Seconds between gusts, as a range to draw from. `hasGusts` is false when the level says
    // `null`, which is how a sheltered level says "no gusts" — distinct from a range of [0,0],
    // which would be a gust every frame.
    bool  hasGusts{};
    float gustEverySecondsMin{}, gustEverySecondsMax{};

    std::string precipitation;

    // Wind speed in m/s at a height, base times the interpolated multiplier.
    float WindAt(float height) const noexcept;
};

struct SiteSpec
{
    float                      safeLineDistance{};
    bool                       hasCorridor{};
    int32_t                    corridorFrom{}, corridorTo{};
    std::vector<ExclusionSpec> exclusions;

    // Bearings wrap at 360, so a corridor may run 340->20. Callers must not compare raw.
    bool InCorridor(int32_t bearing) const noexcept;
};

class SJ_API LevelData
{
public:
    static LevelData LoadFrom(const std::string& path);
    static LevelData Parse(const std::string& json, const std::string& origin);

    const std::string& Id() const noexcept { return id_; }
    const std::string& Name() const noexcept { return name_; }
    const std::string& Archetype() const noexcept { return archetype_; }
    int32_t Order() const noexcept { return order_; }

    float TotalHeight() const noexcept { return structure_.height; }

    // The daylight the job comes with, and what a good day looks like. Authored in every level
    // file since the first one and read by nothing until FELL-006 priced a felling in shift.
    // 0 when the file does not say, which means "untimed".
    int32_t ShiftMinutes() const noexcept { return shiftMinutes_; }
    int32_t TargetMinutes() const noexcept { return targetMinutes_; }

    // The band containing `height`. Throws if none does — a height outside the structure is a
    // caller bug, and returning the nearest band would put a climber in brickwork that is not there.
    const BandSpec& BandAt(float height) const;

    const std::vector<BandSpec>& Bands() const noexcept { return bands_; }
    const StructureSpec& Structure() const noexcept { return structure_; }
    const SiteSpec& Site() const noexcept { return site_; }
    const WeatherSpec& Weather() const noexcept { return weather_; }

    // The ladder sections the job comes with — `loadoutHint.ladders`. 0 when the file does not say.
    // The reachability gate (CORE-009) proves the top can be reached with this many, and the game
    // fills the cradle with it.
    int32_t LoadoutLadders() const noexcept { return loadoutLadders_; }

    // Every rule `tools/validate_data.py` enforces, in the same order, with messages that name the
    // same things. Empty means the level is playable. Never throws: a broken level must be
    // *reportable*, not fatal, or the editor tooling cannot show a designer what is wrong.
    std::vector<std::string> Validate() const;

private:
    std::string           id_, name_, archetype_;
    int32_t               order_{};
    StructureSpec         structure_;
    std::vector<BandSpec> bands_;
    int32_t               loadoutLadders_{};
    int32_t               shiftMinutes_{}, targetMinutes_{};
    SiteSpec              site_;
    WeatherSpec           weather_;
    std::string           origin_;
};

}  // namespace sj
