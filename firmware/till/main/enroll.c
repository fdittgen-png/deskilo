// SPDX-License-Identifier: AGPL-3.0-or-later
#include "enroll.h"
#include <string.h>

static const char ALPHABET[] = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

int enroll_symbol(char c) {
    if (c >= 'a' && c <= 'z') c = (char)(c - 'a' + 'A');
    if (c == 'O') c = '0';
    if (c == 'I' || c == 'L') c = '1';
    const char *p = c ? strchr(ALPHABET, c) : NULL;
    return p ? (int)(p - ALPHABET) : -1;
}

char enroll_symbol_char(int v) { return v >= 0 && v < 32 ? ALPHABET[v] : '?'; }

bool enroll_code_normal(const char *in, char out[ENROLL_CODE_LEN + 1]) {
    int n = 0;
    for (const char *c = in ? in : ""; *c; c++) {
        if (*c == ' ' || *c == '-' || *c == '\t') continue;
        int v = enroll_symbol(*c);
        if (v < 0 || n == ENROLL_CODE_LEN) return false;
        out[n++] = ALPHABET[v];
    }
    out[n] = 0;
    return n == ENROLL_CODE_LEN;
}

int64_t enroll_code_pack(const char code[ENROLL_CODE_LEN + 1]) {
    int64_t v = 0;
    for (int i = 0; i < ENROLL_CODE_LEN; i++) v = (v << 5) | enroll_symbol(code[i]);
    return v;
}

void enroll_code_unpack(int64_t v, char out[ENROLL_CODE_LEN + 1]) {
    for (int i = ENROLL_CODE_LEN - 1; i >= 0; i--) { out[i] = ALPHABET[v & 31]; v >>= 5; }
    out[ENROLL_CODE_LEN] = 0;
}

link_t link_of_status(const char *status) {
    if (status && !strcmp(status, "paired")) return LINK_ASKING;
    if (status && !strcmp(status, "pending_approval")) return LINK_PENDING;
    return LINK_ENROLL;
}

link_t link_on(link_t now, const char *reason) {
    if (!reason) return now;
    if (!strcmp(reason, "operator_expired") || !strcmp(reason, "operator_revoked") || !strcmp(reason, "scope_mismatch")) return LINK_ASKING;
    if (!strcmp(reason, "pair_proof_invalid") || !strcmp(reason, "device_revoked")) return LINK_ENROLL;
    if (!strcmp(reason, "pair_pending")) return LINK_PENDING;
    if (!strcmp(reason, "operator_pending")) return LINK_ASKING;
    return now;
}
