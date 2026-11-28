// SPDX-License-Identifier: AGPL-3.0-or-later
// #4508 host tests of the published layout's item keys (main/layout_keys.c):
//   ordered    -- page by page, row by row, left to right; only item keys
//   grid       -- the tablet grid first, then the phone's, then the desk's
//   bounded    -- no more than asked, an item once, a malformed cell skipped, no layout no keys
// Run: ./run.sh (exit 0 = all passed).
#include <stdio.h>
#include <string.h>
#include "cJSON.h"
#include "layout_keys.h"

static int failed, passed;
#define CHECK(cond, what) do { if (cond) passed++; else { failed++; printf("FAIL %s:%d %s\n", __FILE__, __LINE__, what); } } while (0)

static int read_ids(const char *json, char out[][40], int max) {
    cJSON *j = cJSON_Parse(json);
    int n = layout_item_ids(j, out, max);
    cJSON_Delete(j);
    return n;
}

static void ordered(void) {
    char ids[8][40];
    int n = read_ids("{\"pages\":["
        "{\"grids\":{\"phone\":{\"cols\":4,\"rows\":6,\"cells\":["
        "{\"kind\":\"item_key\",\"col\":1,\"row\":1,\"params\":{\"item_id\":\"tea\",\"label\":\"Tea\"}},"
        "{\"kind\":\"basket\",\"col\":0,\"row\":2},"
        "{\"kind\":\"item_key\",\"col\":0,\"row\":1,\"params\":{\"item_id\":\"coffee\"}},"
        "{\"kind\":\"item_key\",\"col\":3,\"row\":0,\"params\":{\"item_id\":\"water\"}}]}}},"
        "{\"grids\":{\"phone\":{\"cells\":[{\"kind\":\"item_key\",\"col\":0,\"row\":0,\"params\":{\"item_id\":\"soup\"}}]}}}]}", ids, 8);
    CHECK(n == 4, "four item keys, the basket left out");
    CHECK(n == 4 && !strcmp(ids[0], "water") && !strcmp(ids[1], "coffee") && !strcmp(ids[2], "tea") && !strcmp(ids[3], "soup"),
          "row by row, left to right, then the next page");
}

static void grid(void) {
    char ids[8][40];
    int n = read_ids("{\"pages\":[{\"grids\":{"
        "\"phone\":{\"cells\":[{\"kind\":\"item_key\",\"col\":0,\"row\":0,\"params\":{\"item_id\":\"phone-item\"}}]},"
        "\"tablet\":{\"cells\":[{\"kind\":\"item_key\",\"col\":0,\"row\":0,\"params\":{\"item_id\":\"tablet-item\"}}]}}}]}", ids, 8);
    CHECK(n == 1 && !strcmp(ids[0], "tablet-item"), "the tablet grid is the board's");
    n = read_ids("{\"pages\":[{\"grids\":{\"desk\":{\"cells\":[{\"kind\":\"item_key\",\"col\":0,\"row\":0,\"params\":{\"item_id\":\"d\"}}]},"
        "\"phone\":{\"cells\":[{\"kind\":\"item_key\",\"col\":0,\"row\":0,\"params\":{\"item_id\":\"p\"}}]}}}]}", ids, 8);
    CHECK(n == 1 && !strcmp(ids[0], "p"), "without one, the phone's before the desk's");
}

static void bounded(void) {
    char ids[2][40];
    int n = read_ids("{\"pages\":[{\"grids\":{\"phone\":{\"cells\":["
        "{\"kind\":\"item_key\",\"col\":0,\"row\":0,\"params\":{\"item_id\":\"a\"}},"
        "{\"kind\":\"item_key\",\"col\":1,\"row\":0,\"params\":{\"item_id\":\"a\"}},"
        "{\"kind\":\"item_key\",\"col\":2,\"row\":0,\"params\":{}},"
        "{\"kind\":\"item_key\",\"col\":3,\"row\":0,\"params\":{\"item_id\":7}},"
        "{\"kind\":\"item_key\",\"col\":0,\"row\":1,\"params\":{\"item_id\":\"b\"}},"
        "{\"kind\":\"item_key\",\"col\":1,\"row\":1,\"params\":{\"item_id\":\"c\"}}]}}}]}", ids, 2);
    CHECK(n == 2 && !strcmp(ids[0], "a") && !strcmp(ids[1], "b"), "an item once, malformed keys skipped, no more than asked");
    char none[8][40];
    CHECK(read_ids("{}", none, 8) == 0, "no layout, no keys");
    CHECK(read_ids("{\"pages\":[{\"grids\":{}}]}", none, 8) == 0, "a page without a grid, no keys");
}

int main(void) {
    ordered();
    grid();
    bounded();
    printf("layout_keys: %d passed, %d failed\n", passed, failed);
    return failed ? 1 : 0;
}
