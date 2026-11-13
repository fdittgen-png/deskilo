// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2014 — configuration fails closed. A failed credential read throws
// (no order on the installation fallback); a deliberately absent row still
// falls back to the environment; Stripe is "configured" only with the
// webhook secret its settlement needs; a provider name must be one of
// ours, not an inherited property such as `constructor`.
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  effectiveConfig,
  failureOutcome,
  handleWith,
  idempotencyKey,
  isProvider,
  missingFields,
  KEY_RETENTION_S,
  ProviderRefusal,
  reuseVerdict,
} from "./index.ts";

// deno-lint-ignore no-explicit-any
function admin(result: { data: unknown; error: unknown }): any {
  const chain = {
    select: () => chain,
    eq: () => chain,
    maybeSingle: () => Promise.resolve(result),
  };
  return { from: () => chain };
}

const env = (vars: Record<string, string>) => (n: string) => vars[n];

Deno.test("a failed credential read throws, even with env credentials", async () => {
  await assertRejects(() =>
    effectiveConfig(
      admin({ data: null, error: { message: "down" } }),
      "ws-1",
      "stripe",
      env({ STRIPE_SECRET_KEY: "sk", STRIPE_WEBHOOK_SECRET: "wh", PAYMENT_RETURN_URL: "r" }),
    )
  );
});

Deno.test("a deliberately absent row falls back to the environment", async () => {
  const cfg = await effectiveConfig(
    admin({ data: null, error: null }),
    "ws-1",
    "stripe",
    env({ STRIPE_SECRET_KEY: "sk", STRIPE_WEBHOOK_SECRET: "wh", PAYMENT_RETURN_URL: "r" }),
  );
  assertEquals(missingFields(cfg, "stripe"), []);
});

Deno.test("Stripe without its webhook secret is not configured", async () => {
  const cfg = await effectiveConfig(
    admin({ data: { config: { secret_key: "sk", return_url: "r" } }, error: null }),
    "ws-1",
    "stripe",
    env({}),
  );
  assertEquals(missingFields(cfg, "stripe"), ["webhook_secret"]);
});

Deno.test("only our own provider names are providers", () => {
  assertEquals(isProvider("stripe"), true);
  assertEquals(isProvider("constructor"), false);
  assertEquals(isProvider("toString"), false);
  assertEquals(isProvider(42), false);
});

Deno.test("#2014 B — only a provider 4xx fails the intent; the rest is unknown", () => {
  assertEquals(failureOutcome(new ProviderRefusal(402)), "failed");
  assertEquals(failureOutcome(new ProviderRefusal(400)), "failed");
  assertEquals(failureOutcome(new ProviderRefusal(503)), "unknown");
  assertEquals(failureOutcome(new TypeError("network")), "unknown");
  assertEquals(failureOutcome(new DOMException("timeout", "TimeoutError")), "unknown");
});

Deno.test("#2014 B — one stable idempotency key per intent", () => {
  assertEquals(idempotencyKey("i-1"), idempotencyKey("i-1"));
  assertEquals(idempotencyKey("i-1") === idempotencyKey("i-2"), false);
});

// #2014 B — a retried request answers from its stored intent: paid is
// paid, failed needs a new request, a pending one is resent under the
// same key only while the provider still remembers that key.
Deno.test("#2014 B — a reused intent: paid, failed, stale or resend", () => {
  const now = Date.parse("2026-10-01T12:00:00Z");
  const at = (s: number) => new Date(now - s * 1000).toISOString();
  assertEquals(reuseVerdict({ status: "captured", created_at: at(60) }, now), "paid");
  assertEquals(reuseVerdict({ status: "failed", created_at: at(60) }, now), "failed");
  assertEquals(reuseVerdict({ status: "created", created_at: at(60) }, now), "resend");
  assertEquals(reuseVerdict({ status: "created", created_at: at(KEY_RETENTION_S + 1) }, now), "stale");
});

// #1863 C — replaces the source grep for `"webhook_id"`: paypal-webhook
// refuses every event without one, so PayPal is not configured without it.
Deno.test("PayPal without its webhook id is not configured", async () => {
  const cfg = await effectiveConfig(
    admin({ data: { config: { client_id: "c", secret: "s", return_url: "r" } }, error: null }),
    "ws-1",
    "paypal",
    env({}),
  );
  assertEquals(missingFields(cfg, "paypal"), ["webhook_id"]);
});

Deno.test("a provider's 408, 409, 425 and 429 leave the outcome unknown; other 4xx fail it", () => {
  for (const status of [408, 409, 425, 429]) {
    assertEquals(failureOutcome(new ProviderRefusal(status)), "unknown", `${status}`);
  }
  assertEquals(failureOutcome(new ProviderRefusal(400)), "failed");
  assertEquals(failureOutcome(new ProviderRefusal(422)), "failed");
  assertEquals(failureOutcome(new ProviderRefusal(503)), "unknown");
});

/** A service client whose reads are canned per table; it records the
 * tables read, in order. */
function recordingAdmin(
  rows: Record<string, unknown>,
  read: string[],
  // deno-lint-ignore no-explicit-any
): any {
  return {
    auth: {
      getUser: () =>
        Promise.resolve({ data: { user: { id: "user-1" } }, error: null }),
    },
    from: (table: string) => {
      read.push(table);
      const result = { data: rows[table] ?? null, error: null };
      const chain = {
        select: () => chain,
        eq: () => chain,
        maybeSingle: () => Promise.resolve(result),
        single: () => Promise.resolve(result),
      };
      return chain;
    },
  };
}

const order = (memberId: string) =>
  new Request("http://localhost/create-payment-order", {
    method: "POST",
    headers: { Authorization: "Bearer t" },
    body: JSON.stringify({
      workspace_id: "11111111-1111-4111-8111-111111111111",
      member_id: memberId,
      provider: "stripe",
      amount_cents: 1000,
      request_id: "22222222-2222-4222-8222-222222222222",
    }),
  });

Deno.test("a caller who is not the member of this workspace is refused before the workspace is read", async () => {
  const foreign = "33333333-3333-4333-8333-333333333333";
  for (
    const member of [
      // Another person's membership.
      { id: foreign, user_id: "user-2", workspace_id: "11111111-1111-4111-8111-111111111111", status: "active" },
      // The caller's own membership, in another workspace.
      { id: foreign, user_id: "user-1", workspace_id: "44444444-4444-4444-8444-444444444444", status: "active" },
      // No such member.
      null,
    ]
  ) {
    const read: string[] = [];
    const res = await handleWith(
      order(foreign),
      recordingAdmin({
        members: member,
        // A development workspace and no provider configured: neither is
        // answered to a caller who is not the member.
        workspaces: { environment: "dev", currency_code: "EUR" },
      }, read),
    );
    assertEquals(res.status, 403);
    assertEquals((await res.json()).error, "not_your_bill");
    assertEquals(read.includes("workspaces"), false, read.join(","));
  }
});

Deno.test("a member id that is not one is refused as not the caller's bill", async () => {
  const read: string[] = [];
  const res = await handleWith(order("not-a-uuid"), recordingAdmin({}, read));
  assertEquals(res.status, 403);
  assertEquals(read, []);
});

Deno.test("the member themself, in a development workspace, is told it takes no payments", async () => {
  const me = "55555555-5555-4555-8555-555555555555";
  const read: string[] = [];
  const res = await handleWith(
    order(me),
    recordingAdmin({
      members: { id: me, user_id: "user-1", workspace_id: "11111111-1111-4111-8111-111111111111", status: "active" },
      workspaces: { environment: "dev", currency_code: "EUR" },
    }, read),
  );
  assertEquals(res.status, 409);
  assertEquals((await res.json()).error, "development_workspace");
  assertEquals(read, ["members", "workspaces"]);
});
