// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The end of a connection and the check of its company.
//
//   POST {action: "revoke", connection_id}
//        A billing manager revokes the connection. The database revokes it
//        first (the Vault is cleared, nothing can deliver any more), with
//        the caller's own token; then, where the target documents a
//        revocation endpoint (RFC 7009), the refresh token it held (else
//        the access token) is revoked there too. That second step is best
//        effort: whatever the target answers, the connection stays revoked
//        here, and the answer says `remote_revocation`: `revoked`,
//        `failed` or `not_supported` (a target without an endpoint, or a
//        connection made by an API token, which only the company can
//        withdraw). That outcome is recorded on the revoked connection
//        (service role, 0644), and the app tells the person to remove
//        DesKilo in the target's settings when it is not `revoked`. The
//        token is never logged and never in an answer.
//   POST {action: "verify", connection_id}
//        A billing manager checks that a TOKEN connection reaches the
//        company it was made for. The adapter resolves the token's own
//        company: when the connection names none it is recorded (the
//        tenant guard protects it from then on); when it names another,
//        the connection goes to `error`, the mismatch said, and nothing
//        is delivered to it.

import { revokeToken } from "../_shared/accounting_oauth.ts";
import { clientOf, type Deps, json, resolved, STATUS_DETAIL_LENGTH, store, targetOf, UUID } from "./connection.ts";
import { adapterContext, deliveryAdapters } from "./deliver.ts";

type Remote = "revoked" | "failed" | "not_supported";

export async function revoke(deps: Deps, authorization: string, body: Record<string, unknown>): Promise<Response> {
  const connectionId = typeof body.connection_id === "string" ? body.connection_id : "";
  if (!UUID.test(connectionId)) return json({ error: "connection_id required" }, 400);
  const caller = deps.caller(authorization);
  const allowed = await caller.rpc("accounting_connection_manageable_v1", { p_connection_id: connectionId });
  if (allowed.error || !allowed.data) return json({ error: "not allowed to manage this connection" }, 403);
  // The tokens are read before the Vault is cleared, and kept in memory
  // for the one call below.
  const held = await resolved(deps, connectionId);
  const revoked = await caller.rpc("revoke_accounting_connection_v1", { p_connection_id: connectionId });
  if (revoked.error || !revoked.data) return json({ error: "the connection could not be revoked" }, 500);
  let remote: Remote = "not_supported";
  const target = held ? targetOf(deps, held.target_id) : undefined;
  const client = held ? clientOf(deps, held.target_id) : null;
  if (held && !held.revoked && held.auth_kind === "oauth2" && target?.revokeUrl && client) {
    const refresh = held.secrets.refresh_token ?? "";
    const token = refresh || (held.secrets.access_token ?? "");
    if (token) {
      const done = await revokeToken(deps.fetcher ?? fetch, target, client, token, refresh ? "refresh_token" : "access_token");
      remote = done.ok ? "revoked" : "failed";
      if (!done.ok) console.error(`accounting-connect: ${held.target_id} did not confirm the revocation (${done.detail})`);
    }
  }
  // The outcome is recorded on the revoked row by the service role alone
  // (record_accounting_revocation), so the card can say the target never
  // confirmed; the caller could forge a value it passed itself. A failed
  // record leaves the connection revoked and the answer the same.
  const recorded = await deps.service().rpc("record_accounting_revocation", {
    p_connection_id: connectionId,
    p_outcome: remote,
  });
  if (recorded.error) console.error("accounting-connect: the revocation outcome was not recorded");
  const connection = !recorded.error && recorded.data ? recorded.data : revoked.data;
  return json({ connection, remote_revocation: remote });
}

export async function verify(deps: Deps, authorization: string, body: Record<string, unknown>): Promise<Response> {
  const connectionId = typeof body.connection_id === "string" ? body.connection_id : "";
  if (!UUID.test(connectionId)) return json({ error: "connection_id required" }, 400);
  const allowed = await deps.caller(authorization).rpc("accounting_connection_manageable_v1", {
    p_connection_id: connectionId,
  });
  if (allowed.error || !allowed.data) return json({ error: "not allowed to manage this connection" }, 403);
  const held = await resolved(deps, connectionId);
  const adapterOf = held ? deliveryAdapters[held.target_id] : undefined;
  if (!held || held.revoked || held.auth_kind !== "token" || !adapterOf) {
    return json({ error: "this connection is not checked by its token" }, 400);
  }
  const token = held.secrets.access_token ?? "";
  if (!token) return json({ error: "not_connected" }, 409);
  const adapter = adapterOf(adapterContext(deps, held.target_id, token, held.remote_tenant_id));
  const reached = adapter.signedInTenant ? await adapter.signedInTenant() : undefined;
  let refused = reached && "refused" in reached ? reached.refused : null;
  if (!refused && reached && "tenant" in reached && held.remote_tenant_id && reached.tenant !== held.remote_tenant_id) {
    refused = "this token reaches another company than the one this connection was made for";
  }
  // A target that cannot name the token's company checks the one it was
  // given (its own `prepare`).
  if (!refused && !reached) refused = await adapter.prepare();
  if (refused) {
    await store(deps, connectionId, {
      secrets: {},
      patch: { status: "error", status_detail: refused.slice(0, STATUS_DETAIL_LENGTH) },
    });
    return json({ status: "refused", detail: refused.slice(0, STATUS_DETAIL_LENGTH) }, 409);
  }
  if (reached && "tenant" in reached && !held.remote_tenant_id) {
    if (!await store(deps, connectionId, { secrets: {}, patch: { remote_tenant_id: reached.tenant } })) {
      return json({ error: "the connection could not be saved" }, 500);
    }
  }
  return json({ status: "verified" });
}
