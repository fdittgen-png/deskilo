// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice -- the `test` action (#4400): a sandbox test document of the national channel (#3883).

import type { Action } from "../common.ts";
import { json, configForDestination, configFor, missingFor, sha256, onDocumentedSandbox, clipDeclared } from "../common.ts";
import type { Config } from "../common.ts";
import { SANDBOX, acceptedFormats, takesTestDocument, SANDBOX_ENVIRONMENT } from "../connectors.ts";
import { safeError } from "../connectors/common.ts";
import { dispatchPrepared } from "../dispatch.ts";
import type { TransmissionStore } from "../store.ts";
import { logLine } from "../../_shared/log.ts";
/** #3883 -- why a second test waits, in a sentence a person can act on. */
export const TEST_PENDING_DETAIL =
  "A test document is still waiting for the platform's verdict. Ask the " +
  "platform about it before sending another.";

/** #3883 -- sends a sandbox test document through the national channel: the
 * holder of the integrations' right only, a connector whose verdict opens the
 * channel's gate only, the sandbox credentials only (never the live ones,
 * never a fallback), one test at a time. It is no invoice: nothing is issued,
 * numbered or booked. */
export async function sendTestDocument(
  store: TransmissionStore,
  fetchImpl: typeof fetch,
  payload: {
    content_base64?: string;
    file_name?: string;
    mime_type?: string;
    format?: string;
    declared?: unknown;
  },
  ctx: {
    workspaceId: string;
    userId: string;
    mayManage: boolean;
    credentials: { provider: string; config: Record<string, string> } | null;
  },
): Promise<Response> {
  if (!ctx.mayManage) {
    return json({
      error: "not allowed to manage the integrations of this workspace",
    }, 403);
  }
  const provider = ctx.credentials?.provider ?? "generic";
  if (!takesTestDocument(provider)) {
    return json({ error: "test_unavailable", provider }, 409);
  }
  const cfg = configForDestination(
    (ctx.credentials?.config ?? {}) as Config,
    "government",
  );
  const missing = missingFor(cfg, SANDBOX_ENVIRONMENT, provider);
  if (missing.length > 0) {
    return json({ error: "sandbox_credentials_missing", missing }, 409);
  }
  // Its verdict opens the gate, so a test goes only to the connector's
  // documented sandbox: the platform's own answer, never another host's.
  if (!onDocumentedSandbox(configFor(cfg, SANDBOX_ENVIRONMENT, provider), SANDBOX[provider] ?? {})) {
    return json({ error: "sandbox_not_documented", provider }, 409);
  }
  const content = payload.content_base64 ?? "";
  if (!content) return json({ error: "content_base64 required" }, 400);
  if (content.length > 14_000_000) {
    return json({ error: "document_too_large" }, 413);
  }
  const bytes = Uint8Array.from(atob(content), (c) => c.charCodeAt(0));
  const hash = await sha256(bytes);
  const fileName = payload.file_name || "test.xml";
  const mimeType = payload.mime_type || "application/xml";
  // a test document is in the channel's own syntax, whatever the caller named
  const formats = acceptedFormats(provider);
  const format = payload.format || formats[0] || "";
  if (!formats.includes(format)) {
    return json({ error: "format_not_accepted", provider, formats }, 400);
  }
  let prepared;
  try {
    prepared = await store.prepareTest({
      workspaceId: ctx.workspaceId,
      provider,
      actor: ctx.userId,
      byName: await store.profileName(ctx.userId),
      format,
      hash,
      fileName,
      mimeType,
      bytes,
      declared: clipDeclared(payload.declared),
    });
  } catch (error) {
    logLine("error", "send-e-invoice", "test_prepare_failed", { error: safeError(error) });
    return json({ error: "prepare_failed" }, 500);
  }
  if (prepared.outcome === "test_pending" || !prepared.id) {
    return json({
      error: "test_pending",
      transmission_id: prepared.id ?? "",
      phase: prepared.phase ?? "",
      detail: TEST_PENDING_DETAIL,
    }, 409);
  }
  return await dispatchPrepared(store, fetchImpl, {
    id: prepared.id,
    hash,
    provider,
    cfg,
    environment: SANDBOX_ENVIRONMENT,
    destination: "government",
    fileName,
    mimeType,
    format,
    number: fileName,
  });
}

export const test: Action = (ctx) =>
  sendTestDocument(ctx.store, ctx.fetchImpl, ctx.payload, {
    workspaceId: ctx.workspaceId,
    userId: ctx.userId,
    mayManage: ctx.mayManage,
    credentials: ctx.credentials,
  });
