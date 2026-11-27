// SPDX-License-Identifier: AGPL-3.0-or-later
// #4453/#4456 -- the plain data the network task fills and the screen shows: no ESP-IDF in here, so the host tests use it.
#pragma once
#include <stdbool.h>
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

// The commands the screen sends to the network task.
enum { CMD_TAP, CMD_NEXT, CMD_REPORT, CMD_PAY, CMD_CASH, CMD_RETRY, CMD_REFRESH };
// The sale's phase: selling; the cash being counted; sent; paid; sent without a proven answer; a payment of another binding
// waits and nothing is sold here.
enum { PH_SELL, PH_CASH, PH_PAYING, PH_PAID, PH_UNCERTAIN, PH_BLOCKED };

// What the screen shows: a copy of the network task's state, taken under its lock.
typedef struct {
    char status[96];     // what the board is doing, or what went wrong
    product_t products[MAX_PRODUCTS];
    int n_products;
    roll_t roll;
    bool has_roll;
    bool online;
    // #4456 the payment: where the sale stands, what is due and given, and the receipt it got
    int phase;
    int64_t due, given;
    char paid_number[32];
    uint32_t version;
} shared_t;
