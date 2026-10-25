// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the adapter of the accounting target `pennylane_api`: the
// Pennylane external API v2, the most used SME accounting platform in
// France. What it sends:
//
//   * every issued invoice and credit note as a customer invoice created
//     ALREADY ISSUED (imported, never a draft Pennylane would number
//     again), with its legal number as it is and its PDF/A-3 as the
//     voucher (the *justificatif*);
//   * payments and write-offs as balanced ledger entries.
//
// Delivery is idempotent: each document is first read back by its
// `external_reference` (the app's document id), and a document Pennylane
// already holds is reported `exists`, never created twice.
//
// The adapter is pure and takes `fetch` as a parameter, so the tests play
// Pennylane and no request leaves a test run (adapter_test.ts). The live
// exchange is NOT RUN: it needs a Pennylane sandbox company the owner
// opens, and the connection and credential store it plugs into (OAuth
// tokens, their refresh, the delivery log) is the adapter kit of #2370,
// not yet on master. The directory has no index.ts on purpose: it is a
// module for that kit, not an Edge function of its own.
//
// Every field name follows the Pennylane API v2 reference as far as it
// could be read without an account; a mapping not yet verified against
// the live API says so in a `// spec:` comment naming where to check.

import { exponentOf, toMajor } from "../_shared/money.ts";

export type Config = Record<string, string>;
export type Fetch = typeof fetch;

/** The config fields a delivery cannot run without. */
export const requiredFields = ["base_url", "access_token"] as const;

/** Pennylane documents no shared sandbox host: a sandbox is a test
 * company on the production API, so the base URL is the same and the
 * token decides which company is written to.
 * spec: developers.pennylane.com — "Sandbox" / "Getting started". */
export const SANDBOX: Config = {
  base_url: "https://app.pennylane.com/api/external/v2",
};

/** One line of an issued document, in integer minor units. */
export interface PennylaneLine {
  label: string;
  /** Net amount (before tax), minor units. */
  netMinor: number;
  /** Tax amount, minor units. */
  vatMinor: number;
  /** The rate as the document states it, a decimal string ("20", "5.5"). */
  vatRate: string;
}

/** An issued invoice or credit note, as the app holds it. */
export interface PennylaneDocument {
  /** The app's document id: Pennylane's `external_reference`. */
  id: string;
  /** The legal number, carried as it is. */
  number: string;
  kind: "invoice" | "credit_note";
  /** YYYY-MM-DD. */
  issueDate: string;
  /** YYYY-MM-DD; the issue date when the document has no due date. */
  dueDate?: string;
  currency: string;
  customer: { number: string; name: string; legalId?: string };
  lines: PennylaneLine[];
  /** The document's gross total, minor units (credit note: negative). */
  totalMinor: number;
  label?: string;
  pdf: { fileName: string; bytes: Uint8Array };
}

/** A payment or write-off, as a balanced entry of the books. */
export interface PennylaneJournalEntry {
  /** The app's posting id: the entry's external reference. */
  id: string;
  /** YYYY-MM-DD. */
  date: string;
  /** The app's journal code (BQ, OD). */
  journalCode: string;
  label: string;
  /** The document the entry settles, by its legal number. */
  documentReference: string;
  currency: string;
  lines: {
    account: string;
    debitMinor: number;
    creditMinor: number;
    label?: string;
  }[];
}

/** Why something was not delivered. Never thrown: returned. */
export type FailureReason =
  | "reauth_needed" // 401: the token is gone; the kit refreshes or asks
  | "rejected" // 422 and other 4xx: Pennylane said no, with its words
  | "retry_later" // 429 and 5xx: try again later
  | "unbalanced" // an entry whose debits and credits differ
  | "unsupported" // a currency or VAT rate the adapter cannot state
  | "unreachable"; // no answer at all

export interface Failure {
  reason: FailureReason;
  detail: string;
}

export interface Delivery {
  documentId: string;
  status: "created" | "exists" | "failed";
  pennylaneId?: string;
  error?: Failure;
}

/** Pennylane's VAT rate codes for the French rates.
 * spec: API v2 reference, "Customer invoices" → invoice_lines.vat_rate
 * enum (FR_200, FR_100, FR_85, FR_55, FR_21, exempt). */
const VAT_CODES: Record<string, string> = {
  "20": "FR_200",
  "10": "FR_100",
  "8.5": "FR_85",
  "5.5": "FR_55",
  "2.1": "FR_21",
  "0": "exempt",
};

const normaliseRate = (rate: string): string =>
  rate.trim().replace(",", ".").replace(/(\.\d*?)0+$/, "$1").replace(
    /\.$/,
    "",
  );

/** A typed refusal while building a payload. */
export class PayloadRefusal extends Error {
  constructor(readonly failure: Failure) {
    super(`${failure.reason}: ${failure.detail}`);
    this.name = "PayloadRefusal";
  }
}

/** Minor units → the decimal string Pennylane reads, from the digits. */
export function amount(minor: number, currency: string): string {
  if (exponentOf(currency) === null) {
    throw new PayloadRefusal({ reason: "unsupported", detail: currency });
  }
  return toMajor(minor, currency);
}

function vatCode(rate: string): string {
  const code = VAT_CODES[normaliseRate(rate)];
  if (!code) {
    throw new PayloadRefusal({ reason: "unsupported", detail: `VAT ${rate}` });
  }
  return code;
}

/** The body of `POST /customer_invoices/import`: the document as ALREADY
 * ISSUED, its PDF the attachment [fileAttachmentId], its customer
 * [customerId]. Throws [PayloadRefusal] for an unstated currency or rate. */
export function customerInvoicePayload(
  doc: PennylaneDocument,
  ids: { fileAttachmentId: number; customerId: number },
): Record<string, unknown> {
  const c = doc.currency.toUpperCase();
  const net = doc.lines.reduce((s, l) => s + l.netMinor, 0);
  const tax = doc.lines.reduce((s, l) => s + l.vatMinor, 0);
  return {
    file_attachment_id: ids.fileAttachmentId,
    customer_id: ids.customerId,
    // The legal number, as it is: Pennylane must not renumber.
    invoice_number: doc.number,
    external_reference: doc.id,
    date: doc.issueDate,
    deadline: doc.dueDate ?? doc.issueDate,
    currency: c,
    // spec: "Import a customer invoice" — currency_amount_before_tax,
    // currency_tax and currency_amount are the document-currency totals;
    // a credit note is imported with negative amounts (verify against
    // the credit-note section of the same page).
    currency_amount_before_tax: amount(net, c),
    currency_tax: amount(tax, c),
    currency_amount: amount(doc.totalMinor, c),
    label: doc.label ?? doc.number,
    invoice_lines: doc.lines.map((l) => ({
      label: l.label,
      quantity: "1",
      // spec: invoice_lines — raw_currency_unit_price is the unit price
      // before tax; unit is free text ("piece" in the examples).
      raw_currency_unit_price: amount(l.netMinor, c),
      unit: "piece",
      vat_rate: vatCode(l.vatRate),
      currency_amount: amount(l.netMinor + l.vatMinor, c),
      currency_tax: amount(l.vatMinor, c),
    })),
  };
}

/** The body of `POST /ledger_entries` for a payment or write-off, its
 * accounts and journal resolved to Pennylane ids by [accountIds] (by
 * number) and [journalId]. Throws [PayloadRefusal] when the entry does not
 * balance or names an account Pennylane does not hold. */
export function journalEntryPayload(
  entry: PennylaneJournalEntry,
  accountIds: Record<string, number>,
  journalId: number,
): Record<string, unknown> {
  const c = entry.currency.toUpperCase();
  let debit = 0;
  let credit = 0;
  for (const l of entry.lines) {
    if (
      !Number.isInteger(l.debitMinor) || !Number.isInteger(l.creditMinor) ||
      l.debitMinor < 0 || l.creditMinor < 0 ||
      (l.debitMinor === 0) === (l.creditMinor === 0)
    ) {
      throw new PayloadRefusal({
        reason: "unbalanced",
        detail: `${entry.documentReference}: a line is one debit or one credit`,
      });
    }
    debit += l.debitMinor;
    credit += l.creditMinor;
  }
  if (entry.lines.length < 2 || debit !== credit) {
    throw new PayloadRefusal({
      reason: "unbalanced",
      detail: `${entry.documentReference}: debit ${debit} ≠ credit ${credit}`,
    });
  }
  return {
    date: entry.date,
    label: entry.label,
    journal_id: journalId,
    // spec: "Create a ledger entry" — whether ledger_entries take an
    // external_reference or only a label/piece number.
    external_reference: entry.id,
    piece_number: entry.documentReference,
    currency: c,
    ledger_entry_lines: entry.lines.map((l) => {
      const id = accountIds[l.account];
      if (id === undefined) {
        throw new PayloadRefusal({
          reason: "rejected",
          detail: `account ${l.account} is not in the Pennylane chart`,
        });
      }
      return {
        ledger_account_id: id,
        label: l.label ?? entry.label,
        debit: amount(l.debitMinor, c),
        credit: amount(l.creditMinor, c),
      };
    }),
  };
}

const join = (base: string, path: string): string =>
  `${base.replace(/\/+$/, "")}/${path.replace(/^\/+/, "")}`;

/** The filter query Pennylane v2 lists take: a JSON array of conditions.
 * spec: API v2 "Filtering" — `filter=[{field, operator, value}]`. */
const byField = (field: string, value: string): string =>
  `filter=${
    encodeURIComponent(JSON.stringify([{ field, operator: "eq", value }]))
  }`;

/** An HTTP answer that is not a success, as a typed failure. */
async function failureOf(res: Response): Promise<Failure> {
  const text = (await res.text()).slice(0, 500);
  if (res.status === 401) return { reason: "reauth_needed", detail: text };
  if (res.status === 429 || res.status >= 500) {
    return { reason: "retry_later", detail: `${res.status} ${text}` };
  }
  let message = text;
  try {
    const body = JSON.parse(text);
    if (body && typeof body === "object") {
      message = String(body.message ?? body.error ?? text);
    }
  } catch {
    // Not JSON: Pennylane's words as they came.
  }
  return { reason: "rejected", detail: `${res.status} ${message}` };
}

type Call = { ok: true; body: Record<string, unknown> } | {
  ok: false;
  failure: Failure;
};

async function call(
  fetchImpl: Fetch,
  cfg: Config,
  path: string,
  init: RequestInit = {},
): Promise<Call> {
  let res: Response;
  try {
    res = await fetchImpl(join(cfg.base_url, path), {
      ...init,
      headers: {
        authorization: `Bearer ${cfg.access_token}`,
        accept: "application/json",
        ...(init.headers ?? {}),
      },
    });
  } catch (error) {
    return {
      ok: false,
      failure: { reason: "unreachable", detail: String(error).slice(0, 500) },
    };
  }
  if (!res.ok) return { ok: false, failure: await failureOf(res) };
  const text = await res.text();
  try {
    const body = text ? JSON.parse(text) : {};
    return { ok: true, body: body && typeof body === "object" ? body : {} };
  } catch {
    return { ok: true, body: {} };
  }
}

const first = (
  body: Record<string, unknown>,
): Record<string, unknown> | null => {
  const items = body.items;
  return Array.isArray(items) && items.length > 0
    ? items[0] as Record<string, unknown>
    : null;
};

/** The Pennylane customer of [doc], read back by its number or created. */
async function customerId(
  fetchImpl: Fetch,
  cfg: Config,
  doc: PennylaneDocument,
): Promise<{ id: number } | { failure: Failure }> {
  // spec: "List customers" — external_reference is a filterable field.
  const found = await call(
    fetchImpl,
    cfg,
    `customers?${byField("external_reference", doc.customer.number)}`,
  );
  if (!found.ok) return { failure: found.failure };
  const existing = first(found.body);
  if (existing) return { id: Number(existing.id) };
  const created = await call(fetchImpl, cfg, "company_customers", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      name: doc.customer.name,
      external_reference: doc.customer.number,
      // spec: "Create a company customer" — reg_no carries the SIREN.
      ...(doc.customer.legalId ? { reg_no: doc.customer.legalId } : {}),
    }),
  });
  if (!created.ok) return { failure: created.failure };
  return { id: Number(created.body.id) };
}

/** The failure [build] refuses with, or null when it builds. */
function refusalOf(build: () => unknown): Failure | null {
  try {
    build();
    return null;
  } catch (error) {
    if (error instanceof PayloadRefusal) return error.failure;
    throw error;
  }
}

async function deliverOne(
  doc: PennylaneDocument,
  fetchImpl: Fetch,
  cfg: Config,
): Promise<Delivery> {
  const failed = (error: Failure): Delivery => ({
    documentId: doc.id,
    status: "failed",
    error,
  });
  const known = await call(
    fetchImpl,
    cfg,
    `customer_invoices?${byField("external_reference", doc.id)}`,
  );
  if (!known.ok) return failed(known.failure);
  const held = first(known.body);
  if (held) {
    return {
      documentId: doc.id,
      status: "exists",
      pennylaneId: String(held.id),
    };
  }
  // A currency or rate the payload cannot state is refused before
  // anything is written to Pennylane: no orphan customer or attachment.
  const refusal = refusalOf(() =>
    customerInvoicePayload(doc, { fileAttachmentId: 0, customerId: 0 })
  );
  if (refusal) return failed(refusal);
  const customer = await customerId(fetchImpl, cfg, doc);
  if ("failure" in customer) return failed(customer.failure);
  const form = new FormData();
  form.append(
    "file",
    new Blob([new Uint8Array(doc.pdf.bytes)], { type: "application/pdf" }),
    doc.pdf.fileName,
  );
  const upload = await call(fetchImpl, cfg, "file_attachments", {
    method: "POST",
    body: form,
  });
  if (!upload.ok) return failed(upload.failure);
  const payload = customerInvoicePayload(doc, {
    fileAttachmentId: Number(upload.body.id),
    customerId: customer.id,
  });
  const imported = await call(fetchImpl, cfg, "customer_invoices/import", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!imported.ok) return failed(imported.failure);
  return {
    documentId: doc.id,
    status: "created",
    pennylaneId: String(imported.body.id),
  };
}

/** Delivers [docs] one by one: read back by external_reference, else the
 * PDF uploaded and the invoice imported as issued. A failure is that
 * document's answer; the others still go. Never throws for an HTTP
 * answer or a refused payload. */
export async function deliver(
  docs: PennylaneDocument[],
  { fetch: fetchImpl, config }: { fetch: Fetch; config: Config },
): Promise<Delivery[]> {
  const missing = requiredFields.filter((f) => !config[f]);
  if (missing.length > 0) {
    return docs.map((d) => ({
      documentId: d.id,
      status: "failed" as const,
      error: {
        reason: "reauth_needed" as const,
        detail: `missing ${missing.join(", ")}`,
      },
    }));
  }
  const out: Delivery[] = [];
  for (const doc of docs) out.push(await deliverOne(doc, fetchImpl, config));
  return out;
}
