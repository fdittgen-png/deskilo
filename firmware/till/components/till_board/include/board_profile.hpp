#pragma once

#include <cstddef>
#include <cstdint>

namespace deskilo::till {
struct BoardProfile {
  static constexpr const char* id = "lcdwiki_e32r40t";
  static constexpr int width = 480;
  static constexpr int height = 320;
  static constexpr int spi_clock = 14;
  static constexpr int spi_mosi = 13;
  static constexpr int spi_miso = 12;
  static constexpr int lcd_select = 15;
  static constexpr int lcd_data_command = 2;
  // LCD reset is wired to EN: an independent GPIO reset is not available.
  static constexpr int lcd_reset = -1;
  static constexpr int backlight = 27;
  static constexpr int touch_select = 33;
  static constexpr int touch_interrupt = 36;
  static constexpr int drawer = 21;
  static constexpr bool drawer_output_enabled = false;
  static constexpr int pixel_clock_hz = 20'000'000;
  static constexpr int buffer_rows = 20;
  static constexpr std::size_t buffer_bytes = width * buffer_rows * 2;
  static constexpr std::size_t display_bytes = buffer_bytes * 2;
  static constexpr std::uint32_t flash_bytes = 4 * 1024 * 1024;
};
static_assert(BoardProfile::display_bytes == 38'400);
static_assert(!BoardProfile::drawer_output_enabled);
static_assert(BoardProfile::drawer != BoardProfile::lcd_select);
static_assert(BoardProfile::drawer != BoardProfile::touch_select);
}  // namespace deskilo::till
