// SPDX-License-Identifier: AGPL-3.0-or-later
// #4453 (E02) -- the LCDWiki E32R40T: ST7796S 320x480 over SPI2 (shared with the XPT2046 touch), backlight on IO27.
// Pins are the vendor's documented assignment; E10 (#4461) records the measured board before any output beyond display/touch is enabled.
#pragma once
#include <stdbool.h>
#include <stdint.h>
#include "esp_err.h"

#include "sdkconfig.h"

// #4474 -- the board profile this firmware is built for: named in the pairing code, so the app sends the matching image.
#if CONFIG_DESKILO_BOARD_IDEASPARK
// ideaspark ESP32 (ESP-WROOM-32) with a 1.9 in ST7789 170x320, portrait; no touch: BOOT (IO0) is its one button.
// Pins as the board's published examples use them; checked on the board in E10.
#define BOARD_PROFILE "ideaspark_st7789_v1"
#define BOARD_LCD_W 170
#define BOARD_LCD_H 320
#define BOARD_HAS_TOUCH 0
#define PIN_LCD_MOSI 23
#define PIN_LCD_SCLK 18
#define PIN_LCD_CS   15
#define PIN_LCD_DC   2
#define PIN_LCD_RST  4
#define PIN_LCD_BL   32
#else
#define BOARD_PROFILE "lcdwiki_e32r40t_v1"
#define BOARD_LCD_W 480   // landscape, after the controller's rotation
#define BOARD_LCD_H 320
#define BOARD_HAS_TOUCH 1
#define PIN_LCD_MISO 12
#define PIN_LCD_MOSI 13
#define PIN_LCD_SCLK 14
#define PIN_LCD_CS   15
#define PIN_LCD_DC   2
#define PIN_LCD_BL   27
#define PIN_TOUCH_CS 33
#define PIN_TOUCH_IRQ 36
#endif

esp_err_t board_init(void);
void board_backlight(bool on);
// Draws the pixels [x0,x1)x[y0,y1) (RGB565 as LVGL gives them, row-major) and queues the transfer.
esp_err_t board_draw(int x0, int y0, int x1, int y1, const void *pixels);
// True while the panel is touched; x,y are screen pixels (0..479, 0..319), through the touch calibration.
bool board_touch(int *x, int *y);
// True while the panel is touched; rx,ry are the XPT2046's raw readings (0..4095), for calibrating.
bool board_touch_raw(int *rx, int *ry);
// The BOOT button (IO0) held down: at start, the way into calibration when the touch is too far off to reach Settings.
bool board_boot_button(void);

// #4456 -- how raw touch readings map to the screen: which raw axis gives the screen's X (swap), and the raw reading at
// two known points of each screen axis. The default is the vendor's range, X running right to left.
typedef struct {
    int32_t swap;            // 1: the screen's X comes from the raw Y reading
    int32_t x0, rx0, x1, rx1; // screen x0 reads raw rx0, screen x1 reads raw rx1
    int32_t y0, ry0, y1, ry1;
} touch_cal_t;
touch_cal_t board_touch_cal_default(void);
void board_touch_set_cal(const touch_cal_t *cal);
