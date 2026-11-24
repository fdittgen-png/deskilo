// SPDX-License-Identifier: AGPL-3.0-or-later
// #4454/#4456 bring-up -- the terminal's calls to Deskilo: Wi-Fi, time, the user's session, the products of the company, a draft of the
// basket (priced by the server) and the roll of the open draft. Every call is HTTPS; the server owns prices, tax and numbers.
#pragma once
#include <stdbool.h>
#include "esp_err.h"

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
