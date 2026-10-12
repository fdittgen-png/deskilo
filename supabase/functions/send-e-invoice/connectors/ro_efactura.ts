// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ro_efactura — ANAF's RO e-Factura API ("Sistemul național privind
// factura electronică RO e-Factura", the REST services /upload and
// /stareMesaj under /FCTEL/rest, test and prod), authenticated by the
// OAuth 2.0 bearer token ANAF issues for the company's qualified
// certificate. Upload answers an index_incarcare; stareMesaj turns it
// into ok (with the id_descarcare of the signed receipt), nok, or still
// processing.
//
// The access token comes from ANAF's OAuth flow with the owner's
// certificate — the live round-trip needs that account; nothing here has
// been exchanged with ANAF yet.

import {
  accepted,
  Config,
  ConnectorDocument,
  Fetch,
  join,
  refused,
  Submission,
} from "./common.ts";

/** An attribute of the first element named [element] in ANAF's flat XML
 * answers (`<header … index_incarcare="…"/>`). */
export function xmlAttribute(
  xml: string,
  element: string,
  attribute: string,
): string {
  const tag = new RegExp(`<(?:\\w+:)?${element}\\b[^>]*>`, "s").exec(xml)?.[0];
  if (!tag) return "";
  const value = new RegExp(`\\b${attribute}="([^"]*)"`).exec(tag)?.[1];
  return value ?? "";
}

/** ANAF's error messages (`<Errors errorMessage="…"/>`), joined. */
export function xmlErrors(xml: string): string {
  return [...xml.matchAll(/<(?:\w+:)?Errors\b[^>]*errorMessage="([^"]*)"/g)]
    .map((m) => m[1])
    .join("; ");
}

export async function submitRoEfactura(
  cfg: Config,
  doc: ConnectorDocument,
  fetchImpl: Fetch,
): Promise<Submission> {
  // A credit note travels under its own standard.
  const head = new TextDecoder().decode(doc.bytes.subarray(0, 600));
  const standard = /<(?:\w+:)?CreditNote\b/.test(head) ? "CN" : "UBL";
  const url = join(cfg.base_url, "upload") +
    `?standard=${standard}&cif=${encodeURIComponent(cfg.cif)}`;
  const res = await fetchImpl(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${cfg.access_token}`,
      "Content-Type": "text/plain",
    },
    body: doc.bytes,
  });
  if (!res.ok) return refused(res);
  const text = await res.text();
  const executionStatus = xmlAttribute(text, "header", "ExecutionStatus");
  const index = xmlAttribute(text, "header", "index_incarcare");
  if (executionStatus !== "0" || !index) {
    return {
      status: "rejected",
      externalId: index,
      detail: (xmlErrors(text) || text).slice(0, 500),
      receipt: { executionStatus },
    };
  }
  return accepted(index, text, { index_incarcare: index });
}

export async function statusRoEfactura(
  cfg: Config,
  index: string,
  fetchImpl: Fetch,
): Promise<Submission> {
  const res = await fetchImpl(
    join(cfg.base_url, "stareMesaj") +
      `?id_incarcare=${encodeURIComponent(index)}`,
    {
      method: "GET",
      headers: { "Authorization": `Bearer ${cfg.access_token}` },
    },
  );
  if (!res.ok) return refused(res);
  const text = await res.text();
  const stare = xmlAttribute(text, "header", "stare");
  const download = xmlAttribute(text, "header", "id_descarcare");
  const receipt = { index_incarcare: index, stare, id_descarcare: download };
  if (stare === "nok" || stare === "XML cu erori nepreluat de sistem") {
    return {
      status: "rejected",
      externalId: index,
      detail: (xmlErrors(text) || text).slice(0, 500),
      receipt,
    };
  }
  return accepted(index, text, receipt);
}
