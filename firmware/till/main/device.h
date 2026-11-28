// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- the board's own identity: a device id and a 256-bit secret made once, at the first start, from the hardware
// random source, and kept in the `attempts` partition, which re-provisioning never rewrites. The pairing code carries the
// id, the SHA-256 of the secret (which the server's code is bound to, #4454) and its short fingerprint, never the secret.
#pragma once
#include <stdbool.h>
#include "esp_err.h"

typedef struct {
    char id[37];        // a UUID v4
    char fingerprint[10]; // "AB12-CD34": the first four bytes of SHA-256(secret), to compare by eye
    char secret_hash[65]; // SHA-256(secret), lower-case hex: what the board's connection code is bound to (#4454)
} device_t;

// Reads the identity, making it on the first start; ESP_OK with [out] filled.
esp_err_t device_identity(device_t *out);
// #4519 -- the secret as the board presents it to Deskilo (64 lower-case hex) into [out]; never shown, never traced.
esp_err_t device_secret_hex(char out[65]);
// #4466 -- the readable code of this board (XXXXX-XXXXX, readable_code.h): its short id, [profile] and the first 10
// bits of its fingerprint; [out] holds READABLE_CODE_LEN.
void device_readable_code(const device_t *d, int profile, char *out);

// The text of the pairing code for this board (deskilo-device:v1?...), into [out].
void device_pairing_payload(const device_t *d, const char *board_profile, const char *firmware, char *out, int cap);
