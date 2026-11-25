// SPDX-License-Identifier: AGPL-3.0-or-later
// #4456 (E05) -- the payment attempt kept across a timeout or a power cut. It is written BEFORE the finalize request leaves
// the board and cleared only after the server's answer is kept: a sale whose answer was lost is asked again under the same
// request id and the same payload, never paid a second time. It lives in its own NVS partition (`attempts`), which
// re-provisioning the settings does not touch. It holds no password or token.
#pragma once
#include <stdbool.h>
#include <stdint.h>
#include "esp_err.h"

typedef struct {
    char request_id[37];
    char receipt_id[37];
    int revision;
    int64_t total_minor;   // the sale total sent as the cash tender
    int64_t given_minor;   // the cash handed over, for the change
    char currency[4];
    char workspace[37];    // the binding: a pending payment is asked again only for the business it was made in
    char server[96];
} pending_t;

typedef struct {
    char number[32];       // the receipt's number, as the server issued it
    int64_t total_minor;
    int64_t given_minor;
    char currency[4];
} paid_t;

esp_err_t pending_init(void);
// Writes the attempt; ESP_OK only once it is committed to flash. No request may be sent otherwise.
esp_err_t pending_save(const pending_t *p);
bool pending_load(pending_t *out);
// Keeps the answer, then forgets the attempt: in this order, so a cut between the two replays to the same receipt.
esp_err_t pending_settle(const paid_t *paid);
bool pending_last_paid(paid_t *out);
// A payment the server refused before it committed anything: the attempt is forgotten, nothing was paid.
esp_err_t pending_drop(void);

// #4456 -- the touch calibration, kept in the same partition: re-provisioning the settings does not undo it.
#include "board.h"
esp_err_t touch_cal_save(const touch_cal_t *cal);
bool touch_cal_load(touch_cal_t *out);
