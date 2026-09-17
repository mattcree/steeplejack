// The JSON reader — CORE-014.
//
// Moved out of Tuning.cpp, where CORE-007 wrote it, and grown a tree. Same accepted subset, same
// rejections, same "origin:line: what" errors — with two deliberate deltas, both verified against
// the old reader by a 50-input differential probe and both recorded in CORE-014's Outcome:
//
//   * `null` now parses to Kind::Null instead of being a parse error, because whether a null is
//     acceptable is the caller's policy. Tuning still rejects one. Consequence: in a document with
//     both a null and a later syntax error, the syntax error is now reported first, since the whole
//     document is parsed before Tuning inspects any leaf.
//   * The \u rejection message no longer says "in tuning files", because this reader serves level
//     files too.
//
// What is new otherwise is that it builds a value rather than only emitting leaves, because
// CORE-008 has to walk level bands in order and check each against its neighbour.

#include "Json.h"

#include <algorithm>
#include <cstring>

namespace sj {
namespace {

constexpr std::size_t kFirstLine = 1;

}  // namespace

// ---------------------------------------------------------------- reader

class JsonReader
{
public:
    JsonReader(const std::string& text, std::string origin)
        : text_(text), origin_(std::move(origin)) {}

    JsonValue ReadDocument()
    {
        SkipSpace();
        JsonValue root = ReadValue();
        SkipSpace();
        if (pos_ < text_.size())
        {
            Fail("trailing content after the top-level value");
        }
        return root;
    }

private:
    [[noreturn]] void Fail(const std::string& why) const
    {
        throw JsonError(origin_, Line(), why);
    }

    std::size_t Line() const
    {
        const auto upto = text_.begin() + static_cast<std::ptrdiff_t>(std::min(pos_, text_.size()));
        return static_cast<std::size_t>(std::count(text_.begin(), upto, '\n')) + kFirstLine;
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
                // data-schemas.md writes these files as jsonc, with line comments.
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

    JsonValue Begin(JsonValue::Kind kind) const
    {
        JsonValue v;
        v.kind_ = kind;
        v.origin_ = origin_;
        v.line_ = Line();
        return v;
    }

    JsonValue ReadValue()
    {
        SkipSpace();
        switch (Peek())
        {
        case '{': return ReadObject();
        case '[': return ReadArray();
        case '"':
        {
            JsonValue v = Begin(JsonValue::Kind::String);
            v.text_ = ReadString();
            return v;
        }
        case 't':
        {
            JsonValue v = Begin(JsonValue::Kind::Bool);
            ReadLiteral("true");
            v.boolean_ = true;
            return v;
        }
        case 'f':
        {
            JsonValue v = Begin(JsonValue::Kind::Bool);
            ReadLiteral("false");
            v.boolean_ = false;
            return v;
        }
        case 'n':
        {
            // Parsed, not rejected. Whether a null is acceptable is the caller's policy: Tuning
            // refuses one because a null tuning value would reach a getter as a zero, which is the
            // failure that loader exists to prevent. A level file might legitimately use one.
            JsonValue v = Begin(JsonValue::Kind::Null);
            ReadLiteral("null");
            return v;
        }
        default:
        {
            JsonValue v = Begin(JsonValue::Kind::Number);
            v.number_ = ReadNumber();
            return v;
        }
        }
    }

    JsonValue ReadObject()
    {
        JsonValue v = Begin(JsonValue::Kind::Object);
        Expect('{');
        SkipSpace();
        if (Peek() == '}')
        {
            ++pos_;
            return v;
        }
        for (;;)
        {
            SkipSpace();
            std::string key = ReadString();
            SkipSpace();
            Expect(':');
            v.members_.emplace_back(std::move(key), ReadValue());
            SkipSpace();
            if (Peek() == ',')
            {
                ++pos_;
                continue;
            }
            Expect('}');
            return v;
        }
    }

    JsonValue ReadArray()
    {
        JsonValue v = Begin(JsonValue::Kind::Array);
        Expect('[');
        SkipSpace();
        if (Peek() == ']')
        {
            ++pos_;
            return v;
        }
        for (;;)
        {
            v.elements_.push_back(ReadValue());
            SkipSpace();
            if (Peek() == ',')
            {
                ++pos_;
                continue;
            }
            Expect(']');
            return v;
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
        for (;;)
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
            switch (const char e = text_[pos_++])
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
                // Decoding UTF-16 surrogate pairs and getting it quietly wrong is worse than
                // saying so. No key or value in the data needs one.
                Fail("\\u escapes are not supported");
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
            anyDigit = anyDigit || (c >= '0' && c <= '9');  // literal: digit range, not a tunable
            ++pos_;
        }
        if (!anyDigit)
        {
            Fail("expected a value");
        }
        const std::string token = text_.substr(start, pos_ - start);
        std::size_t used = 0;
        double value = 0.0;
        try
        {
            value = std::stod(token, &used);
        }
        catch (const std::exception&)
        {
            Fail("malformed number '" + token + "'");
        }
        if (used != token.size())
        {
            Fail("malformed number '" + token + "'");
        }
        return value;
    }

    const std::string& text_;
    std::string        origin_;
    std::size_t        pos_{0};
};

// ---------------------------------------------------------------- JsonValue

JsonValue JsonValue::Parse(const std::string& text, const std::string& origin)
{
    JsonReader reader(text, origin);
    return reader.ReadDocument();
}

const char* JsonValue::KindName() const noexcept
{
    switch (kind_)
    {
    case Kind::Object: return "an object";
    case Kind::Array:  return "an array";
    case Kind::Number: return "a number";
    case Kind::String: return "a string";
    case Kind::Bool:   return "true or false";
    case Kind::Null:   return "null";
    }
    return "a value";
}

void JsonValue::FailKind(const char* wanted) const
{
    throw JsonError(origin_, line_,
                    std::string("expected ") + wanted + " but found " + KindName());
}

bool JsonValue::Has(std::string_view key) const noexcept
{
    if (kind_ != Kind::Object)
    {
        return false;
    }
    return std::any_of(members_.begin(), members_.end(),
                       [key](const auto& m) { return m.first == key; });
}

const JsonValue& JsonValue::At(std::string_view key) const
{
    if (kind_ != Kind::Object)
    {
        FailKind("an object");
    }
    const auto it = std::find_if(members_.begin(), members_.end(),
                                 [key](const auto& m) { return m.first == key; });
    if (it == members_.end())
    {
        throw JsonError(origin_, line_, "no member '" + std::string(key) + "'");
    }
    return it->second;
}

const JsonValue& JsonValue::At(std::size_t index) const
{
    if (kind_ != Kind::Array)
    {
        FailKind("an array");
    }
    if (index >= elements_.size())
    {
        throw JsonError(origin_, line_,
                        "index " + std::to_string(index) + " is past the end of an array of " +
                        std::to_string(elements_.size()));
    }
    return elements_[index];
}

std::size_t JsonValue::Size() const noexcept
{
    switch (kind_)
    {
    case Kind::Object: return members_.size();
    case Kind::Array:  return elements_.size();
    default:           return 0;
    }
}

double JsonValue::AsNumber() const
{
    if (kind_ != Kind::Number)
    {
        FailKind("a number");
    }
    return number_;
}

const std::string& JsonValue::AsString() const
{
    if (kind_ != Kind::String)
    {
        FailKind("a string");
    }
    return text_;
}

bool JsonValue::AsBool() const
{
    if (kind_ != Kind::Bool)
    {
        FailKind("true or false");
    }
    return boolean_;
}

void JsonValue::ForEachLeaf(const LeafVisitor& visit) const
{
    Visit("", visit);
}

void JsonValue::Visit(const std::string& path, const LeafVisitor& visit) const
{
    const auto join = [&path](const std::string& leaf)
    {
        return path.empty() ? leaf : path + "." + leaf;
    };

    switch (kind_)
    {
    case Kind::Object:
        for (const auto& [key, value] : members_)
        {
            value.Visit(join(key), visit);
        }
        return;
    case Kind::Array:
        for (std::size_t i = 0; i < elements_.size(); ++i)
        {
            elements_[i].Visit(join(std::to_string(i)), visit);
        }
        return;
    default:
        // An empty object or array contributes no leaves, which is why this is not `visit(...)`
        // on every node: a key that holds nothing is not a key.
        visit(path, *this);
        return;
    }
}

}  // namespace sj
