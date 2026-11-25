// SPDX-License-Identifier: AGPL-3.0-or-later
// #4454/#4456 bring-up -- the terminal's calls to Deskilo: Wi-Fi, time, the user's session, the products of the company, a draft of the
// basket (priced by the server) and the roll of the open draft. Every call is HTTPS; the server owns prices, tax and numbers.
#pragma once
#include <stdbool.h>
#include "esp_err.h"
#include "pending.h"
#include <stdint.h>

#define MAX_PRODUCTS 8
#define MAX_LINES 24

typedef struct { char id[40]; char name[40]; int price_minor; } product_t;
typedef struct { char label[48]; char qty[16]; int gross_minor; } roll_line_t;
typedef struct {
    roll_line_t lines[MAX_LINES];
    int n;
    int total_minor;
    char currency[4];
    int revision;
    char receipt_id[40];
} roll_t;
typedef struct { char item_id[40]; int qty; } basket_line_t;

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

// #4456 (E05) -- the end of a payment, as far as the board can prove it.
typedef enum {
    PAY_DONE,       // the server issued the receipt (number filled)
    PAY_REFUSED,    // the server refused before it committed anything: nothing was paid (why filled)
    PAY_UNCERTAIN,  // no proof either way: the attempt stays, and is asked again under the same request id
} pay_result_t;

// Pays receipt [p->receipt_id] at revision [p->revision] in cash: one tender of the SALE TOTAL (the change is the board's
// business). Sends exactly what [p] holds, so a retry is the same request.
pay_result_t api_finalize_cash(const pending_t *p, char *number, int number_cap, char *why, int cap);
// A decimal string or integer field of the wire as minor units; false for anything else (exponent, fraction, overflow).
bool minor_from_json(const void *cjson_item, int64_t *out);
// The draft's priced total and currency as the server answered them last (valid after api_draft returned true).
int64_t api_draft_total(void);
// A new random request id (UUID v4) into out[37].
void api_new_id(char *out);
