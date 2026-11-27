// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4454 (E03A, slice 1) -- the till board's own routes. A board has no Deskilo account: it proves who it is with
// the code its owner was given (enrollment.claim) and then with its secret (enrollment.status). Both are checked in
// the database by functions only the service role may call (till_terminal_claim_v1, till_terminal_status_v1,
// migration 0984); this function only shapes what reaches them.
//
//   POST { action: "enrollment.claim", code, device_id, secret_hash, firmware, protocol, claim_request_id }
//   POST { action: "enrollment.status", device_id, secret }
//
// Anything else is refused before the database: another method, another action, a body over its ceiling, a value
// of the wrong form, or a source past its budget of attempts. No credential travels in the query string, and none
// is written to the log. A refusal is { ok: false, reason } with the contract's reason code.

import { refuseDelegated } from "../_shared/delegated.ts";
import { describeError, logLine } from "../_shared/log.ts";
import { ok } from "../_shared/respond.ts";
import { callerOf } from "../badge-signin/badge_guard.ts";

export type Rpc = (
  fn: string,
  args: Record<string, unknown>,
  // deno-lint-ignore no-explicit-any
) => PromiseLike<{ data: any; error: { message: string } | null }>;

export type Deps = {
  rpc: Rpc;
  /** Whether [source] may make one more attempt now (a bounded budget per source). */
  allow: (source: string) => boolean;
};

export const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** The largest body a board sends: a claim is about 300 bytes. */
export const MAX_BODY_BYTES = 1024;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const HEX64 = /^[0-9a-f]{64}$/;
const CODE = /^[0-9A-Za-z -]{12,16}$/;
const FIRMWARE = /^[!-~]{1,40}$/;
const PROTOCOL = /^v[0-9]{1,3}$/;

function answer(body: unknown, status = 200): Response {
  return ok(body, status, CORS);
}

function refused(reason: string, status = 200): Response {
  return answer({ ok: false, reason }, status);
}

/** The most sources one instance keeps a budget for; past it, a new source is refused until older minutes end. */
export const MAX_SOURCES = 10_000;

/** A small budget of attempts per source and minute, kept in this instance's memory. Only expired minutes are
 * forgotten: a flood of new sources cannot wipe the budget of the ones already counted. */
export function budget(perMinute: number, now: () => number = Date.now): (source: string) => boolean {
  const seen = new Map<string, { start: number; n: number }>();
  return (source) => {
    const t = now();
    const s = seen.get(source);
    if (s && t - s.start < 60_000) {
      s.n += 1;
      return s.n <= perMinute;
    }
    if (!s && seen.size >= MAX_SOURCES) {
      for (const [k, v] of seen) if (t - v.start >= 60_000) seen.delete(k);
      if (seen.size >= MAX_SOURCES) return false;
    }
    seen.set(source, { start: t, n: 1 });
    return true;
  };
}

/** The source a budget counts: the hop the platform's proxy appended (badge-signin's rule), never a value the
 * caller wrote first in the header. */
export const sourceOf = (req: Request): string => callerOf(req) || "unknown";

/** The body read no further than its ceiling: a declared length over it, or more bytes than it, stop the read. */
async function bodyOf(req: Request): Promise<Record<string, unknown> | "too_large" | null> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (!Number.isFinite(declared) || declared > MAX_BODY_BYTES) return "too_large";
  if (!req.body) return null;
  const reader = req.body.getReader();
  const bytes = new Uint8Array(MAX_BODY_BYTES);
  let n = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (n + value.length > MAX_BODY_BYTES) {
      await reader.cancel();
      return "too_large";
    }
    bytes.set(value, n);
    n += value.length;
  }
  try {
    const value = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes.subarray(0, n)));
    return value && typeof value === "object" && !Array.isArray(value) ? value : null;
  } catch (_) {
    return null;
  }
}

const str = (v: unknown) => (typeof v === "string" ? v : "");

export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return refused("protocol_unsupported", 405);
  const delegated = refuseDelegated(req, CORS);
  if (delegated) return delegated;
  if (new URL(req.url).search !== "") return refused("protocol_unsupported", 400);
  if (!deps.allow(sourceOf(req))) return refused("rate_limited", 429);

  const body = await bodyOf(req);
  if (body === "too_large") return refused("payload_too_large", 413);
  if (body === null) return refused("protocol_unsupported", 400);

  let fn: string;
  let args: Record<string, unknown>;
  switch (body.action) {
    case "enrollment.claim": {
      const code = str(body.code), device = str(body.device_id), hash = str(body.secret_hash);
      const firmware = str(body.firmware), protocol = str(body.protocol), request = str(body.claim_request_id);
      if (!PROTOCOL.test(protocol)) return refused("protocol_unsupported", 400);
      if (!CODE.test(code) || !UUID.test(device) || !HEX64.test(hash) || !FIRMWARE.test(firmware) || !UUID.test(request)) {
        return refused("pair_proof_invalid", 400);
      }
      fn = "till_terminal_claim_v1";
      args = {
        p_code: code,
        p_device_id: device,
        p_secret_hash: hash,
        p_firmware: firmware,
        p_protocol: protocol,
        p_claim_request_id: request,
      };
      break;
    }
    case "enrollment.status": {
      const device = str(body.device_id), secret = str(body.secret);
      if (!UUID.test(device) || !HEX64.test(secret)) return refused("pair_proof_invalid", 400);
      fn = "till_terminal_status_v1";
      args = { p_device_id: device, p_secret: secret };
      break;
    }
    default:
      return refused("protocol_unsupported", 400);
  }

  const { data, error } = await deps.rpc(fn, args);
  if (error || !data || typeof data !== "object" || typeof data.ok !== "boolean") {
    // what went wrong is in the log by its kind, never a value the board sent
    logLine("error", "embedded-till", "rpc_failed", { fn, error: describeError(error) });
    return refused("uncertain", 503);
  }
  return answer(data);
}
