// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- the touch calibration's rules (touch_cal.h).
#include "touch_cal.h"

#include <stdlib.h>
#include <string.h>

void touch_cal_targets(int w, int h, int x[TOUCH_CAL_POINTS], int y[TOUCH_CAL_POINTS]) {
    const int m = 40;
    x[0] = m;     y[0] = m;
    x[1] = w - m; y[1] = m;
    x[2] = w - m; y[2] = h - m;
    x[3] = m;     y[3] = h - m;
    x[4] = w / 2; y[4] = h / 2;
}

static int clamp(int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }

static int map_axis(int raw, int s0, int r0, int s1, int r1, int out) {
    if (r1 == r0) return 0;
    long v = s0 + (long)(raw - r0) * (s1 - s0) / (r1 - r0);
    return clamp((int)v, 0, out - 1);
}

void touch_cal_map(const touch_cal_t *c, int w, int h, int rx, int ry, int *x, int *y) {
    rx = clamp(rx, 0, TOUCH_RAW_MAX);
    ry = clamp(ry, 0, TOUCH_RAW_MAX);
    int ax = c->swap ? ry : rx, ay = c->swap ? rx : ry;
    *x = map_axis(ax, c->x0, c->rx0, c->x1, c->rx1, w);
    *y = map_axis(ay, c->y0, c->ry0, c->y1, c->ry1, h);
}

bool touch_cal_fit(int w, int h, const int rx[TOUCH_CAL_POINTS], const int ry[TOUCH_CAL_POINTS], touch_cal_t *out) {
    for (int i = 0; i < TOUCH_CAL_POINTS; i++) {
        if (rx[i] < TOUCH_RAW_LOW || rx[i] > TOUCH_RAW_HIGH || ry[i] < TOUCH_RAW_LOW || ry[i] > TOUCH_RAW_HIGH) return false;
    }
    int tx[TOUCH_CAL_POINTS], ty[TOUCH_CAL_POINTS];
    touch_cal_targets(w, h, tx, ty);
    // which raw axis follows the screen's X: the one that changes between the left and the right crosses
    int dx_rx = abs((rx[1] + rx[2]) - (rx[0] + rx[3]));
    int dx_ry = abs((ry[1] + ry[2]) - (ry[0] + ry[3]));
    int swap = dx_ry > dx_rx;
    const int *ax = swap ? ry : rx, *ay = swap ? rx : ry;
    touch_cal_t c = {.swap = swap,
                     .x0 = tx[0], .rx0 = (ax[0] + ax[3]) / 2, .x1 = tx[1], .rx1 = (ax[1] + ax[2]) / 2,
                     .y0 = ty[0], .ry0 = (ay[0] + ay[1]) / 2, .y1 = ty[2], .ry1 = (ay[2] + ay[3]) / 2};
    if (abs(c.rx1 - c.rx0) < 400 || abs(c.ry1 - c.ry0) < 300) return false;   // touches too close together
    for (int i = 0; i < TOUCH_CAL_POINTS; i++) {   // every cross, the centre too, lands where it was drawn
        int x, y;
        touch_cal_map(&c, w, h, rx[i], ry[i], &x, &y);
        if (abs(x - tx[i]) > TOUCH_CAL_SLACK_PX || abs(y - ty[i]) > TOUCH_CAL_SLACK_PX) return false;
    }
    *out = c;
    return true;
}

static uint32_t crc32(const uint8_t *p, size_t n) {
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < n; i++) {
        c ^= p[i];
        for (int k = 0; k < 8; k++) c = (c >> 1) ^ (0xEDB88320u & (0u - (c & 1u)));
    }
    return ~c;
}

static void put32(uint8_t *p, uint32_t v) { p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); p[2] = (uint8_t)(v >> 16); p[3] = (uint8_t)(v >> 24); }
static uint32_t get32(const uint8_t *p) { return (uint32_t)p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 | (uint32_t)p[3] << 24; }

#define FIELDS 9
static void fields(const touch_cal_t *c, int32_t f[FIELDS]) {
    const int32_t v[FIELDS] = {c->swap, c->x0, c->rx0, c->x1, c->rx1, c->y0, c->ry0, c->y1, c->ry1};
    memcpy(f, v, sizeof v);
}

void touch_cal_encode(const touch_cal_t *cal, uint8_t out[TOUCH_CAL_BLOB]) {
    memset(out, 0, TOUCH_CAL_BLOB);
    memcpy(out, "DTC1", 4);
    int32_t f[FIELDS];
    fields(cal, f);
    for (int i = 0; i < FIELDS; i++) put32(out + 4 + 4 * i, (uint32_t)f[i]);
    put32(out + TOUCH_CAL_BLOB - 4, crc32(out, TOUCH_CAL_BLOB - 4));
}

static bool in(int32_t v, int32_t lo, int32_t hi) { return v >= lo && v <= hi; }

bool touch_cal_decode(const uint8_t *p, size_t n, int w, int h, touch_cal_t *out) {
    if (n != TOUCH_CAL_BLOB || memcmp(p, "DTC1", 4) != 0) return false;
    if (get32(p + TOUCH_CAL_BLOB - 4) != crc32(p, TOUCH_CAL_BLOB - 4)) return false;
    for (int i = 4 + 4 * FIELDS; i < TOUCH_CAL_BLOB - 4; i++) if (p[i] != 0) return false;
    int32_t f[FIELDS];
    for (int i = 0; i < FIELDS; i++) f[i] = (int32_t)get32(p + 4 + 4 * i);
    touch_cal_t c = {.swap = f[0], .x0 = f[1], .rx0 = f[2], .x1 = f[3], .rx1 = f[4], .y0 = f[5], .ry0 = f[6], .y1 = f[7], .ry1 = f[8]};
    if (!in(c.swap, 0, 1)) return false;
    if (!in(c.x0, 0, w - 1) || !in(c.x1, 0, w - 1) || !in(c.y0, 0, h - 1) || !in(c.y1, 0, h - 1)) return false;
    if (c.x0 >= c.x1 || c.y0 >= c.y1) return false;
    if (!in(c.rx0, 0, TOUCH_RAW_MAX) || !in(c.rx1, 0, TOUCH_RAW_MAX) || !in(c.ry0, 0, TOUCH_RAW_MAX) || !in(c.ry1, 0, TOUCH_RAW_MAX)) return false;
    if (abs(c.rx1 - c.rx0) < 400 || abs(c.ry1 - c.ry0) < 300) return false;
    *out = c;
    return true;
}
