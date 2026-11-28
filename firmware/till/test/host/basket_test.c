// SPDX-License-Identifier: AGPL-3.0-or-later
// #4508 host tests of the basket the screen shows at once (main/basket.c):
//   shown_at_once  -- a key adds its line and the total from the board's price, unconfirmed until the server answers
//   coalesced      -- keys pressed while a draft is on its way stay unconfirmed and go in the next draft
//   refused        -- a refused draft brings back the last confirmed basket
//   bounded        -- a ninth product or a quantity of 0 changes nothing; the next customer starts empty and confirmed
// Run: ./run.sh (exit 0 = all passed).
#include <stdio.h>
#include <string.h>
#include "basket.h"

static int failed, passed;
#define CHECK(cond, what) do { if (cond) passed++; else { failed++; printf("FAIL %s:%d %s\n", __FILE__, __LINE__, what); } } while (0)

static product_t coffee = {"item-coffee", "Coffee", 250}, croissant = {"item-croissant", "Croissant", 180};

static void shown_at_once(void) {
    basket_t b = {0};
    CHECK(basket_is_confirmed(&b), "an empty basket is confirmed");
    CHECK(basket_add(&b, &coffee, 1), "a key adds its line");
    CHECK(b.n == 1 && b.items == 1 && b.total_minor == 250, "the total is the board's price, at once");
    CHECK(!basket_is_confirmed(&b), "and stays unconfirmed until the server answers");
    basket_confirm(&b, b.seq);
    CHECK(basket_is_confirmed(&b), "the server's answer confirms it");
}

static void coalesced(void) {
    basket_t b = {0};
    basket_add(&b, &coffee, 1);
    uint32_t sent = b.seq;   // the draft goes out with one coffee
    basket_add(&b, &coffee, 1);
    basket_add(&b, &croissant, 1);
    CHECK(b.n == 2 && b.lines[0].qty == 2 && b.items == 3 && b.total_minor == 680, "the keys pressed meanwhile are shown");
    basket_confirm(&b, sent);
    CHECK(!basket_is_confirmed(&b), "the answer to the first draft leaves the later keys unconfirmed");
    basket_confirm(&b, b.seq);
    CHECK(basket_is_confirmed(&b), "the next draft, with all three, confirms them");
    basket_confirm(&b, sent);
    CHECK(basket_is_confirmed(&b) && b.confirmed == b.seq, "a late answer to an older draft confirms nothing back");
}

static void refused(void) {
    basket_t b = {0}, last;
    basket_add(&b, &coffee, 1);
    basket_confirm(&b, b.seq);
    last = b;
    basket_add(&b, &croissant, 2);
    basket_restore(&b, &last);
    CHECK(b.n == 1 && b.items == 1 && b.total_minor == 250, "a refused draft brings back the last confirmed basket");
    CHECK(basket_is_confirmed(&b), "which is confirmed");
}

static void bounded(void) {
    basket_t b = {0};
    product_t p[MAX_PRODUCTS + 1];
    for (int i = 0; i <= MAX_PRODUCTS; i++) { snprintf(p[i].id, sizeof p[i].id, "item-%d", i); p[i].price_minor = 100; }
    for (int i = 0; i < MAX_PRODUCTS; i++) basket_add(&b, &p[i], 1);
    uint32_t seq = b.seq;
    CHECK(!basket_add(&b, &p[MAX_PRODUCTS], 1) && b.seq == seq && b.n == MAX_PRODUCTS, "a line past the last is not added");
    CHECK(!basket_add(&b, &coffee, 0) && b.seq == seq, "nor a quantity of 0");
    basket_clear(&b);
    CHECK(b.n == 0 && b.total_minor == 0 && basket_is_confirmed(&b) && b.seq > seq, "the next customer starts empty");
}

int main(void) {
    shown_at_once();
    coalesced();
    refused();
    bounded();
    printf("basket: %d passed, %d failed\n", passed, failed);
    return failed ? 1 : 0;
}
