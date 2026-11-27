// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- a server text copied into one of the board's fixed fields: cut at a whole character, never in the middle of
// one, so a long name ends a little earlier instead of on half a letter the font cannot draw.
#pragma once
#include <stddef.h>

// Copies s into d (cap bytes, cap >= 1), always NUL-terminated, cut at the last whole UTF-8 character that fits.
void utf8_copy(char *d, size_t cap, const char *s);
