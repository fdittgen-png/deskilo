// SPDX-License-Identifier: AGPL-3.0-or-later
// #4456 (E05) host tests of the payment rules (main/pay_logic.c), on the same cJSON as the board:
//   quantity_money   -- money read from the wire without a float; exponents, fractions, signs, overflow refused
//   cash_confirmation-- too little cash sends nothing; total 1250 given 2000 sends 1250 and leaves 750 change
//   uncertain_http   -- timeout, malformed success, 5xx, 401, a 4xx without a business code stay uncertain
//   powercut         -- a store that fails sends nothing; a sent attempt replays with the same request
// Run: ./run.sh (exit 0 = all passed).
#include <stdio.h>
#include <string.h>
#include "cJSON.h"
#include "pay_logic.h"

static int failed, passed;
#define CHECK(cond, what) do { if (cond) passed++; else { failed++; printf("FAIL %s:%d %s\n", __FILE__, __LINE__, what); } } while (0)

static bool parse(const char *json, int64_t *out) {
    cJSON *j = cJSON_Parse(json);
    bool ok = pay_minor_from_json(j, out);
    cJSON_Delete(j);
    return ok;
}

static void quantity_money(void) {
    int64_t v = 0;
    CHECK(parse("\"1250\"", &v) && v == 1250, "a decimal string is read exactly");
    CHECK(parse("\"-30\"", &v) && v == -30, "a negative amount is read");
    CHECK(parse("\"0\"", &v) && v == 0, "zero is read");
    CHECK(parse("\"9223372036854775807\"", &v) && v == INT64_MAX, "the largest int64 is read");
    CHECK(!parse("\"9223372036854775808\"", &v), "one past int64 is refused");
    CHECK(!parse("\"12.50\"", &v), "a fraction is refused");
    CHECK(!parse("\"1e3\"", &v), "an exponent is refused");
    CHECK(!parse("\"+5\"", &v), "a plus sign is refused");
    CHECK(!parse("\" 5\"", &v), "a leading space is refused");
    CHECK(!parse("\"05\"", &v), "a leading zero is refused");
    CHECK(!parse("\"-0\"", &v), "a signed zero is refused");
    CHECK(!parse("\"1 000\"", &v), "grouping is refused");
    CHECK(!parse("\"\"", &v), "an empty string is refused");
    CHECK(parse("1250", &v) && v == 1250, "an exact integer number is read");
    CHECK(!parse("12.5", &v), "a fractional number is refused");
    CHECK(!parse("1e300", &v), "a number beyond exact integers is refused");
    CHECK(!parse("null", &v), "null is refused");
}

static void cash_confirmation(void) {
    int64_t change = -1;
    CHECK(!pay_cash_enough(1250, 1000, &change), "too little cash is refused");
    CHECK(pay_cash_enough(1250, 2000, &change) && change == 750, "1250 due, 2000 given: 750 change");
    CHECK(pay_cash_enough(1250, 1250, &change) && change == 0, "exact cash: no change");
    CHECK(!pay_cash_enough(0, 100, &change), "nothing due is not a payment");
}

static void uncertain_http(void) {
    char n[32], why[96];
    const char *rid = "r-1";
    CHECK(pay_classify(200, "{\"receipt_id\":\"r-1\",\"number\":\"R-00012\"}", rid, n, sizeof n, why, sizeof why) == PAY_DONE && !strcmp(n, "R-00012"),
          "a success naming this receipt and its number is done");
    CHECK(pay_classify(200, "{\"number\":\"R-00012\"}", rid, n, sizeof n, why, sizeof why) == PAY_DONE, "a success with a number and no receipt id is done");
    CHECK(pay_classify(200, "{\"receipt_id\":\"r-2\",\"number\":\"R-9\"}", rid, n, sizeof n, why, sizeof why) == PAY_UNCERTAIN, "a success for another receipt proves nothing");
    CHECK(pay_classify(200, "{\"receipt_id\":\"r-1\"", rid, n, sizeof n, why, sizeof why) == PAY_UNCERTAIN, "a truncated success is uncertain");
    CHECK(pay_classify(200, "{}", rid, n, sizeof n, why, sizeof why) == PAY_UNCERTAIN, "a success without a number is uncertain");
    CHECK(pay_classify(-1, NULL, rid, n, sizeof n, why, sizeof why) == PAY_UNCERTAIN, "no answer (timeout) is uncertain");
    CHECK(pay_classify(500, "{\"code\":\"DKL06\"}", rid, n, sizeof n, why, sizeof why) == PAY_UNCERTAIN, "a 5xx is uncertain, whatever it says");
    CHECK(pay_classify(502, "<html>bad gateway</html>", rid, n, sizeof n, why, sizeof why) == PAY_UNCERTAIN, "a gateway page is uncertain");
    CHECK(pay_classify(401, "{\"code\":\"PGRST301\",\"message\":\"JWT expired\"}", rid, n, sizeof n, why, sizeof why) == PAY_UNCERTAIN, "an expired session is uncertain");
    CHECK(pay_classify(400, "{\"code\":\"22P02\"}", rid, n, sizeof n, why, sizeof why) == PAY_UNCERTAIN, "a 4xx without a business code is uncertain");
    CHECK(pay_classify(400, "{\"code\":\"DKL01\",\"message\":\"this operation is not supported here\"}", rid, n, sizeof n, why, sizeof why) == PAY_REFUSED && !strncmp(why, "DKL01", 5),
          "a business refusal is refused, with its code");
    CHECK(pay_classify(400, "{\"code\":\"DKL10\"}", rid, n, sizeof n, why, sizeof why) == PAY_REFUSED, "a stale revision is refused");
}

// The fakes: a store that keeps or fails, a server that counts what it receives and remembers each request id once.
static int store_fails, saved, sends;
static char last_request[40], seen_requests[4][40];
static int seen_n, sales;
typedef struct { char request_id[40]; } fake_attempt_t;
static int fake_save(const void *a) { if (store_fails) return 1; saved++; return 0; }
static pay_result_t fake_send(const void *a, char *n, int ncap, char *why, int cap) {
    const fake_attempt_t *t = a;
    sends++;
    snprintf(last_request, sizeof last_request, "%s", t->request_id);
    int known = 0;
    for (int i = 0; i < seen_n; i++) if (!strcmp(seen_requests[i], t->request_id)) known = 1;
    if (!known && seen_n < 4) { snprintf(seen_requests[seen_n++], 40, "%s", t->request_id); sales++; }   // the server is idempotent per request
    snprintf(n, ncap, "R-%05d", sales);
    return sends == 1 ? PAY_UNCERTAIN : PAY_DONE;   // the first answer is lost
}

static void powercut(void) {
    char n[32], why[96];
    fake_attempt_t a = {"11111111-1111-4111-8111-111111111111"};
    store_fails = 1;
    CHECK(pay_run(&a, fake_save, fake_send, n, sizeof n, why, sizeof why) == PAY_NOT_STARTED && sends == 0, "a store that fails sends nothing");
    store_fails = 0;
    CHECK(pay_run(&a, fake_save, fake_send, n, sizeof n, why, sizeof why) == PAY_UNCERTAIN && saved == 1 && sends == 1, "kept, sent, the answer lost");
    // the board restarts: the kept attempt is sent again as it is
    CHECK(fake_send(&a, n, sizeof n, why, sizeof why) == PAY_DONE && !strcmp(last_request, a.request_id), "the replay carries the same request");
    CHECK(sales == 1, "and the server made one sale");
}

int main(void) {
    quantity_money();
    cash_confirmation();
    uncertain_http();
    powercut();
    printf("%d passed, %d failed\n", passed, failed);
    return failed ? 1 : 0;
}
