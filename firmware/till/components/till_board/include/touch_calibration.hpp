#pragma once

#include <array>
#include <cstdint>

namespace deskilo::till {
struct TouchPoint {
  std::int32_t x = 0;
  std::int32_t y = 0;
};

class TouchCalibration {
 public:
  static constexpr std::size_t target_count = 5;
  static constexpr std::size_t encoded_size = 64;
  using Samples = std::array<TouchPoint, target_count>;
  using Encoded = std::array<std::uint8_t, encoded_size>;

  static Samples targets();
  bool fit(const Samples& raw);
  bool valid() const { return valid_; }
  TouchPoint map(TouchPoint raw) const;
  Encoded encode() const;
  bool decode(const Encoded& encoded);

 private:
  TouchPoint project(TouchPoint raw) const;
  std::array<std::int64_t, 7> coefficients_{};
  bool valid_ = false;
};
}  // namespace deskilo::till
