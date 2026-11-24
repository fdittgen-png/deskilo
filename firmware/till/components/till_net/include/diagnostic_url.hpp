#pragma once
#include <cstddef>
#include <string_view>

namespace deskilo::till {
constexpr std::size_t kDiagnosticUrlMaxBytes = 240;
bool valid_diagnostic_url(std::string_view url);
}  // namespace deskilo::till
