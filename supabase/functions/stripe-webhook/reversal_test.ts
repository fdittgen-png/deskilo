// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3905 -- a dispute or a refund at Stripe marks its online payment reversed:
// the checkout session is found from the charge's payment intent with the key
// of the workspace whose own secret signed the event. A charge of no session of
// ours, an event no workspace signed and a test-mode event record nothing and
// are acknowledged; a transient read failure asks for a redelivery.
import { assertEquals } from "jsr:@std/assert@1";
import { handleReversal, isReversalEvent } from "./reversal.ts";

const SECRET = "whsec_ws1";

type Result = { data: unknown; error: { message: string } | null };

function fakeAdmin(opts: { credentials?: Result; rpc?: Result } = {}) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const admin = {
    from() {
      const chain = {
        select: () => chain,
        eq: () =>
          Promise.resolve(
            opts.credentials ?? {
              data: [
                { workspace_id: "ws-other", config: { webhook_secret: "whsec_other", secret_key: "sk_live_other" } },
                { workspace_id: "ws-1", config: { webhook_secret: SECRET, secret_key: "sk_live_1" } },
              ],
              error: null,
            },
          ),
      };
      return chain;
    },
    rpc(name: string, args: Record<string, unknown>) {
      calls.push({ name, args });
      return Promise.resolve(opts.rpc ?? { data: null, error: null });
    },
  };
  return { admin, calls };
}

const dispute = (over: Record<string, unknown> = {}) => ({
  type: "charge.dispute.created",
  livemode: true,
  data: { object: { id: "dp_1", object: "dispute", charge: "ch_1", payment_intent: "pi_1" } },
  ...over,
});

const sessions = (ids: string[], status = 200) => () =>
  Promise.resolve(new Response(JSON.stringify({ data: ids.map((id) => ({ id })) }), { status }));

const run = (fake: ReturnType<typeof fakeAdmin>, event: Record<string, unknown>, fetchFn: typeof fetch, secret = SECRET) =>
  handleReversal(
    event,
    (s) => Promise.resolve(s === secret),
    // deno-lint-ignore no-explicit-any
    { admin: () => fake.admin as any, fetch: fetchFn },
  );

Deno.test("the reversal event types recorded", () => {
  for (const t of ["charge.dispute.created", "charge.refunded"]) assertEquals(isReversalEvent(t), true);
  for (const t of ["charge.succeeded", "checkout.session.completed", "payout.paid", undefined]) {
    assertEquals(isReversalEvent(t), false);
  }
});

Deno.test("a dispute marks the payment of its checkout session reversed, with the signing workspace's key", async () => {
  const fake = fakeAdmin();
  const seen: Array<{ url: string; key: string }> = [];
  const fetchFn = ((url: string, init?: RequestInit) => {
    seen.push({ url, key: String((init?.headers as Record<string, string>)?.Authorization ?? "") });
    return sessions(["cs_1"])();
  }) as unknown as typeof fetch;
  const res = await run(fake, dispute(), fetchFn);
  assertEquals(res.status, 200);
  assertEquals(seen.length, 1);
  assertEquals(seen[0].url.includes("payment_intent=pi_1"), true);
  assertEquals(seen[0].key, "Bearer sk_live_1");
  assertEquals(fake.calls, [{
    name: "mark_payment_reversed",
    args: { p_provider: "stripe", p_order_id: "cs_1", p_reason: "charge.dispute.created" },
  }]);
});

Deno.test("a refund made at Stripe marks the payment reversed", async () => {
  const fake = fakeAdmin();
  const event = { type: "charge.refunded", livemode: true, data: { object: { id: "ch_1", object: "charge", payment_intent: "pi_1" } } };
  assertEquals((await run(fake, event, sessions(["cs_1"]) as unknown as typeof fetch)).status, 200);
  assertEquals(fake.calls.map((c) => c.args.p_order_id), ["cs_1"]);
});

Deno.test("a charge of no session of ours records nothing and is acknowledged", async () => {
  const fake = fakeAdmin();
  assertEquals((await run(fake, dispute(), sessions([]) as unknown as typeof fetch)).status, 200);
  assertEquals(fake.calls, []);
});

Deno.test("an event no workspace signed records nothing and is acknowledged", async () => {
  const fake = fakeAdmin();
  assertEquals((await run(fake, dispute(), sessions(["cs_1"]) as unknown as typeof fetch, "whsec_nobody")).status, 200);
  assertEquals(fake.calls, []);
});

Deno.test("a test-mode reversal records nothing", async () => {
  const fake = fakeAdmin();
  assertEquals((await run(fake, dispute({ livemode: false }), sessions(["cs_1"]) as unknown as typeof fetch)).status, 200);
  assertEquals(fake.calls, []);
});

Deno.test("a transient session read failure asks for a redelivery", async () => {
  const fake = fakeAdmin();
  assertEquals((await run(fake, dispute(), sessions([], 503) as unknown as typeof fetch)).status, 500);
  assertEquals(fake.calls, []);
});
