// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Untrusted requests do no privileged work; authorized callers receive one
// opaque accepted response regardless of configuration or identifier details.
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

Deno.test("unknown identifiers and unreadable records have the same opaque response", async () => {
  Deno.env.set("PUSH_SHARED_SECRET", secret);
  Deno.env.set("FCM_SERVICE_ACCOUNT", JSON.stringify({ project_id: "fixture" }));
  try {
    for (const mode of ["unknown", "unavailable"]) {
      let reads = 0;
      const chain = {
        select: () => chain,
        eq: () => chain,
        maybeSingle: () => {
          reads++;
          if (mode === "unavailable") throw new Error("fixture read refused");
          return Promise.resolve({ data: null });
        },
      };
      // deno-lint-ignore no-explicit-any
      const client = { from: () => chain } as any;
      const response = await handle(request({ "x-deskilo-push-secret": secret }), client);
      assertEquals(reads, 1);
      assertEquals(response.status, 202);
      assertEquals(await response.json(), { accepted: true });
    }
  } finally {
    Deno.env.delete("FCM_SERVICE_ACCOUNT");
    Deno.env.delete("PUSH_SHARED_SECRET");
  }
});
