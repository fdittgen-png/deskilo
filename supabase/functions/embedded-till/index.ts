// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4454 (E03A) -- the till board's endpoint. The service role reads and writes only through the board's own database
// functions (enrollment, lease request and resolve); a cashier's authorization and every command go to the database as
// the cashier, with the installation's public key and their own access token, never as the service role.
import { env as readEnv, KEYS } from "../_shared/config.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { guard } from "../_shared/serve.ts";
import { budget, handle, type RestCall, type Verified } from "./handler.ts";

const url = readEnv(KEYS.supabaseUrl)!;
const anonKey = readEnv(KEYS.supabaseAnonKey) ?? "";
const supabase = createClient(url, readEnv(KEYS.supabaseServiceRoleKey)!);

const allow = budget(30);

/** The function's key, or null when it is missing or not 32 bytes: then no cashier is authorized. */
async function tokenKey(): Promise<CryptoKey | null> {
  const raw = readEnv(KEYS.embeddedTillTokenKey) ?? "";
  let bytes: Uint8Array<ArrayBuffer>;
  try {
    bytes = Uint8Array.from(atob(raw), (c) => c.charCodeAt(0));
  } catch (_) { // handled: a key that is not base64 is no key; the routes answer terminal_not_configured
    return null;
  }
  if (bytes.length !== 32) return null;
  return await crypto.subtle.importKey("raw", bytes, "AES-GCM", false, ["encrypt", "decrypt"]);
}
const key = await tokenKey();

/** A bearer the installation's Auth accepts, with the sign-in and expiry of its own (now verified) claims. */
async function verify(bearer: string): Promise<Verified | null> {
  const { data, error } = await supabase.auth.getUser(bearer);
  if (error || !data.user) return null;
  try {
    const part = bearer.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    const claims = JSON.parse(atob(part + "=".repeat((4 - (part.length % 4)) % 4)));
    if (claims.sub !== data.user.id || typeof claims.session_id !== "string" || typeof claims.exp !== "number") return null;
    return { userId: data.user.id, sessionId: claims.session_id, expiresAt: new Date(claims.exp * 1000) };
  } catch (_) { // handled: a token whose claims cannot be read authorizes nothing
    return null;
  }
}

/** A call to the installation's REST endpoint as [bearer], its answer's bytes untouched (no JSON round trip). */
const rest: RestCall = async (fn, body, bearer) => {
  const res = await fetch(`${url}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { apikey: anonKey, authorization: `Bearer ${bearer}`, "content-type": "application/json" },
    body,
    signal: AbortSignal.timeout(15000),
  });
  return { status: res.status, bytes: new Uint8Array(await res.arrayBuffer()) };
};

Deno.serve(guard("embedded-till", (req) =>
  handle(req, {
    rpc: (fn, args) => supabase.rpc(fn, args),
    allow,
    verify,
    tokenKey: key,
    rest,
  })
));
