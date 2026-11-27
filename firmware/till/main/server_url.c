// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- the Deskilo server address's rules (server_url.h).
#include "server_url.h"

#include <string.h>

static bool ldh(char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-'; }

bool server_url_ok(const char *url, size_t cap) {
    if (!url) return false;
    size_t n = 0;
    while (n < cap && url[n]) n++;   // the length, read no further than the field
    if (n == 0 || n >= cap) return false;
    for (size_t i = 0; i < n; i++) {
        unsigned char c = (unsigned char)url[i];
        if (c < 33 || c > 126 || c == '@' || c == '?' || c == '#' || c == '\\') return false;
    }
    static const char scheme[] = "https://";
    if (strncmp(url, scheme, sizeof scheme - 1) != 0) return false;
    const char *a = url + sizeof scheme - 1;
    const char *end = strchr(a, '/');
    size_t alen = end ? (size_t)(end - a) : strlen(a);
    const char *colon = memchr(a, ':', alen);
    size_t hlen = colon ? (size_t)(colon - a) : alen;
    if (hlen == 0 || hlen > 253) return false;
    size_t label = 0;
    for (size_t i = 0; i < hlen; i++) {
        char c = a[i];
        if (c == '.') {
            if (label == 0 || a[i - 1] == '-') return false;
            label = 0;
            continue;
        }
        if (!ldh(c) || (label == 0 && c == '-') || ++label > 63) return false;
    }
    if (label == 0 || a[hlen - 1] == '-') return false;
    if (colon) {
        size_t plen = alen - hlen - 1;
        if (plen == 0 || plen > 5) return false;
        long port = 0;
        for (size_t i = 0; i < plen; i++) {
            char c = colon[1 + i];
            if (c < '0' || c > '9') return false;
            port = port * 10 + (c - '0');
        }
        if (port < 1 || port > 65535) return false;
    }
    return true;
}
