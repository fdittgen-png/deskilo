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
#include "esp_ota_ops.h"
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
#include "ui.h"
#include "readable_code.h"
#include "device.h"
#include "boot_button.h"
#include "money_text.h"
#include "pending.h"
#include "trace.h"
#include "strings.h"
#include "basket.h"
#include "enroll.h"


static const char *TAG = "till";
#define BUF_LINES 32   // one partial buffer: 480 x 32 x 2 bytes = 30 KiB (two buffers, 60 KiB of the 520 KB SRAM)

static lv_disp_draw_buf_t s_draw;
static lv_disp_drv_t s_disp;
static lv_indev_drv_t s_indev;

// ---- state shared between the network task and the screen (guarded by s_lock; the screen copies it) ----
static shared_t S;
static SemaphoreHandle_t s_lock;
static QueueHandle_t s_cmd;
typedef struct { int kind; int index; int64_t value; } cmd_t;
// #4508 -- the basket the screen shows at once (guarded by s_lock): the screen adds a key to it, the network task sends it
// and confirms it with the server's answer; s_last is the basket as the server last confirmed it.
static basket_t s_local, s_last;
static uint32_t s_seen;   // the state's version the screen shows

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

// ---- the network task ----
static void roll_set_fn(void *a) { S.roll = *(roll_t *)a; S.has_roll = S.roll.n > 0; }
static void products_set_fn(void *a) { S.n_products = 0; }

// What the screen shows of the basket, from s_local (under s_lock).
static void show_basket(void) {
    S.shown_items = s_local.items;
    S.shown_total = s_local.total_minor;
    S.unconfirmed = !basket_is_confirmed(&s_local);
    S.version++;
}

static void set_phase(int phase, const char *status) {
    xSemaphoreTake(s_lock, portMAX_DELAY);
    S.phase = phase;
    if (status) snprintf(S.status, sizeof S.status, "%s", status);
    S.version++;
    xSemaphoreGive(s_lock);
}

static int save_attempt(const void *a) { return pending_save((const pending_t *)a) == ESP_OK ? 0 : 1; }

// Sends the attempt under the cashier's lease. A lease that ended sends nothing: the attempt stays kept, and is sent again,
// the SAME request, once a cashier took the board again (#4519).
static pay_result_t send_attempt(const void *a, char *number, int ncap, char *why, int cap) {
    return api_finalize_cash((const pending_t *)a, number, ncap, why, cap);
}

// ---- #4519: the board's link with the server: connected by the owner's code, approved, asking for a cashier, selling ----
static link_t s_link = LINK_ENROLL;

static void set_link_fn(void *a) {
    S.link = *(const int *)a;
    device_t d;
    if (device_identity(&d) == ESP_OK) snprintf(S.fingerprint, sizeof S.fingerprint, "%s", d.fingerprint);
    const char *say = S.link == LINK_ENROLL ? T(S_ST_CONNECT) : S.link == LINK_PENDING ? T(S_ST_APPROVE)
                    : S.link == LINK_ASKING ? T(S_ST_ASK) : T(S_ST_CHOOSE);
    snprintf(S.status, sizeof S.status, say, S.fingerprint);
}
static void set_link(link_t l) { int v = (int)l; s_link = l; with_lock(set_link_fn, &v); trace("link: %d", v); }

// Until the board sells: its status with the server; the owner's code typed and claimed; the owner's approval waited for;
// a cashier asked for and waited for. The basket and a kept payment stay as they are meanwhile.
static void link_until_selling(void) {
    char status[24], reason[32], why[96];
    bool asked = false;
    for (;;) {
        if (s_link == LINK_ENROLL || s_link == LINK_PENDING) {
            reason[0] = 0;
            if (api_status(status, sizeof status, reason, sizeof reason)) {
                link_t l = link_of_status(status);
                if (l != s_link || l != LINK_PENDING) set_link(l);
            } else if (!strcmp(reason, "uncertain")) { vTaskDelay(pdMS_TO_TICKS(3000)); continue; }
            else if (s_link != LINK_ENROLL) set_link(LINK_ENROLL);
        }
        if (s_link == LINK_ENROLL) {
            cmd_t c;
            if (xQueueReceive(s_cmd, &c, pdMS_TO_TICKS(5000)) != pdTRUE || c.kind != CMD_CODE) continue;
            char code[ENROLL_CODE_LEN + 1];
            enroll_code_unpack(c.value, code);
            set_status(T(S_ST_SENDING));
            if (api_claim(code, status, sizeof status, why, sizeof why)) { trace("connection code taken: %s", status); set_link(link_of_status(status)); }
            else { char t[96]; snprintf(t, sizeof t, T(S_ST_CODE_REFUSED), why); set_status(t); trace("connection code refused: %s", why); }
            continue;
        }
        if (s_link == LINK_PENDING) { vTaskDelay(pdMS_TO_TICKS(3000)); continue; }
        if (s_link == LINK_ASKING) {
            if (!asked) {
                reason[0] = 0;
                if (!api_ask_cashier(reason, sizeof reason)) {
                    link_t l = link_on(LINK_ASKING, reason);
                    if (l != LINK_ASKING) set_link(l);
                    vTaskDelay(pdMS_TO_TICKS(3000));
                    continue;
                }
                asked = true;
                trace("a cashier asked for");
            }
            reason[0] = 0;
            if (api_leased(reason, sizeof reason)) { set_link(LINK_SELLING); trace("a cashier took the board"); return; }
            link_t l = link_on(LINK_ASKING, reason);
            if (l != LINK_ASKING) { asked = false; set_link(l); continue; }
            if (strcmp(reason, "operator_pending") != 0 && strcmp(reason, "uncertain") != 0) asked = false;   // the request ended: ask again
            vTaskDelay(pdMS_TO_TICKS(3000));
            continue;
        }
        return;
    }
}

static bool pending_here(const pending_t *p);

// After a call under the lease: a lease that ended asks for a cashier again, and the board waits, basket kept.
static bool lease_still_held(void) {
    const char *r = api_take_link_reason();
    if (!r[0]) return true;
    link_t l = link_on(LINK_SELLING, r);
    if (l == LINK_SELLING) return true;
    set_status(T(S_ST_LEASE_ENDED));
    set_link(l);
    link_until_selling();
    // the board may now serve another business: a payment kept from before is checked against it again
    pending_t p;
    if (pending_load(&p) && !pending_here(&p)) {
        trace("a payment of another business is pending (%.8s): nothing is sold here", p.request_id);
        set_phase(PH_BLOCKED, T(S_ST_PENDING_OTHER));
    }
    return false;
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

// Whether a kept attempt was made in the business and on the server the board serves now. One of another binding is
// never sent here (the board was connected again elsewhere): it waits, blocked, for the business it belongs to.
static bool pending_here(const pending_t *p) { return !strcmp(p->workspace, g_cfg.workspace) && !strcmp(p->server, g_cfg.url); }

// Asks Deskilo again about the attempt kept in flash: the same request, the same payload, in its own binding only.
static void settle(const pending_t *p) {
    if (!pending_here(p)) {
        trace("a payment of another business is pending (%.8s): nothing is sold here", p->request_id);
        set_phase(PH_BLOCKED, T(S_ST_PENDING_OTHER));
        return;
    }
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
    set_link(LINK_ENROLL);
    link_until_selling();
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
            if (!pending_here(&p)) {
                trace("a payment of another business is pending (%.8s): nothing is sold here", p.request_id);
                set_phase(PH_BLOCKED, T(S_ST_PENDING_OTHER));
            } else {
                trace("restart with a payment pending (%.8s)", p.request_id);
                set_phase(PH_UNCERTAIN, T(S_ST_UNKNOWN));
                settle(&p);
            }
        }
    } else set_status(T(S_ST_WAITING));
    for (;;) {
        cmd_t c;
        bool got = xQueueReceive(s_cmd, &c, strcmp(g_cfg.role, "roll") == 0 ? pdMS_TO_TICKS(1500) : pdMS_TO_TICKS(1000)) == pdTRUE;
        static int idle;
        int phase_now;
        xSemaphoreTake(s_lock, portMAX_DELAY); phase_now = S.phase; xSemaphoreGive(s_lock);
        if (phase_now == PH_UNCERTAIN && ((got && c.kind == CMD_RETRY) || (!got && ++idle >= 10))) {
            idle = 0;
            pending_t p;
            if (pending_load(&p)) { settle(&p); lease_still_held(); } else set_phase(PH_SELL, T(S_ST_CHOOSE));
            continue;
        }
        if (got && c.kind == CMD_REPORT) { set_status(api_report(g_cfg.role, "till.traces_sent", "") ? T(S_ST_TRACES_SENT) : T(S_ST_TRACES_NOT_SENT)); continue; }
        if (!strcmp(g_cfg.role, "roll")) {
            bool ok = api_roll(&roll, why, sizeof why);
            if (!ok && !lease_still_held()) continue;
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
            bool payable = S.has_roll && S.roll.revision > 0 && due > 0 && due == S.roll.total_minor && basket_is_confirmed(&s_local);
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
            p.given_minor = c.value;
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
            lease_still_held();
            continue;
        }
        if (c.kind == CMD_RETRY) continue;
        if (c.kind == CMD_REFRESH) {   // the products read again: added ones appear without a restart
            int n = api_products(prods, MAX_PRODUCTS, why, sizeof why);
            xSemaphoreTake(s_lock, portMAX_DELAY);
            if (n >= 0) { memcpy(S.products, prods, sizeof prods); S.n_products = n; snprintf(S.status, sizeof S.status, T(S_ST_UPDATED), n); }
            else snprintf(S.status, sizeof S.status, "%s", why);
            S.version++;
            xSemaphoreGive(s_lock);
            if (n < 0) fail("products", why); else trace("products read again: %d", n);
            continue;
        }
        if (c.kind == CMD_NEXT) {
            xSemaphoreTake(s_lock, portMAX_DELAY); basket_clear(&s_local); s_last = s_local; show_basket(); xSemaphoreGive(s_lock);
            api_reset_draft();
            memset(&roll, 0, sizeof roll);
            xSemaphoreTake(s_lock, portMAX_DELAY); S.roll = roll; S.has_roll = false; S.phase = PH_SELL; S.paid_number[0] = 0; snprintf(S.status, sizeof S.status, T(S_ST_NEXT)); S.version++; xSemaphoreGive(s_lock);
            trace("next customer");
            continue;
        }
        if (phase_now != PH_SELL) continue;   // the basket is frozen from the cash count on
        // #4508 -- the screen added the key already; the basket as it stands now goes to the server, once: keys pressed
        // while an earlier draft was on its way are in it, and their own commands then find it confirmed
        basket_t sent;
        xSemaphoreTake(s_lock, portMAX_DELAY); sent = s_local; xSemaphoreGive(s_lock);
        if (basket_is_confirmed(&sent)) continue;
        set_status(T(S_ST_SENDING));
        const int64_t t0 = esp_timer_get_time();
        bool ok = api_draft(sent.lines, sent.n, &roll, why, sizeof why);
        if (!ok && !lease_still_held()) ok = api_draft(sent.lines, sent.n, &roll, why, sizeof why);   // the same basket, once taken again
        xSemaphoreTake(s_lock, portMAX_DELAY);
        if (ok) {
            S.roll = roll; S.has_roll = true; basket_confirm(&s_local, sent.seq); s_last = sent; s_last.confirmed = sent.seq;
            snprintf(S.status, sizeof S.status, "%s", basket_is_confirmed(&s_local) ? T(S_ST_CHOOSE) : T(S_ST_SENDING));
        } else { basket_restore(&s_local, &s_last); snprintf(S.status, sizeof S.status, "%s", why); }
        show_basket();
        xSemaphoreGive(s_lock);
        if (ok) trace("draft of %d items: receipt %.8s rev %d in %lld ms", sent.items, roll.receipt_id, roll.revision,
                      (long long)((esp_timer_get_time() - t0) / 1000));
        else fail("draft", why);
    }
}

// ---- the display and touch glue; the screens themselves are ui.c ----
static void flush(lv_disp_drv_t *drv, const lv_area_t *a, lv_color_t *px) {
    board_draw(a->x1, a->y1, a->x2 + 1, a->y2 + 1, px);   // done when the transfer ends (drawn, below)
}
static void read_touch(lv_indev_drv_t *drv, lv_indev_data_t *d) {
    int x, y;
    if (board_touch(&x, &y)) { d->state = LV_INDEV_STATE_PR; d->point.x = x; d->point.y = y; }
    else d->state = LV_INDEV_STATE_REL;
}
static void tick(void *arg) { lv_tick_inc(2); }
// #4508 -- a buffer is drawn into again only once its pixels reached the panel, not as soon as they were queued
static void drawn(void *ctx) { lv_disp_flush_ready((lv_disp_drv_t *)ctx); }


static void ui_send(int kind, int index, int64_t value) {
    // #4508 -- a key is on the screen at once: its line and the total from the price the board holds; the server confirms
    if (kind == CMD_TAP) {
        static shared_t copy;
        bool added = false;
        xSemaphoreTake(s_lock, portMAX_DELAY);
        if (S.phase == PH_SELL && index >= 0 && index < S.n_products) {
            added = basket_add(&s_local, &S.products[index], value > 0 && value < 1000 ? (int)value : 1);
            if (added) show_basket();
        }
        copy = S;
        xSemaphoreGive(s_lock);
        if (!added) return;
        s_seen = copy.version;
        ui_refresh(&copy);
    }
    cmd_t c = {kind, index, value};
    xQueueSend(s_cmd, &c, 0);
}
static void ui_reset(void) { cfg_erase(); esp_restart(); }
static void save_cal(const touch_cal_t *cal) {
    board_touch_set_cal(cal);
    if (touch_cal_save(cal) != ESP_OK) trace("touch calibration not kept: it holds until the next restart");
}
// Hands the screen a copy of the shared state whenever its version changed.
// ---- the pairing code (#4474): BOOT held for 3 s shows it, on every board; pressed again, it closes ----
static char s_pairing[288];   // the payload with its 64-character hash and a firmware version of up to 40
static char s_readable[READABLE_CODE_LEN];   // #4466: the code typed instead of scanning
static device_t s_device;
static boot_button_t s_boot;
static void boot_cb(lv_timer_t *t) {
    if (boot_button_poll(&s_boot, board_boot_button(), ui_pairing_shown())) ui_toggle_pairing(s_pairing, s_device.fingerprint, s_readable);
}

static void refresh_cb(lv_timer_t *t) {
    static shared_t copy;
    xSemaphoreTake(s_lock, portMAX_DELAY);
    if (S.version == s_seen) { xSemaphoreGive(s_lock); return; }
    copy = S;
    xSemaphoreGive(s_lock);
    s_seen = copy.version;
    ui_refresh(&copy);
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
    touch_cal_t cal;
    if (touch_cal_load(&cal)) board_touch_set_cal(&cal);   // the calibration taken on this board, else the vendor's range
    bool calibrate = BOARD_HAS_TOUCH && board_boot_button();   // BOOT held at start on a touch board: calibrate first
    if (device_identity(&s_device) == ESP_OK) {
        device_pairing_payload(&s_device, BOARD_PROFILE, esp_app_get_description()->version, s_pairing, sizeof s_pairing);
        device_readable_code(&s_device, BOARD_PROFILE_CODE, s_readable);
        trace("device %.8s, code %s", s_device.id, s_device.fingerprint);
    } else trace("the device identity cannot be read: the board shows no pairing code");
    lv_init();
    static lv_color_t buf1[BOARD_LCD_W * BUF_LINES], buf2[BOARD_LCD_W * BUF_LINES];
    lv_disp_draw_buf_init(&s_draw, buf1, buf2, BOARD_LCD_W * BUF_LINES);
    lv_disp_drv_init(&s_disp);
    s_disp.hor_res = BOARD_LCD_W;
    s_disp.ver_res = BOARD_LCD_H;
    s_disp.flush_cb = flush;
    s_disp.draw_buf = &s_draw;
    lv_disp_drv_register(&s_disp);
    board_on_drawn(drawn, &s_disp);
    lv_indev_drv_init(&s_indev);
    s_indev.type = LV_INDEV_TYPE_POINTER;
    s_indev.read_cb = read_touch;
    lv_indev_drv_register(&s_indev);
    const esp_timer_create_args_t t = {.callback = tick, .name = "lv_tick"};
    esp_timer_handle_t h;
    ESP_ERROR_CHECK(esp_timer_create(&t, &h));
    ESP_ERROR_CHECK(esp_timer_start_periodic(h, 2000));
    s_lock = xSemaphoreCreateMutex();
    static const ui_port_t port = {.send = ui_send, .factory_reset = ui_reset, .raw_touch = board_touch_raw, .save_cal = save_cal};
    ui_init(&port);
    s_cmd = xQueueCreate(8, sizeof(cmd_t));
    // a board without touch has no till or roll screen: until its own roles (price tag #4472, seat #4473) it shows its code
    if (!cfg_complete() || !BOARD_HAS_TOUCH) {
        ui_build_not_set_up();
        ui_toggle_pairing(s_pairing, s_device.fingerprint, s_readable);   // a board not set up shows its code by itself
        trace("not set up: no settings on this board");
    } else {
        if (!strcmp(g_cfg.role, "till")) ui_build_till(); else ui_build_roll();
        lv_timer_create(refresh_cb, 200, NULL);
        xTaskCreatePinnedToCore(net_task, "net", 12288, NULL, 4, NULL, 0);
    }
    if (calibrate) ui_calibrate();
    boot_button_init(&s_boot);
    lv_timer_create(boot_cb, 100, NULL);
    board_backlight(true);
    // #4474: the screens are up, so this image works: an update that never got here is rolled back at the next start
    esp_err_t valid = esp_ota_mark_app_valid_cancel_rollback();
    if (valid != ESP_OK) trace("this image could not be marked as working: %s", esp_err_to_name(valid));
    ESP_LOGI(TAG, "up (%s, %s): free heap %lu", g_cfg.role[0] ? g_cfg.role : "no settings", esp_app_get_description()->version,
             (unsigned long)esp_get_free_heap_size());
    for (;;) {
        lv_timer_handler();
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}
