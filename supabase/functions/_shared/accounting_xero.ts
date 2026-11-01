// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The adapter of the accounting targets `xero_gb`, `xero_ca`, `xero_us` and
// `xero_eu`: the Xero Accounting API 2.0, one organisation (tenant) per
// connection. What it sends of a period's postings:
//
//   * an invoice as an `ACCREC` invoice, a credit note as an `ACCRECCREDIT`
//     credit note: the legal number as `InvoiceNumber` / `CreditNoteNumber`,
//     the period as `Reference`, line amounts `Exclusive` of tax, one line
//     per revenue line of the posting (net, on the account its revenue role
//     is mapped to, with the `TaxType` its rate group is mapped to and the
//     document's own tax of that group as `TaxAmount`), always `AUTHORISED`:
//     the app's document is issued, and a Xero draft is not a posted sale;
//   * a credit note is then allocated to the invoice it corrects, for what
//     that invoice still owes;
//   * a receipt as a `Payment` against the invoice of its number, on the
//     account its debit role is mapped to (a bank account, or one that
//     takes payments);
//   * every other event (refund, write-off, provider fee, purchases, tax
//     release) as a balanced, `POSTED` manual journal on the mapped accounts.
//
// Tax. The issued document is the source: Xero is never its tax authority.
// The `TaxType`s are the organisation's own (GET /TaxRates), so a mapped
// `TaxType` the organisation does not hold, or one its account's class does
// not admit, refuses the document before anything is sent, with the mapping
// key named. Xero's `TotalTax`, `Total` and `AmountDue` are compared with
// the document's: a difference is a conflict, never a re-issue.
//
// Idempotency and conflicts. Every write carries `Idempotency-Key` (the
// delivery's key; Xero answers a repeated key from its cache for a day).
// After that day a lost answer is resolved by reading back the legal number,
// never by a second create: a sale document of the same number is ours only
// when it is held for the same contact, and anything else holding the number
// is a conflict a person resolves. Nothing is ever updated: Xero's PUT only
// creates. A payment and a journal carry the key in their `Reference` or
// `Narration`, by which a readback knows its own.
//
// One organisation keeps one workspace's books: a contact is found by the
// member number alone, so two workspaces delivering to one organisation
// would share the contact of a number.
//
// The tenant. Every call names the connection's organisation
// (`xero-tenant-id`); the sign-in binds it from the organisations THAT
// sign-in authorised (its `authentication_event_id`), exactly one, and the
// organisation's country must be the target's before anything goes.
//
// Not sent: the invoice PDF as an attachment (the PDF is built in the app;
// no server copy exists yet), a contact's tax number (the postings' parties
// carry none), and batches of 50 (one document per call keeps each lost
// answer one document's). A call refused for Xero's call limits stops the
// run's remaining calls; the next run continues.
//
// Pure: `fetch` is the context's, so the tests play Xero
// (accounting_xero_test.ts). The live exchange is NOT RUN: it needs a Xero
// developer application and a demo organisation per region. Field names
// follow the Accounting API 2.0 reference; what was not verified against a
// live organisation says so in a `// spec:` comment.

import { type AccountingMap, type CreateOutcome, DETAIL_LENGTH, type MapNeed, type RemoteDocument } from "./accounting_delivery.ts";
import {
  accountNeeds,
  type AdapterContext,
  type Posting,
  type PostingAdapter,
  type PostingLine,
  type PostingParty,
  roleKey,
} from "./accounting_postings.ts";
import { exponentOf, toMajor, toMinor } from "./money.ts";

/** spec: developer.xero.com — "Accounting API" base URL. */
const API_BASE = "https://api.xero.com/api.xro/2.0";

/** spec: developer.xero.com — "OAuth 2.0 / Connections": the organisations
 * a token may reach, each with the sign-in (`authEventId`) that added it. */
export const CONNECTIONS_URL = "https://api.xero.com/connections";

/** The function's environment variable that points the adapter at another
 * host (a recorded or proxied Xero), set by the installation's operator. */
const API_BASE_ENV = "ACCOUNTING_XERO_API_BASE";

/** The longest `Idempotency-Key` Xero keeps. spec: "Idempotent requests". */
export const IDEMPOTENCY_KEY_LENGTH = 128;

/** The longest `ContactNumber` Xero keeps. spec: Contacts. */
const CONTACT_NUMBER_LENGTH = 50;

/** What a payment's `Reference` or a journal's `Narration` carries before
 * the delivery's idempotency key. */
const NOTE_PREFIX = "deskilo:";

/** The country of the organisation each target is for, as
 * `Organisation.CountryCode` reads it: the app descriptor's
 * (`accounting_targets_xero.dart`; pinned by accounting_targets_test).
 * `xero_eu` takes an organisation in any member state, as the tax
 * reference's `eu_member` rows say (`is_eu_country`). */
export const ORGANISATION_COUNTRIES: Record<string, string[]> = {
  xero_gb: ["GB"],
  xero_ca: ["CA"],
  xero_us: ["US"],
};

/** The target whose organisation is any EU member state. */
export const EU_TARGET = "xero_eu";

/** The tenant type of an organisation (not a practice). spec: Connections. */
const ORGANISATION = "ORGANISATION";

/** The mapping kind that names a rate group's `TaxType`, keyed by the
 * group's tax role (`vat_output:<group>`). Not `account`: the same role key
 * names the tax ACCOUNT of a manual journal's tax line, and one key must not
 * mean both. As in the QuickBooks adapter. */
const TAX_TYPE_MAP = "item" as const;

/** The roles of the posting contract the adapter reads (book_chart.dart). */
const ROLE = {
  customers: "customers",
  revenue: "revenue",
  vatOutput: "vat_output",
  vatPending: "vat_pending",
} as const;

/** The field of a tax rate that admits it on an account of each class.
 * spec: TaxRates — `CanApplyToAssets`, `CanApplyToEquity`,
 * `CanApplyToExpenses`, `CanApplyToLiabilities`, `CanApplyToRevenue`;
 * Accounts — `Class`. */
const APPLIES_TO: Record<string, string> = {
  ASSET: "CanApplyToAssets",
  EQUITY: "CanApplyToEquity",
  EXPENSE: "CanApplyToExpenses",
  LIABILITY: "CanApplyToLiabilities",
  REVENUE: "CanApplyToRevenue",
};

/** The states of a sale document that are a posted sale. spec: Invoices,
 * CreditNotes — `Status`. */
const POSTED_SALE = new Set(["AUTHORISED", "PAID"]);
/** The states of a sale document that are not posted yet. */
const DRAFT_SALE = new Set(["DRAFT", "SUBMITTED"]);

/** The Xero object a document event becomes. */
type Entity = "Invoice" | "CreditNote" | "Payment" | "ManualJournal";

function entityOf(kind: string): Entity {
  switch (kind) {
    case "invoice":
      return "Invoice";
    case "credit_note":
      return "CreditNote";
    case "receipt":
      return "Payment";
    default:
      return "ManualJournal";
  }
}

/** Each entity's collection on the API and in its answers. */
const COLLECTION: Record<Entity, string> = {
  Invoice: "Invoices",
  CreditNote: "CreditNotes",
  Payment: "Payments",
  ManualJournal: "ManualJournals",
};

/** Each entity's id field. */
const ID_FIELD: Record<Entity, string> = {
  Invoice: "InvoiceID",
  CreditNote: "CreditNoteID",
  Payment: "PaymentID",
  ManualJournal: "ManualJournalID",
};

type Row = Record<string, unknown>;

type Cfg = { base: string; token: string; tenant: string };

type Answer = { ok: true; body: Row } | { ok: false; status?: number; detail: string };

/** Xero's own words of a refusal. spec: the `ValidationException` body
 * (`Message`, `Elements[].ValidationErrors[].Message`) and the problem body
 * of a refused token (`Title`, `Detail`). */
function problemOf(text: string): string {
  try {
    const body = JSON.parse(text) as Row;
    const elements = Array.isArray(body.Elements) ? body.Elements as Row[] : [];
    const validation = elements.flatMap((e) =>
      Array.isArray(e.ValidationErrors) ? (e.ValidationErrors as Row[]).map((v) => String(v.Message ?? "")) : []
    ).filter(Boolean);
    if (validation.length > 0) return validation.join("; ");
    const words = [body.Message, body.Title, body.Detail].filter((w) => typeof w === "string" && w);
    if (words.length > 0) return words.join(": ");
  } catch {
    // Not JSON: Xero's words as they came.
  }
  return text;
}

/** Whether a send that got [status] (none: no answer) may have created. */
const outcomeUnknown = (status?: number): boolean => status === undefined || status >= 500;

const failure = (answer: { status?: number; detail: string }): CreateOutcome => ({
  ok: false,
  unknown: outcomeUnknown(answer.status),
  detail: answer.detail,
});

const refused = (detail: string): CreateOutcome => ({ ok: false, unknown: false, detail });

/** A `where` value, its quotes escaped. spec: "Filtering" (`==` on a
 * quoted string). */
const quoted = (value: string): string => `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;

/** The sale lines of an invoice or credit note: its revenue lines. */
const revenueLines = (p: Posting): PostingLine[] => p.lines.filter((l) => l.role === ROLE.revenue);

/** The amount of a line, whichever side it books. */
const amountOf = (l: PostingLine): number => l.debitCents + l.creditCents;

const isTax = (l: PostingLine): boolean => l.role === ROLE.vatOutput;

/** The tax of the rate group [qualifier]. */
const groupTax = (p: Posting, qualifier: string | null): number =>
  p.lines.filter((l) => isTax(l) && l.qualifier === qualifier).reduce((s, l) => s + amountOf(l), 0);

/** The tax a sales posting carries. */
const taxOf = (p: Posting): number => p.lines.filter(isTax).reduce((s, l) => s + amountOf(l), 0);

/** The tax role key that names a rate group's `TaxType`. */
const taxKeyOf = (l: Pick<PostingLine, "qualifier">): string => roleKey({ role: ROLE.vatOutput, qualifier: l.qualifier });

const major = (minor: number, currency: string): number => Number(toMajor(minor, currency));

/** Minor units of a Xero amount, null when it is missing or not one. */
const minorOf = (value: unknown, currency: string): number | null =>
  typeof value === "number" && Number.isFinite(value) ? toMinor(String(value), currency) : null;

/** The code a mapping names: `remoteCode` first (a `TaxType`, an account
 * `Code`), the remote id otherwise. */
function codeOf(maps: AccountingMap[], kind: AccountingMap["kind"], key: string): string {
  const m = maps.find((x) => x.kind === kind && x.key === key);
  return m ? (m.remoteCode || m.remoteId) : "";
}

/** The name a contact is found and created under: unique in an
 * organisation, so the member or supplier number is part of it. */
const contactName = (party: PostingParty): string => party.number ? `${party.name} (${party.number})` : party.name;

/** What the run learned of the organisation in `prepare`. */
type Organisation = {
  /** `Organisation.BaseCurrency`: the only currency sent, so Xero never
   * puts its own day rate in place of the document's. */
  baseCurrency: string;
  taxRates: Row[];
  accounts: Row[];
};

/** The tenant the sign-in authorised, read from its access token's
 * `authentication_event_id` and the connections that event added; a
 * refusal in words when it is not exactly one organisation. */
export async function signedInTenant(
  fetchImpl: typeof fetch,
  accessToken: string,
): Promise<{ tenant: string } | { refused: string }> {
  const event = authEventOf(accessToken);
  if (!event) return { refused: "the Xero sign-in named no authorisation event" };
  let res: Response;
  try {
    res = await fetchImpl(CONNECTIONS_URL, {
      headers: { authorization: `Bearer ${accessToken}`, accept: "application/json" },
    });
  } catch (error) {
    return { refused: String(error).slice(0, DETAIL_LENGTH) };
  }
  const text = await res.text();
  if (!res.ok) return { refused: `${res.status} ${problemOf(text).slice(0, DETAIL_LENGTH)}` };
  let rows: Row[] = [];
  try {
    const parsed = JSON.parse(text);
    rows = Array.isArray(parsed) ? parsed : [];
  } catch {
    return { refused: "the Xero connections were not JSON" };
  }
  // spec: Connections — that a re-consent to an organisation already
  // connected rewrites its `authEventId` to the new sign-in's event; if it
  // does not, such a sign-in answers "no organisation".
  const added = rows.filter((r) => r.authEventId === event && r.tenantType === ORGANISATION && r.tenantId);
  if (added.length === 1) return { tenant: String(added[0].tenantId) };
  return {
    refused: added.length === 0
      ? "the Xero sign-in authorised no organisation"
      : `the Xero sign-in authorised ${added.length} organisations: sign in again and choose the one this issuer keeps its books in`,
  };
}

/** The `authentication_event_id` claim of a Xero access token (a JWT),
 * '' when it has none. The token came from the token endpoint over TLS; its
 * claim only narrows which organisations that endpoint's sign-in added. */
function authEventOf(token: string): string {
  const payload = token.split(".")[1] ?? "";
  try {
    const json = atob(payload.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(payload.length / 4) * 4, "="));
    const claim = (JSON.parse(json) as Row).authentication_event_id;
    return typeof claim === "string" ? claim : "";
  } catch {
    return "";
  }
}

/** The organisation's account the `account` mapping of [key] names, by
 * its `Code` or its `AccountID`. */
function accountOf(org: Organisation, maps: AccountingMap[], key: string): Row | undefined {
  const m = maps.find((x) => x.kind === "account" && x.key === key);
  if (!m) return undefined;
  return org.accounts.find((a) => (m.remoteCode !== "" && a.Code === m.remoteCode) || (m.remoteId !== "" && a.AccountID === m.remoteId));
}

/** The line's account reference as Xero takes it. */
function accountRef(maps: AccountingMap[], key: string): Row {
  const m = maps.find((x) => x.kind === "account" && x.key === key);
  // spec: LineItems/JournalLines/Payments take `AccountCode` (or
  // `Account.Code`); an account without a code is named by `AccountID`.
  return m?.remoteCode ? { AccountCode: m.remoteCode } : { AccountID: m?.remoteId ?? "" };
}

/** Why [p]'s sale lines cannot go to this organisation as mapped, naming
 * the mapping key; null when every line's account and `TaxType` fit. */
function saleProblem(p: Posting, maps: AccountingMap[], org: Organisation): string | null {
  // Tax due on receipt carries no rate group in the postings, so it cannot
  // be put on a line's TaxType: such a document is not delivered yet.
  if (p.lines.some((l) => l.role === ROLE.vatPending && amountOf(l) > 0)) {
    return "deferred tax (vat_pending): a document taxed on receipt is not delivered to Xero yet";
  }
  for (const l of revenueLines(p)) {
    const accountKey = roleKey(l);
    const account = accountOf(org, maps, accountKey);
    if (!account || account.Status !== "ACTIVE") {
      return `account ${accountKey} → ${codeOf(maps, "account", accountKey)}: not an active account of this Xero organisation`;
    }
    const taxKey = taxKeyOf(l);
    const taxType = codeOf(maps, TAX_TYPE_MAP, taxKey);
    const rate = org.taxRates.find((r) => r.TaxType === taxType);
    if (!rate || rate.Status !== "ACTIVE") {
      return `${TAX_TYPE_MAP} ${taxKey} → ${taxType}: not an active TaxType of this Xero organisation`;
    }
    const cls = String(account.Class ?? "");
    const field = APPLIES_TO[cls];
    if (!field) return `account ${accountKey} → ${account.Code}: Xero names its class ${cls || "nothing"}`;
    if (rate[field] !== true) {
      return `${TAX_TYPE_MAP} ${taxKey} → ${taxType}: Xero does not admit it on account ${account.Code} (class ${cls})`;
    }
  }
  const groups = new Set(revenueLines(p).map((l) => l.qualifier));
  const orphan = p.lines.find((l) => isTax(l) && amountOf(l) > 0 && !groups.has(l.qualifier));
  if (orphan) return `the tax of ${roleKey(orphan)} has no sale line of its rate group`;
  return null;
}

/** The body of an `ACCREC` invoice or `ACCRECCREDIT` credit note for [p]. */
function salePayload(
  p: Posting,
  contactId: string,
  maps: AccountingMap[],
  reference: string,
): Row {
  const credit = entityOf(p.kind) === "CreditNote";
  return {
    Type: credit ? "ACCRECCREDIT" : "ACCREC",
    Contact: { ContactID: contactId },
    // spec: Date and DueDate as YYYY-MM-DD; with no DueDate the
    // organisation's own sales terms apply.
    Date: p.date,
    [credit ? "CreditNoteNumber" : "InvoiceNumber"]: p.documentNumber,
    Reference: reference,
    CurrencyCode: p.currency,
    LineAmountTypes: "Exclusive",
    Status: "AUTHORISED",
    LineItems: revenueLines(p).map((l, i, lines) => ({
      Description: l.qualifier ? `${p.documentNumber} ${l.qualifier}` : p.documentNumber,
      Quantity: 1,
      UnitAmount: major(amountOf(l), p.currency),
      ...accountRef(maps, roleKey(l)),
      TaxType: codeOf(maps, TAX_TYPE_MAP, taxKeyOf(l)),
      // spec: LineItems.TaxAmount overrides the amount Xero computes. A
      // group's tax goes on its first line, once.
      TaxAmount: major(
        lines.findIndex((x) => x.qualifier === l.qualifier) === i ? groupTax(p, l.qualifier) : 0,
        p.currency,
      ),
    })),
  };
}

/** The body of a balanced `POSTED` manual journal for [p]. */
function journalPayload(p: Posting, maps: AccountingMap[], narration: string): Row {
  return {
    Narration: narration,
    Date: p.date,
    LineAmountTypes: "NoTax",
    Status: "POSTED",
    // spec: JournalLines.LineAmount — a debit positive, a credit negative.
    JournalLines: p.lines.map((l) => ({
      LineAmount: major(l.debitCents - l.creditCents, p.currency),
      ...accountRef(maps, roleKey(l)),
      Description: `${p.documentNumber} ${roleKey(l)}`,
    })),
  };
}

/** What a sale document must read in Xero. */
const saleExpected = (p: Posting) => {
  const tax = taxOf(p);
  return { total: revenueLines(p).reduce((s, l) => s + amountOf(l), 0) + tax, tax };
};

/** What the readback of a sale [row] says of [p]. [contactId] is the
 * contact the document is ours under ('' when the contact is unknown). */
function saleRemote(row: Row, p: Posting, contactId: string, fresh: boolean): RemoteDocument {
  const entity = entityOf(p.kind);
  const expected = saleExpected(p);
  const differences: string[] = [];
  const held = (row.Contact as Row | undefined)?.ContactID;
  if (!contactId || held !== contactId) differences.push(`Xero holds number ${p.documentNumber} for another contact`);
  const status = String(row.Status ?? "");
  if (!POSTED_SALE.has(status)) {
    differences.push(DRAFT_SALE.has(status) ? `a ${status} in Xero is not a posted sale` : `Xero holds it as ${status || "no status"}`);
  }
  const total = minorOf(row.Total, p.currency);
  const tax = minorOf(row.TotalTax, p.currency);
  const due = minorOf(entity === "CreditNote" ? row.RemainingCredit : row.AmountDue, p.currency);
  if (total !== expected.total) differences.push(`Xero total ${row.Total ?? "missing"}, the document ${toMajor(expected.total, p.currency)}`);
  if (tax !== expected.tax) differences.push(`Xero tax ${row.TotalTax ?? "missing"}, the document ${toMajor(expected.tax, p.currency)}`);
  // A fresh document owes its whole total; a later one owes no more than it.
  if (due === null || due < 0 || due > expected.total || (fresh && due !== expected.total)) {
    differences.push(`Xero ${entity === "CreditNote" ? "RemainingCredit" : "AmountDue"} ${row.AmountDue ?? row.RemainingCredit ?? "missing"}`);
  }
  return {
    id: String(row[ID_FIELD[entity]] ?? ""),
    number: String(row.InvoiceNumber ?? row.CreditNoteNumber ?? ""),
    version: String(row.UpdatedDateUTC ?? ""),
    state: DRAFT_SALE.has(status) ? "draft" : "posted",
    matches: differences.length === 0,
    difference: differences.length > 0 ? differences.join("; ") : undefined,
  };
}

/** What the readback of a payment or journal [row] says of [p]. */
function entryRemote(row: Row, p: Posting, entity: Entity): RemoteDocument {
  const debits = p.lines.reduce((s, l) => s + l.debitCents, 0);
  const differences: string[] = [];
  const status = String(row.Status ?? "");
  if (entity === "Payment") {
    if (status !== "AUTHORISED") differences.push(`Xero holds the payment as ${status || "no status"}`);
    const amount = minorOf(row.Amount, p.currency);
    if (amount !== debits) differences.push(`Xero amount ${row.Amount ?? "missing"}, the document ${toMajor(debits, p.currency)}`);
  } else {
    if (status !== "POSTED") differences.push(`Xero holds the journal as ${status || "no status"}`);
    const lines = Array.isArray(row.JournalLines) ? row.JournalLines as Row[] : [];
    const held = lines.reduce((s, l) => {
      const v = minorOf(l.LineAmount, p.currency);
      return v !== null && v > 0 ? s + v : s;
    }, 0);
    if (held !== debits) differences.push(`Xero debits ${toMajor(held, p.currency)}, the document ${toMajor(debits, p.currency)}`);
  }
  return {
    id: String(row[ID_FIELD[entity]] ?? ""),
    number: p.documentNumber,
    version: String(row.UpdatedDateUTC ?? ""),
    state: "posted",
    matches: differences.length === 0,
    difference: differences.length > 0 ? differences.join("; ") : undefined,
  };
}

/** The Xero adapter of the delivery kit. */
export function xeroAccounting(ctx: AdapterContext): PostingAdapter {
  const cfg: Cfg = {
    base: (ctx.env(API_BASE_ENV) || API_BASE).replace(/\/+$/, ""),
    token: ctx.secrets.access_token ?? "",
    tenant: ctx.tenant,
  };
  const f = ctx.fetch;
  let org: Organisation | null = null;
  /** Set once Xero refused a call for its limits: the run sends no more. */
  let limited = "";

  async function xero(path: string, init: RequestInit & { idempotencyKey?: string } = {}): Promise<Answer> {
    if (limited) return { ok: false, status: 429, detail: limited };
    const { idempotencyKey, ...rest } = init;
    let res: Response;
    try {
      res = await f(`${cfg.base}/${path}`, {
        ...rest,
        headers: {
          authorization: `Bearer ${cfg.token}`,
          "xero-tenant-id": cfg.tenant,
          accept: "application/json",
          ...(rest.body ? { "content-type": "application/json" } : {}),
          ...(idempotencyKey ? { "Idempotency-Key": idempotencyKey.slice(0, IDEMPOTENCY_KEY_LENGTH) } : {}),
        },
      });
    } catch (error) {
      return { ok: false, detail: String(error).slice(0, DETAIL_LENGTH) };
    }
    const text = await res.text();
    // spec: "Rate limits" — 429 with `Retry-After` (seconds) and
    // `X-Rate-Limit-Problem` (minute, day or appminute); nothing was done.
    if (res.status === 429) {
      limited = `Xero's ${res.headers.get("X-Rate-Limit-Problem") ?? "call"} limit was reached` +
        ` (retry after ${res.headers.get("Retry-After") ?? "?"} s): run the delivery again then`;
      return { ok: false, status: 429, detail: limited };
    }
    if (!res.ok) return { ok: false, status: res.status, detail: `${res.status} ${problemOf(text).slice(0, DETAIL_LENGTH)}` };
    try {
      const body = text ? JSON.parse(text) : {};
      return { ok: true, body: body && typeof body === "object" ? body : {} };
    } catch {
      return { ok: false, status: res.status, detail: "the answer was not JSON" };
    }
  }

  /** The rows of [collection] [query] finds, or Xero's words. */
  async function list(collection: string, query: string): Promise<Row[] | string> {
    const found = await xero(`${collection}?${query}`);
    if (!found.ok) return found.detail;
    const rows = found.body[collection];
    return Array.isArray(rows) ? rows as Row[] : [];
  }

  const where = (collection: string, field: string, value: string) =>
    list(collection, `where=${encodeURIComponent(`${field}==${quoted(value)}`)}`);

  /** The contact of [party], by its number; '' when Xero holds none. */
  async function findContact(party: PostingParty | undefined): Promise<string | { failure: CreateOutcome }> {
    if (!party?.number) return "";
    const found = await where("Contacts", "ContactNumber", party.number.slice(0, CONTACT_NUMBER_LENGTH));
    if (typeof found === "string") return { failure: refused(found) };
    if (found.length > 1) {
      return { failure: refused(`Xero holds ${found.length} contacts numbered ${party.number}`) };
    }
    return found.length === 1 ? String(found[0].ContactID ?? "") : "";
  }

  /** The contact of [party]: found by its number, else created. */
  async function contactOf(party: PostingParty | undefined): Promise<string | { failure: CreateOutcome }> {
    if (!party?.name || !party.number) return { failure: refused("the document names no customer with a number") };
    const found = await findContact(party);
    if (typeof found !== "string" || found) return found;
    const number = party.number.slice(0, CONTACT_NUMBER_LENGTH);
    const created = await xero("Contacts", {
      method: "PUT",
      // The contact's own key: a lost answer finds the same contact again.
      idempotencyKey: `contact:${number}`,
      body: JSON.stringify({ Contacts: [{ Name: contactName(party), ContactNumber: number }] }),
    });
    if (!created.ok) return { failure: failure(created) };
    const id = ((created.body.Contacts as Row[] | undefined)?.[0])?.ContactID;
    return id ? String(id) : { failure: { ok: false, unknown: true, detail: "Xero answered no contact" } };
  }

  /** The sale documents of [entity] holding [number]. */
  function salesNumbered(entity: Entity, number: string): Promise<Row[] | string> {
    return entity === "Invoice"
      // spec: Invoices?InvoiceNumbers= matches sales and bills: the sales.
      ? list("Invoices", `InvoiceNumbers=${encodeURIComponent(number)}`).then((rows) =>
        typeof rows === "string" ? rows : rows.filter((r) => r.Type === "ACCREC")
      )
      : where("CreditNotes", "CreditNoteNumber", number).then((rows) =>
        typeof rows === "string" ? rows : rows.filter((r) => r.Type === "ACCRECCREDIT")
      );
  }

  /** The one sale invoice numbered [number], or why there is none. */
  async function invoiceNumbered(number: string): Promise<Row | string> {
    const found = await salesNumbered("Invoice", number);
    if (typeof found === "string") return found;
    if (found.length === 1) return found[0];
    return found.length === 0
      ? `the invoice ${number} is not in Xero yet: deliver it first`
      : `Xero holds ${found.length} invoices numbered ${number}`;
  }

  /** Allocates [credit] to [invoice] (numbered [credited]) for what it
   * still owes. */
  async function allocate(credit: Row, invoice: Row, credited: string, p: Posting, key: string): Promise<string | null> {
    const owed = minorOf(invoice.AmountDue, p.currency);
    const total = minorOf(credit.Total, p.currency);
    if (owed === null || total === null) return `Xero answered no amount for ${credited}`;
    const amount = Math.min(owed, total);
    // An invoice already settled keeps the credit for a refund.
    if (amount === 0) return null;
    const done = await xero(`CreditNotes/${encodeURIComponent(String(credit.CreditNoteID))}/Allocations`, {
      method: "PUT",
      idempotencyKey: `${key}:allocation`,
      body: JSON.stringify({
        Allocations: [{ Invoice: { InvoiceID: invoice.InvoiceID }, Amount: major(amount, p.currency), Date: p.date }],
      }),
    });
    return done.ok ? null : `its allocation to ${credited} was refused: ${done.detail}`;
  }

  return {
    async prepare() {
      if (!cfg.token) return "the connection holds no token";
      if (!cfg.tenant) return "the sign-in named no Xero organisation";
      const info = await xero("Organisation");
      if (!info.ok) return info.detail;
      const organisation = (info.body.Organisations as Row[] | undefined)?.[0];
      const held = String(organisation?.CountryCode ?? "");
      if (!held) return "the Xero organisation named no country";
      const baseCurrency = String(organisation?.BaseCurrency ?? "");
      if (!baseCurrency) return "the Xero organisation named no base currency";
      const allowed = ctx.targetId === EU_TARGET
        ? (await ctx.isEuCountry?.(held)) === true
        : (ORGANISATION_COUNTRIES[ctx.targetId] ?? []).includes(held);
      if (!allowed) {
        return `this Xero organisation is in ${held}; the connection is for ${
          ctx.targetId === EU_TARGET ? "an EU member state" : (ORGANISATION_COUNTRIES[ctx.targetId] ?? []).join(", ") || "no country"
        }`;
      }
      const rates = await xero("TaxRates");
      if (!rates.ok) return rates.detail;
      const accounts = await xero("Accounts");
      if (!accounts.ok) return accounts.detail;
      org = {
        baseCurrency,
        taxRates: Array.isArray(rates.body.TaxRates) ? rates.body.TaxRates as Row[] : [],
        accounts: Array.isArray(accounts.body.Accounts) ? accounts.body.Accounts as Row[] : [],
      };
      return null;
    },
    signedInTenant: () => signedInTenant(f, cfg.token),
    needs(p): MapNeed[] {
      switch (entityOf(p.kind)) {
        case "Invoice":
        case "CreditNote": {
          const lines = revenueLines(p);
          return [
            ...[...new Set(lines.map(roleKey))].map((key) => ({ kind: "account" as const, key })),
            ...[...new Set(lines.map(taxKeyOf))].map((key) => ({ kind: TAX_TYPE_MAP, key })),
          ];
        }
        case "Payment":
          return p.lines.filter((l) => l.debitCents > 0).map((l) => ({ kind: "account" as const, key: roleKey(l) }));
        case "ManualJournal":
          return accountNeeds(p);
      }
    },
    remote(p, party, maps, credited) {
      const entity = entityOf(p.kind);
      const sale = entity === "Invoice" || entity === "CreditNote";
      return {
        async readback(key) {
          if (sale) {
            const rows = await salesNumbered(entity, p.documentNumber);
            if (typeof rows === "string") return rows;
            if (rows.length === 0) return [];
            const contact = await findContact(party);
            if (typeof contact !== "string") return "detail" in contact.failure ? contact.failure.detail : "the contact could not be read";
            return rows.map((r) => {
              const remote = saleRemote(r, p, contact, false);
              // A credit note whose answer was lost may never have been
              // allocated: a person allocates it, nothing is sent twice.
              // spec: CreditNotes — whether the filtered list answers
              // `Allocations`, or only GET CreditNotes/{id} does.
              const allocated = Array.isArray(r.Allocations) && r.Allocations.length > 0;
              return entity === "CreditNote" && credited && remote.matches && !allocated
                ? { ...remote, matches: false, difference: `not allocated to ${credited} in Xero` }
                : remote;
            });
          }
          const rows = entity === "Payment"
            ? await where("Payments", "Reference", `${NOTE_PREFIX}${key}`)
            : await where("ManualJournals", "Narration", narrationOf(p, key));
          if (typeof rows === "string") return rows;
          return rows.map((r) => entryRemote(r, p, entity));
        },
        async create(key, job) {
          if (exponentOf(p.currency) === null) return refused(`the currency ${p.currency} is not stated`);
          if (!org) return refused("the Xero organisation was not read before the delivery");
          if (p.currency !== org.baseCurrency) {
            return refused(`the document is in ${p.currency}; this Xero organisation keeps its books in ${org.baseCurrency}`);
          }
          if (sale) {
            const problem = saleProblem(p, maps, org);
            if (problem) return refused(problem);
            // The invoice a credit note corrects first: a credit note that
            // cannot be allocated creates nothing.
            const creditedInvoice = entity === "CreditNote" && credited ? await invoiceNumbered(credited) : undefined;
            if (typeof creditedInvoice === "string") return refused(creditedInvoice);
            const held = await salesNumbered(entity, p.documentNumber);
            if (typeof held === "string") return refused(held);
            if (held.length > 0) {
              return {
                ok: false,
                unknown: false,
                conflict: true,
                detail: `Xero already holds ${entity} ${p.documentNumber} (${held.map((r) => r[ID_FIELD[entity]]).join(", ")})`,
              };
            }
            const contact = await contactOf(party);
            if (typeof contact !== "string") return contact.failure;
            const sent = await xero(COLLECTION[entity], {
              method: "PUT",
              idempotencyKey: key,
              body: JSON.stringify({ [COLLECTION[entity]]: [salePayload(p, contact, maps, job.periodFrom.slice(0, 7))] }),
            });
            if (!sent.ok) return failure(sent);
            const row = (sent.body[COLLECTION[entity]] as Row[] | undefined)?.[0];
            if (!row?.[ID_FIELD[entity]]) return { ok: false, unknown: true, detail: `Xero answered no ${entity}` };
            const remote = saleRemote(row, p, contact, true);
            if (creditedInvoice && credited && remote.matches) {
              const unallocated = await allocate(row, creditedInvoice, credited, p, key);
              if (unallocated) return { ok: true, remote: { ...remote, matches: false, difference: unallocated } };
            }
            return { ok: true, remote };
          }
          if (entity === "Payment") {
            const invoice = await invoiceNumbered(p.documentNumber);
            if (typeof invoice === "string") return refused(invoice);
            const deposit = p.lines.find((l) => l.debitCents > 0)!;
            const account = accountOf(org, maps, roleKey(deposit));
            // spec: Payments — a BANK account, or one with payments enabled.
            if (!account || (account.Type !== "BANK" && account.EnablePaymentsToAccount !== true)) {
              return refused(`account ${roleKey(deposit)} → ${codeOf(maps, "account", roleKey(deposit))}: Xero takes no payment on it`);
            }
            const ref = accountRef(maps, roleKey(deposit));
            const sent = await xero("Payments", {
              method: "PUT",
              idempotencyKey: key,
              body: JSON.stringify({
                Payments: [{
                  Invoice: { InvoiceID: invoice.InvoiceID },
                  Account: ref.AccountCode ? { Code: ref.AccountCode } : { AccountID: ref.AccountID },
                  // The day the money moved at the bank, when a statement line
                  // is reconciled with the receipt (#2380); the booking day otherwise.
                  Date: p.valueDate ?? p.date,
                  Amount: major(deposit.debitCents, p.currency),
                  Reference: `${NOTE_PREFIX}${key}`,
                }],
              }),
            });
            if (!sent.ok) return failure(sent);
            const row = (sent.body.Payments as Row[] | undefined)?.[0];
            if (!row?.PaymentID) return { ok: false, unknown: true, detail: "Xero answered no Payment" };
            return { ok: true, remote: entryRemote(row, p, entity) };
          }
          const sent = await xero("ManualJournals", {
            method: "PUT",
            idempotencyKey: key,
            body: JSON.stringify({ ManualJournals: [journalPayload(p, maps, narrationOf(p, key))] }),
          });
          if (!sent.ok) return failure(sent);
          const row = (sent.body.ManualJournals as Row[] | undefined)?.[0];
          if (!row?.ManualJournalID) return { ok: false, unknown: true, detail: "Xero answered no ManualJournal" };
          return { ok: true, remote: entryRemote(row, p, entity) };
        },
      };
    },
  };
}

/** A journal's narration: its event and number, then the delivery's key. */
const narrationOf = (p: Posting, key: string): string => `${p.kind} ${p.documentNumber} ${NOTE_PREFIX}${key}`;
