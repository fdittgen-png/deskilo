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
import { recorderOf, scanSettlements } from "../_shared/mollie_settlements.ts";
import { mollieApi } from "../_shared/providers.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { describeError, logLine } from "../_shared/log.ts";
import { ok, refuse } from "../_shared/respond.ts";
import { guard } from "../_shared/serve.ts";
import { PROVIDER_CALL_TIMEOUT_MS } from "../_shared/limits.ts";

const FN = "mollie-settlements";

/** The most pages of settlements one request reads (50 a page). */
export const MAX_PAGES = 10; // not-mirrored: a run's own page budget against the provider
/** The longest one call to Mollie may take before it counts as unreachable. */
export const CALL_TIMEOUT_MS = PROVIDER_CALL_TIMEOUT_MS;
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


type Row = Record<string, unknown>;

export { settlementOf } from "../_shared/mollie_settlements.ts";

export async function handle(req: Request, deps: Deps = defaultDeps): Promise<Response> {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return refuse("method_not_allowed", 405);
  const delegated = refuseDelegated(req, CORS);
  if (delegated) return delegated;
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization) return refuse("not signed in", 401);
  let body: Row;
  try {
    body = await req.json();
  } catch {
    return refuse("invalid body", 400);
  }
  const workspaceId = typeof body.workspace_id === "string" ? body.workspace_id : "";
  if (!UUID.test(workspaceId)) return refuse("workspace_id required", 400);

  const caller = deps.caller(authorization);
  const may = await caller.rpc("has_permission", { ws: workspaceId, perm: "manageBilling" });
  if (may.error || may.data !== true) return refuse("not allowed", 403);
  const on = await caller.rpc("feature_effective", { p_workspace_id: workspaceId, p_key: "onlinePayments" });
  if (on.error || on.data !== true) return refuse("online_payments_off", 409);

  const service = deps.service();
  // A failed credential read is not an absent key: it answers 5xx, never the
  // installation's key for a workspace that has its own (#2014).
  const cred = await service.from("payment_credentials").select("config")
    .eq("workspace_id", workspaceId).eq("provider", "mollie").maybeSingle();
  if (cred.error) return refuse("credential_lookup_failed", 500);
  const stored = (cred.data?.config ?? {}) as Record<string, string>;
  const key = stored.api_key || "";
  if (!key) return refuse("mollie_not_configured", 409);

  // #3510: counted from what the recorder decided, not from the calls made;
  // the read is the schedule's (_shared/mollie_settlements.ts), from the
  // newest, at most MAX_PAGES.
  const read = await scanSettlements({
    fetch: deps.fetch,
    base: mollieApi(),
    key,
    from: null,
    maxPages: MAX_PAGES,
    callTimeoutMs: CALL_TIMEOUT_MS,
    stopWhenKnown: false,
    record: recorderOf(service, workspaceId),
  });
  const imported = read.new;
  switch (read.failure?.kind) {
    case "refused":
      return refuse("mollie_refused", 422, undefined, { status: read.failure.status, imported });
    case "unreachable":
      return refuse("mollie_unreachable", 502, undefined, { status: read.failure.status, imported });
    case "record_failed":
      return refuse("settlement_record_failed", 500, undefined, { settlement: read.failure.settlement, imported });
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
  if (waiting.error) logLine("error", FN, "reviews_read_failed", { error: describeError(waiting.error) });
  return ok({
    imported,
    unchanged: read.unchanged,
    skipped: read.pending + read.rejected,
    refused: read.refused,
    complete: read.complete,
    reviews: waiting.error ? null : waiting.data ?? [],
  });
}

/** The function as it is served: whatever [handle] throws is the envelope (#4412). */
export const serve = (deps: Deps = defaultDeps) => guard(FN, (req) => handle(req, deps));

if (import.meta.main) Deno.serve(serve());
