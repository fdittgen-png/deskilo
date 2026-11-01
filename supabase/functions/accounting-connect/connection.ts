// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What the sign-in and the delivery of `accounting-connect` share: the
// clients they are given, the installation's OAuth client of a target, the
// connection with its secrets (service role only) and the one writer of
// those secrets. No secret leaves this function in an answer.

import { CORS } from "../_shared/cors.ts";
import { clientEnvName } from "../_shared/accounting_targets.ts";
import type { Fetch, OAuthClient } from "../_shared/accounting_oauth.ts";

/** The width of `accounting_connections.status_detail` (0595): the most
 * of a target's words a connection keeps. */
export const STATUS_DETAIL_LENGTH = 500;

export const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type Db = {
  rpc: (
    fn: string,
    args: Record<string, unknown>,
  ) => PromiseLike<{ data: unknown; error: unknown }>;
};

/** A client bound to the caller's token that also reads tables, under the
 * caller's row-level security. */
export type CallerDb = Db & {
  from: (table: string) => {
    select: (columns: string) => {
      in: (
        column: string,
        values: string[],
      ) => PromiseLike<{ data: unknown; error: unknown }>;
    };
  };
};

export type Deps = {
  /** A client bound to the caller's own token. */
  caller: (authorization: string) => CallerDb;
  /** The service role: Vault reads and writes, and the delivery log. */
  service: () => Db;
  env: (name: string) => string | undefined;
  /** Where the target sends the person back: this function's URL. */
  redirectUri: string;
  fetcher?: Fetch;
  now?: () => Date;
};

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

export function clientOf(deps: Deps, targetId: string): OAuthClient | null {
  const clientId = deps.env(clientEnvName(targetId, "CLIENT_ID")) ?? "";
  const clientSecret = deps.env(clientEnvName(targetId, "CLIENT_SECRET")) ?? "";
  return clientId && clientSecret ? { clientId, clientSecret } : null;
}

/** The connection as `accounting_credentials_resolved` answers it. */
export type Resolved = {
  id: string;
  workspace_id: string;
  issuer_site_id: string;
  target_id: string;
  auth_kind: string;
  status: string;
  remote_tenant_id: string;
  revoked: boolean;
  token_expires_at: string | null;
  secrets: Record<string, string>;
};

export async function resolved(
  deps: Deps,
  connectionId: string,
): Promise<Resolved | null> {
  const { data, error } = await deps.service().rpc(
    "accounting_credentials_resolved",
    {
      p_connection_id: connectionId,
    },
  );
  return error || !data ? null : data as Resolved;
}

/** After a REFUSED refresh: whether another request already rotated the
 * single-use refresh token meanwhile (HMRC's refresh tokens are single-use,
 * so the second of two concurrent refreshes is refused though the connection
 * is fine). Gives the newer access token then, or null when the stored
 * refresh token is still the one that was refused. */
export async function rotatedMeanwhile(
  deps: Deps,
  connectionId: string,
  usedRefreshToken: string,
): Promise<string | null> {
  const again = await resolved(deps, connectionId);
  if (!again || again.revoked) return null;
  const current = again.secrets.refresh_token ?? "";
  const access = again.secrets.access_token ?? "";
  return current !== "" && current !== usedRefreshToken && access !== ""
    ? access
    : null;
}

export async function store(
  deps: Deps,
  connectionId: string,
  write: { secrets: Record<string, string>; patch: Record<string, unknown> },
): Promise<boolean> {
  const { error } = await deps.service().rpc("set_accounting_credentials", {
    p_connection_id: connectionId,
    p_secrets: write.secrets,
    p_patch: write.patch,
  });
  if (error) {
    console.error("accounting-connect: the credentials were not stored");
  }
  return !error;
}
