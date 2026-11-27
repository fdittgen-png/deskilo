// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- the touch calibration's rules on the host: every orientation of the panel calibrates and puts each cross back,
// a reading out of range, a cross touched twice or a centre that disagrees gives no calibration, a refusal leaves the way
// open to a good one; the kept form survives a fresh read, any flipped bit or wrong mark refuses it, and the screen is
// never left by a reading however wild.
#include <limits.h>
#include <stdio.h>
#include <string.h>

#include "touch_cal.h"

static int checks, failures;
static void check(int ok, const char *what) {
    checks++;
    if (!ok) { failures++; printf("FAIL: %s\n", what); }
}

enum { W = 480, H = 320 };

// The raw readings of the five crosses on a panel whose raw axes run 300..3800, swapped and reversed as given.
static void readings(int swap, int rev_x, int rev_y, int rx[TOUCH_CAL_POINTS], int ry[TOUCH_CAL_POINTS]) {
    int tx[TOUCH_CAL_POINTS], ty[TOUCH_CAL_POINTS];
    touch_cal_targets(W, H, tx, ty);
    for (int i = 0; i < TOUCH_CAL_POINTS; i++) {
        int ax = 300 + tx[i] * 3500 / (W - 1), ay = 300 + ty[i] * 3500 / (H - 1);
        if (rev_x) ax = 4100 - ax;
        if (rev_y) ay = 4100 - ay;
        rx[i] = swap ? ay : ax;
        ry[i] = swap ? ax : ay;
    }
}

int main(void) {
    int tx[TOUCH_CAL_POINTS], ty[TOUCH_CAL_POINTS];
    touch_cal_targets(W, H, tx, ty);
    for (int o = 0; o < 8; o++) {
        int rx[TOUCH_CAL_POINTS], ry[TOUCH_CAL_POINTS];
        readings(o & 1, (o >> 1) & 1, (o >> 2) & 1, rx, ry);
        touch_cal_t c;
        check(touch_cal_fit(W, H, rx, ry, &c), "every orientation of the panel calibrates");
        check(c.swap == (o & 1), "the swapped axis is found");
        for (int i = 0; i < TOUCH_CAL_POINTS; i++) {
            int x, y;
            touch_cal_map(&c, W, H, rx[i], ry[i], &x, &y);
            check(x >= tx[i] - 2 && x <= tx[i] + 2 && y >= ty[i] - 2 && y <= ty[i] + 2, "each cross lands where it was drawn");
        }
        uint8_t blob[TOUCH_CAL_BLOB];
        touch_cal_encode(&c, blob);
        check(memcmp(blob, "DTC1", 4) == 0, "the kept form starts with its mark");
        touch_cal_t back;
        check(touch_cal_decode(blob, sizeof blob, W, H, &back) && memcmp(&back, &c, sizeof c) == 0, "the kept form reads back the same");
        int all = 1;
        for (size_t bit = 0; bit < sizeof blob * 8; bit++) {
            uint8_t bad[TOUCH_CAL_BLOB];
            memcpy(bad, blob, sizeof bad);
            bad[bit / 8] ^= (uint8_t)(1u << (bit % 8));
            touch_cal_t t;
            if (touch_cal_decode(bad, sizeof bad, W, H, &t)) all = 0;
        }
        check(all, "every flipped bit of the kept form refuses it");
        check(!touch_cal_decode(blob, sizeof blob - 1, W, H, &back), "a kept form of another length is refused");
    }

    int rx[TOUCH_CAL_POINTS], ry[TOUCH_CAL_POINTS];
    touch_cal_t c = {0}, before;
    readings(1, 1, 0, rx, ry);
    int keep = rx[2];
    rx[2] = -5;
    memcpy(&before, &c, sizeof c);
    check(!touch_cal_fit(W, H, rx, ry, &c) && memcmp(&c, &before, sizeof c) == 0, "a negative reading gives no calibration, nothing written");
    rx[2] = 4096;
    check(!touch_cal_fit(W, H, rx, ry, &c), "a reading beyond 12 bits gives no calibration");
    rx[2] = 10;
    check(!touch_cal_fit(W, H, rx, ry, &c), "a reading at the panel's edge gives no calibration");
    rx[2] = keep;

    int sx = rx[1], sy = ry[1];
    rx[1] = rx[0]; ry[1] = ry[0];
    check(!touch_cal_fit(W, H, rx, ry, &c), "a cross touched twice gives no calibration");
    rx[1] = sx; ry[1] = sy;

    int cx = rx[4];
    rx[4] += 400;
    check(!touch_cal_fit(W, H, rx, ry, &c), "a centre the corners disagree with gives no calibration");
    rx[4] = cx;
    int cy = ry[3];
    ry[3] += 400;
    check(!touch_cal_fit(W, H, rx, ry, &c), "a fourth corner the others disagree with gives no calibration");
    ry[3] = cy;
    check(touch_cal_fit(W, H, rx, ry, &c), "after a refusal, good touches calibrate");

    int x, y;
    touch_cal_map(&c, W, H, INT_MIN, INT_MIN, &x, &y);
    check(x >= 0 && x < W && y >= 0 && y < H, "the wildest low reading stays on the screen");
    touch_cal_map(&c, W, H, INT_MAX, INT_MAX, &x, &y);
    check(x >= 0 && x < W && y >= 0 && y < H, "the wildest high reading stays on the screen");

    uint8_t blob[TOUCH_CAL_BLOB];
    touch_cal_t odd = c;
    odd.swap = 2;
    touch_cal_encode(&odd, blob);
    check(!touch_cal_decode(blob, sizeof blob, W, H, &odd), "a kept form with values no calibration gives is refused");
    touch_cal_t vendor = {.swap = 1, .x0 = 0, .rx0 = 3900, .x1 = W - 1, .rx1 = 200, .y0 = 0, .ry0 = 3900, .y1 = H - 1, .ry1 = 200};
    touch_cal_encode(&vendor, blob);
    check(touch_cal_decode(blob, sizeof blob, W, H, &odd), "the vendor's range is a calibration that can be kept");

    printf("touch_cal: %d checks, %d failures\n", checks, failures);
    return failures ? 1 : 0;
}
