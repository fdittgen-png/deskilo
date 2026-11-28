// SPDX-License-Identifier: AGPL-3.0-or-later
#include "layout_keys.h"
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

static const char *const SIZES[] = {"tablet", "phone", "desk"};   // the board's 480 x 320 is closest to a tablet's

typedef struct { int row, col; const char *id; } key_t;

static int by_place(const void *a, const void *b) {
    const key_t *x = a, *y = b;
    return x->row != y->row ? x->row - y->row : x->col - y->col;
}

int layout_item_ids(const cJSON *layout, char out[][40], int max) {
    int n = 0;
    const cJSON *pages = cJSON_GetObjectItemCaseSensitive(layout, "pages");
    const cJSON *page;
    cJSON_ArrayForEach(page, pages) {
        const cJSON *grids = cJSON_GetObjectItemCaseSensitive(page, "grids"), *grid = NULL;
        for (int s = 0; s < 3 && !cJSON_IsObject(grid); s++) grid = cJSON_GetObjectItemCaseSensitive(grids, SIZES[s]);
        const cJSON *cells = cJSON_GetObjectItemCaseSensitive(grid, "cells");
        key_t keys[64];
        int k = 0;
        const cJSON *cell;
        cJSON_ArrayForEach(cell, cells) {
            if (k >= 64) break;
            const cJSON *kind = cJSON_GetObjectItemCaseSensitive(cell, "kind");
            const cJSON *params = cJSON_GetObjectItemCaseSensitive(cell, "params");
            const cJSON *id = cJSON_GetObjectItemCaseSensitive(params, "item_id");
            if (!cJSON_IsString(kind) || strcmp(kind->valuestring, "item_key") != 0) continue;
            if (!cJSON_IsString(id) || strlen(id->valuestring) == 0 || strlen(id->valuestring) >= 40) continue;
            const cJSON *row = cJSON_GetObjectItemCaseSensitive(cell, "row"), *col = cJSON_GetObjectItemCaseSensitive(cell, "col");
            keys[k++] = (key_t){cJSON_IsNumber(row) ? row->valueint : 0, cJSON_IsNumber(col) ? col->valueint : 0, id->valuestring};
        }
        qsort(keys, k, sizeof keys[0], by_place);
        for (int i = 0; i < k && n < max; i++) {
            bool seen = false;
            for (int j = 0; j < n && !seen; j++) seen = strcmp(out[j], keys[i].id) == 0;
            if (seen) continue;
            strncpy(out[n], keys[i].id, 39);
            out[n][39] = 0;
            n++;
        }
    }
    return n;
}
