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
  Connector,
  ConnectorDocument,
  Fetch,
  Submission,
  unreachable,
} from "./connectors/common.ts";
import { frPaConnector } from "./connectors/fr_pa.ts";
import { genericConnector } from "./connectors/generic.ts";
import { itSdiConnector } from "./connectors/it_sdi.ts";
import { peppolConnector } from "./connectors/peppol.ts";
import { plKsefConnector } from "./connectors/pl_ksef.ts";
import { roEfacturaConnector } from "./connectors/ro_efactura.ts";

export type { Config, ConnectorDocument, Fetch, Submission };

/** THE list of installed connectors (#3337). A provider is removed by
 * deleting its file and its line here; nothing below names a provider. The
 * generic upload stays first: it answers for every provider value that has
 * no connector of its own. */
const CONNECTORS: readonly Connector[] = [
  genericConnector,
  peppolConnector,
  frPaConnector,
  itSdiConnector,
  plKsefConnector,
  roEfacturaConnector,
];

/** The registry of a list of connectors (#3338). The installed one is built
 * from [CONNECTORS]; a test builds one WITHOUT a connector to prove the others
 * keep working when a country's provider is retired. Every operation is
 * derived from the list: nothing here names a provider. */
export function buildRegistry(list: readonly Connector[]) {
  const connectorOf = (provider: string): Connector =>
    list.find((c) => c.id === provider) ?? genericConnector;
  const providers: readonly string[] = list.map((c) => c.id);
  const requiredFields = (provider: string): string[] =>
    connectorOf(provider).requiredFields;
  const acceptedFormats = (provider: string): string[] =>
    connectorOf(provider).acceptedFormats;

  /** Sends [doc] through [provider]. A document in a syntax the provider
   * does not take is refused before anything leaves — a network that
   * rejects it later costs the customer a day. */
  async function submit(
    provider: string,
    cfg: Config,
    doc: ConnectorDocument,
    fetchImpl: Fetch = fetch,
  ): Promise<Submission> {
    if (!list.some((c) => c.id === provider)) {
      // a retired or unknown provider never falls back to the generic upload
      // (#3338): nothing leaves, and the owner is told why
      return {
        status: "failed",
        externalId: "",
        detail: `no connector is installed for ${provider}`,
        receipt: {},
      };
    }
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
      return classify(
        await connectorOf(provider).submit(cfg, tracked, fetchImpl),
        dispatched,
      );
    } catch (error) {
      // A thrown error before the upload request left proves nothing was
      // accepted; after it, the upload may have landed (#3335).
      return classify(unreachable(error), dispatched);
    }
  }

  /** Asks [provider] what became of an earlier submission. The generic
   * upload has no read-back: its platforms vary too much. */
  async function status(
    provider: string,
    cfg: Config,
    externalId: string,
    fetchImpl: Fetch = fetch,
  ): Promise<Submission> {
    if (!list.some((c) => c.id === provider)) {
      return {
        status: "failed",
        externalId,
        detail: `no connector is installed for ${provider}`,
        receipt: {},
      };
    }
    const readBack = connectorOf(provider).status;
    if (readBack === undefined) {
      return {
        status: "failed",
        externalId,
        detail: "the generic upload has no status read-back",
        receipt: {},
      };
    }
    try {
      return await readBack(cfg, externalId, fetchImpl);
    } catch (error) {
      return unreachable(error);
    }
  }

  return { providers, requiredFields, acceptedFormats, submit, status };
}

const installed = buildRegistry(CONNECTORS);

export const PROVIDERS: readonly string[] = installed.providers;
export type Provider = string;

export const isProvider = (value: string): boolean => PROVIDERS.includes(value);

/** The documented test environments. A French accredited platform has
 * none shared — its URLs are the platform's own. */
export const SANDBOX: Record<string, Config> = Object.fromEntries(
  CONNECTORS.map((c) => [c.id, c.sandbox]),
);

/** The config fields a provider cannot send without. */
export const requiredFields = installed.requiredFields;

/** The syntaxes a provider accepts, by the app's format names. Empty =
 * anything (the generic upload decides for itself). */
export const acceptedFormats = installed.acceptedFormats;

export const submit = installed.submit;
export const status = installed.status;

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
