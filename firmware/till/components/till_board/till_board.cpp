#include "till_board.hpp"

#include <algorithm>
#include <cstdint>

#include "board_profile.hpp"
#include "driver/gpio.h"
#include "driver/spi_master.h"
#include "esp_check.h"
#include "esp_flash.h"
#include "esp_heap_caps.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "esp_lcd_touch_xpt2046.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs.h"
#include "panel_init.hpp"

namespace deskilo::till {
namespace {
constexpr const char* kTag = "till_board";
constexpr auto kBus = SPI2_HOST;
esp_lcd_panel_handle_t panel = nullptr;
esp_lcd_touch_handle_t touch = nullptr;
TouchCalibration calibration;
RawTouch latest_touch;
bool capture_raw = false;

std::uint32_t milliseconds() {
  return static_cast<std::uint32_t>(esp_timer_get_time() / 1000);
}

bool flush_complete(esp_lcd_panel_io_handle_t, esp_lcd_panel_io_event_data_t*, void* context) {
  lv_display_flush_ready(static_cast<lv_display_t*>(context));
  return false;
}

void flush_display(lv_display_t* display, const lv_area_t* area, std::uint8_t* pixels) {
  const auto count = lv_area_get_width(area) * lv_area_get_height(area);
  lv_draw_sw_rgb565_swap(pixels, count);
  const auto result = esp_lcd_panel_draw_bitmap(panel, area->x1, area->y1,
      area->x2 + 1, area->y2 + 1, pixels);
  if (result != ESP_OK) {
    ESP_LOGE(kTag, "display transfer failed: %s", esp_err_to_name(result));
    lv_display_flush_ready(display);
  }
}

void read_touch(lv_indev_t*, lv_indev_data_t* data) {
  esp_lcd_touch_point_data_t point{};
  std::uint8_t count = 0;
  const auto result = esp_lcd_touch_read_data(touch);
  const bool pressed = result == ESP_OK &&
      esp_lcd_touch_get_data(touch, &point, &count, 1) == ESP_OK && count == 1;
  latest_touch = {{point.x, point.y}, pressed, latest_touch.sequence + 1};
  if (pressed && calibration.valid() && !capture_raw) {
    const auto position = calibration.map({point.x, point.y});
    data->point.x = position.x;
    data->point.y = position.y;
    data->state = LV_INDEV_STATE_PRESSED;
  } else {
    data->state = LV_INDEV_STATE_RELEASED;
  }
}

void load_calibration() {
  nvs_handle_t storage;
  auto result = nvs_open_from_partition("diag_nvs", "touch", NVS_READONLY, &storage);
  if (result == ESP_ERR_NVS_NOT_FOUND) return;
  if (result != ESP_OK) {
    ESP_LOGW(kTag, "calibration storage unavailable: %s", esp_err_to_name(result));
    return;
  }
  TouchCalibration::Encoded encoded{};
  auto size = encoded.size();
  result = nvs_get_blob(storage, "landscape_v1", encoded.data(), &size);
  nvs_close(storage);
  if (result == ESP_OK && size == encoded.size() && calibration.decode(encoded)) return;
  ESP_LOGW(kTag, "calibration missing or invalid; targets required");
}

esp_err_t init_panel(esp_lcd_panel_io_handle_t* io) {
  for (const int pin : {BoardProfile::lcd_select, BoardProfile::touch_select}) {
    const auto gpio = static_cast<gpio_num_t>(pin);
    ESP_RETURN_ON_ERROR(gpio_set_level(gpio, 1), kTag, "SPI deselect latch");
    ESP_RETURN_ON_ERROR(gpio_set_direction(gpio, GPIO_MODE_OUTPUT), kTag, "SPI deselect direction");
  }
  spi_bus_config_t bus{};
  bus.sclk_io_num = BoardProfile::spi_clock;
  bus.mosi_io_num = BoardProfile::spi_mosi;
  bus.miso_io_num = BoardProfile::spi_miso;
  bus.quadwp_io_num = -1;
  bus.quadhd_io_num = -1;
  bus.max_transfer_sz = BoardProfile::buffer_bytes;
  ESP_RETURN_ON_ERROR(spi_bus_initialize(kBus, &bus, SPI_DMA_CH_AUTO), kTag, "SPI init");

  esp_lcd_panel_io_spi_config_t config{};
  config.dc_gpio_num = static_cast<gpio_num_t>(BoardProfile::lcd_data_command);
  config.cs_gpio_num = static_cast<gpio_num_t>(BoardProfile::lcd_select);
  config.pclk_hz = BoardProfile::pixel_clock_hz;
  config.lcd_cmd_bits = 8;
  config.lcd_param_bits = 8;
  config.spi_mode = 0;
  config.trans_queue_depth = 2;
  ESP_RETURN_ON_ERROR(esp_lcd_new_panel_io_spi(kBus, &config, io), kTag, "LCD IO init");

  st7796_vendor_config_t vendor{};
  vendor.init_cmds = kPanelCommands;
  vendor.init_cmds_size = sizeof(kPanelCommands) / sizeof(kPanelCommands[0]);
  esp_lcd_panel_dev_config_t device{};
  device.reset_gpio_num = GPIO_NUM_NC;
  device.rgb_ele_order = LCD_RGB_ELEMENT_ORDER_BGR;
  device.bits_per_pixel = 16;
  device.vendor_config = &vendor;
  ESP_RETURN_ON_ERROR(esp_lcd_new_panel_st7796(*io, &device, &panel), kTag, "ST7796 init");
  ESP_RETURN_ON_ERROR(esp_lcd_panel_reset(panel), kTag, "software reset");
  ESP_RETURN_ON_ERROR(esp_lcd_panel_init(panel), kTag, "panel init");
  ESP_RETURN_ON_ERROR(esp_lcd_panel_swap_xy(panel, true), kTag, "landscape orientation");
  ESP_RETURN_ON_ERROR(esp_lcd_panel_mirror(panel, false, false), kTag, "panel mirror");
  return esp_lcd_panel_disp_on_off(panel, true);
}

esp_err_t init_touch(lv_display_t* display) {
  esp_lcd_panel_io_spi_config_t io_config{};
  io_config.cs_gpio_num = static_cast<gpio_num_t>(BoardProfile::touch_select);
  io_config.dc_gpio_num = GPIO_NUM_NC;
  io_config.spi_mode = 0;
  io_config.pclk_hz = ESP_LCD_TOUCH_SPI_CLOCK_HZ;
  io_config.trans_queue_depth = 3;
  io_config.lcd_cmd_bits = 8;
  io_config.lcd_param_bits = 8;
  esp_lcd_panel_io_handle_t io = nullptr;
  ESP_RETURN_ON_ERROR(esp_lcd_new_panel_io_spi(kBus, &io_config, &io), kTag, "touch IO init");
  esp_lcd_touch_config_t config{};
  config.x_max = 4096;
  config.y_max = 4096;
  config.rst_gpio_num = GPIO_NUM_NC;
  config.int_gpio_num = static_cast<gpio_num_t>(BoardProfile::touch_interrupt);
  ESP_RETURN_ON_ERROR(esp_lcd_touch_new_spi_xpt2046(io, &config, &touch), kTag, "XPT2046 init");
  auto* input = lv_indev_create();
  ESP_RETURN_ON_FALSE(input, ESP_ERR_NO_MEM, kTag, "LVGL input allocation");
  lv_indev_set_type(input, LV_INDEV_TYPE_POINTER);
  lv_indev_set_display(input, display);
  lv_indev_set_read_cb(input, read_touch);
  load_calibration();
  return ESP_OK;
}
}  // namespace

esp_err_t hold_drawer_disabled() {
  // This image has no output path. The external driver still needs a hardware
  // pull-down to cover reset, boot ROM, loss of power, and disconnected cables.
  gpio_config_t config{};
  config.pin_bit_mask = 1ULL << BoardProfile::drawer;
  config.mode = GPIO_MODE_INPUT;
  config.pull_down_en = GPIO_PULLDOWN_ENABLE;
  config.pull_up_en = GPIO_PULLUP_DISABLE;
  config.intr_type = GPIO_INTR_DISABLE;
  return gpio_config(&config);
}

esp_err_t init_board() {
  ESP_RETURN_ON_ERROR(hold_drawer_disabled(), kTag, "drawer inhibit");
  std::uint32_t flash_size = 0;
  ESP_RETURN_ON_ERROR(esp_flash_get_size(nullptr, &flash_size), kTag, "flash identity");
  ESP_RETURN_ON_FALSE(flash_size == BoardProfile::flash_bytes, ESP_ERR_INVALID_SIZE,
      kTag, "flash profile mismatch: %lu", static_cast<unsigned long>(flash_size));
  gpio_config_t backlight{};
  backlight.pin_bit_mask = 1ULL << BoardProfile::backlight;
  backlight.mode = GPIO_MODE_OUTPUT;
  ESP_RETURN_ON_ERROR(gpio_config(&backlight), kTag, "backlight config");
  ESP_RETURN_ON_ERROR(gpio_set_level(static_cast<gpio_num_t>(BoardProfile::backlight), 0), kTag, "backlight off");

  esp_lcd_panel_io_handle_t io = nullptr;
  ESP_RETURN_ON_ERROR(init_panel(&io), kTag, "display setup");
  lv_init();
  lv_tick_set_cb(milliseconds);
  auto* display = lv_display_create(BoardProfile::width, BoardProfile::height);
  ESP_RETURN_ON_FALSE(display, ESP_ERR_NO_MEM, kTag, "LVGL display allocation");
  auto* first = heap_caps_malloc(BoardProfile::buffer_bytes, MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL);
  auto* second = heap_caps_malloc(BoardProfile::buffer_bytes, MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL);
  ESP_RETURN_ON_FALSE(first && second, ESP_ERR_NO_MEM, kTag, "partial DMA buffers");
  lv_display_set_color_format(display, LV_COLOR_FORMAT_RGB565);
  lv_display_set_buffers(display, first, second, BoardProfile::buffer_bytes, LV_DISPLAY_RENDER_MODE_PARTIAL);
  lv_display_set_flush_cb(display, flush_display);
  esp_lcd_panel_io_callbacks_t callbacks{};
  callbacks.on_color_trans_done = flush_complete;
  ESP_RETURN_ON_ERROR(esp_lcd_panel_io_register_event_callbacks(io, &callbacks, display), kTag, "flush callback");
  ESP_RETURN_ON_ERROR(init_touch(display), kTag, "touch setup");
  ESP_RETURN_ON_ERROR(gpio_set_level(static_cast<gpio_num_t>(BoardProfile::backlight), 1), kTag, "backlight on");
  ESP_LOGI(kTag, "profile=%s, RGB565 DMA=%u, drawer_output=disabled", BoardProfile::id,
      static_cast<unsigned>(BoardProfile::display_bytes));
  return ESP_OK;
}

void run_display_loop() {
  // All LVGL calls except its documented flush completion run on this task.
  // Both devices use one ESP-IDF SPI bus, whose transaction queue serializes CS.
  for (;;) {
    const auto delay = std::clamp<std::uint32_t>(lv_timer_handler(), 1, 20);
    vTaskDelay(pdMS_TO_TICKS(delay));
  }
}

RawTouch raw_touch() { return latest_touch; }
void capture_touch(bool enabled) { capture_raw = enabled; }
bool has_touch_calibration() { return calibration.valid(); }
void use_touch_calibration_for_boot(const TouchCalibration& candidate) {
  if (candidate.valid()) calibration = candidate;
}

esp_err_t save_touch_calibration(const TouchCalibration& candidate) {
  if (!candidate.valid()) return ESP_ERR_INVALID_ARG;
  nvs_handle_t storage;
  auto result = nvs_open_from_partition("diag_nvs", "touch", NVS_READWRITE, &storage);
  if (result != ESP_OK) return result;
  const auto encoded = candidate.encode();
  result = nvs_set_blob(storage, "landscape_v1", encoded.data(), encoded.size());
  if (result == ESP_OK) result = nvs_commit(storage);
  nvs_close(storage);
  if (result == ESP_OK) calibration = candidate;
  return result;
}
}  // namespace deskilo::till
