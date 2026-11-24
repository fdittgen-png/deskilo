// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice -- the `send` action (#4400). Sends an invoice's document: prepare, then dispatch.

import type { Action } from "../common.ts";
import { json, sha256, bindingOf, answer, clipDeclared } from "../common.ts";
import { safeError } from "../connectors/common.ts";
import { dispatchPrepared } from "../dispatch.ts";
import { logLine } from "../../_shared/log.ts";

export const send: Action = async (ctx) => {
  const { store, fetchImpl, payload, workspaceId, userId, cfg, environment, destination, provider, missing } = ctx;
if (missing.length > 0) {
  return json({ error: "not_configured", missing, environment }, 409);
}

// ── send ─────────────────────────────────────────────────────────────
const invoiceId = payload.invoice_id ?? "";
const content = payload.content_base64 ?? "";
if (!invoiceId || !content) {
  return json({ error: "invoice_id and content_base64 required" }, 400);
}
const invoice = await store.invoice(invoiceId);
if (!invoice || invoice.workspace_id !== workspaceId) {
  return json({ error: "unknown invoice" }, 404);
}
// A voided invoice is not sent.
if (invoice.voided_at) return json({ error: "invoice_voided" }, 409);
// About ten megabytes once decoded.
if (content.length > 14_000_000) {
  return json({ error: "document_too_large" }, 413);
}

const bytes = Uint8Array.from(atob(content), (c) => c.charCodeAt(0));
const hash = await sha256(bytes);
const fileName = payload.file_name || `${invoice.number}.pdf`;
const mimeType = payload.mime_type || "application/pdf";
const format = payload.format ||
  (mimeType === "application/pdf" ? "facturX" : "en16931Ubl");

// 1. PREPARE: durable, deduplicated by the business identity. Any
// failure here means nothing has left (O1).
let prepared;
try {
  prepared = await store.prepare({
    workspaceId,
    invoiceId,
    provider,
    destination,
    environment,
    actor: userId,
    byName: await store.profileName(userId),
    format,
    hash,
    fileName,
    mimeType,
    receiverScheme: payload.receiver_scheme ?? "",
    receiverId: payload.receiver_id ?? "",
    bytes,
    declared: clipDeclared(payload.declared),
  });
} catch (error) {
  logLine("error", "send-e-invoice", "prepare_failed", { error: safeError(error) });
  return json({ error: "prepare_failed" }, 500);
}
if (prepared.outcome === "unknown_invoice" || !prepared.id) {
  return json({ error: "unknown invoice" }, 404);
}
if (prepared.outcome === "conflict") {
  return json({
    error: "binding_changed",
    phase: prepared.phase,
    transmission_id: prepared.id,
    detail: "This invoice already has a submission to this destination " +
      "with other content; it is not sent again.",
  }, 409);
}
const id = prepared.id;
const state = prepared.phase ?? "prepared";
// An existing record that is not waiting for a first (or proven
// no-effect) dispatch answers as it stands: no second upload (O7).
if (
  prepared.outcome === "existing" && state !== "prepared" &&
  state !== "failed"
) {
  return answer(
    state,
    id,
    prepared.external_id ?? "",
    prepared.detail ?? "",
    environment,
    destination,
  );
}

return dispatchPrepared(store, fetchImpl, {
  id,
  hash,
  provider,
  cfg,
  environment,
  destination,
  fileName,
  mimeType,
  format,
  number: invoice.number,
  binding: await bindingOf(
    hash,
    format,
    payload.receiver_scheme ?? "",
    payload.receiver_id ?? "",
  ),
});
};
