#pragma once

#include "esp_lcd_st7796.h"

namespace deskilo::till {
// Electrical register values published for E32R40T by LCDWiki:
// https://www.lcdwiki.com/res/E32R40T/ST7796_Init.txt
// Keep them separate from the controller's generic defaults.
static constexpr std::uint8_t kUnlock1[] = {0xc3};
static constexpr std::uint8_t kUnlock2[] = {0x96};
static constexpr std::uint8_t kInversion[] = {0x01};
static constexpr std::uint8_t kEntryMode[] = {0xc6};
static constexpr std::uint8_t kPower1[] = {0x80, 0x45};
static constexpr std::uint8_t kPower2[] = {0x13};
static constexpr std::uint8_t kPower3[] = {0xa7};
static constexpr std::uint8_t kVcom[] = {0x20};
static constexpr std::uint8_t kOutputTiming[] = {0x40, 0x8a, 0x00, 0x00, 0x29, 0x19, 0xa5, 0x33};
static constexpr std::uint8_t kPositiveGamma[] = {0xd0, 0x08, 0x0f, 0x06, 0x06, 0x33, 0x30, 0x33, 0x47, 0x17, 0x13, 0x13, 0x2b, 0x31};
static constexpr std::uint8_t kNegativeGamma[] = {0xd0, 0x0a, 0x11, 0x0b, 0x09, 0x07, 0x2f, 0x33, 0x47, 0x38, 0x15, 0x16, 0x2c, 0x32};
static constexpr std::uint8_t kLock1[] = {0x3c};
static constexpr std::uint8_t kLock2[] = {0x69};
static const st7796_lcd_init_cmd_t kPanelCommands[] = {
  // The driver exits sleep for 100 ms; this adds the vendor's remaining 20 ms.
  {0xf0, kUnlock1, sizeof(kUnlock1), 20},
  {0xf0, kUnlock2, sizeof(kUnlock2), 0},
  {0xb4, kInversion, sizeof(kInversion), 0},
  {0xb7, kEntryMode, sizeof(kEntryMode), 0},
  {0xc0, kPower1, sizeof(kPower1), 0},
  {0xc1, kPower2, sizeof(kPower2), 0},
  {0xc2, kPower3, sizeof(kPower3), 0},
  {0xc5, kVcom, sizeof(kVcom), 0},
  {0xe8, kOutputTiming, sizeof(kOutputTiming), 0},
  {0xe0, kPositiveGamma, sizeof(kPositiveGamma), 0},
  {0xe1, kNegativeGamma, sizeof(kNegativeGamma), 0},
  {0xf0, kLock1, sizeof(kLock1), 0},
  {0xf0, kLock2, sizeof(kLock2), 120},
};
}  // namespace deskilo::till
