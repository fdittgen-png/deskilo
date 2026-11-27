// SPDX-License-Identifier: AGPL-3.0-or-later
// #4466 -- see readable_code.h.
#include "readable_code.h"

#include <ctype.h>
#include <string.h>

static const char ALPHABET[] = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
#define BASE 31
#define DATA 9

static int index_of(char c) {
    const char *p = strchr(ALPHABET, c);
    return (c && p) ? (int)(p - ALPHABET) : -1;
}

// The position-weighted sum of the data symbols, mod 31: one wrong symbol, or two neighbours swapped, changes it.
static char check_of(const int *digits) {
    int sum = 0;
    for (int i = 0; i < DATA; i++) sum += (i + 1) * digits[i];
    return ALPHABET[sum % BASE];
}

void readable_code_encode(uint32_t short_id, int profile, int proof, char *out) {
    uint64_t v = ((uint64_t)short_id << 12) | ((uint64_t)(profile & 3) << 10) | (uint64_t)(proof & 0x3ff);
    int digits[DATA];
    for (int i = DATA - 1; i >= 0; i--) {
        digits[i] = (int)(v % BASE);
        v /= BASE;
    }
    char s[DATA + 1];
    for (int i = 0; i < DATA; i++) s[i] = ALPHABET[digits[i]];
    s[DATA] = check_of(digits);
    memcpy(out, s, 5);
    out[5] = '-';
    memcpy(out + 6, s + 5, 5);
    out[11] = '\0';
}

readable_result_t readable_code_decode(const char *typed, uint32_t *short_id, int *profile, int *proof) {
    char s[DATA + 1];
    int n = 0;
    for (const char *p = typed; *p; p++) {
        if (*p == '-' || *p == ' ') continue;
        if (n == DATA + 1) return READABLE_LENGTH;
        s[n++] = (char)toupper((unsigned char)*p);
    }
    if (n != DATA + 1) return READABLE_LENGTH;
    int digits[DATA];
    for (int i = 0; i < DATA + 1; i++) {
        if (index_of(s[i]) < 0) return READABLE_ALPHABET;
        if (i < DATA) digits[i] = index_of(s[i]);
    }
    if (check_of(digits) != s[DATA]) return READABLE_CHECK;
    uint64_t v = 0;
    for (int i = 0; i < DATA; i++) v = v * BASE + (uint64_t)digits[i];
    if (v >> 44) return READABLE_CHECK;   // more than the 44 bits a code holds
    *short_id = (uint32_t)(v >> 12);
    *profile = (int)((v >> 10) & 3);
    *proof = (int)(v & 0x3ff);
    return READABLE_OK;
}
