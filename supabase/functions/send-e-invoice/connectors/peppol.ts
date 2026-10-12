// SPDX-License-Identifier: AGPL-3.0-or-later
//
// peppol — a Peppol access point's REST API, in the shape of the
// Storecove API v2 ("Document Submissions", api.storecove.com/api/v2):
// the access point owns the Peppol AS4 exchange, the SMP lookup and the
// message-level response; this posts the Peppol BIS (or XRechnung) UBL
// as raw document data and reads the evidence back.
//
// The live round-trip needs a sandbox account the owner creates with the
// access point (a legal entity id and an API key); nothing here has been
// exchanged with a real access point yet.

import {
  accepted,
  Config,
  ConnectorDocument,
  Fetch,
  join,
  parseJson,
  refused,
  Submission,
  toBase64,
} from "./common.ts";

/** Storecove names receiver schemes by country and register rather than
 * by the ISO 6523 / EAS code the invoice carries (BT-49). Unknown codes
 * pass through as they are — the access point answers if it disagrees. */
export const PEPPOL_SCHEMES: Record<string, string> = {
  "0002": "FR:SIRENE",
  "0009": "FR:SIRET",
  "0088": "GLN",
  "0106": "NL:KVK",
  "0190": "NL:OINO",
  "0192": "NO:ORG",
  "0204": "DE:LWID",
  "0208": "BE:EN",
  "9925": "BE:VAT",
  "9930": "DE:VAT",
  "9957": "FR:VAT",
};

export async function submitPeppol(
  cfg: Config,
  doc: ConnectorDocument,
  fetchImpl: Fetch,
): Promise<Submission> {
  if (!doc.receiver?.id) {
    return {
      status: "rejected",
      externalId: "",
      detail: "the customer has no electronic address (BT-49) to route to",
      receipt: {},
    };
  }
  const legalEntityId = Number(cfg.legal_entity_id);
  const res = await fetchImpl(
    join(cfg.base_url, "api/v2/document_submissions"),
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${cfg.api_key}`,
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: JSON.stringify({
        legalEntityId: Number.isFinite(legalEntityId)
          ? legalEntityId
          : cfg.legal_entity_id,
        routing: {
          eIdentifiers: [{
            scheme: PEPPOL_SCHEMES[doc.receiver.scheme] ?? doc.receiver.scheme,
            id: doc.receiver.id,
          }],
          emails: [],
        },
        document: {
          documentType: "invoice",
          rawDocumentData: {
            document: toBase64(doc.bytes),
            parse: false,
            parseStrategy: "ubl",
          },
        },
      }),
    },
  );
  if (!res.ok) return refused(res);
  const text = await res.text();
  const body = parseJson(text);
  const guid = String(body.guid ?? body.id ?? "");
  return accepted(guid, text, { guid });
}

/** The delivery evidence: what the receiving access point acknowledged
 * (the AS4 receipt and, once the buyer answers, the message-level
 * response). */
export async function statusPeppol(
  cfg: Config,
  guid: string,
  fetchImpl: Fetch,
): Promise<Submission> {
  const res = await fetchImpl(
    join(
      cfg.base_url,
      `api/v2/document_submissions/${
        encodeURIComponent(guid)
      }/evidence/sending`,
    ),
    {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${cfg.api_key}`,
        "Accept": "application/json",
      },
    },
  );
  if (!res.ok) return refused(res);
  const text = await res.text();
  const body = parseJson(text);
  return accepted(guid, text, { guid, evidence: body });
}
