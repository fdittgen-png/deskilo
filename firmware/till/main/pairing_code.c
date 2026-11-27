// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- the text of the pairing code: what the app reads from the QR. Pure, so the host tests read it as the app does.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "device.h"
#include "readable_code.h"

void device_pairing_payload(const device_t *d, const char *board_profile, const char *firmware, char *out, int cap) {
    // #4454: h is the SHA-256 of the board's secret; the code its owner is given is bound to it, so a board that only
    // copied the QR (id and fingerprint) cannot use that code
    snprintf(out, cap, "deskilo-device:v1?id=%s&board=%s&fw=%s&fp=%s&h=%s", d->id, board_profile, firmware, d->fingerprint,
             d->secret_hash);
}

void device_readable_code(const device_t *d, int profile, char *out) {
    char id[9] = {0}, b0[3] = {0}, b1[3] = {0};
    memcpy(id, d->id, 8);                 // a UUID's first 8 hex digits: 32 bits
    memcpy(b0, d->fingerprint, 2);        // "AB12-CD34": the fingerprint's first two bytes
    memcpy(b1, d->fingerprint + 2, 2);
    int proof = ((int)strtol(b0, NULL, 16) << 2) | ((int)strtol(b1, NULL, 16) >> 6);
    readable_code_encode((uint32_t)strtoul(id, NULL, 16), profile, proof, out);
}
