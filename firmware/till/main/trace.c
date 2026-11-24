// SPDX-License-Identifier: AGPL-3.0-or-later
#include "trace.h"
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"

static const char *TAG = "trace";
static char s_ring[TRACE_LINES][TRACE_WIDTH];
static int s_next, s_count;
static uint32_t s_version;
static portMUX_TYPE s_mux = portMUX_INITIALIZER_UNLOCKED;

void trace(const char *fmt, ...) {
    char line[TRACE_WIDTH];
    int at = snprintf(line, sizeof line, "%5lus ", (unsigned long)(esp_timer_get_time() / 1000000));
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(line + at, sizeof line - at, fmt, ap);
    va_end(ap);
    for (char *c = line; *c; c++) if (*c == '\n' || *c == '\r') *c = ' ';
    ESP_LOGI(TAG, "%s", line);
    portENTER_CRITICAL(&s_mux);
    memcpy(s_ring[s_next], line, sizeof line);
    s_next = (s_next + 1) % TRACE_LINES;
    if (s_count < TRACE_LINES) s_count++;
    s_version++;
    portEXIT_CRITICAL(&s_mux);
}

static int lines(char *out, int cap, int from_newest) {
    static char copy[TRACE_LINES][TRACE_WIDTH];
    int next, count;
    portENTER_CRITICAL(&s_mux);
    memcpy(copy, s_ring, sizeof copy);
    next = s_next; count = s_count;
    portEXIT_CRITICAL(&s_mux);
    int take = from_newest < count ? from_newest : count, o = 0;
    if (cap > 0) out[0] = 0;
    for (int i = count - take; i < count && o < cap - 1; i++) {
        int idx = (next - count + i + TRACE_LINES) % TRACE_LINES;
        o += snprintf(out + o, cap - o, "%s%s", o ? "\n" : "", copy[idx]);
    }
    return o < cap ? o : cap - 1;
}

int trace_dump(char *out, int cap) { return lines(out, cap, TRACE_LINES); }
int trace_tail(char *out, int cap, int n) { return lines(out, cap, n); }
uint32_t trace_version(void) {
    portENTER_CRITICAL(&s_mux);
    uint32_t v = s_version;
    portEXIT_CRITICAL(&s_mux);
    return v;
}
