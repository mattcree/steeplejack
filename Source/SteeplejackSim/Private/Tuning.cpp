// Tuning loader — CORE-007.
//
// A self-contained JSON reader and a SHA-256, because SteeplejackSim has no third-party
// dependencies by design: it must configure and build under CMake with nothing but a compiler
// (ADR-0004). Both are small, and both are fully covered by tests/unit/test_tuning.cpp — the
// SHA-256 against the FIPS 180-4 published vectors.
//
// The JSON is flattened at load into one map of dotted path -> value, so lookup is a single
// map probe with no tree walk per call, and so a nested file and a flat file are the same
// thing to a caller.

#include "Tuning.h"

#include <algorithm>
#include <array>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <sstream>

namespace sj {
namespace {

// ---------------------------------------------------------------- key normalisation

// "gripDrainPerSecond.oneHand" and "grip_drain_per_second.one_hand" are the same key. Case and
// underscores carry no meaning here, only house style, and the two styles are both in use: the
// JSON files are camelCase, the GDD prose is snake_case. Making them equal is cheaper than
// making everyone remember which is which.
std::string Normalise(std::string_view key)
{
    std::string out;
    out.reserve(key.size());
    for (const char c : key)
    {
        if (c == '_' || c == '-')
        {
            continue;
        }
        out.push_back(static_cast<char>((c >= 'A' && c <= 'Z') ? c - 'A' + 'a' : c));
    }
    return out;
}

// ---------------------------------------------------------------- JSON

// A recursive-descent reader for the JSON subset the tuning files use: objects, arrays, numbers,
// strings, booleans. It flattens as it goes rather than building a tree, because nothing needs
// the tree. Arrays become indexed keys ("reputation.starThresholds.0"), which keeps them
// reachable without adding an array accessor to the interface.
class JsonReader
{
public:
    JsonReader(const std::string& text, std::string origin)
        : text_(text), origin_(std::move(origin)) {}

    // Emits (path, value) for every leaf.
    template <typename Emit>
    void ReadDocument(const Emit& emit)
    {
        SkipSpace();
        ReadValue("", emit);
        SkipSpace();
        if (pos_ < text_.size())
        {
            Fail("trailing content after the top-level value");
        }
    }

private:
    [[noreturn]] void Fail(const std::string& why) const
    {
        throw TuningError(origin_ + ":" + std::to_string(Line()) + ": " + why);
    }

    std::size_t Line() const
    {
        return static_cast<std::size_t>(
                   std::count(text_.begin(),
                              text_.begin() + static_cast<std::ptrdiff_t>(
                                                  std::min(pos_, text_.size())),
                              '\n')) + 1u;
    }

    void SkipSpace()
    {
        while (pos_ < text_.size())
        {
            const char c = text_[pos_];
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r')
            {
                ++pos_;
            }
            else if (c == '/' && pos_ + 1 < text_.size() && text_[pos_ + 1] == '/')
            {
                // The data-schemas doc writes these files as jsonc, with line comments.
                while (pos_ < text_.size() && text_[pos_] != '\n')
                {
                    ++pos_;
                }
            }
            else
            {
                break;
            }
        }
    }

    char Peek() const
    {
        if (pos_ >= text_.size())
        {
            Fail("unexpected end of file");
        }
        return text_[pos_];
    }

    void Expect(char c)
    {
        if (Peek() != c)
        {
            Fail(std::string("expected '") + c + "' but found '" + text_[pos_] + "'");
        }
        ++pos_;
    }

    static std::string Join(const std::string& prefix, const std::string& leaf)
    {
        return prefix.empty() ? leaf : prefix + "." + leaf;
    }

    template <typename Emit>
    void ReadValue(const std::string& path, const Emit& emit)
    {
        SkipSpace();
        switch (Peek())
        {
        case '{': ReadObject(path, emit); return;
        case '[': ReadArray(path, emit); return;
        case '"': emit(path, ReadString()); return;
        case 't': ReadLiteral("true");  emit(path, true);  return;
        case 'f': ReadLiteral("false"); emit(path, false); return;
        case 'n': ReadLiteral("null");
            // Deliberately fatal. A null tuning value would reach a getter as either a missing
            // key or a zero, and both of those are the failure this loader exists to prevent.
            Fail("null is not a tuning value — remove the key or give it a value");
        default:  emit(path, ReadNumber()); return;
        }
    }

    template <typename Emit>
    void ReadObject(const std::string& path, const Emit& emit)
    {
        Expect('{');
        SkipSpace();
        if (Peek() == '}')
        {
            ++pos_;
            return;
        }
        for (;;)
        {
            SkipSpace();
            const std::string key = ReadString();
            SkipSpace();
            Expect(':');
            ReadValue(Join(path, key), emit);
            SkipSpace();
            if (Peek() == ',')
            {
                ++pos_;
                continue;
            }
            Expect('}');
            return;
        }
    }

    template <typename Emit>
    void ReadArray(const std::string& path, const Emit& emit)
    {
        Expect('[');
        SkipSpace();
        if (Peek() == ']')
        {
            ++pos_;
            return;
        }
        for (std::size_t i = 0;; ++i)
        {
            ReadValue(Join(path, std::to_string(i)), emit);
            SkipSpace();
            if (Peek() == ',')
            {
                ++pos_;
                continue;
            }
            Expect(']');
            return;
        }
    }

    void ReadLiteral(const char* word)
    {
        const std::size_t n = std::strlen(word);
        if (text_.compare(pos_, n, word) != 0)
        {
            Fail(std::string("expected '") + word + "'");
        }
        pos_ += n;
    }

    std::string ReadString()
    {
        Expect('"');
        std::string out;
        while (true)
        {
            if (pos_ >= text_.size())
            {
                Fail("unterminated string");
            }
            const char c = text_[pos_++];
            if (c == '"')
            {
                return out;
            }
            if (c != '\\')
            {
                out.push_back(c);
                continue;
            }
            if (pos_ >= text_.size())
            {
                Fail("unterminated escape");
            }
            const char e = text_[pos_++];
            switch (e)
            {
            case '"':  out.push_back('"');  break;
            case '\\': out.push_back('\\'); break;
            case '/':  out.push_back('/');  break;
            case 'b':  out.push_back('\b'); break;
            case 'f':  out.push_back('\f'); break;
            case 'n':  out.push_back('\n'); break;
            case 'r':  out.push_back('\r'); break;
            case 't':  out.push_back('\t'); break;
            case 'u':
                // No tuning key or value needs one, and decoding UTF-16 surrogate pairs to get
                // it wrong quietly is worse than saying so.
                Fail("\\u escapes are not supported in tuning files");
                break;
            default:
                Fail(std::string("unknown escape '\\") + e + "'");
            }
        }
    }

    double ReadNumber()
    {
        const std::size_t start = pos_;
        if (pos_ < text_.size() && (text_[pos_] == '-' || text_[pos_] == '+'))
        {
            ++pos_;
        }
        bool anyDigit = false;
        while (pos_ < text_.size())
        {
            const char c = text_[pos_];
            const bool part = (c >= '0' && c <= '9') || c == '.' || c == 'e' || c == 'E' ||
                              ((c == '-' || c == '+') && (text_[pos_ - 1] == 'e' ||
                                                          text_[pos_ - 1] == 'E'));
            if (!part)
            {
                break;
            }
            anyDigit = anyDigit || (c >= '0' && c <= '9');
            ++pos_;
        }
        if (!anyDigit)
        {
            Fail("expected a value");
        }
        const std::string token = text_.substr(start, pos_ - start);
        try
        {
            std::size_t used = 0;
            const double v = std::stod(token, &used);
            if (used != token.size())
            {
                Fail("malformed number '" + token + "'");
            }
            return v;
        }
        catch (const TuningError&)
        {
            throw;
        }
        catch (const std::exception&)
        {
            Fail("malformed number '" + token + "'");
        }
    }

    const std::string& text_;
    std::string        origin_;
    std::size_t        pos_{0};
};

// ---------------------------------------------------------------- SHA-256
//
// FIPS 180-4. Here rather than in a library because SteeplejackSim takes no dependencies, and
// hand-rolled rather than approximated because the digest is stamped into every replay file and
// has to mean the same thing in five years. Verified against the published test vectors.

constexpr std::array<uint32_t, 64> kRoundConstants = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
};

constexpr std::array<uint32_t, 8> kInitialHash = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
};

constexpr uint32_t kWordBits = 32;
constexpr std::array<uint32_t, 3> kSigma0Rotations = {7, 18, 3};    // small sigma 0
constexpr std::array<uint32_t, 3> kSigma1Rotations = {17, 19, 10};  // small sigma 1
constexpr std::array<uint32_t, 3> kUpper0Rotations = {2, 13, 22};   // capital sigma 0
constexpr std::array<uint32_t, 3> kUpper1Rotations = {6, 11, 25};   // capital sigma 1

uint32_t Rotr(uint32_t x, uint32_t n) noexcept
{
    return (x >> n) | (x << (kWordBits - n));
}

std::string Sha256(const std::string& data)
{
    std::array<uint32_t, 8> h = kInitialHash;

    // Pad: 0x80, then zeroes, then the bit length as a 64-bit big-endian integer.
    std::string msg = data;
    const uint64_t bitLength = static_cast<uint64_t>(data.size()) * 8u;
    msg.push_back(static_cast<char>(0x80));
    while (msg.size() % 64u != 56u)
    {
        msg.push_back('\0');
    }
    for (int i = 7; i >= 0; --i)
    {
        msg.push_back(static_cast<char>((bitLength >> (static_cast<uint32_t>(i) * 8u)) & 0xffu));
    }

    std::array<uint32_t, 64> w{};
    for (std::size_t block = 0; block < msg.size(); block += 64u)
    {
        for (std::size_t t = 0; t < 16u; ++t)
        {
            w[t] = 0;
            for (std::size_t b = 0; b < 4u; ++b)
            {
                const auto byte = static_cast<uint32_t>(
                    static_cast<unsigned char>(msg[block + t * 4u + b]));
                w[t] = (w[t] << 8u) | byte;
            }
        }
        for (std::size_t t = 16; t < 64u; ++t)
        {
            const uint32_t s0 = Rotr(w[t - 15u], kSigma0Rotations[0]) ^
                                Rotr(w[t - 15u], kSigma0Rotations[1]) ^
                                (w[t - 15u] >> kSigma0Rotations[2]);
            const uint32_t s1 = Rotr(w[t - 2u], kSigma1Rotations[0]) ^
                                Rotr(w[t - 2u], kSigma1Rotations[1]) ^
                                (w[t - 2u] >> kSigma1Rotations[2]);
            w[t] = w[t - 16u] + s0 + w[t - 7u] + s1;
        }

        uint32_t a = h[0], b = h[1], c = h[2], d = h[3];
        uint32_t e = h[4], f = h[5], g = h[6], hh = h[7];

        for (std::size_t t = 0; t < 64u; ++t)
        {
            const uint32_t s1 = Rotr(e, kUpper1Rotations[0]) ^ Rotr(e, kUpper1Rotations[1]) ^
                                Rotr(e, kUpper1Rotations[2]);
            const uint32_t ch = (e & f) ^ (~e & g);
            const uint32_t t1 = hh + s1 + ch + kRoundConstants[t] + w[t];
            const uint32_t s0 = Rotr(a, kUpper0Rotations[0]) ^ Rotr(a, kUpper0Rotations[1]) ^
                                Rotr(a, kUpper0Rotations[2]);
            const uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
            const uint32_t t2 = s0 + maj;

            hh = g; g = f; f = e; e = d + t1;
            d = c;  c = b; b = a; a = t1 + t2;
        }

        h[0] += a; h[1] += b; h[2] += c; h[3] += d;
        h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
    }

    static const char* kHexDigits = "0123456789abcdef";
    std::string out;
    out.reserve(64u);
    for (const uint32_t word : h)
    {
        for (int shift = 28; shift >= 0; shift -= 4)
        {
            out.push_back(kHexDigits[(word >> static_cast<uint32_t>(shift)) & 0xfu]);
        }
    }
    return out;
}

// How close two keys are, so a typo can be answered with "did you mean". Levenshtein, on
// normalised keys, computed only on the error path.
std::size_t EditDistance(const std::string& a, const std::string& b)
{
    std::vector<std::size_t> prev(b.size() + 1u), cur(b.size() + 1u);
    for (std::size_t j = 0; j <= b.size(); ++j)
    {
        prev[j] = j;
    }
    for (std::size_t i = 1; i <= a.size(); ++i)
    {
        cur[0] = i;
        for (std::size_t j = 1; j <= b.size(); ++j)
        {
            const std::size_t cost = (a[i - 1u] == b[j - 1u]) ? 0u : 1u;
            cur[j] = std::min({prev[j] + 1u, cur[j - 1u] + 1u, prev[j - 1u] + cost});
        }
        prev = cur;
    }
    return prev[b.size()];
}

}  // namespace

// ---------------------------------------------------------------- Tuning

Tuning Tuning::Parse(const std::string& json, const std::string& origin)
{
    Tuning t;
    t.sources_.push_back(origin);

    JsonReader reader(json, origin);
    const auto emit = [&t, &origin](const std::string& path, auto&& raw)
    {
        Value v;
        v.origin = origin;
        v.spelling = path;
        using Raw = std::decay_t<decltype(raw)>;
        if constexpr (std::is_same_v<Raw, bool>)
        {
            v.kind = Kind::Bool;
            v.boolean = raw;
        }
        else if constexpr (std::is_same_v<Raw, double>)
        {
            v.kind = Kind::Number;
            v.number = raw;
        }
        else
        {
            v.kind = Kind::String;
            v.text = raw;
        }

        std::string norm;
        std::size_t segStart = 0;
        for (std::size_t i = 0; i <= path.size(); ++i)
        {
            if (i == path.size() || path[i] == '.')
            {
                if (!norm.empty())
                {
                    norm.push_back('.');
                }
                norm += Normalise(std::string_view(path).substr(segStart, i - segStart));
                segStart = i + 1u;
            }
        }

        const auto it = t.values_.find(norm);
        if (it != t.values_.end())
        {
            throw TuningError("tuning key collision: '" + path + "' in " + origin +
                              " and '" + it->second.spelling + "' in " + it->second.origin +
                              " both normalise to '" + norm +
                              "' — two spellings of one key is ambiguous, rename one");
        }
        t.values_.emplace(norm, std::move(v));
    };
    reader.ReadDocument(emit);
    return t;
}

Tuning Tuning::LoadAll(const std::string& dir)
{
    namespace fs = std::filesystem;

    std::error_code ec;
    if (!fs::is_directory(dir, ec))
    {
        throw TuningError("tuning directory '" + dir + "' does not exist or is not a directory");
    }

    std::vector<std::string> files;
    for (const auto& entry : fs::directory_iterator(dir, ec))
    {
        if (entry.is_regular_file() && entry.path().extension() == ".json")
        {
            files.push_back(entry.path().string());
        }
    }
    // Sorted so that a collision is reported against the same file every run, and so that load
    // order does not depend on the filesystem.
    std::sort(files.begin(), files.end());

    if (files.empty())
    {
        throw TuningError("no *.json tuning files in '" + dir + "'");
    }

    Tuning all;
    for (const std::string& path : files)
    {
        std::ifstream in(path, std::ios::binary);
        if (!in)
        {
            throw TuningError("cannot read tuning file '" + path + "'");
        }
        std::ostringstream buf;
        buf << in.rdbuf();

        const std::string name = std::filesystem::path(path).filename().string();
        Tuning one = Parse(buf.str(), name);

        for (auto& [key, value] : one.values_)
        {
            const auto it = all.values_.find(key);
            if (it != all.values_.end())
            {
                throw TuningError("tuning key '" + value.spelling + "' in " + value.origin +
                                  " collides with '" + it->second.spelling + "' in " +
                                  it->second.origin + " — each key must live in exactly one file");
            }
            all.values_.emplace(key, std::move(value));
        }
        all.sources_.push_back(name);
    }
    return all;
}

void Tuning::ThrowMissing(std::string_view key, const char* wanted) const
{
    const std::string norm = Normalise(key);

    std::string best;
    std::size_t bestDistance = std::string::npos;
    for (const auto& [candidate, value] : values_)
    {
        const std::size_t d = EditDistance(norm, candidate);
        if (d < bestDistance)
        {
            bestDistance = d;
            best = value.spelling + "' in " + value.origin;
        }
    }

    std::string files;
    for (const std::string& s : sources_)
    {
        files += (files.empty() ? "" : ", ") + s;
    }

    std::string msg = "tuning key '" + std::string(key) + "' (" + wanted +
                      ") was not found in any of: " + (files.empty() ? "<nothing loaded>" : files);
    if (!best.empty())
    {
        msg += ". Did you mean '" + best + "?";
    }
    msg += " Tuning never returns a default — a silently-zero constant is worse than a crash.";
    throw TuningError(msg);
}

const Tuning::Value& Tuning::Find(std::string_view key, const char* wanted) const
{
    const auto it = values_.find(Normalise(key));
    if (it == values_.end())
    {
        ThrowMissing(key, wanted);
    }
    return it->second;
}

float Tuning::GetF(std::string_view key) const
{
    const Value& v = Find(key, "a number");
    if (v.kind != Kind::Number)
    {
        throw TuningError("tuning key '" + std::string(key) + "' in " + v.origin +
                          " is not a number");
    }
    return static_cast<float>(v.number);
}

int32_t Tuning::GetI(std::string_view key) const
{
    const Value& v = Find(key, "an integer");
    if (v.kind != Kind::Number)
    {
        throw TuningError("tuning key '" + std::string(key) + "' in " + v.origin +
                          " is not a number");
    }
    const double rounded = (v.number < 0.0) ? -static_cast<double>(static_cast<int64_t>(-v.number))
                                            : static_cast<double>(static_cast<int64_t>(v.number));
    if (rounded != v.number)
    {
        throw TuningError("tuning key '" + std::string(key) + "' in " + v.origin + " is " +
                          std::to_string(v.number) + ", which is not a whole number — use GetF");
    }
    return static_cast<int32_t>(v.number);
}

bool Tuning::GetB(std::string_view key) const
{
    const Value& v = Find(key, "a boolean");
    if (v.kind != Kind::Bool)
    {
        throw TuningError("tuning key '" + std::string(key) + "' in " + v.origin +
                          " is not true or false");
    }
    return v.boolean;
}

bool Tuning::Has(std::string_view key) const noexcept
{
    return values_.find(Normalise(key)) != values_.end();
}

std::vector<std::string> Tuning::Keys() const
{
    std::vector<std::string> out;
    out.reserve(values_.size());
    for (const auto& [key, value] : values_)
    {
        (void)value;
        out.push_back(key);
    }
    return out;  // std::map already orders them
}

std::string Tuning::Hash() const
{
    // Canonical form: normalised key, a type tag, then the value's raw bytes. Raw bytes rather
    // than a printed number on purpose — a printed double loses precision at whatever the format
    // chooses, and two values that differ below that cutoff would hash the same. The digest goes
    // into replay files, so "close enough" is not.
    std::string canonical;
    canonical.reserve(values_.size() * 48u);
    for (const auto& [key, value] : values_)
    {
        canonical += key;
        canonical.push_back('=');
        canonical.push_back(static_cast<char>(value.kind));
        switch (value.kind)
        {
        case Kind::Number:
        {
            std::array<char, sizeof(double)> bytes{};
            std::memcpy(bytes.data(), &value.number, sizeof(double));
            canonical.append(bytes.data(), bytes.size());
            break;
        }
        case Kind::Bool:
            canonical.push_back(value.boolean ? '1' : '0');
            break;
        case Kind::String:
            canonical += value.text;
            break;
        }
        canonical.push_back('\n');
    }
    return Sha256(canonical);
}

}  // namespace sj
