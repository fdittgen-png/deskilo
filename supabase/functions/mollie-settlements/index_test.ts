// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3504 -- Mollie settlements fetched on demand: each paid one becomes a payout
// with the costs Mollie kept, once; who may ask; a refused key is permanent, a
// transient failure is retried.
import { assertEquals } from "jsr:@std/assert@1";
import { handle, settlementOf } from "./index.ts";

const WS = "00000000-0000-4000-8000-000000000001";

type R = { data: unknown; error: unknown };

function fakes(opts: { may?: R; on?: R; config?: R; rpc?: R } = {}) {
  const recorded: Array<Record<string, unknown>> = [];
  const caller = {
    rpc: (fn: string) => Promise.resolve(fn === "has_permission"
      ? opts.may ?? { data: true, error: null }
      : opts.on ?? { data: true, error: null }),
    from: () => ({}),
  };
  const service = {
    rpc: (_fn: string, args: Record<string, unknown>) => {
      recorded.push(args);
      return Promise.resolve(opts.rpc ?? { data: { costs_added: 1 }, error: null });
    },
    from: () => {
      const chain = {
        select: () => chain,
        eq: () => chain,
        maybeSingle: () => Promise.resolve(opts.config ?? { data: { config: { api_key: "test_key" } }, error: null }),
      };
      return chain;
    },
  };
  return { caller, service, recorded };
}

const settlement = (over: Record<string, unknown> = {}) => ({
  id: "stl_1",
  status: "paidout",
  settledAt: "2026-03-15T08:00:00+00:00",
  amount: { currency: "EUR", value: "340.00" },
  periods: {
    "2026": {
      "03": {
        costs: [
          { description: "iDEAL", method: "ideal", count: 3, amountNet: { currency: "EUR", value: "1.20" } },
          { description: "Credit card", method: "creditcard", count: 1, amountNet: { currency: "EUR", value: "0.55" } },
        ],
      },
    },
  },
  ...over,
});

const page = (settlements: unknown[], next?: string) =>
  new Response(JSON.stringify({ _embedded: { settlements }, _links: { next: next ? { href: next } : null } }), { status: 200 });

const call = (
  f: ReturnType<typeof fakes>,
  fetchFn: typeof fetch,
  body: unknown = { workspace_id: WS },
  auth: string | null = "Bearer tok",
) =>
  handle(
    new Request("http://x", { method: "POST", body: JSON.stringify(body), headers: auth ? { Authorization: auth } : {} }),
    // deno-lint-ignore no-explicit-any
    { caller: () => f.caller as any, service: () => f.service as any, env: () => undefined, fetch: fetchFn },
  );

Deno.test("a paid settlement is recorded as a payout with its period costs, once per settlement", async () => {
  const f = fakes();
  const urls: string[] = [];
  const res = await call(f, (input, init) => {
    urls.push(String(input));
    assertEquals((init?.headers as Record<string, string>).Authorization, "Bearer test_key");
    return Promise.resolve(page([settlement(), settlement({ id: "stl_open", status: "open" })]));
  });
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { imported: 1, skipped: 1 });
  assertEquals(urls, ["https://api.mollie.com/v2/settlements?limit=50"]);
  assertEquals(f.recorded[0], {
    p_workspace_id: WS, p_provider: "mollie", p_settlement_id: "stl_1", p_amount_cents: 34000, p_currency: "EUR",
    p_arrival_date: "2026-03-15", p_status: "paid",
    p_costs: [
      { period: "2026-03", method: "ideal", description: "iDEAL", cost_count: 3, amount_net_cents: 120 },
      { period: "2026-03", method: "creditcard", description: "Credit card", cost_count: 1, amount_net_cents: 55 },
    ],
  });
});

Deno.test("the settlements are read page after page", async () => {
  const f = fakes();
  const urls: string[] = [];
  const res = await call(f, (input) => {
    urls.push(String(input));
    return Promise.resolve(urls.length === 1 ? page([settlement()], "https://api.mollie.com/v2/settlements?from=stl_1") : page([settlement({ id: "stl_2" })]));
  });
  assertEquals((await res.json()).imported, 2);
  assertEquals(urls[1], "https://api.mollie.com/v2/settlements?from=stl_1");
});

Deno.test("who may ask: a caller without the billing right, with online payments off, signed out", async () => {
  const noFetch = () => Promise.reject(new Error("must not call Mollie"));
  assertEquals((await call(fakes({ may: { data: false, error: null } }), noFetch)).status, 403);
  assertEquals((await call(fakes({ on: { data: false, error: null } }), noFetch)).status, 409);
  assertEquals((await call(fakes(), noFetch, { workspace_id: WS }, null)).status, 401);
  assertEquals((await call(fakes(), noFetch, { workspace_id: "x" })).status, 400);
});

Deno.test("a key Mollie refuses is permanent (422, nothing recorded); a transient failure is 502", async () => {
  const f = fakes();
  assertEquals((await call(f, () => Promise.resolve(new Response("{}", { status: 401 })))).status, 422);
  assertEquals(f.recorded, []);
  assertEquals((await call(fakes(), () => Promise.resolve(new Response("{}", { status: 503 })))).status, 502);
  assertEquals((await call(fakes(), () => Promise.resolve(new Response("{}", { status: 429 })))).status, 502);
  assertEquals((await call(fakes(), () => Promise.reject(new Error("socket")))).status, 502);
});

Deno.test("no key, a failed credential read, and a refused record", async () => {
  assertEquals((await call(fakes({ config: { data: null, error: null } }), () => Promise.resolve(page([])))).status, 409);
  assertEquals((await call(fakes({ config: { data: null, error: { message: "down" } } }), () => Promise.resolve(page([])))).status, 500);
  const refused = await call(
    fakes({ rpc: { data: null, error: { message: "the provider reported other costs for this settlement" } } }),
    () => Promise.resolve(page([settlement()])),
  );
  assertEquals(refused.status, 500);
});

Deno.test("no workspace key + an installation MOLLIE_API_KEY → 409, Mollie is never called", async () => {
  const f = fakes({ config: { data: null, error: null } });
  let fetched = 0;
  const res = await handle(
    new Request("http://x", { method: "POST", body: JSON.stringify({ workspace_id: WS }), headers: { Authorization: "Bearer tok" } }),
    {
      // deno-lint-ignore no-explicit-any
      caller: () => f.caller as any, service: () => f.service as any,
      env: (k: string) => (k === "MOLLIE_API_KEY" ? "test_installation_key" : undefined),
      fetch: () => { fetched++; return Promise.resolve(page([settlement()])); },
    },
  );
  assertEquals(res.status, 409);
  assertEquals((await res.json()).error, "mollie_not_configured");
  assertEquals(fetched, 0);
});

Deno.test("what is not a paid or failed settlement, or is malformed, is not recorded", () => {
  assertEquals(settlementOf({ id: "stl_x", status: "pending", amount: { currency: "EUR", value: "1.00" } }), null);
  assertEquals(settlementOf({ id: "stl_x", status: "paidout", amount: { currency: "EUR", value: "oops" } }), null);
  assertEquals(settlementOf({ status: "paidout", amount: { currency: "EUR", value: "1.00" } }), null);
  assertEquals(settlementOf(settlement({ status: "failed" }))?.status, "failed");
});
