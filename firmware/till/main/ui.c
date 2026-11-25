// SPDX-License-Identifier: AGPL-3.0-or-later
// #4453/#4456 -- the screens: the till (keys, basket, Pay cash, the cash count, Ask again), the receipt roll, the settings and
// the trace box. LVGL only: what a tap means goes out through the port, what is shown comes in as a copy of the state, so
// the host tests drive these very screens with a pointer on the Mac.
#include "ui.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cfg.h"
#include "money_text.h"
#include "strings.h"
#include "trace.h"

LV_FONT_DECLARE(till_font_14)
LV_FONT_DECLARE(till_font_16)
LV_FONT_DECLARE(till_font_20)
LV_FONT_DECLARE(till_font_28)

static ui_port_t s_port;

static lv_obj_t *s_status, *s_total, *s_roll_list, *s_basket_label;
static lv_obj_t *s_keys[MAX_PRODUCTS];
static lv_obj_t *s_pay, *s_retry, *s_cash, *s_cash_text, *s_cash_ok;
static int64_t s_typed;   // the cash typed on the keypad, in minor units
static int64_t s_cash_due;
static char s_cash_cur[4];
static lv_obj_t *s_settings;

// ---- the quantity keypad: switched with the product keys; the quantity typed goes with the next product tapped ----
static lv_obj_t *s_keypad, *s_keypad_label, *s_switch_label;
static int s_products;   // the keys in use, shown again when the keypad goes away
static bool s_keypad_on;
static int s_qty;   // 0: none typed, the product is added once

static void qty_show(void) {
    char t[64];
    snprintf(t, sizeof t, T(S_ST_QTY), s_qty > 0 ? s_qty : 1);
    if (s_keypad_label) lv_label_set_text(s_keypad_label, t);
    if (s_switch_label) {
        char sw[16];
        if (s_keypad_on) snprintf(sw, sizeof sw, "%s", T(S_BTN_ITEMS));
        else if (s_qty > 0) snprintf(sw, sizeof sw, "x%d", s_qty);
        else snprintf(sw, sizeof sw, "%s", T(S_BTN_KEYPAD));
        lv_label_set_text(s_switch_label, sw);
    }
}
static void keys_visible(bool show);
static void switch_cb(lv_event_t *e) {
    s_keypad_on = !s_keypad_on;
    if (s_keypad_on) lv_obj_clear_flag(s_keypad, LV_OBJ_FLAG_HIDDEN); else lv_obj_add_flag(s_keypad, LV_OBJ_FLAG_HIDDEN);
    keys_visible(!s_keypad_on);
    qty_show();
}
static void qty_key_cb(lv_event_t *e) {
    int d = (int)(intptr_t)lv_event_get_user_data(e);
    if (d < 0) s_qty = 0;                          // C
    else if (s_qty < 999) s_qty = s_qty * 10 + d;  // at most three digits
    qty_show();
}
static void keys_visible(bool show) {
    for (int i = 0; i < MAX_PRODUCTS; i++) {
        if (show && i < s_products) lv_obj_clear_flag(s_keys[i], LV_OBJ_FLAG_HIDDEN); else lv_obj_add_flag(s_keys[i], LV_OBJ_FLAG_HIDDEN);
    }
}
static void key_cb(lv_event_t *e) {
    s_port.send(CMD_TAP, (int)(intptr_t)lv_event_get_user_data(e), s_qty > 0 ? s_qty : 1);
    s_qty = 0;
    qty_show();
}
static void next_cb(lv_event_t *e) { s_port.send(CMD_NEXT, 0, 0); }

static const char *or_unset(const char *v) { return v[0] ? v : T(S_NOT_SET); }

// ---- the trace box: the newest lines on the screen; a tap shows them all and can send them to Deskilo ----
static lv_obj_t *s_trace_box, *s_trace_label, *s_traces;
static void close_traces_cb(lv_event_t *e) { lv_obj_del(s_traces); s_traces = NULL; }
static void send_traces_cb(lv_event_t *e) { s_port.send(CMD_REPORT, 0, 0); close_traces_cb(e); }
static void open_traces_cb(lv_event_t *e) {
    if (s_traces) return;
    static char all[TRACE_LINES * TRACE_WIDTH];
    trace_dump(all, sizeof all);
    s_traces = lv_obj_create(lv_scr_act());
    lv_obj_set_size(s_traces, 472, 312);
    lv_obj_center(s_traces);
    lv_obj_t *list = lv_obj_create(s_traces);
    lv_obj_set_size(list, 448, 236);
    lv_obj_align(list, LV_ALIGN_TOP_LEFT, 0, 0);
    lv_obj_t *t = lv_label_create(list);
    lv_obj_set_width(t, 420);
    lv_label_set_long_mode(t, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_font(t, &till_font_14, 0);
    lv_label_set_text(t, all[0] ? all : T(S_NO_TRACE));
    lv_obj_scroll_to_y(list, LV_COORD_MAX, LV_ANIM_OFF);   // the newest at hand
    lv_obj_t *b1 = lv_btn_create(s_traces);
    lv_obj_align(b1, LV_ALIGN_BOTTOM_LEFT, 0, 0);
    lv_obj_add_event_cb(b1, close_traces_cb, LV_EVENT_CLICKED, NULL);
    lv_label_set_text(lv_label_create(b1), T(S_BTN_CLOSE));
    lv_obj_t *b2 = lv_btn_create(s_traces);
    lv_obj_align(b2, LV_ALIGN_BOTTOM_RIGHT, 0, 0);
    lv_obj_add_event_cb(b2, send_traces_cb, LV_EVENT_CLICKED, NULL);
    lv_label_set_text(lv_label_create(b2), T(S_BTN_SEND));
}
static void build_trace_box(int y, int h) {
    s_trace_box = lv_obj_create(lv_scr_act());
    lv_obj_set_size(s_trace_box, 464, h);
    lv_obj_align(s_trace_box, LV_ALIGN_TOP_LEFT, 8, y);
    lv_obj_set_style_bg_color(s_trace_box, lv_color_hex(0x0B0F14), 0);
    lv_obj_set_style_border_color(s_trace_box, lv_color_hex(0x334455), 0);
    lv_obj_set_style_pad_all(s_trace_box, 3, 0);
    lv_obj_clear_flag(s_trace_box, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_add_flag(s_trace_box, LV_OBJ_FLAG_CLICKABLE);
    lv_obj_add_event_cb(s_trace_box, open_traces_cb, LV_EVENT_CLICKED, NULL);
    s_trace_label = lv_label_create(s_trace_box);
    lv_obj_set_width(s_trace_label, 452);
    lv_label_set_long_mode(s_trace_label, LV_LABEL_LONG_CLIP);
    lv_obj_set_style_text_font(s_trace_label, &till_font_14, 0);
    lv_obj_set_style_text_color(s_trace_label, lv_color_hex(0x8FA3B8), 0);
    lv_label_set_text(s_trace_label, "");
}
static void trace_box_cb(lv_timer_t *t) {
    static uint32_t seen = UINT32_MAX;
    uint32_t v = trace_version();
    if (!s_trace_label || v == seen) return;
    seen = v;
    char tail[3 * TRACE_WIDTH];
    trace_tail(tail, sizeof tail, lv_obj_get_height(s_trace_box) > 52 ? 3 : 2);
    lv_label_set_text(s_trace_label, tail);
}

static void calibrate_cb(lv_event_t *e);
static void close_settings_cb(lv_event_t *e) { lv_obj_del(s_settings); s_settings = NULL; }
static void clear_cb(lv_event_t *e) { s_port.factory_reset(); }
static void open_settings_cb(lv_event_t *e) {
    if (s_settings) return;
    s_settings = lv_obj_create(lv_scr_act());
    lv_obj_set_size(s_settings, 460, 300);
    lv_obj_center(s_settings);
    lv_obj_t *t = lv_label_create(s_settings);
    lv_label_set_text_fmt(t, T(S_SETTINGS),
        or_unset(g_cfg.role), or_unset(g_cfg.ssid), or_unset(g_cfg.workspace_name), g_cfg.email[0] ? T(S_SIGNED_IN) : T(S_NOT_SET), g_cfg.refresh[0] ? T(S_KEPT) : T(S_NOT_SET));
    lv_obj_set_style_text_font(t, &till_font_16, 0);
    lv_obj_align(t, LV_ALIGN_TOP_LEFT, 0, 0);
    lv_obj_t *b1 = lv_btn_create(s_settings);
    lv_obj_align(b1, LV_ALIGN_BOTTOM_LEFT, 0, 0);
    lv_obj_add_event_cb(b1, close_settings_cb, LV_EVENT_CLICKED, NULL);
    lv_label_set_text(lv_label_create(b1), T(S_BTN_CLOSE));
    lv_obj_t *b2 = lv_btn_create(s_settings);
    lv_obj_set_style_bg_color(b2, lv_color_hex(0xB00020), 0);
    lv_obj_align(b2, LV_ALIGN_BOTTOM_RIGHT, 0, 0);
    lv_obj_add_event_cb(b2, clear_cb, LV_EVENT_LONG_PRESSED, NULL);
    lv_obj_t *b3 = lv_btn_create(s_settings);
    lv_obj_align(b3, LV_ALIGN_BOTTOM_MID, 0, 0);
    lv_obj_add_event_cb(b3, calibrate_cb, LV_EVENT_CLICKED, NULL);
    lv_label_set_text(lv_label_create(b3), T(S_BTN_CALIBRATE));
    lv_label_set_text(lv_label_create(b2), T(S_BTN_CLEAR));
}

static void update_cb(lv_event_t *e) { s_port.send(CMD_REFRESH, 0, 0); }

// ---- the touch calibration: four crosses near the corners, the raw reading of each, a mapping from them ----
static const int CAL_X[4] = {40, 440, 440, 40}, CAL_Y[4] = {40, 40, 280, 280};
static lv_obj_t *s_cal, *s_cal_cross, *s_cal_text;
static lv_timer_t *s_cal_timer;
static int s_cal_step, s_cal_n, s_cal_rx[4], s_cal_ry[4];
static long s_cal_sx, s_cal_sy;
static bool s_cal_down;

static void cal_show(void) {
    lv_obj_set_pos(s_cal_cross, CAL_X[s_cal_step] - 20, CAL_Y[s_cal_step] - 20);
    char t[96];
    snprintf(t, sizeof t, T(S_CAL_HINT), s_cal_step + 1);
    lv_label_set_text(s_cal_text, t);
}

static void cal_finish(void) {
    // which raw axis follows the screen's X: the one that changes between the left and the right crosses
    int dx_rx = abs((s_cal_rx[1] + s_cal_rx[2]) - (s_cal_rx[0] + s_cal_rx[3]));
    int dx_ry = abs((s_cal_ry[1] + s_cal_ry[2]) - (s_cal_ry[0] + s_cal_ry[3]));
    int swap = dx_ry > dx_rx;
    const int *ax = swap ? s_cal_ry : s_cal_rx, *ay = swap ? s_cal_rx : s_cal_ry;
    touch_cal_t c = {.swap = swap,
                     .x0 = CAL_X[0], .rx0 = (ax[0] + ax[3]) / 2, .x1 = CAL_X[1], .rx1 = (ax[1] + ax[2]) / 2,
                     .y0 = CAL_Y[0], .ry0 = (ay[0] + ay[1]) / 2, .y1 = CAL_Y[2], .ry1 = (ay[2] + ay[3]) / 2};
    if (abs(c.rx1 - c.rx0) < 400 || abs(c.ry1 - c.ry0) < 300) {   // touches too close together: nothing is kept
        s_cal_step = 0;
        lv_label_set_text(s_cal_text, T(S_CAL_RETRY));
        lv_obj_set_pos(s_cal_cross, CAL_X[0] - 20, CAL_Y[0] - 20);
        return;
    }
    s_port.save_cal(&c);
    lv_timer_del(s_cal_timer);
    s_cal_timer = NULL;
    lv_obj_del(s_cal);
    s_cal = NULL;
    trace("touch calibrated: swap %ld, x %ld..%ld, y %ld..%ld", (long)c.swap, (long)c.rx0, (long)c.rx1, (long)c.ry0, (long)c.ry1);
}

// Polls the raw touch: a press is averaged, its release takes the cross's reading and moves to the next one.
static void cal_poll(lv_timer_t *t) {
    int rx, ry;
    if (s_port.raw_touch && s_port.raw_touch(&rx, &ry)) {
        s_cal_down = true;
        s_cal_sx += rx; s_cal_sy += ry; s_cal_n++;
        return;
    }
    if (!s_cal_down) return;
    s_cal_down = false;
    if (s_cal_n > 0) {
        s_cal_rx[s_cal_step] = (int)(s_cal_sx / s_cal_n);
        s_cal_ry[s_cal_step] = (int)(s_cal_sy / s_cal_n);
        s_cal_step++;
    }
    s_cal_sx = s_cal_sy = 0; s_cal_n = 0;
    if (s_cal_step == 4) cal_finish(); else cal_show();
}

void ui_calibrate(void) {
    if (s_cal) return;
    s_cal = lv_obj_create(lv_layer_top());
    lv_obj_set_size(s_cal, 480, 320);
    lv_obj_set_pos(s_cal, 0, 0);
    lv_obj_set_style_bg_color(s_cal, lv_color_white(), 0);
    lv_obj_set_style_radius(s_cal, 0, 0);
    lv_obj_clear_flag(s_cal, LV_OBJ_FLAG_SCROLLABLE);
    s_cal_text = lv_label_create(s_cal);
    lv_obj_set_style_text_font(s_cal_text, &till_font_16, 0);
    lv_obj_align(s_cal_text, LV_ALIGN_CENTER, 0, 0);
    s_cal_cross = lv_label_create(s_cal);
    lv_obj_set_style_text_font(s_cal_cross, &till_font_28, 0);
    lv_obj_set_style_text_color(s_cal_cross, lv_color_hex(0xB00020), 0);
    lv_label_set_text(s_cal_cross, LV_SYMBOL_PLUS);
    s_cal_step = 0; s_cal_n = 0; s_cal_sx = s_cal_sy = 0; s_cal_down = false;
    cal_show();
    s_cal_timer = lv_timer_create(cal_poll, 20, NULL);
}

static void calibrate_cb(lv_event_t *e) {
    if (s_settings) { lv_obj_del(s_settings); s_settings = NULL; }
    ui_calibrate();
}

static void build_common(const char *title) {
    lv_obj_t *scr = lv_scr_act();
    lv_obj_set_style_bg_color(scr, lv_color_hex(0x101820), 0);
    lv_obj_t *t = lv_label_create(scr);
    lv_obj_set_style_text_color(t, lv_color_white(), 0);
    lv_obj_set_style_text_font(t, &till_font_20, 0);
    lv_label_set_text(t, title);
    lv_obj_align(t, LV_ALIGN_TOP_LEFT, 10, 8);
    if (strcmp(g_cfg.role, "roll") != 0) {   // the customer's roll has no settings; the till's need a long press, a staff gesture
        lv_obj_t *g = lv_btn_create(scr);
        lv_obj_set_size(g, 44, 34);
        lv_obj_align(g, LV_ALIGN_TOP_RIGHT, -8, 4);
        lv_obj_add_event_cb(g, open_settings_cb, LV_EVENT_LONG_PRESSED, NULL);
        lv_label_set_text(lv_label_create(g), LV_SYMBOL_SETTINGS);
        // the products read again without a restart
        lv_obj_t *u = lv_btn_create(scr);
        lv_obj_set_size(u, 44, 34);
        lv_obj_align(u, LV_ALIGN_TOP_RIGHT, -58, 4);
        lv_obj_add_event_cb(u, update_cb, LV_EVENT_CLICKED, NULL);
        lv_label_set_text(lv_label_create(u), LV_SYMBOL_REFRESH);
    }
    s_status = lv_label_create(scr);
    lv_obj_set_style_text_color(s_status, lv_color_hex(0x9fd3ff), 0);
    // two lines between the title and the gear, never cut with dots: a refusal's code and words, and the longer languages,
    // stay readable (the trace box keeps the whole text too)
    lv_obj_set_style_text_font(s_status, &till_font_14, 0);
    lv_label_set_long_mode(s_status, LV_LABEL_LONG_WRAP);
    lv_obj_set_size(s_status, 200, 36);
    lv_obj_align(s_status, LV_ALIGN_TOP_LEFT, 150, 6);
    lv_label_set_text(s_status, "");
}

static void pay_cb(lv_event_t *e) { s_port.send(CMD_PAY, 0, 0); }
static void retry_cb(lv_event_t *e) { s_port.send(CMD_RETRY, 0, 0); }

static void cash_show(void) {
    char due[40], given[40], change[40], t[160];
    money(due, sizeof due, s_cash_due, s_cash_cur);
    money(given, sizeof given, s_typed, s_cash_cur);
    if (s_typed >= s_cash_due) money(change, sizeof change, s_typed - s_cash_due, s_cash_cur); else snprintf(change, sizeof change, "-");
    snprintf(t, sizeof t, T(S_CASH_LINES), due, given, change);
    lv_label_set_text(s_cash_text, t);
    if (s_typed >= s_cash_due) lv_obj_clear_state(s_cash_ok, LV_STATE_DISABLED); else lv_obj_add_state(s_cash_ok, LV_STATE_DISABLED);
}
static void cash_key_cb(lv_event_t *e) {
    const char *k = lv_label_get_text(lv_obj_get_child(lv_event_get_target(e), 0));
    if (!strcmp(k, "C")) s_typed = 0;
    else if (strchr(k, '=')) s_typed = s_cash_due;                // exact amount
    else if (s_typed < 100000000000LL) {                          // at most 12 digits: never an overflow
        for (const char *d = k; *d; d++) s_typed = s_typed * 10 + (*d - '0');
    }
    cash_show();
}
static void cash_done_cb(lv_event_t *e) {
    int ok = (int)(intptr_t)lv_event_get_user_data(e);
    if (ok && s_typed < s_cash_due) return;                       // too little: nothing is sent
    s_port.send(CMD_CASH, ok, s_typed);
}
static void cash_open(int64_t due, const char *cur) {
    if (s_cash) return;
    s_cash_due = due; s_typed = 0;
    snprintf(s_cash_cur, sizeof s_cash_cur, "%s", cur);
    s_cash = lv_obj_create(lv_scr_act());
    lv_obj_set_size(s_cash, 472, 312);
    lv_obj_center(s_cash);
    lv_obj_clear_flag(s_cash, LV_OBJ_FLAG_SCROLLABLE);
    s_cash_text = lv_label_create(s_cash);
    lv_obj_set_style_text_font(s_cash_text, &till_font_20, 0);
    lv_obj_align(s_cash_text, LV_ALIGN_TOP_LEFT, 0, 0);
    static const char *keys[] = {"7", "8", "9", "4", "5", "6", "1", "2", "3", "C", "0", "00"};
    for (int i = 0; i < 12; i++) {   // a 3 x 4 keypad on the right
        lv_obj_t *b = lv_btn_create(s_cash);
        lv_obj_set_size(b, 62, 46);
        lv_obj_align(b, LV_ALIGN_TOP_RIGHT, -(2 - i % 3) * 68, (i / 3) * 52);
        lv_label_set_text(lv_label_create(b), keys[i]);
        lv_obj_add_event_cb(b, cash_key_cb, LV_EVENT_CLICKED, NULL);
    }
    lv_obj_t *exact = lv_btn_create(s_cash);   // "=": the exact amount, under the totals
    lv_obj_set_size(exact, 120, 46);
    lv_obj_align(exact, LV_ALIGN_TOP_LEFT, 0, 112);
    lv_label_set_text(lv_label_create(exact), T(S_BTN_EXACT));
    lv_obj_add_event_cb(exact, cash_key_cb, LV_EVENT_CLICKED, NULL);
    lv_obj_t *cancel = lv_btn_create(s_cash);
    lv_obj_align(cancel, LV_ALIGN_BOTTOM_LEFT, 0, 0);
    lv_label_set_text(lv_label_create(cancel), T(S_BTN_CANCEL));
    lv_obj_add_event_cb(cancel, cash_done_cb, LV_EVENT_CLICKED, (void *)(intptr_t)0);
    s_cash_ok = lv_btn_create(s_cash);
    lv_obj_set_size(s_cash_ok, 200, 46);
    lv_obj_align(s_cash_ok, LV_ALIGN_BOTTOM_LEFT, 110, 0);
    lv_obj_set_style_bg_color(s_cash_ok, lv_color_hex(0x1B7F3B), 0);
    lv_label_set_text(lv_label_create(s_cash_ok), T(S_BTN_CASH_OK));
    lv_obj_add_event_cb(s_cash_ok, cash_done_cb, LV_EVENT_CLICKED, (void *)(intptr_t)1);
    cash_show();
}
static void cash_close(void) { if (s_cash) { lv_obj_del(s_cash); s_cash = NULL; } }

void ui_build_till(void) {
    build_common(T(S_TITLE_TILL));
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
    // the keypad sits where the product keys are; the switch beside the update button shows which one is up
    s_keypad = lv_obj_create(scr);
    lv_obj_set_size(s_keypad, 468, 148);
    lv_obj_align(s_keypad, LV_ALIGN_TOP_LEFT, 6, 46);
    lv_obj_clear_flag(s_keypad, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_set_style_pad_all(s_keypad, 4, 0);
    s_keypad_label = lv_label_create(s_keypad);
    lv_obj_set_style_text_font(s_keypad_label, &till_font_16, 0);
    lv_obj_align(s_keypad_label, LV_ALIGN_TOP_LEFT, 4, 0);
    static const char *digits[] = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "C"};
    for (int i = 0; i < 11; i++) {
        lv_obj_t *b = lv_btn_create(s_keypad);
        lv_obj_set_size(b, 66, 50);
        lv_obj_align(b, LV_ALIGN_TOP_LEFT, (i % 6) * 74, 26 + (i / 6) * 58);
        lv_obj_add_event_cb(b, qty_key_cb, LV_EVENT_CLICKED, (void *)(intptr_t)(i == 10 ? -1 : (i == 9 ? 0 : i + 1)));
        lv_label_set_text(lv_label_create(b), digits[i]);
    }
    lv_obj_add_flag(s_keypad, LV_OBJ_FLAG_HIDDEN);
    lv_obj_t *sw = lv_btn_create(scr);
    lv_obj_set_size(sw, 58, 34);
    lv_obj_align(sw, LV_ALIGN_TOP_RIGHT, -108, 4);
    lv_obj_add_event_cb(sw, switch_cb, LV_EVENT_CLICKED, NULL);
    s_switch_label = lv_label_create(sw);
    lv_obj_center(s_switch_label);
    qty_show();
    build_trace_box(198, 58);
    s_basket_label = lv_label_create(scr);
    lv_obj_set_style_text_color(s_basket_label, lv_color_white(), 0);
    lv_obj_set_style_text_font(s_basket_label, &till_font_28, 0);
    lv_obj_align(s_basket_label, LV_ALIGN_BOTTOM_LEFT, 12, -14);
    lv_label_set_text(s_basket_label, "");
    lv_obj_t *n = lv_btn_create(scr);
    lv_obj_set_size(n, 150, 50);
    lv_obj_align(n, LV_ALIGN_BOTTOM_RIGHT, -8, -8);
    lv_obj_add_event_cb(n, next_cb, LV_EVENT_CLICKED, NULL);
    lv_label_set_text(lv_label_create(n), T(S_ST_NEXT));
    s_pay = lv_btn_create(scr);
    lv_obj_set_size(s_pay, 120, 50);
    lv_obj_align(s_pay, LV_ALIGN_BOTTOM_RIGHT, -166, -8);
    lv_obj_set_style_bg_color(s_pay, lv_color_hex(0x1B7F3B), 0);
    lv_obj_add_event_cb(s_pay, pay_cb, LV_EVENT_CLICKED, NULL);
    lv_label_set_text(lv_label_create(s_pay), T(S_BTN_PAY));
    lv_obj_add_state(s_pay, LV_STATE_DISABLED);
    s_retry = lv_btn_create(scr);
    lv_obj_set_size(s_retry, 120, 50);
    lv_obj_align(s_retry, LV_ALIGN_BOTTOM_RIGHT, -166, -8);
    lv_obj_add_event_cb(s_retry, retry_cb, LV_EVENT_CLICKED, NULL);
    lv_label_set_text(lv_label_create(s_retry), T(S_BTN_RETRY));
    lv_obj_add_flag(s_retry, LV_OBJ_FLAG_HIDDEN);
}

void ui_build_roll(void) {
    build_common(T(S_TITLE_ROLL));
    lv_obj_t *scr = lv_scr_act();
    s_roll_list = lv_obj_create(scr);
    lv_obj_set_size(s_roll_list, 464, 158);
    lv_obj_align(s_roll_list, LV_ALIGN_TOP_LEFT, 8, 46);
    lv_obj_set_style_bg_color(s_roll_list, lv_color_hex(0xFAF7EE), 0);
    lv_obj_set_style_text_color(s_roll_list, lv_color_hex(0x202020), 0);
    lv_obj_set_flex_flow(s_roll_list, LV_FLEX_FLOW_COLUMN);
    build_trace_box(210, 46);
    s_total = lv_label_create(scr);
    lv_obj_set_style_text_color(s_total, lv_color_white(), 0);
    lv_obj_set_style_text_font(s_total, &till_font_28, 0);
    lv_obj_align(s_total, LV_ALIGN_BOTTOM_RIGHT, -12, -12);
    lv_label_set_text(s_total, "");
}

void ui_refresh(const shared_t *cp) {
    const shared_t copy = *cp;
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
                lv_obj_set_style_text_font(l, &till_font_16, 0);
                lv_label_set_text(l, row);
            }
            money(m, sizeof m, copy.roll.total_minor, copy.roll.currency);
            char tt[64]; snprintf(tt, sizeof tt, T(S_TOTAL), m);
            lv_label_set_text(s_total, tt);
        } else lv_label_set_text(s_total, "");
        return;
    }
    s_products = cp->n_products;
    for (int i = 0; i < MAX_PRODUCTS; i++) {   // till
        if (i < copy.n_products) {
            char a[24];
            money(a, sizeof a, copy.products[i].price_minor, "");
            char txt[96]; snprintf(txt, sizeof txt, "%s\n%d.%02d", copy.products[i].name, copy.products[i].price_minor / 100, copy.products[i].price_minor % 100);
            lv_label_set_text(lv_obj_get_child(s_keys[i], 0), txt);
            if (!s_keypad_on) lv_obj_clear_flag(s_keys[i], LV_OBJ_FLAG_HIDDEN);
        } else lv_obj_add_flag(s_keys[i], LV_OBJ_FLAG_HIDDEN);
    }
    if (copy.has_roll) {
        money(m, sizeof m, copy.roll.total_minor, copy.roll.currency);
        int items = 0;
        for (int i = 0; i < copy.roll.n; i++) items += atoi(copy.roll.lines[i].qty);
        char tt[80]; snprintf(tt, sizeof tt, T(S_BASKET), items, m);
        lv_label_set_text(s_basket_label, tt);
    } else lv_label_set_text(s_basket_label, "");
    // the payment: Pay only on a priced basket while selling; the cash count while counting; Ask again while uncertain
    bool payable = copy.phase == PH_SELL && copy.has_roll && copy.roll.total_minor > 0;
    if (payable) lv_obj_clear_state(s_pay, LV_STATE_DISABLED); else lv_obj_add_state(s_pay, LV_STATE_DISABLED);
    if (copy.phase == PH_UNCERTAIN) { lv_obj_add_flag(s_pay, LV_OBJ_FLAG_HIDDEN); lv_obj_clear_flag(s_retry, LV_OBJ_FLAG_HIDDEN); }
    else { lv_obj_clear_flag(s_pay, LV_OBJ_FLAG_HIDDEN); lv_obj_add_flag(s_retry, LV_OBJ_FLAG_HIDDEN); }
    if (copy.phase == PH_CASH) cash_open(copy.due, copy.roll.currency); else cash_close();
}


void ui_init(const ui_port_t *port) {
    s_port = *port;
    lv_timer_create(trace_box_cb, 300, NULL);
}

void ui_build_not_set_up(void) {
    build_common(T(S_TITLE_TILL));
    lv_label_set_text(s_status, T(S_ST_NOT_SET_UP));
    build_trace_box(60, 58);
}
