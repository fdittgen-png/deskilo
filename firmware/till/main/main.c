// SPDX-License-Identifier: AGPL-3.0-or-later
// #4453 (E02) -- bring-up: the display, the touch and LVGL with partial buffers (E32R40T, landscape 480x320).
// The screen is the till's first page: a title, a 4 x 2 grid of keys and the line under it names the key touched.
#include "board.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "lvgl.h"

static const char *TAG = "till";
#define BUF_LINES 32   // one partial buffer: 480 x 32 x 2 bytes = 30 KiB (two buffers, 60 KiB of the 520 KB SRAM)

static lv_disp_draw_buf_t s_draw;
static lv_disp_drv_t s_disp;
static lv_indev_drv_t s_indev;
static lv_obj_t *s_status;

static void flush(lv_disp_drv_t *drv, const lv_area_t *a, lv_color_t *px) {
    board_draw(a->x1, a->y1, a->x2 + 1, a->y2 + 1, px);
    lv_disp_flush_ready(drv);   // the SPI queue copies before the next frame is produced: partial buffers are reused only after the queue drains
}

static void read_touch(lv_indev_drv_t *drv, lv_indev_data_t *d) {
    int x, y;
    if (board_touch(&x, &y)) { d->state = LV_INDEV_STATE_PR; d->point.x = x; d->point.y = y; }
    else d->state = LV_INDEV_STATE_REL;
}

static void tick(void *arg) { lv_tick_inc(2); }

static void key_cb(lv_event_t *e) {
    const char *name = lv_event_get_user_data(e);
    lv_label_set_text_fmt(s_status, "Key: %s", name);
}

static void build_ui(void) {
    static const char *NAMES[8] = {"Baguette", "Sourdough", "Rye", "Coffee", "Tea", "Pastry", "Cheese", "Milk"};
    lv_obj_t *scr = lv_scr_act();
    lv_obj_set_style_bg_color(scr, lv_color_hex(0x101820), 0);
    lv_obj_t *title = lv_label_create(scr);
    lv_obj_set_style_text_color(title, lv_color_white(), 0);
    lv_obj_set_style_text_font(title, &lv_font_montserrat_28, 0);
    lv_label_set_text(title, "DesKilo Kasse");
    lv_obj_align(title, LV_ALIGN_TOP_LEFT, 12, 8);
    for (int i = 0; i < 8; i++) {
        lv_obj_t *b = lv_btn_create(scr);
        lv_obj_set_size(b, 108, 80);
        lv_obj_align(b, LV_ALIGN_TOP_LEFT, 8 + (i % 4) * 116, 52 + (i / 4) * 88);
        lv_obj_add_event_cb(b, key_cb, LV_EVENT_CLICKED, (void *)NAMES[i]);
        lv_obj_t *l = lv_label_create(b);
        lv_label_set_text(l, NAMES[i]);
        lv_obj_center(l);
    }
    s_status = lv_label_create(scr);
    lv_obj_set_style_text_color(s_status, lv_color_hex(0x9fd3ff), 0);
    lv_obj_set_style_text_font(s_status, &lv_font_montserrat_20, 0);
    lv_label_set_text(s_status, "Touch a key");
    lv_obj_align(s_status, LV_ALIGN_BOTTOM_LEFT, 12, -12);
}

void app_main(void) {
    ESP_ERROR_CHECK(board_init());
    lv_init();
    static lv_color_t buf1[BOARD_LCD_W * BUF_LINES], buf2[BOARD_LCD_W * BUF_LINES];
    lv_disp_draw_buf_init(&s_draw, buf1, buf2, BOARD_LCD_W * BUF_LINES);
    lv_disp_drv_init(&s_disp);
    s_disp.hor_res = BOARD_LCD_W;
    s_disp.ver_res = BOARD_LCD_H;
    s_disp.flush_cb = flush;
    s_disp.draw_buf = &s_draw;
    lv_disp_drv_register(&s_disp);
    lv_indev_drv_init(&s_indev);
    s_indev.type = LV_INDEV_TYPE_POINTER;
    s_indev.read_cb = read_touch;
    lv_indev_drv_register(&s_indev);
    const esp_timer_create_args_t t = {.callback = tick, .name = "lv_tick"};
    esp_timer_handle_t h;
    ESP_ERROR_CHECK(esp_timer_create(&t, &h));
    ESP_ERROR_CHECK(esp_timer_start_periodic(h, 2000));
    build_ui();
    board_backlight(true);
    ESP_LOGI(TAG, "up: free heap %lu", (unsigned long)esp_get_free_heap_size());
    for (;;) {
        lv_timer_handler();
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}
