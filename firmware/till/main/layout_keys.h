// SPDX-License-Identifier: AGPL-3.0-or-later
// #4508 -- the item keys of a till's published layout (till_layouts.layout, #4448), as the board shows them: page by
// page, each page's grid for the board's width (tablet, else phone, else desk), its item keys row by row, left to right;
// an item already on an earlier key is not repeated. No ESP-IDF in here: the host tests use it.
#pragma once
#include "cJSON.h"

// Writes up to [max] item ids of [layout] into [out]; answers how many (0 for a layout without item keys).
int layout_item_ids(const cJSON *layout, char out[][40], int max);
