// SPDX-License-Identifier: AGPL-3.0-or-later
// #4519 -- the connection code as the server reads it, carried in one number, and where the board's link goes on each
// answer of the server.
#include <stdio.h>
#include <string.h>
#include "enroll.h"

static int failed;
#define CHECK(cond, what) do { if (!(cond)) { printf("FAIL: %s\n", what); failed++; } } while (0)

int main(void) {
    char c[ENROLL_CODE_LEN + 1];
    CHECK(enroll_code_normal("K7M2-9QXR-4TNB", c) && !strcmp(c, "K7M29QXR4TNB"), "a code with its dashes");
    CHECK(enroll_code_normal(" k7m2 9qxr 4tnb ", c) && !strcmp(c, "K7M29QXR4TNB"), "lower case and spaces");
    CHECK(enroll_code_normal("OILK-0110-ABCD", c) && !strcmp(c, "011K0110ABCD"), "O is 0, I and L are 1");
    CHECK(!enroll_code_normal("K7M2-9QXR-4TN", c), "eleven symbols are no code");
    CHECK(!enroll_code_normal("K7M2-9QXR-4TNBX", c), "nor thirteen");
    CHECK(!enroll_code_normal("K7M2-9QXR-4TNU", c), "U is not a symbol");
    CHECK(!enroll_code_normal("K7M2-9QXR-4TN!", c), "nor anything else");
    CHECK(!enroll_code_normal(NULL, c), "nor nothing");
    enroll_code_normal("ZZZZ-ZZZZ-ZZZZ", c);
    char back[ENROLL_CODE_LEN + 1];
    enroll_code_unpack(enroll_code_pack(c), back);
    CHECK(!strcmp(back, c), "the largest code goes there and back in one number");
    CHECK(enroll_code_pack(c) > 0, "and stays positive");
    enroll_code_normal("K7M2-9QXR-4TNB", c);
    enroll_code_unpack(enroll_code_pack(c), back);
    CHECK(!strcmp(back, c), "a code goes there and back");

    CHECK(link_of_status("paired") == LINK_ASKING, "a paired board asks for a cashier");
    CHECK(link_of_status("pending_approval") == LINK_PENDING, "a claimed board waits for the owner");
    CHECK(link_of_status(NULL) == LINK_ENROLL, "an unknown board is connected first");
    CHECK(link_on(LINK_SELLING, "operator_expired") == LINK_ASKING, "an ended lease asks again");
    CHECK(link_on(LINK_SELLING, "operator_revoked") == LINK_ASKING, "so does an ended one");
    CHECK(link_on(LINK_SELLING, "device_revoked") == LINK_ENROLL, "a removed board is connected again");
    CHECK(link_on(LINK_SELLING, "refused") == LINK_SELLING, "a refused sale keeps selling");
    CHECK(link_on(LINK_SELLING, "uncertain") == LINK_SELLING, "an uncertain answer is no refusal");
    CHECK(link_on(LINK_ASKING, "operator_pending") == LINK_ASKING, "a board waits for its cashier");
    if (failed) { printf("enroll_test: %d failed\n", failed); return 1; }
    printf("enroll_test: all passed\n");
    return 0;
}
