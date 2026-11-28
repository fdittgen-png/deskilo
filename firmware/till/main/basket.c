// SPDX-License-Identifier: AGPL-3.0-or-later
#include "basket.h"
#include <string.h>

bool basket_add(basket_t *b, const product_t *p, int qty) {
    if (qty <= 0) return false;
    int i = 0;
    while (i < b->n && strcmp(b->lines[i].item_id, p->id) != 0) i++;
    if (i == b->n) {
        if (b->n >= MAX_PRODUCTS) return false;
        strncpy(b->lines[i].item_id, p->id, sizeof b->lines[i].item_id - 1);
        b->lines[i].item_id[sizeof b->lines[i].item_id - 1] = 0;
        b->lines[i].qty = 0;
        b->n++;
    }
    b->lines[i].qty += qty;
    b->total_minor += (int64_t)p->price_minor * qty;
    b->items += qty;
    b->seq++;
    return true;
}

bool basket_is_confirmed(const basket_t *b) { return b->seq == b->confirmed; }

void basket_confirm(basket_t *b, uint32_t seq) {
    if (seq > b->confirmed && seq <= b->seq) b->confirmed = seq;
}

void basket_restore(basket_t *b, const basket_t *last) {
    uint32_t next = b->seq + 1;
    *b = *last;
    b->seq = next;
    b->confirmed = next;
}

void basket_clear(basket_t *b) {
    uint32_t next = b->seq + 1;
    memset(b, 0, sizeof *b);
    b->seq = next;
    b->confirmed = next;
}
