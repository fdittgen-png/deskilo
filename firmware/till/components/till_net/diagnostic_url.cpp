#include "diagnostic_url.hpp"

namespace deskilo::till {
bool valid_diagnostic_url(std::string_view url) {
  constexpr std::string_view scheme = "https://";
  if (url.size() > kDiagnosticUrlMaxBytes || url.substr(0, scheme.size()) != scheme) return false;
  const auto authority_end = url.find('/', scheme.size());
  const auto authority = url.substr(scheme.size(), authority_end - scheme.size());
  if (authority.empty() || authority.size() > 253) return false;
  for (const unsigned char value : url) {
    if (value <= 32 || value >= 127 || value == '@' || value == '#' || value == '?' || value == '\\') return false;
  }
  const auto colon = authority.find(':');
  const auto host = authority.substr(0, colon);
  if (host.empty() || host.front() == '.' || host.back() == '.' || host.front() == '-' || host.back() == '-') return false;
  std::size_t label_length = 0;
  char previous = 0;
  for (const char value : host) {
    if (value == '.') {
      if (label_length == 0 || previous == '-') return false;
      label_length = 0;
    } else {
      const bool letter = (value >= 'A' && value <= 'Z') || (value >= 'a' && value <= 'z');
      if (!letter && !(value >= '0' && value <= '9') && value != '-') return false;
      if (value == '-' && label_length == 0) return false;
      if (++label_length > 63) return false;
    }
    previous = value;
  }
  if (colon != std::string_view::npos) {
    const auto port = authority.substr(colon + 1);
    if (port.empty() || port.size() > 5) return false;
    unsigned value = 0;
    for (const char digit : port) {
      if (digit < '0' || digit > '9') return false;
      value = value * 10 + unsigned(digit - '0');
    }
    if (value == 0 || value > 65535) return false;
  }
  return true;
}
}  // namespace deskilo::till
