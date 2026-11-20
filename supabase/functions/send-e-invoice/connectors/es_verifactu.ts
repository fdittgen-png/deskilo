// SPDX-License-Identifier: AGPL-3.0-or-later
//
// es_verifactu (#3932) -- the AEAT's Verifactu web service
// (SistemaFacturacion / VerifactuSOAP, the technical documentation of the
// Agencia Tributaria). One SOAP call carries the record; the answer states, in
// the same call, whether the platform kept it (readVerifactuResponse): no
// later query decides it, so this connector has no `status`.
//
// The caller proves itself with the business's own certificate in the TLS
// handshake (mutual TLS). The certificate and its private key are the owner's
// credential (stored in the Vault like every secret); they are loaded into a
// client for this one call, closed after it, and never reach a log, an answer
// or a stored row: a failure says only a fixed key. The client certificate is
// offered to the AEAT's own hosts only.
//
// Nothing here has been exchanged with the AEAT yet: the live round-trip needs
// the operator's certificate and the owner's test account (#3534). The
// addresses below are the ones the documentation names.

import {
  accepted,
  Config,
  Connector,
  ConnectorDocument,
  Fetch,
  noVerdictYet,
  refused,
  Submission,
  unreachable,
} from "./common.ts";
import { readVerifactuResponse } from "../verifactu_outcome.ts";

/** The AEAT as its documentation names it. */
export const AEAT = {
  /** The test environment of the Verifactu service (personal certificate). */
  sandboxUrl:
    "https://prewww1.aeat.es/wlpl/TIKE-CONT/ws/SistemaFacturacion/VerifactuSOAP",
  /** Every host the certificate may be offered to: the test and the
   * production service, for a personal certificate and for a seal. */
  hosts: [
    "prewww1.aeat.es",
    "prewww10.aeat.es",
    "www1.agenciatributaria.gob.es",
    "www10.agenciatributaria.gob.es",
  ],
  contentType: "text/xml; charset=utf-8",
} as const;

/** What a failure before any request says: fixed keys, never the material. */
export const ES_REFUSALS = {
  host: "destination_not_allowed",
  certificate: "certificate_unreadable",
} as const;

/** The mutual-TLS client of one call; a test hands in its own. */
export type MakeClient = (cert: string, key: string) => Deno.HttpClient;

/** The factory the installed connector uses; a test swaps it and puts it back. */
export const clients: { make: MakeClient } = {
  make: (cert, key) => Deno.createHttpClient({ cert, key }),
};

/** A PEM as stored: line breaks typed as `\n` become line breaks. */
const pem = (text: string): string =>
  text.includes("\n") ? text.trim() : text.replace(/\\n/g, "\n").trim();

const CERT = /^-----BEGIN CERTIFICATE-----[\s\S]+-----END CERTIFICATE-----$/;
const KEY =
  /^-----BEGIN (?:RSA |EC )?PRIVATE KEY-----[\s\S]+-----END (?:RSA |EC )?PRIVATE KEY-----$/;

const failed = (detail: string): Submission => ({
  status: "failed",
  externalId: "",
  detail,
  receipt: {},
});

export async function submitEsVerifactu(
  cfg: Config,
  doc: ConnectorDocument,
  fetchImpl: Fetch,
  makeClient: MakeClient = (cert, key) => clients.make(cert, key),
): Promise<Submission> {
  let host = "";
  try {
    host = new URL(cfg.base_url).host;
  } catch {
    // an unreadable address is refused below
  }
  if (!(AEAT.hosts as readonly string[]).includes(host)) {
    return failed(ES_REFUSALS.host);
  }
  const cert = pem(cfg.client_certificate ?? "");
  const key = pem(cfg.private_key ?? "");
  if (!CERT.test(cert) || !KEY.test(key)) {
    return failed(ES_REFUSALS.certificate);
  }
  let client: Deno.HttpClient;
  try {
    client = makeClient(cert, key);
  } catch {
    return failed(ES_REFUSALS.certificate);
  }
  try {
    doc.onDispatch?.();
    const res = await fetchImpl(cfg.base_url, {
      method: "POST",
      headers: { "Content-Type": AEAT.contentType, "SOAPAction": "" },
      body: doc.bytes,
      client,
    } as RequestInit);
    if (!res.ok) return refused(res);
    const outcome = readVerifactuResponse(await res.text());
    const receipt = {
      csv: outcome.csv,
      submission_state: outcome.submissionState,
      lines: outcome.lines,
    };
    const id = outcome.csv || doc.fileName;
    if (outcome.verdict === "unknown") {
      return noVerdictYet(id, outcome.reason, receipt);
    }
    // the platform took the upload and said what became of the record
    return {
      ...accepted(id, outcome.reason, receipt),
      verdict: outcome.verdict,
    };
  } catch (error) {
    return unreachable(error);
  } finally {
    client.close();
  }
}

/** The es_verifactu connector record. */
export const esVerifactuConnector: Connector = {
  id: "es_verifactu",
  requiredFields: ["base_url", "client_certificate", "private_key"],
  acceptedFormats: ["verifactu"],
  sandbox: { base_url: AEAT.sandboxUrl },
  submit: (cfg, doc, fetchImpl) => submitEsVerifactu(cfg, doc, fetchImpl),
  testDocument: true,
};
