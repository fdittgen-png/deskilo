// SPDX-License-Identifier: AGPL-3.0-or-later
#include "board.h"
#include "driver/gpio.h"
#include "driver/spi_master.h"
#include "esp_lcd_panel_io.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "board";
#define LCD_HOST SPI2_HOST
#define LCD_CLOCK_HZ (40 * 1000 * 1000)
#define TOUCH_CLOCK_HZ (2 * 1000 * 1000)
// 4-line SPI: 8-bit commands, DC on IO2. Partial buffers are 480 x 32 pixels x 2 bytes = 30 KiB each, so one transfer is bounded.
#define MAX_TRANSFER (BOARD_LCD_W * 32 * 2)

static esp_lcd_panel_io_handle_t s_io;
static spi_device_handle_t s_touch;

typedef struct { uint8_t cmd; uint8_t data[16]; uint8_t len; uint16_t delay_ms; } init_cmd_t;
// ST7796S power-on sequence (vendor demo values); MADCTL 0x28 = landscape (MV | BGR); COLMOD 0x55 = RGB565.
static const init_cmd_t INIT[] = {
    {0x01, {0}, 0, 120},
    {0x11, {0}, 0, 120},
    {0xF0, {0xC3}, 1, 0}, {0xF0, {0x96}, 1, 0},
    {0x36, {0x28}, 1, 0},
    {0x3A, {0x55}, 1, 0},
    {0xB4, {0x01}, 1, 0},
    {0xB7, {0xC6}, 1, 0},
    {0xC0, {0x80, 0x45}, 2, 0}, {0xC1, {0x13}, 1, 0}, {0xC2, {0xA7}, 1, 0}, {0xC5, {0x0A}, 1, 0},
    {0xE8, {0x40, 0x8A, 0x00, 0x00, 0x29, 0x19, 0xA5, 0x33}, 8, 0},
    {0xE0, {0xD0, 0x08, 0x0F, 0x06, 0x06, 0x33, 0x30, 0x33, 0x47, 0x17, 0x13, 0x13, 0x2B, 0x31}, 14, 0},
    {0xE1, {0xD0, 0x0A, 0x11, 0x0B, 0x09, 0x07, 0x2F, 0x33, 0x47, 0x38, 0x15, 0x16, 0x2C, 0x32}, 14, 0},
    {0xF0, {0x3C}, 1, 0}, {0xF0, {0x69}, 1, 0},
    {0x21, {0}, 0, 0},
    {0x29, {0}, 0, 120},
};

esp_err_t board_init(void) {
    gpio_config_t bl = {.pin_bit_mask = 1ULL << PIN_LCD_BL, .mode = GPIO_MODE_OUTPUT};
    ESP_ERROR_CHECK(gpio_config(&bl));
    gpio_set_level(PIN_LCD_BL, 0);
    gpio_config_t irq = {.pin_bit_mask = 1ULL << PIN_TOUCH_IRQ, .mode = GPIO_MODE_INPUT};
    ESP_ERROR_CHECK(gpio_config(&irq));

    spi_bus_config_t bus = {.mosi_io_num = PIN_LCD_MOSI, .miso_io_num = PIN_LCD_MISO, .sclk_io_num = PIN_LCD_SCLK,
                            .quadwp_io_num = -1, .quadhd_io_num = -1, .max_transfer_sz = MAX_TRANSFER};
    ESP_ERROR_CHECK(spi_bus_initialize(LCD_HOST, &bus, SPI_DMA_CH_AUTO));
    esp_lcd_panel_io_spi_config_t io = {.dc_gpio_num = PIN_LCD_DC, .cs_gpio_num = PIN_LCD_CS, .pclk_hz = LCD_CLOCK_HZ,
                                        .lcd_cmd_bits = 8, .lcd_param_bits = 8, .spi_mode = 0, .trans_queue_depth = 4};
    ESP_ERROR_CHECK(esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t)LCD_HOST, &io, &s_io));
    for (size_t i = 0; i < sizeof(INIT) / sizeof(INIT[0]); i++) {
        ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(s_io, INIT[i].cmd, INIT[i].data, INIT[i].len));
        if (INIT[i].delay_ms) vTaskDelay(pdMS_TO_TICKS(INIT[i].delay_ms));
    }
    spi_device_interface_config_t t = {.clock_speed_hz = TOUCH_CLOCK_HZ, .mode = 0, .spics_io_num = PIN_TOUCH_CS, .queue_size = 1};
    ESP_ERROR_CHECK(spi_bus_add_device(LCD_HOST, &t, &s_touch));
    ESP_LOGI(TAG, "display and touch ready");
    return ESP_OK;
}

void board_backlight(bool on) { gpio_set_level(PIN_LCD_BL, on ? 1 : 0); }

esp_err_t board_draw(int x0, int y0, int x1, int y1, const void *pixels) {
    uint8_t ca[4] = {x0 >> 8, x0 & 0xFF, (x1 - 1) >> 8, (x1 - 1) & 0xFF};
    uint8_t ra[4] = {y0 >> 8, y0 & 0xFF, (y1 - 1) >> 8, (y1 - 1) & 0xFF};
    ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(s_io, 0x2A, ca, 4));
    ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(s_io, 0x2B, ra, 4));
    return esp_lcd_panel_io_tx_color(s_io, 0x2C, pixels, (size_t)(x1 - x0) * (y1 - y0) * 2);
}

static uint16_t xpt_read(uint8_t cmd) {
    uint8_t tx[3] = {cmd, 0, 0}, rx[3] = {0};
    spi_transaction_t tr = {.length = 24, .tx_buffer = tx, .rx_buffer = rx};
    if (spi_device_polling_transmit(s_touch, &tr) != ESP_OK) return 0;
    return (uint16_t)(((rx[1] << 8) | rx[2]) >> 3) & 0x0FFF;
}

// XPT2046 raw range of the 4.0" panel; calibrated on the real board in E10. Landscape: the panel's Y axis runs along the screen's X.
#define RAW_MIN 200
#define RAW_MAX 3900
static int scale(int raw, int out) {
    if (raw < RAW_MIN) raw = RAW_MIN;
    if (raw > RAW_MAX) raw = RAW_MAX;
    return (raw - RAW_MIN) * (out - 1) / (RAW_MAX - RAW_MIN);
}

bool board_touch(int *x, int *y) {
    if (gpio_get_level(PIN_TOUCH_IRQ) != 0) return false;
    int sx = 0, sy = 0;
    for (int i = 0; i < 4; i++) { sx += xpt_read(0xD0); sy += xpt_read(0x90); }
    sx /= 4; sy /= 4;
    *x = scale(sy, BOARD_LCD_W);
    *y = BOARD_LCD_H - 1 - scale(sx, BOARD_LCD_H);
    return true;
}
