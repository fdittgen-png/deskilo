// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice -- the `status` action (#4400). What became of an earlier submission.

import type { Action } from "../common.ts";
import { json, configForDestination, configFor, legacyStatus, UNRESOLVED_DETAIL, onDocumentedSandbox } from "../common.ts";
import type { Environment, Destination } from "../common.ts";
import { SANDBOX, status as askStatus, SANDBOX_ENVIRONMENT } from "../connectors.ts";
import { redact } from "../connectors/common.ts";
import { clientDetail } from "../connectors/safe_fetch.ts";
import { logLine } from "../../_shared/log.ts";

export const status: Action = async (ctx) => {
  const { store, fetchImpl, payload, workspaceId, mayIssue, fullCfg } = ctx;
  const sent = await store.transmission(payload.transmission_id ?? "");
  if (!sent || sent.workspace_id !== workspaceId) {
    return json({ error: "unknown transmission" }, 404);
  }
  // #3883 -- whoever manages the integrations asks about a test document
  // only; an invoice's transmission is the issuer's.
  if (!mayIssue && sent.kind !== "test") {
    return json({ error: "not allowed to issue invoices in this workspace" }, 403);
  }
  // Only a recorded upload can be asked about, and never by a resend.
  if (
    !sent.external_id ||
    (sent.phase !== "accepted" && sent.phase !== "uncertain")
  ) {
    return json({
      phase: sent.phase,
      status: legacyStatus(sent.phase),
      lookup: "unavailable",
      detail: sent.phase === "uncertain" ? UNRESOLVED_DETAIL : sent.detail,
    });
  }
  // The stored destination and environment decide the credentials, not
  // the request's defaults (O11).
  const sentCfg = configForDestination(
    fullCfg,
    sent.destination as Destination,
  );
  // #3883 -- a test's verdict opens the gate: it is read from the
  // connector's documented sandbox only, as the test was sent there.
  if (
    sent.kind === "test" &&
    !onDocumentedSandbox(
      configFor(sentCfg, SANDBOX_ENVIRONMENT, sent.provider),
      SANDBOX[sent.provider] ?? {},
    )
  ) {
    return json({ error: "sandbox_not_documented", provider: sent.provider }, 409);
  }
  const asked = await askStatus(
    sent.provider,
    configFor(sentCfg, sent.environment as Environment, sent.provider),
    sent.external_id,
    fetchImpl,
  );
  // A document verdict is something the connector READ from a successful
  // answer; a refused or failed query is a query error, never a verdict.
  const isVerdict = asked.httpStatus === undefined &&
    !asked.pending &&
    (asked.status === "accepted" || asked.status === "rejected") &&
    Object.keys(asked.receipt).length > 0;
  if (isVerdict) {
    await store.lookup(
      sent.id,
      sent.phase === "uncertain" ? "accepted" : null,
      sent.external_id,
      asked.receipt,
      {
        status: asked.status,
        detail: clientDetail(asked.status, asked.detail),
      },
      "",
    );
  } else if (asked.httpStatus === undefined && asked.pending) {
    // #3881 -- a readable answer with no verdict yet: the provider holds
    // the upload (an uncertain upload settles accepted) and what it said
    // is kept; the document has no verdict and no query error.
    logLine("info", "send-e-invoice", "no_document_verdict_yet");
    await store.lookup(
      sent.id,
      sent.phase === "uncertain" ? "accepted" : null,
      sent.external_id,
      Object.keys(asked.receipt).length > 0 ? asked.receipt : null,
      null,
      "",
    );
  } else {
    logLine("error", "send-e-invoice", "status_query_failed", { error: redact(asked.detail) });
    await store.lookup(
      sent.id,
      null,
      "",
      null,
      null,
      clientDetail(asked.status, asked.detail),
    );
  }
  const current = await store.transmission(sent.id);
  return json({
    phase: current?.phase ?? sent.phase,
    status: legacyStatus(current?.phase ?? sent.phase),
    document_status: isVerdict ? asked.status : "unknown",
    detail: isVerdict ? clientDetail(asked.status, asked.detail) : "",
    receipt: current?.receipt ?? sent.receipt,
  });
};
