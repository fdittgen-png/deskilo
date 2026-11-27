// SPDX-License-Identifier: AGPL-3.0-or-later
#include "pay_logic.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cJSON.h"

bool pay_minor_from_json(const void *item, int64_t *out) {
    const cJSON *v = (const cJSON *)item;
    if (cJSON_IsString(v)) {
        const char *t = v->valuestring;
        // digits only, an optional leading minus, no leading zero, no sign on zero: spaces, '+', exponents and fractions are refused
        if (!t[0] || (t[0] == '0' && t[1]) || (t[0] == '-' && (t[1] == '0' || !t[1]))) return false;
        for (const char *c = t[0] == '-' ? t + 1 : t; *c; c++) if (*c < '0' || *c > '9') return false;
        errno = 0;
        char *end;
        long long n = strtoll(t, &end, 10);
        if (errno || *end) return false;
        *out = n;
        return true;
    }
    if (cJSON_IsNumber(v)) {   // only while the number is an exact integer
        double d = v->valuedouble;
        if (d > 9007199254740991.0 || d < -9007199254740991.0 || d != (double)(long long)d) return false;
        *out = (long long)d;
        return true;
    }
    return false;
}

pay_result_t pay_classify(int status, const char *body, const char *receipt_id, char *number, int number_cap, char *why, int cap) {
    cJSON *j = body ? cJSON_Parse(body) : NULL;
    pay_result_t r = PAY_UNCERTAIN;
    if (status == 200 && j && cJSON_IsObject(j)) {
        const cJSON *n = cJSON_GetObjectItem(j, "number"), *rid = cJSON_GetObjectItem(j, "receipt_id");
        // a success is proven only by the receipt it names: this attempt's receipt, with its number
        if (cJSON_IsString(n) && n->valuestring[0] && (!rid || (cJSON_IsString(rid) && !strcmp(rid->valuestring, receipt_id)))) {
            snprintf(number, number_cap, "%s", n->valuestring);
            r = PAY_DONE;
        } else snprintf(why, cap, "answer without this receipt's number");
    } else if (status >= 400 && status < 500 && j) {
        // a business refusal (DK...) is raised before the server commits: rolled back, nothing paid. A 401 (the session ran
        // out) or any 4xx without such a code proves nothing.
        const cJSON *code = cJSON_GetObjectItem(j, "code"), *msg = cJSON_GetObjectItem(j, "message");
        if (cJSON_IsString(code) && !strncmp(code->valuestring, "DK", 2)) {
            snprintf(why, cap, "%s %.70s", code->valuestring, cJSON_IsString(msg) ? msg->valuestring : "");
            r = PAY_REFUSED;
        } else snprintf(why, cap, "no proof (%d)", status);
    } else if (status < 0) snprintf(why, cap, "no answer");
    else snprintf(why, cap, "no proof (%d)", status);
    cJSON_Delete(j);
    return r;
}

bool pay_cash_enough(int64_t due, int64_t given, int64_t *change) {
    if (due <= 0 || given < due) return false;
    *change = given - due;
    return true;
}

pay_result_t pay_run(const void *attempt, pay_save_fn save, pay_send_fn send, char *number, int number_cap, char *why, int why_cap) {
    if (save(attempt) != 0) {
        snprintf(why, why_cap, "the attempt could not be stored");
        return PAY_NOT_STARTED;
    }
    return send(attempt, number, number_cap, why, why_cap);
}
