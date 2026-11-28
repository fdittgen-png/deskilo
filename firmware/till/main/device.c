// SPDX-License-Identifier: AGPL-3.0-or-later
#include "device.h"
#include <stdio.h>
#include <string.h>
#include "esp_random.h"
#include "mbedtls/sha256.h"
#include "nvs.h"

#define PART "attempts"
#define NS "device"

static void fingerprint_of(const uint8_t secret[32], device_t *out) {
    uint8_t h[32];
    mbedtls_sha256(secret, 32, h, 0);
    snprintf(out->fingerprint, sizeof out->fingerprint, "%02X%02X-%02X%02X", h[0], h[1], h[2], h[3]);
    for (int i = 0; i < 32; i++) snprintf(out->secret_hash + 2 * i, 3, "%02x", h[i]);
}

esp_err_t device_secret_hex(char out[65]) {
    nvs_handle_t h;
    esp_err_t e = nvs_open_from_partition(PART, NS, NVS_READONLY, &h);
    if (e != ESP_OK) return e;
    uint8_t secret[32];
    size_t n = sizeof secret;
    e = nvs_get_blob(h, "secret", secret, &n);
    nvs_close(h);
    if (e == ESP_OK && n != sizeof secret) e = ESP_ERR_INVALID_SIZE;
    if (e == ESP_OK) for (int i = 0; i < 32; i++) snprintf(out + 2 * i, 3, "%02x", secret[i]);
    memset(secret, 0, sizeof secret);
    return e;
}

esp_err_t device_identity(device_t *out) {
    nvs_handle_t h;
    esp_err_t e = nvs_open_from_partition(PART, NS, NVS_READWRITE, &h);
    if (e != ESP_OK) return e;
    uint8_t secret[32];
    size_t n = sizeof secret, idn = sizeof out->id;
    if (nvs_get_blob(h, "secret", secret, &n) != ESP_OK || n != sizeof secret || nvs_get_str(h, "id", out->id, &idn) != ESP_OK) {
        // the first start: an id and a secret from the hardware random source, kept before anything shows them
        uint8_t b[16];
        esp_fill_random(b, sizeof b);
        b[6] = (b[6] & 0x0F) | 0x40;
        b[8] = (b[8] & 0x3F) | 0x80;
        snprintf(out->id, sizeof out->id, "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
                 b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]);
        esp_fill_random(secret, sizeof secret);
        e = nvs_set_blob(h, "secret", secret, sizeof secret);
        if (e == ESP_OK) e = nvs_set_str(h, "id", out->id);
        if (e == ESP_OK) e = nvs_commit(h);
    }
    nvs_close(h);
    if (e == ESP_OK) fingerprint_of(secret, out);
    memset(secret, 0, sizeof secret);
    return e;
}
