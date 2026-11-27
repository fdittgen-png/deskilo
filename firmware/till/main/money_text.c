// SPDX-License-Identifier: AGPL-3.0-or-later
#include "money_text.h"
#include <stdio.h>
#include <string.h>

static int exponent_of(const char *c) {
    if (!strcmp(c, "JPY") || !strcmp(c, "KRW") || !strcmp(c, "ISK")) return 0;
    if (!strcmp(c, "KWD") || !strcmp(c, "BHD") || !strcmp(c, "OMR") || !strcmp(c, "TND") || !strcmp(c, "JOD")) return 3;
    return 2;
}
void money(char *out, size_t cap, int64_t minor, const char *cur) {
    int e = exponent_of(cur);
    int64_t div = 1;
    for (int i = 0; i < e; i++) div *= 10;
    const char *sign = minor < 0 ? "-" : "";
    int64_t a = minor < 0 ? -minor : minor;
    char t[64];   // room for any int64 and a currency: the caller's buffer only cuts the end
    if (e == 0) snprintf(t, sizeof t, "%s%lld %.3s", sign, (long long)a, cur);
    else snprintf(t, sizeof t, "%s%lld.%0*lld %.3s", sign, (long long)(a / div), e, (long long)(a % div), cur);
    size_t n = strlen(t) < cap - 1 ? strlen(t) : cap - 1;
    memcpy(out, t, n);
    out[n] = 0;
}

