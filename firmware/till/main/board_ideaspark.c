// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- the ideaspark ESP32 board: a 1.9 in ST7789 170x320 over SPI, portrait, and no touch. The panel is 240 columns
// wide inside, of which the glass shows 170 from column 35. BOOT (IO0) is the board's one button; touch calls answer false.
#include "board.h"
#include "driver/gpio.h"
#include "driver/spi_master.h"
#include "esp_lcd_panel_io.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "board";
#define LCD_HOST SPI2_HOST
#define LCD_CLOCK_HZ (26 * 1000 * 1000)
#define COL_OFFSET 35   // the 170 visible columns of the ST7789's 240
#define ROW_OFFSET 0
#define MAX_TRANSFER (BOARD_LCD_W * 32 * 2)

static esp_lcd_panel_io_handle_t s_io;

typedef struct { uint8_t cmd; uint8_t data[4]; uint8_t len; uint16_t delay_ms; } init_cmd_t;
// ST7789 power-on: reset, wake, RGB565, portrait (MADCTL 0x00), inversion on (the IPS glass shows true colours with it).
static const init_cmd_t INIT[] = {
    {0x01, {0}, 0, 150},
    {0x11, {0}, 0, 120},
    {0x3A, {0x55}, 1, 10},
    {0x36, {0x00}, 1, 0},
    {0x21, {0}, 0, 10},
    {0x13, {0}, 0, 10},
    {0x29, {0}, 0, 50},
};

esp_err_t board_init(void) {
    gpio_config_t out = {.pin_bit_mask = (1ULL << PIN_LCD_BL) | (1ULL << PIN_LCD_RST), .mode = GPIO_MODE_OUTPUT};
    ESP_ERROR_CHECK(gpio_config(&out));
    gpio_set_level(PIN_LCD_BL, 0);
    gpio_set_level(PIN_LCD_RST, 0);   // a hardware reset before the panel is spoken to
    vTaskDelay(pdMS_TO_TICKS(20));
    gpio_set_level(PIN_LCD_RST, 1);
    vTaskDelay(pdMS_TO_TICKS(120));

    spi_bus_config_t bus = {.mosi_io_num = PIN_LCD_MOSI, .miso_io_num = -1, .sclk_io_num = PIN_LCD_SCLK,
                            .quadwp_io_num = -1, .quadhd_io_num = -1, .max_transfer_sz = MAX_TRANSFER};
    ESP_ERROR_CHECK(spi_bus_initialize(LCD_HOST, &bus, SPI_DMA_CH_AUTO));
    esp_lcd_panel_io_spi_config_t io = {.dc_gpio_num = PIN_LCD_DC, .cs_gpio_num = PIN_LCD_CS, .pclk_hz = LCD_CLOCK_HZ,
                                        .lcd_cmd_bits = 8, .lcd_param_bits = 8, .spi_mode = 0, .trans_queue_depth = 4};
    ESP_ERROR_CHECK(esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t)LCD_HOST, &io, &s_io));
    for (size_t i = 0; i < sizeof(INIT) / sizeof(INIT[0]); i++) {
        ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(s_io, INIT[i].cmd, INIT[i].len ? INIT[i].data : NULL, INIT[i].len));
        if (INIT[i].delay_ms) vTaskDelay(pdMS_TO_TICKS(INIT[i].delay_ms));
    }
    ESP_LOGI(TAG, "display ready (%s)", BOARD_PROFILE);
    return ESP_OK;
}

void board_backlight(bool on) { gpio_set_level(PIN_LCD_BL, on ? 1 : 0); }

// #4508 -- the end of a pixel transfer, told to whoever drew
static void (*s_drawn)(void *);
static void *s_drawn_ctx;
static bool drawn_isr(esp_lcd_panel_io_handle_t io, esp_lcd_panel_io_event_data_t *e, void *ctx) {
    if (s_drawn) s_drawn(s_drawn_ctx);
    return false;
}
void board_on_drawn(void (*done)(void *ctx), void *ctx) {
    s_drawn = done;
    s_drawn_ctx = ctx;
    const esp_lcd_panel_io_callbacks_t cbs = {.on_color_trans_done = drawn_isr};
    ESP_ERROR_CHECK(esp_lcd_panel_io_register_event_callbacks(s_io, &cbs, NULL));
}

esp_err_t board_draw(int x0, int y0, int x1, int y1, const void *pixels) {
    int ax = x0 + COL_OFFSET, bx = x1 - 1 + COL_OFFSET, ay = y0 + ROW_OFFSET, by = y1 - 1 + ROW_OFFSET;
    uint8_t ca[4] = {ax >> 8, ax & 0xFF, bx >> 8, bx & 0xFF};
    uint8_t ra[4] = {ay >> 8, ay & 0xFF, by >> 8, by & 0xFF};
    ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(s_io, 0x2A, ca, 4));
    ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(s_io, 0x2B, ra, 4));
    return esp_lcd_panel_io_tx_color(s_io, 0x2C, pixels, (size_t)(x1 - x0) * (y1 - y0) * 2);
}

// No touch on this board: the screens are read, and BOOT is the one input.
bool board_touch(int *x, int *y) { return false; }
bool board_touch_raw(int *rx, int *ry) { return false; }
touch_cal_t board_touch_cal_default(void) { return (touch_cal_t){0}; }
void board_touch_set_cal(const touch_cal_t *cal) {}

bool board_boot_button(void) {
    static bool ready;
    if (!ready) {
        gpio_config_t c = {.pin_bit_mask = 1ULL << 0, .mode = GPIO_MODE_INPUT, .pull_up_en = GPIO_PULLUP_ENABLE};
        gpio_config(&c);
        ready = true;
    }
    return gpio_get_level(0) == 0;
}
