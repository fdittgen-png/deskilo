// SPDX-License-Identifier: AGPL-3.0-or-later
//
// pl_ksef — Krajowy System e-Faktur, API 2.0 (Ministerstwo Finansów,
// "KSeF API 2.0" OpenAPI and its integration guide, test environment
// ksef-test.mf.gov.pl/api/v2). The exchange: a challenge; the company's
// KSeF token encrypted with the ministry's RSA key (RSA-OAEP, SHA-256)
// over "token|timestampMs"; the authentication polled until it succeeds;
// an access token redeemed; an online session opened with a fresh
// AES-256 key wrapped by the ministry's key; the FA(3) invoice sent
// AES-256-CBC encrypted with the SHA-256 and size of both forms; the
// session closed. The status read returns the KSeF number and the UPO.
//
// The live round-trip needs the KSeF token the owner generates in the
// test environment for the company's NIP; nothing here has been
// exchanged with KSeF yet. Every path and field name sits in KSEF below,
// so a correction after that round-trip is one line.

import {
  accepted,
  Config,
  ConnectorDocument,
  Fetch,
  fromBase64,
  join,
  parseJson,
  refused,
  Submission,
  toBase64,
} from "./common.ts";
import { spkiOfCertificate } from "./der.ts";

/** The API as the KSeF 2.0 documentation names it. */
export const KSEF = {
  certificates: "security/public-key-certificates",
  challenge: "auth/challenge",
  tokenAuth: "auth/ksef-token",
  authStatus: (ref: string) => `auth/${ref}`,
  redeem: "auth/token/redeem",
  openSession: "sessions/online",
  sendInvoice: (session: string) => `sessions/online/${session}/invoices`,
  closeSession: (session: string) => `sessions/online/${session}/close`,
  invoiceStatus: (session: string, invoice: string) =>
    `sessions/${session}/invoices/${invoice}`,
  /** The certificate usages that select the right key. */
  usageToken: "KsefTokenEncryption",
  usageSymmetric: "SymmetricKeyEncryption",
  formCode: { systemCode: "FA (3)", schemaVersion: "1-0E", value: "FA" },
  /** Authentication status codes: 100 in progress, 200 done. */
  authDone: 200,
  authPending: 100,
  pollAttempts: 10,
  pollDelayMs: 1000,
} as const;

async function sha256(
  bytes: Uint8Array<ArrayBuffer>,
): Promise<Uint8Array<ArrayBuffer>> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
}

/** RSA-OAEP (SHA-256) with the key of a DER certificate. */
export async function rsaEncrypt(
  certificateDer: Uint8Array,
  data: Uint8Array<ArrayBuffer>,
): Promise<Uint8Array<ArrayBuffer>> {
  const key = await crypto.subtle.importKey(
    "spki",
    spkiOfCertificate(certificateDer),
    { name: "RSA-OAEP", hash: "SHA-256" },
    false,
    ["encrypt"],
  );
  return new Uint8Array(
    await crypto.subtle.encrypt({ name: "RSA-OAEP" }, key, data),
  );
}

/** AES-256-CBC with PKCS#7 padding (WebCrypto pads AES-CBC itself). */
export async function aesEncrypt(
  rawKey: Uint8Array<ArrayBuffer>,
  iv: Uint8Array<ArrayBuffer>,
  data: Uint8Array<ArrayBuffer>,
): Promise<Uint8Array<ArrayBuffer>> {
  const key = await crypto.subtle.importKey(
    "raw",
    rawKey,
    { name: "AES-CBC" },
    false,
    ["encrypt"],
  );
  return new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-CBC", iv }, key, data),
  );
}

type Step<T> = T | Response;

const json = (token?: string): HeadersInit => ({
  "Content-Type": "application/json",
  "Accept": "application/json",
  ...(token ? { "Authorization": `Bearer ${token}` } : {}),
});

async function call(
  fetchImpl: Fetch,
  url: string,
  init: RequestInit,
): Promise<Step<Record<string, unknown>>> {
  const res = await fetchImpl(url, init);
  if (!res.ok) return res;
  return parseJson(await res.text());
}

/** The ministry's certificate for [usage]. */
async function certificate(
  cfg: Config,
  usage: string,
  fetchImpl: Fetch,
): Promise<Step<Uint8Array>> {
  const res = await fetchImpl(join(cfg.base_url, KSEF.certificates), {
    method: "GET",
    headers: json(),
  });
  if (!res.ok) return res;
  const list = JSON.parse(await res.text()) as Array<Record<string, unknown>>;
  const found = list.find((c) =>
    Array.isArray(c.usage) && (c.usage as string[]).includes(usage)
  );
  if (!found || typeof found.certificate !== "string") {
    return new Response(`no ${usage} certificate`, { status: 502 });
  }
  return fromBase64(found.certificate);
}

/** Challenge → encrypted token → poll → access token. */
export async function authenticate(
  cfg: Config,
  fetchImpl: Fetch,
  sleep: (ms: number) => Promise<void> = (ms) =>
    new Promise((r) => setTimeout(r, ms)),
): Promise<Step<string>> {
  const cert = await certificate(cfg, KSEF.usageToken, fetchImpl);
  if (cert instanceof Response) return cert;
  const challenge = await call(fetchImpl, join(cfg.base_url, KSEF.challenge), {
    method: "POST",
    headers: json(),
  });
  if (challenge instanceof Response) return challenge;
  const timestampMs = typeof challenge.timestampMs === "number"
    ? challenge.timestampMs
    : Date.parse(String(challenge.timestamp));
  const encryptedToken = await rsaEncrypt(
    cert,
    new TextEncoder().encode(`${cfg.ksef_token}|${timestampMs}`),
  );
  const auth = await call(fetchImpl, join(cfg.base_url, KSEF.tokenAuth), {
    method: "POST",
    headers: json(),
    body: JSON.stringify({
      challenge: challenge.challenge,
      contextIdentifier: { type: "Nip", value: cfg.nip },
      encryptedToken: toBase64(encryptedToken),
    }),
  });
  if (auth instanceof Response) return auth;
  const ref = String(auth.referenceNumber ?? "");
  const authToken = String(
    (auth.authenticationToken as Record<string, unknown> | undefined)?.token ??
      "",
  );
  for (let i = 0; i < KSEF.pollAttempts; i++) {
    const state = await call(
      fetchImpl,
      join(cfg.base_url, KSEF.authStatus(encodeURIComponent(ref))),
      { method: "GET", headers: json(authToken) },
    );
    if (state instanceof Response) return state;
    const code = Number(
      (state.status as Record<string, unknown> | undefined)?.code,
    );
    if (code === KSEF.authDone) break;
    if (code !== KSEF.authPending) {
      return new Response(JSON.stringify(state), { status: 401 });
    }
    if (i === KSEF.pollAttempts - 1) {
      return new Response("authentication still pending", { status: 504 });
    }
    await sleep(KSEF.pollDelayMs);
  }
  const redeemed = await call(fetchImpl, join(cfg.base_url, KSEF.redeem), {
    method: "POST",
    headers: json(authToken),
  });
  if (redeemed instanceof Response) return redeemed;
  const access = (redeemed.accessToken as Record<string, unknown> | undefined)
    ?.token;
  return typeof access === "string"
    ? access
    : new Response("no access token", { status: 502 });
}

export async function submitPlKsef(
  cfg: Config,
  doc: ConnectorDocument,
  fetchImpl: Fetch,
  sleep?: (ms: number) => Promise<void>,
): Promise<Submission> {
  const token = await authenticate(cfg, fetchImpl, sleep);
  if (token instanceof Response) return refused(token);
  const cert = await certificate(cfg, KSEF.usageSymmetric, fetchImpl);
  if (cert instanceof Response) return refused(cert);
  const aesKey = crypto.getRandomValues(new Uint8Array(32));
  const iv = crypto.getRandomValues(new Uint8Array(16));
  const opened = await call(fetchImpl, join(cfg.base_url, KSEF.openSession), {
    method: "POST",
    headers: json(token),
    body: JSON.stringify({
      formCode: KSEF.formCode,
      encryption: {
        encryptedSymmetricKey: toBase64(await rsaEncrypt(cert, aesKey)),
        initializationVector: toBase64(iv),
      },
    }),
  });
  if (opened instanceof Response) return refused(opened);
  const session = String(opened.referenceNumber ?? "");
  const encrypted = await aesEncrypt(aesKey, iv, doc.bytes);
  const sent = await call(
    fetchImpl,
    join(cfg.base_url, KSEF.sendInvoice(encodeURIComponent(session))),
    {
      method: "POST",
      headers: json(token),
      body: JSON.stringify({
        invoiceHash: toBase64(await sha256(doc.bytes)),
        invoiceSize: doc.bytes.length,
        encryptedInvoiceHash: toBase64(await sha256(encrypted)),
        encryptedInvoiceSize: encrypted.length,
        encryptedInvoiceContent: toBase64(encrypted),
        offlineMode: false,
      }),
    },
  );
  if (sent instanceof Response) return refused(sent);
  const invoiceRef = String(sent.referenceNumber ?? "");
  // Closing starts the UPO; a failed close leaves the invoice sent, so it
  // is recorded in the receipt rather than turning the send into a refusal.
  const closed = await fetchImpl(
    join(cfg.base_url, KSEF.closeSession(encodeURIComponent(session))),
    { method: "POST", headers: json(token) },
  );
  return accepted(`${session}/${invoiceRef}`, JSON.stringify(sent), {
    sessionReferenceNumber: session,
    invoiceReferenceNumber: invoiceRef,
    sessionClosed: closed.ok,
  });
}

/** The invoice's processing status: the KSeF number once accepted, and
 * where its UPO (urzędowe poświadczenie odbioru) can be read. */
export async function statusPlKsef(
  cfg: Config,
  externalId: string,
  fetchImpl: Fetch,
  sleep?: (ms: number) => Promise<void>,
): Promise<Submission> {
  const [session, invoice] = externalId.split("/");
  if (!session || !invoice) {
    return {
      status: "failed",
      externalId,
      detail: "not a KSeF session/invoice reference",
      receipt: {},
    };
  }
  const token = await authenticate(cfg, fetchImpl, sleep);
  if (token instanceof Response) return refused(token);
  const res = await fetchImpl(
    join(
      cfg.base_url,
      KSEF.invoiceStatus(
        encodeURIComponent(session),
        encodeURIComponent(invoice),
      ),
    ),
    { method: "GET", headers: json(token) },
  );
  if (!res.ok) return refused(res);
  const text = await res.text();
  const body = parseJson(text);
  const state = body.status as Record<string, unknown> | undefined;
  const receipt = {
    ksefNumber: body.ksefNumber ?? "",
    statusCode: state?.code ?? null,
    statusDescription: state?.description ?? "",
    upoDownloadUrl: body.upoDownloadUrl ?? "",
  };
  const code = Number(state?.code);
  if (Number.isFinite(code) && code >= 400) {
    return {
      status: "rejected",
      externalId,
      detail: text.slice(0, 500),
      receipt,
    };
  }
  return accepted(externalId, text, receipt);
}
