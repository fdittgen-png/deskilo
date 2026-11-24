#include "touch_calibration.hpp"

#include <algorithm>
#include <cstdlib>

#include "board_profile.hpp"

namespace deskilo::till {
namespace {
constexpr std::int64_t kMinimumDeterminant = 1'000'000;
constexpr int kValidationErrorPixels = 14;
constexpr std::uint32_t kMagic = 0x31435444;

std::uint32_t checksum(const std::uint8_t* bytes, std::size_t length) {
  std::uint32_t crc = 0xffffffff;
  for (std::size_t i = 0; i < length; ++i) {
    crc ^= bytes[i];
    for (int bit = 0; bit < 8; ++bit) {
      crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1u)));
    }
  }
  return ~crc;
}

void put32(std::uint8_t* out, std::uint32_t value) {
  for (int i = 0; i < 4; ++i) out[i] = value >> (i * 8);
}

std::uint32_t get32(const std::uint8_t* in) {
  std::uint32_t value = 0;
  for (int i = 0; i < 4; ++i) value |= std::uint32_t(in[i]) << (i * 8);
  return value;
}
}  // namespace

TouchCalibration::Samples TouchCalibration::targets() {
  return {{{28, 28}, {451, 28}, {28, 291}, {451, 291}, {239, 159}}};
}

bool TouchCalibration::fit(const Samples& raw) {
  valid_ = false;
  for (const auto point : raw) {
    if (point.x < 50 || point.x > 4046 || point.y < 50 || point.y > 4046) return false;
  }
  const std::int64_t x0 = raw[0].x, x1 = raw[1].x, x2 = raw[2].x;
  const std::int64_t y0 = raw[0].y, y1 = raw[1].y, y2 = raw[2].y;
  const auto determinant = x0 * (y1 - y2) + x1 * (y2 - y0) + x2 * (y0 - y1);
  if (std::abs(determinant) < kMinimumDeterminant) return false;
  const auto expected = targets();
  for (int axis = 0; axis < 2; ++axis) {
    const std::int64_t p0 = axis == 0 ? expected[0].x : expected[0].y;
    const std::int64_t p1 = axis == 0 ? expected[1].x : expected[1].y;
    const std::int64_t p2 = axis == 0 ? expected[2].x : expected[2].y;
    coefficients_[axis * 3] = p0 * (y1 - y2) + p1 * (y2 - y0) + p2 * (y0 - y1);
    coefficients_[axis * 3 + 1] = p0 * (x2 - x1) + p1 * (x0 - x2) + p2 * (x1 - x0);
    coefficients_[axis * 3 + 2] = p0 * (x1 * y2 - x2 * y1) +
        p1 * (x2 * y0 - x0 * y2) + p2 * (x0 * y1 - x1 * y0);
  }
  coefficients_[6] = determinant;
  for (std::size_t i = 3; i < target_count; ++i) {
    const auto projected = project(raw[i]);
    if (std::abs(projected.x - expected[i].x) > kValidationErrorPixels ||
        std::abs(projected.y - expected[i].y) > kValidationErrorPixels) return false;
  }
  valid_ = true;
  return true;
}

TouchPoint TouchCalibration::project(TouchPoint raw) const {
  if (coefficients_[6] == 0) return {};
  return {
    static_cast<std::int32_t>((coefficients_[0] * raw.x + coefficients_[1] * raw.y + coefficients_[2]) / coefficients_[6]),
    static_cast<std::int32_t>((coefficients_[3] * raw.x + coefficients_[4] * raw.y + coefficients_[5]) / coefficients_[6]),
  };
}

TouchPoint TouchCalibration::map(TouchPoint raw) const {
  if (!valid_) return {};
  raw.x = std::clamp<std::int32_t>(raw.x, 0, 4095);
  raw.y = std::clamp<std::int32_t>(raw.y, 0, 4095);
  auto point = project(raw);
  point.x = std::clamp<std::int32_t>(point.x, 0, BoardProfile::width - 1);
  point.y = std::clamp<std::int32_t>(point.y, 0, BoardProfile::height - 1);
  return point;
}

TouchCalibration::Encoded TouchCalibration::encode() const {
  Encoded output{};
  if (!valid_) return output;
  put32(output.data(), kMagic);
  for (std::size_t i = 0; i < coefficients_.size(); ++i) {
    const auto value = static_cast<std::uint64_t>(coefficients_[i]);
    for (int b = 0; b < 8; ++b) output[4 + i * 8 + b] = value >> (8 * b);
  }
  put32(output.data() + 60, checksum(output.data(), 60));
  return output;
}

bool TouchCalibration::decode(const Encoded& encoded) {
  valid_ = false;
  if (get32(encoded.data()) != kMagic || get32(encoded.data() + 60) != checksum(encoded.data(), 60)) return false;
  for (std::size_t i = 0; i < coefficients_.size(); ++i) {
    std::uint64_t value = 0;
    for (int b = 0; b < 8; ++b) value |= std::uint64_t(encoded[4 + i * 8 + b]) << (8 * b);
    coefficients_[i] = static_cast<std::int64_t>(value);
    if (coefficients_[i] < -100'000'000'000LL || coefficients_[i] > 100'000'000'000LL) return false;
  }
  if (std::abs(coefficients_[6]) < kMinimumDeterminant || std::abs(coefficients_[6]) > 16'777'216) return false;
  valid_ = true;
  return true;
}
}  // namespace deskilo::till
