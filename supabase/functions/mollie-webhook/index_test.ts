// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3917 -- Mollie posts only a payment id. An intent whose provider answer
// was uncertain does not know it yet, so the webhook address names the
// intent; the payment is attached and settled once only when Mollie, asked
// with the business's own key, shows that the payment carries that intent.
// An address that names nothing waiting, a payment that carries another
// intent, or an unreachable Mollie attaches and settles nothing.
import { assertEquals } from "jsr:@std/assert@1";
import { handle } from "./index.ts";

const INTENT = "00000000-0000-4000-8000-000000003917";
const KEY = "live_businesskey";

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
          return { data: { config: { api_key: KEY } }, error: null };
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
    workspace_id: "ws-1",
    provider: "mollie",
    amount_cents: 1250,
    currency: "EUR",
    reference: "PAY-2026-0001",
  },
  error: null,
};

const payment = (metadata: Record<string, unknown>) => ({
  id: "tr_late",
  status: "paid",
  mode: "live",
  amount: { value: "12.50", currency: "EUR" },
  metadata,
});

async function call(
  fake: ReturnType<typeof fakeAdmin>,
  query: string,
  answer: () => Promise<Response>,
) {
  const fetched: string[] = [];
  const req = new Request(`http://x/mollie-webhook${query}`, {
    method: "POST",
    body: new URLSearchParams({ id: "tr_late" }),
    headers: { "content-type": "application/x-www-form-urlencoded" },
  });
  const res = await handle(req, {
    // deno-lint-ignore no-explicit-any
    admin: () => fake.admin as any,
    env: () => undefined,
    fetch: (input) => {
      fetched.push(String(input));
      return answer();
    },
    allowTest: () => false,
  });
  return { status: res.status, fetched };
}

Deno.test("a payment whose intent waits for it is attached and settled once", async () => {
  const fake = fakeAdmin(waiting);
  const { status, fetched } = await call(
    fake,
    `?intent=${INTENT}`,
    () =>
      Promise.resolve(
        Response.json(
          payment({ reference: "PAY-2026-0001", deskilo_intent: INTENT }),
        ),
      ),
  );
  assertEquals(status, 200);
  assertEquals(
    fetched.length,
    1,
    "Mollie is asked with the business's own key",
  );
  assertEquals(fake.updates.length, 1);
  assertEquals(fake.updates[0].values, { order_id: "tr_late" });
  assertEquals(fake.updates[0].filters, [
    `id=${INTENT}`,
    "order_id like pending:%",
  ]);
  assertEquals(fake.rpcCalls, ["settle_online_payment"]);
});

Deno.test("an address naming nothing that waits settles nothing and answers 200", async () => {
  const fake = fakeAdmin({ data: null, error: null });
  const { status, fetched } = await call(
    fake,
    `?intent=${INTENT}`,
    () => Promise.resolve(Response.json(payment({ deskilo_intent: INTENT }))),
  );
  assertEquals(status, 200);
  assertEquals(fetched, []);
  assertEquals(fake.updates, []);
  assertEquals(fake.rpcCalls, []);
});

Deno.test("a payment that does not carry the named intent attaches and settles nothing", async () => {
  const fake = fakeAdmin(waiting);
  const { status } = await call(
    fake,
    `?intent=${INTENT}`,
    () =>
      Promise.resolve(Response.json(payment({ reference: "PAY-2026-0001" }))),
  );
  assertEquals(status, 200);
  assertEquals(fake.updates, []);
  assertEquals(fake.rpcCalls, []);
});

Deno.test("an unreachable Mollie changes nothing and is retried", async () => {
  const fake = fakeAdmin(waiting);
  const { status } = await call(
    fake,
    `?intent=${INTENT}`,
    () => Promise.reject(new TypeError("connection reset")),
  );
  assertEquals(status, 500);
  assertEquals(fake.updates, []);
  assertEquals(fake.rpcCalls, []);
});
