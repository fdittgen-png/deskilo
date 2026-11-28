// SPDX-License-Identifier: AGPL-3.0-or-later
// #4519 (E05) -- the board connects itself and sells under a cashier's lease. The connection code the owner gets in
// Settings > Devices is typed on the touchscreen: 12 symbols of 0-9 and A-Z without I, L, O and U (the server's
// till_terminal_code_normal, 0984: O is read as 0, I and L as 1; spaces and dashes do not count). Where the board stands
// with the server is its link: to be connected, waiting for the owner's approval, asking for a cashier, or selling. No
// ESP-IDF in here: the host tests use it.
#pragma once
#include <stdbool.h>
#include <stdint.h>

#define ENROLL_CODE_LEN 12

// [in] as the server reads it into [out] (ENROLL_CODE_LEN symbols and a 0); false for anything else.
bool enroll_code_normal(const char *in, char out[ENROLL_CODE_LEN + 1]);
// The symbol's value (0..31), or -1; and the symbol of a value.
int enroll_symbol(char c);
char enroll_symbol_char(int v);
// A normal code in one number (5 bits a symbol), so the screen sends it as a command's value; and back.
int64_t enroll_code_pack(const char code[ENROLL_CODE_LEN + 1]);
void enroll_code_unpack(int64_t v, char out[ENROLL_CODE_LEN + 1]);

// Where the board stands with the server.
typedef enum { LINK_SELLING, LINK_ENROLL, LINK_PENDING, LINK_ASKING } link_t;   // selling first: a state never set is a screen of its own

// Where a board in [now] goes on the server's [reason] (a refusal of `command` or of operator.request, or the
// enrollment status): a lease that ended asks again, a board the server does not know is connected again, the rest stays.
link_t link_on(link_t now, const char *reason);
// The link an enrollment status of [status] ("pending_approval", "paired") gives.
link_t link_of_status(const char *status);
