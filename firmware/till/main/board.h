// SPDX-License-Identifier: AGPL-3.0-or-later
// #4453 (E02) -- the LCDWiki E32R40T: ST7796S 320x480 over SPI2 (shared with the XPT2046 touch), backlight on IO27.
// Pins are the vendor's documented assignment; E10 (#4461) records the measured board before any output beyond display/touch is enabled.
#pragma once
#include <stdbool.h>
#include <stdint.h>
#include "esp_err.h"
#include "touch_cal.h"

#include "sdkconfig.h"

// #4474 -- the board profile this firmware is built for: named in the pairing code, so the app sends the matching image.
#if CONFIG_DESKILO_BOARD_IDEASPARK
// ideaspark ESP32 (ESP-WROOM-32) with a 1.9 in ST7789 170x320, portrait; no touch: BOOT (IO0) is its one button.
// Pins as the board's published examples use them; checked on the board in E10.
#define BOARD_PROFILE "ideaspark_st7789_v1"
#define BOARD_PROFILE_CODE 1   // #4466: the profile in the readable pairing code
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
#define BOARD_PROFILE_CODE 0   // #4466: the profile in the readable pairing code
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
#define PIN_LCD_RST  -1   // the panel's reset is the board's EN: there is no reset pin to drive
// The cash drawer's output on the board's connector: held as an input with its pull-down, never driven, until the
// board's drawer interface is measured and recorded (E10, #4461).
#define PIN_DRAWER   21
#endif

// #4474 -- one signal per pin: a profile that gives two signals the same pin does not build.
#define BOARD_PIN_DISTINCT(a, b) _Static_assert((a) < 0 || (a) != (b), "two board signals on one pin: " #a " and " #b)
#if CONFIG_DESKILO_BOARD_IDEASPARK
BOARD_PIN_DISTINCT(PIN_LCD_MOSI, PIN_LCD_SCLK); BOARD_PIN_DISTINCT(PIN_LCD_MOSI, PIN_LCD_CS); BOARD_PIN_DISTINCT(PIN_LCD_MOSI, PIN_LCD_DC);
BOARD_PIN_DISTINCT(PIN_LCD_MOSI, PIN_LCD_RST); BOARD_PIN_DISTINCT(PIN_LCD_MOSI, PIN_LCD_BL); BOARD_PIN_DISTINCT(PIN_LCD_SCLK, PIN_LCD_CS);
BOARD_PIN_DISTINCT(PIN_LCD_SCLK, PIN_LCD_DC); BOARD_PIN_DISTINCT(PIN_LCD_SCLK, PIN_LCD_RST); BOARD_PIN_DISTINCT(PIN_LCD_SCLK, PIN_LCD_BL);
BOARD_PIN_DISTINCT(PIN_LCD_CS, PIN_LCD_DC); BOARD_PIN_DISTINCT(PIN_LCD_CS, PIN_LCD_RST); BOARD_PIN_DISTINCT(PIN_LCD_CS, PIN_LCD_BL);
BOARD_PIN_DISTINCT(PIN_LCD_DC, PIN_LCD_RST); BOARD_PIN_DISTINCT(PIN_LCD_DC, PIN_LCD_BL); BOARD_PIN_DISTINCT(PIN_LCD_RST, PIN_LCD_BL);
BOARD_PIN_DISTINCT(PIN_LCD_MOSI, 0); BOARD_PIN_DISTINCT(PIN_LCD_SCLK, 0); BOARD_PIN_DISTINCT(PIN_LCD_CS, 0);   // IO0 is BOOT
BOARD_PIN_DISTINCT(PIN_LCD_DC, 0); BOARD_PIN_DISTINCT(PIN_LCD_RST, 0); BOARD_PIN_DISTINCT(PIN_LCD_BL, 0);
#else
BOARD_PIN_DISTINCT(PIN_LCD_MISO, PIN_LCD_MOSI); BOARD_PIN_DISTINCT(PIN_LCD_MISO, PIN_LCD_SCLK); BOARD_PIN_DISTINCT(PIN_LCD_MISO, PIN_LCD_CS);
BOARD_PIN_DISTINCT(PIN_LCD_MISO, PIN_LCD_DC); BOARD_PIN_DISTINCT(PIN_LCD_MISO, PIN_LCD_BL); BOARD_PIN_DISTINCT(PIN_LCD_MISO, PIN_TOUCH_CS);
BOARD_PIN_DISTINCT(PIN_LCD_MISO, PIN_TOUCH_IRQ); BOARD_PIN_DISTINCT(PIN_LCD_MISO, PIN_DRAWER); BOARD_PIN_DISTINCT(PIN_LCD_MOSI, PIN_LCD_SCLK);
BOARD_PIN_DISTINCT(PIN_LCD_MOSI, PIN_LCD_CS); BOARD_PIN_DISTINCT(PIN_LCD_MOSI, PIN_LCD_DC); BOARD_PIN_DISTINCT(PIN_LCD_MOSI, PIN_LCD_BL);
BOARD_PIN_DISTINCT(PIN_LCD_MOSI, PIN_TOUCH_CS); BOARD_PIN_DISTINCT(PIN_LCD_MOSI, PIN_TOUCH_IRQ); BOARD_PIN_DISTINCT(PIN_LCD_MOSI, PIN_DRAWER);
BOARD_PIN_DISTINCT(PIN_LCD_SCLK, PIN_LCD_CS); BOARD_PIN_DISTINCT(PIN_LCD_SCLK, PIN_LCD_DC); BOARD_PIN_DISTINCT(PIN_LCD_SCLK, PIN_LCD_BL);
BOARD_PIN_DISTINCT(PIN_LCD_SCLK, PIN_TOUCH_CS); BOARD_PIN_DISTINCT(PIN_LCD_SCLK, PIN_TOUCH_IRQ); BOARD_PIN_DISTINCT(PIN_LCD_SCLK, PIN_DRAWER);
BOARD_PIN_DISTINCT(PIN_LCD_CS, PIN_LCD_DC); BOARD_PIN_DISTINCT(PIN_LCD_CS, PIN_LCD_BL); BOARD_PIN_DISTINCT(PIN_LCD_CS, PIN_TOUCH_CS);
BOARD_PIN_DISTINCT(PIN_LCD_CS, PIN_TOUCH_IRQ); BOARD_PIN_DISTINCT(PIN_LCD_CS, PIN_DRAWER); BOARD_PIN_DISTINCT(PIN_LCD_DC, PIN_LCD_BL);
BOARD_PIN_DISTINCT(PIN_LCD_DC, PIN_TOUCH_CS); BOARD_PIN_DISTINCT(PIN_LCD_DC, PIN_TOUCH_IRQ); BOARD_PIN_DISTINCT(PIN_LCD_DC, PIN_DRAWER);
BOARD_PIN_DISTINCT(PIN_LCD_BL, PIN_TOUCH_CS); BOARD_PIN_DISTINCT(PIN_LCD_BL, PIN_TOUCH_IRQ); BOARD_PIN_DISTINCT(PIN_LCD_BL, PIN_DRAWER);
BOARD_PIN_DISTINCT(PIN_TOUCH_CS, PIN_TOUCH_IRQ); BOARD_PIN_DISTINCT(PIN_TOUCH_CS, PIN_DRAWER); BOARD_PIN_DISTINCT(PIN_TOUCH_IRQ, PIN_DRAWER);
#endif
#if !CONFIG_ESPTOOLPY_FLASHSIZE_4MB
#error "the partition table (partitions.csv) is laid out for the boards' 4 MB flash"
#endif

esp_err_t board_init(void);
void board_backlight(bool on);
// Draws the pixels [x0,x1)x[y0,y1) (RGB565 as LVGL gives them, row-major) and queues the transfer.
esp_err_t board_draw(int x0, int y0, int x1, int y1, const void *pixels);
// #4508 -- [done] is called (from the transfer's interrupt) once the pixels of a board_draw have reached the panel, so
// their buffer may be drawn into again.
void board_on_drawn(void (*done)(void *ctx), void *ctx);
// True while the panel is touched; x,y are screen pixels (0..479, 0..319), through the touch calibration.
bool board_touch(int *x, int *y);
// True while the panel is touched; rx,ry are the XPT2046's raw readings (0..4095), for calibrating.
bool board_touch_raw(int *rx, int *ry);
// The BOOT button (IO0) held down: at start, the way into calibration when the touch is too far off to reach Settings.
bool board_boot_button(void);

// #4456 -- how raw touch readings map to the screen (touch_cal.h); the default is the vendor's range, X running right to left.
touch_cal_t board_touch_cal_default(void);
void board_touch_set_cal(const touch_cal_t *cal);
