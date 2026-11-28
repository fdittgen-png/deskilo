// SPDX-License-Identifier: AGPL-3.0-or-later
// #4508 -- the basket the screen shows at once: a key adds its line and the total from the price the board already holds,
// before the server has answered. Each change takes the next sequence number; the server's answer to a draft confirms the
// basket as it was sent (its sequence), so keys pressed meanwhile stay unconfirmed and go in the next draft. The server's
// total is the one that is paid. No ESP-IDF in here: the host tests use it.
#pragma once
#include <stdbool.h>
#include <stdint.h>
#include "till_types.h"

typedef struct {
    basket_line_t lines[MAX_PRODUCTS];
    int n;
    int64_t total_minor;   // from the board's prices: what the screen shows until the server answers
    int items;
    uint32_t seq;          // the change this basket is at
    uint32_t confirmed;    // the change the server last confirmed
} basket_t;

// Adds [qty] of [p]; false (nothing changed) when the basket has no room for another line or [qty] is not positive.
bool basket_add(basket_t *b, const product_t *p, int qty);
// Whether the basket on the screen is the one the server last confirmed.
bool basket_is_confirmed(const basket_t *b);
// The server answered the draft sent at change [seq].
void basket_confirm(basket_t *b, uint32_t seq);
// The server refused the draft: the basket goes back to [last] (the last confirmed one), at a new change.
void basket_restore(basket_t *b, const basket_t *last);
// Empty, confirmed (the next customer).
void basket_clear(basket_t *b);
