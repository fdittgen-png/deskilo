// SPDX-License-Identifier: AGPL-3.0-or-later
//
// payment-reconcile (#4126) -- the attempts left open with a provider's order,
// asked of their provider once older than its lifetime of an unpaid order
// (payment_reconciliation_tick, 0798, hourly).
//
// Who may call it: the database job, with the shared secret from Vault in
// `x-deskilo-reconcile-secret` (PAYMENT_RECONCILE_SECRET here), or the exact
// service credential (an operator's manual run). Nothing else; a delegated
// token is refused first.
//
// One run claims the businesses one at a time, each under a lease
// (payment_reconciliation_claim_v1), until none is due or the run's budget is
// spent. Each attempt is read with the business's stored credentials
// (readers.ts) and the answer applied through the notifications' own paths:
// settle_online_payment, which credits once whoever comes first, or
// mark_payment_failed. An attempt the provider still calls pending is left;
// one whose order is still the provisional id of an uncertain answer was never
// given a way to pay and is ended without asking, counted apart (a late
// notification still credits it once, #3917);
// one that cannot be read is left too and named with its reason in the run's
// record (payment_reconciliation_finish_v1).

import { refuseDelegated } from "../_shared/delegated.ts";
import { sameSecret } from "../_shared/same_secret.ts";
import { allowsTestPayments } from "../_shared/test_payments.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  type Decision,
  type OpenIntent,
  readerOf,
  type UnreadableReason,
} from "./readers.ts";
import { describeError, logLine } from "../_shared/log.ts";
import { ok, refuse } from "../_shared/respond.ts";
import { guard } from "../_shared/serve.ts";
import { PROVIDER_CALL_TIMEOUT_MS } from "../_shared/limits.ts";

const FN = "payment-reconcile";

export const RECONCILE_SECRET_HEADER = "x-deskilo-reconcile-secret";
/** The most attempts of one business read per run. */
export const MAX_INTENTS = 50; // not-mirrored: a run's own batch size
/** The longest one call to a provider may take before it counts as unreachable. */
export const CALL_TIMEOUT_MS = PROVIDER_CALL_TIMEOUT_MS;
/** No business is claimed once a run has lasted this long. */
export const RUN_BUDGET_MS = 60_000;
/** A lease outlives the longest read it covers (a PayPal read is two calls). */
export const LEASE_SECONDS = (MAX_INTENTS * CALL_TIMEOUT_MS * 2) / 1000;

type Row = Record<string, unknown>;

export type Db = {
  rpc: (
    fn: string,
    args: Row,
  ) => PromiseLike<{ data: unknown; error: unknown }>;
  // deno-lint-ignore no-explicit-any
  from: (table: string) => any;
};

export type Deps = {
  /** The service role: the claim, the credentials, the settlement, the record. */
  service: () => Db;
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  now: () => number;
};

const defaultDeps: Deps = {
  service: () =>
    createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    ) as unknown as Db,
  env: (name) => Deno.env.get(name),
  fetch: (input, init) => fetch(input, init),
  now: () => Date.now(),
};


/** The database job's secret, or the exact service credential. */
export function mayReconcile(
  req: Request,
  secret: string | undefined,
  serviceKey: string | undefined,
): boolean {
  const sent = req.headers.get(RECONCILE_SECRET_HEADER);
  if (secret && sent && sameSecret(sent, secret)) return true;
  const bearer = (req.headers.get("authorization") ?? "").match(
    /^Bearer\s+(.+)$/i,
  )?.[1];
  return !!(serviceKey && bearer && sameSecret(bearer, serviceKey));
}

type Claim = {
  workspace_id: string;
  lease_token: string;
  intents: OpenIntent[];
};

/** What one business's run did, as payment_reconciliation_finish_v1 keeps it. */
export type RunResult = {
  started_at: string;
  read: number;
  settled: number;
  ended: number;
  left: number;
  abandoned: number;
  unreadable: Array<{ intent: string; reason: UnreadableReason }>;
  /** The attempts this run read, with what the provider said of each: the
   * finish stamps these, so one claimed and not read keeps its place. */
  read_items: Array<
    { intent: string; seen_state?: string; seen_client?: string }
  >;
};

async function credentials(
  service: Db,
  workspaceId: string,
  provider: string,
): Promise<Row | null> {
  const { data, error } = await service
    .from("payment_credentials")
    .select("config")
    .eq("workspace_id", workspaceId)
    .eq("provider", provider)
    .maybeSingle();
  if (error) return null;
  return ((data as Row | null)?.config ?? {}) as Row;
}

/** Applies [decision] for [intent]; a write that fails leaves the attempt as
 * it is, named. */
async function apply(
  service: Db,
  intent: OpenIntent,
  decision: Decision,
): Promise<Decision> {
  if (decision.kind === "settle") {
    const { error } = await service.rpc("settle_online_payment", {
      p_provider: intent.provider,
      p_order_id: intent.order_id,
      p_capture_id: decision.captureId,
      p_amount_cents: intent.amount_cents,
    });
    if (error) return { kind: "unreadable", reason: "record_failed" };
    if (decision.fee) {
      // #2380 -- what the provider kept, recorded once (the same idempotent
      // call as the notification's): the notification that would have
      // recorded it never came.
      const recorded = await service.rpc("record_provider_fee_v1", {
        p_provider: intent.provider,
        p_order_id: intent.order_id,
        p_fee_cents: decision.fee.feeCents,
        p_net_cents: decision.fee.netCents,
        p_currency: decision.fee.currency,
        p_transaction_id: decision.fee.transactionId,
      });
      if (recorded.error) return { ...decision, feeFailed: true };
    }
    return decision;
  }
  if (decision.kind === "end") {
    const { error } = await service.rpc("mark_payment_failed", {
      p_provider: intent.provider,
      p_order_id: intent.order_id,
    });
    if (error) return { kind: "unreadable", reason: "record_failed" };
    // Counted ended only when it was this write that ended it: a notification
    // may have settled it in between, and mark_payment_failed touches only an
    // open attempt.
    const after = await service
      .from("payment_intents")
      .select("status")
      .eq("id", intent.id)
      .maybeSingle();
    if (after.error) return { kind: "unreadable", reason: "record_failed" };
    const status = (after.data as Row | null)?.status;
    if (status === "failed") return decision;
    if (status === "captured") return { kind: "left" };
    return { kind: "unreadable", reason: "record_failed" };
  }
  return decision;
}

/** Reads and applies every attempt of one claimed business. */
export async function reconcileBusiness(
  claim: Claim,
  service: Db,
  deps: Deps,
  startedAt: string,
  deadline: number,
): Promise<RunResult> {
  const result: RunResult = {
    started_at: startedAt,
    read: 0,
    settled: 0,
    ended: 0,
    left: 0,
    abandoned: 0,
    unreadable: [],
    read_items: [],
  };
  const allowTest = allowsTestPayments(deps.env);
  for (const intent of claim.intents) {
    // The budget is the run's, checked per attempt: a run that stops early
    // finishes with what it has, and the rest is claimed again later.
    if (deps.now() >= deadline) break;
    const reader = readerOf(intent.provider);
    if (!reader) continue;
    const item: RunResult["read_items"][number] = { intent: intent.id };
    result.read_items.push(item);
    if (intent.order_id.startsWith("pending:")) {
      // No order was ever known: there is nothing to ask the provider.
      const ended = await apply(service, intent, { kind: "end" });
      if (ended.kind === "end") result.abandoned++;
      else if (ended.kind === "left") result.left++;
      else {result.unreadable.push({
          intent: intent.id,
          reason: "record_failed",
        });}
      continue;
    }
    result.read++;
    const cfg = await credentials(service, claim.workspace_id, intent.provider);
    const readDeps = {
      fetch: deps.fetch,
      env: deps.env,
      allowTest,
      timeoutMs: CALL_TIMEOUT_MS,
      observe: (seen: { state: string; client: string }) => {
        item.seen_state = seen.state;
        item.seen_client = seen.client;
      },
      stillOpen: async () => {
        const now = await service.from("payment_intents").select("status").eq(
          "id",
          intent.id,
        ).maybeSingle();
        return !now.error && (now.data as Row | null)?.status === "created";
      },
    };
    const read: Decision = cfg === null
      ? { kind: "unreadable", reason: "unreachable" }
      : await reader(intent, cfg, readDeps);
    const done = await apply(service, intent, read);
    switch (done.kind) {
      case "settle":
        result.settled++;
        // Settled, but what the provider kept was not recorded: named.
        if (done.feeFailed) {
          result.unreadable.push({
            intent: intent.id,
            reason: "record_failed",
          });
        }
        break;
      case "end":
        result.ended++;
        break;
      case "left":
        result.left++;
        break;
      case "unreadable":
        result.unreadable.push({ intent: intent.id, reason: done.reason });
        break;
    }
  }
  return result;
}

export async function handle(
  req: Request,
  deps: Deps = defaultDeps,
): Promise<Response> {
  if (req.method !== "POST") return refuse("method_not_allowed", 405);
  const delegated = refuseDelegated(req);
  if (delegated) return delegated;
  if (
    !mayReconcile(
      req,
      deps.env("PAYMENT_RECONCILE_SECRET"),
      deps.env("SUPABASE_SERVICE_ROLE_KEY"),
    )
  ) {
    return refuse("not allowed", 401);
  }
  const service = deps.service();
  const started = deps.now();
  // The run's marker is the database's clock, never this function's.
  const begun = await service.rpc("payment_reconciliation_begin_v1", {});
  if (begun.error || typeof begun.data !== "string") {
    logLine("error", FN, "begin_failed", { error: begun.error ? describeError(begun.error) : "no marker" });
    return refuse("begin_failed", 500);
  }
  const runStarted = begun.data;
  const runs: Row[] = [];
  while (deps.now() - started < RUN_BUDGET_MS) {
    const claimed = await service.rpc("payment_reconciliation_claim_v1", {
      p_lease_seconds: LEASE_SECONDS,
      p_run_started: runStarted,
      p_limit: MAX_INTENTS,
    });
    if (claimed.error) {
      logLine("error", FN, "claim_failed", { error: describeError(claimed.error) });
      return refuse("claim_failed", 500, undefined, { runs });
    }
    const one = ((claimed.data ?? []) as Claim[])[0];
    if (!one) break;
    const result = await reconcileBusiness(
      one,
      service,
      deps,
      runStarted,
      started + RUN_BUDGET_MS,
    );
    const finished = await service.rpc("payment_reconciliation_finish_v1", {
      p_workspace_id: one.workspace_id,
      p_lease_token: one.lease_token,
      p_result: result,
    });
    const kept = !finished.error && finished.data === true;
    if (!kept) {
      // The lease ran out under this run: what it settled or ended stays (the
      // paths are exactly once); its record is not kept.
      logLine("error", FN, "record_not_kept", { workspace: one.workspace_id });
    }
    runs.push({
      workspace: one.workspace_id,
      read: result.read,
      settled: result.settled,
      ended: result.ended,
      left: result.left,
      abandoned: result.abandoned,
      unreadable: result.unreadable.length,
      kept,
    });
  }
  return ok({ runs });
}

/** The function as it is served: whatever [handle] throws is the envelope (#4412). */
export const serve = (deps: Deps = defaultDeps) => guard(FN, (req) => handle(req, deps));

if (import.meta.main) Deno.serve(serve());
