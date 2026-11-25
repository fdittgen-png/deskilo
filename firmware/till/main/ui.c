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

static void key_cb(lv_event_t *e) { s_port.send(CMD_TAP, (int)(intptr_t)lv_event_get_user_data(e), 0); }
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
    lv_label_set_text(lv_label_create(b2), T(S_BTN_CLEAR));
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
    }
    s_status = lv_label_create(scr);
    lv_obj_set_style_text_color(s_status, lv_color_hex(0x9fd3ff), 0);
    // two lines between the title and the gear, never cut with dots: a refusal's code and words, and the longer languages,
    // stay readable (the trace box keeps the whole text too)
    lv_obj_set_style_text_font(s_status, &till_font_14, 0);
    lv_label_set_long_mode(s_status, LV_LABEL_LONG_WRAP);
    lv_obj_set_size(s_status, 268, 36);
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
