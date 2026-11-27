// SPDX-License-Identifier: AGPL-3.0-or-later
#include "pending.h"
#include <string.h>
#include "nvs.h"
#include "nvs_flash.h"

#define PART "attempts"
#define NS "pay"

// An unreadable attempts area is never erased to make it readable: a pending payment may be in it. The board then sells
// nothing until someone looks (the caller refuses to take payments when this fails).
esp_err_t pending_init(void) { return nvs_flash_init_partition(PART); }

static esp_err_t open_rw(nvs_handle_t *h) { return nvs_open_from_partition(PART, NS, NVS_READWRITE, h); }

esp_err_t pending_save(const pending_t *p) {
    nvs_handle_t h;
    esp_err_t e = open_rw(&h);
    if (e != ESP_OK) return e;
    e = nvs_set_blob(h, "attempt", p, sizeof *p);
    if (e == ESP_OK) e = nvs_commit(h);
    nvs_close(h);
    return e;
}

bool pending_load(pending_t *out) {
    nvs_handle_t h;
    if (nvs_open_from_partition(PART, NS, NVS_READONLY, &h) != ESP_OK) return false;
    size_t n = sizeof *out;
    bool ok = nvs_get_blob(h, "attempt", out, &n) == ESP_OK && n == sizeof *out && out->request_id[0];
    nvs_close(h);
    return ok;
}

esp_err_t pending_settle(const paid_t *paid) {
    nvs_handle_t h;
    esp_err_t e = open_rw(&h);
    if (e != ESP_OK) return e;
    e = nvs_set_blob(h, "paid", paid, sizeof *paid);
    if (e == ESP_OK) e = nvs_commit(h);
    if (e == ESP_OK) {
        e = nvs_erase_key(h, "attempt");
        if (e == ESP_OK || e == ESP_ERR_NVS_NOT_FOUND) e = nvs_commit(h);
    }
    nvs_close(h);
    return e;
}

bool pending_last_paid(paid_t *out) {
    nvs_handle_t h;
    if (nvs_open_from_partition(PART, NS, NVS_READONLY, &h) != ESP_OK) return false;
    size_t n = sizeof *out;
    bool ok = nvs_get_blob(h, "paid", out, &n) == ESP_OK && n == sizeof *out;
    nvs_close(h);
    return ok;
}

esp_err_t pending_drop(void) {
    nvs_handle_t h;
    esp_err_t e = open_rw(&h);
    if (e != ESP_OK) return e;
    e = nvs_erase_key(h, "attempt");
    if (e == ESP_OK || e == ESP_ERR_NVS_NOT_FOUND) e = nvs_commit(h);
    nvs_close(h);
    return e;
}

esp_err_t touch_cal_save(const touch_cal_t *cal) {
    nvs_handle_t h;
    esp_err_t e = nvs_open_from_partition(PART, "touch", NVS_READWRITE, &h);
    if (e != ESP_OK) return e;
    uint8_t blob[TOUCH_CAL_BLOB];
    touch_cal_encode(cal, blob);
    e = nvs_set_blob(h, "cal", blob, sizeof blob);
    if (e == ESP_OK) e = nvs_commit(h);
    nvs_close(h);
    return e;
}

bool touch_cal_load(touch_cal_t *out) {
    nvs_handle_t h;
    if (nvs_open_from_partition(PART, "touch", NVS_READONLY, &h) != ESP_OK) return false;
    uint8_t blob[TOUCH_CAL_BLOB];
    size_t n = sizeof blob;
    // a kept calibration without its mark and checksum, or with values no calibration gives, is not used
    bool ok = nvs_get_blob(h, "cal", blob, &n) == ESP_OK && touch_cal_decode(blob, n, BOARD_LCD_W, BOARD_LCD_H, out);
    nvs_close(h);
    return ok;
}
