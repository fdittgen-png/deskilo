// SPDX-License-Identifier: AGPL-3.0-or-later
// #4453/#4456 -- the screens, behind a port: the board wires it to its command queue and its factory reset, the host tests
// to a recorder.
#pragma once
#include <stdint.h>
#include "lvgl.h"
#include "board.h"
#include "till_types.h"

typedef struct {
    void (*send)(int kind, int index, int64_t value);   // a tap: CMD_* with its key index, or the cash given for CMD_CASH
    void (*factory_reset)(void);                       // the settings' long press
    bool (*raw_touch)(int *rx, int *ry);               // the raw touch, for calibrating
    void (*save_cal)(const touch_cal_t *cal);          // a calibration taken: applied and kept
    void (*perf_text)(char *out, int cap);             // #4450: where the time went since the start, for Settings; may be NULL
} ui_port_t;

void ui_init(const ui_port_t *port);
void ui_build_not_set_up(void);
void ui_build_till(void);
void ui_build_roll(void);
// Shows [state]: the keys, the basket, the roll, the payment's phase and the cash count.
void ui_refresh(const shared_t *state);
// The touch calibration: four crosses, touched one after the other; the result goes to the port's save_cal.
void ui_calibrate(void);
// #4474 -- the pairing code over everything: the QR of [payload] and the fingerprint [fp] to compare by eye. Shown again
// while it is up, it closes (BOOT pressed again, or a tap on a touch board).
void ui_toggle_pairing(const char *payload, const char *fp, const char *readable);
bool ui_pairing_shown(void);
