// SPDX-License-Identifier: AGPL-3.0-or-later
// #4454/#4456 bring-up -- the terminal's calls to Deskilo: Wi-Fi, time, the user's session, the products of the company, a draft of the
// basket (priced by the server) and the roll of the open draft. Every call is HTTPS; the server owns prices, tax and numbers.
#pragma once
#include <stdbool.h>
#include "esp_err.h"
#include "pending.h"
#include <stdint.h>

#include "till_types.h"

esp_err_t net_connect(const char *ssid, const char *pass);   // Wi-Fi and the time (TLS needs it)
bool net_online(void);
bool api_sign_in(char *why, int cap);                         // refresh token -> access token; the rotated refresh token is kept
int api_products(product_t *out, int max, char *why, int cap);
// Sends the basket as a draft (a new one, or the open one at [receipt_id]/[revision]); fills [out] with the server's priced lines.
bool api_draft(const basket_line_t *b, int n, roll_t *out, char *why, int cap);
void api_reset_draft(void);                                   // the next customer: the next basket starts a new draft
// Reads the newest open draft of the company into [out]; false with [why] empty when there is none.
bool api_roll(roll_t *out, char *why, int cap);
// The server's refusal code of the last failed call (DKG01, a PostgREST code or the HTTP status).
const char *api_last_code(void);
// Sends the trace ring to Deskilo as a trace report of this board; the installation's operator reads it in the app.
bool api_report(const char *role, const char *failure_type, const char *failure_code);

#include "pay_logic.h"
// Pays receipt [p->receipt_id] at revision [p->revision] in cash: one tender of the SALE TOTAL (the change is the board's
// business). Sends exactly what [p] holds, so a retry is the same request.
pay_result_t api_finalize_cash(const pending_t *p, char *number, int number_cap, char *why, int cap);
// The draft's priced total and currency as the server answered them last (valid after api_draft returned true).
int64_t api_draft_total(void);
// A new random request id (UUID v4) into out[37].
void api_new_id(char *out);
