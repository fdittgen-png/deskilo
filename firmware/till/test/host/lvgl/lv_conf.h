// SPDX-License-Identifier: AGPL-3.0-or-later
// The host tests' LVGL configuration: what sdkconfig.defaults sets for the board (16-bit colour, the four Montserrat sizes,
// the system allocator), minus the byte swap the board's SPI panel needs.
#ifndef LV_CONF_H
#define LV_CONF_H
#define LV_COLOR_DEPTH 16
#define LV_COLOR_16_SWAP 0
#define LV_MEM_CUSTOM 1
#define LV_MEM_CUSTOM_INCLUDE <stdlib.h>
#define LV_TICK_CUSTOM 0
#define LV_DPI_DEF 130
#define LV_FONT_MONTSERRAT_14 1
#define LV_FONT_MONTSERRAT_16 1
#define LV_FONT_MONTSERRAT_20 1
#define LV_FONT_MONTSERRAT_28 1
#define LV_FONT_DEFAULT &lv_font_montserrat_14
#define LV_USE_LOG 0
#define LV_USE_ASSERT_NULL 1
#define LV_USE_ASSERT_MALLOC 1
#define LV_USE_QRCODE 1
#endif
