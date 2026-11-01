// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — HMRC Making Tax Digital for VAT, as far as it needs no credential:
// the OAuth target, the fraud-prevention headers of connection method
// WEB_APP_VIA_SERVER, the nine-box request body, the obligations read, the
// submission and the header validation, with HMRC's refusals told apart.
// Pure: `fetch` is a parameter, so the tests play HMRC and no request leaves
// a test run. The base URL is a setting of the installation (sandbox
// `https://test-api.service.hmrc.gov.uk`, production
// `https://api.service.hmrc.gov.uk`), never a constant here.
//
// Nothing in this module guesses a client value: a header HMRC requires of
// the browser that the browser did not send makes the call refuse, naming
// the header, instead of sending a plausible one.

import type { OAuthTarget } from "./accounting_targets.ts";
import type { Fetch } from "./accounting_oauth.ts";

export const HMRC_SCOPES = ["read:vat", "write:vat"];
const ACCEPT = "application/vnd.hmrc.1.0+json";

/** The OAuth target of an HMRC installation at [baseUrl]. */
export function hmrcTarget(baseUrl: string): OAuthTarget {
  const base = baseUrl.replace(/\/+$/, "");
  return {
    authorizeUrl: `${base}/oauth/authorize`,
    tokenUrl: `${base}/oauth/token`,
    scopes: HMRC_SCOPES,
    // spec: developer.service.hmrc.gov.uk — "User-restricted endpoints": the
    // person signs in at HMRC and the redirect carries code and state only.
    stateLifetimeMs: 10 * 60 * 1000,
  };
}

// ── the nine boxes ────────────────────────────────────────────────────────

/** The nine boxes under HMRC's field names: boxes 1-5 in pounds with pence,
 * boxes 6-9 in whole pounds (the same figures as the MTD bridging CSV). */
export interface NineBoxes {
  vatDueSales: number;
  vatDueAcquisitions: number;
  totalVatDue: number;
  vatReclaimedCurrPeriod: number;
  netVatDue: number;
  totalValueSalesExVAT: number;
  totalValuePurchasesExVAT: number;
  totalValueGoodsSuppliedExVAT: number;
  totalAcquisitionsExVAT: number;
}

const POUNDS_AND_PENCE: (keyof NineBoxes)[] = [
  "vatDueSales",
  "vatDueAcquisitions",
  "totalVatDue",
  "vatReclaimedCurrPeriod",
  "netVatDue",
];
const WHOLE_POUNDS: (keyof NineBoxes)[] = [
  "totalValueSalesExVAT",
  "totalValuePurchasesExVAT",
  "totalValueGoodsSuppliedExVAT",
  "totalAcquisitionsExVAT",
];

export class HmrcInputError extends Error {
  constructor(public readonly field: string, message: string) {
    super(message);
  }
}

const pence = (pounds: number) => Math.round(pounds * 100);

/** The submission body for [periodKey]: the nine boxes exactly, finalised.
 * HMRC's own arithmetic is checked first, so a wrong sum is refused here,
 * not after a round trip. */
export function returnBody(
  periodKey: string,
  boxes: NineBoxes,
): Record<string, unknown> {
  if (!/^[A-Z0-9#]{4}$/.test(periodKey)) {
    throw new HmrcInputError("periodKey", "the period key is four characters");
  }
  for (const key of [...POUNDS_AND_PENCE, ...WHOLE_POUNDS]) {
    const v = boxes[key];
    if (typeof v !== "number" || !Number.isFinite(v)) {
      throw new HmrcInputError(key, `${key} is not a number`);
    }
  }
  for (const key of POUNDS_AND_PENCE) {
    if (Math.abs(boxes[key] * 100 - pence(boxes[key])) > 1e-6) {
      throw new HmrcInputError(key, `${key} has more than two decimals`);
    }
  }
  for (const key of WHOLE_POUNDS) {
    if (!Number.isInteger(boxes[key])) {
      throw new HmrcInputError(key, `${key} is whole pounds`);
    }
  }
  if (
    pence(boxes.vatDueSales) + pence(boxes.vatDueAcquisitions) !==
      pence(boxes.totalVatDue)
  ) {
    throw new HmrcInputError("totalVatDue", "box 3 is box 1 plus box 2");
  }
  if (
    Math.abs(pence(boxes.totalVatDue) - pence(boxes.vatReclaimedCurrPeriod)) !==
      pence(boxes.netVatDue)
  ) {
    throw new HmrcInputError(
      "netVatDue",
      "box 5 is the difference of box 3 and box 4, unsigned",
    );
  }
  return { periodKey, ...boxes, finalised: true };
}

// ── fraud-prevention headers (WEB_APP_VIA_SERVER) ─────────────────────────

/** What only the person's browser knows, collected by the web client. */
export interface ClientValues {
  browserJsUserAgent: string;
  deviceId: string;
  /** The person's id in the product, for Gov-Client-User-IDs. */
  userId: string;
  /** `UTC+01:00`. */
  timezone: string;
  /** `width=1920&height=1080&scaling-factor=1&colour-depth=24`. */
  screens: string;
  /** `width=1256&height=803`. */
  windowSize: string;
  doNotTrack: boolean;
  /** Present only when the person signed in with a second factor. */
  multiFactor?: string;
  /** The person's public IP as the SERVER saw it, with the instant. */
  publicIp: string;
  publicIpTimestamp: string;
  publicPort: string;
}

/** What only the server knows. */
export interface VendorValues {
  productName: string;
  /** `deskilo=1.4.0`. */
  version: string;
  /** The server's public IP, and the client's as it reached the server. */
  publicIp: string;
  forwardedFor: string;
  /** Licence ids, hashed, when the installation has any. */
  licenseIds?: string;
}

export class FraudHeadersMissing extends Error {
  constructor(public readonly missing: string[]) {
    super(`missing fraud-prevention values: ${missing.join(", ")}`);
  }
}

const enc = encodeURIComponent;

/** The headers of connection method WEB_APP_VIA_SERVER, percent-encoded as
 * HMRC's specification asks. Throws [FraudHeadersMissing] naming every
 * required header the caller could not supply. */
export function fraudHeaders(
  client: ClientValues,
  vendor: VendorValues,
): Record<string, string> {
  const required: [string, string | undefined][] = [
    ["Gov-Client-Browser-JS-User-Agent", client.browserJsUserAgent],
    ["Gov-Client-Device-ID", client.deviceId],
    ["Gov-Client-User-IDs", client.userId],
    ["Gov-Client-Timezone", client.timezone],
    ["Gov-Client-Screens", client.screens],
    ["Gov-Client-Window-Size", client.windowSize],
    ["Gov-Client-Public-IP", client.publicIp],
    ["Gov-Client-Public-IP-Timestamp", client.publicIpTimestamp],
    ["Gov-Client-Public-Port", client.publicPort],
    ["Gov-Vendor-Product-Name", vendor.productName],
    ["Gov-Vendor-Version", vendor.version],
    ["Gov-Vendor-Public-IP", vendor.publicIp],
    ["Gov-Vendor-Forwarded", vendor.forwardedFor],
  ];
  const missing = required.filter(([, v]) => !v || v.trim().length === 0).map((
    [k],
  ) => k);
  if (missing.length > 0) throw new FraudHeadersMissing(missing);

  const headers: Record<string, string> = {
    "Gov-Client-Connection-Method": "WEB_APP_VIA_SERVER",
    "Gov-Client-Browser-JS-User-Agent": client.browserJsUserAgent,
    "Gov-Client-Device-ID": client.deviceId,
    "Gov-Client-User-IDs": `deskilo=${enc(client.userId)}`,
    "Gov-Client-Timezone": client.timezone,
    "Gov-Client-Screens": client.screens,
    "Gov-Client-Window-Size": client.windowSize,
    "Gov-Client-Browser-Do-Not-Track": client.doNotTrack ? "true" : "false",
    "Gov-Client-Public-IP": client.publicIp,
    "Gov-Client-Public-IP-Timestamp": client.publicIpTimestamp,
    "Gov-Client-Public-Port": client.publicPort,
    "Gov-Vendor-Product-Name": enc(vendor.productName),
    "Gov-Vendor-Version": vendor.version,
    "Gov-Vendor-Public-IP": vendor.publicIp,
    "Gov-Vendor-Forwarded": `by=${vendor.publicIp}&for=${client.publicIp}`,
  };
  // Only when the person used a second factor: never invented.
  if (client.multiFactor) {
    headers["Gov-Client-Multi-Factor"] = client.multiFactor;
  }
  if (vendor.licenseIds) headers["Gov-Vendor-License-IDs"] = vendor.licenseIds;
  return headers;
}

// ── the API ───────────────────────────────────────────────────────────────

export interface Obligation {
  periodKey: string;
  start: string;
  end: string;
  due: string;
  status: string;
}

/** Why a call did not give an answer. */
export type HmrcFailure = {
  ok: false;
  /** `token`: the access token is not accepted (refresh it);
   * `not_authorised`: the person or the VRN may not do this at HMRC;
   * `already_submitted`: HMRC has this period (409);
   * `refused`: HMRC rejected the request (400/422), with its code;
   * `busy`: rate limited (429);
   * `unreachable`: no answer or a server fault. */
  reason:
    | "token"
    | "not_authorised"
    | "already_submitted"
    | "refused"
    | "busy"
    | "unreachable";
  status: number;
  /** HMRC's own error code, e.g. `DUPLICATE_SUBMISSION`; never a token. */
  code: string;
};

async function call(
  fetchImpl: Fetch,
  url: string,
  init: RequestInit,
): Promise<{ ok: true; body: Record<string, unknown> } | HmrcFailure> {
  let res: Response;
  try {
    res = await fetchImpl(url, init);
  } catch {
    return { ok: false, reason: "unreachable", status: 0, code: "NETWORK" };
  }
  let body: Record<string, unknown> = {};
  try {
    body = await res.json();
  } catch {
    // not JSON: the status alone answers
  }
  if (res.ok) return { ok: true, body };
  const code =
    (typeof body.code === "string" ? body.code : `HTTP_${res.status}`).slice(
      0,
      60,
    );
  const reason: HmrcFailure["reason"] = res.status === 401
    ? "token"
    : res.status === 403
    ? "not_authorised"
    : res.status === 409
    ? "already_submitted"
    : res.status === 429
    ? "busy"
    : res.status >= 500
    ? "unreachable"
    : "refused";
  return { ok: false, reason, status: res.status, code };
}

const authed = (accessToken: string, fraud: Record<string, string>) => ({
  accept: ACCEPT,
  authorization: `Bearer ${accessToken}`,
  ...fraud,
});

const vrnOf = (vrn: string) => {
  if (!/^\d{9}$/.test(vrn)) {
    throw new HmrcInputError("vrn", "a VRN is nine digits");
  }
  return vrn;
};

/** The open obligations of [vrn] between two days (YYYY-MM-DD). */
export async function openObligations(
  fetchImpl: Fetch,
  baseUrl: string,
  vrn: string,
  accessToken: string,
  fraud: Record<string, string>,
  from: string,
  to: string,
): Promise<{ ok: true; obligations: Obligation[] } | HmrcFailure> {
  const url =
    `${baseUrl.replace(/\/+$/, "")}/organisations/vat/${
      vrnOf(vrn)
    }/obligations` +
    `?from=${enc(from)}&to=${enc(to)}&status=O`;
  const r = await call(fetchImpl, url, {
    method: "GET",
    headers: authed(accessToken, fraud),
  });
  if (!r.ok) return r;
  const list = Array.isArray(r.body.obligations)
    ? r.body.obligations as Record<string, unknown>[]
    : [];
  return {
    ok: true,
    obligations: list.map((o) => ({
      periodKey: String(o.periodKey ?? ""),
      start: String(o.start ?? ""),
      end: String(o.end ?? ""),
      due: String(o.due ?? ""),
      status: String(o.status ?? ""),
    })).filter((o) => o.periodKey.length > 0),
  };
}

/** The open obligation whose period is exactly [start]..[end], if any. */
export function obligationFor(
  obligations: Obligation[],
  start: string,
  end: string,
): Obligation | null {
  return obligations.find((o) => o.start === start && o.end === end) ?? null;
}

/** What HMRC gives back for an accepted return: the receipt. */
export interface Receipt {
  formBundleNumber: string;
  processingDate: string;
  chargeRefNumber: string | null;
}

export async function submitReturn(
  fetchImpl: Fetch,
  baseUrl: string,
  vrn: string,
  accessToken: string,
  fraud: Record<string, string>,
  periodKey: string,
  boxes: NineBoxes,
): Promise<{ ok: true; receipt: Receipt } | HmrcFailure> {
  const body = returnBody(periodKey, boxes);
  const url = `${baseUrl.replace(/\/+$/, "")}/organisations/vat/${
    vrnOf(vrn)
  }/returns`;
  const r = await call(fetchImpl, url, {
    method: "POST",
    headers: {
      ...authed(accessToken, fraud),
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!r.ok) return r;
  const bundle = typeof r.body.formBundleNumber === "string"
    ? r.body.formBundleNumber
    : "";
  if (!bundle) {
    return {
      ok: false,
      reason: "unreachable",
      status: 200,
      code: "NO_RECEIPT",
    };
  }
  return {
    ok: true,
    receipt: {
      formBundleNumber: bundle,
      processingDate: String(r.body.processingDate ?? ""),
      chargeRefNumber: typeof r.body.chargeRefNumber === "string"
        ? r.body.chargeRefNumber
        : null,
    },
  };
}

/** HMRC's validator for the headers (sandbox tooling): its verdict and its
 * findings, as the API words them. */
export async function validateHeaders(
  fetchImpl: Fetch,
  baseUrl: string,
  accessToken: string,
  fraud: Record<string, string>,
): Promise<{ ok: true; code: string; errors: unknown[] } | HmrcFailure> {
  const url = `${
    baseUrl.replace(/\/+$/, "")
  }/test/fraud-prevention-headers/validate`;
  let res: Response;
  try {
    res = await fetchImpl(url, {
      method: "GET",
      headers: authed(accessToken, fraud),
    });
  } catch {
    return { ok: false, reason: "unreachable", status: 0, code: "NETWORK" };
  }
  let body: Record<string, unknown> = {};
  try {
    body = await res.json();
  } catch {
    // not JSON
  }
  // 200 = valid (maybe with advisories), 400 = the validator found errors.
  if (res.status === 200 || res.status === 400) {
    return {
      ok: true,
      code: typeof body.code === "string"
        ? body.code
        : res.status === 200
        ? "VALID_HEADERS"
        : "INVALID_HEADERS",
      errors: Array.isArray(body.errors) ? body.errors : [],
    };
  }
  return {
    ok: false,
    reason: res.status === 401 ? "token" : "unreachable",
    status: res.status,
    code: `HTTP_${res.status}`,
  };
}
