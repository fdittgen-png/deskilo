// SPDX-License-Identifier: AGPL-3.0-or-later
//
// accounting-connect — signs an issuer in to an accounting target (OAuth
// 2.0 authorisation code) and keeps the connection's tokens fresh. No
// token ever reaches the client: they go to Vault through
// `set_accounting_credentials` (service role), and the client reads the
// connection's state only (`accounting_connections_v1`).
//
//   POST {action: "authorize", workspace_id, issuer_site_id, target_id,
//         display_name}
//        The caller (their own token) opens a pending connection, which
//        `open_accounting_connection_v1` allows only to a billing manager
//        of a space with accountingConnectors on. The answer is the
//        target's sign-in page; its `state` names the connection and a
//        random value kept in Vault.
//   GET  ?code&state  (the target's redirect, no bearer token)
//        #3906 — stores nothing and calls no target: the browser is sent
//        on to the app's page (`DESKILO_APP_URL`/#/accounting/connected)
//        with the code and the state.
//   POST {action: "complete", code, state, error?, tenant?}
//        The signed-in person who may manage the connection completes the
//        sign-in: the state is checked against Vault (and its age) before
//        the code is exchanged; the tokens are stored, the state is spent,
//        the connection is connected. A refused exchange leaves it in
//        `error`, said. A target that checks the company first
//        (QuickBooks: its country and its own numbering; Xero: the one
//        organisation the sign-in authorised, and its country) refuses it
//        before it is connected, and a connection signed in again keeps
//        its company.
//   POST {action: "refresh", connection_id}
//        A billing manager asks for a fresh token; a refused refresh marks
//        the connection expired, which the screen shows.
//   POST {action: "deliver", connection_id, from, to, document?}
//        A billing manager delivers a period's postings, or one document
//        again, through the delivery kit (deliver.ts).
//   POST {action: "revoke" | "verify", connection_id}
//        Revoking a connection here and at the target (RFC 7009), and
//        checking that a token reaches its company (lifecycle.ts).
//
// An installation that registered no OAuth application with a target
// answers 503 `oauth_not_configured` before anything is opened.

import { refuseDelegated } from "../_shared/delegated.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { CORS, preflight } from "../_shared/cors.ts";
import {
  type OAuthTarget,
  oauthTargets,
} from "../_shared/accounting_targets.ts";
import {
  authorizeUrl,
  connectedWrite,
  exchangeCode,
  isFailure,
  newState,
  refreshTokens,
  sameSecret,
} from "../_shared/accounting_oauth.ts";
import {
  clientOf,
  type Deps,
  json,
  manageableRpc,
  refreshExclusive,
  resolved,
  STATUS_DETAIL_LENGTH,
  store,
  targetIdOf,
  targetOf,
  UUID,
} from "./connection.ts";
import { adapterContext, deliverPeriod, deliveryAdapters } from "./deliver.ts";
import { hmrcObligations, hmrcSubmit, hmrcValidateHeaders } from "./hmrc.ts";
import { revoke, verify } from "./lifecycle.ts";

export type { Deps } from "./connection.ts";

/** The most a request body may weigh: ids and a display name. A protocol
 * bound on the request's shape, not a choice. */
export const MAX_BODY_BYTES = 4096;

/** The page the browser shows after the redirect: plain words, no data. */
const page = (text: string, status = 200) =>
  new Response(text, {
    status,
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });

async function authorize(
  deps: Deps,
  authorization: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const targetId = typeof body.target_id === "string" ? body.target_id : "";
  const target: OAuthTarget | undefined = targetOf(deps, targetId);
  if (!target) return json({ error: "this target is not signed in to" }, 400);
  const workspaceId = typeof body.workspace_id === "string"
    ? body.workspace_id
    : "";
  const issuer = typeof body.issuer_site_id === "string"
    ? body.issuer_site_id
    : "";
  if (!UUID.test(workspaceId) || !UUID.test(issuer)) {
    return json({ error: "workspace_id and issuer_site_id required" }, 400);
  }
  const client = clientOf(deps, targetId);
  if (!client) return json({ error: "oauth_not_configured" }, 503);
  // The database decides who may connect, with the caller's own token: a
  // new connection, or signing an existing one in again.
  const again = typeof body.connection_id === "string"
    ? body.connection_id
    : "";
  const opened = again
    ? await deps.caller(authorization).rpc(manageableRpc(targetId), {
      p_connection_id: again,
    })
    : targetId === "hmrc_mtd"
    ? await deps.caller(authorization).rpc("open_hmrc_connection_v1", {
      p_workspace_id: workspaceId,
      p_issuer_site_id: issuer,
      p_display_name: typeof body.display_name === "string" ? body.display_name : "",
    })
    : await deps.caller(authorization).rpc("open_accounting_connection_v1", {
      p_workspace_id: workspaceId,
      p_issuer_site_id: issuer,
      p_target_id: targetId,
      p_auth_kind: "oauth2",
      p_display_name: typeof body.display_name === "string"
        ? body.display_name
        : "",
    });
  const row = opened.data as {
    id?: string;
    target_id?: string;
    auth_kind?: string;
  } | null;
  if (
    opened.error || !row?.id || row.target_id !== targetId ||
    row.auth_kind !== "oauth2"
  ) {
    return json({ error: "not allowed to connect this issuer" }, 403);
  }
  const connectionId = String(row.id);
  const state = newState();
  const issuedAt = (deps.now ?? (() => new Date()))().toISOString();
  if (
    !await store(deps, connectionId, {
      secrets: { oauth_state: state, oauth_state_at: issuedAt },
      patch: {},
    })
  ) {
    return json({ error: "the connection could not be prepared" }, 500);
  }
  return json({
    connection_id: connectionId,
    authorize_url: authorizeUrl(
      target,
      client,
      deps.redirectUri,
      `${connectionId}.${state}`,
    ),
  });
}

/** #3906 — the app's page that completes a target's sign-in. */
function returnRoute(deps: Deps): string | null {
  const base = (deps.env("DESKILO_APP_URL") ?? "").replace(/\/+$/, "");
  // The web app routes by fragment.
  return base ? `${base}/#/accounting/connected` : null;
}

/** The longest value passed on from the target's redirect. */
const FORWARDED_LENGTH = 2048;

/** The names a target's redirect gives the company it signed in to. */
const TENANT_PARAMS = [
  ...new Set(
    Object.values(oauthTargets).flatMap((t) => t.tenantParam ? [t.tenantParam] : []),
  ),
];

/** #3906 — the target's redirect stores nothing and calls no target: it
 * passes the code and the state on to the app's page, where the signed-in
 * person completes the sign-in (`complete`). */
function callback(deps: Deps, url: URL): Response {
  const [connectionId, secret] = (url.searchParams.get("state") ?? "").split(
    ".",
  );
  if (!UUID.test(connectionId ?? "") || !secret) {
    return page("This sign-in link is not valid.", 400);
  }
  const back = returnRoute(deps);
  if (!back) return page("This server cannot sign in to this target.", 503);
  const query = new URLSearchParams();
  const pass = (from: string, to = from) => {
    const value = url.searchParams.get(from);
    if (value) query.set(to, value.slice(0, FORWARDED_LENGTH));
  };
  pass("code");
  pass("state");
  pass("error");
  for (const name of TENANT_PARAMS) pass(name, "tenant");
  return new Response(null, {
    status: 302,
    headers: {
      Location: `${back}?${query}`,
      "Cache-Control": "no-store",
      "Referrer-Policy": "no-referrer",
    },
  });
}

/** Text of a body field, or empty. */
const field = (body: Record<string, unknown>, key: string) =>
  typeof body[key] === "string" ? (body[key] as string) : "";

/** #3906 — the sign-in completed by the person who may manage the
 * connection, with their own session: the state must be the one this
 * connection holds and still fresh; then the code is exchanged. The state
 * is spent on every outcome past its check. */
async function complete(
  deps: Deps,
  authorization: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const [connectionId, secret] = field(body, "state").split(".");
  if (!UUID.test(connectionId ?? "") || !secret) {
    return json({ error: "state_invalid" }, 400);
  }
  const allowed = await deps.caller(authorization).rpc(
    manageableRpc(await targetIdOf(deps, connectionId)),
    { p_connection_id: connectionId },
  );
  const held = await resolved(deps, connectionId);
  const matches = !!held && !held.revoked &&
    sameSecret(held.secrets.oauth_state ?? "", secret);
  const spend = (patch: Record<string, unknown> = {}) =>
    store(deps, connectionId, {
      secrets: { oauth_state: "", oauth_state_at: "" },
      patch,
    });
  if (allowed.error || !allowed.data) {
    if (matches) await spend();
    return json({ error: "not allowed to manage this connection" }, 403);
  }
  if (!held || !matches) return json({ error: "state_invalid" }, 400);
  const target = targetOf(deps, held.target_id);
  const client = target ? clientOf(deps, held.target_id) : null;
  if (!target || !client) {
    await spend();
    return json({ error: "oauth_not_configured" }, 503);
  }
  const now = (deps.now ?? (() => new Date()))();
  const issuedAt = Date.parse(held.secrets.oauth_state_at ?? "");
  if (
    !Number.isFinite(issuedAt) ||
    now.getTime() - issuedAt > target.stateLifetimeMs
  ) {
    await spend();
    return json({ error: "state_expired" }, 400);
  }
  const code = field(body, "code");
  if (!code) {
    await spend({
      status: "error",
      status_detail: (field(body, "error") || "access_denied").slice(0, 100),
    });
    return json({ error: "sign_in_not_completed" }, 400);
  }
  const tokens = await exchangeCode(
    deps.fetcher ?? fetch,
    target,
    client,
    code,
    deps.redirectUri,
    now,
  );
  if (isFailure(tokens)) {
    await spend({ status: "error", status_detail: tokens.detail });
    return json({ error: "sign_in_refused" }, 502);
  }
  const adapterOf = deliveryAdapters[held.target_id];
  let tenant = target.tenantParam ? field(body, "tenant") || undefined : undefined;
  let refused: string | null = null;
  // A target whose redirect names no company (Xero): the one the sign-in
  // authorised, read with the new token.
  const signedIn = !target.tenantParam
    ? await adapterOf?.(
      adapterContext(deps, held.target_id, tokens.accessToken, ""),
    ).signedInTenant?.()
    : undefined;
  if (signedIn && "refused" in signedIn) refused = signedIn.refused;
  if (signedIn && "tenant" in signedIn) tenant = signedIn.tenant;
  // A connection signed in again stays the company it was made for.
  if (
    !refused && tenant && held.remote_tenant_id &&
    tenant !== held.remote_tenant_id
  ) {
    refused =
      "this sign-in reached another company than the one this connection was made for";
  }
  refused ??= await adapterOf?.(
    adapterContext(deps, held.target_id, tokens.accessToken, tenant ?? ""),
  ).prepare() ?? null;
  if (refused) {
    await spend({
      status: "error",
      status_detail: refused.slice(0, STATUS_DETAIL_LENGTH),
    });
    return json({ error: "company_refused" }, 409);
  }
  if (!await store(deps, connectionId, connectedWrite(tokens, tenant))) {
    await spend();
    return json({ error: "the connection could not be saved" }, 500);
  }
  return json({ status: "connected", connection_id: connectionId });
}

async function refresh(
  deps: Deps,
  authorization: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const connectionId = typeof body.connection_id === "string"
    ? body.connection_id
    : "";
  if (!UUID.test(connectionId)) {
    return json({ error: "connection_id required" }, 400);
  }
  // Which door asks is read without the secrets; they are decrypted only
  // once the database has said the caller may manage the connection.
  const allowed = await deps.caller(authorization).rpc(
    manageableRpc(await targetIdOf(deps, connectionId)),
    { p_connection_id: connectionId },
  );
  if (allowed.error || !allowed.data) {
    return json({ error: "not allowed to manage this connection" }, 403);
  }
  const held = await resolved(deps, connectionId);
  const target = held ? targetOf(deps, held.target_id) : undefined;
  if (!held || held.auth_kind !== "oauth2" || !target) {
    return json({ error: "this connection is not signed in to" }, 400);
  }
  const client = clientOf(deps, held.target_id);
  if (!client) return json({ error: "oauth_not_configured" }, 503);
  const refreshToken = held.secrets.refresh_token ?? "";
  const now = (deps.now ?? (() => new Date()))();
  // One refresh at a time per connection, across every writer (single-use
  // refresh tokens): the lease first, then the provider.
  const result = await refreshExclusive(
    deps,
    connectionId,
    refreshToken,
    (token) => refreshTokens(deps.fetcher ?? fetch, target, client, token, now),
  );
  switch (result.status) {
    case "refreshed":
    case "rotated":
      return json({ status: "connected" });
    case "failed":
      return json({ status: "expired" });
    case "busy":
      return json({ error: "refresh_busy" }, 503);
    default:
      return json({ error: "this connection is not signed in to" }, 400);
  }
}

export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return preflight();
  // The target's redirect carries no bearer: it is passed on to the app.
  if (req.method === "GET") return callback(deps, new URL(req.url));
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  // #1614 — an assistant's delegated token never connects the books.
  const delegated = refuseDelegated(req, CORS);
  if (delegated) return delegated;
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization) return json({ error: "not signed in" }, 401);
  const text = await req.text();
  if (text.length > MAX_BODY_BYTES) {
    return json({ error: "body too large" }, 400);
  }
  let body: Record<string, unknown>;
  try {
    const parsed = JSON.parse(text);
    if (typeof parsed !== "object" || parsed === null) {
      throw new Error("not an object");
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return json({ error: "invalid body" }, 400);
  }
  switch (body.action) {
    case "authorize":
      return authorize(deps, authorization, body);
    case "complete":
      return complete(deps, authorization, body);
    case "refresh":
      return refresh(deps, authorization, body);
    case "deliver":
      return deliverPeriod(deps, authorization, body);
    case "revoke":
      return revoke(deps, authorization, body);
    case "verify":
      return verify(deps, authorization, body);
    case "hmrc_obligations":
      return hmrcObligations(deps, req, authorization, body);
    case "hmrc_submit":
      return hmrcSubmit(deps, req, authorization, body);
    case "hmrc_validate_headers":
      return hmrcValidateHeaders(deps, req, authorization, body);
    default:
      return json({ error: "unknown action" }, 400);
  }
}

if (import.meta.main) {
  const url = Deno.env.get("SUPABASE_URL")!;
  const deps: Deps = {
    caller: (authorization) => {
      const client = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
        global: { headers: { Authorization: authorization } },
      });
      return {
        rpc: (fn, args) => client.rpc(fn, args),
        from: (table) => ({
          select: (columns) => ({
            in: (column, values) =>
              client.from(table).select(columns).in(column, values),
          }),
        }),
      };
    },
    service: () =>
      createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!),
    env: (name) => Deno.env.get(name),
    redirectUri: `${url}/functions/v1/accounting-connect`,
  };
  Deno.serve((req) => handle(req, deps));
}
