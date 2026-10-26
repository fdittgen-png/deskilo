// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The adapter of the accounting targets `quickbooks_online_us`, `_ca` and
// `_gb`: QuickBooks Online, Accounting API v3, one realm (company) per
// connection. What it sends of a period's postings:
//
//   * an invoice as an `Invoice`, a credit note as a `CreditMemo`: the
//     legal number as `DocNumber`, one `SalesItemLine` per revenue line of
//     the posting (net, on the realm `Item` its revenue role is mapped to),
//     the customer found by name and member number or created;
//   * a receipt as a `Payment` linked to the invoice of its number, on the
//     account its debit role is mapped to;
//   * every other event (refund, write-off, purchases, tax release) as a
//     balanced `JournalEntry` on the mapped accounts.
//
// Tax. The issued document is the source and never changes, so QuickBooks
// is never the tax authority of it: the document's own tax is sent and the
// total QuickBooks books is compared with it. A difference is a conflict,
// never a silent re-issue.
//   * US realm: each line carries the pseudo code TAX (its rate group
//     carries tax) or NON, and the invoice's tax is the override
//     `TxnTaxDetail {TxnTaxCodeRef, TotalTax}`, honoured from minor version
//     70 on; `TxnTaxCodeRef` is the realm tax code the posting's tax role
//     is mapped to (`account vat_output:<group>`).
//   * CA and GB realms: tax codes are realm objects (`HST ON`, `GST/QST QC`,
//     `20.0% S`, `0.0% Z`), so each line carries the code its rate group is
//     mapped to (`account vat_output:<group>`, a zero-rated group too) and
//     `TotalTax` is the document's.
//
// Idempotency and concurrency. Every create names `requestid` (the
// delivery's idempotency key, cut to its 50 characters) and carries the key
// in `PrivateNote`, by which a readback knows its own document. Nothing is
// ever updated: a document that is held with another `SyncToken` than the
// first was edited in QuickBooks and is a conflict, and the app's copy is
// never pushed over it. A document of the same number that DesKilo did not
// deliver (another issuer, a hand-made one) is a conflict, never a reason
// to create a second one.
//
// The company. Before a run (and after a sign-in) the realm's country must
// be the target's and its sales forms must keep custom transaction
// numbers: otherwise QuickBooks renumbers and the legal number is lost.
//
// Pure: `fetch` is the context's, so the tests play QuickBooks
// (accounting_quickbooks_test.ts). The live exchange is NOT RUN: it needs an
// Intuit developer application and a sandbox company per country. Field
// names follow the Accounting API v3 reference; what was not verified
// against a live realm says so in a `// spec:` comment.

import type { AccountingMap, CreateOutcome, MapNeed, RemoteDocument } from "./accounting_delivery.ts";
import {
  accountNeeds,
  type AdapterContext,
  mapped,
  type Posting,
  type PostingAdapter,
  type PostingLine,
  type PostingParty,
  roleKey,
} from "./accounting_postings.ts";
import { exponentOf, toMajor, toMinor } from "./money.ts";

/** spec: developer.intuit.com — "Accounting API" base URL of production
 * companies; a sandbox company is reached at
 * https://sandbox-quickbooks.api.intuit.com, set in [API_BASE_ENV]. */
export const API_BASE = "https://quickbooks.api.intuit.com";

/** The function's environment variable that points the adapter at another
 * host (an Intuit sandbox), set by the installation's operator. */
export const API_BASE_ENV = "ACCOUNTING_QUICKBOOKS_API_BASE";

/** The minor version every call names: `TxnTaxDetail.TxnTaxCodeRef` is
 * honoured on a US realm from it on. spec: "Manage sales tax for US
 * locales" (minorversion 70). */
export const MINOR_VERSION = "70";

/** The longest `requestid` QuickBooks keeps. spec: "Idempotency". */
const REQUEST_ID_LENGTH = 50;

/** The `SyncToken` of a document nobody edited since it was created. */
const FIRST_SYNC_TOKEN = "0";

/** What `PrivateNote` carries before the delivery's idempotency key. */
const NOTE_PREFIX = "deskilo:";

/** The country of the realm each target is for (the app's descriptor
 * `accounting_target.dart`; pinned to it by accounting_targets_test).
 * spec: `CompanyInfo.Country` reads the ISO code ("US", "CA", "GB"). */
export const REALM_COUNTRIES: Record<string, string> = {
  quickbooks_online_us: "US",
  quickbooks_online_ca: "CA",
  quickbooks_online_gb: "GB",
};

/** The US realm's pseudo tax codes of a line. spec: "US sales tax". */
const US_TAXABLE = "TAX";
const US_NOT_TAXABLE = "NON";

/** The roles of the posting contract the adapter reads (book_chart.dart). */
const ROLE = {
  customers: "customers",
  suppliers: "suppliers",
  revenue: "revenue",
  vatOutput: "vat_output",
  vatPending: "vat_pending",
} as const;

/** The QuickBooks object a document event becomes. */
export type Entity = "Invoice" | "CreditMemo" | "Payment" | "JournalEntry";

export function entityOf(kind: string): Entity {
  switch (kind) {
    case "invoice":
      return "Invoice";
    case "credit_note":
      return "CreditMemo";
    case "receipt":
      return "Payment";
    default:
      return "JournalEntry";
  }
}

export const CUSTOM_NUMBERS_OFF =
  "custom transaction numbers is off in this QuickBooks company (Account and settings › Sales › " +
  "Custom transaction numbers): QuickBooks would renumber the legal invoice numbers";

type Cfg = { base: string; token: string; realm: string };

type Answer = { ok: true; body: Record<string, unknown> } | { ok: false; status?: number; detail: string };

/** QuickBooks' own words of a refusal. spec: `Fault.Error[].Message/Detail`. */
function faultOf(text: string): string {
  try {
    const errors = JSON.parse(text)?.Fault?.Error;
    if (Array.isArray(errors) && errors.length > 0) {
      return errors.map((e: Record<string, unknown>) => [e.Message, e.Detail].filter(Boolean).join(": ")).join("; ");
    }
  } catch {
    // Not JSON: QuickBooks' words as they came.
  }
  return text;
}

async function qbo(fetchImpl: typeof fetch, cfg: Cfg, path: string, init: RequestInit = {}): Promise<Answer> {
  const sep = path.includes("?") ? "&" : "?";
  let res: Response;
  try {
    res = await fetchImpl(
      `${cfg.base.replace(/\/+$/, "")}/v3/company/${encodeURIComponent(cfg.realm)}/${path}${sep}minorversion=${MINOR_VERSION}`,
      {
        ...init,
        headers: {
          authorization: `Bearer ${cfg.token}`,
          accept: "application/json",
          ...(init.body ? { "content-type": "application/json" } : {}),
          ...(init.headers ?? {}),
        },
      },
    );
  } catch (error) {
    return { ok: false, detail: String(error).slice(0, 500) };
  }
  const text = await res.text();
  if (!res.ok) return { ok: false, status: res.status, detail: `${res.status} ${faultOf(text).slice(0, 500)}` };
  try {
    const body = text ? JSON.parse(text) : {};
    return { ok: true, body: body && typeof body === "object" ? body : {} };
  } catch {
    return { ok: false, status: res.status, detail: "the answer was not JSON" };
  }
}

/** A query string value, its quotes escaped. spec: "Query operations". */
const quoted = (value: string): string => `'${value.replace(/\\/g, "\\\\").replace(/'/g, "\\'")}'`;

async function query(
  fetchImpl: typeof fetch,
  cfg: Cfg,
  entity: string,
  where: string,
): Promise<Record<string, unknown>[] | string> {
  const found = await qbo(fetchImpl, cfg, `query?query=${encodeURIComponent(`select * from ${entity} where ${where}`)}`);
  if (!found.ok) return found.detail;
  const rows = (found.body.QueryResponse as Record<string, unknown> | undefined)?.[entity];
  return Array.isArray(rows) ? rows as Record<string, unknown>[] : [];
}

/** Whether a send that got [status] (none: no answer) may have created. */
const outcomeUnknown = (status?: number): boolean => status === undefined || status >= 500;

const failure = (answer: { status?: number; detail: string }): CreateOutcome => ({
  ok: false,
  unknown: outcomeUnknown(answer.status),
  detail: answer.detail,
});

const refused = (detail: string): CreateOutcome => ({ ok: false, unknown: false, detail });

/** The sale lines of an invoice or credit note: its revenue lines. */
const revenueLines = (p: Posting): PostingLine[] => p.lines.filter((l) => l.role === ROLE.revenue);

/** The amount of a line, whichever side it books. */
const amountOf = (l: PostingLine): number => l.debitCents + l.creditCents;

/** The tax a sales posting carries, due now or on its tax point. */
const taxOf = (p: Posting): number =>
  p.lines.filter((l) => l.role === ROLE.vatOutput || l.role === ROLE.vatPending).reduce((s, l) => s + amountOf(l), 0);

/** The tax role key that names a rate group's tax code. */
const taxKeyOf = (l: Pick<PostingLine, "qualifier">): string => roleKey({ role: ROLE.vatOutput, qualifier: l.qualifier });

/** The rate groups of [p] that carry tax. */
const taxedGroups = (p: Posting): Set<string | null> =>
  new Set(p.lines.filter((l) => l.role === ROLE.vatOutput && amountOf(l) > 0).map((l) => l.qualifier));

const major = (minor: number, currency: string): number => Number(toMajor(minor, currency));

/** The name a party is found and created under: unique in a realm, so the
 * member or supplier number is part of it. */
const displayName = (party: PostingParty): string =>
  party.number ? `${party.name} (${party.number})` : party.name;

/** The realm id of [party]: found by its display name, else created. */
async function partyRef(
  fetchImpl: typeof fetch,
  cfg: Cfg,
  party: PostingParty | undefined,
): Promise<{ id: string; type: "Customer" | "Vendor" } | { failure: CreateOutcome }> {
  if (!party || !party.name) return { failure: refused("the document names no customer or supplier") };
  const type = party.kind === "supplier" ? "Vendor" : "Customer";
  const name = displayName(party);
  const found = await query(fetchImpl, cfg, type, `DisplayName = ${quoted(name)}`);
  if (typeof found === "string") return { failure: { ok: false, unknown: false, detail: found } };
  if (found.length > 0) return { id: String(found[0].Id), type };
  const created = await qbo(
    fetchImpl,
    cfg,
    `${type.toLowerCase()}?requestid=${encodeURIComponent(`${type}:${party.number || name}`.slice(0, REQUEST_ID_LENGTH))}`,
    // spec: Customer/Vendor — DisplayName unique in the realm; Notes free.
    { method: "POST", body: JSON.stringify({ DisplayName: name, Notes: party.number }) },
  );
  if (!created.ok) return { failure: failure(created) };
  return { id: String((created.body[type] as Record<string, unknown>)?.Id ?? ""), type };
}

/** The realm's country and its numbering, checked before anything goes:
 * a refusal in words, or null. */
export async function checkRealm(fetchImpl: typeof fetch, cfg: Cfg, country: string): Promise<string | null> {
  if (!cfg.token) return "the connection holds no token";
  if (!cfg.realm) return "the sign-in named no QuickBooks company";
  const info = await qbo(fetchImpl, cfg, `companyinfo/${encodeURIComponent(cfg.realm)}`);
  if (!info.ok) return info.detail;
  const held = String((info.body.CompanyInfo as Record<string, unknown> | undefined)?.Country ?? "");
  if (held !== country) {
    return `this QuickBooks company is in ${held || "no named country"}; the connection is for ${country}`;
  }
  const prefs = await qbo(fetchImpl, cfg, "preferences");
  if (!prefs.ok) return prefs.detail;
  // spec: Preferences.SalesFormsPrefs.CustomTxnNumbers.
  const sales = (prefs.body.Preferences as Record<string, unknown> | undefined)?.SalesFormsPrefs as
    | Record<string, unknown>
    | undefined;
  return sales?.CustomTxnNumbers === true ? null : CUSTOM_NUMBERS_OFF;
}

/** What the readback of [row] says of [p], [ours] when it carries [key]. */
function remoteOf(row: Record<string, unknown>, p: Posting, key: string, expected?: { total: number; tax?: number }): RemoteDocument {
  const ours = row.PrivateNote === `${NOTE_PREFIX}${key}`;
  const sync = String(row.SyncToken ?? "");
  const differences: string[] = [];
  if (!ours) differences.push(`QuickBooks holds number ${p.documentNumber} from elsewhere`);
  if (sync !== FIRST_SYNC_TOKEN) differences.push(`edited in QuickBooks (SyncToken ${sync})`);
  if (expected) {
    const total = toMinor(String(row.TotalAmt ?? ""), p.currency);
    if (total !== expected.total) differences.push(`QuickBooks total ${row.TotalAmt}, the document ${toMajor(expected.total, p.currency)}`);
    if (expected.tax !== undefined) {
      const detail = row.TxnTaxDetail as Record<string, unknown> | undefined;
      const tax = toMinor(String(detail?.TotalTax ?? 0), p.currency);
      if (tax !== expected.tax) {
        differences.push(`QuickBooks tax ${detail?.TotalTax ?? 0}, the document ${toMajor(expected.tax, p.currency)}`);
      }
    }
  }
  return {
    id: String(row.Id ?? ""),
    number: String(row.DocNumber ?? row.PaymentRefNum ?? ""),
    version: sync,
    state: "posted",
    matches: differences.length === 0,
    difference: differences.length > 0 ? differences.join("; ") : undefined,
  };
}

/** What a sales document's total and tax must read in QuickBooks. */
const salesExpected = (p: Posting) => ({ total: revenueLines(p).reduce((s, l) => s + amountOf(l), 0) + taxOf(p), tax: taxOf(p) });

/** The body of an `Invoice` or `CreditMemo` for [p]; a string when the
 * document cannot be stated in this realm. */
export function salesPayload(
  p: Posting,
  key: string,
  customerId: string,
  maps: AccountingMap[],
  country: string,
): Record<string, unknown> | string {
  const lines = revenueLines(p);
  if (lines.length === 0) return "the document has no sale line";
  const tax = taxOf(p);
  const groups = taxedGroups(p);
  const us = country === "US";
  let txnTaxCode = "";
  if (us && tax > 0) {
    if (groups.size !== 1) return `a US invoice carries one sales-tax code; this one has ${groups.size} taxed rate groups`;
    txnTaxCode = mapped(maps, "account", taxKeyOf({ qualifier: [...groups][0] }));
  }
  return {
    DocNumber: p.documentNumber,
    TxnDate: p.date,
    CustomerRef: { value: customerId },
    // spec: CurrencyRef — the realm's home currency is accepted without
    // multicurrency; another one needs it on.
    CurrencyRef: { value: p.currency },
    PrivateNote: `${NOTE_PREFIX}${key}`,
    // spec: GlobalTaxCalculation — the line amounts are net of tax (CA, GB).
    ...(us ? {} : { GlobalTaxCalculation: "TaxExcluded" }),
    Line: lines.map((l) => ({
      Amount: major(amountOf(l), p.currency),
      DetailType: "SalesItemLineDetail",
      SalesItemLineDetail: {
        ItemRef: { value: mapped(maps, "item", roleKey(l)) },
        TaxCodeRef: {
          value: us ? (groups.has(l.qualifier) ? US_TAXABLE : US_NOT_TAXABLE) : mapped(maps, "account", taxKeyOf(l)),
        },
      },
    })),
    TxnTaxDetail: {
      ...(txnTaxCode ? { TxnTaxCodeRef: { value: txnTaxCode } } : {}),
      TotalTax: major(tax, p.currency),
    },
  };
}

/** The body of a balanced `JournalEntry` for [p]. */
export function journalPayload(
  p: Posting,
  key: string,
  maps: AccountingMap[],
  party?: { id: string; type: "Customer" | "Vendor" },
): Record<string, unknown> {
  return {
    DocNumber: p.documentNumber,
    TxnDate: p.date,
    CurrencyRef: { value: p.currency },
    PrivateNote: `${NOTE_PREFIX}${key}`,
    Line: p.lines.map((l) => ({
      Amount: major(amountOf(l), p.currency),
      DetailType: "JournalEntryLineDetail",
      JournalEntryLineDetail: {
        PostingType: l.debitCents > 0 ? "Debit" : "Credit",
        AccountRef: { value: mapped(maps, "account", roleKey(l)) },
        // spec: an Accounts Receivable/Payable line names its customer or
        // vendor as Entity.
        ...(party && (l.role === ROLE.customers || l.role === ROLE.suppliers)
          ? { Entity: { Type: party.type, EntityRef: { value: party.id } } }
          : {}),
      },
    })),
  };
}

/** The QuickBooks Online adapter of the delivery kit. */
export function quickbooksOnline(ctx: AdapterContext): PostingAdapter {
  const country = REALM_COUNTRIES[ctx.targetId] ?? "";
  const cfg: Cfg = {
    base: ctx.env(API_BASE_ENV) || API_BASE,
    token: ctx.secrets.access_token ?? "",
    realm: ctx.tenant,
  };
  const f = ctx.fetch;
  return {
    prepare: () => country ? checkRealm(f, cfg, country) : Promise.resolve(`no QuickBooks realm for ${ctx.targetId}`),
    needs(p): MapNeed[] {
      switch (entityOf(p.kind)) {
        case "Invoice":
        case "CreditMemo": {
          const lines = revenueLines(p);
          const taxKeys = country === "US"
            ? [...taxedGroups(p)].map((qualifier) => taxKeyOf({ qualifier }))
            : lines.map(taxKeyOf);
          return [
            ...new Set(lines.map((l) => `item ${roleKey(l)}`)),
            ...new Set(taxKeys.map((k) => `account ${k}`)),
          ].map((n) => ({ kind: n.slice(0, n.indexOf(" ")) as MapNeed["kind"], key: n.slice(n.indexOf(" ") + 1) }));
        }
        case "Payment":
          return p.lines.filter((l) => l.debitCents > 0).map((l) => ({ kind: "account" as const, key: roleKey(l) }));
        case "JournalEntry":
          return accountNeeds(p);
      }
    },
    remote(p, party, maps) {
      const entity = entityOf(p.kind);
      const byNumber = entity === "Payment" ? "PaymentRefNum" : "DocNumber";
      const expected = entity === "Invoice" || entity === "CreditMemo"
        ? salesExpected(p)
        : entity === "Payment"
        ? { total: p.lines.filter((l) => l.debitCents > 0).reduce((s, l) => s + l.debitCents, 0) }
        : undefined;
      return {
        async readback(key) {
          const rows = await query(f, cfg, entity, `${byNumber} = ${quoted(p.documentNumber)}`);
          if (typeof rows === "string") return rows;
          // The legal number of a sale is the realm's: anything holding it
          // is ours or a conflict. A payment or an entry of the same number
          // that is not ours is another delivery's.
          const relevant = entity === "Invoice" || entity === "CreditMemo"
            ? rows
            : rows.filter((r) => r.PrivateNote === `${NOTE_PREFIX}${key}`);
          return relevant.map((r) => remoteOf(r, p, key, expected));
        },
        async create(key) {
          if (exponentOf(p.currency) === null) return refused(`the currency ${p.currency} is not stated`);
          const requestId = encodeURIComponent(key.slice(0, REQUEST_ID_LENGTH));
          let body: Record<string, unknown>;
          if (entity === "Invoice" || entity === "CreditMemo") {
            const held = await query(f, cfg, entity, `DocNumber = ${quoted(p.documentNumber)}`);
            if (typeof held === "string") return refused(held);
            if (held.length > 0) {
              return {
                ok: false,
                unknown: false,
                conflict: true,
                detail: `QuickBooks already holds ${entity} ${p.documentNumber} (${held.map((r) => r.Id).join(", ")})`,
              };
            }
            const customer = await partyRef(f, cfg, party);
            if ("failure" in customer) return customer.failure;
            const sale = salesPayload(p, key, customer.id, maps, country);
            if (typeof sale === "string") return refused(sale);
            body = sale;
          } else if (entity === "Payment") {
            const customer = await partyRef(f, cfg, party);
            if ("failure" in customer) return customer.failure;
            const invoices = await query(f, cfg, "Invoice", `DocNumber = ${quoted(p.documentNumber)}`);
            if (typeof invoices === "string") return refused(invoices);
            if (invoices.length !== 1) {
              return refused(
                invoices.length === 0
                  ? `the invoice ${p.documentNumber} is not in QuickBooks yet: deliver it first`
                  : `QuickBooks holds ${invoices.length} invoices numbered ${p.documentNumber}`,
              );
            }
            const deposit = p.lines.find((l) => l.debitCents > 0)!;
            body = {
              CustomerRef: { value: customer.id },
              TxnDate: p.date,
              PaymentRefNum: p.documentNumber,
              CurrencyRef: { value: p.currency },
              PrivateNote: `${NOTE_PREFIX}${key}`,
              TotalAmt: major(expected!.total, p.currency),
              DepositToAccountRef: { value: mapped(maps, "account", roleKey(deposit)) },
              Line: [{
                Amount: major(expected!.total, p.currency),
                LinkedTxn: [{ TxnId: String(invoices[0].Id), TxnType: "Invoice" }],
              }],
            };
          } else {
            const needsParty = p.lines.some((l) => l.role === ROLE.customers || l.role === ROLE.suppliers);
            const ref = needsParty ? await partyRef(f, cfg, party) : undefined;
            if (ref && "failure" in ref) return ref.failure;
            body = journalPayload(p, key, maps, ref);
          }
          const sent = await qbo(f, cfg, `${entity.toLowerCase()}?requestid=${requestId}`, {
            method: "POST",
            body: JSON.stringify(body),
          });
          if (!sent.ok) return failure(sent);
          const row = sent.body[entity] as Record<string, unknown> | undefined;
          if (!row?.Id) return { ok: false, unknown: true, detail: `QuickBooks answered no ${entity}` };
          return { ok: true, remote: remoteOf(row, p, key, expected) };
        },
      };
    },
  };
}

