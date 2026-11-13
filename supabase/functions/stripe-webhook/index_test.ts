// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2014 — the Stripe webhook answers truthfully: 2xx only when the event
// was handled or genuinely is not ours. A failed intent or credential
// lookup, a missing secret, a callback before the order id is stored and a
// failed mark-failed are 5xx so Stripe redelivers; an old unknown session
// is acknowledged (bounded retries). Settlement still needs a valid
// signature and `paid`.
import { assertEquals } from "jsr:@std/assert@1";
import { EARLY_CALLBACK_WINDOW_S, handle } from "./index.ts";

const NOW = 1_800_000_000;
const SECRET = "whsec_test";

type Result = { data: unknown; error: { message: string } | null };

function fakeAdmin(opts: {
  intent?: Result;
  credentials?: Result;
  rpc?: Record<string, Result>;
}) {
  const rpcCalls: string[] = [];
  const admin = {
    from(table: string) {
      const result = table === "payment_intents"
        ? opts.intent ?? { data: { workspace_id: "ws-1" }, error: null }
        : opts.credentials ??
          { data: { config: { webhook_secret: SECRET } }, error: null };
      const chain = {
        select: () => chain,
        eq: () => chain,
        maybeSingle: () => Promise.resolve(result),
      };
      return chain;
    },
    rpc(name: string) {
      rpcCalls.push(name);
      return Promise.resolve(opts.rpc?.[name] ?? { data: null, error: null });
    },
  };
  return { admin, rpcCalls };
}

async function signed(body: string, secret = SECRET, t = NOW) {
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" },
    false, ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${t}.${body}`));
  const hex = [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `t=${t},v1=${hex}`;
}

async function call(
  fake: ReturnType<typeof fakeAdmin>,
  event: Record<string, unknown>,
  env: Record<string, string> = {},
  fetchFn?: typeof fetch,
) {
  const body = JSON.stringify(event);
  const req = new Request("http://x/stripe-webhook", {
    method: "POST",
    body,
    headers: { "stripe-signature": await signed(body) },
  });
  // deno-lint-ignore no-explicit-any
  const res = await handle(req, { admin: () => fake.admin as any, env: (n) => env[n], nowS: () => NOW, fetch: fetchFn });
  return { status: res.status, text: await res.text() };
}

const paid = (type = "checkout.session.completed", created = NOW) => ({
  type,
  created,
  data: { object: { id: "cs_1", payment_status: "paid", amount_total: 1200, payment_intent: "pi_1" } },
});

Deno.test("a paid session settles once and answers ok", async () => {
  const fake = fakeAdmin({});
  assertEquals((await call(fake, paid())).status, 200);
  assertEquals(fake.rpcCalls, ["settle_online_payment"]);
});

Deno.test("an intent lookup failure is a 500, nothing settled", async () => {
  const fake = fakeAdmin({ intent: { data: null, error: { message: "timeout" } } });
  assertEquals((await call(fake, paid())).status, 500);
  assertEquals(fake.rpcCalls, []);
});

Deno.test("a callback before the order id is stored asks for a redelivery", async () => {
  const fake = fakeAdmin({ intent: { data: null, error: null } });
  assertEquals((await call(fake, paid())).status, 503);
  assertEquals(fake.rpcCalls, []);
});

Deno.test("an old unknown session is acknowledged: no endless retries", async () => {
  const fake = fakeAdmin({ intent: { data: null, error: null } });
  const old = paid("checkout.session.completed", NOW - EARLY_CALLBACK_WINDOW_S - 1);
  assertEquals((await call(fake, old)).status, 200);
});

Deno.test("a credential lookup failure is a 500, never the env fallback", async () => {
  const fake = fakeAdmin({ credentials: { data: null, error: { message: "down" } } });
  const res = await call(fake, paid(), { STRIPE_WEBHOOK_SECRET: SECRET });
  assertEquals(res.status, 500);
  assertEquals(fake.rpcCalls, []);
});

Deno.test("a deliberately absent workspace secret may use the installation's", async () => {
  const fake = fakeAdmin({ credentials: { data: null, error: null } });
  const res = await call(fake, paid(), { STRIPE_WEBHOOK_SECRET: SECRET });
  assertEquals(res.status, 200);
  assertEquals(fake.rpcCalls, ["settle_online_payment"]);
});

Deno.test("no secret anywhere: not consumed (503)", async () => {
  const fake = fakeAdmin({ credentials: { data: null, error: null } });
  assertEquals((await call(fake, paid())).status, 503);
  assertEquals(fake.rpcCalls, []);
});

Deno.test("a failed mark-failed is a 500, so the expiry is redelivered", async () => {
  const fake = fakeAdmin({ rpc: { mark_payment_failed: { data: null, error: { message: "x" } } } });
  const expired = { ...paid("checkout.session.expired"), data: { object: { id: "cs_1" } } };
  assertEquals((await call(fake, expired)).status, 500);
});

Deno.test("a settle failure stays a 500", async () => {
  const fake = fakeAdmin({ rpc: { settle_online_payment: { data: null, error: { message: "x" } } } });
  assertEquals((await call(fake, paid())).status, 500);
});

Deno.test("a bad signature is refused before anything is written", async () => {
  const fake = fakeAdmin({});
  const body = JSON.stringify(paid());
  const req = new Request("http://x", {
    method: "POST", body, headers: { "stripe-signature": await signed(body, "whsec_other") },
  });
  // deno-lint-ignore no-explicit-any
  const res = await handle(req, { admin: () => fake.admin as any, env: () => undefined, nowS: () => NOW });
  assertEquals(res.status, 400);
  assertEquals(fake.rpcCalls, []);
});

// #1863 C — replaces the source grep for `filter(([k]) => k === "v1")`.
// During a secret rollover Stripe sends one v1 per active secret; the
// valid one may come FIRST (a last-wins parse drops it) or last.
Deno.test("every v1 signature is tried: valid first or last, both settle", async () => {
  const body = JSON.stringify(paid());
  const good = (await signed(body)).split(",")[1];
  const other = (await signed(body, "whsec_old")).split(",")[1];
  for (const header of [`t=${NOW},${good},${other}`, `t=${NOW},${other},${good}`]) {
    const fake = fakeAdmin({});
    const req = new Request("http://x", { method: "POST", body, headers: { "stripe-signature": header } });
    // deno-lint-ignore no-explicit-any
    const res = await handle(req, { admin: () => fake.admin as any, env: () => undefined, nowS: () => NOW });
    assertEquals([res.status, fake.rpcCalls], [200, ["settle_online_payment"]], header);
  }
});

// #3093 E5 — every answer given before the signature is checked carries one
// body: an unsigned caller cannot tell the stage that refused.
Deno.test("the answers before verification all carry one body", async () => {
  const lookup = await call(
    fakeAdmin({ intent: { data: null, error: { message: "timeout" } } }),
    paid(),
  );
  const early = await call(fakeAdmin({ intent: { data: null, error: null } }), paid());
  const credentials = await call(
    fakeAdmin({ credentials: { data: null, error: { message: "down" } } }),
    paid(),
  );
  const unconfigured = await call(
    fakeAdmin({ credentials: { data: null, error: null } }),
    paid(),
  );
  const bodies = new Set([lookup, early, credentials, unconfigured].map((r) => r.text));
  assertEquals([...bodies], ["not_ready"]);
});

// #2380 -- what Stripe kept of a paid payment is recorded once, read from the
// balance transaction of the payment intent's latest charge (the issue's
// fixture: gross 120.00, fee 3.78, net 116.22).
const withKey = {
  credentials: { data: { config: { webhook_secret: SECRET, secret_key: "sk_test_1" } }, error: null },
};
const balanceTransaction = {
  id: "txn_1", object: "balance_transaction", amount: 12000, fee: 378, net: 11622, currency: "eur",
};
const stripeIntent = (bt: unknown) =>
  new Response(JSON.stringify({ id: "pi_1", latest_charge: { id: "ch_1", balance_transaction: bt } }), { status: 200 });

Deno.test("a paid session records the fee and net Stripe kept, once", async () => {
  const fake = fakeAdmin(withKey);
  const urls: string[] = [];
  const headers: string[] = [];
  const fetchFn: typeof fetch = (input, init) => {
    urls.push(String(input));
    headers.push(String((init?.headers as Record<string, string>)?.Authorization));
    return Promise.resolve(stripeIntent(balanceTransaction));
  };
  assertEquals((await call(fake, paid(), {}, fetchFn)).status, 200);
  assertEquals(fake.rpcCalls, ["settle_online_payment", "record_provider_fee_v1"]);
  assertEquals(urls, ["https://api.stripe.com/v1/payment_intents/pi_1?expand[]=latest_charge.balance_transaction"]);
  assertEquals(headers, ["Bearer sk_test_1"]);
});

Deno.test("a payment Stripe has no balance transaction for yet records nothing and is acknowledged", async () => {
  const fake = fakeAdmin(withKey);
  const res = await call(fake, paid(), {}, () => Promise.resolve(stripeIntent(null)));
  assertEquals(res.status, 200);
  assertEquals(fake.rpcCalls, ["settle_online_payment"]);
});

Deno.test("a failed Stripe read is a 500 after the settlement, so Stripe redelivers", async () => {
  const fake = fakeAdmin(withKey);
  const res = await call(fake, paid(), {}, () => Promise.resolve(new Response("{}", { status: 503 })));
  assertEquals(res.status, 500);
  assertEquals(res.text, "fee_read_failed");
  assertEquals(fake.rpcCalls, ["settle_online_payment"]);
});

for (const status of [403, 404]) {
  Deno.test(`a ${status} on the fee read (a key Stripe refuses) is logged and answered 2xx: no endless retries`, async () => {
    const fake = fakeAdmin(withKey);
    const res = await call(fake, paid(), {}, () => Promise.resolve(new Response("{}", { status })));
    assertEquals(res.status, 200);
    assertEquals(fake.rpcCalls, ["settle_online_payment"]);
  });
}

Deno.test("a 429 on the fee read is transient: 500, Stripe redelivers", async () => {
  const fake = fakeAdmin(withKey);
  const res = await call(fake, paid(), {}, () => Promise.resolve(new Response("{}", { status: 429 })));
  assertEquals(res.status, 500);
});

Deno.test("a network failure on the fee read is transient: 500", async () => {
  const fake = fakeAdmin(withKey);
  const res = await call(fake, paid(), {}, () => Promise.reject(new Error("socket")));
  assertEquals(res.status, 500);
  assertEquals(res.text, "fee_read_failed");
});

Deno.test("a fee the database refuses is a 500, never an ok", async () => {
  const fake = fakeAdmin({ ...withKey, rpc: { record_provider_fee_v1: { data: null, error: { message: "the provider reported another fee" } } } });
  const res = await call(fake, paid(), {}, () => Promise.resolve(stripeIntent(balanceTransaction)));
  assertEquals(res.status, 500);
  assertEquals(res.text, "fee_record_failed");
});

Deno.test("with no Stripe key the settlement stands and no fee is read", async () => {
  const fake = fakeAdmin({});
  let called = false;
  const res = await call(fake, paid(), {}, () => { called = true; return Promise.resolve(stripeIntent(balanceTransaction)); });
  assertEquals(res.status, 200);
  assertEquals(called, false);
  assertEquals(fake.rpcCalls, ["settle_online_payment"]);
});

// #2380 -- a payout event is routed to the payout path, never to the intent
// lookup that would ask Stripe to redeliver it for an hour.
Deno.test("a payout event signed by a workspace's secret is recorded, not looked up as a session", async () => {
  const rpcs: string[] = [];
  const admin = {
    from: () => {
      const chain = {
        select: () => chain,
        eq: () => Promise.resolve({ data: [{ workspace_id: "ws-1", config: { webhook_secret: SECRET, secret_key: "sk_t" } }], error: null }),
      };
      return chain;
    },
    rpc(name: string) { rpcs.push(name); return Promise.resolve({ data: { reconciled: true }, error: null }); },
  };
  const body = JSON.stringify({ type: "payout.paid", data: { object: { id: "po_1", amount: 1000, currency: "eur", arrival_date: 1773532800 } } });
  const req = new Request("http://x/stripe-webhook", { method: "POST", body, headers: { "stripe-signature": await signed(body) } });
  const res = await handle(req, {
    // deno-lint-ignore no-explicit-any
    admin: () => admin as any, env: () => undefined, nowS: () => NOW,
    fetch: () => Promise.resolve(new Response(JSON.stringify({ data: [{ id: "txn_1", type: "charge" }], has_more: false }), { status: 200 })),
  });
  assertEquals(res.status, 200);
  assertEquals(rpcs, ["record_provider_payout_v1"]);
});

Deno.test("a payout event nobody's secret signed is acknowledged, not retried", async () => {
  const admin = {
    from: () => {
      const chain = { select: () => chain, eq: () => Promise.resolve({ data: [], error: null }) };
      return chain;
    },
    rpc: () => Promise.resolve({ data: null, error: null }),
  };
  const body = JSON.stringify({ type: "payout.paid", data: { object: { id: "po_1", amount: 1000, currency: "eur" } } });
  const req = new Request("http://x/stripe-webhook", { method: "POST", body, headers: { "stripe-signature": await signed(body) } });
  // deno-lint-ignore no-explicit-any
  const res = await handle(req, { admin: () => admin as any, env: () => undefined, nowS: () => NOW });
  assertEquals(res.status, 200);
});

Deno.test("#3905 a test-mode event settles nothing in the ledger", async () => {
  const fake = fakeAdmin({});
  assertEquals((await call(fake, { ...paid(), livemode: false })).status, 200);
  assertEquals(fake.rpcCalls, []);
});
