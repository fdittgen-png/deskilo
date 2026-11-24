// SPDX-License-Identifier: AGPL-3.0-or-later
#include "terminal_contract.hpp"

#include "cJSON.h"
#include <cmath>
#include <cstring>
#include <initializer_list>
#include <memory>
#include <string>
#include <vector>

namespace deskilo::terminal {
namespace {
using Code = ValidationCode;
using Json = std::unique_ptr<cJSON, decltype(&cJSON_Delete)>;

bool digit(char value) { return value >= '0' && value <= '9'; }

// cJSON accepts some non-JSON numeric spellings; reject them before allocating.
bool number_token(std::string_view source, std::size_t& index) {
  auto end = index;
  if (source[end] == '-') ++end;
  if (end == source.size() || !digit(source[end])) return false;
  if (source[end] == '0') ++end;
  else while (end < source.size() && digit(source[end])) ++end;
  if (end < source.size() && source[end] == '.') {
    ++end;
    const auto fraction = end;
    while (end < source.size() && digit(source[end])) ++end;
    if (end == fraction) return false;
  }
  if (end < source.size() && (source[end] == 'e' || source[end] == 'E')) {
    ++end;
    if (end < source.size() && (source[end] == '+' || source[end] == '-')) ++end;
    const auto exponent = end;
    while (end < source.size() && digit(source[end])) ++end;
    if (end == exponent) return false;
  }
  if (end < source.size()) {
    const auto next = source[end];
    if (next != ' ' && next != '\n' && next != '\r' && next != '\t' &&
        next != ',' && next != '}' && next != ']') return false;
  }
  index = end - 1;
  return true;
}

bool valid_utf8(std::string_view text) {
  for (std::size_t i = 0; i < text.size();) {
    const auto first = static_cast<unsigned char>(text[i++]);
    if (first < 0x80) continue;
    std::uint32_t point = 0;
    unsigned count = 0;
    std::uint32_t minimum = 0;
    if (first >= 0xc2 && first <= 0xdf) { point = first & 0x1f; count = 1; minimum = 0x80; }
    else if (first >= 0xe0 && first <= 0xef) { point = first & 0x0f; count = 2; minimum = 0x800; }
    else if (first >= 0xf0 && first <= 0xf4) { point = first & 0x07; count = 3; minimum = 0x10000; }
    else return false;
    if (i + count > text.size()) return false;
    for (unsigned n = 0; n < count; ++n) {
      const auto next = static_cast<unsigned char>(text[i++]);
      if ((next & 0xc0) != 0x80) return false;
      point = (point << 6) | (next & 0x3f);
    }
    if (point < minimum || point > 0x10ffff || (point >= 0xd800 && point <= 0xdfff)) return false;
  }
  return true;
}

Code envelope(std::string_view text) {
  if (text.size() > ContractLimits::max_response_bytes) return Code::payload_too_large;
  if (!valid_utf8(text)) return Code::invalid_utf8;
  bool quoted = false;
  bool escaped = false;
  std::size_t depth = 0;
  for (std::size_t i = 0; i < text.size(); ++i) {
    const auto c = text[i];
    if (c == '\0') return Code::invalid_json;
    if (quoted) {
      if (static_cast<unsigned char>(c) < 0x20) return Code::invalid_json;
      if (escaped) {
        if (c == 'u' && text.substr(i, 5) == "u0000") return Code::invalid_json;
        escaped = false;
      } else if (c == '\\') escaped = true;
      else if (c == '"') quoted = false;
    } else if (static_cast<unsigned char>(c) < 0x20 && c != '\n' && c != '\r' && c != '\t') return Code::invalid_json;
    else if (c == '-' || digit(c)) {
      if (!number_token(text, i)) return Code::invalid_json;
    } else if (c == '"') quoted = true;
    else if (c == '{' || c == '[') {
      if (++depth > ContractLimits::max_depth) return Code::capacity_exceeded;
    } else if (c == '}' || c == ']') {
      if (depth == 0) return Code::invalid_json;
      --depth;
    }
  }
  return quoted || escaped || depth != 0 ? Code::invalid_json : Code::ok;
}

const cJSON* field(const cJSON* value, const char* name) {
  return cJSON_GetObjectItemCaseSensitive(value, name);
}

bool members(const cJSON* value, std::initializer_list<std::string_view> names) {
  if (!cJSON_IsObject(value)) return false;
  for (auto* child = value->child; child; child = child->next) {
    if (!child->string) return false;
    const std::string_view name(child->string);
    bool known = false;
    for (const auto allowed : names) known = known || name == allowed;
    if (!known) return false;
    for (auto* prior = value->child; prior != child; prior = prior->next) {
      if (std::strcmp(prior->string, child->string) == 0) return false;
    }
  }
  return true;
}

bool string_is(const cJSON* value, std::string_view expected) {
  return cJSON_IsString(value) && value->valuestring && expected == value->valuestring;
}

bool text(const cJSON* value, std::size_t maximum) {
  if (!cJSON_IsString(value) || !value->valuestring) return false;
  const std::string_view content(value->valuestring);
  if (content.empty() || content.size() > maximum || !valid_utf8(content)) return false;
  for (const unsigned char c : content) if (c < 0x20 || c == 0x7f) return false;
  return true;
}

bool integer_is(const cJSON* value, int expected) {
  return cJSON_IsNumber(value) && value->valuedouble == expected;
}

bool uuid(const cJSON* value) {
  if (!cJSON_IsString(value) || !value->valuestring) return false;
  const std::string_view id(value->valuestring);
  if (id.size() != 36) return false;
  for (std::size_t i = 0; i < id.size(); ++i) {
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      if (id[i] != '-') return false;
    } else if (!(id[i] >= '0' && id[i] <= '9') && !(id[i] >= 'a' && id[i] <= 'f')) return false;
  }
  return true;
}

Code header(const cJSON* root) {
  if (!members(root, {"protocol", "board_id", "width", "height", "profile_id", "revision", "mode", "financial_actions_enabled", "required_capabilities", "currency", "minor_digits", "pages"})) return Code::invalid_profile;
  const auto* protocol = field(root, "protocol");
  if (!members(protocol, {"major", "minor"}) || !integer_is(field(protocol, "major"), ContractLimits::major) || !integer_is(field(protocol, "minor"), ContractLimits::minor)) return Code::unsupported_protocol;
  if (!string_is(field(root, "board_id"), ContractLimits::board_id) || !integer_is(field(root, "width"), ContractLimits::width) || !integer_is(field(root, "height"), ContractLimits::height)) return Code::unsupported_board;
  if (!string_is(field(root, "mode"), "diagnostic") || !cJSON_IsFalse(field(root, "financial_actions_enabled"))) return Code::financial_action_forbidden;
  const auto* revision = field(root, "revision");
  if (!uuid(field(root, "profile_id")) || !cJSON_IsNumber(revision) || revision->valuedouble < 1 || revision->valuedouble > 2147483647 || std::floor(revision->valuedouble) != revision->valuedouble) return Code::invalid_profile;
  const auto* currency = field(root, "currency");
  if (!text(currency, 3) || std::strlen(currency->valuestring) != 3) return Code::invalid_profile;
  for (const char c : std::string_view(currency->valuestring)) if (c < 'A' || c > 'Z') return Code::invalid_profile;
  const auto* digits = field(root, "minor_digits");
  if (!integer_is(digits, 0) && !integer_is(digits, 2) && !integer_is(digits, 3)) return Code::invalid_money;
  const auto* capabilities = field(root, "required_capabilities");
  if (!cJSON_IsArray(capabilities) || cJSON_GetArraySize(capabilities) > 2) return Code::unsupported_capability;
  for (auto* capability = capabilities->child; capability; capability = capability->next) {
    if (!string_is(capability, "profile.v1") && !string_is(capability, "diagnostics")) return Code::unsupported_capability;
    for (auto* prior = capabilities->child; prior != capability; prior = prior->next) if (string_is(prior, capability->valuestring)) return Code::unsupported_capability;
  }
  return Code::ok;
}

Code key(const cJSON* value) {
  if (!members(value, {"item_id", "label", "unit", "quantity", "gross_minor"}) || !uuid(field(value, "item_id")) || !text(field(value, "label"), ContractLimits::max_label_bytes) || !text(field(value, "unit"), ContractLimits::max_unit_bytes)) return Code::invalid_profile;
  const auto* quantity = field(value, "quantity");
  std::int64_t parsed = 0;
  if (!cJSON_IsString(quantity) || !parse_quantity(quantity->valuestring, parsed)) return Code::invalid_quantity;
  const auto* gross = field(value, "gross_minor");
  if (gross && (!cJSON_IsString(gross) || !parse_minor(gross->valuestring, parsed) || parsed < 0)) return Code::invalid_money;
  return Code::ok;
}

ValidationResult pages(const cJSON* value) {
  if (!cJSON_IsArray(value)) return {Code::invalid_profile};
  const auto page_count = static_cast<std::size_t>(cJSON_GetArraySize(value));
  if (page_count == 0 || page_count > ContractLimits::max_pages) return {Code::capacity_exceeded};
  std::vector<std::string> seen;
  std::size_t total_keys = 0;
  int page_number = 1;
  for (auto* page = value->child; page; page = page->next) {
    if (!members(page, {"number", "keys"}) || !integer_is(field(page, "number"), page_number++)) return {Code::invalid_profile};
    const auto* keys = field(page, "keys");
    if (!cJSON_IsArray(keys)) return {Code::invalid_profile};
    const auto count = static_cast<std::size_t>(cJSON_GetArraySize(keys));
    if (count > ContractLimits::max_keys_per_page) return {Code::capacity_exceeded};
    for (auto* entry = keys->child; entry; entry = entry->next) {
      const auto code = key(entry);
      if (code != Code::ok) return {code};
      const std::string id(field(entry, "item_id")->valuestring);
      for (const auto& previous : seen) if (id == previous) return {Code::invalid_profile};
      seen.push_back(id);
    }
    total_keys += count;
  }
  return {Code::ok, page_count, total_keys};
}
}  // namespace

ValidationResult validate_profile_json(const char* json, std::size_t length) {
  if (!json || length == 0) return {Code::invalid_json};
  const std::string_view source(json, length);
  const auto bounded = envelope(source);
  if (bounded != Code::ok) return {bounded};
  const char* end = nullptr;
  Json root(cJSON_ParseWithLengthOpts(json, length, &end, false), cJSON_Delete);
  if (!root || !end) return {Code::invalid_json};
  const auto* limit = json + length;
  while (end < limit && (*end == ' ' || *end == '\n' || *end == '\r' || *end == '\t')) ++end;
  if (end != limit) return {Code::invalid_json};
  const auto code = header(root.get());
  return code == Code::ok ? pages(field(root.get(), "pages")) : ValidationResult{code};
}
}  // namespace deskilo::terminal
