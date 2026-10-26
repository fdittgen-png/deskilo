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
//        The state is checked against Vault before the code is exchanged;
//        the tokens are stored, the state is spent, the connection is
//        connected. A refused exchange leaves it in `error`, said.
//   POST {action: "refresh", connection_id}
//        A billing manager asks for a fresh token; a refused refresh marks
//        the connection expired, which the screen shows.
//
// An installation that registered no OAuth application with a target
// answers 503 `oauth_not_configured` before anything is opened.

import { refuseDelegated } from "../_shared/delegated.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { CORS, preflight } from "../_shared/cors.ts";
import { clientEnvName, type OAuthTarget, oauthTargets } from "../_shared/accounting_targets.ts";
import {
  authorizeUrl,
  connectedWrite,
  exchangeCode,
  expiredWrite,
  type Fetch,
  isFailure,
  newState,
  type OAuthClient,
  refreshTokens,
  sameSecret,
} from "../_shared/accounting_oauth.ts";

/** The most a request body may weigh: ids and a display name. A protocol
 * bound on the request's shape, not a choice. */
export const MAX_BODY_BYTES = 4096;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Db = {
  rpc: (fn: string, args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: unknown }>;
};

export type Deps = {
  /** A client bound to the caller's own token. */
  caller: (authorization: string) => Db;
  /** The service role: Vault reads and writes only. */
  service: () => Db;
  env: (name: string) => string | undefined;
  /** Where the target sends the person back: this function's URL. */
  redirectUri: string;
  fetcher?: Fetch;
  now?: () => Date;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

/** The page the browser shows after the redirect: plain words, no data. */
const page = (text: string, status = 200) =>
  new Response(text, { status, headers: { "Content-Type": "text/plain; charset=utf-8" } });

function clientOf(deps: Deps, targetId: string): OAuthClient | null {
  const clientId = deps.env(clientEnvName(targetId, "CLIENT_ID")) ?? "";
  const clientSecret = deps.env(clientEnvName(targetId, "CLIENT_SECRET")) ?? "";
  return clientId && clientSecret ? { clientId, clientSecret } : null;
}

type Resolved = {
  id: string;
  target_id: string;
  auth_kind: string;
  revoked: boolean;
  secrets: Record<string, string>;
};

async function resolved(deps: Deps, connectionId: string): Promise<Resolved | null> {
  const { data, error } = await deps.service().rpc("accounting_credentials_resolved", {
    p_connection_id: connectionId,
  });
  return error || !data ? null : data as Resolved;
}

async function store(
  deps: Deps,
  connectionId: string,
  write: { secrets: Record<string, string>; patch: Record<string, unknown> },
): Promise<boolean> {
  const { error } = await deps.service().rpc("set_accounting_credentials", {
    p_connection_id: connectionId,
    p_secrets: write.secrets,
    p_patch: write.patch,
  });
  if (error) console.error("accounting-connect: the credentials were not stored");
  return !error;
}

async function authorize(
  deps: Deps,
  authorization: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const targetId = typeof body.target_id === "string" ? body.target_id : "";
  const target: OAuthTarget | undefined = oauthTargets[targetId];
  if (!target) return json({ error: "this target is not signed in to" }, 400);
  const workspaceId = typeof body.workspace_id === "string" ? body.workspace_id : "";
  const issuer = typeof body.issuer_site_id === "string" ? body.issuer_site_id : "";
  if (!UUID.test(workspaceId) || !UUID.test(issuer)) {
    return json({ error: "workspace_id and issuer_site_id required" }, 400);
  }
  const client = clientOf(deps, targetId);
  if (!client) return json({ error: "oauth_not_configured" }, 503);
  // The database decides who may connect, with the caller's own token: a
  // new connection, or signing an existing one in again.
  const again = typeof body.connection_id === "string" ? body.connection_id : "";
  const opened = again
    ? await deps.caller(authorization).rpc("accounting_connection_manageable_v1", {
      p_connection_id: again,
    })
    : await deps.caller(authorization).rpc("open_accounting_connection_v1", {
      p_workspace_id: workspaceId,
      p_issuer_site_id: issuer,
      p_target_id: targetId,
      p_auth_kind: "oauth2",
      p_display_name: typeof body.display_name === "string" ? body.display_name : "",
    });
  const row = opened.data as { id?: string; target_id?: string; auth_kind?: string } | null;
  if (opened.error || !row?.id || row.target_id !== targetId || row.auth_kind !== "oauth2") {
    return json({ error: "not allowed to connect this issuer" }, 403);
  }
  const connectionId = String(row.id);
  const state = newState();
  const issuedAt = (deps.now ?? (() => new Date()))().toISOString();
  if (!await store(deps, connectionId, { secrets: { oauth_state: state, oauth_state_at: issuedAt }, patch: {} })) {
    return json({ error: "the connection could not be prepared" }, 500);
  }
  return json({
    connection_id: connectionId,
    authorize_url: authorizeUrl(target, client, deps.redirectUri, `${connectionId}.${state}`),
  });
}

async function callback(deps: Deps, url: URL): Promise<Response> {
  const [connectionId, state] = (url.searchParams.get("state") ?? "").split(".");
  const code = url.searchParams.get("code") ?? "";
  if (!UUID.test(connectionId ?? "") || !state) return page("This sign-in link is not valid.", 400);
  const held = await resolved(deps, connectionId);
  if (!held || held.revoked || !sameSecret(held.secrets.oauth_state ?? "", state)) {
    return page("This sign-in link is not valid any more.", 400);
  }
  const target = oauthTargets[held.target_id];
  const client = target ? clientOf(deps, held.target_id) : null;
  if (!target || !client) return page("This server cannot sign in to this target.", 503);
  const now = (deps.now ?? (() => new Date()))();
  const issuedAt = Date.parse(held.secrets.oauth_state_at ?? "");
  if (!Number.isFinite(issuedAt) || now.getTime() - issuedAt > target.stateLifetimeMs) {
    await store(deps, connectionId, { secrets: { oauth_state: "", oauth_state_at: "" }, patch: {} });
    return page("This sign-in link has expired. Start again from DesKilo.", 400);
  }
  if (!code) {
    const denied = (url.searchParams.get("error") ?? "access_denied").slice(0, 100);
    await store(deps, connectionId, {
      secrets: { oauth_state: "", oauth_state_at: "" },
      patch: { status: "error", status_detail: denied },
    });
    return page("The sign-in was not completed. You can close this page.", 400);
  }
  const tokens = await exchangeCode(deps.fetcher ?? fetch, target, client, code, deps.redirectUri, now);
  if (isFailure(tokens)) {
    await store(deps, connectionId, {
      secrets: { oauth_state: "", oauth_state_at: "" },
      patch: { status: "error", status_detail: tokens.detail },
    });
    return page("The target refused the sign-in. You can close this page and try again.", 502);
  }
  const tenant = target.tenantParam ? url.searchParams.get(target.tenantParam) ?? undefined : undefined;
  if (!await store(deps, connectionId, connectedWrite(tokens, tenant))) {
    return page("The connection could not be saved. You can close this page and try again.", 500);
  }
  return page("The connection is made. You can close this page and return to DesKilo.");
}

async function refresh(
  deps: Deps,
  authorization: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const connectionId = typeof body.connection_id === "string" ? body.connection_id : "";
  if (!UUID.test(connectionId)) return json({ error: "connection_id required" }, 400);
  const allowed = await deps.caller(authorization).rpc("accounting_connection_manageable_v1", {
    p_connection_id: connectionId,
  });
  if (allowed.error || !allowed.data) return json({ error: "not allowed to manage this connection" }, 403);
  const held = await resolved(deps, connectionId);
  const target = held ? oauthTargets[held.target_id] : undefined;
  if (!held || held.auth_kind !== "oauth2" || !target) {
    return json({ error: "this connection is not signed in to" }, 400);
  }
  const client = clientOf(deps, held.target_id);
  if (!client) return json({ error: "oauth_not_configured" }, 503);
  const refreshToken = held.secrets.refresh_token ?? "";
  const now = (deps.now ?? (() => new Date()))();
  const tokens = refreshToken
    ? await refreshTokens(deps.fetcher ?? fetch, target, client, refreshToken, now)
    : { reason: "refused" as const, detail: "no refresh token" };
  const write = isFailure(tokens) ? expiredWrite(tokens) : connectedWrite(tokens);
  if (!await store(deps, connectionId, write)) return json({ error: "the connection could not be saved" }, 500);
  return json({ status: write.patch.status ?? "unchanged" });
}

export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return preflight();
  // The target's redirect carries no bearer: the state is its authority.
  if (req.method === "GET") return callback(deps, new URL(req.url));
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  // #1614 — an assistant's delegated token never connects the books.
  const delegated = refuseDelegated(req, CORS);
  if (delegated) return delegated;
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization) return json({ error: "not signed in" }, 401);
  const text = await req.text();
  if (text.length > MAX_BODY_BYTES) return json({ error: "body too large" }, 400);
  let body: Record<string, unknown>;
  try {
    const parsed = JSON.parse(text);
    if (typeof parsed !== "object" || parsed === null) throw new Error("not an object");
    body = parsed as Record<string, unknown>;
  } catch {
    return json({ error: "invalid body" }, 400);
  }
  switch (body.action) {
    case "authorize":
      return authorize(deps, authorization, body);
    case "refresh":
      return refresh(deps, authorization, body);
    default:
      return json({ error: "unknown action" }, 400);
  }
}

if (import.meta.main) {
  const url = Deno.env.get("SUPABASE_URL")!;
  const deps: Deps = {
    caller: (authorization) =>
      createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
        global: { headers: { Authorization: authorization } },
      }),
    service: () => createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!),
    env: (name) => Deno.env.get(name),
    redirectUri: `${url}/functions/v1/accounting-connect`,
  };
  Deno.serve((req) => handle(req, deps));
}
