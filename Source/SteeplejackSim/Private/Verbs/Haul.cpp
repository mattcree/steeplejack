// Hauling on the gin wheel — VERB-007. See Haul.h for the model.

#include "Verbs/Haul.h"

#include "Tuning.h"

#include <algorithm>
#include <cmath>

namespace sj::haul {
namespace {

constexpr float kGravity = 9.81f;                  // literal: g, m/s²
constexpr float kDegPerRad = 57.2957795f;          // literal: unit conversion
constexpr float kShortestRope = 1.0f;              // literal: the load stops a metre under the pulley

float Omega(float ropeM) noexcept
{
    return std::sqrt(kGravity / std::max(ropeM, kShortestRope));
}

}  // namespace

float AmplitudeDeg(const HaulState& s, float topM, const Tuning& t) noexcept
{
    (void)t;
    const float w = Omega(topM - s.height);
    // Where it would get to if it kept all the energy it has: the angle now, and the speed now
    // turned back into angle. Small-angle, which is the regime a load on a rope lives in.
    return std::sqrt(s.swingDeg * s.swingDeg + (s.swingVel / w) * (s.swingVel / w));
}

bool Arrived(const HaulState& s, float topM) noexcept
{
    return s.height >= topM - kShortestRope - 0.05f;   // literal: a hand's width of slack
}

void Step(HaulState& s, float dt, float pull, float steer, float wind, float loadKg, float topM,
          const Tuning& t) noexcept
{
    if (s.fouled)
    {
        return;   // snagged: nothing moves until the game has dealt with it
    }

    const float rope = std::max(topM - s.height, kShortestRope);
    const float w2 = kGravity / rope;
    // A heavier load answers to every push more slowly — the pump, the hand, the wind alike. One
    // ladder section is the reference, because that is what goes up the rope most.
    const float inertia = std::max(loadKg, 1.0f) / t.GetF("ladderMassKg");

    const float haul_speed = std::clamp(pull, 0.0f, 1.0f) * t.GetF("haulSpeedMetresPerSecond");

    // Pump: the jerk of hauling, into whichever way it is already going. From dead still it goes
    // away from the wall, the way a load hauled off a cradle does.
    const float dir = (std::fabs(s.swingVel) > 1e-3f) ? std::copysign(1.0f, s.swingVel) : 1.0f;   // literal: at rest
    const float pump = t.GetF("haulSwingGainPerSpeed") * haul_speed * dir;
    const float hand = t.GetF("haulSwingDampPerSteerInput") * std::clamp(steer, -1.0f, 1.0f);
    const float push = t.GetF("haulWindDegPerS2PerMs") * std::max(wind, 0.0f);
    const float drive = (pump + hand + push) / inertia;   // degrees per second²

    // Semi-implicit Euler: new velocity from the old angle, new angle from the new velocity. The
    // difference from the explicit form is the whole of acceptance 5.
    const float restoring = -w2 * std::sin(s.swingDeg / kDegPerRad) * kDegPerRad;
    const float air = -t.GetF("haulAirDampingPerSecond") * s.swingVel;
    s.swingVel += (restoring + air + drive) * dt;
    s.swingDeg += s.swingVel * dt;

    s.height = std::min(s.height + haul_speed * dt, topM - kShortestRope);

    if (AmplitudeDeg(s, topM, t) > t.GetF("haulFoulAmplitudeDegrees"))
    {
        s.fouled = true;
    }
}

}  // namespace sj::haul
