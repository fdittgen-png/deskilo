// SPDX-License-Identifier: AGPL-3.0-or-later
// #4454/#4456 -- the terminal's calls to Deskilo: Wi-Fi, time, and, through the installation's embedded-till function, the
// board's connection (its code, then the owner's approval), the cashier it asks for, and under that cashier's lease the
// products of its till, a draft of the basket (priced by the server) and the roll of the open draft (#4519). The board
// signs in as nobody: it proves itself with its secret and its lease token, which lives in memory only. Every call is
// HTTPS; the server owns prices, tax and numbers.
#pragma once
#include <stdbool.h>
#include "esp_err.h"
#include "pending.h"
#include <stdint.h>

#include "till_types.h"

esp_err_t net_connect(const char *ssid, const char *pass);   // Wi-Fi and the time (TLS needs it)
bool net_online(void);
// #4519 -- the board's connection. The board presents the owner's [code] (normal, enroll.h) with its id and its secret's
// hash; true when the server took it, with the board's status ("pending_approval", "paired") in [status].
bool api_claim(const char *code, char *status, int status_cap, char *why, int cap);
// The board's status with the server; true with [status] when the server knows it, and the business and till it serves
// set from the answer. False with the server's reason in [why_reason] (pair_proof_invalid: a board to connect).
bool api_status(char *status, int status_cap, char *why_reason, int reason_cap);
// Asks for a cashier with a new lease token (kept in memory only); true when the server took the request.
bool api_ask_cashier(char *why_reason, int reason_cap);
// Whether a cashier took the board: true once the lease's command answers. The server's reason otherwise.
bool api_leased(char *why_reason, int reason_cap);
// The server's reason of the last refused command (operator_expired, operator_revoked, ...), consumed; empty when none.
const char *api_take_link_reason(void);
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
