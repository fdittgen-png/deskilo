// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What the sign-in and the delivery of `accounting-connect` share: the
// clients they are given, the installation's OAuth client of a target, the
// connection with its secrets (service role only) and the one writer of
// those secrets. No secret leaves this function in an answer.

import { CORS } from "../_shared/cors.ts";
import {
  clientEnvName,
  type OAuthTarget,
  oauthTargets,
} from "../_shared/accounting_targets.ts";
import { hmrcEndpoints } from "../_shared/hmrc_endpoints.ts";
import { hmrcTarget } from "../_shared/hmrc_mtd.ts";
import {
  connectedWrite,
  expiredWrite,
  isFailure,
} from "../_shared/accounting_oauth.ts";
import type {
  Fetch,
  OAuthClient,
  TokenFailure,
  TokenSet,
} from "../_shared/accounting_oauth.ts";

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
  /** Waiting for another writer's refresh; injected so tests do not wait. */
  sleep?: (ms: number) => Promise<void>;
};

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

/** The OAuth description of target [id]: the static table, or HMRC's, which
 * takes its hosts from the installation's chosen environment (exact approved
 * origins, never a client value). Undefined when the target is not signed in
 * to, or HMRC is not configured. */
export function targetOf(
  deps: Pick<Deps, "env">,
  id: string,
): OAuthTarget | undefined {
  if (id === "hmrc_mtd") {
    const e = hmrcEndpoints(deps.env);
    return e ? hmrcTarget(e.api, e.signIn) : undefined;
  }
  return oauthTargets[id];
}

/** The caller-token door that says whether the person may manage a
 * connection of [targetId]: HMRC has its own (MTD's flag and the owner right,
 * not accountingConnectors). */
export const manageableRpc = (targetId: string | undefined) =>
  targetId === "hmrc_mtd" ? "hmrc_connection_manageable_v1" : "accounting_connection_manageable_v1";

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

/** How long one writer may hold a connection's refresh, and how long and
 * how often another waits for it. */
export const REFRESH_LEASE_SECONDS = 30;
export const REFRESH_POLL_MS = 250;
export const REFRESH_POLL_MAX = 40;

export type Refreshed =
  | { status: "refreshed" | "rotated"; accessToken: string }
  | { status: "failed"; failure: TokenFailure }
  | { status: "busy" | "gone" };

/** Refreshes the connection's token set EXACTLY ONCE across every writer.
 * HMRC's refresh tokens are single-use, so a writer claims the
 * connection's lease before it calls the token endpoint; any other writer
 * waits and re-reads, and takes the pair the first one stored. A loser
 * therefore never spends a spent token and never clears the winner's pair.
 * [run] performs the provider call with the refresh token held at that
 * moment. */
export async function refreshExclusive(
  deps: Deps,
  connectionId: string,
  seenRefreshToken: string,
  run: (refreshToken: string) => Promise<TokenSet | TokenFailure>,
): Promise<Refreshed> {
  const holder = crypto.randomUUID();
  const sleep = deps.sleep ??
    ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  let claimed = false;
  for (let attempt = 0; attempt < REFRESH_POLL_MAX && !claimed; attempt++) {
    const { data, error } = await deps.service().rpc(
      "claim_accounting_refresh_lease",
      {
        p_connection_id: connectionId,
        p_holder: holder,
        p_seconds: REFRESH_LEASE_SECONDS,
      },
    );
    if (error) return { status: "busy" };
    if (data === true) {
      claimed = true;
      break;
    }
    // Someone else holds it: their pair may be stored already.
    const rotated = await rotatedMeanwhile(
      deps,
      connectionId,
      seenRefreshToken,
    );
    if (rotated) return { status: "rotated", accessToken: rotated };
    await sleep(REFRESH_POLL_MS);
  }
  if (!claimed) return { status: "busy" };
  try {
    const held = await resolved(deps, connectionId);
    if (!held || held.revoked) return { status: "gone" };
    const current = held.secrets.refresh_token ?? "";
    if (current === "") {
      return {
        status: "failed",
        failure: { reason: "refused", detail: "no refresh token" },
      };
    }
    // Another writer finished between our read and our claim.
    if (
      current !== seenRefreshToken && (held.secrets.access_token ?? "") !== ""
    ) {
      return { status: "rotated", accessToken: held.secrets.access_token };
    }
    const tokens = await run(current);
    if (isFailure(tokens)) {
      // A writer outside the lease may still have rotated the pair.
      const rotated = await rotatedMeanwhile(deps, connectionId, current);
      if (rotated) return { status: "rotated", accessToken: rotated };
      await storeLeased(deps, connectionId, holder, expiredWrite(tokens));
      return { status: "failed", failure: tokens };
    }
    if (!await storeLeased(deps, connectionId, holder, connectedWrite(tokens))) {
      return { status: "busy" };
    }
    return { status: "refreshed", accessToken: tokens.accessToken };
  } finally {
    await deps.service().rpc("release_accounting_refresh_lease", {
      p_connection_id: connectionId,
      p_holder: holder,
    });
  }
}

/** The same write, but only while [holder] still holds the connection's
 * refresh lease: the database refuses (55P03) a writer whose lease ran out,
 * so a slow refresh cannot overwrite the pair a later holder stored. */
export async function storeLeased(
  deps: Deps,
  connectionId: string,
  holder: string,
  write: { secrets: Record<string, string>; patch: Record<string, unknown> },
): Promise<boolean> {
  const { error } = await deps.service().rpc("set_accounting_credentials_leased", {
    p_connection_id: connectionId,
    p_holder: holder,
    p_secrets: write.secrets,
    p_patch: write.patch,
  });
  if (error) console.error("accounting-connect: the credentials were not stored (lease)");
  return !error;
}

/** The target of a connection, read WITHOUT its secrets: which door to use
 * is decided before anything is decrypted. */
export async function targetIdOf(deps: Deps, connectionId: string): Promise<string | undefined> {
  const { data, error } = await deps.service().rpc("accounting_connection_target_v1", {
    p_connection_id: connectionId,
  });
  return !error && typeof data === "string" ? data : undefined;
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
