// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2393 — a bearer is checked HERE before Auth is asked: its signature
// against the project's published keys (JWKS, cached), its issuer and its
// expiry. A forged, unsigned, wrongly signed, foreign or expired token
// costs no Auth round-trip inside the request deadline. A token signed
// with a symmetric secret (a project still on the legacy HS256 key) cannot
// be verified without that secret: it is left to Auth, which `getUser`
// asks for every caller anyway, so a revoked session is still refused.
//
// Binding the token to this resource (RFC 8707 `resource` -> `aud`) waits
// for the authorization server to emit it; until then the installation id
// and the epoch headers are the binding (docs/guides/OPERATIONS.md).

import { createLocalJWKSet, decodeProtectedHeader, type JSONWebKeySet, jwtVerify } from "npm:jose@5.9.6";

export type LocalVerdict = "valid" | "invalid" | "unverifiable";

const TTL_MS = 10 * 60 * 1000;
let cache: { url: string; at: number; keys: JSONWebKeySet } | null = null;

/** The project's published signing keys, cached for ten minutes. */
async function keys(supabaseUrl: string, signal?: AbortSignal): Promise<JSONWebKeySet | null> {
  const url = `${supabaseUrl.replace(/\/+$/, "")}/auth/v1/.well-known/jwks.json`;
  if (cache && cache.url === url && Date.now() - cache.at < TTL_MS) return cache.keys;
  try {
    const res = await fetch(url, { signal });
    if (!res.ok) return null;
    const set = await res.json() as JSONWebKeySet;
    if (!Array.isArray(set?.keys)) return null;
    cache = { url, at: Date.now(), keys: set };
    return set;
  } catch {
    return null;
  }
}

/** Forgets the cached keys (tests, and a key rotation seen as a miss). */
export function forgetKeys(): void {
  cache = null;
}

/**
 * valid: signed by a published key of this project, issued by its Auth,
 * not expired. invalid: refuse without asking Auth. unverifiable: a
 * symmetric token or no published keys: Auth decides.
 */
export async function verifyLocally(token: string, supabaseUrl: string, signal?: AbortSignal): Promise<LocalVerdict> {
  let alg: string | undefined;
  try {
    alg = decodeProtectedHeader(token).alg;
  } catch {
    return "invalid";
  }
  if (!alg || alg.toLowerCase() === "none") return "invalid";
  if (alg.startsWith("HS")) return "unverifiable";
  const set = await keys(supabaseUrl, signal);
  if (set === null || set.keys.length === 0) return "unverifiable";
  try {
    await jwtVerify(token, createLocalJWKSet(set), {
      issuer: `${supabaseUrl.replace(/\/+$/, "")}/auth/v1`,
      algorithms: [alg],
    });
    return "valid";
  } catch {
    return "invalid";
  }
}
