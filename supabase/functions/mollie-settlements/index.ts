// SPDX-License-Identifier: AGPL-3.0-or-later
//
// mollie-settlements (#3504) — fetches a workspace's Mollie settlements ON
// DEMAND and records each paid one as a payout with the costs Mollie kept.
//
// Mollie reports fees and payouts on SETTLEMENTS (`/v2/settlements`: an
// amount, a `settledAt`, and `periods` whose `costs` are aggregated per
// method: a count and an amount net), not on the payment: no per-payment fee
// exists and none is invented. Each settlement goes to
// `record_provider_settlement_v1` (0700), idempotent and refusing another
// answer for a recorded one.
//
// Who: the caller's own token decides (`has_permission` manageBilling, and the
// `onlinePayments` flag on); the key is the workspace's OWN (payment_credentials) and is read by the
// service role only. There is no installation-wide fallback: /v2/settlements
// lists a whole Mollie account, so another tenant's key would import another
// tenant's payouts and costs; a workspace without a key gets 409. A 4xx from Mollie is permanent (422, nothing recorded); 429, 5xx
// and the network are transient (502).
//
// spec: docs.mollie.com "List settlements" / "Get settlement" — field names as
// documented, not verified against a live account.

import { refuseDelegated } from "../_shared/delegated.ts";
import { CORS, preflight } from "../_shared/cors.ts";
import { toMinor } from "../_shared/money.ts";
import { mollieApi } from "../_shared/providers.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

/** The most pages of settlements one request reads (50 a page). */
export const MAX_PAGES = 10;
/** The reports waiting for review that one answer lists, newest first. */
const REVIEWS_SHOWN = 50;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type Db = {
  rpc: (fn: string, args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: unknown }>;
  // deno-lint-ignore no-explicit-any
  from: (table: string) => any;
};

export type Deps = {
  /** A client bound to the caller's own token. */
  caller: (authorization: string) => Db;
  /** The service role: the key and the recorder only. */
  service: () => Db;
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
};

const defaultDeps: Deps = {
  caller: (authorization) =>
    createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authorization } },
    }) as unknown as Db,
  service: () =>
    createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!) as unknown as Db,
  env: (name) => Deno.env.get(name),
  fetch: (input, init) => fetch(input, init),
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

type Row = Record<string, unknown>;

type Cost = {
  period: string;
  method: string;
  description: string;
  cost_count: number;
  amount_net_cents: number;
  currency: string;
};

/** What `record_provider_settlement_v1` takes of one Mollie settlement, or
 * null when it is not a paid or failed one (open, pending) or malformed.
 * #3510: each cost keeps the currency Mollie gave it (the settlement's when
 * it names none); one in another currency is refused by the recorder and
 * kept for review, never relabelled here. */
export function settlementOf(s: Row): {
  id: string;
  cents: number;
  currency: string;
  arrival: string | null;
  status: "paid" | "failed";
  costs: Array<Cost>;
} | null {
  const status = s.status === "paidout" ? "paid" : s.status === "failed" ? "failed" : null;
  const amount = (s.amount ?? {}) as Row;
  const currency = String(amount.currency ?? "").toUpperCase();
  const cents = toMinor(amount.value as string | undefined, currency);
  const id = typeof s.id === "string" ? s.id : "";
  if (!status || !id || !currency || cents === null) return null;
  const settledAt = typeof s.settledAt === "string" ? s.settledAt : "";
  const costs: Array<Cost> = [];
  for (const [year, months] of Object.entries((s.periods ?? {}) as Row)) {
    for (const [month, period] of Object.entries((months ?? {}) as Row)) {
      for (const c of ((period as Row).costs ?? []) as Row[]) {
        const net = (c.amountNet ?? {}) as Row;
        const costCurrency = String(net.currency ?? currency).toUpperCase();
        const cost = toMinor(net.value as string | undefined, costCurrency);
        if (cost === null || !Number.isInteger(c.count)) return null;
        costs.push({
          period: `${year}-${month}`,
          method: typeof c.method === "string" ? c.method : "",
          description: typeof c.description === "string" ? c.description : "",
          cost_count: c.count as number,
          amount_net_cents: cost,
          currency: costCurrency,
        });
      }
    }
  }
  return { id, cents, currency, arrival: /^\d{4}-\d{2}-\d{2}/.test(settledAt) ? settledAt.slice(0, 10) : null, status, costs };
}

export async function handle(req: Request, deps: Deps = defaultDeps): Promise<Response> {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const delegated = refuseDelegated(req, CORS);
  if (delegated) return delegated;
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization) return json({ error: "not signed in" }, 401);
  let body: Row;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid body" }, 400);
  }
  const workspaceId = typeof body.workspace_id === "string" ? body.workspace_id : "";
  if (!UUID.test(workspaceId)) return json({ error: "workspace_id required" }, 400);

  const caller = deps.caller(authorization);
  const may = await caller.rpc("has_permission", { ws: workspaceId, perm: "manageBilling" });
  if (may.error || may.data !== true) return json({ error: "not allowed" }, 403);
  const on = await caller.rpc("feature_effective", { p_workspace_id: workspaceId, p_key: "onlinePayments" });
  if (on.error || on.data !== true) return json({ error: "online_payments_off" }, 409);

  const service = deps.service();
  // A failed credential read is not an absent key: it answers 5xx, never the
  // installation's key for a workspace that has its own (#2014).
  const cred = await service.from("payment_credentials").select("config")
    .eq("workspace_id", workspaceId).eq("provider", "mollie").maybeSingle();
  if (cred.error) return json({ error: "credential_lookup_failed" }, 500);
  const stored = (cred.data?.config ?? {}) as Record<string, string>;
  const key = stored.api_key || "";
  if (!key) return json({ error: "mollie_not_configured" }, 409);

  // #3510: counted from what the recorder decided, not from the calls made.
  let imported = 0;
  let unchanged = 0;
  let skipped = 0;
  const refused: Array<{ settlement: string; reason: string }> = [];
  let url: string | null = `${mollieApi()}/v2/settlements?limit=50`;
  for (let page = 0; page < MAX_PAGES && url; page++) {
    let res: Response;
    try {
      res = await deps.fetch(url, { headers: { Authorization: `Bearer ${key}` } });
    } catch (e) {
      console.error("mollie settlements read failed", String(e));
      return json({ error: "mollie_unreachable", imported }, 502);
    }
    if (res.status >= 400 && res.status < 500 && res.status !== 429) {
      console.error("mollie settlements refused", { status: res.status });
      return json({ error: "mollie_refused", status: res.status, imported }, 422);
    }
    if (!res.ok) return json({ error: "mollie_unreachable", status: res.status, imported }, 502);
    const list = (await res.json()) as Row;
    for (const s of ((list._embedded as Row | undefined)?.settlements ?? []) as Row[]) {
      const one = settlementOf(s);
      if (!one) {
        skipped++;
        continue;
      }
      const recorded = await service.rpc("record_provider_settlement_v1", {
        p_workspace_id: workspaceId,
        p_provider: "mollie",
        p_settlement_id: one.id,
        p_amount_cents: one.cents,
        p_currency: one.currency,
        p_arrival_date: one.arrival,
        p_status: one.status,
        p_costs: one.costs,
      });
      if (recorded.error) {
        console.error("mollie settlement record failed", String((recorded.error as Row).message ?? recorded.error));
        return json({ error: "settlement_record_failed", settlement: one.id, imported }, 500);
      }
      const outcome = ((recorded.data ?? {}) as Row).outcome;
      if (outcome === "unchanged") unchanged++;
      else if (outcome === "refused") {
        refused.push({ settlement: one.id, reason: String(((recorded.data ?? {}) as Row).reason ?? "") });
      } else imported++;
    }
    url = (((list._links as Row | undefined)?.next as Row | undefined)?.href as string | undefined) ?? null;
  }
  // Every report of this workspace's Mollie settlements that still waits for
  // a person (not handled, #3510): this run's refusals and the earlier ones. A failed read is said
  // (null), never an empty list.
  const waiting = await service.from("provider_settlement_reviews")
    .select("settlement_id, reason")
    .eq("workspace_id", workspaceId).eq("provider", "mollie")
    .is("handled_at", null)
    .order("last_reported_at", { ascending: false })
    .limit(REVIEWS_SHOWN);
  if (waiting.error) console.error("mollie settlement reviews read failed", String(waiting.error));
  return json({ imported, unchanged, skipped, refused, reviews: waiting.error ? null : waiting.data ?? [] });
}

if (import.meta.main) Deno.serve((req) => handle(req));
