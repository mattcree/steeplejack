#pragma once

// Recording a run — CORE-006.
//
// Every intent, per tick, stamped with the level, the seed and the tuning hash. Those three and the
// intents are the whole run: the sim is deterministic (ADR-0003), so the state at any tick is a
// function of them and does not need saving. That is why a sixty-second replay is kilobytes.

#include "Export.h"
#include "Intent.h"

#include <cstdint>
#include <string>
#include <utility>
#include <vector>

namespace sj {

class SJ_API Recorder
{
public:
    Recorder(std::string levelId, uint64_t seed, std::string tuningHash);

    // Ticks must be recorded in order. An empty buffer still advances the length: a run that ends
    // with the player standing still for ten seconds is ten seconds longer than one that does not.
    void Record(int32_t tick, const IntentBuffer& intents);

    std::string ToJson() const;

private:
    // One row covers `repeat` consecutive ticks with the same intent in the same slot.
    struct Row
    {
        int32_t start{};
        int32_t slot{};
        Intent  intent{};
        int32_t repeat{1};
    };

    std::string levelId_;
    uint64_t    seed_{};
    std::string tuningHash_;
    int32_t     lastTick_{-1};
    std::vector<Row>     rows_;
    std::vector<int32_t> open_;   // per slot, the row the previous tick's intent went into, or -1
};

}  // namespace sj
