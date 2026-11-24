// SPDX-License-Identifier: AGPL-3.0-or-later
// #4453/#4456 bring-up -- the till terminal. One firmware, two roles (set in the board's settings):
//   till: the company's products as keys; a tap adds the product to the basket and Deskilo prices the draft;
//   roll: the receipt roll of the open draft -- the products chosen, their prices and the total -- read from Deskilo.
// The settings screen (gear) shows what the board keeps: Wi-Fi, server, user, company and role. Written with tools/till_provision.py.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "board.h"
#include "cfg.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "lvgl.h"
#include "net.h"

static const char *TAG = "till";
#define BUF_LINES 32   // one partial buffer: 480 x 32 x 2 bytes = 30 KiB (two buffers, 60 KiB of the 520 KB SRAM)

static lv_disp_draw_buf_t s_draw;
static lv_disp_drv_t s_disp;
static lv_indev_drv_t s_indev;

// ---- state shared between the network task and the screen (guarded by s_lock; the screen copies it) ----
typedef struct {
    char status[96];     // what the board is doing, or what went wrong
    product_t products[MAX_PRODUCTS];
    int n_products;
    roll_t roll;
    bool has_roll;
    bool online;
    uint32_t version;
} shared_t;
static shared_t S;
static SemaphoreHandle_t s_lock;
static QueueHandle_t s_cmd;
enum { CMD_TAP, CMD_NEXT };
typedef struct { int kind; int index; } cmd_t;
static basket_line_t s_basket[MAX_PRODUCTS];
static int s_basket_n;

static void with_lock(void (*fn)(void *), void *arg) { xSemaphoreTake(s_lock, portMAX_DELAY); fn(arg); S.version++; xSemaphoreGive(s_lock); }
static void set_status_fn(void *a) { snprintf(S.status, sizeof S.status, "%s", (const char *)a); }
static void set_status(const char *t) { with_lock(set_status_fn, (void *)t); }

// ---- money ----
static int exponent_of(const char *c) {
    if (!strcmp(c, "JPY") || !strcmp(c, "KRW") || !strcmp(c, "ISK")) return 0;
    if (!strcmp(c, "KWD") || !strcmp(c, "BHD") || !strcmp(c, "OMR") || !strcmp(c, "TND") || !strcmp(c, "JOD")) return 3;
    return 2;
}
static void money(char *out, size_t cap, int minor, const char *cur) {
    int e = exponent_of(cur), div = 1;
    for (int i = 0; i < e; i++) div *= 10;
    if (e == 0) snprintf(out, cap, "%d %s", minor, cur);
    else snprintf(out, cap, "%d.%0*d %s", minor / div, e, minor % div, cur);
}

// ---- the network task ----
static void roll_set_fn(void *a) { S.roll = *(roll_t *)a; S.has_roll = S.roll.n > 0; }
static void products_set_fn(void *a) { S.n_products = 0; }

static void add_to_basket(const char *id) {
    for (int i = 0; i < s_basket_n; i++)
        if (!strcmp(s_basket[i].item_id, id)) { s_basket[i].qty++; return; }
    if (s_basket_n < MAX_PRODUCTS) { strncpy(s_basket[s_basket_n].item_id, id, 39); s_basket[s_basket_n].item_id[39] = 0; s_basket[s_basket_n++].qty = 1; }
}

static void net_task(void *arg) {
    static roll_t roll;
    static product_t prods[MAX_PRODUCTS];
    char why[96] = "";
    set_status("Wi-Fi ...");
    if (net_connect(g_cfg.ssid, g_cfg.wifi_pass) != ESP_OK) { set_status("Wi-Fi or time failed: check Settings"); vTaskDelete(NULL); }
    set_status("Signing in ...");
    if (!api_sign_in(why, sizeof why)) { set_status(why); vTaskDelete(NULL); }
    xSemaphoreTake(s_lock, portMAX_DELAY); S.online = true; xSemaphoreGive(s_lock);
    if (!strcmp(g_cfg.role, "till")) {
        int n = api_products(prods, MAX_PRODUCTS, why, sizeof why);
        xSemaphoreTake(s_lock, portMAX_DELAY);
        if (n >= 0) { memcpy(S.products, prods, sizeof prods); S.n_products = n; }
        snprintf(S.status, sizeof S.status, "%s", n < 0 ? why : (n == 0 ? "No product is for sale in this company" : "Choose a product"));
        S.version++;
        xSemaphoreGive(s_lock);
    } else set_status("Waiting for a receipt ...");
    TickType_t last_refresh = xTaskGetTickCount();
    for (;;) {
        cmd_t c;
        bool got = xQueueReceive(s_cmd, &c, strcmp(g_cfg.role, "roll") == 0 ? pdMS_TO_TICKS(1500) : pdMS_TO_TICKS(1000)) == pdTRUE;
        if (xTaskGetTickCount() - last_refresh > pdMS_TO_TICKS(40 * 60 * 1000)) { if (api_sign_in(why, sizeof why)) last_refresh = xTaskGetTickCount(); }
        if (!strcmp(g_cfg.role, "roll")) {
            bool ok = api_roll(&roll, why, sizeof why);
            xSemaphoreTake(s_lock, portMAX_DELAY);
            if (ok) { S.roll = roll; S.has_roll = true; snprintf(S.status, sizeof S.status, "Receipt %.8s  rev %d", roll.receipt_id, roll.revision); }
            else { S.has_roll = false; snprintf(S.status, sizeof S.status, "%s", why[0] ? why : "Waiting for a receipt ..."); }
            S.version++;
            xSemaphoreGive(s_lock);
            continue;
        }
        if (!got) continue;
        if (c.kind == CMD_NEXT) {
            s_basket_n = 0;
            api_reset_draft();
            memset(&roll, 0, sizeof roll);
            xSemaphoreTake(s_lock, portMAX_DELAY); S.roll = roll; S.has_roll = false; snprintf(S.status, sizeof S.status, "Next customer"); S.version++; xSemaphoreGive(s_lock);
            continue;
        }
        product_t p;
        xSemaphoreTake(s_lock, portMAX_DELAY); bool in = c.index >= 0 && c.index < S.n_products; if (in) p = S.products[c.index]; xSemaphoreGive(s_lock);
        if (!in) continue;
        add_to_basket(p.id);
        set_status("Sending ...");
        bool ok = api_draft(s_basket, s_basket_n, &roll, why, sizeof why);
        if (!ok && strstr(why, "401")) { api_sign_in(why, sizeof why); ok = api_draft(s_basket, s_basket_n, &roll, why, sizeof why); }
        xSemaphoreTake(s_lock, portMAX_DELAY);
        if (ok) { S.roll = roll; S.has_roll = true; snprintf(S.status, sizeof S.status, "%s added", p.name); }
        else snprintf(S.status, sizeof S.status, "%s", why);
        S.version++;
        xSemaphoreGive(s_lock);
    }
}

// ---- the screen ----
static lv_obj_t *s_status, *s_total, *s_roll_list, *s_basket_label;
static lv_obj_t *s_keys[MAX_PRODUCTS];
static lv_obj_t *s_settings;
static uint32_t s_seen;

static void flush(lv_disp_drv_t *drv, const lv_area_t *a, lv_color_t *px) {
    board_draw(a->x1, a->y1, a->x2 + 1, a->y2 + 1, px);
    lv_disp_flush_ready(drv);
}
static void read_touch(lv_indev_drv_t *drv, lv_indev_data_t *d) {
    int x, y;
    if (board_touch(&x, &y)) { d->state = LV_INDEV_STATE_PR; d->point.x = x; d->point.y = y; }
    else d->state = LV_INDEV_STATE_REL;
}
static void tick(void *arg) { lv_tick_inc(2); }

static void key_cb(lv_event_t *e) { cmd_t c = {CMD_TAP, (int)(intptr_t)lv_event_get_user_data(e)}; xQueueSend(s_cmd, &c, 0); }
static void next_cb(lv_event_t *e) { cmd_t c = {CMD_NEXT, 0}; xQueueSend(s_cmd, &c, 0); }

static const char *or_unset(const char *v) { return v[0] ? v : "(not set)"; }

static void close_settings_cb(lv_event_t *e) { lv_obj_del(s_settings); s_settings = NULL; }
static void clear_cb(lv_event_t *e) { cfg_erase(); esp_restart(); }
static void open_settings_cb(lv_event_t *e) {
    if (s_settings) return;
    s_settings = lv_obj_create(lv_scr_act());
    lv_obj_set_size(s_settings, 460, 300);
    lv_obj_center(s_settings);
    lv_obj_t *t = lv_label_create(s_settings);
    lv_label_set_text_fmt(t, "Settings\nRole:      %s\nWi-Fi:     %s\nCompany:   %s\nUser:      %s\nSession:   %s",
        or_unset(g_cfg.role), or_unset(g_cfg.ssid), or_unset(g_cfg.workspace_name), or_unset(g_cfg.email), g_cfg.refresh[0] ? "kept" : "(not set)");
    lv_obj_set_style_text_font(t, &lv_font_montserrat_16, 0);
    lv_obj_align(t, LV_ALIGN_TOP_LEFT, 0, 0);
    lv_obj_t *b1 = lv_btn_create(s_settings);
    lv_obj_align(b1, LV_ALIGN_BOTTOM_LEFT, 0, 0);
    lv_obj_add_event_cb(b1, close_settings_cb, LV_EVENT_CLICKED, NULL);
    lv_label_set_text(lv_label_create(b1), "Close");
    lv_obj_t *b2 = lv_btn_create(s_settings);
    lv_obj_set_style_bg_color(b2, lv_color_hex(0xB00020), 0);
    lv_obj_align(b2, LV_ALIGN_BOTTOM_RIGHT, 0, 0);
    lv_obj_add_event_cb(b2, clear_cb, LV_EVENT_LONG_PRESSED, NULL);
    lv_label_set_text(lv_label_create(b2), "Hold: clear settings");
}

static void build_common(const char *title) {
    lv_obj_t *scr = lv_scr_act();
    lv_obj_set_style_bg_color(scr, lv_color_hex(0x101820), 0);
    lv_obj_t *t = lv_label_create(scr);
    lv_obj_set_style_text_color(t, lv_color_white(), 0);
    lv_obj_set_style_text_font(t, &lv_font_montserrat_20, 0);
    lv_label_set_text(t, title);
    lv_obj_align(t, LV_ALIGN_TOP_LEFT, 10, 8);
    if (strcmp(g_cfg.role, "roll") != 0) {   // the customer's roll has no settings; the till's need a long press, a staff gesture
        lv_obj_t *g = lv_btn_create(scr);
        lv_obj_set_size(g, 44, 34);
        lv_obj_align(g, LV_ALIGN_TOP_RIGHT, -8, 4);
        lv_obj_add_event_cb(g, open_settings_cb, LV_EVENT_LONG_PRESSED, NULL);
        lv_label_set_text(lv_label_create(g), LV_SYMBOL_SETTINGS);
    }
    s_status = lv_label_create(scr);
    lv_obj_set_style_text_color(s_status, lv_color_hex(0x9fd3ff), 0);
    lv_obj_set_style_text_font(s_status, &lv_font_montserrat_16, 0);
    lv_label_set_long_mode(s_status, LV_LABEL_LONG_DOT);
    lv_obj_set_width(s_status, 330);
    lv_obj_align(s_status, LV_ALIGN_TOP_LEFT, 150, 10);
    lv_label_set_text(s_status, "");
}

static void build_till(void) {
    build_common("DesKilo Kasse");
    lv_obj_t *scr = lv_scr_act();
    for (int i = 0; i < MAX_PRODUCTS; i++) {
        s_keys[i] = lv_btn_create(scr);
        lv_obj_set_size(s_keys[i], 112, 70);
        lv_obj_align(s_keys[i], LV_ALIGN_TOP_LEFT, 6 + (i % 4) * 118, 46 + (i / 4) * 76);
        lv_obj_add_event_cb(s_keys[i], key_cb, LV_EVENT_CLICKED, (void *)(intptr_t)i);
        lv_obj_add_flag(s_keys[i], LV_OBJ_FLAG_HIDDEN);
        lv_obj_t *l = lv_label_create(s_keys[i]);
        lv_label_set_long_mode(l, LV_LABEL_LONG_DOT);
        lv_obj_set_width(l, 100);
        lv_obj_set_style_text_align(l, LV_TEXT_ALIGN_CENTER, 0);
        lv_obj_center(l);
    }
    s_basket_label = lv_label_create(scr);
    lv_obj_set_style_text_color(s_basket_label, lv_color_white(), 0);
    lv_obj_set_style_text_font(s_basket_label, &lv_font_montserrat_28, 0);
    lv_obj_align(s_basket_label, LV_ALIGN_BOTTOM_LEFT, 12, -14);
    lv_label_set_text(s_basket_label, "");
    lv_obj_t *n = lv_btn_create(scr);
    lv_obj_set_size(n, 150, 50);
    lv_obj_align(n, LV_ALIGN_BOTTOM_RIGHT, -8, -8);
    lv_obj_add_event_cb(n, next_cb, LV_EVENT_CLICKED, NULL);
    lv_label_set_text(lv_label_create(n), "Next customer");
}

static void build_roll(void) {
    build_common("Receipt");
    lv_obj_t *scr = lv_scr_act();
    s_roll_list = lv_obj_create(scr);
    lv_obj_set_size(s_roll_list, 464, 210);
    lv_obj_align(s_roll_list, LV_ALIGN_TOP_LEFT, 8, 46);
    lv_obj_set_style_bg_color(s_roll_list, lv_color_hex(0xFAF7EE), 0);
    lv_obj_set_style_text_color(s_roll_list, lv_color_hex(0x202020), 0);
    lv_obj_set_flex_flow(s_roll_list, LV_FLEX_FLOW_COLUMN);
    s_total = lv_label_create(scr);
    lv_obj_set_style_text_color(s_total, lv_color_white(), 0);
    lv_obj_set_style_text_font(s_total, &lv_font_montserrat_28, 0);
    lv_obj_align(s_total, LV_ALIGN_BOTTOM_RIGHT, -12, -12);
    lv_label_set_text(s_total, "");
}

// Rebuilt from a copy of the shared state whenever its version changed.
static void refresh_cb(lv_timer_t *t) {
    static shared_t copy;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    if (S.version == s_seen) { xSemaphoreGive(s_lock); return; }
    copy = S;
    xSemaphoreGive(s_lock);
    s_seen = copy.version;
    lv_label_set_text(s_status, copy.status);
    char m[40];
    if (s_roll_list) {   // roll
        lv_obj_clean(s_roll_list);
        if (copy.has_roll) {
            for (int i = 0; i < copy.roll.n; i++) {
                char a[24], row[120];
                money(a, sizeof a, copy.roll.lines[i].gross_minor, copy.roll.currency);
                snprintf(row, sizeof row, "%s x %s   %s", copy.roll.lines[i].qty, copy.roll.lines[i].label, a);
                lv_obj_t *l = lv_label_create(s_roll_list);
                lv_obj_set_style_text_font(l, &lv_font_montserrat_16, 0);
                lv_label_set_text(l, row);
            }
            money(m, sizeof m, copy.roll.total_minor, copy.roll.currency);
            char tt[64]; snprintf(tt, sizeof tt, "Total  %s", m);
            lv_label_set_text(s_total, tt);
        } else lv_label_set_text(s_total, "");
        return;
    }
    for (int i = 0; i < MAX_PRODUCTS; i++) {   // till
        if (i < copy.n_products) {
            char a[24];
            money(a, sizeof a, copy.products[i].price_minor, "");
            char txt[96]; snprintf(txt, sizeof txt, "%s\n%d.%02d", copy.products[i].name, copy.products[i].price_minor / 100, copy.products[i].price_minor % 100);
            lv_label_set_text(lv_obj_get_child(s_keys[i], 0), txt);
            lv_obj_clear_flag(s_keys[i], LV_OBJ_FLAG_HIDDEN);
        } else lv_obj_add_flag(s_keys[i], LV_OBJ_FLAG_HIDDEN);
    }
    if (copy.has_roll) {
        money(m, sizeof m, copy.roll.total_minor, copy.roll.currency);
        int items = 0;
        for (int i = 0; i < copy.roll.n; i++) items += atoi(copy.roll.lines[i].qty);
        char tt[80]; snprintf(tt, sizeof tt, "%d x  %s", items, m);
        lv_label_set_text(s_basket_label, tt);
    } else lv_label_set_text(s_basket_label, "");
}

void app_main(void) {
    ESP_ERROR_CHECK(cfg_load());
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
    s_lock = xSemaphoreCreateMutex();
    s_cmd = xQueueCreate(8, sizeof(cmd_t));
    if (!cfg_complete()) {
        build_common("DesKilo Kasse");
        lv_label_set_text(s_status, "Not set up: run tools/till_provision.py");
    } else {
        if (!strcmp(g_cfg.role, "till")) build_till(); else build_roll();
        lv_timer_create(refresh_cb, 200, NULL);
        xTaskCreatePinnedToCore(net_task, "net", 12288, NULL, 4, NULL, 0);
    }
    board_backlight(true);
    ESP_LOGI(TAG, "up (%s): free heap %lu", g_cfg.role[0] ? g_cfg.role : "no settings", (unsigned long)esp_get_free_heap_size());
    for (;;) {
        lv_timer_handler();
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}
