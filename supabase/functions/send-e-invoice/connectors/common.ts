// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — what every e-invoicing connector shares: the shapes, and the
// one rule for turning a provider's answer into a logged outcome. Each
// connector is pure and takes its `fetch` as a parameter, so the tests
// answer for the provider and no request ever leaves a test run.

export type Config = Record<string, string>;
export type Fetch = typeof fetch;

export interface Submission {
  status: "accepted" | "rejected" | "failed";
  externalId: string;
  detail: string;
  /** What the provider said about the document, as it said it: the
   * Peppol evidence, the SdI notification, the KSeF number and UPO
   * reference, the ANAF download id. Stored with the transmission. */
  receipt: Record<string, unknown>;
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
}

/** A provider's own words, cut to what a log row can hold. */
export const clip = (text: string, max = 500): string => text.slice(0, max);

/** A non-2xx answer: the provider said no. */
export async function refused(res: Response): Promise<Submission> {
  const text = await res.text();
  return {
    status: "rejected",
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
  detail: clip(String(error)),
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
