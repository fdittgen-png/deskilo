// SPDX-License-Identifier: AGPL-3.0-or-later
// The trace ring for the host tests: the same calls as main/trace.c without ESP-IDF's log, timer and locks.
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include "trace.h"

static char s_last[TRACE_WIDTH];
static uint32_t s_version;
void trace_init(void) {}
void trace(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(s_last, sizeof s_last, fmt, ap);
    va_end(ap);
    s_version++;
}
int trace_dump(char *out, int cap) { return snprintf(out, cap, "%s", s_last); }
int trace_tail(char *out, int cap, int n) { (void)n; return snprintf(out, cap, "%s", s_last); }
uint32_t trace_version(void) { return s_version; }
