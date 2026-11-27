// SPDX-License-Identifier: AGPL-3.0-or-later
// #4466 -- the readable pairing code against the shared table (test/fixtures/device_pairing_codes.json), the same table
// the app's Dart tests read: each case encodes to its code and decodes back, each typo is refused for its reason, and a
// code typed in lower case with spaces reads as the code.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cJSON.h"
#include "readable_code.h"

static int failures = 0;
#define CHECK(cond, ...) do { if (!(cond)) { failures++; printf("FAIL: " __VA_ARGS__); printf("\n"); } } while (0)

static char *slurp(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = malloc((size_t)n + 1);
    if (fread(buf, 1, (size_t)n, f) != (size_t)n) { fclose(f); free(buf); return NULL; }
    buf[n] = '\0';
    fclose(f);
    return buf;
}

int main(int argc, char **argv) {
    char *text = slurp(argc > 1 ? argv[1] : "test/fixtures/device_pairing_codes.json");
    CHECK(text != NULL, "the shared table is readable");
    if (!text) return 1;
    cJSON *doc = cJSON_Parse(text);
    int cases = 0;
    cJSON *c;
    cJSON_ArrayForEach(c, cJSON_GetObjectItem(doc, "codes")) {
        uint32_t id = (uint32_t)strtoul(cJSON_GetObjectItem(c, "short_id")->valuestring, NULL, 16);
        int profile = cJSON_GetObjectItem(c, "profile")->valueint, proof = cJSON_GetObjectItem(c, "proof")->valueint;
        const char *code = cJSON_GetObjectItem(c, "code")->valuestring;
        char out[READABLE_CODE_LEN];
        readable_code_encode(id, profile, proof, out);
        CHECK(strcmp(out, code) == 0, "%08x/%d/%d encodes to %s, not %s", (unsigned)id, profile, proof, code, out);
        uint32_t id2;
        int p2, q2;
        CHECK(readable_code_decode(code, &id2, &p2, &q2) == READABLE_OK && id2 == id && p2 == profile && q2 == proof, "%s decodes back", code);
        cases++;
    }
    cJSON_ArrayForEach(c, cJSON_GetObjectItem(doc, "refused")) {
        const char *code = cJSON_GetObjectItem(c, "code")->valuestring, *why = cJSON_GetObjectItem(c, "reason")->valuestring;
        readable_result_t want = strcmp(why, "check") == 0 ? READABLE_CHECK : strcmp(why, "alphabet") == 0 ? READABLE_ALPHABET : READABLE_LENGTH;
        uint32_t id;
        int p, q;
        CHECK(readable_code_decode(code, &id, &p, &q) == want, "%s is refused for %s", code, why);
        cases++;
    }
    cJSON_ArrayForEach(c, cJSON_GetObjectItem(doc, "lenient")) {
        uint32_t a, b;
        int pa, pb, qa, qb;
        CHECK(readable_code_decode(cJSON_GetObjectItem(c, "typed")->valuestring, &a, &pa, &qa) == READABLE_OK
              && readable_code_decode(cJSON_GetObjectItem(c, "code")->valuestring, &b, &pb, &qb) == READABLE_OK && a == b && qa == qb,
              "typed in lower case with spaces it reads as the code");
        cases++;
    }
    cJSON_Delete(doc);
    free(text);
    printf("readable_code: %d cases, %d failures\n", cases, failures);
    return failures ? 1 : 0;
}
