// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- the board's own identity: a device id and a 256-bit secret made once, at the first start, from the hardware
// random source, and kept in the `attempts` partition, which re-provisioning never rewrites. The pairing code carries the
// id and a short fingerprint of the secret, never the secret itself (#4466, E03).
#pragma once
#include <stdbool.h>
#include "esp_err.h"

typedef struct {
    char id[37];        // a UUID v4
    char fingerprint[10]; // "AB12-CD34": the first four bytes of SHA-256(secret), to compare by eye
} device_t;

// Reads the identity, making it on the first start; ESP_OK with [out] filled.
esp_err_t device_identity(device_t *out);
// #4466 -- the readable code of this board (XXXXX-XXXXX, readable_code.h): its short id, [profile] and the first 10
// bits of its fingerprint; [out] holds READABLE_CODE_LEN.
void device_readable_code(const device_t *d, int profile, char *out);

// The text of the pairing code for this board (deskilo-device:v1?...), into [out].
void device_pairing_payload(const device_t *d, const char *board_profile, const char *firmware, char *out, int cap);
