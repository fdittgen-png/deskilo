// SPDX-License-Identifier: AGPL-3.0-or-later
import { assertEquals } from "jsr:@std/assert@1";
import { handle } from "./index.ts";

const secret = "test-trigger-secret";

function request(headers: Record<string, string> = {}) {
  return new Request("https://example.test/send-push", {
    method: "POST", headers, body: JSON.stringify({ event_id: "unknown-event" }),
  });
}

Deno.test("an untrusted caller is refused before any database or provider work", async () => {
  Deno.env.set("PUSH_SHARED_SECRET", secret);
  let reads = 0;
  const client = { from: () => { reads++; throw new Error("unexpected read"); } };
  try {
    // deno-lint-ignore no-explicit-any
    const response = await handle(request(), client as any);
    assertEquals(response.status, 401);
    assertEquals(reads, 0);
  } finally { Deno.env.delete("PUSH_SHARED_SECRET"); }
});

Deno.test("an installation with no secret refuses publishable callers", async () => {
  Deno.env.delete("PUSH_SHARED_SECRET");
  Deno.env.delete("FCM_SERVICE_ACCOUNT");
  // deno-lint-ignore no-explicit-any
  const response = await handle(request(), {} as any);
  assertEquals(response.status, 401);
});

Deno.test("an authorized call has one accepted response without configuration or id details", async () => {
  Deno.env.set("PUSH_SHARED_SECRET", secret);
  Deno.env.delete("FCM_SERVICE_ACCOUNT");
  try {
    // deno-lint-ignore no-explicit-any
    const response = await handle(request({ "x-deskilo-push-secret": secret }), {} as any);
    assertEquals(response.status, 202);
    assertEquals(await response.json(), { accepted: true });
  } finally { Deno.env.delete("PUSH_SHARED_SECRET"); }
});
