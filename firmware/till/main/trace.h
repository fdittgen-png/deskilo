// SPDX-License-Identifier: AGPL-3.0-or-later
// #4453 bring-up -- the board's traces: what it did and what went wrong, kept in a ring of the last TRACE_LINES lines for the
// trace box on the screen, and sent to Deskilo as a trace report (submit_trace_report_v1) when something fails. A trace never
// holds a password, a token or a request body: only steps, HTTP statuses, the server's refusal code and its message.
#pragma once
#include <stdint.h>

#define TRACE_LINES 40
#define TRACE_WIDTH 100

void trace(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
// The ring, oldest first, one "   12s text" line each; returns the length written.
int trace_dump(char *out, int cap);
// The newest [n] lines (newest last) into [out]; returns the length written.
int trace_tail(char *out, int cap, int n);
uint32_t trace_version(void);
