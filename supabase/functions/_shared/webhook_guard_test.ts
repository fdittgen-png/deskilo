// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3093 — a stale or missing transmission time is refused, a failed credential
// read is an error, a provider body is redacted to status and debug id.

import {
  assert,
  assertEquals,
  assertFalse,
  assertThrows,
} from "jsr:@std/assert@1";
import {
  configOf,
  MAX_TRANSMISSION_SKEW_MS,
  redactedProviderLog,
  transmissionFresh,
} from "./webhook_guard.ts";

const now = Date.parse("2026-10-30T12:00:00Z");

Deno.test("a transmission more than five minutes off is stale", () => {
  assert(transmissionFresh("2026-10-30T11:56:00Z", now));
  assert(transmissionFresh("2026-10-30T12:04:00Z", now));
  assertFalse(transmissionFresh("2026-10-30T11:54:00Z", now));
  assertFalse(transmissionFresh("2026-10-30T12:06:00Z", now));
  assertEquals(MAX_TRANSMISSION_SKEW_MS, 300_000);
});

Deno.test("a missing or unreadable transmission time is not fresh", () => {
  assertFalse(transmissionFresh(null, now));
  assertFalse(transmissionFresh("", now));
  assertFalse(transmissionFresh("yesterday", now));
});

Deno.test("a failed credential read throws instead of falling back", () => {
  assertThrows(
    () => configOf({ data: null, error: { message: "db down" } }),
    Error,
    "credential read failed",
  );
  assertEquals(configOf({ data: { config: { api_key: "k" } }, error: null }), {
    api_key: "k",
  });
  // No row is a real answer: the installation's key applies.
  assertEquals(configOf({ data: null, error: null }), {});
});

Deno.test("a provider body is logged as status and debug id only", () => {
  assertEquals(
    redactedProviderLog(
      422,
      JSON.stringify({ debug_id: "abc123", payer: { email: "a@b.c" } }),
    ),
    { status: 422, debug_id: "abc123" },
  );
  assertEquals(redactedProviderLog(500, "<html>payer a@b.c</html>"), {
    status: 500,
  });
  assertEquals(redactedProviderLog(400, JSON.stringify({ name: "x" })), {
    status: 400,
  });
});
