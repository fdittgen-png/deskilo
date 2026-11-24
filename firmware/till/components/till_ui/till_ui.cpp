#include "till_ui.hpp"

#include <algorithm>
#include <cstdint>
#include <cstdio>

#include "board_profile.hpp"
#include "esp_app_desc.h"
#include "esp_heap_caps.h"
#include "esp_log.h"
#include "esp_system.h"
#include "lvgl.h"
#include "nvs.h"
#include "till_board.hpp"
#include "till_build_info.h"
#include "till_net.hpp"
#include "till_strings.h"

extern "C" {
LV_FONT_DECLARE(till_font_16);
}

namespace deskilo::till {
namespace {
constexpr const char* kTag = "till_ui";
constexpr std::uint32_t kBackground = 0x101b27;
constexpr std::uint32_t kForeground = 0xe9f0f5;
Locale locale = Locale::en;
bool contract_valid = false;
bool storage_ready = false;
bool calibration_unsaved = false;
bool refresh_language = false;
lv_obj_t* heap_free = nullptr;
lv_obj_t* heap_minimum = nullptr;
lv_obj_t* heap_largest = nullptr;
lv_obj_t* network_label = nullptr;
lv_obj_t* https_label = nullptr;
lv_obj_t* touch_label = nullptr;
lv_obj_t* touch_coordinates = nullptr;
lv_obj_t* tabview = nullptr;
lv_obj_t* calibration_overlay = nullptr;
lv_obj_t* calibration_target = nullptr;
lv_obj_t* calibration_instruction = nullptr;
lv_obj_t* calibration_status = nullptr;

struct CalibrationCapture {
  TouchCalibration::Samples samples{};
  std::size_t target = 0;
  std::uint32_t sequence = 0;
  std::int64_t sum_x = 0;
  std::int64_t sum_y = 0;
  unsigned count = 0;
  int minimum_x = 4095, minimum_y = 4095, maximum_x = 0, maximum_y = 0;
  bool active = false;
  bool wait_release = true;
} capture;

const char* message(const char* key) { return text(locale, key); }

lv_obj_t* label(lv_obj_t* parent, const char* value, int x, int y, int width) {
  auto* object = lv_label_create(parent);
  lv_obj_set_pos(object, x, y);
  lv_obj_set_width(object, width);
  lv_label_set_text(object, value);
  lv_label_set_long_mode(object, LV_LABEL_LONG_WRAP);
  return object;
}

void button(lv_obj_t* parent, const char* key, int x, int y, int width, lv_event_cb_t action) {
  auto* object = lv_button_create(parent);
  lv_obj_set_pos(object, x, y);
  lv_obj_set_size(object, width, 40);
  auto* caption = lv_label_create(object);
  lv_label_set_text(caption, message(key));
  lv_obj_set_width(caption, width - 12);
  lv_obj_set_style_text_align(caption, LV_TEXT_ALIGN_CENTER, 0);
  lv_label_set_long_mode(caption, LV_LABEL_LONG_WRAP);
  lv_obj_center(caption);
  lv_obj_add_event_cb(object, action, LV_EVENT_CLICKED, nullptr);
}

void locale_changed(lv_event_t* event) {
  const auto value = lv_dropdown_get_selected(static_cast<lv_obj_t*>(lv_event_get_target(event)));
  if (value >= 5) return;
  locale = static_cast<Locale>(value);
  refresh_language = true;
  nvs_handle_t preferences;
  auto result = nvs_open_from_partition("diag_nvs", "preferences", NVS_READWRITE, &preferences);
  if (result != ESP_OK) { ESP_LOGW(kTag, "locale persistence unavailable"); return; }
  result = nvs_set_u8(preferences, "locale", value);
  if (result == ESP_OK) result = nvs_commit(preferences);
  nvs_close(preferences);
  if (result != ESP_OK) ESP_LOGW(kTag, "locale persistence failed: %s", esp_err_to_name(result));
}

void move_calibration_target() {
  const auto target = TouchCalibration::targets()[capture.target];
  lv_obj_set_pos(calibration_target, target.x - 12, target.y - 12);
  lv_label_set_text_fmt(calibration_instruction, "%s  %u/%u", message("tillTerminalTouchTarget"),
      static_cast<unsigned>(capture.target + 1), static_cast<unsigned>(TouchCalibration::target_count));
}

void begin_calibration(lv_event_t*) {
  capture = CalibrationCapture{};
  capture.active = true;
  capture.sequence = raw_touch().sequence;
  capture_touch(true);
  calibration_overlay = lv_obj_create(lv_screen_active());
  lv_obj_set_pos(calibration_overlay, 0, 0);
  lv_obj_set_size(calibration_overlay, BoardProfile::width, BoardProfile::height);
  lv_obj_set_style_pad_all(calibration_overlay, 0, 0);
  lv_obj_set_style_border_width(calibration_overlay, 0, 0);
  lv_obj_set_style_radius(calibration_overlay, 0, 0);
  lv_obj_set_style_bg_color(calibration_overlay, lv_color_hex(kBackground), 0);
  lv_obj_set_scrollable(calibration_overlay, false);
  calibration_instruction = label(calibration_overlay, "", 60, 75, 360);
  lv_obj_set_style_text_align(calibration_instruction, LV_TEXT_ALIGN_CENTER, 0);
  calibration_status = label(calibration_overlay, "", 60, 220, 360);
  lv_obj_set_style_text_align(calibration_status, LV_TEXT_ALIGN_CENTER, 0);
  calibration_target = lv_obj_create(calibration_overlay);
  lv_obj_set_size(calibration_target, 24, 24);
  lv_obj_set_style_radius(calibration_target, LV_RADIUS_CIRCLE, 0);
  lv_obj_set_style_bg_color(calibration_target, lv_color_hex(0xf4ba56), 0);
  lv_obj_set_style_border_color(calibration_target, lv_color_white(), 0);
  lv_obj_set_style_border_width(calibration_target, 2, 0);
  lv_obj_set_scrollable(calibration_target, false);
  move_calibration_target();
}

void reset_sample() {
  capture.sum_x = capture.sum_y = 0;
  capture.count = 0;
  capture.minimum_x = capture.minimum_y = 4095;
  capture.maximum_x = capture.maximum_y = 0;
}

void accept_calibration_sample() {
  if (capture.count < 3 || capture.maximum_x - capture.minimum_x > 100 ||
      capture.maximum_y - capture.minimum_y > 100) {
    lv_label_set_text(calibration_status, message("tillTerminalTouchFailed"));
    return;
  }
  capture.samples[capture.target] = {
    static_cast<std::int32_t>(capture.sum_x / capture.count),
    static_cast<std::int32_t>(capture.sum_y / capture.count),
  };
  ++capture.target;
  if (capture.target < TouchCalibration::target_count) {
    lv_label_set_text(calibration_status, "");
    move_calibration_target();
    return;
  }
  TouchCalibration calibration;
  if (calibration.fit(capture.samples)) {
    const auto persisted = save_touch_calibration(calibration);
    calibration_unsaved = persisted != ESP_OK;
    if (calibration_unsaved) {
      use_touch_calibration_for_boot(calibration);
      ESP_LOGW(kTag, "calibration persistence failed: %s; using RAM only", esp_err_to_name(persisted));
    }
    capture.active = false;
    capture_touch(false);
    lv_obj_delete(calibration_overlay);
    calibration_overlay = nullptr;
    lv_tabview_set_active(tabview, 2, LV_ANIM_OFF);
    lv_label_set_text(touch_label, message(calibration_unsaved ?
        "tillTerminalCalibrationUnsaved" : "tillTerminalTouchAccepted"));
  } else {
    capture.target = 0;
    lv_label_set_text(calibration_status, message("tillTerminalTouchFailed"));
    move_calibration_target();
  }
}

void poll_calibration() {
  const auto touch = raw_touch();
  if (!capture.active || touch.sequence == capture.sequence) return;
  capture.sequence = touch.sequence;
  if (capture.wait_release) {
    if (!touch.pressed) capture.wait_release = false;
    return;
  }
  if (touch.pressed && capture.count < 1000) {
    capture.sum_x += touch.point.x;
    capture.sum_y += touch.point.y;
    ++capture.count;
    capture.minimum_x = std::min(capture.minimum_x, static_cast<int>(touch.point.x));
    capture.minimum_y = std::min(capture.minimum_y, static_cast<int>(touch.point.y));
    capture.maximum_x = std::max(capture.maximum_x, static_cast<int>(touch.point.x));
    capture.maximum_y = std::max(capture.maximum_y, static_cast<int>(touch.point.y));
  } else if (!touch.pressed && capture.count != 0) {
    accept_calibration_sample();
    reset_sample();
  }
}

void https_clicked(lv_event_t*) { request_https_diagnostic(); }
void restart_clicked(lv_event_t*) { esp_restart(); }

void touch_test(lv_event_t* event) {
  const auto* input = lv_indev_active();
  if (!input) return;
  lv_point_t point;
  lv_indev_get_point(input, &point);
  lv_label_set_text_fmt(touch_coordinates, "X %d  Y %d", static_cast<int>(point.x), static_cast<int>(point.y));
  auto* target = static_cast<lv_obj_t*>(lv_event_get_target(event));
  lv_obj_set_style_bg_color(target, lv_color_hex(0x277d77), 0);
}

void diagnostic_tab(lv_obj_t* tab) {
  char line[160];
  std::snprintf(line, sizeof(line), "%s: E32R40T / ESP32 / 4 MiB", message("tillTerminalBoard"));
  label(tab, line, 0, 0, 440);
  std::snprintf(line, sizeof(line), "%s: %s%s", message("tillTerminalFirmware"),
      esp_app_get_description()->version, source_dirty ? "+" : "");
  label(tab, line, 0, 23, 440);
  heap_free = label(tab, "", 0, 49, 440);
  heap_minimum = label(tab, "", 0, 72, 440);
  heap_largest = label(tab, "", 0, 95, 440);
  auto* contract = label(tab, message(contract_valid ? "tillTerminalContractValid" : "tillTerminalContractInvalid"), 0, 122, 440);
  lv_obj_set_style_text_color(contract, lv_color_hex(contract_valid ? 0x63d1b8 : 0xff907e), 0);
  button(tab, "tillTerminalRestart", 0, 153, 200, restart_clicked);
}

void render_screen() {
  auto* screen = lv_screen_active();
  lv_obj_clean(screen);
  lv_obj_set_style_bg_color(screen, lv_color_hex(kBackground), 0);
  lv_obj_set_style_text_color(screen, lv_color_hex(kForeground), 0);
  lv_obj_set_style_text_font(screen, &till_font_16, 0);
  label(screen, message("tillTerminalTitle"), 12, 12, 330);
  auto* language = lv_dropdown_create(screen);
  lv_obj_set_pos(language, 388, 4);
  lv_obj_set_size(language, 80, 36);
  lv_dropdown_set_options(language, "EN\nFR\nDE\nES\nIT");
  lv_dropdown_set_symbol(language, nullptr);
  lv_dropdown_set_selected(language, static_cast<std::uint32_t>(locale));
  lv_obj_add_event_cb(language, locale_changed, LV_EVENT_VALUE_CHANGED, nullptr);
  auto* commission = label(screen, message("tillTerminalNotCommissioned"), 12, 43, 456);
  lv_obj_set_style_text_color(commission, lv_color_hex(0xf4ba56), 0);
  label(screen, message("tillTerminalDrawerDisabled"), 12, 64, 456);
  if (!storage_ready) {
    auto* storage = label(screen, message("tillTerminalStorageUnavailable"), 12, 85, 456);
    lv_obj_set_style_text_color(storage, lv_color_hex(0xff907e), 0);
  }

  auto* tabs = lv_tabview_create(screen);
  tabview = tabs;
  const int tabs_y = storage_ready ? 90 : 112;
  lv_obj_set_pos(tabs, 0, tabs_y);
  lv_obj_set_size(tabs, BoardProfile::width, BoardProfile::height - tabs_y);
  lv_tabview_set_tab_bar_size(tabs, 32);
  auto* diagnostics = lv_tabview_add_tab(tabs, message("tillTerminalDiagnostics"));
  auto* network_tab = lv_tabview_add_tab(tabs, message("tillTerminalNetwork"));
  auto* touch_tab = lv_tabview_add_tab(tabs, message("tillTerminalTouchTest"));
  for (auto* tab : {diagnostics, network_tab, touch_tab}) {
    lv_obj_set_style_pad_all(tab, 10, 0);
    lv_obj_set_style_bg_color(tab, lv_color_hex(kBackground), 0);
    lv_obj_set_style_bg_opa(tab, LV_OPA_COVER, 0);
  }
  diagnostic_tab(diagnostics);
  network_label = label(network_tab, "", 0, 8, 440);
  https_label = label(network_tab, "", 0, 44, 440);
  button(network_tab, "tillTerminalCheckTls", 0, 110, 260, https_clicked);
  touch_label = label(touch_tab, message(calibration_unsaved ?
      "tillTerminalCalibrationUnsaved" : "tillTerminalTouchTest"), 0, 0, 440);
  auto* test = lv_obj_create(touch_tab);
  lv_obj_set_pos(test, 0, 50);
  lv_obj_set_size(test, 440, 70);
  lv_obj_set_style_bg_color(test, lv_color_hex(0x20394b), 0);
  lv_obj_set_scrollable(test, false);
  touch_coordinates = label(test, "", 0, 0, 400);
  lv_obj_add_event_cb(test, touch_test, LV_EVENT_PRESSING, nullptr);
  button(touch_tab, "tillTerminalTouchCalibration", 0, 129, 330, begin_calibration);
}

void refresh_status() {
  lv_label_set_text_fmt(heap_free, "%s: %u B", message("tillTerminalHeapFree"),
      static_cast<unsigned>(heap_caps_get_free_size(MALLOC_CAP_INTERNAL | MALLOC_CAP_8BIT)));
  lv_label_set_text_fmt(heap_minimum, "%s: %u B", message("tillTerminalHeapMinimum"),
      static_cast<unsigned>(heap_caps_get_minimum_free_size(MALLOC_CAP_INTERNAL | MALLOC_CAP_8BIT)));
  lv_label_set_text_fmt(heap_largest, "%s: %u B", message("tillTerminalHeapLargest"),
      static_cast<unsigned>(heap_caps_get_largest_free_block(MALLOC_CAP_INTERNAL | MALLOC_CAP_8BIT)));
  const auto status = diagnostic_network_state();
  const char* network_key = "tillTerminalNetworkNotConfigured";
  switch (status.network) {
    case NetworkState::connecting: network_key = "tillTerminalNetworkConnecting"; break;
    case NetworkState::connected: network_key = "tillTerminalNetworkReady"; break;
    case NetworkState::failed: network_key = "tillTerminalNetworkFailed"; break;
    case NetworkState::not_configured: break;
  }
  const char* https_key = "tillTerminalHttpsNotConfigured";
  switch (status.https) {
    case HttpsState::ready: https_key = "tillTerminalCheckTls"; break;
    case HttpsState::checking: https_key = "tillTerminalHttpsPending"; break;
    case HttpsState::passed: https_key = "tillTerminalHttpsPassed"; break;
    case HttpsState::failed: https_key = "tillTerminalHttpsFailed"; break;
    case HttpsState::clock_failed: https_key = "tillTerminalClockFailed"; break;
    case HttpsState::not_configured: break;
  }
  lv_label_set_text(network_label, message(network_key));
  lv_label_set_text(https_label, message(https_key));
}

void ui_tick(lv_timer_t*) {
  if (refresh_language) {
    refresh_language = false;
    render_screen();
    refresh_status();
  }
  poll_calibration();
}
}  // namespace

void create_diagnostic_ui(bool profile_valid, bool storage_available) {
  contract_valid = profile_valid;
  storage_ready = storage_available;
  auto* display = lv_display_get_default();
  lv_display_set_theme(display, lv_theme_default_init(display, lv_color_hex(0x277d77),
      lv_color_hex(0xf4ba56), true, &till_font_16));
  nvs_handle_t preferences;
  if (nvs_open_from_partition("diag_nvs", "preferences", NVS_READONLY, &preferences) == ESP_OK) {
    std::uint8_t stored = 0;
    if (nvs_get_u8(preferences, "locale", &stored) == ESP_OK && stored < 5) locale = static_cast<Locale>(stored);
    nvs_close(preferences);
  }
  render_screen();
  refresh_status();
  lv_timer_create(ui_tick, 20, nullptr);
  lv_timer_create([](lv_timer_t*) { refresh_status(); }, 1000, nullptr);
  if (!has_touch_calibration()) begin_calibration(nullptr);
}
}  // namespace deskilo::till
