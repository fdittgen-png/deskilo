// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The adapter of the accounting targets `sage_business_cloud_gb`, `_ie`,
// `_ca`, `_us`, `_fr`, `_de` and `_es`: Sage Business Cloud Accounting
// (Sage Accounting), API v3.1, one business per connection. What it sends of
// a period's postings:
//
//   * an invoice as a `sales_invoice`, a credit note as a
//     `sales_credit_note`: the legal number as `reference` (Sage numbers its
//     own artefacts), one line per revenue line of the posting (net, on the
//     ledger account its revenue role is mapped to, with the tax rate its
//     rate group is mapped to and the document's own tax of that group as
//     `tax_amount`);
//   * a credit note names the invoice it corrects (`original_invoice_id`),
//     looked up BEFORE anything is created, and is allocated to it for what
//     that invoice still owes;
//   * a receipt as a `contact_payment` (CUSTOMER_RECEIPT) allocated to the
//     invoice of its number, a refund as one (CUSTOMER_REFUND) allocated to
//     the credit note of its number, both on the bank account of the ledger
//     account the bank role is mapped to; the document allocated to is
//     looked up first, and a missing one creates nothing, not even a
//     contact;
//   * every other event (write-off, purchases, a member's receipt and its
//     reimbursement, tax release) as a balanced `journal` on the mapped
//     ledger accounts.
//
// Tax. The issued document is the source: Sage is never its tax authority.
// The tax rates and ledger accounts are the business's own (read in
// `prepare`), so a mapped one the business does not hold refuses the
// document before anything is sent, with the mapping key named. Sage's
// `total_amount` and `tax_amount` are compared with the document's: a
// difference is a conflict, never a re-issue. Output tax waiting for its tax
// point (`vat_pending`) names no rate group and is refused by name; a
// document in another currency than the business's base currency is refused
// too, so Sage never puts its own day rate in place of the document's.
//
// Idempotency and conflicts. Sage Accounting takes no idempotency key, so a
// lost answer is resolved by the kit's readback, never by a second create:
// a sale artefact holding the legal number is ours only when it is held for
// the same contact, and anything else holding the number is a conflict a
// person resolves. A payment and a journal carry the delivery's key in their
// `reference` / `description`, by which a readback knows its own. Nothing is
// ever updated.
//
// The business. Every call names the connection's business (`X-Business`);
// the sign-in binds it from the businesses the token reaches, exactly one,
// and the business's country must be the target's before anything goes.
//
// Pure: `fetch` is the context's, so the tests play Sage
// (accounting_sage_test.ts). The live exchange is NOT RUN: it needs a Sage
// developer application and a trial business per region. Field names follow
// the Sage Accounting API v3.1 reference; what was not verified against a
// live business says so in a `// spec:` comment.

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

/** spec: developer.sage.com/accounting — the API v3.1 base URL, one host
 * for every region. */
const API_BASE = "https://api.accounting.sage.com/v3.1";

/** The function's environment variable that points the adapter at another
 * host (a recorded or proxied Sage), set by the installation's operator. */
const API_BASE_ENV = "ACCOUNTING_SAGE_API_BASE";

/** The most items a list answers per page. spec: "Pagination"
 * (`items_per_page`, at most 200). */
const ITEMS_PER_PAGE = 200;

/** The most pages a list of tax rates, ledger accounts or bank accounts is
 * followed through: 10,000 rows, far above any business's chart. */
const MAX_PAGES = 50;

/** The longest contact `reference` Sage keeps. spec: Contacts — a number
 * longer than it is refused, never cut: two members would share a cut one. */
export const CONTACT_REFERENCE_LENGTH = 8;

/** What a payment's `reference` or a journal's `description` carries
 * before the delivery's idempotency key. */
const NOTE_PREFIX = "deskilo:";

/** The country of the business each target is for, as the business's
 * `country.id` reads it: the app descriptor's
 * (`accounting_targets_sage.dart`; pinned by accounting_targets_test). */
export const BUSINESS_COUNTRIES: Record<string, string> = {
  sage_business_cloud_gb: "GB",
  sage_business_cloud_ie: "IE",
  sage_business_cloud_ca: "CA",
  sage_business_cloud_us: "US",
  sage_business_cloud_fr: "FR",
  sage_business_cloud_de: "DE",
  sage_business_cloud_es: "ES",
};

/** The mapping kind that names a rate group's tax rate, keyed by the
 * group's tax role (`vat_output:<group>`). Not `account`: the same role key
 * names the tax LEDGER ACCOUNT of a journal's tax line, and one key must not
 * mean both. As in the QuickBooks and Xero adapters. */
const TAX_RATE_MAP = "item" as const;

/** The roles of the posting contract the adapter reads (book_chart.dart). */
const ROLE = {
  customers: "customers",
  suppliers: "suppliers",
  bank: "bank",
  revenue: "revenue",
  vatOutput: "vat_output",
  vatPending: "vat_pending",
} as const;

/** The states of a sale artefact that are not a posted sale.
 * spec: SalesInvoice/SalesCreditNote — `status.id`. */
const NOT_POSTED = new Set(["DRAFT", "VOID"]);

/** The Sage object a document event becomes. */
type Entity = "SalesInvoice" | "SalesCreditNote" | "ContactPayment" | "Journal";

function entityOf(kind: string): Entity {
  switch (kind) {
    case "invoice":
      return "SalesInvoice";
    case "credit_note":
      return "SalesCreditNote";
    case "receipt":
    case "refund":
      return "ContactPayment";
    default:
      return "Journal";
  }
}

/** Each entity's collection and its body's key. spec: the v3.1 resources. */
const RESOURCE: Record<Entity, { path: string; key: string }> = {
  SalesInvoice: { path: "sales_invoices", key: "sales_invoice" },
  SalesCreditNote: { path: "sales_credit_notes", key: "sales_credit_note" },
  ContactPayment: { path: "contact_payments", key: "contact_payment" },
  Journal: { path: "journals", key: "journal" },
};

type Row = Record<string, unknown>;

type Answer = { ok: true; body: Row } | { ok: false; status?: number; detail: string };

/** Sage's own words of a refusal. spec: "Errors" — an array of
 * `{$severity, $dataCode, $message, $source}`. */
function problemOf(text: string): string {
  try {
    const body = JSON.parse(text);
    const errors = Array.isArray(body) ? body as Row[] : [];
    const words = errors.map((e) => [e.$source, e.$message].filter((w) => typeof w === "string" && w).join(": "))
      .filter(Boolean);
    if (words.length > 0) return words.join("; ");
  } catch {
    // Not JSON: Sage's words as they came.
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

/** The tax role key that names a rate group's tax rate. */
const taxKeyOf = (l: Pick<PostingLine, "qualifier">): string => roleKey({ role: ROLE.vatOutput, qualifier: l.qualifier });

const major = (minor: number, currency: string): number => Number(toMajor(minor, currency));

/** Minor units of a Sage amount (a number or a decimal string), null when it
 * is missing or not one. */
function minorOf(value: unknown, currency: string): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return toMinor(String(value), currency);
  if (typeof value === "string" && /^-?\d+(\.\d+)?$/.test(value)) return toMinor(value, currency);
  return null;
}

const idOf = (value: unknown): string => String((value as Row | undefined)?.id ?? "");

/** What the run learned of the business in `prepare`. */
type Business = {
  /** `financial_settings.base_currency`: the only currency sent. */
  baseCurrency: string;
  taxRates: Row[];
  ledgerAccounts: Row[];
  bankAccounts: Row[];
};

/** The ledger account the `account` mapping of [key] names, by its id or
 * its `nominal_code`. */
function ledgerOf(business: Business, maps: AccountingMap[], key: string): Row | undefined {
  const m = maps.find((x) => x.kind === "account" && x.key === key);
  if (!m) return undefined;
  return business.ledgerAccounts.find((a) =>
    (m.remoteId !== "" && a.id === m.remoteId) || (m.remoteCode !== "" && String(a.nominal_code ?? "") === m.remoteCode)
  );
}

/** The tax rate the `item` mapping of [key] names, by its id. */
function taxRateOf(business: Business, maps: AccountingMap[], key: string): Row | undefined {
  const m = maps.find((x) => x.kind === TAX_RATE_MAP && x.key === key);
  const id = m ? (m.remoteId || m.remoteCode) : "";
  return id ? business.taxRates.find((r) => r.id === id) : undefined;
}

/** Why [p] cannot go to this business as mapped, naming the mapping key;
 * null when every ledger account and tax rate is the business's. */
function problemOfPosting(p: Posting, maps: AccountingMap[], business: Business): string | null {
  // Tax due on its tax point carries no rate group in the postings: such a
  // document is not delivered to Sage.
  if (p.lines.some((l) => l.role === ROLE.vatPending && amountOf(l) > 0)) {
    return "deferred tax (vat_pending): a document taxed on its tax point is not delivered to Sage";
  }
  const entity = entityOf(p.kind);
  const accountKeys = entity === "SalesInvoice" || entity === "SalesCreditNote"
    ? revenueLines(p).map(roleKey)
    : entity === "ContactPayment"
    ? [ROLE.bank]
    : p.lines.map(roleKey);
  for (const key of new Set(accountKeys)) {
    if (!ledgerOf(business, maps, key)) return `account ${key}: not a ledger account of this Sage business`;
  }
  if (entity === "SalesInvoice" || entity === "SalesCreditNote") {
    for (const key of new Set(revenueLines(p).map(taxKeyOf))) {
      if (!taxRateOf(business, maps, key)) return `${TAX_RATE_MAP} ${key}: not a tax rate of this Sage business`;
    }
    const groups = new Set(revenueLines(p).map((l) => l.qualifier));
    const orphan = p.lines.find((l) => isTax(l) && amountOf(l) > 0 && !groups.has(l.qualifier));
    if (orphan) return `the tax of ${roleKey(orphan)} has no sale line of its rate group`;
  }
  if (entity === "ContactPayment") {
    const ledger = ledgerOf(business, maps, ROLE.bank)!;
    if (!business.bankAccounts.some((b) => idOf(b.ledger_account) === ledger.id)) {
      return `account ${ROLE.bank}: ledger account ${ledger.nominal_code ?? ledger.id} is no bank account of this Sage business`;
    }
  }
  return null;
}

/** The sale artefact's lines for [p]. */
function saleLines(p: Posting, maps: AccountingMap[], business: Business): Row[] {
  return revenueLines(p).map((l, i, lines) => ({
    description: l.qualifier ? `${p.documentNumber} ${l.qualifier}` : p.documentNumber,
    ledger_account_id: String(ledgerOf(business, maps, roleKey(l))!.id),
    quantity: 1,
    unit_price: major(amountOf(l), p.currency),
    tax_rate_id: String(taxRateOf(business, maps, taxKeyOf(l))!.id),
    // spec: the line's `tax_amount` is taken as given. A group's tax goes on
    // its first line, once.
    tax_amount: major(
      lines.findIndex((x) => x.qualifier === l.qualifier) === i ? groupTax(p, l.qualifier) : 0,
      p.currency,
    ),
  }));
}

/** What a sale artefact must read in Sage. */
const saleExpected = (p: Posting) => {
  const tax = taxOf(p);
  return { total: revenueLines(p).reduce((s, l) => s + amountOf(l), 0) + tax, tax };
};

/** What the readback of a sale [row] says of [p]. [contactId] is the
 * contact the artefact is ours under ('' when the contact is unknown). */
function saleRemote(row: Row, p: Posting, contactId: string): RemoteDocument {
  const expected = saleExpected(p);
  const differences: string[] = [];
  if (!contactId || idOf(row.contact) !== contactId) {
    differences.push(`Sage holds reference ${p.documentNumber} for another contact`);
  }
  const status = idOf(row.status);
  if (NOT_POSTED.has(status)) differences.push(`Sage holds it as ${status}`);
  const total = minorOf(row.total_amount, p.currency);
  const tax = minorOf(row.tax_amount, p.currency);
  if (total !== expected.total) {
    differences.push(`Sage total ${row.total_amount ?? "missing"}, the document ${toMajor(expected.total, p.currency)}`);
  }
  if (tax !== expected.tax) {
    differences.push(`Sage tax ${row.tax_amount ?? "missing"}, the document ${toMajor(expected.tax, p.currency)}`);
  }
  return {
    id: String(row.id ?? ""),
    number: String(row.reference ?? ""),
    version: String(row.updated_at ?? ""),
    state: status === "DRAFT" ? "draft" : "posted",
    matches: differences.length === 0,
    difference: differences.length > 0 ? differences.join("; ") : undefined,
  };
}

/** What the readback of a payment or journal [row] says of [p]. */
function entryRemote(row: Row, p: Posting, entity: Entity): RemoteDocument {
  const debits = p.lines.reduce((s, l) => s + l.debitCents, 0);
  const differences: string[] = [];
  if (entity === "ContactPayment") {
    const amount = minorOf(row.total_amount, p.currency);
    if (amount !== debits) {
      differences.push(`Sage amount ${row.total_amount ?? "missing"}, the document ${toMajor(debits, p.currency)}`);
    }
  } else {
    const lines = Array.isArray(row.journal_lines) ? row.journal_lines as Row[] : [];
    const held = lines.reduce((s, l) => s + (minorOf(l.debit, p.currency) ?? 0), 0);
    if (held !== debits) differences.push(`Sage debits ${toMajor(held, p.currency)}, the document ${toMajor(debits, p.currency)}`);
  }
  return {
    id: String(row.id ?? ""),
    number: p.documentNumber,
    version: String(row.updated_at ?? ""),
    state: "posted",
    matches: differences.length === 0,
    difference: differences.length > 0 ? differences.join("; ") : undefined,
  };
}

/** A journal's description: its event and number, then the delivery's key. */
const descriptionOf = (p: Posting, key: string): string => `${p.kind} ${p.documentNumber} ${NOTE_PREFIX}${key}`;

/** The Sage Accounting adapter of the delivery kit. */
export function sageAccounting(ctx: AdapterContext): PostingAdapter {
  const base = (ctx.env(API_BASE_ENV) || API_BASE).replace(/\/+$/, "");
  const token = ctx.secrets.access_token ?? "";
  const f = ctx.fetch;
  let business: Business | null = null;
  /** Set once Sage refused a call for its limits: the run sends no more. */
  let limited = "";

  async function sage(path: string, init: RequestInit & { tenant?: string } = {}): Promise<Answer> {
    if (limited) return { ok: false, status: 429, detail: limited };
    const { tenant, ...rest } = init;
    const businessId = tenant ?? ctx.tenant;
    let res: Response;
    try {
      res = await f(`${base}/${path}`, {
        ...rest,
        headers: {
          authorization: `Bearer ${token}`,
          accept: "application/json",
          ...(businessId ? { "X-Business": businessId } : {}),
          ...(rest.body ? { "content-type": "application/json" } : {}),
        },
      });
    } catch (error) {
      return { ok: false, detail: String(error).slice(0, DETAIL_LENGTH) };
    }
    const text = await res.text();
    // spec: "Rate limiting" — 429 when a business's per-minute or per-day
    // allowance is spent; nothing was done.
    if (res.status === 429) {
      limited = `Sage's call limit was reached (retry after ${res.headers.get("Retry-After") ?? "?"} s): run the delivery again then`;
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

  /** Every item of [path] [query], page after page; Sage's words when a
   * page is refused or the list is longer than [MAX_PAGES] pages. */
  async function all(path: string, query = ""): Promise<Row[] | string> {
    const rows: Row[] = [];
    for (let page = 1; page <= MAX_PAGES; page++) {
      const found = await sage(`${path}?attributes=all&items_per_page=${ITEMS_PER_PAGE}&page=${page}${query}`);
      if (!found.ok) return found.detail;
      const items = Array.isArray(found.body.$items) ? found.body.$items as Row[] : [];
      rows.push(...items);
      if (!found.body.$next) return rows;
    }
    return `Sage lists more than ${MAX_PAGES * ITEMS_PER_PAGE} ${path}`;
  }

  /** The sale artefacts of [entity] whose `reference` is [number]. */
  async function salesReferenced(entity: Entity, number: string): Promise<Row[] | string> {
    // spec: `search` matches the reference among other fields: the exact
    // reference is kept.
    const found = await all(RESOURCE[entity].path, `&search=${encodeURIComponent(number)}`);
    return typeof found === "string" ? found : found.filter((r) => r.reference === number);
  }

  /** The one sale artefact of [entity] referenced [number], or why there is
   * none. */
  async function oneReferenced(entity: Entity, number: string): Promise<Row | string> {
    const found = await salesReferenced(entity, number);
    if (typeof found === "string") return found;
    if (found.length === 1) return found[0];
    const what = entity === "SalesInvoice" ? "invoice" : "credit note";
    return found.length === 0
      ? `the ${what} ${number} is not in Sage yet: deliver it first`
      : `Sage holds ${found.length} ${what}s referenced ${number}`;
  }

  /** The contact of [party], by its reference; '' when Sage holds none. */
  async function findContact(party: PostingParty | undefined): Promise<string | { failure: CreateOutcome }> {
    if (!party?.number) return "";
    const found = await all("contacts", `&search=${encodeURIComponent(party.number)}`);
    if (typeof found === "string") return { failure: refused(found) };
    const held = found.filter((c) => c.reference === party.number);
    if (held.length > 1) return { failure: refused(`Sage holds ${held.length} contacts referenced ${party.number}`) };
    return held.length === 1 ? String(held[0].id ?? "") : "";
  }

  /** The contact of [party]: found by its reference, else created. */
  async function contactOf(party: PostingParty | undefined): Promise<string | { failure: CreateOutcome }> {
    if (!party?.name || !party.number) return { failure: refused("the document names no customer or supplier with a number") };
    if (party.number.length > CONTACT_REFERENCE_LENGTH) {
      return {
        failure: refused(`the number ${party.number} is longer than the ${CONTACT_REFERENCE_LENGTH} characters of a Sage contact reference`),
      };
    }
    const found = await findContact(party);
    if (typeof found !== "string" || found) return found;
    const created = await sage("contacts", {
      method: "POST",
      body: JSON.stringify({
        contact: {
          name: party.name,
          reference: party.number,
          contact_type_ids: [party.kind === "supplier" ? "VENDOR" : "CUSTOMER"],
        },
      }),
    });
    if (!created.ok) return { failure: failure(created) };
    return created.body.id ? String(created.body.id) : { failure: { ok: false, unknown: true, detail: "Sage answered no contact" } };
  }

  /** Allocates [credit] to [invoice] (referenced [credited]) for what it
   * still owes. spec: ContactAllocations — CUSTOMER_ALLOCATION, the credit
   * note's amount negative. */
  async function allocate(credit: Row, invoice: Row, contactId: string, credited: string, p: Posting): Promise<string | null> {
    const owed = minorOf(invoice.outstanding_amount, p.currency);
    const total = minorOf(credit.total_amount, p.currency);
    if (owed === null || total === null) return `Sage answered no amount for ${credited}`;
    const amount = Math.min(owed, total);
    // An invoice already settled keeps the credit for a refund.
    if (amount === 0) return null;
    const done = await sage("contact_allocations", {
      method: "POST",
      body: JSON.stringify({
        contact_allocation: {
          transaction_type_id: "CUSTOMER_ALLOCATION",
          contact_id: contactId,
          date: p.date,
          allocated_artefacts: [
            { artefact_id: invoice.id, amount: major(amount, p.currency) },
            { artefact_id: credit.id, amount: -major(amount, p.currency) },
          ],
        },
      }),
    });
    return done.ok ? null : `its allocation to ${credited} was refused: ${done.detail}`;
  }

  async function createSale(p: Posting, entity: Entity, party: PostingParty | undefined, maps: AccountingMap[], credited?: string) {
    // The invoice a credit note corrects first: a credit note that cannot be
    // linked creates nothing, not even its contact.
    const creditedInvoice = entity === "SalesCreditNote" && credited
      ? await oneReferenced("SalesInvoice", credited)
      : undefined;
    if (typeof creditedInvoice === "string") return refused(creditedInvoice);
    const held = await salesReferenced(entity, p.documentNumber);
    if (typeof held === "string") return refused(held);
    if (held.length > 0) {
      return {
        ok: false as const,
        unknown: false,
        conflict: true,
        detail: `Sage already holds ${RESOURCE[entity].key} ${p.documentNumber} (${held.map((r) => r.id).join(", ")})`,
      };
    }
    const contact = await contactOf(party);
    if (typeof contact !== "string") return contact.failure;
    const lines = saleLines(p, maps, business!);
    const sent = await sage(RESOURCE[entity].path, {
      method: "POST",
      body: JSON.stringify({
        [RESOURCE[entity].key]: {
          contact_id: contact,
          date: p.date,
          reference: p.documentNumber,
          currency_id: p.currency,
          ...(creditedInvoice ? { original_invoice_id: creditedInvoice.id } : {}),
          [entity === "SalesInvoice" ? "invoice_lines" : "credit_note_lines"]: lines,
        },
      }),
    });
    if (!sent.ok) return failure(sent);
    if (!sent.body.id) return { ok: false as const, unknown: true, detail: `Sage answered no ${RESOURCE[entity].key}` };
    const remote = saleRemote(sent.body, p, contact);
    if (creditedInvoice && credited && remote.matches) {
      const unallocated = await allocate(sent.body, creditedInvoice, contact, credited, p);
      if (unallocated) return { ok: true as const, remote: { ...remote, matches: false, difference: unallocated } };
    }
    return { ok: true as const, remote };
  }

  async function createPayment(p: Posting, key: string, party: PostingParty | undefined, maps: AccountingMap[]) {
    const refund = p.kind === "refund";
    // The document allocated to first: a payment that cannot be allocated
    // creates nothing.
    const artefact = await oneReferenced(refund ? "SalesCreditNote" : "SalesInvoice", p.documentNumber);
    if (typeof artefact === "string") return refused(artefact);
    const contact = idOf(artefact.contact);
    if (!contact) return refused(`Sage answered no contact for ${p.documentNumber}`);
    const known = await findContact(party);
    if (typeof known !== "string") return known.failure;
    if (known !== contact) return refused(`Sage holds ${p.documentNumber} for another contact than ${party?.number ?? "this one"}`);
    const ledger = ledgerOf(business!, maps, ROLE.bank)!;
    const bank = business!.bankAccounts.find((b) => idOf(b.ledger_account) === ledger.id)!;
    const amount = p.lines.filter((l) => l.role === ROLE.bank).reduce((s, l) => s + amountOf(l), 0);
    const sent = await sage("contact_payments", {
      method: "POST",
      body: JSON.stringify({
        contact_payment: {
          transaction_type_id: refund ? "CUSTOMER_REFUND" : "CUSTOMER_RECEIPT",
          contact_id: contact,
          bank_account_id: bank.id,
          date: p.date,
          total_amount: major(amount, p.currency),
          reference: `${NOTE_PREFIX}${key}`,
          allocated_artefacts: [{ artefact_id: artefact.id, amount: major(amount, p.currency) }],
        },
      }),
    });
    if (!sent.ok) return failure(sent);
    if (!sent.body.id) return { ok: false as const, unknown: true, detail: "Sage answered no contact_payment" };
    return { ok: true as const, remote: entryRemote(sent.body, p, "ContactPayment") };
  }

  async function createJournal(p: Posting, key: string, maps: AccountingMap[]) {
    const sent = await sage("journals", {
      method: "POST",
      body: JSON.stringify({
        journal: {
          date: p.date,
          reference: p.documentNumber,
          description: descriptionOf(p, key),
          journal_lines: p.lines.map((l) => ({
            ledger_account_id: String(ledgerOf(business!, maps, roleKey(l))!.id),
            debit: major(l.debitCents, p.currency),
            credit: major(l.creditCents, p.currency),
            details: `${p.documentNumber} ${roleKey(l)}`,
          })),
        },
      }),
    });
    if (!sent.ok) return failure(sent);
    if (!sent.body.id) return { ok: false as const, unknown: true, detail: "Sage answered no journal" };
    return { ok: true as const, remote: entryRemote(sent.body, p, "Journal") };
  }

  return {
    async prepare() {
      if (!token) return "the connection holds no token";
      if (!ctx.tenant) return "the sign-in named no Sage business";
      const expected = BUSINESS_COUNTRIES[ctx.targetId];
      if (!expected) return `no Sage business region for ${ctx.targetId}`;
      // spec: Businesses — `country.id`; a British business may read a
      // subdivision (GB-ENG), so the first two letters are compared.
      const info = await sage(`businesses/${encodeURIComponent(ctx.tenant)}`);
      if (!info.ok) return info.detail;
      const held = idOf(info.body.country).slice(0, 2).toUpperCase();
      if (held !== expected) {
        return `this Sage business is in ${held || "no named country"}; the connection is for ${expected}`;
      }
      const settings = await sage("financial_settings");
      if (!settings.ok) return settings.detail;
      const baseCurrency = idOf(settings.body.base_currency);
      if (!baseCurrency) return "the Sage business named no base currency";
      const taxRates = await all("tax_rates");
      if (typeof taxRates === "string") return taxRates;
      const ledgerAccounts = await all("ledger_accounts");
      if (typeof ledgerAccounts === "string") return ledgerAccounts;
      const bankAccounts = await all("bank_accounts");
      if (typeof bankAccounts === "string") return bankAccounts;
      business = { baseCurrency, taxRates, ledgerAccounts, bankAccounts };
      return null;
    },
    async signedInTenant() {
      // spec: Businesses — the businesses the signed-in user reaches, read
      // without an X-Business header.
      const found = await sage("businesses", { tenant: "" });
      if (!found.ok) return { refused: found.detail };
      const items = Array.isArray(found.body.$items) ? found.body.$items as Row[] : [];
      const ids = items.map((b) => String(b.id ?? "")).filter(Boolean);
      if (ids.length === 1) return { tenant: ids[0] };
      return {
        refused: ids.length === 0
          ? "the Sage sign-in reaches no business"
          : `the Sage sign-in reaches ${ids.length} businesses: sign in as a user of the one business this issuer keeps its books in`,
      };
    },
    needs(p): MapNeed[] {
      switch (entityOf(p.kind)) {
        case "SalesInvoice":
        case "SalesCreditNote": {
          const lines = revenueLines(p);
          return [
            ...[...new Set(lines.map(roleKey))].map((key) => ({ kind: "account" as const, key })),
            ...[...new Set(lines.map(taxKeyOf))].map((key) => ({ kind: TAX_RATE_MAP, key })),
          ];
        }
        case "ContactPayment":
          return [{ kind: "account" as const, key: ROLE.bank }];
        case "Journal":
          return accountNeeds(p);
      }
    },
    remote(p, party, maps, credited) {
      const entity = entityOf(p.kind);
      const sale = entity === "SalesInvoice" || entity === "SalesCreditNote";
      return {
        async readback(key) {
          if (sale) {
            const rows = await salesReferenced(entity, p.documentNumber);
            if (typeof rows === "string") return rows;
            if (rows.length === 0) return [];
            const contact = await findContact(party);
            if (typeof contact !== "string") return "detail" in contact.failure ? contact.failure.detail : "the contact could not be read";
            return rows.map((r) => saleRemote(r, p, contact));
          }
          const window = `&from_date=${p.date}&to_date=${p.date}`;
          const rows = await all(RESOURCE[entity].path, window);
          if (typeof rows === "string") return rows;
          const ours = entity === "ContactPayment"
            ? rows.filter((r) => r.reference === `${NOTE_PREFIX}${key}`)
            : rows.filter((r) => r.description === descriptionOf(p, key));
          return ours.map((r) => entryRemote(r, p, entity));
        },
        async create(key) {
          if (exponentOf(p.currency) === null) return refused(`the currency ${p.currency} is not stated`);
          if (!business) return refused("the Sage business was not read before the delivery");
          if (p.currency !== business.baseCurrency) {
            return refused(`the document is in ${p.currency}; this Sage business keeps its books in ${business.baseCurrency}`);
          }
          const problem = problemOfPosting(p, maps, business);
          if (problem) return refused(problem);
          if (sale) return createSale(p, entity, party, maps, credited);
          if (entity === "ContactPayment") return createPayment(p, key, party, maps);
          return createJournal(p, key, maps);
        },
      };
    },
  };
}
