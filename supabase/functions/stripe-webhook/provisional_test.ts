// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3917 -- an intent whose provider answer was uncertain keeps a provisional
// order id. The session's notification names the intent (metadata), finds it,
// attaches the session once the signature proves the event genuine, and
// settles or ends it on that session through the paths every notification
// uses. The order request's own late write wins; a redelivery takes the
// known-session path; an event that is forged, in test mode, or names an
// intent holding another session attaches nothing.
import { assertEquals } from "jsr:@std/assert@1";
import { handle } from "./index.ts";
import { intentsFake } from "../_shared/testing/intents_fake.ts";

const NOW = 1_800_000_000;
const SECRET = "whsec_test";
const INTENT = "00000000-0000-4000-8000-000000003917";

const waiting = (orderId = "pending:3917") => [{
  id: INTENT,
  provider: "stripe",
  order_id: orderId,
  workspace_id: "ws-1",
  status: "created",
}];

const fake = (opts: Partial<Parameters<typeof intentsFake>[0]> = {}) =>
  intentsFake({
    rows: waiting(),
    credentials: { webhook_secret: SECRET },
    ...opts,
  });

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
  f: ReturnType<typeof intentsFake>,
  opts: {
    metadata?: unknown;
    secret?: string;
    type?: string;
    livemode?: boolean;
    created?: number;
  } = {},
) {
  const body = JSON.stringify({
    type: opts.type ?? "checkout.session.completed",
    created: opts.created ?? NOW,
    livemode: opts.livemode ?? true,
    data: {
      object: {
        id: "cs_late",
        payment_status: opts.type === "checkout.session.expired"
          ? "unpaid"
          : "paid",
        amount_total: 1200,
        payment_intent: "pi_1",
        metadata: opts.metadata === undefined
          ? { deskilo_intent: INTENT }
          : opts.metadata,
      },
    },
  });
  const req = new Request("http://x/stripe-webhook", {
    method: "POST",
    body,
    headers: {
      "stripe-signature": await signature(body, opts.secret ?? SECRET),
    },
  });
  const res = await handle(req, {
    admin: () => f.admin,
    env: () => undefined,
    nowS: () => NOW,
  });
  return res.status;
}

const settled = (f: ReturnType<typeof intentsFake>) =>
  f.rpcCalls.filter((c) => c.name === "settle_online_payment").map((
    c,
  ) => [c.args.p_provider, c.args.p_order_id]);

Deno.test("a session naming an intent that waits for its order attaches it and settles on it", async () => {
  const f = fake();
  assertEquals(await call(f), 200);
  assertEquals(f.rows[0].order_id, "cs_late");
  assertEquals(settled(f), [["stripe", "cs_late"]]);
});

Deno.test("the order request's late write before the provisional read: found by the session, nothing attached", async () => {
  const f = fake({ afterRead: (rows) => (rows[0].order_id = "cs_late") });
  assertEquals(await call(f), 200);
  assertEquals(settled(f), [["stripe", "cs_late"]]);
});

Deno.test("the order request's late write before the attach: the attach changes no row and the event settles on the stored session", async () => {
  const f = fake({
    afterRead: (rows) => (rows[0].order_id = "cs_late"),
    afterReadAt: 2,
  });
  assertEquals(await call(f), 200);
  assertEquals(f.rows[0].order_id, "cs_late");
  assertEquals(settled(f), [["stripe", "cs_late"]]);
});

Deno.test("a redelivery after the attach takes the known-session path", async () => {
  const f = fake();
  await call(f);
  const readsBefore = f.reads;
  assertEquals(await call(f), 200);
  assertEquals(f.reads - readsBefore, 1, "one read, by the session");
  assertEquals(
    settled(f),
    [["stripe", "cs_late"], ["stripe", "cs_late"]],
    "the database credits it once",
  );
});

Deno.test("an expired session after the attach ends the intent on it", async () => {
  const f = fake();
  assertEquals(await call(f, { type: "checkout.session.expired" }), 200);
  assertEquals(
    f.rpcCalls.map((c) => [c.name, c.args.p_provider, c.args.p_order_id]),
    [["mark_payment_failed", "stripe", "cs_late"]],
  );
});

Deno.test("an intent holding another session: nothing attached, the event falls to the age window as before", async () => {
  const f = fake({ rows: waiting("cs_other") });
  assertEquals(await call(f), 503, "within the window, a redelivery is asked");
  assertEquals(
    await call(f, { created: NOW - 7200 }),
    200,
    "after it, acknowledged",
  );
  assertEquals(f.rows[0].order_id, "cs_other");
  assertEquals(f.rpcCalls, []);
});

Deno.test("a forged session attaches nothing: the signature is checked first", async () => {
  const f = fake();
  assertEquals(await call(f, { secret: "whsec_other" }), 400);
  assertEquals(f.rows[0].order_id, "pending:3917");
  assertEquals(f.rpcCalls, []);
});

Deno.test("a test-mode session attaches nothing where the installation takes no test payments", async () => {
  const f = fake();
  assertEquals(await call(f, { livemode: false }), 200);
  assertEquals(f.rows[0].order_id, "pending:3917");
  assertEquals(f.rpcCalls, []);
});

Deno.test("a metadata value that is not an intent id names nothing", async () => {
  const f = fake();
  assertEquals(
    await call(f, { metadata: { deskilo_intent: "PAY-2026-0001" } }),
    503,
  );
  assertEquals(f.rows[0].order_id, "pending:3917");
  assertEquals(f.rpcCalls, []);
});
