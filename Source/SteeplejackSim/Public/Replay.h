#pragma once

// Playing a recording back — CORE-006.
//
// A replay is only meaningful against the tuning it was recorded with: change one number in
// climbing.json and the same intents produce a different climb. So a replay knows its tuning hash,
// and `RequireTuning` refuses to go on against any other — loudly, with both hashes — rather than
// quietly producing a different run that looks like a regression.

#include "Export.h"
#include "Intent.h"

#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>

namespace sj {

class SJ_API ReplayError : public std::runtime_error
{
public:
    using std::runtime_error::runtime_error;
};

class SJ_API Replay
{
public:
    static Replay FromJson(const std::string& text);

    const std::string& LevelId() const noexcept { return levelId_; }
    uint64_t Seed() const noexcept { return seed_; }
    const std::string& TuningHash() const noexcept { return tuningHash_; }

    // The intents on one tick. Empty — the same shared empty buffer, no allocation — for a tick on
    // which the player did nothing, which is most of them.
    const IntentBuffer& IntentsAt(int32_t tick) const noexcept;
    int32_t LengthTicks() const noexcept { return length_; }

    // Throws ReplayError naming both hashes unless `currentHash` is the one this was recorded with.
    void RequireTuning(const std::string& currentHash) const;

private:
    std::string levelId_;
    uint64_t    seed_{};
    std::string tuningHash_;
    int32_t     length_{};
    std::vector<IntentBuffer> byTick_;   // index = tick; sized once at load
    IntentBuffer empty_;
};

}  // namespace sj
