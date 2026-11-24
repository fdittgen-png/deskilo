// SPDX-License-Identifier: AGPL-3.0-or-later
//
// maintenance (#3985) -- the installation-wide maintenance jobs, one request
// per job (maintenance_tick, 0799). One secret serves them all: the database
// job sends the Vault secret deskilo_maintenance_secret in
// `x-deskilo-maintenance-secret` (MAINTENANCE_SECRET here); the exact service
// credential is an operator's manual run. Nothing else; a delegated token is
// refused first. Each job runs under its own lease and leaves one row in the
// maintenance record (maintenance_finish_v1).
//
// invoice-originals-sweep: the uploaded invoice PDFs that no recorded
// original names (invoice_originals_sweep_claim_v1 says which, at most a cap
// per run). In `report` mode, the installation's default, each is named in
// the record and none is removed; in `remove`, which the operator switches
// on, they are removed through the Storage API so the stored file goes with
// its metadata, and a file that could not be removed is named and left.

import { refuseDelegated } from "../_shared/delegated.ts";
import { sameSecret } from "../_shared/same_secret.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { describeError, logLine } from "../_shared/log.ts";
import { ok, refuse } from "../_shared/respond.ts";
import { guard } from "../_shared/serve.ts";

const FN = "maintenance";

export const MAINTENANCE_SECRET_HEADER = "x-deskilo-maintenance-secret";
/** A run's lease: longer than the slowest sweep it covers. */
export const LEASE_SECONDS = 900;
/** How many files one Storage API call removes. */
export const REMOVE_BATCH = 100;
const BUCKET = "invoice-originals";

type Row = Record<string, unknown>;

export type Db = {
  rpc: (
    fn: string,
    args: Row,
  ) => PromiseLike<{ data: unknown; error: unknown }>;
  storage: {
    from: (bucket: string) => {
      remove: (
        paths: string[],
      ) => PromiseLike<{ data: unknown; error: unknown }>;
    };
  };
};

export type Deps = {
  service: () => Db;
  env: (name: string) => string | undefined;
  now: () => number;
};

const defaultDeps: Deps = {
  service: () =>
    createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    ) as unknown as Db,
  env: (name) => Deno.env.get(name),
  now: () => Date.now(),
};


/** The database job's secret, or the exact service credential. */
export function mayMaintain(
  req: Request,
  secret: string | undefined,
  serviceKey: string | undefined,
): boolean {
  const sent = req.headers.get(MAINTENANCE_SECRET_HEADER);
  if (secret && sent && sameSecret(sent, secret)) return true;
  const bearer = (req.headers.get("authorization") ?? "").match(
    /^Bearer\s+(.+)$/i,
  )?.[1];
  return !!(serviceKey && bearer && sameSecret(bearer, serviceKey));
}

type Failure = { item: string; reason: string };
type JobResult = { counts: Record<string, number>; failures: Failure[] } | null;

/** The sweep: null when another run holds its lease. */
export async function sweepInvoiceOriginals(
  service: Db,
): Promise<JobResult & { lease?: string } | null> {
  const claimed = await service.rpc("invoice_originals_sweep_claim_v1", {
    p_lease_seconds: LEASE_SECONDS,
  });
  if (claimed.error) throw new Error("claim_failed");
  const one = ((claimed.data ?? []) as Array<
    { lease_token: string; mode: string; candidates: Array<{ name: string }> }
  >)[0];
  if (!one) return null;
  const names = (one.candidates ?? []).map((c) => c.name);
  if (one.mode !== "remove") {
    return {
      lease: one.lease_token,
      counts: { candidates: names.length, removed: 0 },
      failures: names.map((item) => ({ item, reason: "report_only" })),
    };
  }
  const failures: Failure[] = [];
  let removed = 0;
  for (let i = 0; i < names.length; i += REMOVE_BATCH) {
    const batch = names.slice(i, i + REMOVE_BATCH);
    let answer: { data: unknown; error: unknown };
    try {
      answer = await service.storage.from(BUCKET).remove(batch);
    } catch {
      answer = { data: null, error: "unreachable" };
    }
    if (answer.error) {
      for (const item of batch) {
        failures.push({ item, reason: "remove_failed" });
      }
      continue;
    }
    const gone = new Set(
      ((answer.data ?? []) as Row[]).map((o) => String(o.name ?? "")),
    );
    for (const item of batch) {
      if (gone.has(item)) removed++;
      else failures.push({ item, reason: "not_removed" });
    }
  }
  return {
    lease: one.lease_token,
    counts: { candidates: names.length, removed },
    failures,
  };
}

const JOBS: Record<
  string,
  (service: Db) => Promise<(JobResult & { lease?: string }) | null>
> = {
  "invoice-originals-sweep": sweepInvoiceOriginals,
};

export async function handle(
  req: Request,
  deps: Deps = defaultDeps,
): Promise<Response> {
  if (req.method !== "POST") return refuse("method_not_allowed", 405);
  const delegated = refuseDelegated(req);
  if (delegated) return delegated;
  if (
    !mayMaintain(
      req,
      deps.env("MAINTENANCE_SECRET"),
      deps.env("SUPABASE_SERVICE_ROLE_KEY"),
    )
  ) {
    return refuse("not allowed", 401);
  }
  const body = (await req.json().catch(() => ({}))) as Row;
  const job = String(body.job ?? "");
  const run = Object.hasOwn(JOBS, job) ? JOBS[job] : undefined;
  if (!run) return refuse("unknown_job", 400);
  const service = deps.service();
  const startedAt = new Date(deps.now()).toISOString();
  let result: (JobResult & { lease?: string }) | null;
  try {
    result = await run(service);
  } catch (e) {
    logLine("error", FN, "maintenance_job_failed", { job, error: String(e) });
    return refuse("job_failed", 500, undefined, { job });
  }
  if (!result) return ok({ job, skipped: "leased" });
  const finished = await service.rpc("maintenance_finish_v1", {
    p_job: job,
    p_lease_token: result.lease,
    p_started_at: startedAt,
    p_counts: result.counts,
    p_failures: result.failures,
  });
  const kept = !finished.error && finished.data === true;
  if (!kept) logLine("error", FN, "maintenance_record_not_kept", { job });
  return ok({
    job,
    ...result.counts,
    failures: result.failures.length,
    kept,
  });
}

/** The function as it is served: whatever [handle] throws is the envelope (#4412). */
export const serve = (deps: Deps = defaultDeps) => guard(FN, (req) => handle(req, deps));

if (import.meta.main) Deno.serve(serve());
