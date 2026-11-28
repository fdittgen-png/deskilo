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
// #4454 (slice 2) -- the cashier and the board's commands (migration 0995):
//   POST { action: "operator.request", device_id, secret, lease_hash }             the board asks for a cashier
//   POST { action: "operator.authorize", terminal_id }  + the cashier's bearer      a cashier attaches themselves
//   POST { action: "command", device_id, secret, lease_token, op, args }            the board sells as that cashier
// A command is one of COMMANDS: the workspace and the till come from the lease, never from the board, and the call goes
// to the till's existing function with the cashier's own access token (stored encrypted, AES-GCM, by this function's
// key), so the function checks the cashier's rights and the features as for any person. Numbers keep every digit
// (exact_json.ts). A lost or unreadable answer of a financial command is `uncertain`, never a refusal.
//
// Anything else is refused before the database: another method, another action, a body over its ceiling, a value
// of the wrong form, or a source past its budget of attempts. No credential travels in the query string, and none
// is written to the log. A refusal is { ok: false, reason } with the contract's reason code.

import { refuseDelegated } from "../_shared/delegated.ts";
import {
  asI64,
  ExactDecimal,
  ExactJsonError,
  type ExactLimits,
  type ExactValue,
  parseExactBytes,
  stringifyExact,
} from "../_shared/exact_json.ts";
import { describeError, logLine } from "../_shared/log.ts";
import { ok } from "../_shared/respond.ts";

export type Rpc = (
  fn: string,
  args: Record<string, unknown>,
  // deno-lint-ignore no-explicit-any
) => PromiseLike<{ data: any; error: { message: string } | null }>;

/** A cashier's access token, verified by the installation's Auth: who they are, their sign-in and its expiry. */
export type Verified = { userId: string; sessionId: string; expiresAt: Date };

/** A call made as a person: the installation's REST endpoint with its public key and [bearer]. */
export type RestCall = (fn: string, body: string, bearer: string) => Promise<{ status: number; bytes: Uint8Array }>;

export type Deps = {
  rpc: Rpc;
  /** Whether [source] may make one more attempt now (a bounded budget per source). */
  allow: (source: string) => boolean;
  /** The bearer verified by the installation's Auth, or null. Absent: no human route. */
  verify?: (bearer: string) => Promise<Verified | null>;
  /** The function's own key for the cashiers' tokens (AES-GCM, 256 bits); null when not configured. */
  tokenKey?: CryptoKey | null;
  /** A call as the cashier (their token and the public key). */
  rest?: RestCall;
};

/** The commands a board may send, each the till's existing function and what the board may pass to it. */
export const COMMANDS: Record<string, { fn: string; args: readonly string[] }> = {
  readiness: { fn: "counter_readiness_v1", args: [] },
  // #4517 -- a board's command acts only on its own till's receipts: a command that names a receipt goes to a board
  // function that takes the lease's till (1002), never to the till's function directly. A later command that names a
  // receipt (a void, a reprint) joins the same way.
  draft: { fn: "counter_board_receipt_draft_v1", args: ["request_id", "receipt_id", "expected_revision", "lines"] },
  finalize: { fn: "counter_board_receipt_finalize_v1", args: ["request_id", "receipt_id", "expected_revision", "tenders"] },
};

/** The largest command a board sends: a basket of its lines. Enrollment stays at [MAX_BODY_BYTES]. */
export const MAX_COMMAND_BYTES = 16384; // not-mirrored: the request size of the function
/** The deepest a command's JSON nests, and the most values it holds. */
const COMMAND_LIMITS = { maxBytes: MAX_COMMAND_BYTES, maxDepth: 8, maxValues: 2000 };

export const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** The largest enrollment body a board sends: a claim is about 300 bytes. */
export const MAX_BODY_BYTES = 1024; // not-mirrored: the request size of the function

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

/** The most sources one instance keeps a budget for; past it, the oldest is forgotten. */
export const MAX_SOURCES = 10_000; // not-mirrored: the memory one instance gives its budget

/** A small budget of attempts per source and minute, kept in this instance's memory: a cost bound, not the lock on a
 * code (the database bounds a code's attempts and life, and 60 random bits are not guessed). Ended minutes are
 * forgotten first; when every slot is live the oldest goes, so a flood of new sources never shuts out a real board. */
export function budget(perMinute: number, now: () => number = Date.now): (source: string) => boolean {
  const seen = new Map<string, { start: number; n: number }>();
  return (source) => {
    const t = now();
    const s = seen.get(source);
    if (s && t - s.start < 60_000) {
      s.n += 1;
      return s.n <= perMinute;
    }
    if (s) seen.delete(source);
    if (seen.size >= MAX_SOURCES) {
      for (const [k, v] of seen) if (t - v.start >= 60_000) seen.delete(k);
      if (seen.size >= MAX_SOURCES) seen.delete(seen.keys().next().value!);
    }
    seen.set(source, { start: t, n: 1 });
    return true;
  };
}

/** The source a budget counts: the hop the platform's proxy appended (badge-signin's callerOf rule), never a value
 * the caller wrote first in the header. */
export const sourceOf = (req: Request): string => {
  const hops = (req.headers.get("x-forwarded-for") ?? "").split(",").map((h) => h.trim()).filter(Boolean);
  return (hops.length > 0 ? hops[hops.length - 1] : req.headers.get("cf-connecting-ip")) || "unknown";
};

/** The body read no further than the command ceiling and parsed exactly; an enrollment body past its own ceiling is
 * refused after the parse (its action is known only then). */
async function bodyOf(req: Request): Promise<{ [key: string]: ExactValue } | "too_large" | null> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (!Number.isFinite(declared) || declared > MAX_COMMAND_BYTES) return "too_large";
  if (!req.body) return null;
  const reader = req.body.getReader();
  const bytes = new Uint8Array(MAX_COMMAND_BYTES);
  let n = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (n + value.length > MAX_COMMAND_BYTES) {
      await reader.cancel();
      return "too_large";
    }
    bytes.set(value, n);
    n += value.length;
  }
  try {
    const value = parseExactBytes(bytes.subarray(0, n), COMMAND_LIMITS);
    if (!value || typeof value !== "object" || Array.isArray(value) || value instanceof ExactDecimal) {
      return null;
    }
    const out = value as { [key: string]: ExactValue };
    const action = out.action;
    if (typeof action === "string" && action.startsWith("enrollment.") && n > MAX_BODY_BYTES) return "too_large";
    return out;
  } catch (e) { // handled: a body that is not bounded UTF-8 JSON is no request; the caller answers its reason
    if (e instanceof ExactJsonError && e.reason !== "invalid_json" && e.reason !== "invalid_utf8") return "too_large";
    return null;
  }
}

const str = (v: unknown) => (typeof v === "string" ? v : "");

const hex = (b: Uint8Array) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
const fromBase64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

async function sha256Hex(text: string): Promise<string> {
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text))));
}

/** What a cashier's token is bound to: the board, the cashier and their sign-in (the AES-GCM additional data). */
const binding = (terminalId: string, userId: string, sessionId: string) =>
  new TextEncoder().encode(`deskilo-till-lease:v1|${terminalId}|${userId}|${sessionId}`);

/** The answer of a till function, read exactly: its value, or why it is no answer. */
const ANSWER_LIMITS: ExactLimits = { maxBytes: 65536, maxDepth: 12, maxValues: 20000 };

/** A board's command args, checked against what the command takes: exact integers in range, uuids as uuids. */
function commandArgs(op: string, args: ExactValue | undefined): Record<string, ExactValue> | null {
  const spec = COMMANDS[op];
  if (!spec) return null;
  const given = args ?? {};
  if (typeof given !== "object" || given === null || Array.isArray(given) || given instanceof ExactDecimal) return null;
  const out: Record<string, ExactValue> = {};
  for (const key of Object.keys(given)) if (!spec.args.includes(key)) return null;
  for (const key of spec.args) {
    const v = (given as Record<string, ExactValue>)[key];
    if (key === "request_id" && !(typeof v === "string" && UUID.test(v))) return null;
    if (key === "receipt_id" && !(v === null || v === undefined || (typeof v === "string" && UUID.test(v)))) return null;
    if (key === "expected_revision" && !(v === null || v === undefined || (asI64(v) !== null && (v as bigint) >= 0n))) return null;
    if ((key === "lines" || key === "tenders") && !Array.isArray(v)) return null;
    if (v !== undefined) out[key] = v;
  }
  return out;
}

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
    case "operator.request": {
      const device = str(body.device_id), secret = str(body.secret), lease = str(body.lease_hash);
      if (!UUID.test(device) || !HEX64.test(secret) || !HEX64.test(lease)) return refused("pair_proof_invalid", 400);
      fn = "till_terminal_lease_request_v1";
      args = { p_device_id: device, p_secret: secret, p_lease_hash: lease };
      break;
    }
    case "operator.authorize":
      return await authorize(req, str(body.terminal_id), deps);
    case "command":
      return await command(body, deps);
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

/** A cashier, signed in, attaches themselves to the board's open request: their token stored encrypted, bound to the
 * board, themselves and their sign-in. Without the function's key nothing is issued. */
async function authorize(req: Request, terminalId: string, deps: Deps): Promise<Response> {
  if (!UUID.test(terminalId)) return refused("scope_mismatch", 400);
  if (!deps.verify || !deps.rest || !deps.tokenKey) return refused("terminal_not_configured", 503);
  const bearer = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  const who = bearer ? await deps.verify(bearer) : null;
  if (!who) return refused("operator_revoked", 401);
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const sealed = new Uint8Array(await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: nonce, additionalData: binding(terminalId, who.userId, who.sessionId) },
    deps.tokenKey,
    new TextEncoder().encode(bearer),
  ));
  const body = stringifyExact({
    p_terminal_id: terminalId,
    p_token_ciphertext: "\\x" + hex(sealed),
    p_token_nonce: "\\x" + hex(nonce),
    p_token_expires_at: who.expiresAt.toISOString(),
  });
  return await forward("till_terminal_lease_grant_v1", body, bearer, deps.rest, false);
}

/** A board's command: the board and its lease checked here, the cashier's token opened, the till's function called as
 * the cashier with the workspace and till of the lease. */
async function command(body: { [key: string]: ExactValue }, deps: Deps): Promise<Response> {
  const device = str(body.device_id), secret = str(body.secret), token = str(body.lease_token), op = str(body.op);
  if (!UUID.test(device) || !HEX64.test(secret) || !HEX64.test(token)) return refused("pair_proof_invalid", 400);
  const given = commandArgs(op, body.args);
  if (!given) return refused("protocol_unsupported", 400);
  if (!deps.rest || !deps.tokenKey) return refused("terminal_not_configured", 503);
  const { data, error } = await deps.rpc("till_terminal_lease_resolve_v1", {
    p_device_id: device,
    p_secret: secret,
    p_lease_hash: await sha256Hex(token),
  });
  if (error || !data || typeof data.ok !== "boolean") {
    logLine("error", "embedded-till", "rpc_failed", { fn: "till_terminal_lease_resolve_v1", error: describeError(error) });
    return refused("uncertain", 503);
  }
  if (!data.ok) return answer({ ok: false, reason: str(data.reason) });
  let bearer: string;
  try {
    const plain = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: fromBase64(str(data.token_nonce)), additionalData: binding(str(data.terminal_id), str(data.user_id), str(data.auth_session_id)) },
      deps.tokenKey,
      fromBase64(str(data.token_ciphertext)),
    );
    bearer = new TextDecoder().decode(plain);
  } catch (_) { // handled: a token this key did not seal, or sealed for another binding, authorizes nothing
    logLine("error", "embedded-till", "lease_unsealed", { op });
    return refused("operator_revoked");
  }
  const call: Record<string, ExactValue> = { p_workspace_id: str(data.workspace_id) };
  if (op === "draft") {
    call.p_till_id = str(data.till_id);
    call.p_request_id = given.request_id;
    call.p_receipt_id = given.receipt_id ?? null;
    call.p_expected_revision = given.expected_revision ?? null;
    call.p_lines = given.lines;
  } else if (op === "finalize") {
    call.p_till_id = str(data.till_id);
    call.p_request_id = given.request_id;
    call.p_receipt_id = given.receipt_id ?? null;
    call.p_expected_revision = given.expected_revision ?? null;
    call.p_tenders = given.tenders;
  }
  logLine("info", "embedded-till", "command", { op, terminal: str(data.terminal_id), member: str(data.member_id) });
  return await forward(COMMANDS[op].fn, stringifyExact(call), bearer, deps.rest, op !== "readiness");
}

/** The till's function called as the cashier; its answer passed on exactly. A refusal keeps its code and detail; a
 * lost, failed or unreadable answer of a financial command is `uncertain`. */
async function forward(fn: string, body: string, bearer: string, rest: RestCall, financial: boolean): Promise<Response> {
  let status: number, bytes: Uint8Array;
  try {
    ({ status, bytes } = await rest(fn, body, bearer));
  } catch (e) { // handled: no answer from the database is an uncertain outcome, told as such
    logLine("error", "embedded-till", "rest_failed", { fn, error: describeError(e) });
    return refused("uncertain", 503);
  }
  let value: ExactValue;
  try {
    value = bytes.length ? parseExactBytes(bytes, ANSWER_LIMITS) : null;
  } catch (_) { // handled: an unreadable answer is never taken for a refusal
    return refused("uncertain", 502);
  }
  if (status >= 200 && status < 300) return new Response(stringifyExact({ ok: true, result: value }), {
    status: 200,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
  if (status >= 500 || status === 0) return refused("uncertain", 503);
  const err = (value ?? {}) as Record<string, ExactValue>;
  const code = str(err.code);
  if (status === 401 || code === "PGRST301" || code === "PGRST303") return refused("operator_expired", 401);
  if (/^DK[A-Z][A-Z0-9]{2}$/.test(code) || code === "42501") {
    return new Response(stringifyExact({ ok: false, reason: "refused", code, detail: err.details ?? null }), {
      status: 200,
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
  return refused(financial ? "uncertain" : "refused", financial ? 502 : 200);
}

