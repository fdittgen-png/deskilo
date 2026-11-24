// SPDX-License-Identifier: AGPL-3.0-or-later
#pragma once

#include <cstddef>
#include <cstdint>
#include <string_view>

namespace deskilo::terminal {

// Memory/protocol ceilings, not configurable business sale limits.
struct ContractLimits {
  static constexpr int major = 1;
  static constexpr int minor = 0;
  static constexpr std::string_view board_id = "lcdwiki_e32r40t";
  static constexpr int width = 480;
  static constexpr int height = 320;
  static constexpr std::size_t max_request_bytes = 8192;
  static constexpr std::size_t max_response_bytes = 16384;
  static constexpr std::size_t max_keys_per_page = 8;
  static constexpr std::size_t max_pages = 12;
  static constexpr std::size_t max_label_bytes = 96;
  static constexpr std::size_t max_unit_bytes = 32;
  static constexpr std::size_t max_depth = 12;
  static constexpr std::int64_t quantity_scale = 1000000;
};

enum class ValidationCode {
  ok,
  payload_too_large,
  invalid_json,
  invalid_utf8,
  invalid_profile,
  unsupported_protocol,
  unsupported_board,
  unsupported_capability,
  financial_action_forbidden,
  capacity_exceeded,
  invalid_money,
  invalid_quantity,
};

struct ValidationResult {
  ValidationCode code = ValidationCode::ok;
  std::size_t page_count = 0;
  std::size_t key_count = 0;
  bool ok() const { return code == ValidationCode::ok; }
};

const char* validation_code_name(ValidationCode code);

// No floating-point conversion; unsuccessful parsing leaves the output unchanged.
bool parse_minor(std::string_view text, std::int64_t& minor);
bool parse_quantity(std::string_view text, std::int64_t& millionths);
bool line_total(std::int64_t unit_minor, std::string_view quantity,
                std::int64_t& total_minor);

// Bootstrap accepts read-only diagnostic profiles only. It cannot authorize sales.
ValidationResult validate_profile_json(const char* json, std::size_t length);
const char* diagnostic_profile_json();
std::size_t diagnostic_profile_size();

}  // namespace deskilo::terminal
