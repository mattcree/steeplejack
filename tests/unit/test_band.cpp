// Getting a steel band round a cracked chimney — the BAND archetype.
//
// One property matters more than the rest of this file: **tightening opposite pairs must beat
// working round the ring in order.** That is the whole verb. If the two ever score the same, the
// archetype has no puzzle in it and is just a button pressed eight times, so it is asserted
// directly and in both directions rather than left to emerge from a feel test.

#include "doctest.h"

#include "Band.h"
#include "Tuning.h"

#include <cmath>
#include <filesystem>
#include <string>
#include <vector>

using sj::Band;
using sj::BandFit;
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

// The star: 0, half way round, a quarter, three quarters, and so on — the order any fitter pulls
// up a flange in.
std::vector<int32_t> StarOrder(int32_t n)
{
    std::vector<int32_t> out;
    std::vector<bool> taken(static_cast<std::size_t>(n), false);
    int32_t at = 0;
    for (int32_t i = 0; i < n; ++i)
    {
        while (taken[static_cast<std::size_t>(at % n)])
        {
            at = (at + 1) % n;
        }
        out.push_back(at % n);
        taken[static_cast<std::size_t>(at % n)] = true;
        at = (at + n / 2 + 1) % n;
    }
    return out;
}

// Pull every bolt all the way up, in the order given, a pull at a time.
Band RunOrder(const std::vector<int32_t>& order, int32_t n)
{
    const Tuning& t = Tune();
    Band b;
    b.Begin(n, t);
    const float per = t.GetF("bandTightenPerPull");
    const int pulls = static_cast<int>(std::ceil(1.0f / per)) + 1;
    for (int round = 0; round < pulls; ++round)
    {
        for (const int32_t bolt : order)
        {
            b.Tighten(bolt, per, t);
        }
    }
    return b;
}

}  // namespace

TEST_CASE("Band: the star sequence beats working round the ring, which is the whole verb")
{
    const Tuning& t = Tune();
    const int32_t n = 8;

    std::vector<int32_t> in_order;
    for (int32_t i = 0; i < n; ++i)
    {
        in_order.push_back(i);
    }

    const Band star = RunOrder(StarOrder(n), n);
    const Band round_it = RunOrder(in_order, n);

    const sj::BandState s = star.State(t);
    const sj::BandState r = round_it.State(t);

    CHECK(star.SequenceQuality() > round_it.SequenceQuality());
    CHECK(s.ovality < r.ovality);
    // Both end with every bolt hard up; only the order they got there differs.
    CHECK(s.slackest == doctest::Approx(r.slackest));
    CHECK(s.seated);
    CHECK_FALSE(r.seated);
    CHECK(r.fit == BandFit::Oval);
}

TEST_CASE("Band: a band nobody has touched is loose, not oval")
{
    const Tuning& t = Tune();
    Band b;
    b.Begin(8, t);
    const sj::BandState s = b.State(t);
    CHECK(s.fit == BandFit::Loose);
    CHECK(s.tightened == 0);
    CHECK_FALSE(s.seated);
    CHECK(s.ovality < t.GetF("bandOvalWarnAt"));
}

TEST_CASE("Band: half way up and true is a band in progress, not a failure")
{
    const Tuning& t = Tune();
    const int32_t n = 8;
    Band b;
    b.Begin(n, t);
    for (const int32_t bolt : StarOrder(n))
    {
        b.Tighten(bolt, 0.3f, t);
    }
    const sj::BandState s = b.State(t);
    CHECK(s.fit == BandFit::True);
    CHECK_FALSE(s.seated);
    CHECK(s.tightened == 0);          // nothing is up to seating tension yet
}

TEST_CASE("Band: one bolt out of order is a wobble, not a verdict")
{
    const Tuning& t = Tune();
    const int32_t n = 8;
    std::vector<int32_t> order = StarOrder(n);
    std::swap(order[2], order[3]);    // one pair done the wrong way about

    const Band b = RunOrder(order, n);
    const sj::BandState s = b.State(t);
    CHECK(s.seated);
    CHECK(s.ovality < t.GetF("bandOvalFailAt"));
}

TEST_CASE("Band: pulling one side hard up and leaving the other is the way to ruin it")
{
    const Tuning& t = Tune();
    const int32_t n = 8;
    Band b;
    b.Begin(n, t);
    // Four adjacent bolts hard up, four barely touched: the shape the trade means by oval.
    for (int round = 0; round < 6; ++round)
    {
        for (int32_t i = 0; i < 4; ++i)
        {
            b.Tighten(i, t.GetF("bandTightenPerPull"), t);
        }
    }
    const sj::BandState s = b.State(t);
    CHECK(s.ovality > t.GetF("bandOvalFailAt"));
    CHECK(s.fit == BandFit::Oval);
    CHECK(s.tightest > s.slackest);
}

TEST_CASE("Band: how many bolts it has comes from the level, not from here")
{
    const Tuning& t = Tune();
    // Four segments of two bolts on one real job; a hundred and twenty sections and two hundred
    // and forty bolts on another. Both have to work.
    for (const int32_t n : {4, 8, 16, 24})
    {
        const Band b = RunOrder(StarOrder(n), n);
        const sj::BandState s = b.State(t);
        CHECK(s.bolts == n);
        CHECK(s.seated);
        CHECK(s.tightened == n);
    }
}

TEST_CASE("Band: a bolt that is not on the band cannot be pulled")
{
    const Tuning& t = Tune();
    Band b;
    b.Begin(6, t);
    CHECK(b.Tighten(0, 0.5f, t));
    CHECK_FALSE(b.Tighten(6, 0.5f, t));
    CHECK_FALSE(b.Tighten(-1, 0.5f, t));
}
