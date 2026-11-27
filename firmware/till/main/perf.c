// SPDX-License-Identifier: AGPL-3.0-or-later
#include "perf.h"
#include <stdio.h>
#include <string.h>
#include "esp_log.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"

static const char *TAG = "perf";

typedef struct { uint32_t n, sum, max, last; } stat_t;   // milliseconds
static void add(stat_t *s, uint32_t ms) { s->n++; s->sum += ms; s->last = ms; if (ms > s->max) s->max = ms; }
static uint32_t avg(const stat_t *s) { return s->n ? s->sum / s->n : 0; }

// What is counted, once for the running window (cleared by each report) and once since the start.
typedef struct {
    stat_t paint, press, tap, http;
    uint32_t px, flush_us, http_new;
} counts_t;
static counts_t s_win, s_all;
// The screen task and the network task both count: one short lock around every change and every copy.
static portMUX_TYPE s_mux = portMUX_INITIALIZER_UNLOCKED;

static int64_t s_press_at, s_command_at;   // 0: nothing waiting to be measured
static struct { char step[16]; uint32_t ms; } s_start[6];
static int s_start_n;

void perf_start(const char *step) {
    uint32_t ms = (uint32_t)(esp_timer_get_time() / 1000);
    portENTER_CRITICAL(&s_mux);
    int slot = s_start_n < (int)(sizeof s_start / sizeof s_start[0]) ? s_start_n++ : -1;
    if (slot >= 0) {
        strncpy(s_start[slot].step, step, sizeof s_start[slot].step - 1);   // the array is static: the last byte stays 0
        s_start[slot].ms = ms;
    }
    portEXIT_CRITICAL(&s_mux);
    ESP_LOGI(TAG, "start: %s at %lu ms", step, (unsigned long)ms);
}

void perf_frame(uint32_t ms, uint32_t px) {
    int64_t now = esp_timer_get_time();
    portENTER_CRITICAL(&s_mux);
    add(&s_win.paint, ms); add(&s_all.paint, ms);
    s_win.px += px; s_all.px += px;
    if (s_press_at) {
        uint32_t d = (uint32_t)((now - s_press_at) / 1000);
        add(&s_win.press, d); add(&s_all.press, d);
        s_press_at = 0;
    }
    portEXIT_CRITICAL(&s_mux);
}

void perf_flush(int64_t us) {
    portENTER_CRITICAL(&s_mux);
    s_win.flush_us += (uint32_t)us; s_all.flush_us += (uint32_t)us;
    portEXIT_CRITICAL(&s_mux);
}

void perf_press(void) {
    int64_t now = esp_timer_get_time();
    portENTER_CRITICAL(&s_mux);
    s_press_at = now;
    portEXIT_CRITICAL(&s_mux);
}

void perf_command(void) {
    int64_t now = esp_timer_get_time();
    portENTER_CRITICAL(&s_mux);
    s_command_at = now;   // a second tap before the answer restarts the measure: the last tap is the one timed
    portEXIT_CRITICAL(&s_mux);
}

void perf_answered(void) {
    int64_t now = esp_timer_get_time();
    portENTER_CRITICAL(&s_mux);
    if (s_command_at) {
        uint32_t d = (uint32_t)((now - s_command_at) / 1000);
        add(&s_win.tap, d); add(&s_all.tap, d);
        s_command_at = 0;
    }
    portEXIT_CRITICAL(&s_mux);
}

void perf_http(const char *method, const char *path, int status, bool kept, bool again, int64_t us) {
    uint32_t ms = (uint32_t)(us / 1000);
    portENTER_CRITICAL(&s_mux);
    add(&s_win.http, ms); add(&s_all.http, ms);
    if (!kept || again) { s_win.http_new++; s_all.http_new++; }
    portEXIT_CRITICAL(&s_mux);
    const char *q = strchr(path, '?');
    int n = q ? (int)(q - path) : (int)strlen(path);
    ESP_LOGI(TAG, "http %s %.*s -> %d in %lu ms (%s)", method, n > 60 ? 60 : n, path, status, (unsigned long)ms,
             again ? "kept, then new" : (kept ? "kept" : "new"));
}

void perf_report(void) {
    counts_t w;
    portENTER_CRITICAL(&s_mux);
    w = s_win;
    memset(&s_win, 0, sizeof s_win);
    portEXIT_CRITICAL(&s_mux);
    if (!w.paint.n && !w.http.n && !w.tap.n) return;   // an idle board says nothing
    ESP_LOGI(TAG, "paint n=%lu avg=%lu max=%lu ms, px=%luk, flush=%lu ms | press>paint last=%lu max=%lu ms | "
                  "tap>answer last=%lu max=%lu ms | http n=%lu new=%lu avg=%lu max=%lu ms | heap free=%luk min=%luk",
             (unsigned long)w.paint.n, (unsigned long)avg(&w.paint), (unsigned long)w.paint.max, (unsigned long)(w.px / 1000),
             (unsigned long)(w.flush_us / 1000), (unsigned long)w.press.last, (unsigned long)w.press.max,
             (unsigned long)w.tap.last, (unsigned long)w.tap.max, (unsigned long)w.http.n, (unsigned long)w.http_new,
             (unsigned long)avg(&w.http), (unsigned long)w.http.max, (unsigned long)(esp_get_free_heap_size() / 1024),
             (unsigned long)(esp_get_minimum_free_heap_size() / 1024));
}

void perf_text(char *out, int cap) {
    static counts_t a;                 // the screen task only: copied under the lock, put into words outside it
    static typeof(s_start) steps;
    int n;
    portENTER_CRITICAL(&s_mux);
    a = s_all;
    memcpy(steps, s_start, sizeof steps);
    n = s_start_n;
    portEXIT_CRITICAL(&s_mux);
    char start[112] = "";
    for (int i = 0, o = 0; i < n && o < (int)sizeof start - 1; i++)
        o += snprintf(start + o, sizeof start - o, "%s%s %lu", i ? ", " : "", steps[i].step, (unsigned long)steps[i].ms);
    snprintf(out, cap, "start ms: %s\npaint avg %lu max %lu ms; press>paint avg %lu max %lu ms\n"
                       "tap>answer avg %lu max %lu ms\nhttp %lu (new %lu) avg %lu max %lu ms",
             start, (unsigned long)avg(&a.paint), (unsigned long)a.paint.max, (unsigned long)avg(&a.press), (unsigned long)a.press.max,
             (unsigned long)avg(&a.tap), (unsigned long)a.tap.max, (unsigned long)a.http.n, (unsigned long)a.http_new,
             (unsigned long)avg(&a.http), (unsigned long)a.http.max);
}
