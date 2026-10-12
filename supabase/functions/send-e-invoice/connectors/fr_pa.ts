// SPDX-License-Identifier: AGPL-3.0-or-later
//
// fr_pa — a French plateforme agréée through the common API the
// accredited platforms expose: AFNOR XP Z12-013 ("Interfaces de service
// des plateformes", Flow Service: POST /v1/flows, GET /v1/flows/{id}),
// authenticated by OAuth 2.0 client credentials (RFC 6749 §4.4). The
// platform routes the invoice through the national directory and reports
// it to the DGFiP; its lifecycle statuses come back on the flow.
//
// The base URL and the token URL are the platform's own: there is no
// shared sandbox, so the live round-trip needs the account the owner
// opens with one platform. Nothing here has been exchanged with one yet.

import {
  accepted,
  Config,
  ConnectorDocument,
  Fetch,
  join,
  parseJson,
  refused,
  Submission,
} from "./common.ts";

/** The flow syntax the standard names for each of the app's formats. */
export const FLOW_SYNTAX: Record<string, string> = {
  en16931Cii: "CII",
  en16931Ubl: "UBL",
  facturX: "Factur-X",
};

/** OAuth 2.0 client credentials: one short-lived token per send. */
export async function clientCredentialsToken(
  cfg: Config,
  fetchImpl: Fetch,
): Promise<string | Response> {
  const body = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: cfg.client_id,
    client_secret: cfg.client_secret,
  });
  if (cfg.scope) body.set("scope", cfg.scope);
  const res = await fetchImpl(cfg.token_url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!res.ok) return res;
  const token = parseJson(await res.text()).access_token;
  return typeof token === "string" ? token : res;
}

export async function submitFrPa(
  cfg: Config,
  doc: ConnectorDocument,
  fetchImpl: Fetch,
): Promise<Submission> {
  const token = await clientCredentialsToken(cfg, fetchImpl);
  if (token instanceof Response) return refused(token);
  const trackingId = doc.number || doc.fileName;
  const form = new FormData();
  form.append(
    "flowInfo",
    new Blob([JSON.stringify({
      trackingId,
      name: doc.fileName,
      processingRule: "B2B",
      flowSyntax: FLOW_SYNTAX[doc.format] ?? "CII",
    })], { type: "application/json" }),
  );
  form.append(
    "file",
    new Blob([doc.bytes], { type: doc.mimeType }),
    doc.fileName,
  );
  const res = await fetchImpl(join(cfg.base_url, "v1/flows"), {
    method: "POST",
    headers: { "Authorization": `Bearer ${token}` },
    body: form,
  });
  if (!res.ok) return refused(res);
  const text = await res.text();
  const body = parseJson(text);
  const flowId = String(body.flowId ?? body.id ?? "");
  return accepted(flowId, text, { flowId, trackingId });
}

/** The flow as the platform sees it now: received, rejected, made
 * available to the buyer, and the lifecycle statuses after that. */
export async function statusFrPa(
  cfg: Config,
  flowId: string,
  fetchImpl: Fetch,
): Promise<Submission> {
  const token = await clientCredentialsToken(cfg, fetchImpl);
  if (token instanceof Response) return refused(token);
  const res = await fetchImpl(
    join(cfg.base_url, `v1/flows/${encodeURIComponent(flowId)}`),
    {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Accept": "application/json",
      },
    },
  );
  if (!res.ok) return refused(res);
  const text = await res.text();
  const body = parseJson(text);
  return accepted(flowId, text, {
    flowId,
    flowStatus: body.flowStatus ?? body.status ?? "",
    lifecycle: body.acknowledgement ?? body.lifecycle ?? null,
  });
}
