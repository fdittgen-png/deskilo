// SPDX-License-Identifier: AGPL-3.0-or-later
//
// federation-inbox — verify_jwt OFF; authenticity from the backchannel
// envelope: HMAC-SHA256 with the key of one relationship and direction,
// over the method, the path, the source and target installation, the
// event id, the request time, the SHA-256 of the raw body and the key id.
//
// This function only carries the request into the database: the raw body
// bytes (base64, never re-serialised) and the `x-deskilo-*` headers go to
// `federation_inbox_accept`, which holds the key (Vault), verifies the
// signature and the digest, remembers the event id and applies the status.
// No key, no decision and no secret lives here. The answer's HTTP status
// tells the sender what to do: 2xx done (applied, a retry, or superseded),
// 401 retry later (a key not configured or rotated here yet), any other 4xx
// refused for good, 5xx retry. A `duplicate` (the same event again) also
// carries `first_outcome`, what the first delivery decided: the sender books
// a retry of a refused event as refused, never as delivered (#2563).

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

/// The envelope this function forwards; every other header stays here.
export const ENVELOPE_HEADERS = [
  "x-deskilo-protocol",
  "x-deskilo-purpose",
  "x-deskilo-source",
  "x-deskilo-target",
  "x-deskilo-event",
  "x-deskilo-timestamp",
  "x-deskilo-digest",
  "x-deskilo-key",
  "x-deskilo-signature",
] as const;

/// A status assertion is a few hundred bytes; the database refuses more
/// than this too, so an oversized body is never read into it.
export const MAX_BODY_BYTES = 16384;

const STATUS: Record<string, number> = {
  applied: 200,
  renewed: 200,
  staged: 200,
  reconciled: 200,
  duplicate: 200,
  superseded: 200,
  malformed: 400,
  bad_digest: 400,
  unknown_installation: 401,
  unknown_key: 401,
  bad_signature: 401,
  event_conflict: 409,
  revision_conflict: 409,
  snapshot_conflict: 409,
  wrong_target: 421,
  future_request: 422,
  future_assertion: 422,
  expired_assertion: 422,
  wrong_issuer: 422,
  unlinked_subject: 422,
  foreign_workspace: 422,
  unenrolled_source: 422,
  unverified: 422,
  expired_snapshot: 422,
};

export interface Deps {
  admin: () => SupabaseClient;
}

const defaultDeps: Deps = {
  admin: () =>
    createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    ),
};

function answer(status: number, outcome: string, firstOutcome?: string): Response {
  const body = firstOutcome === undefined ? { outcome } : { outcome, first_outcome: firstOutcome };
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function base64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}

export async function handle(req: Request, deps: Deps = defaultDeps): Promise<Response> {
  if (req.method !== "POST") return answer(405, "method_not_allowed");
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > MAX_BODY_BYTES) return answer(413, "too_large");
  const raw = new Uint8Array(await req.arrayBuffer());
  if (raw.byteLength === 0 || raw.byteLength > MAX_BODY_BYTES) {
    return answer(raw.byteLength === 0 ? 400 : 413, raw.byteLength === 0 ? "malformed" : "too_large");
  }
  const envelope: Record<string, string> = {};
  for (const name of ENVELOPE_HEADERS) {
    const value = req.headers.get(name);
    if (value !== null) envelope[name] = value;
  }
  // The signed path is the function's own, wherever the gateway mounts it.
  const path = "/" + new URL(req.url).pathname.split("/").filter((s) => s !== "").pop();
  const { data, error } = await deps.admin().rpc("federation_inbox_accept", {
    p_method: req.method,
    p_path: path,
    p_headers: envelope,
    p_body_b64: base64(raw),
  });
  if (error) {
    console.error("federation inbox unavailable", error.message);
    return answer(500, "unavailable");
  }
  const result = data as { outcome?: unknown; first_outcome?: unknown } | null;
  const outcome = String(result?.outcome ?? "");
  const status = STATUS[outcome];
  if (status === undefined) {
    console.error("federation inbox gave no known outcome");
    return answer(500, "unavailable");
  }
  const first = result?.first_outcome;
  if (outcome === "duplicate" && typeof first === "string" && first !== "") {
    return answer(status, outcome, first);
  }
  return answer(status, outcome);
}

if (import.meta.main) Deno.serve((req) => handle(req));
