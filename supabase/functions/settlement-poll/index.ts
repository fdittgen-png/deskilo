// SPDX-License-Identifier: AGPL-3.0-or-later
//
// settlement-poll (#3510) -- the schedule's side of the Mollie settlements:
// what the on-demand fetch (mollie-settlements) does when a person asks, done
// hourly by the database (settlement_poll_tick, 0732) for every workspace
// with a Mollie key and online payments on.
//
// Who may call it: the database job, with the shared secret from Vault in
// `x-deskilo-poll-secret` (SETTLEMENT_POLL_SECRET here), or the exact
// service credential (an operator's manual run). Nothing else; a delegated
// token is refused first.
//
// One run claims the workspaces one at a time, each under a lease
// (settlement_poll_claim_v1), until none is due or the run's budget is
// spent; the rest wait for the next run. Each is read from where its last
// read stopped, at most MAX_PAGES pages; until the account's first full read
// has reached its end, a read goes on past settlements already recorded,
// afterwards it stops at the first page the recorder held whole. The result
// goes back with the lease (settlement_poll_finish_v1), which decides when
// the next attempt comes: a key Mollie refuses (4xx) is permanent and
// logged, the network, 429, 5xx and the database are retried.

import { refuseDelegated } from "../_shared/delegated.ts";
import { recorderOf, type ScanResult, scanSettlements } from "../_shared/mollie_settlements.ts";
import { mollieApi } from "../_shared/providers.ts";
import { sameSecret } from "../_shared/same_secret.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

export const POLL_SECRET_HEADER = "x-deskilo-poll-secret";
/** The most pages one workspace is read per run (50 a page). */
export const MAX_PAGES = 10;
/** The longest one call to Mollie may take before it counts as unreachable. */
export const CALL_TIMEOUT_MS = 15_000;
/** No workspace is claimed once a run has lasted this long. */
export const RUN_BUDGET_MS = 60_000;
/** A lease outlives the longest read it covers, so it never lapses under a
 * read still running; a run that died gives its workspaces back after it. */
export const LEASE_SECONDS = (MAX_PAGES * CALL_TIMEOUT_MS * 2) / 1000;

type Row = Record<string, unknown>;

export type Db = {
  rpc: (fn: string, args: Row) => PromiseLike<{ data: unknown; error: unknown }>;
};

export type Deps = {
  /** The service role: the claim, the recorder and the result. */
  service: () => Db;
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  now: () => number;
};

const defaultDeps: Deps = {
  service: () =>
    createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!) as unknown as Db,
  env: (name) => Deno.env.get(name),
  fetch: (input, init) => fetch(input, init),
  now: () => Date.now(),
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

/** The database job's secret, or the exact service credential. */
export function mayPoll(req: Request, secret: string | undefined, serviceKey: string | undefined): boolean {
  const sent = req.headers.get(POLL_SECRET_HEADER);
  if (secret && sent && sameSecret(sent, secret)) return true;
  const bearer = (req.headers.get("authorization") ?? "").match(/^Bearer\s+(.+)$/i)?.[1];
  return !!(serviceKey && bearer && sameSecret(bearer, serviceKey));
}

/** What settlement_poll_finish_v1 keeps of a read. */
export function resultOf(r: ScanResult): Row {
  return {
    complete: r.complete,
    continuation: r.continuation,
    new: r.new,
    unchanged: r.unchanged,
    pending: r.pending,
    rejected: r.rejected,
    refused: r.refused.length,
    pages: r.pages,
    failure: r.failure,
  };
}

type Claim = { workspace_id: string; backfilled: boolean; continuation: string | null; lease_token: string; api_key: string };

export async function handle(req: Request, deps: Deps = defaultDeps): Promise<Response> {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const delegated = refuseDelegated(req);
  if (delegated) return delegated;
  if (!mayPoll(req, deps.env("SETTLEMENT_POLL_SECRET"), deps.env("SUPABASE_SERVICE_ROLE_KEY"))) {
    return json({ error: "not allowed" }, 401);
  }
  const service = deps.service();
  const started = deps.now();
  const runStarted = new Date(started).toISOString();
  const read: Array<Row> = [];
  while (deps.now() - started < RUN_BUDGET_MS) {
    const claimed = await service.rpc("settlement_poll_claim_v1", {
      p_provider: "mollie",
      p_lease_seconds: LEASE_SECONDS,
      p_run_started: runStarted,
    });
    if (claimed.error) {
      console.error("settlement poll claim failed", String((claimed.error as Row).message ?? claimed.error));
      return json({ error: "claim_failed", read }, 500);
    }
    const one = ((claimed.data ?? []) as Claim[])[0];
    if (!one) break;
    const scan = await scanSettlements({
      fetch: deps.fetch,
      base: mollieApi(),
      key: one.api_key,
      from: one.continuation,
      maxPages: MAX_PAGES,
      callTimeoutMs: CALL_TIMEOUT_MS,
      stopWhenKnown: one.backfilled,
      record: recorderOf(service, one.workspace_id),
    });
    const result = resultOf(scan);
    const finished = await service.rpc("settlement_poll_finish_v1", {
      p_workspace_id: one.workspace_id,
      p_provider: "mollie",
      p_lease_token: one.lease_token,
      p_result: result,
    });
    if (finished.error || finished.data !== true) {
      // The lease ran out under this read: what it recorded stays recorded
      // (the recorder is idempotent), its continuation is not kept.
      console.error("settlement poll result not kept", {
        workspace: one.workspace_id,
        error: finished.error ? String((finished.error as Row).message ?? finished.error) : "lease lost",
      });
    }
    read.push({ workspace: one.workspace_id, ...result, kept: !finished.error && finished.data === true });
  }
  return json({ read });
}

if (import.meta.main) Deno.serve((req) => handle(req));
