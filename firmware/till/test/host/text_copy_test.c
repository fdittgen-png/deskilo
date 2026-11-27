// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- a server text in a fixed field on the host: a short text is copied whole; a long one is cut before the
// character that does not fit, never inside it, whether that character is two, three or four bytes long.
#include <stdio.h>
#include <string.h>

#include "text_copy.h"

static int checks, failures;
static void expect(const char *s, size_t cap, const char *want) {
    char d[64];
    memset(d, 'x', sizeof d);
    utf8_copy(d, cap, s);
    checks++;
    if (strcmp(d, want) != 0) { failures++; printf("FAIL: \"%s\" in %zu gave \"%s\", want \"%s\"\n", s, cap, d, want); }
}

int main(void) {
    expect("Croissant", 40, "Croissant");
    expect("Croissant", 6, "Crois");
    expect("Caf\xC3\xA9", 5, "Caf");              // é is two bytes and only one is left: cut before it
    expect("Caf\xC3\xA9", 6, "Caf\xC3\xA9");      // exactly fits
    expect("Pr\xC3\xA9tzel", 4, "Pr");
    expect("\xE2\x82\xAC" "5", 3, "");            // € is three bytes: two do not hold it
    expect("\xE2\x82\xAC" "5", 4, "\xE2\x82\xAC");
    expect("a\xF0\x9F\x8D\xB0", 4, "a");          // a four-byte character cut anywhere is dropped whole
    expect("", 8, "");
    expect(NULL, 8, "");
    expect("abc", 1, "");
    printf("text_copy: %d checks, %d failures\n", checks, failures);
    return failures ? 1 : 0;
}
