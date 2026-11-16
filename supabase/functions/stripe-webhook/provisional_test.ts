// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3917 -- an intent whose provider answer was uncertain keeps a provisional
// order id. The session's notification names the intent (metadata), finds it,
// attaches the session once the signature proves the event genuine, and
// settles it through the one exactly-once path. A session that names an
// intent waiting for no order settles nothing and is acknowledged; a forged
// one attaches nothing.
import { assertEquals } from "jsr:@std/assert@1";
import { handle } from "./index.ts";

const NOW = 1_800_000_000;
const SECRET = "whsec_test";
const INTENT = "00000000-0000-4000-8000-000000003917";

type Result = { data: unknown; error: { message: string } | null };

/** payment_intents answers by the column a query filters on: an order id
 * the server does not know, and [provisional] for the intent's own id. */
function fakeAdmin(provisional: Result) {
  const rpcCalls: string[] = [];
  const updates: Array<{ values: unknown; filters: string[] }> = [];
  const admin = {
    from(table: string) {
      const filters: string[] = [];
      let update: unknown = null;
      const result = (): Result => {
        if (table !== "payment_intents") {
          return { data: { config: { webhook_secret: SECRET } }, error: null };
        }
        if (filters.some((f) => f.startsWith("id="))) return provisional;
        return { data: null, error: null };
      };
      const chain = {
        select: () => chain,
        update: (values: unknown) => {
          update = values;
          return chain;
        },
        eq: (c: string, v: unknown) => {
          filters.push(`${c}=${v}`);
          return chain;
        },
        in: (c: string, v: unknown) => {
          filters.push(`${c} in ${v}`);
          return chain;
        },
        // deno-lint-ignore no-explicit-any
        like: (c: string, v: unknown): any => {
          filters.push(`${c} like ${v}`);
          if (!update) return chain;
          updates.push({ values: update, filters: [...filters] });
          return Promise.resolve({ data: null, error: null });
        },
        maybeSingle: () => Promise.resolve(result()),
      };
      return chain;
    },
    rpc(name: string) {
      rpcCalls.push(name);
      return Promise.resolve({ data: null, error: null });
    },
  };
  return { admin, rpcCalls, updates };
}

async function signature(body: string, secret: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${NOW}.${body}`),
  );
  const hex = [...new Uint8Array(mac)].map((b) =>
    b.toString(16).padStart(2, "0")
  ).join("");
  return `t=${NOW},v1=${hex}`;
}

async function call(
  fake: ReturnType<typeof fakeAdmin>,
  metadata: unknown,
  secret = SECRET,
) {
  const body = JSON.stringify({
    type: "checkout.session.completed",
    created: NOW,
    data: {
      object: {
        id: "cs_late",
        payment_status: "paid",
        amount_total: 1200,
        payment_intent: "pi_1",
        metadata,
      },
    },
  });
  const req = new Request("http://x/stripe-webhook", {
    method: "POST",
    body,
    headers: { "stripe-signature": await signature(body, secret) },
  });
  // deno-lint-ignore no-explicit-any
  const res = await handle(req, {
    admin: () => fake.admin as any,
    env: () => undefined,
    nowS: () => NOW,
  });
  return res.status;
}

Deno.test("a session naming an intent that waits for its order attaches it and settles once", async () => {
  const fake = fakeAdmin({
    data: { id: INTENT, workspace_id: "ws-1" },
    error: null,
  });
  assertEquals(await call(fake, { deskilo_intent: INTENT }), 200);
  assertEquals(fake.updates.length, 1);
  assertEquals(fake.updates[0].values, { order_id: "cs_late" });
  assertEquals(fake.updates[0].filters, [
    `id=${INTENT}`,
    "order_id like pending:%",
  ]);
  assertEquals(fake.rpcCalls, ["settle_online_payment"]);
});

Deno.test("a session naming an intent that waits for no order settles nothing and answers 200", async () => {
  const fake = fakeAdmin({ data: null, error: null });
  assertEquals(await call(fake, { deskilo_intent: INTENT }), 200);
  assertEquals(fake.updates, []);
  assertEquals(fake.rpcCalls, []);
});

Deno.test("a forged session attaches nothing: the signature is checked first", async () => {
  const fake = fakeAdmin({
    data: { id: INTENT, workspace_id: "ws-1" },
    error: null,
  });
  assertEquals(
    await call(fake, { deskilo_intent: INTENT }, "whsec_other"),
    400,
  );
  assertEquals(fake.updates, []);
  assertEquals(fake.rpcCalls, []);
});

Deno.test("a metadata value that is not an intent id names nothing", async () => {
  const fake = fakeAdmin({
    data: { id: INTENT, workspace_id: "ws-1" },
    error: null,
  });
  // Within the early-callback window an unknown session still asks for a
  // redelivery, as before: nothing is attached or settled.
  assertEquals(await call(fake, { deskilo_intent: "PAY-2026-0001" }), 503);
  assertEquals(fake.updates, []);
  assertEquals(fake.rpcCalls, []);
});
