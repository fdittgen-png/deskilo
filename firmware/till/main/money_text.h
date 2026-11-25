// SPDX-License-Identifier: AGPL-3.0-or-later
// An amount in minor units as text in its currency's exponent (JPY 0, KWD 3, most 2), exact: integers only.
#pragma once
#include <stddef.h>
#include <stdint.h>

void money(char *out, size_t cap, int64_t minor, const char *cur);
