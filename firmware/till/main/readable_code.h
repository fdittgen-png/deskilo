// SPDX-License-Identifier: AGPL-3.0-or-later
// #4466 -- the board's readable pairing code, shown beside its QR and printed on a screenless board's label: the short
// id (the first 32 bits of its id), its profile and a proof (the first 10 bits of its fingerprint) in 9 symbols of base
// 31 -- an alphabet without 0, O, 1, I and L -- then a check symbol, shown as XXXXX-XXXXX. Typing it does what the scan
// does; a typo is refused at once by the check. Pure: the host tests read it against test/fixtures/device_pairing_codes.json.
#pragma once
#include <stdbool.h>
#include <stdint.h>

#define READABLE_CODE_LEN 12   // "XXXXX-XXXXX" and its end

typedef enum { READABLE_OK = 0, READABLE_LENGTH, READABLE_ALPHABET, READABLE_CHECK } readable_result_t;

// [out] (READABLE_CODE_LEN) is the code of [short_id], [profile] (0-3) and [proof] (0-1023).
void readable_code_encode(uint32_t short_id, int profile, int proof, char *out);

// Reads [typed] (any case, spaces and dashes ignored): what it holds, or why it is refused.
readable_result_t readable_code_decode(const char *typed, uint32_t *short_id, int *profile, int *proof);
