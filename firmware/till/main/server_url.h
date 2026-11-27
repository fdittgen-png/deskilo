// SPDX-License-Identifier: AGPL-3.0-or-later
// #4474 -- the Deskilo server the board talks to, as the provisioning wrote it: refused unless it is a plain
// https://host[:port][/path] address, so a value that carries a user, a query, a fragment, a space, a control character
// or a host no DNS name can be never reaches the HTTP client. The paths the board adds itself are not checked here.
#pragma once
#include <stdbool.h>
#include <stddef.h>

// True for "https://" (lower case), then a host of letters, digits, '-' and '.' (labels of 1..63, none starting or
// ending with '-', the whole at most 253), an optional ":port" (1..65535), and an optional path; every byte printable
// ASCII without '@', '?', '#' or '\'; the whole shorter than cap (the field that holds it).
bool server_url_ok(const char *url, size_t cap);
