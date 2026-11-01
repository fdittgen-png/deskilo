// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The OAuth 2.0 authorisation-code exchange and refresh every accounting
// target shares. Pure: `fetch` is a parameter, so the tests play the
// token endpoint and no request leaves a test run.
//
// What leaves this module is never a token for the client: the caller
// stores the token set through `set_accounting_credentials` (service
// role, Vault) and answers the client with the connection's state only.

import type { OAuthTarget } from "./accounting_targets.ts";

export type Fetch = typeof fetch;

export interface OAuthClient {
  clientId: string;
  clientSecret: string;
}

export interface TokenSet {
  accessToken: string;
  refreshToken: string;
  /** When the access token stops working, if the endpoint said. */
  expiresAt: string | null;
  /** When the refresh token stops working, if the endpoint said. */
  refreshExpiresAt: string | null;
  scopes: string[];
}

/** Why a token exchange did not give a token set. */
export interface TokenFailure {
  /** `refused`: the endpoint said no (the grant is gone or wrong);
   * `unreachable`: no answer, or not one that could be read. */
  reason: "refused" | "unreachable";
  detail: string;
}

/** A state value: 32 random bytes, hex. */
export function newState(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Equal strings, compared in time independent of where they differ. */
export function sameSecret(a: string, b: string): boolean {
  if (a.length !== b.length || a.length === 0) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** The page the person signs in on. */
export function authorizeUrl(
  target: OAuthTarget,
  client: OAuthClient,
  redirectUri: string,
  state: string,
): string {
  const url = new URL(target.authorizeUrl);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("client_id", client.clientId);
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("scope", target.scopes.join(" "));
  url.searchParams.set("state", state);
  return url.toString();
}

/** An absolute instant [seconds] after [now], or null. */
function after(now: Date, seconds: unknown): string | null {
  const n = Number(seconds);
  return Number.isFinite(n) && n > 0
    ? new Date(now.getTime() + n * 1000).toISOString()
    : null;
}

async function tokenCall(
  fetchImpl: Fetch,
  target: OAuthTarget,
  client: OAuthClient,
  form: Record<string, string>,
  now: Date,
  previousRefresh = "",
): Promise<TokenSet | TokenFailure> {
  let res: Response;
  try {
    res = await fetchImpl(target.tokenUrl, {
      method: "POST",
      headers: {
        "content-type": "application/x-www-form-urlencoded",
        accept: "application/json",
        // client_secret_basic, which RFC 6749 §2.3.1 makes every
        // authorisation server accept: the default, no secret in the body.
        ...(target.clientAuth === "body"
          ? {}
          : { authorization: `Basic ${btoa(`${client.clientId}:${client.clientSecret}`)}` }),
      },
      // A target that documents it (HMRC) takes the client in the form of
      // this server-to-server request instead; it never reaches a browser.
      body: new URLSearchParams(
        target.clientAuth === "body"
          ? { ...form, client_id: client.clientId, client_secret: client.clientSecret }
          : { ...form, client_id: client.clientId },
      ).toString(),
    });
  } catch (error) {
    return { reason: "unreachable", detail: String(error).slice(0, 300) };
  }
  let body: Record<string, unknown> = {};
  try {
    body = await res.json();
  } catch {
    // not JSON: the status alone answers
  }
  if (!res.ok) {
    // The endpoint's error code (`invalid_grant`), never the request: it
    // carries the code or the refresh token.
    const code = typeof body.error === "string" ? body.error : `${res.status}`;
    return {
      reason: res.status >= 500 ? "unreachable" : "refused",
      detail: code.slice(0, 100),
    };
  }
  const access = typeof body.access_token === "string" ? body.access_token : "";
  if (!access) return { reason: "unreachable", detail: "no access_token" };
  return {
    accessToken: access,
    // A refresh answer may omit the refresh token: the old one stands.
    refreshToken: typeof body.refresh_token === "string"
      ? body.refresh_token
      : previousRefresh,
    expiresAt: after(now, body.expires_in),
    refreshExpiresAt: after(
      now,
      body.refresh_token_expires_in ?? body.x_refresh_token_expires_in,
    ),
    scopes: typeof body.scope === "string"
      ? body.scope.split(/[\s,]+/).filter((s) => s.length > 0)
      : target.scopes,
  };
}

/** The token set the authorisation [code] gives. */
export function exchangeCode(
  fetchImpl: Fetch,
  target: OAuthTarget,
  client: OAuthClient,
  code: string,
  redirectUri: string,
  now: Date,
): Promise<TokenSet | TokenFailure> {
  return tokenCall(fetchImpl, target, client, {
    grant_type: "authorization_code",
    code,
    redirect_uri: redirectUri,
  }, now);
}

/** A fresh token set from [refreshToken]. */
export function refreshTokens(
  fetchImpl: Fetch,
  target: OAuthTarget,
  client: OAuthClient,
  refreshToken: string,
  now: Date,
): Promise<TokenSet | TokenFailure> {
  return tokenCall(fetchImpl, target, client, {
    grant_type: "refresh_token",
    refresh_token: refreshToken,
  }, now, refreshToken);
}

/** Revokes [token] at the target (RFC 7009). Best effort and pure: the
 * answer is whether the target accepted it, and a refusal carries the
 * endpoint's error code at most, never the token or the request. A target
 * that documents no revocation endpoint answers `not_supported`. */
export async function revokeToken(
  fetchImpl: Fetch,
  target: OAuthTarget,
  client: OAuthClient,
  token: string,
  hint: "refresh_token" | "access_token",
): Promise<{ ok: true } | { ok: false; detail: string }> {
  if (!target.revokeUrl) return { ok: false, detail: "not_supported" };
  const json = target.revokeBody === "json";
  let res: Response;
  try {
    res = await fetchImpl(target.revokeUrl, {
      method: "POST",
      headers: {
        "content-type": json ? "application/json" : "application/x-www-form-urlencoded",
        accept: "application/json",
        authorization: `Basic ${btoa(`${client.clientId}:${client.clientSecret}`)}`,
      },
      body: json
        ? JSON.stringify({ token })
        : new URLSearchParams({ token, token_type_hint: hint }).toString(),
    });
  } catch {
    // The error text of a failed request may quote it: say only that
    // nothing answered.
    return { ok: false, detail: "unreachable" };
  }
  if (res.ok) return { ok: true };
  let code = `${res.status}`;
  try {
    const body = await res.json();
    if (typeof body?.error === "string") code = body.error;
  } catch {
    // not JSON: the status alone answers
  }
  return { ok: false, detail: code.slice(0, 100) };
}

export function isFailure(x: TokenSet | TokenFailure): x is TokenFailure {
  return "reason" in x;
}

/** What `set_accounting_credentials` stores for [tokens]: the secrets
 * (the state is spent) and the connection's new state. */
export function connectedWrite(tokens: TokenSet, tenant?: string): {
  secrets: Record<string, string>;
  patch: Record<string, unknown>;
} {
  return {
    secrets: {
      access_token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
      oauth_state: "",
      oauth_state_at: "",
    },
    patch: {
      status: "connected",
      status_detail: "",
      scopes: tokens.scopes,
      token_expires_at: tokens.expiresAt,
      refresh_expires_at: tokens.refreshExpiresAt,
      ...(tenant ? { remote_tenant_id: tenant } : {}),
    },
  };
}

/** The state a refused refresh leaves: expired, with the endpoint's word. */
export function expiredWrite(failure: TokenFailure): {
  secrets: Record<string, string>;
  patch: Record<string, unknown>;
} {
  return failure.reason === "refused"
    ? {
      secrets: { access_token: "", refresh_token: "" },
      patch: { status: "expired", status_detail: failure.detail },
    }
    : { secrets: {}, patch: { status_detail: failure.detail } };
}
