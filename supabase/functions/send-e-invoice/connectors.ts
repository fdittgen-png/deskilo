// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — the e-invoicing channels, one connector per provider value of
// `einvoice_credentials.provider`. The function picks the connector, the
// connector speaks its provider's API; every one takes `fetch` as a
// parameter so the tests answer for the provider (connectors_test.ts).
//
// Sandbox and production differ only by configuration: each base URL is
// a config field, and the SANDBOX constants below are the documented test
// environments the owner starts from. No live exchange has happened yet —
// each needs an account the owner creates with the provider.

import {
  Config,
  ConnectorDocument,
  Fetch,
  Submission,
  unreachable,
} from "./connectors/common.ts";
import { statusFrPa, submitFrPa } from "./connectors/fr_pa.ts";
import { submitGeneric } from "./connectors/generic.ts";
import { statusItSdi, submitItSdi } from "./connectors/it_sdi.ts";
import { statusPeppol, submitPeppol } from "./connectors/peppol.ts";
import { statusPlKsef, submitPlKsef } from "./connectors/pl_ksef.ts";
import {
  statusRoEfactura,
  submitRoEfactura,
} from "./connectors/ro_efactura.ts";

export type { Config, ConnectorDocument, Fetch, Submission };

export const PROVIDERS = [
  "generic",
  "peppol",
  "fr_pa",
  "it_sdi",
  "pl_ksef",
  "ro_efactura",
] as const;
export type Provider = (typeof PROVIDERS)[number];

export const isProvider = (value: string): value is Provider =>
  (PROVIDERS as readonly string[]).includes(value);

/** The documented test environments. A French accredited platform has
 * none shared — its URLs are the platform's own. */
export const SANDBOX: Record<Provider, Config> = {
  generic: {},
  peppol: { base_url: "https://api.storecove.com" },
  fr_pa: {},
  it_sdi: {
    base_url: "https://api-sandbox.acubeapi.com",
    login_url: "https://common-sandbox.api.acubeapi.com/login",
  },
  pl_ksef: { base_url: "https://ksef-test.mf.gov.pl/api/v2" },
  ro_efactura: { base_url: "https://api.anaf.ro/test/FCTEL/rest" },
};

/** The config fields a provider cannot send without. */
export function requiredFields(provider: string): string[] {
  switch (provider) {
    case "peppol":
      return ["base_url", "api_key", "legal_entity_id"];
    case "fr_pa":
      return ["base_url", "token_url", "client_id", "client_secret"];
    case "it_sdi":
      return ["base_url", "login_url", "username", "password"];
    case "pl_ksef":
      return ["base_url", "nip", "ksef_token"];
    case "ro_efactura":
      return ["base_url", "cif", "access_token"];
    default:
      return ["endpoint", "auth_value"];
  }
}

/** The syntaxes a provider accepts, by the app's format names. Empty =
 * anything (the generic upload decides for itself). */
export function acceptedFormats(provider: string): string[] {
  switch (provider) {
    case "peppol":
      return ["peppolBis", "xrechnung"];
    case "fr_pa":
      return ["en16931Cii", "facturX", "en16931Ubl"];
    case "it_sdi":
      return ["fatturaPa"];
    case "pl_ksef":
      return ["ksefFa3"];
    case "ro_efactura":
      return ["ciusRo"];
    default:
      return [];
  }
}

/** Sends [doc] through [provider]. A document in a syntax the provider
 * does not take is refused before anything leaves — a network that
 * rejects it later costs the customer a day. */
export async function submit(
  provider: string,
  cfg: Config,
  doc: ConnectorDocument,
  fetchImpl: Fetch = fetch,
): Promise<Submission> {
  const formats = acceptedFormats(provider);
  if (formats.length > 0 && !formats.includes(doc.format)) {
    // nothing has left: a refusal of ours, not the platform's verdict
    return {
      status: "failed",
      externalId: "",
      detail: `${provider} does not accept ${doc.format} ` +
        `(it takes ${formats.join(", ")})`,
      receipt: {},
    };
  }
  let dispatched = false;
  const tracked: ConnectorDocument = {
    ...doc,
    onDispatch: () => {
      dispatched = true;
    },
  };
  try {
    switch (provider) {
      case "peppol":
        return classify(
          await submitPeppol(cfg, tracked, fetchImpl),
          dispatched,
        );
      case "fr_pa":
        return classify(await submitFrPa(cfg, tracked, fetchImpl), dispatched);
      case "it_sdi":
        return classify(await submitItSdi(cfg, tracked, fetchImpl), dispatched);
      case "pl_ksef":
        return classify(
          await submitPlKsef(cfg, tracked, fetchImpl),
          dispatched,
        );
      case "ro_efactura":
        return classify(
          await submitRoEfactura(cfg, tracked, fetchImpl),
          dispatched,
        );
      default:
        return classify(
          await submitGeneric(cfg, tracked, fetchImpl),
          dispatched,
        );
    }
  } catch (error) {
    // A thrown error before the upload request left proves nothing was
    // accepted; after it, the upload may have landed (#3335).
    return classify(unreachable(error), dispatched);
  }
}

/** What an answer proves about acceptance (#3335). Before the request that
 * carries the document, nothing can have been accepted: `failed`. After it,
 * only an explicit refusal (a 4xx other than a timeout or a throttle) is
 * `rejected`; a thrown error, a 5xx, a timeout and an unreadable answer are
 * `uncertain` — they never permit another upload by themselves. A verdict
 * the connector itself read from a successful answer is kept as it is. */
export function classify(outcome: Submission, dispatched: boolean): Submission {
  if (outcome.status === "accepted") return outcome;
  // the destination guard refuses before any request is made (#3090)
  if (!dispatched || outcome.detail === "destination_not_allowed") {
    return outcome.status === "failed"
      ? outcome
      : { ...outcome, status: "failed" };
  }
  if (outcome.httpStatus === undefined) {
    // no HTTP refusal: a thrown error (failed) is uncertain after dispatch;
    // a connector-read document answer (rejected) stays a refusal
    return outcome.status === "failed"
      ? { ...outcome, status: "uncertain" }
      : outcome;
  }
  // 401/403/404: the credential or the endpoint was refused, the document
  // was not read — no effect, and once the owner fixes it the same record
  // may be dispatched again (a terminal `rejected` would block it for good)
  if ([401, 403, 404].includes(outcome.httpStatus)) {
    return { ...outcome, status: "failed" };
  }
  // 408/429 (timeout, throttle) and 409 (the platform may already hold it)
  // prove nothing; other 4xx refuse the document itself
  const refusal = outcome.httpStatus >= 400 && outcome.httpStatus < 500 &&
    ![408, 409, 429].includes(outcome.httpStatus);
  return refusal ? outcome : { ...outcome, status: "uncertain" };
}

/** Asks [provider] what became of an earlier submission. The generic
 * upload has no read-back: its platforms vary too much. */
export async function status(
  provider: string,
  cfg: Config,
  externalId: string,
  fetchImpl: Fetch = fetch,
): Promise<Submission> {
  try {
    switch (provider) {
      case "peppol":
        return await statusPeppol(cfg, externalId, fetchImpl);
      case "fr_pa":
        return await statusFrPa(cfg, externalId, fetchImpl);
      case "it_sdi":
        return await statusItSdi(cfg, externalId, fetchImpl);
      case "pl_ksef":
        return await statusPlKsef(cfg, externalId, fetchImpl);
      case "ro_efactura":
        return await statusRoEfactura(cfg, externalId, fetchImpl);
      default:
        return {
          status: "failed",
          externalId,
          detail: "the generic upload has no status read-back",
          receipt: {},
        };
    }
  } catch (error) {
    return unreachable(error);
  }
}
