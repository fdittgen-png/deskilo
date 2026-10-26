// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The delivery of a connection: the postings of one period (or of one
// document of it, delivered again) taken to the connection's target
// through the delivery kit, one document event at a time.
//
//   POST {action: "deliver", connection_id, from, to, document?: {kind, id}}
//
// Who may: the caller's own token decides at every step. The connection
// must be one the caller manages (`accounting_connection_manageable_v1`:
// manageBilling, the accountingConnectors flag, a native session); the
// postings are the engine's answer to the caller (`compute_postings`,
// viewFinances), never a body the client sent. Only the token and the
// delivery log are the service role's.
//
// What it guarantees is the kit's (`_shared/accounting_delivery.ts`): the
// identity is recorded before a byte leaves, an acknowledged document is a
// no-op, an unknown outcome is read back before any create, and a mapping
// key nobody filled blocks that document with the key named. A period the
// engine cannot post (an unmapped role, an unbalanced document) delivers
// nothing; a target that refuses the company (pennylane: its journals;
// quickbooks: its country and its numbering; xero: its country, its tax
// rates and accounts) delivers nothing either.
// A period lies within one calendar month, so one run stays well inside
// the function's time and the target's rate limits; the app asks month by
// month.

import {
  type AccountingMap,
  databaseStore,
  deliver,
  DeliveryNotRecorded,
  type DeliveryResult,
} from "../_shared/accounting_delivery.ts";
import { oauthTargets } from "../_shared/accounting_targets.ts";
import { connectedWrite, expiredWrite, isFailure, refreshTokens } from "../_shared/accounting_oauth.ts";
import {
  type AdapterContext,
  balanced,
  deliveryIds,
  type PostingAdapter,
  type PostingParty,
  postingSha256,
  postingsOf,
} from "../_shared/accounting_postings.ts";
import { pennylaneLedger } from "../_shared/accounting_pennylane.ts";
import { quickbooksOnline } from "../_shared/accounting_quickbooks.ts";
import { xeroAccounting } from "../_shared/accounting_xero.ts";
import { type CallerDb, clientOf, type Deps, json, resolved, store, UUID } from "./connection.ts";

/** The targets this server delivers to, by target id. */
export const deliveryAdapters: Record<string, (ctx: AdapterContext) => PostingAdapter> = {
  pennylane_api: pennylaneLedger,
  quickbooks_online_us: quickbooksOnline,
  quickbooks_online_ca: quickbooksOnline,
  quickbooks_online_gb: quickbooksOnline,
  xero_gb: xeroAccounting,
  xero_ca: xeroAccounting,
  xero_us: xeroAccounting,
  xero_eu: xeroAccounting,
};

/** The context every adapter of [targetId] is built with. The EU check is
 * the tax reference's own (`is_eu_country`), asked as the service role:
 * a sign-in's redirect carries no caller token. */
export function adapterContext(
  deps: Deps,
  targetId: string,
  accessToken: string,
  tenant: string,
): AdapterContext {
  return {
    fetch: deps.fetcher ?? fetch,
    secrets: { access_token: accessToken },
    tenant,
    targetId,
    env: deps.env,
    isEuCountry: async (code) => {
      const { data, error } = await deps.service().rpc("is_eu_country", { p_code: code });
      return error || typeof data !== "boolean" ? null : data;
    },
  };
}

/** The legal number of the invoice each credit note of [documentIds]
 * corrects (`invoices.replaces_number`), as the caller reads them. A
 * credit note that names none is a credit kept for the customer. */
async function creditedNumbers(caller: CallerDb, documentIds: string[]): Promise<Record<string, string> | null> {
  if (documentIds.length === 0) return {};
  const { data, error } = await caller.from("invoices").select("id, replaces_number").in("id", documentIds);
  if (error || !Array.isArray(data)) return null;
  const numbers: Record<string, string> = {};
  for (const row of data as Record<string, unknown>[]) {
    if (typeof row.id === "string" && typeof row.replaces_number === "string" && row.replaces_number) {
      numbers[row.id] = row.replaces_number;
    }
  }
  return numbers;
}

/** The longest an Edge function runs on the hosted platform (its
 * wall-clock limit). spec: supabase.com/docs/guides/functions/limits. */
const FUNCTION_BUDGET_MS = 400_000;

/** A token that expires within one function budget is refreshed before
 * the run: a run makes many calls and must not lose its token halfway. */
const REFRESH_AHEAD_MS = FUNCTION_BUDGET_MS;

const DAY = /^\d{4}-\d{2}-\d{2}$/;

/** [from]..[to] as one period of one calendar month, or null. */
function periodOf(from: unknown, to: unknown): { from: string; to: string } | null {
  if (typeof from !== "string" || typeof to !== "string" || !DAY.test(from) || !DAY.test(to)) {
    return null;
  }
  const a = new Date(`${from}T00:00:00Z`);
  const b = new Date(`${to}T00:00:00Z`);
  if (isNaN(a.getTime()) || isNaN(b.getTime()) || a.toISOString().slice(0, 10) !== from ||
    b.toISOString().slice(0, 10) !== to || b < a || from.slice(0, 7) !== to.slice(0, 7)) {
    return null;
  }
  return { from, to };
}

/** The document a re-delivery names, or undefined for the whole period. */
function documentOf(raw: unknown): { kind: string; id: string } | undefined | null {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== "object") return null;
  const d = raw as Record<string, unknown>;
  const kind = typeof d.kind === "string" ? d.kind : "";
  const id = typeof d.id === "string" ? d.id : "";
  return /^[a-z_]{1,40}$/.test(kind) && UUID.test(id) ? { kind, id } : null;
}

/** The mappings of [connectionId] as the caller reads them. */
async function mapsOf(
  deps: Deps,
  authorization: string,
  workspaceId: string,
  connectionId: string,
): Promise<AccountingMap[] | null> {
  const { data, error } = await deps.caller(authorization).rpc("accounting_connections_v1", {
    p_workspace_id: workspaceId,
  });
  if (error || !Array.isArray(data)) return null;
  const c = (data as Record<string, unknown>[]).find((x) => x.id === connectionId);
  if (!c || !Array.isArray(c.maps)) return null;
  return (c.maps as Record<string, unknown>[]).map((m) => ({
    kind: m.kind as AccountingMap["kind"],
    key: String(m.key ?? ""),
    remoteId: String(m.remote_id ?? ""),
    remoteCode: String(m.remote_code ?? ""),
  }));
}

/** The connection's access token, fresh; null when the sign-in is gone
 * (the connection is then marked expired). The adapter is given this token
 * and nothing else of Vault. */
async function freshToken(
  deps: Deps,
  held: NonNullable<Awaited<ReturnType<typeof resolved>>>,
): Promise<string | null> {
  const current = held.secrets.access_token ?? "";
  const target = oauthTargets[held.target_id];
  if (held.auth_kind !== "oauth2" || !target) return current || null;
  const now = (deps.now ?? (() => new Date()))();
  const expires = Date.parse(held.token_expires_at ?? "");
  if (current && Number.isFinite(expires) && expires - now.getTime() > REFRESH_AHEAD_MS) return current;
  const client = clientOf(deps, held.target_id);
  const refreshToken = held.secrets.refresh_token ?? "";
  if (!client || !refreshToken) return null;
  const tokens = await refreshTokens(deps.fetcher ?? fetch, target, client, refreshToken, now);
  if (isFailure(tokens)) {
    await store(deps, held.id, expiredWrite(tokens));
    return null;
  }
  const write = connectedWrite(tokens);
  if (!await store(deps, held.id, write)) return null;
  return tokens.accessToken;
}

type Outcome = {
  document_kind: string;
  document_id: string;
  document_number: string;
  event_date: string;
  status: DeliveryResult["status"];
  missing?: string[];
  detail?: string;
  /** The delivery log's refusal code, when it refused the record. */
  code?: string;
};

export async function deliverPeriod(
  deps: Deps,
  authorization: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const connectionId = typeof body.connection_id === "string" ? body.connection_id : "";
  const period = periodOf(body.from, body.to);
  const only = documentOf(body.document);
  if (!UUID.test(connectionId) || !period || only === null) {
    return json({ error: "connection_id, a period within one month and a valid document required" }, 400);
  }
  const caller = deps.caller(authorization);
  const allowed = await caller.rpc("accounting_connection_manageable_v1", { p_connection_id: connectionId });
  const manageable = allowed.data as { workspace_id?: string; target_id?: string } | null;
  if (allowed.error || !manageable?.workspace_id) {
    return json({ error: "not allowed to deliver for this connection" }, 403);
  }
  const workspaceId = manageable.workspace_id;
  const adapterOf = deliveryAdapters[manageable.target_id ?? ""];
  if (!adapterOf) return json({ error: "not_delivered_here" }, 400);
  const held = await resolved(deps, connectionId);
  if (!held || held.revoked || held.status !== "connected") return json({ error: "not_connected" }, 409);
  const token = await freshToken(deps, held);
  if (!token) return json({ error: "not_connected" }, 409);
  const maps = await mapsOf(deps, authorization, workspaceId, connectionId);
  if (!maps) return json({ error: "not allowed to deliver for this connection" }, 403);
  const computed = await caller.rpc("compute_postings", {
    p_workspace_id: workspaceId,
    p_issuer_site_id: held.issuer_site_id,
    p_from: period.from,
    p_to: period.to,
  });
  if (computed.error) return json({ error: "not allowed to read the books" }, 403);
  const { postings, blockers } = postingsOf(computed.data);
  if (blockers.length > 0) return json({ error: "books_blocked", blockers }, 409);
  const ids = await deliveryIds(postings);
  const chosen = postings
    .map((posting, i) => ({ posting, id: ids[i] }))
    .filter(({ posting, id }) => !only || (posting.kind === only.kind && id === only.id));
  const parties = chosen.length === 0 ? {} : await caller.rpc("posting_parties", {
    p_workspace_id: workspaceId,
    p_document_ids: [...new Set(chosen.map(({ posting }) => posting.documentId))],
  }).then((r) => (r.error ? {} : (r.data ?? {}) as Record<string, PostingParty>));
  const credited = await creditedNumbers(
    caller,
    [...new Set(chosen.filter(({ posting }) => posting.kind === "credit_note").map(({ posting }) => posting.documentId))],
  );
  if (!credited) return json({ error: "not allowed to read the books" }, 403);
  const adapter = adapterOf(adapterContext(deps, held.target_id, token, held.remote_tenant_id));
  if (chosen.length > 0) {
    const refused = await adapter.prepare();
    if (refused) return json({ error: "target_refused", detail: refused }, 409);
  }
  const deliveries = databaseStore(deps.service());
  const results: Outcome[] = [];
  for (const { posting, id } of chosen) {
    const base = {
      document_kind: posting.kind,
      document_id: id,
      document_number: posting.documentNumber,
      event_date: posting.date,
    };
    if (!balanced(posting)) {
      results.push({ ...base, status: "failed", detail: "the posting does not balance" });
      continue;
    }
    try {
      const result = await deliver({
        connectionId,
        documentKind: posting.kind,
        documentId: id,
        eventDate: posting.date,
        documentNumber: posting.documentNumber,
        periodFrom: period.from,
        periodTo: period.to,
        payloadSha256: await postingSha256(posting),
        needs: adapter.needs(posting),
      }, maps, deliveries, adapter.remote(posting, parties[posting.documentId], maps, credited[posting.documentId]));
      results.push(
        result.status === "blocked"
          ? { ...base, status: "blocked", missing: result.missing }
          : { ...base, status: result.status, ...(result.row.error ? { detail: result.row.error } : {}) },
      );
    } catch (error) {
      // A delivery the log refused (a changed document already
      // acknowledged: 23514) was not sent; the others still go.
      if (!(error instanceof DeliveryNotRecorded)) throw error;
      results.push({ ...base, status: "failed", code: error.code, detail: error.message });
    }
  }
  const counts: Record<string, number> = {};
  for (const r of results) counts[r.status] = (counts[r.status] ?? 0) + 1;
  return json({ results, counts });
}
