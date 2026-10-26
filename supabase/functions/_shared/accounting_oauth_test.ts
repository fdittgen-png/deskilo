// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The OAuth exchange: what is asked of the token endpoint, what comes back
// as a token set, and that a refusal never carries the code or a token.
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  authorizeUrl,
  connectedWrite,
  exchangeCode,
  expiredWrite,
  isFailure,
  newState,
  refreshTokens,
  sameSecret,
  type TokenSet,
} from "./accounting_oauth.ts";
import { clientEnvName, oauthTargets } from "./accounting_targets.ts";

const target = oauthTargets.pennylane_api;
const client = { clientId: "app-id", clientSecret: "app-secret" };
const now = new Date("2026-10-25T10:00:00Z");

const answering = (status: number, body: unknown, seen?: RequestInit[]) =>
  ((_url: string | URL | Request, init?: RequestInit) => {
    seen?.push(init!);
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  }) as typeof fetch;

Deno.test("the sign-in page carries the client, the redirect, the scopes and the state", () => {
  const url = new URL(authorizeUrl(target, client, "https://x.test/functions/v1/accounting-connect", "c.s"));
  assertEquals(url.origin + url.pathname, target.authorizeUrl);
  assertEquals(url.searchParams.get("client_id"), "app-id");
  assertEquals(url.searchParams.get("state"), "c.s");
  assertEquals(url.searchParams.get("scope"), target.scopes.join(" "));
  assertEquals(url.searchParams.get("client_secret"), null);
});

Deno.test("a code becomes a token set with absolute expiries; the secret travels as basic auth", async () => {
  const seen: RequestInit[] = [];
  const tokens = await exchangeCode(answering(200, {
    access_token: "at",
    refresh_token: "rt",
    expires_in: 3600,
    refresh_token_expires_in: 86400,
    scope: "customers:all ledger_entries:all",
  }, seen), target, client, "the-code", "https://x.test/cb", now) as TokenSet;
  assertEquals(tokens, {
    accessToken: "at",
    refreshToken: "rt",
    expiresAt: "2026-10-25T11:00:00.000Z",
    refreshExpiresAt: "2026-10-26T10:00:00.000Z",
    scopes: ["customers:all", "ledger_entries:all"],
  });
  const body = new URLSearchParams(String(seen[0].body));
  assertEquals(body.get("grant_type"), "authorization_code");
  assertEquals(body.get("code"), "the-code");
  assertEquals(body.get("client_secret"), null);
  assertEquals((seen[0].headers as Record<string, string>).authorization, `Basic ${btoa("app-id:app-secret")}`);
});

Deno.test("a refusal names the endpoint's error code only", async () => {
  const failed = await exchangeCode(
    answering(400, { error: "invalid_grant", error_description: "code the-code expired" }),
    target, client, "the-code", "https://x.test/cb", now,
  );
  assert(isFailure(failed));
  assertEquals(failed, { reason: "refused", detail: "invalid_grant" });
});

Deno.test("no answer is unreachable, not refused", async () => {
  const failed = await exchangeCode(
    (() => Promise.reject(new TypeError("network"))) as typeof fetch,
    target, client, "c", "https://x.test/cb", now,
  );
  assert(isFailure(failed));
  assertEquals(failed.reason, "unreachable");
  const down = await refreshTokens(answering(503, {}), target, client, "rt", now);
  assert(isFailure(down));
  assertEquals(down.reason, "unreachable");
});

Deno.test("a refresh without a new refresh token keeps the old one", async () => {
  const tokens = await refreshTokens(answering(200, { access_token: "at2" }), target, client, "rt", now) as TokenSet;
  assertEquals(tokens.refreshToken, "rt");
  assertEquals(tokens.expiresAt, null);
  assertEquals(tokens.scopes, target.scopes);
});

Deno.test("connected spends the state; a refused refresh expires and forgets the tokens", () => {
  const write = connectedWrite({ accessToken: "a", refreshToken: "r", expiresAt: null, refreshExpiresAt: null, scopes: [] }, "realm-1");
  assertEquals(write.secrets.oauth_state, "");
  assertEquals(write.patch.status, "connected");
  assertEquals(write.patch.remote_tenant_id, "realm-1");
  assertEquals(expiredWrite({ reason: "refused", detail: "invalid_grant" }), {
    secrets: { access_token: "", refresh_token: "" },
    patch: { status: "expired", status_detail: "invalid_grant" },
  });
  assertEquals(expiredWrite({ reason: "unreachable", detail: "503" }).patch.status, undefined);
});

Deno.test("states are random and compared whole", () => {
  const a = newState();
  assertEquals(a.length, 64);
  assert(a !== newState());
  assert(sameSecret(a, a));
  assert(!sameSecret(a, a.slice(0, 63) + "x"));
  assert(!sameSecret("", ""));
});

Deno.test("the client's environment names follow the target id", () => {
  assertEquals(clientEnvName("pennylane_api", "CLIENT_ID"), "ACCOUNTING_PENNYLANE_API_CLIENT_ID");
});
