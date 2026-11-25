// SPDX-License-Identifier: AGPL-3.0-or-later
// #4456 (E05) host LVGL action tests: the board's own screens (main/ui.c) on a 480 x 320 display in memory, driven by a
// pointer that presses the real buttons, found by their text in each of the five languages:
//   a product key adds the product; Pay cash opens the cash count only on a priced basket;
//   too little cash sends nothing; 2000 given for 1250 shows 7.50 change and sends the cash given;
//   a result that is not known offers Ask again instead of Pay; a refusal is shown in words.
#include <stdio.h>
#include <string.h>
#include "cfg.h"
#include "lvgl.h"
#include "strings.h"
#include "ui.h"

cfg_t g_cfg = {.role = "till"};
static int failed, passed;
#define CHECK(cond, what) do { if (cond) passed++; else { failed++; printf("FAIL [%s] %s\n", s_lang, what); } } while (0)
static const char *s_lang = "en";

// ---- the recorder behind the port ----
static int sent_kind = -1, sent_index = -1, sent_count;
static int64_t sent_value;
static void rec_send(int kind, int index, int64_t value) { sent_kind = kind; sent_index = index; sent_value = value; sent_count++; }
static void rec_reset(void) {}
// the raw touch for the calibration test: four presses at the corners, raw Y following the screen's X right to left
static int raw_step = -1, raw_ticks;
static const int RAW_X[4] = {3500, 3500, 600, 600}, RAW_Y[4] = {3600, 700, 700, 3600};
static bool rec_raw(int *rx, int *ry) {
    if (raw_step < 0 || raw_step > 3) return false;
    int phase = raw_ticks++ % 6;   // per cross: three polls down, three up
    if (phase < 3) { *rx = RAW_X[raw_step]; *ry = RAW_Y[raw_step]; return true; }
    if (phase == 5) raw_step++;
    return false;
}
static touch_cal_t saved_cal;
static int cal_saves;
static void rec_save_cal(const touch_cal_t *c) { saved_cal = *c; cal_saves++; }
static void forget(void) { sent_kind = sent_index = -1; sent_value = 0; sent_count = 0; }

// ---- a display in memory and a pointer ----
static lv_disp_draw_buf_t draw;
static lv_color_t buf[480 * 40];
static lv_disp_drv_t disp;
static lv_indev_drv_t indev;
static int px, py, pressed;
static void flush(lv_disp_drv_t *d, const lv_area_t *a, lv_color_t *c) { (void)a; (void)c; lv_disp_flush_ready(d); }
static void read(lv_indev_drv_t *d, lv_indev_data_t *data) { (void)d; data->point.x = px; data->point.y = py; data->state = pressed ? LV_INDEV_STATE_PR : LV_INDEV_STATE_REL; }
static void pump(int ms) { for (int t = 0; t < ms; t += 5) { lv_tick_inc(5); lv_timer_handler(); } }

// The first VISIBLE label with [text]: a hidden panel's buttons (the keypad behind the keys) are not on screen.
static lv_obj_t *find(lv_obj_t *o, const char *text) {
    if (lv_obj_has_flag(o, LV_OBJ_FLAG_HIDDEN)) return NULL;
    if (lv_obj_check_type(o, &lv_label_class) && !strcmp(lv_label_get_text(o), text)) return o;
    for (uint32_t i = 0; i < lv_obj_get_child_cnt(o); i++) {
        lv_obj_t *f = find(lv_obj_get_child(o, i), text);
        if (f) return f;
    }
    return NULL;
}
static lv_obj_t *find_prefix(lv_obj_t *o, const char *prefix) {
    if (lv_obj_has_flag(o, LV_OBJ_FLAG_HIDDEN)) return NULL;
    if (lv_obj_check_type(o, &lv_label_class) && !strncmp(lv_label_get_text(o), prefix, strlen(prefix))) return o;
    for (uint32_t i = 0; i < lv_obj_get_child_cnt(o); i++) {
        lv_obj_t *f = find_prefix(lv_obj_get_child(o, i), prefix);
        if (f) return f;
    }
    return NULL;
}
// Presses the button that carries [text], as a finger would: down at its centre, then up. False when not visible.
static bool press(const char *text) {
    lv_obj_t *l = find(lv_scr_act(), text);
    if (!l) return false;
    lv_obj_t *b = lv_obj_get_parent(l);
    for (lv_obj_t *o = b; o; o = lv_obj_get_parent(o)) if (lv_obj_has_flag(o, LV_OBJ_FLAG_HIDDEN)) return false;
    lv_area_t a;
    lv_obj_get_coords(b, &a);
    px = (a.x1 + a.x2) / 2; py = (a.y1 + a.y2) / 2;
    pressed = 1; pump(60);
    pressed = 0; pump(60);
    return true;
}
static bool shown_disabled(const char *text) {
    lv_obj_t *l = find(lv_scr_act(), text);
    return l && lv_obj_has_state(lv_obj_get_parent(l), LV_STATE_DISABLED);
}

static shared_t state(int phase, int total) {
    shared_t s = {0};
    s.n_products = 2;
    snprintf(s.products[0].name, sizeof s.products[0].name, "Coffee");
    s.products[0].price_minor = 250;
    snprintf(s.products[1].name, sizeof s.products[1].name, "Cake");
    s.products[1].price_minor = 1000;
    if (total > 0) {
        s.has_roll = true;
        s.roll.n = 1;
        s.roll.total_minor = total;
        s.roll.revision = 2;
        snprintf(s.roll.currency, sizeof s.roll.currency, "EUR");
        snprintf(s.roll.lines[0].qty, sizeof s.roll.lines[0].qty, "1");
        s.roll.lines[0].gross_minor = total;
    }
    s.phase = phase;
    s.due = total;
    return s;
}

static void one_language(const char *lang) {
    s_lang = lang;
    strings_set_lang(lang);
    lv_obj_t *scr = lv_obj_create(NULL);
    lv_scr_load(scr);
    static const ui_port_t port = {.send = rec_send, .factory_reset = rec_reset, .raw_touch = rec_raw, .save_cal = rec_save_cal};
    ui_init(&port);
    ui_build_till();

    // nothing priced: Pay cannot be pressed
    shared_t s = state(PH_SELL, 0);
    ui_refresh(&s); pump(50);
    CHECK(shown_disabled(T(S_BTN_PAY)), "Pay cash is disabled before a product is priced");
    forget();
    press(T(S_BTN_PAY));
    CHECK(sent_count == 0, "a disabled Pay sends nothing");

    // a product key adds the product
    lv_obj_t *key = find_prefix(lv_scr_act(), "Coffee");
    CHECK(key != NULL, "the product key shows its name");
    forget();
    if (key) {
        lv_area_t a; lv_obj_get_coords(lv_obj_get_parent(key), &a);
        px = (a.x1 + a.x2) / 2; py = (a.y1 + a.y2) / 2; pressed = 1; pump(60); pressed = 0; pump(60);
    }
    CHECK(sent_kind == CMD_TAP && sent_index == 0, "pressing the first key sends it");

    // a priced basket: Pay opens the count
    s = state(PH_SELL, 1250);
    ui_refresh(&s); pump(50);
    forget();
    CHECK(press(T(S_BTN_PAY)) && sent_kind == CMD_PAY, "Pay cash is pressed on a priced basket");

    // the cash count: too little sends nothing; 2000 for 1250 shows 7.50 and sends 2000
    s = state(PH_CASH, 1250);
    ui_refresh(&s); pump(50);
    forget();
    press("1"); press("0"); press("0"); press("0");
    CHECK(shown_disabled(T(S_BTN_CASH_OK)), "Cash received stays disabled for too little");
    press(T(S_BTN_CASH_OK));
    CHECK(sent_kind != CMD_CASH, "too little cash sends nothing");
    press("C"); press("2"); press("0"); press("00");
    CHECK(find_prefix(lv_scr_act(), "") && find(lv_scr_act(), T(S_BTN_CASH_OK)) && !shown_disabled(T(S_BTN_CASH_OK)), "enough cash enables Cash received");
    char want[160];
    snprintf(want, sizeof want, T(S_CASH_LINES), "12.50 EUR", "20.00 EUR", "7.50 EUR");
    CHECK(find(lv_scr_act(), want) != NULL, "the count shows total, given and the change");
    forget();
    press(T(S_BTN_CASH_OK));
    CHECK(sent_kind == CMD_CASH && sent_index == 1 && sent_value == 2000, "Cash received sends the cash given");

    // a result not known: Ask again instead of Pay
    s = state(PH_UNCERTAIN, 1250);
    snprintf(s.status, sizeof s.status, "%s", T(S_ST_UNKNOWN));
    ui_refresh(&s); pump(50);
    CHECK(find(lv_scr_act(), T(S_ST_UNKNOWN)) != NULL, "the status says the result is not known");
    forget();
    CHECK(!press(T(S_BTN_PAY)), "Pay is not offered while the result is not known");
    CHECK(press(T(S_BTN_RETRY)) && sent_kind == CMD_RETRY, "Ask again is offered and sends");

    // a refusal in words
    s = state(PH_SELL, 1250);
    snprintf(s.status, sizeof s.status, T(S_ST_NOT_PAID), "DKL01 this operation is not supported here");
    ui_refresh(&s); pump(50);
    CHECK(find(lv_scr_act(), s.status) != NULL, "a refusal is shown with its code and words");
    // the update button reads the products again
    forget();
    CHECK(press(LV_SYMBOL_REFRESH) && sent_kind == CMD_REFRESH, "the update button asks for the products again");

    // the keypad: 3 typed, back on the items the switch says x3, the next product goes with 3
    s = state(PH_SELL, 0);
    ui_refresh(&s); pump(50);
    CHECK(press(T(S_BTN_KEYPAD)), "the 123 switch shows the keypad");
    press("3");
    CHECK(press(T(S_BTN_ITEMS)), "the switch goes back to the items");
    CHECK(find(lv_scr_act(), "x3") != NULL, "the switch shows the quantity waiting");
    forget();
    lv_obj_t *k2 = find_prefix(lv_scr_act(), "Cake");
    if (k2) {
        lv_area_t a; lv_obj_get_coords(lv_obj_get_parent(k2), &a);
        px = (a.x1 + a.x2) / 2; py = (a.y1 + a.y2) / 2; pressed = 1; pump(60); pressed = 0; pump(60);
    }
    CHECK(sent_kind == CMD_TAP && sent_index == 1 && sent_value == 3, "the next product goes with the quantity typed");
    CHECK(find(lv_scr_act(), T(S_BTN_KEYPAD)) != NULL, "and the quantity is used once");
}

static void calibration(void) {
    s_lang = "calibration";
    strings_set_lang("en");
    raw_step = 0; raw_ticks = 0; cal_saves = 0;
    ui_calibrate();
    pump(2000);
    CHECK(cal_saves == 1, "four touches give one calibration");
    CHECK(saved_cal.swap == 1, "the raw axis that follows the screen's X is found (Y here)");
    CHECK(saved_cal.rx0 == 3600 && saved_cal.rx1 == 700, "the left and right crosses give the X range");
    CHECK(saved_cal.ry0 == 3500 && saved_cal.ry1 == 600, "the top and bottom crosses give the Y range");
}


int main(void) {
    lv_init();
    lv_disp_draw_buf_init(&draw, buf, NULL, 480 * 40);
    lv_disp_drv_init(&disp);
    disp.hor_res = 480; disp.ver_res = 320; disp.flush_cb = flush; disp.draw_buf = &draw;
    lv_disp_drv_register(&disp);
    lv_indev_drv_init(&indev);
    indev.type = LV_INDEV_TYPE_POINTER; indev.read_cb = read;
    lv_indev_drv_register(&indev);
    const char *langs[] = {"en", "de", "fr", "es", "it"};
    for (int i = 0; i < 5; i++) one_language(langs[i]);
    calibration();
    printf("%d passed, %d failed\n", passed, failed);
    return failed ? 1 : 0;
}
