// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice — the handler (#3335). It lives apart from index.ts so
// its decisions can be exercised with an injected store and provider:
//
//   authenticate → authorise → (config | status | resolve | send)
//
// A send is PREPARED durably before any byte leaves (prepare_einvoice_v1:
// one record per business transmission, bytes and recipient pinned), its
// artifact is read back and verified, and the dispatch is CLAIMED
// atomically with an owner and a generation. The provider is called only
// by the claim's winner; its outcome is recorded against that owner and
// generation, so a late writer changes nothing. A dispatch that may have
// landed and whose answer is lost is `uncertain` and is never resent
// automatically: a lookup (where the channel has one) or a person with
// the send authority settles it.
// The actions are a table (actions/index.ts): this file reads the request,
// decides who may ask, builds the context and runs the action it names.

import { refuseDelegated } from "../_shared/delegated.ts";
import { CORS, preflight } from "../_shared/cors.ts";
import { actionFor } from "./actions/index.ts";
import {
  type ActionContext,
  type Config,
  configForDestination,
  type Deps,
  DESTINATIONS,
  type Destination,
  ENVIRONMENTS,
  type Environment,
  json,
  missingFor,
  type Payload,
} from "./common.ts";
import { safeError } from "./connectors/common.ts";
import { safeFetch } from "./connectors/safe_fetch.ts";
import { logLine } from "../_shared/log.ts";

export { clipDeclared, DISPATCH_WINDOW_SECONDS } from "./common.ts";
export type { Deps } from "./common.ts";

export async function handle(req: Request, deps: Deps): Promise<Response> {
  const { store } = deps;
  const fetchImpl = deps.fetchImpl ?? safeFetch();
  // #1553 — the preflight is answered before anything else.
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  // #1614 — a delegated (MCP) token never transmits an invoice.
  const delegated = refuseDelegated(req, CORS);
  if (delegated) return delegated;

  const authorization = req.headers.get("Authorization") ?? "";
  let payload: Payload;
  try {
    payload = await req.json();
  } catch (error) {
    logLine("warn", "send-e-invoice", "invalid_body", { error: safeError(error) });
    return json({ error: "invalid body" }, 400);
  }
  const workspaceId = payload.workspace_id ?? "";
  if (!workspaceId) return json({ error: "workspace_id required" }, 400);
  // #2357 — a VAT return is not an upload.
  if (payload.declaration_id) {
    return json({
      error: "vat_return_not_transmitted",
      detail: "A VAT return is filed by its owner with the tax authority; " +
        "this channel carries invoices only.",
    }, 410);
  }

  // #1078 — WHO is asking, BEFORE anything answers; scoped by user_id.
  const userId = await store.user(authorization.replace("Bearer ", ""));
  if (!userId) return json({ error: "unauthorized" }, 401);
  const action = actionFor(payload.action);
  const rights = await rightsOf(store, workspaceId, userId, action.manage);
  if (!rights) {
    return json({ error: "not allowed to issue invoices in this workspace" }, 403);
  }
  const { mayIssue, mayManage } = rights;
  const credentials = await store.credentials(workspaceId);
  const fullCfg = (credentials?.config ?? {}) as Config;
  const environment = (ENVIRONMENTS as readonly string[]).includes(
      payload.environment ?? "",
    )
    ? (payload.environment as Environment)
    : "prod";
  const destination = (DESTINATIONS as readonly string[]).includes(
      payload.destination ?? "",
    )
    ? (payload.destination as Destination)
    : "government";
  const cfg = configForDestination(fullCfg, destination);
  // The customer leg is always the generic upload (#568).
  const provider = destination === "customer"
    ? "generic"
    : (credentials?.provider ?? "generic");
  const missing = missingFor(cfg, environment, provider);

  // The client asks first whether sending is even possible.

  const ctx: ActionContext = {
    store, fetchImpl, payload, workspaceId, userId, mayIssue, mayManage,
    credentials, fullCfg, cfg, environment, destination, provider, missing,
  };

  // A development workspace and an uncertain dispatch matter to the actions
  // that talk to the outside world; the client's first question does not.
  if (action.live) {
    const refused = await liveGate(store, workspaceId);
    if (refused) return refused;
  }
  return await action.run(ctx);
}

/** #917 — a DEVELOPMENT workspace does not talk to the outside world; and a
 * dispatch whose deadline passed with no outcome is uncertain now. */
async function liveGate(
  store: Deps["store"],
  workspaceId: string,
): Promise<Response | null> {
  if ((await store.workspaceEnvironment(workspaceId)) !== "prod") {
    return json({
      error: "development_workspace",
      detail:
        "This workspace is a development one: it does not send documents " +
        "to a government platform or to a customer. Declare it production " +
        "to send for real.",
    }, 409);
  }
  try {
    await store.expire(workspaceId);
  } catch (error) {
    logLine("error", "send-e-invoice", "expiry_sweep_failed", { error: safeError(error) });
  }
  return null;
}

/** WHO may ask (#1078): an active owner, or an active member who holds
 * issueInvoices (from the base role or a role of the space). #3883 -- a
 * sandbox test document issues nothing: it is sent, and asked about, by
 * whoever manages the integrations (the credentials' right). Null: refused. */
async function rightsOf(
  store: Deps["store"],
  workspaceId: string,
  userId: string,
  testing: boolean,
): Promise<{ mayIssue: boolean; mayManage: boolean } | null> {
  const me = await store.member(workspaceId, userId);
  const active = !!me && me.status === "active";
  const mayIssue = active &&
    (me.is_owner || await store.hasPermission(me.id, "issueInvoices"));
  const mayManage = testing && active &&
    (me.is_owner || await store.hasPermission(me.id, "manageIntegrations"));
  if (!me || (!mayIssue && !mayManage) || (!testing && !mayIssue)) return null;
  return { mayIssue, mayManage };
}
