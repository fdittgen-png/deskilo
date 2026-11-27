// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- a server text copied into a fixed field (text_copy.h).
#include "text_copy.h"

#include <string.h>

void utf8_copy(char *d, size_t cap, const char *s) {
    if (cap == 0) return;
    size_t n = s ? strlen(s) : 0;
    if (n > cap - 1) {
        n = cap - 1;
        // step back over continuation bytes (10xxxxxx) to the start of the character the cut falls in, and drop it
        // unless it ends exactly at the cut
        size_t start = n;
        while (start > 0 && ((unsigned char)s[start] & 0xC0) == 0x80) start--;
        n = start;
    }
    if (n) memcpy(d, s, n);
    d[n] = 0;
}
