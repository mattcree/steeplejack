// Recording and replay — CORE-006, the acceptance by number.
//
// The run here is synthetic but the sim it drives is real. Intents move the meters, set the
// stance and swing the hammer at real joints. The state trace is a hash of that state every tick,
// so "identical" means the grip, nerve, stance and every dog's depth agree to the bit on every one
// of 3,600 ticks, not just at the end.

#include "doctest.h"

#include "Intent.h"
#include "Meters.h"
#include "Recorder.h"
#include "Replay.h"
#include "Rng.h"
#include "Tuning.h"
#include "Types.h"
#include "Verbs/Hammer.h"

#include <cstdint>
#include <cstring>
#include <filesystem>
#include <string>
#include <vector>

using sj::Intent;
using sj::IntentBuffer;
using sj::IntentKind;
using sj::Tuning;

namespace {

std::string TuningDir()
{
    namespace fs = std::filesystem;
    fs::path here = fs::current_path();
    for (int up = 0; up < 5; ++up)
    {
        if (fs::is_directory(here / "data" / "tuning"))
        {
            return (here / "data" / "tuning").string();
        }
        if (!here.has_parent_path())
        {
            break;
        }
        here = here.parent_path();
    }
    return {};
}

const Tuning& Tune()
{
    static const Tuning t = Tuning::LoadAll(TuningDir());
    return t;
}

constexpr int32_t kTicks = 3600;   // sixty seconds
constexpr uint64_t kSeed = 0x5eed'f00d'1234'5678ULL;

// The state a replay has to reproduce, folded into one number per tick.
struct World
{
    sj::Meters meters = sj::nerve::FreshShift(Tune());
    float yaw{}, pitch{}, height{};
    float depth[4]{};
    sj::Joint joints[4]{};
    bool drawing{};
    float power{};

    World()
    {
        for (int i = 0; i < 4; ++i)
        {
            joints[i].tier = static_cast<sj::JointTier>(i);
            joints[i].quality = 0.2f + 0.2f * static_cast<float>(i);
        }
    }

    void Apply(const Intent& in)
    {
        switch (in.kind)
        {
        case IntentKind::Look:
            yaw += in.a;
            pitch += in.b;
            break;
        case IntentKind::Climb:
            height += in.a * sj::kTick;
            break;
        case IntentKind::SetStance:
            meters.stance = static_cast<sj::Stance>(in.target);
            break;
        case IntentKind::HammerDraw:
            drawing = true;
            break;
        case IntentKind::HammerRelease:
        {
            drawing = false;
            const auto j = static_cast<std::size_t>(in.target);
            const sj::StrikeResult r =
                sj::hammer::Strike(joints[j], depth[j], in.a, in.b, 1.0f, Tune());
            depth[j] += r.depthGain;
            break;
        }
        default:
            break;
        }
    }

    void Step()
    {
        sj::MeterContext ctx{};
        ctx.height = height;
        ctx.windSpeed = 6.0f;
        ctx.working = drawing;
        sj::grip::Step(meters, sj::kTick, ctx, Tune());
        sj::nerve::Step(meters, sj::kTick, ctx, Tune());
    }

    uint64_t Hash() const
    {
        // FNV-1a over the raw bytes: any bit that differs changes the hash.
        uint64_t h = 1469598103934665603ULL;
        auto mix = [&](const void* p, std::size_t n) {
            const auto* b = static_cast<const unsigned char*>(p);
            for (std::size_t i = 0; i < n; ++i)
            {
                h = (h ^ b[i]) * 1099511628211ULL;
            }
        };
        mix(&meters.grip, sizeof(float));
        mix(&meters.nerve, sizeof(float));
        mix(&meters.stance, sizeof(meters.stance));
        mix(&yaw, sizeof(float));
        mix(&pitch, sizeof(float));
        mix(&height, sizeof(float));
        mix(depth, sizeof(depth));
        return h;
    }
};

// A minute of play as a player makes it: the mouse moving most ticks, a held climb key in long
// runs, taps and blows every few seconds, a stance change now and then.
std::vector<IntentBuffer> Synthetic()
{
    sj::Rng rng(kSeed);
    std::vector<IntentBuffer> run(kTicks);
    bool climbing = false;
    for (int32_t t = 0; t < kTicks; ++t)
    {
        IntentBuffer& buf = run[static_cast<std::size_t>(t)];
        if (t % 240 == 0)
        {
            climbing = !climbing;
        }
        if (climbing)
        {
            buf.push_back({IntentKind::Climb, 1.0f, 0.0f, -1});
        }
        if (rng.NextFloat() < 0.8f)
        {
            buf.push_back({IntentKind::Look, (rng.NextFloat() - 0.5f) * 0.02f,
                           (rng.NextFloat() - 0.5f) * 0.01f, -1});
        }
        if (t % 300 == 150)
        {
            buf.push_back({IntentKind::SetStance, 0.0f, 0.0f,
                           static_cast<int32_t>(rng.NextFloat() * 4.99f)});
        }
        if (t % 45 == 20)
        {
            buf.push_back({IntentKind::HammerDraw, 0.0f, 0.0f, -1});
        }
        if (t % 45 == 40)
        {
            buf.push_back({IntentKind::HammerRelease, 0.5f + rng.NextFloat() * 0.5f,
                           rng.NextFloat() * 8.0f, static_cast<int32_t>(t / 45 % 4)});
        }
    }
    return run;
}

std::vector<uint64_t> Play(const std::vector<IntentBuffer>& run)
{
    World w;
    std::vector<uint64_t> trace;
    trace.reserve(run.size());
    for (const IntentBuffer& buf : run)
    {
        for (const Intent& in : buf)
        {
            w.Apply(in);
        }
        w.Step();
        trace.push_back(w.Hash());
    }
    return trace;
}

std::vector<uint64_t> Play(const sj::Replay& replay)
{
    std::vector<IntentBuffer> run(static_cast<std::size_t>(replay.LengthTicks()));
    for (int32_t t = 0; t < replay.LengthTicks(); ++t)
    {
        run[static_cast<std::size_t>(t)] = replay.IntentsAt(t);
    }
    return Play(run);
}

std::string Record(const std::vector<IntentBuffer>& run, const std::string& hash)
{
    sj::Recorder rec("00-greybox", kSeed, hash);
    for (int32_t t = 0; t < static_cast<int32_t>(run.size()); ++t)
    {
        rec.Record(t, run[static_cast<std::size_t>(t)]);
    }
    return rec.ToJson();
}

}  // namespace

TEST_CASE("ReplayRoundtrip: acceptance 1, 3,600 ticks replay to a tick-for-tick identical trace")
{
    const auto run = Synthetic();
    const auto recorded = Play(run);
    const sj::Replay replay = sj::Replay::FromJson(Record(run, Tune().Hash()));

    CHECK(replay.LevelId() == "00-greybox");
    CHECK(replay.Seed() == kSeed);
    CHECK(replay.LengthTicks() == kTicks);

    const auto replayed = Play(replay);
    REQUIRE(replayed.size() == recorded.size());
    int32_t first_diff = -1;
    for (std::size_t i = 0; i < recorded.size() && first_diff < 0; ++i)
    {
        if (recorded[i] != replayed[i])
        {
            first_diff = static_cast<int32_t>(i);
        }
    }
    CHECK(first_diff == -1);

    // And the intents themselves, not just their effect: a replay that dropped an intent with no
    // effect on this toy world would still be a broken replay.
    for (int32_t t = 0; t < kTicks; ++t)
    {
        if (!(replay.IntentsAt(t) == run[static_cast<std::size_t>(t)]))
        {
            FAIL("intents differ at tick " << t);
        }
    }

    // The control: the trace is not trivially constant, so an equal trace means something.
    CHECK(recorded.front() != recorded.back());
}

TEST_CASE("ReplayRoundtrip: acceptance 2, Determinism — replaying twice from one file gives one result")
{
    const std::string file = Record(Synthetic(), Tune().Hash());
    const auto a = Play(sj::Replay::FromJson(file));
    const auto b = Play(sj::Replay::FromJson(file));
    CHECK(a == b);
}

TEST_CASE("ReplayRoundtrip: acceptance 3, a different tuning hash fails and names both hashes")
{
    const std::string file = Record(Synthetic(), "recorded-hash-aaaa");
    const sj::Replay replay = sj::Replay::FromJson(file);
    CHECK_NOTHROW(replay.RequireTuning("recorded-hash-aaaa"));
    try
    {
        replay.RequireTuning(Tune().Hash());
        FAIL("a replay against the wrong tuning was accepted");
    }
    catch (const sj::ReplayError& e)
    {
        const std::string what = e.what();
        CHECK(what.find("recorded-hash-aaaa") != std::string::npos);
        CHECK(what.find(Tune().Hash()) != std::string::npos);
    }
}

TEST_CASE("ReplayRoundtrip: acceptance 4, a sixty-second replay is under 100 KB")
{
    // Synthetic() is close to a worst case: a fresh full-precision mouse delta on 80% of ticks. It
    // comes in at about 99 KB. A real mouse moves in whole counts times a sensitivity, which prints
    // shorter, and sits still for whole seconds.
    const std::string file = Record(Synthetic(), Tune().Hash());
    MESSAGE("60 s replay: " << file.size() << " bytes");
    CHECK(file.size() < 100u * 1024u);
}

TEST_CASE("ReplayRoundtrip: acceptance 5, an idle tick is empty and costs no allocation")
{
    std::vector<IntentBuffer> run(10);
    run[3].push_back({IntentKind::Tap, 0.0f, 0.0f, 7});
    const sj::Replay replay = sj::Replay::FromJson(Record(run, "h"));
    CHECK(replay.IntentsAt(0).empty());
    CHECK(replay.IntentsAt(9).empty());
    CHECK(replay.IntentsAt(-5).empty());
    CHECK(replay.IntentsAt(10'000).empty());
    // Out of range comes back as the replay's one shared empty buffer, by reference: there is
    // nothing to allocate.
    CHECK(&replay.IntentsAt(-5) == &replay.IntentsAt(10'000));
    // In range, an idle tick's buffer has never been given storage.
    CHECK(replay.IntentsAt(0).capacity() == 0u);
    REQUIRE(replay.IntentsAt(3).size() == 1u);
    CHECK(replay.IntentsAt(3)[0].target == 7);
}

TEST_CASE("ReplayRoundtrip: order inside a tick survives the run-length encoding")
{
    // Climb held for three ticks, with a Look in front of it on the middle one. The slot is what
    // keeps Look-then-Climb from coming back as Climb-then-Look.
    std::vector<IntentBuffer> run(3);
    const Intent climb{IntentKind::Climb, 1.0f, 0.0f, -1};
    const Intent look{IntentKind::Look, 0.25f, 0.0f, -1};
    run[0] = {climb};
    run[1] = {look, climb};
    run[2] = {climb};
    const sj::Replay replay = sj::Replay::FromJson(Record(run, "h"));
    for (int32_t t = 0; t < 3; ++t)
    {
        CHECK(replay.IntentsAt(t) == run[static_cast<std::size_t>(t)]);
    }
}

TEST_CASE("ReplayRoundtrip: every float comes back to the bit")
{
    // Values chosen to sit awkwardly in decimal, including denormals and the extremes.
    const float values[] = {0.1f, 1.0f / 3.0f, 3.4028234e38f, 1.17549435e-38f, 1.4e-45f,
                            -0.0f, 16777217.0f, 0.30000001f, 2.7182817f};
    std::vector<IntentBuffer> run(1);
    for (float v : values)
    {
        run[0].push_back({IntentKind::Look, v, -v, -1});
    }
    const sj::Replay replay = sj::Replay::FromJson(Record(run, "h"));
    const IntentBuffer& back = replay.IntentsAt(0);
    REQUIRE(back.size() == run[0].size());
    for (std::size_t i = 0; i < back.size(); ++i)
    {
        CHECK(std::memcmp(&back[i].a, &run[0][i].a, sizeof(float)) == 0);
        CHECK(std::memcmp(&back[i].b, &run[0][i].b, sizeof(float)) == 0);
    }
}

TEST_CASE("ReplayRoundtrip: a malformed file is refused, not half-read")
{
    CHECK_THROWS(sj::Replay::FromJson(R"({"format":2,"level":"x","seed":"1","tuning":"h","ticks":1,"intents":[]})"));
    CHECK_THROWS(sj::Replay::FromJson(R"({"format":1,"level":"x","seed":"1","tuning":"h","ticks":2,"intents":[[0,0,1,0,-1,5]]})"));
    CHECK_THROWS(sj::Replay::FromJson(R"({"format":1,"level":"x","seed":"1","tuning":"h","ticks":2,"intents":[[0,31]]})"));
}
