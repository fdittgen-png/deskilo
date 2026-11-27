// SPDX-License-Identifier: AGPL-3.0-or-later
// #4456 (E05) -- the payment's rules with no hardware in them, so the host tests run them as the board does: money read from
// the wire without a float, the server's answer to a finalize classified (done, refused before commit, or uncertain), and
// the order of a payment (kept in flash first, sent only then).
#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef enum { PAY_DONE, PAY_REFUSED, PAY_UNCERTAIN, PAY_NOT_STARTED } pay_result_t;

// A decimal string ("1250", "-30") or an exact integer JSON number as minor units; anything else is refused.
bool pay_minor_from_json(const void *cjson_item, int64_t *out);

// What a finalize answer proves: [status] the HTTP status (-1: none), [body] the answer, [receipt_id] the sale it paid.
pay_result_t pay_classify(int status, const char *body, const char *receipt_id, char *number, int number_cap, char *why, int why_cap);

// Enough cash for the total, both in minor units of one currency; the change into [change].
bool pay_cash_enough(int64_t due, int64_t given, int64_t *change);

// One payment, in its order: [save] the attempt (0 = kept), and only then [send] it. A failed save sends nothing.
typedef int (*pay_save_fn)(const void *attempt);
typedef pay_result_t (*pay_send_fn)(const void *attempt, char *number, int number_cap, char *why, int why_cap);
pay_result_t pay_run(const void *attempt, pay_save_fn save, pay_send_fn send, char *number, int number_cap, char *why, int why_cap);
