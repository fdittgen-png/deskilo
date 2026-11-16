// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3917 -- PayPal's capture names the order PayPal made, which an intent whose
// provider answer was uncertain does not know yet. The order carries the
// intent's own id (custom_id): the capture finds the intent by it, the order
// is attached once PayPal has verified the event, and the capture is settled
// once. A custom id naming nothing that waits settles nothing and answers 200;
// an event PayPal does not verify attaches nothing.
import { assertEquals } from "jsr:@std/assert@1";
import { handle } from "./index.ts";

const INTENT = "00000000-0000-4000-8000-000000003917";

type Result = { data: unknown; error: { message: string } | null };

function fakeAdmin(provisional: Result) {
  const rpcCalls: string[] = [];
  const updates: Array<{ values: unknown; filters: string[] }> = [];
  const admin = {
    from(table: string) {
      const filters: string[] = [];
      let update: unknown = null;
      const result = (): Result => {
        if (table === "payment_credentials") {
          return {
            data: {
              config: {
                client_id: "c",
                secret: "s",
                env: "sandbox",
                webhook_id: "wh",
              },
            },
            error: null,
          };
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

const waiting = {
  data: {
    id: INTENT,
    order_id: "pending:x",
    workspace_id: "ws-1",
    amount_cents: 1250,
    currency: "EUR",
    reference: "PAY-2026-0001",
    status: "created",
  },
  error: null,
};

const capture = (customId: string) => ({
  event_type: "PAYMENT.CAPTURE.COMPLETED",
  resource: {
    id: "CAP-1",
    status: "COMPLETED",
    amount: { value: "12.50", currency_code: "EUR" },
    custom_id: customId,
    supplementary_data: { related_ids: { order_id: "O-LATE" } },
  },
});

async function call(
  fake: ReturnType<typeof fakeAdmin>,
  event: unknown,
  verified = "SUCCESS",
) {
  const req = new Request("http://x/paypal-webhook", {
    method: "POST",
    body: JSON.stringify(event),
  });
  const res = await handle(req, {
    // deno-lint-ignore no-explicit-any
    admin: () => fake.admin as any,
    env: () => undefined,
    fetch: (input) =>
      Promise.resolve(
        String(input).endsWith("/v1/oauth2/token")
          ? Response.json({ access_token: "t" })
          : Response.json({ verification_status: verified }),
      ),
    allowTest: () => true,
  });
  return res.status;
}

Deno.test("a capture naming an intent that waits for its order attaches it and settles once", async () => {
  const fake = fakeAdmin(waiting);
  assertEquals(await call(fake, capture(INTENT)), 200);
  assertEquals(fake.updates.length, 1);
  assertEquals(fake.updates[0].values, { order_id: "O-LATE" });
  assertEquals(fake.updates[0].filters, [
    `id=${INTENT}`,
    "order_id like pending:%",
  ]);
  assertEquals(fake.rpcCalls, ["settle_online_payment"]);
});

Deno.test("a custom id naming nothing that waits settles nothing and answers 200", async () => {
  const fake = fakeAdmin({ data: null, error: null });
  assertEquals(await call(fake, capture(INTENT)), 200);
  assertEquals(fake.updates, []);
  assertEquals(fake.rpcCalls, []);
});

Deno.test("an event PayPal does not verify attaches and settles nothing", async () => {
  const fake = fakeAdmin(waiting);
  assertEquals(await call(fake, capture(INTENT), "FAILURE"), 400);
  assertEquals(fake.updates, []);
  assertEquals(fake.rpcCalls, []);
});

Deno.test("an order made before this change (its custom id is the reference) names no intent", async () => {
  const fake = fakeAdmin(waiting);
  assertEquals(await call(fake, capture("PAY-2026-0001")), 200);
  assertEquals(fake.updates, []);
  assertEquals(fake.rpcCalls, []);
});
