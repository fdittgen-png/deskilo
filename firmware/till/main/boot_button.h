// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- what the BOOT button means, on every board: held for three seconds it shows the pairing code; while the code
// is up, one press closes it; a button held down at start (the calibration's way in) counts only after it is let go.
// Pure, polled every 100 ms by the board; the host tests run it as the board does.
#pragma once
#include <stdbool.h>

#define BOOT_HOLD_TICKS 30   // 3 s at the 100 ms poll

typedef struct { int held; } boot_button_t;   // held < 0: still down since the start

static inline void boot_button_init(boot_button_t *b) { b->held = -1; }

// One poll: [down] the button now, [shown] the pairing code up. True when the code is to be shown or closed now.
bool boot_button_poll(boot_button_t *b, bool down, bool shown);
