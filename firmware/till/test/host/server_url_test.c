// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- the Deskilo server address on the host: the project addresses the provisioning writes pass; an address with a
// user, a query, a fragment, a space, a control character, another scheme, a bad host or port, or one too long for its
// field, is refused.
#include <stdio.h>
#include <string.h>

#include "server_url.h"

static int checks, failures;
static void expect(const char *url, int ok) {
    checks++;
    if (server_url_ok(url, 96) != ok) { failures++; printf("FAIL: %s should be %s\n", url, ok ? "accepted" : "refused"); }
}

int main(void) {
    expect("https://zwzbynivewivvjmripeb.supabase.co", 1);
    expect("https://deskilo.example.org:8443", 1);
    expect("https://api.deskilo.example.org/base", 1);
    expect("https://localhost", 1);
    expect("http://deskilo.example.org", 0);
    expect("HTTPS://deskilo.example.org", 0);
    expect("https://", 0);
    expect("https:///path", 0);
    expect("https://user@deskilo.example.org", 0);
    expect("https://deskilo.example.org?x=1", 0);
    expect("https://deskilo.example.org#top", 0);
    expect("https://deskilo example.org", 0);
    expect("https://deskilo.example.org\r\nHost: other", 0);
    expect("https://deskilo.example.org\\x", 0);
    expect("https://[::1]", 0);
    expect("https://.deskilo.org", 0);
    expect("https://deskilo.org.", 0);
    expect("https://deskilo..org", 0);
    expect("https://-deskilo.org", 0);
    expect("https://deskilo-.org", 0);
    expect("https://deskilo.org:", 0);
    expect("https://deskilo.org:0", 0);
    expect("https://deskilo.org:65536", 0);
    expect("https://deskilo.org:443:1", 0);
    expect("https://deskilo.org:44a", 0);
    expect("", 0);
    char label[128] = "https://";
    memset(label + 8, 'a', 64);
    strcpy(label + 72, ".org");
    checks++;
    if (server_url_ok(label, sizeof label)) { failures++; printf("FAIL: a label of 64 should be refused\n"); }
    char longest[96] = "https://";
    memset(longest + 8, 'a', 50);
    longest[58] = '.';
    memset(longest + 59, 'b', 36);
    longest[95] = 0;
    checks++;
    if (!server_url_ok(longest, sizeof longest)) { failures++; printf("FAIL: 95 bytes in a 96-byte field should pass\n"); }
    char over[97];
    memcpy(over, longest, 95);
    over[95] = 'c';
    over[96] = 0;
    checks++;
    if (server_url_ok(over, 96)) { failures++; printf("FAIL: an address that fills its field should be refused\n"); }
    char nul[] = "https://deskilo.org\0https://other.org";
    checks++;
    if (!server_url_ok(nul, 96) || strlen(nul) != 19) { failures++; printf("FAIL: the C string ends at its NUL\n"); }
    printf("server_url: %d checks, %d failures\n", checks, failures);
    return failures ? 1 : 0;
}
