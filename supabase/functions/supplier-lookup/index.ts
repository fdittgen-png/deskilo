// SPDX-License-Identifier: AGPL-3.0-or-later
//
// supplier-lookup (#2863) — asks a company registry about a supplier's
// identifier on behalf of a workspace, and answers in the provider-neutral
// contract (contract.ts). Nothing is stored: a lookup is a suggestion the
// person reviews in the app before any save, which goes through
// `save_supplier` with its own guard.
//
// WHO may ask is decided by the database with the caller's own token —
// the same conditions `supplier_guard` puts on saving a supplier
// (`manageBilling`, `supplyExpenses` on) plus the `viesVerification`
// flag — before any request leaves. The service role is never used:
// there is nothing to write. VIES is public, so no credential exists to
// leak; the identifier asked for is never logged. How long the registry
// is waited for and how many lookups a caller may make per minute are the
// server's settings (`purchase.supplier_lookup_timeout_seconds`,
// `purchase.supplier_lookup_per_minute`), read with the same token.

import { refuseDelegated } from "../_shared/delegated.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { CORS, preflight } from "../_shared/cors.ts";
import type { Adapter, LookupRequest } from "./contract.ts";
import { viesAdapter } from "./vies.ts";

/** The registries this function can ask, by id. */
export const adapters: Record<string, Adapter> = { [viesAdapter.id]: viesAdapter };

/** The most a request body may weigh: a workspace id and an identifier. A
 * protocol bound on the request's shape, not a choice. */
export const MAX_BODY_BYTES = 2048;

/** The quota's window: the setting counts lookups per minute. */
export const RATE_WINDOW_MS = 60_000;

/** The server settings this function reads, with the caller's own token. */
export const SETTING_TIMEOUT = "purchase.supplier_lookup_timeout_seconds";
export const SETTING_PER_MINUTE = "purchase.supplier_lookup_per_minute";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const COUNTRY = /^[A-Z]{2}$/;
const IDENTIFIER = /^[A-Z0-9]{2,20}$/;

export type Parsed = { workspace_id: string; adapter: Adapter; request: LookupRequest };

/**
 * Reads and checks a body. Returns the parsed question or the words of the
 * refusal — a shape the app shows as "the registry rejected the format",
 * never as a verdict on the company.
 */
export function parseLookupRequest(body: unknown): Parsed | { error: string } {
  if (typeof body !== "object" || body === null) return { error: "invalid body" };
  const b = body as Record<string, unknown>;
  const workspaceId = typeof b.workspace_id === "string" ? b.workspace_id : "";
  if (!UUID.test(workspaceId)) return { error: "workspace_id required" };
  const adapter = adapters[typeof b.provider === "string" ? b.provider : ""];
  if (!adapter) return { error: "unknown provider" };
  const kind = b.kind === "registration" ? "registration" : b.kind === "vat" ? "vat" : null;
  const mode = b.mode === "name" ? "name" : b.mode === "identifier" ? "identifier" : null;
  if (!kind || !adapter.kinds.includes(kind)) return { error: "unsupported identifier kind" };
  if (!mode || !adapter.modes.includes(mode)) return { error: "unsupported lookup mode" };
  const country = typeof b.country_code === "string" ? b.country_code.trim().toUpperCase() : "";
  if (!COUNTRY.test(country)) return { error: "country_code must be two letters" };
  const identifier = typeof b.identifier === "string"
    ? b.identifier.replace(/[\s.\-/]/g, "").toUpperCase()
    : "";
  if (!IDENTIFIER.test(identifier)) return { error: "identifier must be 2-20 letters or digits" };
  return {
    workspace_id: workspaceId,
    adapter,
    request: { country_code: country, identifier, kind, mode },
  };
}

/** A sliding window per caller, in this instance's memory. The quota is
 * the caller's current setting, so a changed setting applies at once. */
export class RateLimiter {
  constructor(private readonly windowMs = RATE_WINDOW_MS) {}

  private readonly seen = new Map<string, number[]>();

  /** Whether `key` may proceed at `now` under `limit` lookups per window;
   * records the attempt when it may. */
  allow(key: string, limit: number, now = Date.now()): boolean {
    const recent = (this.seen.get(key) ?? []).filter((t) => now - t < this.windowMs);
    if (recent.length >= limit) {
      this.seen.set(key, recent);
      return false;
    }
    recent.push(now);
    this.seen.set(key, recent);
    return true;
  }
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

/** The bearer token, hashed, as the rate limiter's key: never the token itself. */
async function callerKey(authorization: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(authorization));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

/** What the handler asks the database, as the caller. Reads only: a lookup
 * writes nothing, so no other call exists. */
export type CallerDb = {
  rpc: (fn: string, args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: unknown }>;
};

export type Deps = {
  /** A client bound to the caller's own token; never the service role. */
  caller: (authorization: string) => CallerDb;
  limiter: RateLimiter;
  fetcher?: typeof fetch;
  now?: () => Date;
};

/** A whole number from a `setting_value` answer, or null. */
function settingNumber(answer: { data: unknown; error: unknown }): number | null {
  if (answer.error) return null;
  const n = Number(answer.data);
  return Number.isFinite(n) && n >= 1 ? Math.floor(n) : null;
}

/**
 * One lookup: the shape, the size and the caller's rights are checked
 * before anything leaves; the registry is asked under the server's own
 * wait and quota; the answer is the neutral contract. Nothing is written.
 */
export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return preflight();
  // #1614 — an assistant's delegated token never reaches this function.
  const delegated = refuseDelegated(req, CORS);
  if (delegated) return delegated;

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization) return json({ error: "not signed in" }, 401);
  if (Number(req.headers.get("content-length") ?? "0") > MAX_BODY_BYTES) {
    return json({ error: "body too large" }, 400);
  }
  const text = await req.text();
  if (text.length > MAX_BODY_BYTES) return json({ error: "body too large" }, 400);
  let payload: unknown;
  try {
    payload = JSON.parse(text);
  } catch {
    return json({ error: "invalid body" }, 400);
  }
  const parsed = parseLookupRequest(payload);
  if ("error" in parsed) return json({ error: parsed.error }, 400);

  // WHO is asking, decided by the database before anything leaves: the
  // caller's own token answers has_permission and feature_effective, for
  // the workspace named in the request — another workspace's rights never
  // stand in for it.
  const caller = deps.caller(authorization);
  const ws = parsed.workspace_id;
  const [permission, suppliers, verification] = await Promise.all([
    caller.rpc("has_permission", { ws, perm: "manageBilling" }),
    caller.rpc("feature_effective", { p_workspace_id: ws, p_key: "supplyExpenses" }),
    caller.rpc("feature_effective", { p_workspace_id: ws, p_key: "viesVerification" }),
  ]);
  if (permission.error || permission.data !== true) {
    return json({ error: "not allowed to manage suppliers" }, 403);
  }
  if (suppliers.error || suppliers.data !== true) {
    return json({ error: "supplier management is switched off in this space" }, 403);
  }
  if (verification.error || verification.data !== true) {
    return json({ error: "vat verification is off in this workspace" }, 403);
  }

  const [timeout, perMinute] = await Promise.all([
    caller.rpc("setting_value", { p_workspace: ws, p_key: SETTING_TIMEOUT }),
    caller.rpc("setting_value", { p_workspace: ws, p_key: SETTING_PER_MINUTE }),
  ]);
  const seconds = settingNumber(timeout);
  const limit = settingNumber(perMinute);
  if (seconds === null || limit === null) {
    // A server without the settings cannot bound the call: it is not made.
    console.warn("supplier-lookup: the lookup settings could not be read");
    return json({ error: "lookup settings unavailable" }, 503);
  }
  if (!deps.limiter.allow(await callerKey(authorization), limit)) {
    return json({ error: "too many lookups" }, 429);
  }
  return json(
    await parsed.adapter.lookup(parsed.request, {
      timeoutMs: seconds * 1000,
      fetcher: deps.fetcher,
      now: deps.now,
    }),
  );
}

if (import.meta.main) {
  const deps: Deps = {
    caller: (authorization) =>
      createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_ANON_KEY")!,
        { global: { headers: { Authorization: authorization } } },
      ),
    limiter: new RateLimiter(),
  };
  Deno.serve((req) => handle(req, deps));
}
