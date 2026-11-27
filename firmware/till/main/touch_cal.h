// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- the touch calibration's rules, apart from the board and the screen so the host tests run them: five crosses
// (the four corners and the centre) give a mapping only when every reading is a real one, the touches are far enough
// apart and the mapping puts each cross back where it was drawn; what is kept in flash carries a mark and a checksum,
// and a kept mapping that fails either, or holds values no calibration can give, is not used.
#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// How raw touch readings map to the screen: which raw axis gives the screen's X (swap), and the raw reading at two known
// points of each screen axis.
typedef struct {
    int32_t swap;             // 1: the screen's X comes from the raw Y reading
    int32_t x0, rx0, x1, rx1; // screen x0 reads raw rx0, screen x1 reads raw rx1
    int32_t y0, ry0, y1, ry1;
} touch_cal_t;

#define TOUCH_CAL_POINTS 5     // the four corners, clockwise from the top left, then the centre
#define TOUCH_RAW_MAX 4095     // the XPT2046's 12-bit reading
#define TOUCH_RAW_LOW 50       // a reading at or beyond these is the panel's edge or no touch at all
#define TOUCH_RAW_HIGH 4046
#define TOUCH_CAL_SLACK_PX 14  // how far a cross may land from where it was drawn
#define TOUCH_CAL_BLOB 48      // the bytes kept in flash

// Where the crosses are drawn on a w x h screen.
void touch_cal_targets(int w, int h, int x[TOUCH_CAL_POINTS], int y[TOUCH_CAL_POINTS]);

// The mapping from the raw readings of the five crosses, or false: a reading out of range, touches too close together,
// or a cross the mapping does not put back within TOUCH_CAL_SLACK_PX of where it was drawn (a cross touched twice, a
// slip). Nothing is written to *out on a refusal.
bool touch_cal_fit(int w, int h, const int rx[TOUCH_CAL_POINTS], const int ry[TOUCH_CAL_POINTS], touch_cal_t *out);

// A raw reading (clamped to 0..TOUCH_RAW_MAX) mapped to a screen pixel inside w x h.
void touch_cal_map(const touch_cal_t *cal, int w, int h, int rx, int ry, int *x, int *y);

// The kept form: "DTC1", the nine values little-endian, a CRC-32 of the bytes before it.
void touch_cal_encode(const touch_cal_t *cal, uint8_t out[TOUCH_CAL_BLOB]);
// True and *out set only for a kept form with its mark, its checksum and values a calibration of w x h can give.
bool touch_cal_decode(const uint8_t *in, size_t n, int w, int h, touch_cal_t *out);
