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
#include "esp_app_desc.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "lvgl.h"
#include "net.h"
#include "pending.h"
#include "trace.h"
#include "strings.h"

LV_FONT_DECLARE(till_font_14)
LV_FONT_DECLARE(till_font_16)
LV_FONT_DECLARE(till_font_20)
LV_FONT_DECLARE(till_font_28)

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
    // #4456 the payment: where the sale stands, what is due and given, and the receipt it got
    int phase;
    int64_t due, given;
    char paid_number[32];
    uint32_t version;
} shared_t;
static shared_t S;
static SemaphoreHandle_t s_lock;
static QueueHandle_t s_cmd;
enum { CMD_TAP, CMD_NEXT, CMD_REPORT, CMD_PAY, CMD_CASH, CMD_RETRY };
// The sale's phase: selling; the cash being counted; sent; paid; sent without a proven answer; a payment of another binding
// waits and nothing is sold here.
enum { PH_SELL, PH_CASH, PH_PAYING, PH_PAID, PH_UNCERTAIN, PH_BLOCKED };
static int64_t s_cash_given;   // set by the keypad before CMD_CASH
typedef struct { int kind; int index; } cmd_t;
static basket_line_t s_basket[MAX_PRODUCTS];
static int s_basket_n;

static void with_lock(void (*fn)(void *), void *arg) { xSemaphoreTake(s_lock, portMAX_DELAY); fn(arg); S.version++; xSemaphoreGive(s_lock); }
static void set_status_fn(void *a) { snprintf(S.status, sizeof S.status, "%s", (const char *)a); }
// A failure is traced and, once Deskilo is reachable, reported to it -- at most one report per kind every ten minutes,
// inside the installation's hourly budget (trace.reports_per_hour).
static void fail(const char *kind, const char *why) {
    static struct { char kind[24]; int64_t at; } sent[6];
    trace("%s: %s", kind, why);
    int64_t now = esp_timer_get_time(), free_slot = -1;
    for (int i = 0; i < 6; i++) {
        if (!strcmp(sent[i].kind, kind)) { if (now - sent[i].at < 600LL * 1000000) return; sent[i].at = now; free_slot = -2; break; }
        if (!sent[i].kind[0] && free_slot == -1) free_slot = i;
    }
    if (free_slot >= 0) { snprintf(sent[free_slot].kind, sizeof sent[free_slot].kind, "%s", kind); sent[free_slot].at = now; }
    char type[48];
    snprintf(type, sizeof type, "till.%s", kind);
    api_report(g_cfg.role, type, api_last_code());
}
static void set_status(const char *t) { with_lock(set_status_fn, (void *)t); }

// ---- money ----
static int exponent_of(const char *c) {
    if (!strcmp(c, "JPY") || !strcmp(c, "KRW") || !strcmp(c, "ISK")) return 0;
    if (!strcmp(c, "KWD") || !strcmp(c, "BHD") || !strcmp(c, "OMR") || !strcmp(c, "TND") || !strcmp(c, "JOD")) return 3;
    return 2;
}
static void money(char *out, size_t cap, int64_t minor, const char *cur) {
    int e = exponent_of(cur);
    int64_t div = 1;
    for (int i = 0; i < e; i++) div *= 10;
    const char *sign = minor < 0 ? "-" : "";
    int64_t a = minor < 0 ? -minor : minor;
    char t[64];   // room for any int64 and a currency: the caller's buffer only cuts the end
    if (e == 0) snprintf(t, sizeof t, "%s%lld %.3s", sign, (long long)a, cur);
    else snprintf(t, sizeof t, "%s%lld.%0*lld %.3s", sign, (long long)(a / div), e, (long long)(a % div), cur);
    size_t n = strlen(t) < cap - 1 ? strlen(t) : cap - 1;
    memcpy(out, t, n);
    out[n] = 0;
}

// ---- the network task ----
static void roll_set_fn(void *a) { S.roll = *(roll_t *)a; S.has_roll = S.roll.n > 0; }
static void products_set_fn(void *a) { S.n_products = 0; }

static void add_to_basket(const char *id) {
    for (int i = 0; i < s_basket_n; i++)
        if (!strcmp(s_basket[i].item_id, id)) { s_basket[i].qty++; return; }
    if (s_basket_n < MAX_PRODUCTS) { strncpy(s_basket[s_basket_n].item_id, id, 39); s_basket[s_basket_n].item_id[39] = 0; s_basket[s_basket_n++].qty = 1; }
}

static void set_phase(int phase, const char *status) {
    xSemaphoreTake(s_lock, portMAX_DELAY);
    S.phase = phase;
    if (status) snprintf(S.status, sizeof S.status, "%s", status);
    S.version++;
    xSemaphoreGive(s_lock);
}

static int save_attempt(const void *a) { return pending_save((const pending_t *)a) == ESP_OK ? 0 : 1; }

// Sends the attempt; a session that ran out (401) is renewed and the SAME request asked once more.
static pay_result_t send_attempt(const void *a, char *number, int ncap, char *why, int cap) {
    const pending_t *p = (const pending_t *)a;
    pay_result_t r = api_finalize_cash(p, number, ncap, why, cap);
    if (r == PAY_UNCERTAIN && strstr(why, "401")) {
        char w2[96];
        if (api_sign_in(w2, sizeof w2)) r = api_finalize_cash(p, number, ncap, why, cap);
    }
    return r;
}

// What an answer does to the sale: only a proven one moves it on; anything else keeps it uncertain and the next customer waits.
static void conclude(const pending_t *p, pay_result_t r, const char *number, const char *why) {
    if (r == PAY_DONE) {
        paid_t paid = {.total_minor = p->total_minor, .given_minor = p->given_minor};
        snprintf(paid.number, sizeof paid.number, "%s", number);
        snprintf(paid.currency, sizeof paid.currency, "%s", p->currency);
        if (pending_settle(&paid) != ESP_OK) trace("paid %s, but the answer is not kept yet", number);   // a replay finds it again
        char ch[40], st[120];
        money(ch, sizeof ch, p->given_minor - p->total_minor, p->currency);
        snprintf(st, sizeof st, T(S_ST_PAID), number, ch);
        trace("paid %s: %lld, given %lld", number, (long long)p->total_minor, (long long)p->given_minor);
        xSemaphoreTake(s_lock, portMAX_DELAY);
        snprintf(S.paid_number, sizeof S.paid_number, "%s", number);
        S.given = p->given_minor;
        S.due = p->total_minor;
        xSemaphoreGive(s_lock);
        set_phase(PH_PAID, st);
    } else if (r == PAY_REFUSED) {
        pending_drop();
        fail("pay", why);
        char st[120];
        snprintf(st, sizeof st, T(S_ST_NOT_PAID), why);
        set_phase(PH_SELL, st);
    } else if (r == PAY_NOT_STARTED) {
        trace("payment not started: %s", why);
        set_phase(PH_SELL, T(S_ST_NOT_STARTED));
    } else {
        trace("payment result unknown: %s (request %.8s)", why, p->request_id);
        set_phase(PH_UNCERTAIN, T(S_ST_UNKNOWN));
    }
}

// Asks Deskilo again about the attempt kept in flash: the same request, the same payload.
static void settle(const pending_t *p) {
    char number[32] = "", why[96] = "";
    pay_result_t r = send_attempt(p, number, sizeof number, why, sizeof why);
    conclude(p, r, number, why);
}

static void net_task(void *arg) {
    static roll_t roll;
    static product_t prods[MAX_PRODUCTS];
    char why[96] = "", seen_receipt[40] = "x";   // "x": the first answer is always traced
    int seen_revision = -1;
    trace("start: role %s, firmware %s", g_cfg.role, esp_app_get_description()->version);
    set_status(T(S_ST_WIFI));
    if (net_connect(g_cfg.ssid, g_cfg.wifi_pass) != ESP_OK) { trace("Wi-Fi or time failed"); set_status("Wi-Fi or time failed: check Settings"); vTaskDelete(NULL); }
    trace("Wi-Fi up");
    set_status(T(S_ST_SIGNING_IN));
    if (!api_sign_in(why, sizeof why)) { trace("%s", why); set_status(why); vTaskDelete(NULL); }   // no session: nothing to report with
    trace("signed in");
    xSemaphoreTake(s_lock, portMAX_DELAY); S.online = true; xSemaphoreGive(s_lock);
    if (!strcmp(g_cfg.role, "till")) {
        int n = api_products(prods, MAX_PRODUCTS, why, sizeof why);
        xSemaphoreTake(s_lock, portMAX_DELAY);
        if (n >= 0) { memcpy(S.products, prods, sizeof prods); S.n_products = n; }
        snprintf(S.status, sizeof S.status, "%s", n < 0 ? why : (n == 0 ? T(S_ST_NO_PRODUCTS) : T(S_ST_CHOOSE)));
        S.version++;
        xSemaphoreGive(s_lock);
        if (n < 0) fail("products", why); else trace("%d products", n);
        pending_t p;
        if (pending_load(&p)) {
            // a payment sent before the restart: settled first, under the binding it was made in, before anything is sold
            if (strcmp(p.workspace, g_cfg.workspace) || strcmp(p.server, g_cfg.url)) {
                trace("a payment of another business is pending (%.8s): nothing is sold here", p.request_id);
                set_phase(PH_BLOCKED, T(S_ST_PENDING_OTHER));
            } else {
                trace("restart with a payment pending (%.8s)", p.request_id);
                set_phase(PH_UNCERTAIN, T(S_ST_UNKNOWN));
                settle(&p);
            }
        }
    } else set_status(T(S_ST_WAITING));
    TickType_t last_refresh = xTaskGetTickCount();
    for (;;) {
        cmd_t c;
        bool got = xQueueReceive(s_cmd, &c, strcmp(g_cfg.role, "roll") == 0 ? pdMS_TO_TICKS(1500) : pdMS_TO_TICKS(1000)) == pdTRUE;
        if (xTaskGetTickCount() - last_refresh > pdMS_TO_TICKS(40 * 60 * 1000)) { if (api_sign_in(why, sizeof why)) last_refresh = xTaskGetTickCount(); }
        static int idle;
        int phase_now;
        xSemaphoreTake(s_lock, portMAX_DELAY); phase_now = S.phase; xSemaphoreGive(s_lock);
        if (phase_now == PH_UNCERTAIN && ((got && c.kind == CMD_RETRY) || (!got && ++idle >= 10))) {
            idle = 0;
            pending_t p;
            if (pending_load(&p)) settle(&p); else set_phase(PH_SELL, T(S_ST_CHOOSE));
            continue;
        }
        if (got && c.kind == CMD_REPORT) { set_status(api_report(g_cfg.role, "till.traces_sent", "") ? T(S_ST_TRACES_SENT) : T(S_ST_TRACES_NOT_SENT)); continue; }
        if (!strcmp(g_cfg.role, "roll")) {
            bool ok = api_roll(&roll, why, sizeof why);
            xSemaphoreTake(s_lock, portMAX_DELAY);
            bool changed = ok ? (strcmp(seen_receipt, roll.receipt_id) || seen_revision != roll.revision) : (seen_receipt[0] != 0 || why[0]);
            if (ok) { S.roll = roll; S.has_roll = true; snprintf(S.status, sizeof S.status, T(S_ST_RECEIPT), roll.receipt_id, roll.revision); }
            else { S.has_roll = false; snprintf(S.status, sizeof S.status, "%s", why[0] ? why : T(S_ST_WAITING)); }
            S.version++;
            xSemaphoreGive(s_lock);
            if (changed) {
                if (ok) trace("receipt %.8s rev %d: %d lines", roll.receipt_id, roll.revision, roll.n);
                else if (why[0]) fail("roll", why);
                else trace("no open receipt");
                snprintf(seen_receipt, sizeof seen_receipt, "%s", ok ? roll.receipt_id : "");
                seen_revision = ok ? roll.revision : 0;
            }
            continue;
        }
        if (!got) continue;
        if (c.kind == CMD_NEXT && (phase_now == PH_UNCERTAIN || phase_now == PH_PAYING || phase_now == PH_BLOCKED)) {
            set_status(phase_now == PH_BLOCKED ? T(S_ST_PENDING_OTHER) : T(S_ST_SETTLE_FIRST));
            continue;
        }
        if (c.kind == CMD_PAY) {
            if (phase_now != PH_SELL) continue;
            int64_t due = api_draft_total();
            xSemaphoreTake(s_lock, portMAX_DELAY);
            bool payable = S.has_roll && S.roll.revision > 0 && due > 0 && due == S.roll.total_minor;
            if (payable) { S.due = due; S.phase = PH_CASH; S.version++; }
            xSemaphoreGive(s_lock);
            if (!payable) set_status(T(S_ST_NOTHING_TO_PAY));
            continue;
        }
        if (c.kind == CMD_CASH) {
            if (phase_now != PH_CASH) continue;
            if (c.index == 0) { set_phase(PH_SELL, T(S_ST_CANCELLED)); continue; }
            pending_t p = {0};
            xSemaphoreTake(s_lock, portMAX_DELAY);
            p.total_minor = S.due;
            p.given_minor = s_cash_given;
            snprintf(p.receipt_id, sizeof p.receipt_id, "%.36s", S.roll.receipt_id);
            p.revision = S.roll.revision;
            snprintf(p.currency, sizeof p.currency, "%s", S.roll.currency);
            xSemaphoreGive(s_lock);
            // the server's total, unchanged since it was shown, and enough cash: else nothing is sent
            int64_t change;
            if (!pay_cash_enough(p.total_minor, p.given_minor, &change) || api_draft_total() != p.total_minor) { set_phase(PH_CASH, T(S_ST_NOT_ENOUGH)); continue; }
            api_new_id(p.request_id);
            snprintf(p.workspace, sizeof p.workspace, "%.36s", g_cfg.workspace);
            snprintf(p.server, sizeof p.server, "%.95s", g_cfg.url);
            trace("paying %.8s rev %d: %lld cash, given %lld (request %.8s)", p.receipt_id, p.revision, (long long)p.total_minor, (long long)p.given_minor, p.request_id);
            set_phase(PH_PAYING, T(S_ST_PAYING));
            char number[32] = "", pwhy[96] = "";
            pay_result_t r = pay_run(&p, save_attempt, send_attempt, number, sizeof number, pwhy, sizeof pwhy);   // kept first, then sent
            conclude(&p, r, number, pwhy);
            continue;
        }
        if (c.kind == CMD_RETRY) continue;
        if (c.kind == CMD_NEXT) {
            s_basket_n = 0;
            api_reset_draft();
            memset(&roll, 0, sizeof roll);
            xSemaphoreTake(s_lock, portMAX_DELAY); S.roll = roll; S.has_roll = false; S.phase = PH_SELL; S.paid_number[0] = 0; snprintf(S.status, sizeof S.status, T(S_ST_NEXT)); S.version++; xSemaphoreGive(s_lock);
            trace("next customer");
            continue;
        }
        if (phase_now != PH_SELL) continue;   // the basket is frozen from the cash count on
        product_t p;
        xSemaphoreTake(s_lock, portMAX_DELAY); bool in = c.index >= 0 && c.index < S.n_products; if (in) p = S.products[c.index]; xSemaphoreGive(s_lock);
        if (!in) continue;
        add_to_basket(p.id);
        set_status(T(S_ST_SENDING));
        bool ok = api_draft(s_basket, s_basket_n, &roll, why, sizeof why);
        if (!ok && strstr(why, "401")) { api_sign_in(why, sizeof why); ok = api_draft(s_basket, s_basket_n, &roll, why, sizeof why); }
        xSemaphoreTake(s_lock, portMAX_DELAY);
        if (ok) { S.roll = roll; S.has_roll = true; snprintf(S.status, sizeof S.status, T(S_ST_ADDED), p.name); }
        else snprintf(S.status, sizeof S.status, "%s", why);
        S.version++;
        xSemaphoreGive(s_lock);
        if (ok) trace("%.30s added: receipt %.8s rev %d", p.name, roll.receipt_id, roll.revision); else fail("draft", why);
    }
}

// ---- the screen ----
static lv_obj_t *s_status, *s_total, *s_roll_list, *s_basket_label;
static lv_obj_t *s_keys[MAX_PRODUCTS];
static lv_obj_t *s_pay, *s_retry, *s_cash, *s_cash_text, *s_cash_ok;
static int64_t s_typed;   // the cash typed on the keypad, in minor units
static int64_t s_cash_due;
static char s_cash_cur[4];
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

static const char *or_unset(const char *v) { return v[0] ? v : T(S_NOT_SET); }

// ---- the trace box: the newest lines on the screen; a tap shows them all and can send them to Deskilo ----
static lv_obj_t *s_trace_box, *s_trace_label, *s_traces;
static void close_traces_cb(lv_event_t *e) { lv_obj_del(s_traces); s_traces = NULL; }
static void send_traces_cb(lv_event_t *e) { cmd_t c = {CMD_REPORT, 0}; xQueueSend(s_cmd, &c, 0); close_traces_cb(e); }
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
static void clear_cb(lv_event_t *e) { cfg_erase(); esp_restart(); }
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
    lv_obj_set_style_text_font(s_status, &till_font_16, 0);
    lv_label_set_long_mode(s_status, LV_LABEL_LONG_DOT);
    lv_obj_set_width(s_status, 330);
    lv_obj_align(s_status, LV_ALIGN_TOP_LEFT, 150, 10);
    lv_label_set_text(s_status, "");
}

static void pay_cb(lv_event_t *e) { cmd_t c = {CMD_PAY, 0}; xQueueSend(s_cmd, &c, 0); }
static void retry_cb(lv_event_t *e) { cmd_t c = {CMD_RETRY, 0}; xQueueSend(s_cmd, &c, 0); }

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
    s_cash_given = s_typed;
    cmd_t c = {CMD_CASH, ok};
    xQueueSend(s_cmd, &c, 0);
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

static void build_till(void) {
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

static void build_roll(void) {
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

void app_main(void) {
    trace_init();
    ESP_ERROR_CHECK(cfg_load());
    strings_set_lang(g_cfg.lang);
    if (pending_init() != ESP_OK) {   // the attempts area unreadable: a pending payment may be in it, so nothing is sold
        trace("the payment store cannot be read: nothing is sold until it is looked at");
        S.phase = PH_BLOCKED;
    }
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
        build_common(T(S_TITLE_TILL));
        lv_label_set_text(s_status, T(S_ST_NOT_SET_UP));
        build_trace_box(60, 58);
        trace("not set up: no settings on this board");
    } else {
        if (!strcmp(g_cfg.role, "till")) build_till(); else build_roll();
        lv_timer_create(refresh_cb, 200, NULL);
        xTaskCreatePinnedToCore(net_task, "net", 12288, NULL, 4, NULL, 0);
    }
    lv_timer_create(trace_box_cb, 300, NULL);
    board_backlight(true);
    ESP_LOGI(TAG, "up (%s): free heap %lu", g_cfg.role[0] ? g_cfg.role : "no settings", (unsigned long)esp_get_free_heap_size());
    for (;;) {
        lv_timer_handler();
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}
