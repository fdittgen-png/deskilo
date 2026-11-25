// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- the text of the pairing code: what the app reads from the QR. Pure, so the host tests read it as the app does.
#include <stdio.h>
#include "device.h"

void device_pairing_payload(const device_t *d, const char *board_profile, const char *firmware, char *out, int cap) {
    snprintf(out, cap, "deskilo-device:v1?id=%s&board=%s&fw=%s&fp=%s", d->id, board_profile, firmware, d->fingerprint);
}
