// SPDX-License-Identifier: AGPL-3.0-or-later
// #4453/#4456 -- the screens, behind a port: the board wires it to its command queue and its factory reset, the host tests
// to a recorder.
#pragma once
#include <stdint.h>
#include "lvgl.h"
#include "till_types.h"

typedef struct {
    void (*send)(int kind, int index, int64_t value);   // a tap: CMD_* with its key index, or the cash given for CMD_CASH
    void (*factory_reset)(void);                       // the settings' long press
} ui_port_t;

void ui_init(const ui_port_t *port);
void ui_build_not_set_up(void);
void ui_build_till(void);
void ui_build_roll(void);
// Shows [state]: the keys, the basket, the roll, the payment's phase and the cash count.
void ui_refresh(const shared_t *state);
