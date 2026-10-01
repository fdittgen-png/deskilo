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
) {
  const body = JSON.stringify(event);
  const req = new Request("http://x/stripe-webhook", {
    method: "POST",
    body,
    headers: { "stripe-signature": await signed(body) },
  });
  // deno-lint-ignore no-explicit-any
  const res = await handle(req, { admin: () => fake.admin as any, env: (n) => env[n], nowS: () => NOW });
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
