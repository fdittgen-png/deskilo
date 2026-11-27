// SPDX-License-Identifier: AGPL-3.0-or-later
#include "boot_button.h"

bool boot_button_poll(boot_button_t *b, bool down, bool shown) {
    if (b->held < 0) {
        if (!down) b->held = 0;
        return false;
    }
    if (!down) {
        b->held = 0;
        return false;
    }
    b->held++;
    // closing needs only a press; opening needs the full hold, so a brushed button never covers a sale
    return (shown && b->held == 1) || (!shown && b->held == BOOT_HOLD_TICKS);
}
