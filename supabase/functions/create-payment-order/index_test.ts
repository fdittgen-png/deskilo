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
  claimRefusal,
  handedThen,
  handleWith,
  orderFailure,
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

Deno.test("#3917 -- a 400 to a resent intent is unknown: its order may exist under its key", () => {
  // A retry across a change of the order's parameters sends them under the
  // old key: Stripe answers 400 idempotency_error, Mollie 400 Bad Request.
  assertEquals(failureOutcome(new ProviderRefusal(400), true), "unknown");
  assertEquals(failureOutcome(new ProviderRefusal(402), true), "failed");
  assertEquals(failureOutcome(new ProviderRefusal(400), false), "failed");
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

/** A service client that records each update and the filters on it. */
function filterRecordingAdmin(writes: { table: string; patch: unknown; eq: [string, unknown][] }[]) {
  return {
    from: (table: string) => ({
      update: (patch: unknown) => {
        const write = { table, patch, eq: [] as [string, unknown][] };
        writes.push(write);
        const chain = {
          eq: (column: string, value: unknown) => {
            write.eq.push([column, value]);
            return chain;
          },
          then: (resolve: (v: unknown) => void) => resolve({ error: null }),
        };
        return chain;
      },
    }),
  };
}

Deno.test("a definitive refusal marks the intent failed only while it is still created", async () => {
  const writes: { table: string; patch: unknown; eq: [string, unknown][] }[] = [];
  const res = await orderFailure(filterRecordingAdmin(writes), "intent-1", "stripe", new ProviderRefusal(400));
  assertEquals(res.status, 502);
  assertEquals(writes, [{
    table: "payment_intents",
    patch: { status: "failed" },
    eq: [["id", "intent-1"], ["status", "created"]],
  }]);
});

Deno.test("an outcome that is not definitive writes nothing: the intent stays pending", async () => {
  for (const e of [new ProviderRefusal(409), new ProviderRefusal(503), new Error("socket reset")]) {
    const writes: { table: string; patch: unknown; eq: [string, unknown][] }[] = [];
    const res = await orderFailure(filterRecordingAdmin(writes), "intent-1", "stripe", e);
    assertEquals(res.status, 503);
    assertEquals(writes, []);
  }
});

/** A service client whose rpc records its calls and answers [data] and
 * [error]. */
function handOverAdmin(
  calls: { fn: string; args: unknown }[],
  data: unknown,
  error: { message: string } | null,
) {
  return {
    rpc: (fn: string, args: unknown) => {
      calls.push({ fn, args });
      return Promise.resolve({ data, error });
    },
  };
}

Deno.test("#3556 — the database hands the intent over before the provider is called", async () => {
  const calls: { fn: string; args: unknown }[] = [];
  const seen: number[] = [];
  const handed = await handedThen(
    handOverAdmin(calls, true, null),
    "intent-1",
    "stripe",
    () => {
      seen.push(calls.length);
      return Promise.resolve("order-1");
    },
  );
  assertEquals(handed, { ok: true, value: "order-1" });
  assertEquals(seen, [1], "the provider is called after the hand-over");
  assertEquals(calls, [{ fn: "hand_payment_intent", args: { p_intent: "intent-1" } }]);
});

Deno.test("#3556 — a claim the database will not hand over calls no provider and answers intent_stale", async () => {
  const calls: { fn: string; args: unknown }[] = [];
  let called = false;
  const handed = await handedThen(
    handOverAdmin(calls, false, null),
    "intent-1",
    "stripe",
    () => {
      called = true;
      return Promise.resolve("order-1");
    },
  );
  assertEquals(called, false);
  if (handed.ok) throw new Error("a refused hand-over must not hand over");
  assertEquals(handed.response.status, 409);
  assertEquals(await handed.response.json(), { error: "intent_stale", provider: "stripe" });
});

Deno.test("#3556 — a hand-over that cannot be asked calls no provider", async () => {
  const calls: { fn: string; args: unknown }[] = [];
  let called = false;
  const handed = await handedThen(
    handOverAdmin(calls, null, { message: "permission denied" }),
    "intent-1",
    "stripe",
    () => {
      called = true;
      return Promise.resolve("order-1");
    },
  );
  assertEquals(called, false);
  if (handed.ok) throw new Error("a failed hand-over must not hand over");
  assertEquals(handed.response.status, 500);
});

Deno.test("#3556 — a claim the database refuses is answered by its code, not as our failure", async () => {
  const refused = claimRefusal({ code: "DKC06" });
  assertEquals(refused?.status, 409);
  assertEquals(await refused?.json(), { error: "claim_refused", code: "DKC06" });
  assertEquals(claimRefusal({ code: "P0001" }), null, "another refusal stays a failure to open");
  assertEquals(claimRefusal(null), null);
});

/** A member of a production workspace with Stripe configured, as the
 * service client reads them, for [me]. */
function readyAdmin(me: string, read: string[]) {
  return recordingAdmin({
    members: { id: me, user_id: "user-1", workspace_id: "11111111-1111-4111-8111-111111111111", status: "active" },
    workspaces: { environment: "prod", currency_code: "EUR", name: "Atelier" },
    payment_credentials: {
      config: { secret_key: "sk_live_x", return_url: "https://r", webhook_secret: "whsec_x" },
    },
  }, read);
}

Deno.test("#3556 — a claim the database refuses answers 409 with its code and no provider is called", async () => {
  const me = "55555555-5555-4555-8555-555555555555";
  const calls: string[] = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = (input: RequestInfo | URL) => {
    calls.push(String(input));
    return Promise.resolve(Response.json({}));
  };
  try {
    const claimed = new Request("http://localhost/create-payment-order", {
      method: "POST",
      headers: { Authorization: "Bearer t" },
      body: JSON.stringify({
        workspace_id: "11111111-1111-4111-8111-111111111111",
        member_id: me,
        provider: "stripe",
        amount_cents: 1000,
        period: "2026-10",
        request_id: "22222222-2222-4222-8222-222222222222",
        invoice_ids: ["66666666-6666-4666-8666-666666666666"],
      }),
    });
    const opened: unknown[] = [];
    const res = await handleWith(claimed, readyAdmin(me, []), () => ({
      rpc: (fn: string, args: unknown) => {
        opened.push({ fn, args });
        return Promise.resolve({ data: null, error: { code: "DKC06", message: "already in a payment" } });
      },
    }));
    assertEquals(res.status, 409);
    assertEquals(await res.json(), { error: "claim_refused", code: "DKC06" });
    assertEquals(opened.length, 1, "the intent was asked for once");
    assertEquals(calls, [], "no provider was called");
  } finally {
    globalThis.fetch = realFetch;
  }
});

Deno.test("#3556 — the function says it takes a payment's claim", async () => {
  const me = "55555555-5555-4555-8555-555555555555";
  const probe = new Request("http://localhost/create-payment-order", {
    method: "POST",
    headers: { Authorization: "Bearer t" },
    body: JSON.stringify({
      workspace_id: "11111111-1111-4111-8111-111111111111",
      action: "config",
    }),
  });
  const res = await handleWith(probe, readyAdmin(me, []));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).claims, true);
});
