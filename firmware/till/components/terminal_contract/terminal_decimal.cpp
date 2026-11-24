// SPDX-License-Identifier: AGPL-3.0-or-later
#include "terminal_contract.hpp"

#include <limits>

namespace deskilo::terminal {
namespace {
bool digit(char c) { return c >= '0' && c <= '9'; }
}  // namespace

bool parse_minor(std::string_view text, std::int64_t& minor) {
  if (text.empty()) return false;
  const bool negative = text.front() == '-';
  const auto start = negative ? 1U : 0U;
  if (start == text.size() || text.size() - start > 19) return false;
  if (text[start] == '0' && (negative || text.size() - start != 1)) return false;
  const auto maximum = static_cast<std::uint64_t>(std::numeric_limits<std::int64_t>::max());
  const auto limit = negative ? maximum + 1 : maximum;
  std::uint64_t value = 0;
  for (auto i = start; i < text.size(); ++i) {
    if (!digit(text[i])) return false;
    const auto next = static_cast<std::uint64_t>(text[i] - '0');
    if (value > (limit - next) / 10) return false;
    value = value * 10 + next;
  }
  if (negative && value == maximum + 1) {
    minor = std::numeric_limits<std::int64_t>::min();
  } else {
    minor = negative ? -static_cast<std::int64_t>(value) : static_cast<std::int64_t>(value);
  }
  return true;
}

bool parse_quantity(std::string_view text, std::int64_t& millionths) {
  std::int64_t whole = 0;
  std::int64_t fraction = 0;
  std::size_t index = 0;
  while (index < text.size() && digit(text[index])) {
    if (index == 12) return false;
    whole = whole * 10 + (text[index++] - '0');
  }
  if (index == 0) return false;
  std::size_t decimals = 0;
  if (index < text.size()) {
    if (text[index++] != '.') return false;
    while (index < text.size()) {
      if (!digit(text[index]) || decimals == 6) return false;
      fraction = fraction * 10 + (text[index++] - '0');
      ++decimals;
    }
    if (decimals == 0) return false;
  }
  while (decimals++ < 6) fraction *= 10;
  const auto value = whole * ContractLimits::quantity_scale + fraction;
  if (value <= 0) return false;
  millionths = value;
  return true;
}

bool line_total(std::int64_t unit_minor, std::string_view quantity,
                std::int64_t& total_minor) {
  std::int64_t units = 0;
  if (unit_minor < 0 || !parse_quantity(quantity, units)) return false;
  const auto scale = ContractLimits::quantity_scale;
  const auto whole = units / scale;
  const auto fraction = units % scale;
  const auto maximum = std::numeric_limits<std::int64_t>::max();
  if (whole != 0 && unit_minor > maximum / whole) return false;
  const auto whole_total = unit_minor * whole;
  // Divide before multiplying: this works on the 32-bit target without __int128.
  const auto fractional_total = (unit_minor / scale) * fraction +
      ((unit_minor % scale) * fraction + scale / 2) / scale;
  if (whole_total > maximum - fractional_total) return false;
  total_minor = whole_total + fractional_total;
  return true;
}

const char* validation_code_name(ValidationCode code) {
  switch (code) {
    case ValidationCode::ok: return "ok";
    case ValidationCode::payload_too_large: return "payload_too_large";
    case ValidationCode::invalid_json: return "invalid_json";
    case ValidationCode::invalid_utf8: return "invalid_utf8";
    case ValidationCode::invalid_profile: return "invalid_profile";
    case ValidationCode::unsupported_protocol: return "unsupported_protocol";
    case ValidationCode::unsupported_board: return "unsupported_board";
    case ValidationCode::unsupported_capability: return "unsupported_capability";
    case ValidationCode::financial_action_forbidden: return "financial_action_forbidden";
    case ValidationCode::capacity_exceeded: return "capacity_exceeded";
    case ValidationCode::invalid_money: return "invalid_money";
    case ValidationCode::invalid_quantity: return "invalid_quantity";
  }
  return "invalid_profile";
}

}  // namespace deskilo::terminal
