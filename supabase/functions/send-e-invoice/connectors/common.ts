// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — what every e-invoicing connector shares: the shapes, and the
// one rule for turning a provider's answer into a logged outcome. Each
// connector is pure and takes its `fetch` as a parameter, so the tests
// answer for the provider and no request ever leaves a test run.

export type Config = Record<string, string>;
export type Fetch = typeof fetch;

export interface Submission {
  /** accepted = the platform took the upload; rejected = it affirmatively
   * refused the upload; failed = nothing can have been accepted (#3335);
   * uncertain = the upload may have landed and the answer is missing,
   * unreadable or ambiguous — never to be resent automatically. */
  status: "accepted" | "rejected" | "failed" | "uncertain";
  /** The HTTP status of a refusing answer, when there was one. */
  httpStatus?: number;
  externalId: string;
  detail: string;
  /** What the provider said about the document, as it said it: the
   * Peppol evidence, the SdI notification, the KSeF number and UPO
   * reference, the ANAF download id. Stored with the transmission. */
  receipt: Record<string, unknown>;
}

/** One provider, declared where it is implemented (#3337). The registry in
 * connectors.ts is the only list of them: removing a provider is deleting its
 * file and its line there, and no switch elsewhere names it. */
export interface Connector {
  /** The value of `einvoice_credentials.provider`. */
  id: string;
  /** The config fields the provider cannot send without. */
  requiredFields: string[];
  /** The syntaxes it accepts, by the app's format names; empty = anything. */
  acceptedFormats: string[];
  /** The documented test environment the owner starts from. */
  sandbox: Config;
  submit(
    cfg: Config,
    doc: ConnectorDocument,
    fetchImpl: Fetch,
  ): Promise<Submission>;
  /** What became of an earlier submission; absent = no read-back. */
  status?(
    cfg: Config,
    externalId: string,
    fetchImpl: Fetch,
  ): Promise<Submission>;
}

export interface ConnectorDocument {
  fileName: string;
  mimeType: string;
  bytes: Uint8Array<ArrayBuffer>;
  /** The app's EInvoiceFormat name (facturX, en16931Cii, peppolBis, …). */
  format: string;
  /** Where a network delivers it: the buyer's electronic address
   * (BT-49) — Peppol routes by it. */
  receiver?: { scheme: string; id: string };
  /** The invoice number, for providers that track by it. */
  number?: string;
  /** Called by a connector immediately before the request that carries the
   * document: from then on a missing or unreadable answer is `uncertain`,
   * before it nothing can have been accepted (#3335). */
  onDispatch?: () => void;
}

/** A provider's own words, cut to what a log row can hold. */
export const clip = (text: string, max = 500): string => text.slice(0, max);

/** A non-2xx answer: the provider said no. */
export async function refused(res: Response): Promise<Submission> {
  const text = await res.text();
  return {
    status: "rejected",
    httpStatus: res.status,
    externalId: "",
    detail: clip(`${res.status} ${text}`),
    receipt: {},
  };
}

/** The provider could not be reached (or answered something unreadable
 * before a decision existed). */
export const unreachable = (error: unknown): Submission => ({
  status: "failed",
  externalId: "",
  // A refused destination (#3090) keeps its fixed key; anything else is
  // the platform or the network speaking, clipped for the log.
  detail: error instanceof Error &&
      (error.message === "destination_not_allowed" ||
        error.message === "redirect_refused")
    ? error.message
    : clip(String(error)),
  receipt: {},
});

export const accepted = (
  externalId: string,
  detail: string,
  receipt: Record<string, unknown> = {},
): Submission => ({
  status: "accepted",
  externalId,
  detail: clip(detail),
  receipt,
});

export function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}

export function fromBase64(text: string): Uint8Array<ArrayBuffer> {
  return Uint8Array.from(atob(text), (c) => c.charCodeAt(0));
}

/** Joins a configured base URL and a path without doubling the slash. */
export const join = (base: string, path: string): string =>
  `${base.replace(/\/+$/, "")}/${path.replace(/^\/+/, "")}`;

/** Parses JSON when there is some; an empty or non-JSON body is `{}`. */
export function parseJson(text: string): Record<string, unknown> {
  try {
    const value = JSON.parse(text);
    return value && typeof value === "object"
      ? value as Record<string, unknown>
      : {};
  } catch {
    return {};
  }
}
