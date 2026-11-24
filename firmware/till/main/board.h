// SPDX-License-Identifier: AGPL-3.0-or-later
// #4453 (E02) -- the LCDWiki E32R40T: ST7796S 320x480 over SPI2 (shared with the XPT2046 touch), backlight on IO27.
// Pins are the vendor's documented assignment; E10 (#4461) records the measured board before any output beyond display/touch is enabled.
#pragma once
#include <stdbool.h>
#include <stdint.h>
#include "esp_err.h"

#define BOARD_LCD_W 480   // landscape, after the controller's rotation
#define BOARD_LCD_H 320

#define PIN_LCD_MISO 12
#define PIN_LCD_MOSI 13
#define PIN_LCD_SCLK 14
#define PIN_LCD_CS   15
#define PIN_LCD_DC   2
#define PIN_LCD_BL   27
#define PIN_TOUCH_CS 33
#define PIN_TOUCH_IRQ 36

esp_err_t board_init(void);
void board_backlight(bool on);
// Draws the pixels [x0,x1)x[y0,y1) (RGB565 as LVGL gives them, row-major) and queues the transfer.
esp_err_t board_draw(int x0, int y0, int x1, int y1, const void *pixels);
// True while the panel is touched; x,y are screen pixels (0..479, 0..319).
bool board_touch(int *x, int *y);
