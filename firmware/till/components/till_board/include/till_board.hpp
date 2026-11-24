#pragma once

#include <cstdint>

#include "esp_err.h"
#include "lvgl.h"
#include "touch_calibration.hpp"

namespace deskilo::till {
struct RawTouch {
  TouchPoint point;
  bool pressed = false;
  std::uint32_t sequence = 0;
};

esp_err_t hold_drawer_disabled();
esp_err_t init_board();
void run_display_loop();
RawTouch raw_touch();
void capture_touch(bool enabled);
bool has_touch_calibration();
void use_touch_calibration_for_boot(const TouchCalibration& calibration);
esp_err_t save_touch_calibration(const TouchCalibration& calibration);
}  // namespace deskilo::till
