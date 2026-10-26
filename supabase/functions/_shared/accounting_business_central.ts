// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2374 — the adapter of the accounting targets `business_central_de`, `_fr`,
// `_ch`, `_gb`, `_us` and `_ca`: Microsoft Dynamics 365 Business Central,
// API v2.0, one company of one environment per connection. What it sends of
// a period's postings:
//
//   * an invoice as a `salesInvoice`, a credit note as a `salesCreditMemo`:
//     the legal number as `externalDocumentNumber` (Business Central numbers
//     the document from its own series), one `Account` line per revenue line
//     of the posting (net, on the G/L account its revenue role is mapped to,
//     with the `taxCode` its rate group is mapped to: the VAT product posting
//     group, or the tax group in the US and Canada), created in one deep
//     insert, read back, then POSTED as its own step (`Microsoft.NAV.post`).
//     `postAndSend` is never called: sending a document to the customer is
//     the app's, not the books';
//   * a credit memo names the posted invoice it corrects (`invoiceId`),
//     looked up BEFORE anything is created;
//   * a receipt as a `customerPayment` applied to the posted invoice of its
//     number (`appliesToInvoiceId`), in the customer payment journal whose
//     code is the posting's journal, then that journal is posted;
//   * every other event (refund, write-off, provider fee, purchases) as
//     balanced `journalLines` in the general journal whose code is the
//     posting's journal, written in one transactional `$batch`, then that
//     journal is posted. A customer's or supplier's line is a `Customer` /
//     `Vendor` line of the party's number, which must exist.
//
// Draft and posting. A create (201) is a draft, never a posted document:
// the kit records the draft's id and ETag `sent`, then posts it
// (accounting_delivery.ts, step 5). The permission set the application
// holds in Business Central is the explicit allowance: a post it refuses
// leaves the delivery `sent` with its draft, never acknowledged, and the
// next run posts the same draft. A post with no answer is reconciled by
// reading the same document back by its legal number, never by creating
// again; a draft whose ETag changed since it was delivered is a conflict and
// is never posted (`If-Match` on the post as well). A journal is posted as a
// whole, so a journal holding a line this delivery did not write is refused
// before anything is added to it, and again before it is posted.
//
// Tax. The issued document is the source: Business Central recomputes the
// tax from its posting groups, and its read-back totals
// (`totalAmountExcludingTax`, `totalTaxAmount`, `totalAmountIncludingTax`)
// must equal the document's to the cent, otherwise the delivery is a
// conflict (a rounding difference in the company's setup is the
// accountant's to fix, not the app's to paper over). Output tax waiting for
// its tax point (`vat_pending`) names no rate group and is refused by name;
// a document in another currency than the company's is refused too.
//
// Correlation. `externalDocumentNumber` is not unique in Business Central:
// a document holding the legal number is ours only when it is held for the
// customer of the posting's number; anything else holding it is a conflict
// a person resolves. A payment and a journal carry a document number made
// of the delivery's idempotency key, by which a readback knows its own, in
// the journal before posting and in the G/L entries after.
//
// The company. A connection names `{tenant}/{environment}/{companyId}`: the
// company by its id, never by its name, and an environment (production or a
// sandbox) is its own connection. Its country must be the target's
// localisation before anything goes. The credential is the client id and
// secret of the Microsoft Entra application the company's administrator
// registered and added to Business Central's Microsoft Entra Applications
// (OAuth 2.0 client credentials, service to service): a token is asked for
// each run from that tenant, and nothing else is kept. A US or Canadian
// customer is never created: its tax area is the localisation's to set.
//
// Not sent: the invoice PDF as an attachment (no server copy exists yet)
// and dimensions (the site is the connection's issuer). A call refused for
// Business Central's limits stops the run's remaining calls; the next run
// continues.
//
// Pure: `fetch` is the context's, so the tests play Business Central
// (accounting_business_central_test.ts). The live exchange is NOT RUN: it
// needs an Entra application registration and a Business Central sandbox
// per localisation. Field names follow the API v2.0 reference; what was not
// verified against a live company says so in a `// spec:` comment.

import { type AccountingMap, type CreateOutcome, DETAIL_LENGTH, type MapNeed, type RemoteDocument } from "./accounting_delivery.ts";
import {
  type AdapterContext,
  type Posting,
  type PostingAdapter,
  type PostingLine,
  type PostingParty,
  roleKey,
} from "./accounting_postings.ts";
import { exponentOf, toMajor, toMinor } from "./money.ts";

/** spec: learn.microsoft.com — "Business Central API v2.0" endpoint. */
const API_BASE = "https://api.businesscentral.dynamics.com/v2.0";

/** spec: "Using service to service authentication": the tenant's token
 * endpoint and the one scope of the Business Central API. */
const LOGIN_BASE = "https://login.microsoftonline.com";
const API_SCOPE = "https://api.businesscentral.dynamics.com/.default";

/** The function's environment variables that point the adapter at another
 * host (a recorded or proxied Business Central, another Entra cloud), set by
 * the installation's operator. */
const API_BASE_ENV = "ACCOUNTING_BUSINESS_CENTRAL_API_BASE";
const LOGIN_BASE_ENV = "ACCOUNTING_BUSINESS_CENTRAL_LOGIN_BASE";

/** The company a connection names: `{tenant}/{environment}/{companyId}` —
 * the Entra tenant (its id or a verified domain), the environment's name and
 * the company's id. The app composes it (business_central_connection.dart;
 * the pattern is pinned by accounting_targets_business_central_test). */
const COMPANY_ADDRESS = /^([A-Za-z0-9][A-Za-z0-9.-]{0,99})\/([A-Za-z0-9][A-Za-z0-9_-]{0,29})\/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$/;

/** What separates the application's client id from its secret in the
 * credential the connection keeps: a client id is a GUID, never this. */
const CREDENTIAL_SEPARATOR = ":";

/** The longest `externalDocumentNumber` (Code[35]) and customer or vendor
 * `number` (Code[20]) Business Central keeps: a longer one is refused,
 * never cut — two documents would share a cut number. spec: salesInvoice,
 * customer. */
export const EXTERNAL_NUMBER_LENGTH = 35;
export const PARTY_NUMBER_LENGTH = 20;

/** A journal line's `documentNumber` (Code[20]): this prefix and the start
 * of the delivery's idempotency key, in capitals. */
const ENTRY_NUMBER_PREFIX = "DK";
const DOCUMENT_NUMBER_LENGTH = 20;

/** The longest line `description` (Text[100]). */
const DESCRIPTION_LENGTH = 100;

/** The most a list is followed through `@odata.nextLink`: far above any
 * company's chart. spec: "Server-driven paging". */
const MAX_PAGES = 50;

/** Each target's localisation, as the company's
 * `companyInformation.countryRegionCode` reads it: the app descriptor's
 * (`accounting_targets_business_central.dart`; pinned by
 * accounting_targets_business_central_test). */
const COMPANY_COUNTRIES: Record<string, string> = {
  business_central_de: "DE",
  business_central_fr: "FR",
  business_central_ch: "CH",
  business_central_gb: "GB",
  business_central_us: "US",
  business_central_ca: "CA",
};

/** The localisations whose tax is a sales tax computed from the customer's
 * tax area: a customer is never created there. */
const SALES_TAX_COUNTRIES = new Set(["US", "CA"]);

/** The code of the Business Central journal each posting journal goes to:
 * the app's journal codes (posting.dart `PostingJournal`; pinned by
 * accounting_targets_business_central_test). */
const JOURNAL_CODES: Record<string, string> = {
  sales: "VE",
  bank: "BQ",
  purchases: "HA",
  other: "OD",
};

/** The mapping kind that names a rate group's `taxCode`, keyed by the
 * group's tax role (`vat_output:<group>`). Not `account`: the same role key
 * names the tax G/L account of a journal's tax line, and one key must not
 * mean both. As in the other adapters. */
const TAX_CODE_MAP = "item" as const;

/** The roles of the posting contract the adapter reads (book_chart.dart). */
const ROLE = {
  customers: "customers",
  suppliers: "suppliers",
  bank: "bank",
  revenue: "revenue",
  vatOutput: "vat_output",
  vatPending: "vat_pending",
} as const;

/** The states of a sale document. spec: salesInvoice, salesCreditMemo —
 * `status`. */
const DRAFT_SALE = new Set(["Draft", "In Review"]);
const POSTED_SALE = new Set(["Open", "Paid"]);

/** The Business Central object a document event becomes. */
type Entity = "salesInvoices" | "salesCreditMemos" | "customerPayments" | "journalLines";

function entityOf(kind: string): Entity {
  switch (kind) {
    case "invoice":
      return "salesInvoices";
    case "credit_note":
      return "salesCreditMemos";
    case "receipt":
      return "customerPayments";
    default:
      return "journalLines";
  }
}

/** Each sale entity's lines in a deep insert. */
const LINES: Record<"salesInvoices" | "salesCreditMemos", string> = {
  salesInvoices: "salesInvoiceLines",
  salesCreditMemos: "salesCreditMemoLines",
};

/** Each sale entity's document date. */
const DATE_FIELD: Record<"salesInvoices" | "salesCreditMemos", string> = {
  salesInvoices: "invoiceDate",
  salesCreditMemos: "creditMemoDate",
};

/** The line account type of a party role. spec: journalLine — `accountType`. */
const PARTY_ACCOUNT: Record<string, { type: string; collection: string }> = {
  [ROLE.customers]: { type: "Customer", collection: "customers" },
  [ROLE.suppliers]: { type: "Vendor", collection: "vendors" },
};

type Row = Record<string, unknown>;

type Answer = { ok: true; status: number; body: Row } | { ok: false; status?: number; detail: string };

/** Business Central's own words of a refusal. spec: the OData error body
 * `{error: {code, message}}`. */
function problemOf(text: string): string {
  try {
    const error = (JSON.parse(text) as Row).error as Row | undefined;
    const words = [error?.code, error?.message].filter((w) => typeof w === "string" && w);
    if (words.length > 0) return words.join(": ");
  } catch {
    // Not JSON: the words as they came.
  }
  return text;
}

/** Whether a send that got [status] (none: no answer) may have done it. */
const outcomeUnknown = (status?: number): boolean => status === undefined || status >= 500;

/** Whether [status] refuses a write for a changed ETag. spec: "Handling
 * concurrency" — 412 Precondition Failed, or 409 `Request_EntityChanged`. */
const versionRefused = (status?: number): boolean => status === 409 || status === 412;

const failure = (answer: { status?: number; detail: string }): CreateOutcome =>
  versionRefused(answer.status)
    ? { ok: false, unknown: false, conflict: true, detail: `Business Central's document changed: ${answer.detail}` }
    : { ok: false, unknown: outcomeUnknown(answer.status), detail: answer.detail };

const refused = (detail: string): CreateOutcome => ({ ok: false, unknown: false, detail });

const lost = (detail: string): CreateOutcome => ({ ok: false, unknown: true, detail });

/** An OData string literal, its quotes doubled. */
const literal = (value: string): string => `'${value.replace(/'/g, "''")}'`;

const eq = (field: string, value: string): string => `$filter=${encodeURIComponent(`${field} eq ${literal(value)}`)}`;

/** The sale lines of an invoice or credit note: its revenue lines. */
const revenueLines = (p: Posting): PostingLine[] => p.lines.filter((l) => l.role === ROLE.revenue);

/** The amount of a line, whichever side it books. */
const amountOf = (l: PostingLine): number => l.debitCents + l.creditCents;

const isTax = (l: PostingLine): boolean => l.role === ROLE.vatOutput;

/** The tax role key that names a rate group's `taxCode`. */
const taxKeyOf = (l: Pick<PostingLine, "qualifier">): string => roleKey({ role: ROLE.vatOutput, qualifier: l.qualifier });

const major = (minor: number, currency: string): number => Number(toMajor(minor, currency));

/** Minor units of a Business Central amount, null when it is missing. */
const minorOf = (value: unknown, currency: string): number | null =>
  typeof value === "number" && Number.isFinite(value) ? toMinor(String(value), currency) : null;

const etagOf = (row: Row): string => String(row["@odata.etag"] ?? "");

const debitsOf = (p: Posting): number => p.lines.reduce((s, l) => s + l.debitCents, 0);

/** What a sale document must read in Business Central. */
function saleExpected(p: Posting) {
  const tax = p.lines.filter(isTax).reduce((s, l) => s + amountOf(l), 0);
  const net = revenueLines(p).reduce((s, l) => s + amountOf(l), 0);
  return { net, tax, gross: net + tax };
}

/** A journal line's or payment's document number for the delivery [key]. */
const entryNumberOf = (key: string): string =>
  `${ENTRY_NUMBER_PREFIX}${key.toUpperCase()}`.slice(0, DOCUMENT_NUMBER_LENGTH);

/** The client id and secret of the credential the connection keeps. */
function credentialOf(held: string): { clientId: string; secret: string } | null {
  const at = held.indexOf(CREDENTIAL_SEPARATOR);
  if (at <= 0 || at === held.length - 1) return null;
  return { clientId: held.slice(0, at), secret: held.slice(at + 1) };
}

/** What the run learned of the company in `prepare`. */
type Company = {
  country: string;
  /** `companyInformation.currencyCode`: the only currency sent. */
  baseCurrency: string;
  accounts: Row[];
  bankAccounts: Row[];
  taxGroups: Row[];
  journals: Row[];
  paymentJournals: Row[];
};

/** The row of [rows] the mapping of [kind] [key] names, by its `number` or
 * `code` ([field]) or its id. */
function mappedRow(rows: Row[], maps: AccountingMap[], kind: AccountingMap["kind"], key: string, field: string): Row | undefined {
  const m = maps.find((x) => x.kind === kind && x.key === key);
  if (!m) return undefined;
  return rows.find((r) => (m.remoteCode !== "" && r[field] === m.remoteCode) || (m.remoteId !== "" && r.id === m.remoteId));
}

/** The G/L account of the `account` mapping of [key], when it takes
 * postings. spec: account — `blocked`, `accountType` `Posting`. */
function postingAccount(company: Company, maps: AccountingMap[], key: string): Row | undefined {
  const a = mappedRow(company.accounts, maps, "account", key, "number");
  return a && a.blocked !== true && (a.accountType === undefined || a.accountType === "Posting") ? a : undefined;
}

/** The lines of a journal entry that are not a party's: each needs its
 * account mapped. */
const ledgerLines = (p: Posting): PostingLine[] => p.lines.filter((l) => !PARTY_ACCOUNT[l.role]);

/** Why [p] cannot go to this company as mapped, naming the mapping key;
 * null when every account and tax code is the company's. */
function problemOfPosting(p: Posting, maps: AccountingMap[], company: Company): string | null {
  if (p.lines.some((l) => l.role === ROLE.vatPending && amountOf(l) > 0)) {
    return "deferred tax (vat_pending): a document taxed on its tax point is not delivered to Business Central yet";
  }
  if (p.documentNumber.length > EXTERNAL_NUMBER_LENGTH) {
    return `the number ${p.documentNumber} is longer than the ${EXTERNAL_NUMBER_LENGTH} characters of an external document number`;
  }
  const entity = entityOf(p.kind);
  if (entity === "salesInvoices" || entity === "salesCreditMemos") {
    for (const key of new Set(revenueLines(p).map(roleKey))) {
      if (!postingAccount(company, maps, key)) return `account ${key}: not a G/L account of this company that takes postings`;
    }
    for (const key of new Set(revenueLines(p).map(taxKeyOf))) {
      if (!mappedRow(company.taxGroups, maps, TAX_CODE_MAP, key, "code")) {
        return `${TAX_CODE_MAP} ${key}: not a tax group or VAT product posting group of this company`;
      }
    }
    const groups = new Set(revenueLines(p).map((l) => l.qualifier));
    const orphan = p.lines.find((l) => isTax(l) && amountOf(l) > 0 && !groups.has(l.qualifier));
    if (orphan) return `the tax of ${roleKey(orphan)} has no sale line of its rate group`;
    return null;
  }
  const code = JOURNAL_CODES[p.journal] ?? "";
  const journals = entity === "customerPayments" ? company.paymentJournals : company.journals;
  if (!journals.some((j) => j.code === code)) {
    return `Business Central holds no ${entity === "customerPayments" ? "customer payment" : "general"} journal ${code || p.journal}`;
  }
  if (entity === "journalLines") {
    for (const l of ledgerLines(p)) {
      const key = roleKey(l);
      const found = l.role === ROLE.bank
        ? mappedRow(company.bankAccounts, maps, "account", key, "number")
        : postingAccount(company, maps, key);
      if (!found) return `account ${key}: not a ${l.role === ROLE.bank ? "bank account" : "G/L account that takes postings"} of this company`;
    }
  }
  return null;
}

/** What the readback of a sale [row] says of [p]: ours under the customer
 * [customerNumber], with the invoice [credited] a credit memo applies to. */
function saleRemote(row: Row, p: Posting, customerNumber: string, credited?: Row): RemoteDocument {
  const expected = saleExpected(p);
  const differences: string[] = [];
  if (!customerNumber || row.customerNumber !== customerNumber) {
    differences.push(`Business Central holds ${p.documentNumber} for another customer`);
  }
  const status = String(row.status ?? "");
  const draft = DRAFT_SALE.has(status);
  if (!draft && !POSTED_SALE.has(status)) differences.push(`Business Central holds it as ${status || "no status"}`);
  for (
    const [field, want] of [
      ["totalAmountExcludingTax", expected.net],
      ["totalTaxAmount", expected.tax],
      ["totalAmountIncludingTax", expected.gross],
    ] as const
  ) {
    if (minorOf(row[field], p.currency) !== want) {
      differences.push(`Business Central ${field} ${row[field] ?? "missing"}, the document ${toMajor(want, p.currency)}`);
    }
  }
  if (credited) {
    // A credit memo whose application did not land, or that still owes
    // beside an invoice that still owes, would leave the invoice open.
    const applied = row.invoiceId === credited.id;
    const bothOwe = !draft && status === "Open" && (minorOf(credited.remainingAmount, p.currency) ?? 0) > 0;
    if (!applied || bothOwe) differences.push(`not applied to ${credited.externalDocumentNumber ?? credited.number} in Business Central`);
  } else if (!draft && entityOf(p.kind) === "salesInvoices") {
    const remaining = minorOf(row.remainingAmount, p.currency);
    if (remaining === null || remaining < 0 || remaining > expected.gross) {
      differences.push(`Business Central remainingAmount ${row.remainingAmount ?? "missing"}`);
    }
  }
  return {
    id: String(row.id ?? ""),
    number: String(row.number ?? ""),
    version: etagOf(row),
    state: draft ? "draft" : "posted",
    matches: differences.length === 0,
    difference: differences.length > 0 ? differences.join("; ") : undefined,
  };
}

/** What the unposted lines [rows] of a payment or journal say of [p]. */
function draftEntryRemote(rows: Row[], p: Posting, number: string, invoiceId?: string): RemoteDocument {
  const debits = debitsOf(p);
  const differences: string[] = [];
  const held = rows.reduce((s, r) => {
    const v = minorOf(r.amount, p.currency) ?? 0;
    return s + Math.abs(v);
  }, 0);
  // A payment is one line of its amount; a journal's lines add up to twice
  // its debits, a debit and a credit for each.
  const want = invoiceId === undefined ? 2 * debits : debits;
  if (held !== want) differences.push(`Business Central lines ${toMajor(held, p.currency)}, the document ${toMajor(want, p.currency)}`);
  if (invoiceId !== undefined && rows.some((r) => r.appliesToInvoiceId !== invoiceId)) {
    differences.push(`not applied to ${p.documentNumber} in Business Central`);
  }
  return {
    id: number,
    number,
    version: rows.map(etagOf).join(","),
    state: "draft",
    matches: differences.length === 0,
    difference: differences.length > 0 ? differences.join("; ") : undefined,
  };
}

/** What the posted G/L entries [rows] of a payment or journal say of [p]. */
function postedEntryRemote(rows: Row[], p: Posting, number: string): RemoteDocument {
  const debits = debitsOf(p);
  const held = rows.reduce((s, r) => s + (minorOf(r.debitAmount, p.currency) ?? 0), 0);
  const credits = rows.reduce((s, r) => s + (minorOf(r.creditAmount, p.currency) ?? 0), 0);
  const differences: string[] = [];
  if (held !== debits || credits !== debits) {
    differences.push(
      `Business Central posted ${toMajor(held, p.currency)} / ${toMajor(credits, p.currency)}, the document ${toMajor(debits, p.currency)}`,
    );
  }
  return {
    id: number,
    number,
    version: rows.map((r) => String(r.entryNumber ?? "")).join(","),
    state: "posted",
    matches: differences.length === 0,
    difference: differences.length > 0 ? differences.join("; ") : undefined,
  };
}

/** The Business Central adapter of the delivery kit. */
export function businessCentral(ctx: AdapterContext): PostingAdapter {
  const address = COMPANY_ADDRESS.exec(ctx.tenant);
  const credential = credentialOf(ctx.secrets.access_token ?? "");
  const apiBase = (ctx.env(API_BASE_ENV) || API_BASE).replace(/\/+$/, "");
  const loginBase = (ctx.env(LOGIN_BASE_ENV) || LOGIN_BASE).replace(/\/+$/, "");
  const f = ctx.fetch;
  const root = address ? `${apiBase}/${encodeURIComponent(address[1])}/${encodeURIComponent(address[2])}/api/v2.0` : "";
  const companyPath = address ? `companies(${address[3]})` : "";
  let token = "";
  let company: Company | null = null;
  /** Set once Business Central refused a call for its limits: the run
   * sends no more. */
  let limited = "";

  async function call(url: string, init: RequestInit & { etag?: string } = {}): Promise<Answer> {
    if (limited) return { ok: false, status: 429, detail: limited };
    const { etag, ...rest } = init;
    let res: Response;
    try {
      res = await f(url, {
        ...rest,
        headers: {
          authorization: `Bearer ${token}`,
          accept: "application/json",
          ...(rest.body ? { "content-type": "application/json" } : {}),
          ...(etag ? { "If-Match": etag } : {}),
          ...(rest.headers as Record<string, string> | undefined),
        },
      });
    } catch (error) {
      return { ok: false, detail: String(error).slice(0, DETAIL_LENGTH) };
    }
    const text = await res.text();
    // spec: "Working with API limits" — 429 with `Retry-After` when the
    // environment's 600 calls a minute (6,000 per five minutes) are spent;
    // nothing was done.
    if (res.status === 429) {
      limited = `Business Central's call limit was reached (retry after ${res.headers.get("Retry-After") ?? "?"} s): run the delivery again then`;
      return { ok: false, status: 429, detail: limited };
    }
    if (!res.ok) return { ok: false, status: res.status, detail: `${res.status} ${problemOf(text).slice(0, DETAIL_LENGTH)}` };
    try {
      const body = text ? JSON.parse(text) : {};
      return { ok: true, status: res.status, body: body && typeof body === "object" ? body : {} };
    } catch {
      return { ok: false, status: res.status, detail: "the answer was not JSON" };
    }
  }

  /** A call on the connection's company. */
  const bc = (path: string, init: RequestInit & { etag?: string } = {}) => call(`${root}/${companyPath}/${path}`, init);

  /** Every row of [path], page after page; the words when a page is refused
   * or the list is longer than [MAX_PAGES] pages. */
  async function all(path: string): Promise<Row[] | string> {
    const rows: Row[] = [];
    let url = `${root}/${companyPath}/${path}`;
    for (let page = 0; page < MAX_PAGES; page++) {
      const found = await call(url);
      if (!found.ok) return found.detail;
      rows.push(...(Array.isArray(found.body.value) ? found.body.value as Row[] : []));
      const next = found.body["@odata.nextLink"];
      if (typeof next !== "string" || !next) return rows;
      url = next;
    }
    return `Business Central lists more than ${MAX_PAGES} pages of ${path.split("?")[0]}`;
  }

  /** A token for this run, from the tenant's client credentials. */
  async function signIn(): Promise<string | null> {
    let res: Response;
    try {
      res = await f(`${loginBase}/${encodeURIComponent(address![1])}/oauth2/v2.0/token`, {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded", accept: "application/json" },
        body: new URLSearchParams({
          grant_type: "client_credentials",
          client_id: credential!.clientId,
          client_secret: credential!.secret,
          scope: API_SCOPE,
        }).toString(),
      });
    } catch (error) {
      return `the Microsoft Entra sign-in got no answer: ${String(error).slice(0, DETAIL_LENGTH)}`;
    }
    const text = await res.text();
    let body: Row = {};
    try {
      body = JSON.parse(text) as Row;
    } catch {
      // Not JSON: refused below.
    }
    if (!res.ok || typeof body.access_token !== "string" || !body.access_token) {
      // spec: the token endpoint's `error` / `error_description`.
      const words = [body.error, body.error_description].filter((w) => typeof w === "string" && w).join(": ");
      return `Microsoft Entra refused the application's credentials: ${(words || `${res.status}`).slice(0, DETAIL_LENGTH)}`;
    }
    token = body.access_token;
    return null;
  }

  /** The sale documents of [entity] holding the legal number [number]. */
  async function salesNumbered(entity: "salesInvoices" | "salesCreditMemos", number: string): Promise<Row[] | string> {
    return all(`${entity}?${eq("externalDocumentNumber", number)}`);
  }

  /** The one posted invoice of [party]'s customer holding the legal number
   * [number], or why there is none. */
  async function postedInvoice(number: string, party: PostingParty | undefined): Promise<Row | string> {
    const found = await salesNumbered("salesInvoices", number);
    if (typeof found === "string") return found;
    const ours = found.filter((r) => party?.number && r.customerNumber === party.number);
    if (ours.length > 1) return `Business Central holds ${ours.length} invoices ${number} for customer ${party!.number}`;
    if (ours.length === 0 || !POSTED_SALE.has(String(ours[0].status ?? ""))) {
      return `the invoice ${number} is not posted in Business Central yet: deliver it first`;
    }
    return ours[0];
  }

  /** The id of the party of [number] in [collection], '' when none. */
  async function partyId(collection: string, number: string): Promise<{ row?: Row } | { failure: CreateOutcome }> {
    const found = await all(`${collection}?${eq("number", number)}`);
    if (typeof found === "string") return { failure: refused(found) };
    if (found.length > 1) return { failure: refused(`Business Central holds ${found.length} ${collection} numbered ${number}`) };
    return { row: found[0] };
  }

  /** The customer of [party]: found by its number, else created. */
  async function customerOf(party: PostingParty | undefined): Promise<{ row: Row } | { failure: CreateOutcome }> {
    if (!party?.name || !party.number) return { failure: refused("the document names no customer with a number") };
    if (party.number.length > PARTY_NUMBER_LENGTH) {
      return { failure: refused(`the number ${party.number} is longer than the ${PARTY_NUMBER_LENGTH} characters of a customer number`) };
    }
    const found = await partyId("customers", party.number);
    if ("failure" in found) return found;
    if (found.row) {
      // spec: customer — `currencyCode`, blank for the company's own.
      const currency = String(found.row.currencyCode ?? "");
      if (currency && currency !== company!.baseCurrency) {
        return { failure: refused(`Business Central keeps customer ${party.number} in ${currency}`) };
      }
      return { row: found.row };
    }
    if (SALES_TAX_COUNTRIES.has(company!.country)) {
      return {
        failure: refused(
          `customer ${party.number} is not in Business Central: in ${company!.country} its tax area is set there, so create it there first`,
        ),
      };
    }
    // spec: customer — a `number` given on create needs the customer number
    // series to allow manual numbers; that is the company's decision, and
    // its refusal is said in Business Central's words.
    const created = await bc("customers", {
      method: "POST",
      body: JSON.stringify({ number: party.number, displayName: party.name.slice(0, DESCRIPTION_LENGTH) }),
    });
    if (!created.ok) return { failure: failure(created) };
    return created.body.id ? { row: created.body } : { failure: lost("Business Central answered no customer") };
  }

  /** The journal of [p] by its code, from the run's lists. */
  function journalOf(p: Posting): Row | undefined {
    const code = JOURNAL_CODES[p.journal];
    const journals = entityOf(p.kind) === "customerPayments" ? company!.paymentJournals : company!.journals;
    return journals.find((j) => j.code === code);
  }

  /** The unposted lines of [journal] ([collection] under [owner]). */
  const journalLines = (owner: string, journal: Row, collection: string) =>
    all(`${owner}(${String(journal.id)})/${collection}`);

  async function createSale(
    p: Posting,
    entity: "salesInvoices" | "salesCreditMemos",
    party: PostingParty | undefined,
    maps: AccountingMap[],
    credited?: string,
  ): Promise<CreateOutcome> {
    // The invoice a credit memo corrects first: a credit memo that cannot be
    // applied creates nothing, not even its customer.
    const creditedInvoice = entity === "salesCreditMemos" && credited ? await postedInvoice(credited, party) : undefined;
    if (typeof creditedInvoice === "string") return refused(creditedInvoice);
    const held = await salesNumbered(entity, p.documentNumber);
    if (typeof held === "string") return refused(held);
    if (held.length > 0) {
      return {
        ok: false,
        unknown: false,
        conflict: true,
        detail: `Business Central already holds ${p.documentNumber} (${held.map((r) => r.id).join(", ")})`,
      };
    }
    const found = await customerOf(party);
    if ("failure" in found) return found.failure;
    const customer = found.row;
    const lines = revenueLines(p).map((l) => ({
      lineType: "Account",
      lineObjectNumber: String(postingAccount(company!, maps, roleKey(l))!.number),
      description: (l.qualifier ? `${p.documentNumber} ${l.qualifier}` : p.documentNumber).slice(0, DESCRIPTION_LENGTH),
      quantity: 1,
      unitPrice: major(amountOf(l), p.currency),
      taxCode: String(mappedRow(company!.taxGroups, maps, TAX_CODE_MAP, taxKeyOf(l), "code")!.code),
    }));
    // spec: "Deep insert" — the document and its lines in one call, all or
    // nothing.
    const sent = await bc(`${entity}?$expand=${LINES[entity]}`, {
      method: "POST",
      body: JSON.stringify({
        customerId: customer.id,
        [DATE_FIELD[entity]]: p.date,
        postingDate: p.date,
        externalDocumentNumber: p.documentNumber,
        ...(creditedInvoice ? { invoiceId: creditedInvoice.id } : {}),
        [LINES[entity]]: lines,
      }),
    });
    if (!sent.ok) return failure(sent);
    const id = String(sent.body.id ?? "");
    if (!id) return lost(`Business Central answered no ${entity}`);
    // The draft as Business Central computed it: its totals and its ETag.
    const draft = await bc(`${entity}(${id})`);
    if (!draft.ok) return lost(`the draft ${id} was not read back: ${draft.detail}`);
    return { ok: true, remote: saleRemote(draft.body, p, String(customer.number ?? party!.number), creditedInvoice) };
  }

  async function createPayment(p: Posting, key: string, party: PostingParty | undefined): Promise<CreateOutcome> {
    // The invoice it is applied to first: a payment that cannot be applied
    // creates nothing.
    const invoice = await postedInvoice(p.documentNumber, party);
    if (typeof invoice === "string") return refused(invoice);
    const journal = journalOf(p)!;
    const pending = await journalLines("customerPaymentJournals", journal, "customerPayments");
    if (typeof pending === "string") return refused(pending);
    if (pending.length > 0) {
      return refused(`the customer payment journal ${journal.code} holds ${pending.length} lines: post or clear them first`);
    }
    const amount = p.lines.filter((l) => l.role === ROLE.bank).reduce((s, l) => s + amountOf(l), 0);
    const number = entryNumberOf(key);
    // spec: customerPayment — a receipt credits the customer, so its
    // `amount` is negative; the journal's balancing account is the bank's.
    const sent = await bc(`customerPaymentJournals(${String(journal.id)})/customerPayments`, {
      method: "POST",
      body: JSON.stringify({
        customerId: invoice.customerId,
        postingDate: p.date,
        documentNumber: number,
        externalDocumentNumber: p.documentNumber,
        amount: -major(amount, p.currency),
        appliesToInvoiceId: invoice.id,
        description: `${p.kind} ${p.documentNumber}`.slice(0, DESCRIPTION_LENGTH),
      }),
    });
    if (!sent.ok) return failure(sent);
    if (!sent.body.id) return lost("Business Central answered no customerPayment");
    return { ok: true, remote: draftEntryRemote([sent.body], p, number, String(invoice.id)) };
  }

  async function createJournal(p: Posting, key: string, party: PostingParty | undefined, maps: AccountingMap[]): Promise<CreateOutcome> {
    const parties: Record<string, string> = {};
    for (const role of new Set(p.lines.map((l) => l.role).filter((r) => PARTY_ACCOUNT[r]))) {
      const what = PARTY_ACCOUNT[role];
      if (!party?.number) return refused(`the ${role} line names no party with a number`);
      const found = await partyId(what.collection, party.number);
      if ("failure" in found) return found.failure;
      if (!found.row) return refused(`${what.type} ${party.number} is not in Business Central: deliver its document first`);
      parties[role] = String(found.row.number);
    }
    const journal = journalOf(p)!;
    const pending = await journalLines("journals", journal, "journalLines");
    if (typeof pending === "string") return refused(pending);
    if (pending.length > 0) return refused(`the general journal ${journal.code} holds ${pending.length} lines: post or clear them first`);
    const number = entryNumberOf(key);
    const lines = p.lines.map((l) => {
      const ofParty = PARTY_ACCOUNT[l.role];
      const accountNumber = ofParty
        ? parties[l.role]
        : String(
          (l.role === ROLE.bank
            ? mappedRow(company!.bankAccounts, maps, "account", roleKey(l), "number")
            : postingAccount(company!, maps, roleKey(l)))!.number,
        );
      return {
        accountType: ofParty ? ofParty.type : l.role === ROLE.bank ? "Bank Account" : "G/L Account",
        accountNumber,
        postingDate: p.date,
        documentNumber: number,
        externalDocumentNumber: p.documentNumber,
        // spec: journalLine — `amount` positive for a debit, negative for a
        // credit; no `taxCode`, the tax lines are the posting's own.
        amount: major(l.debitCents - l.creditCents, p.currency),
        description: `${p.kind} ${p.documentNumber} ${roleKey(l)}`.slice(0, DESCRIPTION_LENGTH),
      };
    });
    // spec: "Using OData $batch" with `Isolation: snapshot` — every line or
    // none, so a refused line leaves no half entry in the journal.
    const sent = await call(`${root}/$batch`, {
      method: "POST",
      headers: { Isolation: "snapshot" },
      body: JSON.stringify({
        requests: lines.map((line, i) => ({
          id: String(i + 1),
          method: "POST",
          url: `${companyPath}/journals(${String(journal.id)})/journalLines`,
          headers: { "Content-Type": "application/json" },
          body: line,
        })),
      }),
    });
    if (!sent.ok) return failure(sent);
    const answers = Array.isArray(sent.body.responses) ? sent.body.responses as Row[] : [];
    const refusedLine = answers.find((a) => Number(a.status) >= 300);
    if (refusedLine) {
      return failure({
        status: Number(refusedLine.status),
        detail: `${refusedLine.status} ${problemOf(JSON.stringify(refusedLine.body ?? {})).slice(0, DETAIL_LENGTH)}`,
      });
    }
    if (answers.length !== lines.length) return lost("Business Central answered no journal lines");
    return { ok: true, remote: draftEntryRemote(answers.map((a) => (a.body ?? {}) as Row), p, number) };
  }

  /** The posted G/L entries of the document number [number]. */
  const postedEntries = (number: string) => all(`generalLedgerEntries?${eq("documentNumber", number)}`);

  return {
    async prepare() {
      if (!address) return "the connection names no company as tenant/environment/company id";
      if (!credential) return "the connection holds no application client id and secret";
      const expected = COMPANY_COUNTRIES[ctx.targetId];
      if (!expected) return `no Business Central localisation for ${ctx.targetId}`;
      const signedOut = await signIn();
      if (signedOut) return signedOut;
      // The company by its id: one of another environment or tenant is not
      // found, never taken by its name.
      const found = await call(`${root}/${companyPath}`);
      if (!found.ok) return found.status === 404 ? `the company ${address[3]} is not in the environment ${address[2]}` : found.detail;
      const info = await all("companyInformation");
      if (typeof info === "string") return info;
      const country = String(info[0]?.countryRegionCode ?? "").toUpperCase();
      if (country !== expected) {
        return `this Business Central company is in ${country || "no named country"}; the connection is for ${expected}`;
      }
      const baseCurrency = String(info[0]?.currencyCode ?? "");
      if (!baseCurrency) return "the Business Central company names no local currency";
      const lists: Record<string, Row[]> = {};
      for (const path of ["accounts", "bankAccounts", "taxGroups", "journals", "customerPaymentJournals"]) {
        const rows = await all(path);
        if (typeof rows === "string") return rows;
        lists[path] = rows;
      }
      company = {
        country,
        baseCurrency,
        accounts: lists.accounts,
        bankAccounts: lists.bankAccounts,
        taxGroups: lists.taxGroups,
        journals: lists.journals,
        paymentJournals: lists.customerPaymentJournals,
      };
      return null;
    },
    needs(p): MapNeed[] {
      switch (entityOf(p.kind)) {
        case "salesInvoices":
        case "salesCreditMemos": {
          const lines = revenueLines(p);
          return [
            ...[...new Set(lines.map(roleKey))].map((key) => ({ kind: "account" as const, key })),
            ...[...new Set(lines.map(taxKeyOf))].map((key) => ({ kind: TAX_CODE_MAP, key })),
          ];
        }
        case "customerPayments":
          // The journal's balancing account is the bank's: nothing to map.
          return [];
        case "journalLines":
          return [...new Set(ledgerLines(p).map(roleKey))].map((key) => ({ kind: "account" as const, key }));
      }
    },
    remote(p, party, maps, credited) {
      const entity = entityOf(p.kind);
      const customerNumber = party?.number ?? "";

      /** The credited invoice of a credit memo, or why it cannot be read. */
      const creditedOf = async (): Promise<Row | undefined | string> =>
        entity === "salesCreditMemos" && credited ? await postedInvoice(credited, party) : undefined;

      /** The unposted and posted state of a payment or journal [number]. */
      async function entryState(number: string, invoiceId?: string): Promise<RemoteDocument[] | string> {
        if (!company) return "the Business Central company was not read before the delivery";
        const journal = journalOf(p);
        if (!journal) return `Business Central holds no journal ${JOURNAL_CODES[p.journal] ?? p.journal}`;
        const pending = entity === "customerPayments"
          ? await journalLines("customerPaymentJournals", journal, "customerPayments")
          : await journalLines("journals", journal, "journalLines");
        if (typeof pending === "string") return pending;
        const ours = pending.filter((r) => r.documentNumber === number);
        if (ours.length > 0) return [draftEntryRemote(ours, p, number, invoiceId)];
        const posted = await postedEntries(number);
        if (typeof posted === "string") return posted;
        return posted.length > 0 ? [postedEntryRemote(posted, p, number)] : [];
      }

      return {
        async readback(key) {
          if (entity === "salesInvoices" || entity === "salesCreditMemos") {
            const rows = await salesNumbered(entity, p.documentNumber);
            if (typeof rows === "string") return rows;
            if (rows.length === 0) return [];
            const invoice = await creditedOf();
            if (typeof invoice === "string") return invoice;
            return rows.map((r) => saleRemote(r, p, customerNumber, invoice));
          }
          if (entity === "customerPayments") {
            const invoice = await postedInvoice(p.documentNumber, party);
            if (typeof invoice === "string") return invoice;
            return entryState(entryNumberOf(key), String(invoice.id));
          }
          return entryState(entryNumberOf(key));
        },
        async create(key) {
          if (exponentOf(p.currency) === null) return refused(`the currency ${p.currency} is not stated`);
          if (!company) return refused("the Business Central company was not read before the delivery");
          if (p.currency !== company.baseCurrency) {
            return refused(`the document is in ${p.currency}; this Business Central company keeps its books in ${company.baseCurrency}`);
          }
          const problem = problemOfPosting(p, maps, company);
          if (problem) return refused(problem);
          if (entity === "salesInvoices" || entity === "salesCreditMemos") return createSale(p, entity, party, maps, credited);
          if (entity === "customerPayments") return createPayment(p, key, party);
          return createJournal(p, key, party, maps);
        },
        async post(draft) {
          if (!company) return refused("the Business Central company was not read before the delivery");
          if (entity === "salesInvoices" || entity === "salesCreditMemos") {
            // spec: bound action `Microsoft.NAV.post` (204, no body); the
            // draft's ETag guards it, so a changed draft is never posted.
            const done = await bc(`${entity}(${draft.id})/Microsoft.NAV.post`, { method: "POST", etag: draft.version });
            if (!done.ok) return failure(done);
            // spec: that a posted document keeps the draft's id; if it does
            // not, the delivery log names both ids as a conflict.
            const rows = await salesNumbered(entity, p.documentNumber);
            if (typeof rows === "string") return lost(`the posted document was not read back: ${rows}`);
            const row = rows.find((r) => r.id === draft.id) ?? rows.find((r) => r.customerNumber === customerNumber);
            if (!row) return lost(`Business Central answered no posted ${p.documentNumber}`);
            const invoice = await creditedOf();
            if (typeof invoice === "string") return lost(invoice);
            return { ok: true, remote: saleRemote(row, p, customerNumber, invoice) };
          }
          // A journal is posted as a whole: only while it holds this
          // delivery's lines alone.
          const journal = journalOf(p);
          if (!journal) return refused(`Business Central holds no journal ${JOURNAL_CODES[p.journal] ?? p.journal}`);
          const owner = entity === "customerPayments" ? "customerPaymentJournals" : "journals";
          const pending = await journalLines(owner, journal, entity === "customerPayments" ? "customerPayments" : "journalLines");
          if (typeof pending === "string") return lost(pending);
          const others = pending.filter((r) => r.documentNumber !== draft.id);
          if (others.length > 0) {
            return {
              ok: false,
              unknown: false,
              conflict: true,
              detail: `the journal ${journal.code} holds ${others.length} lines this delivery did not write: it is not posted`,
            };
          }
          // spec: journal / customerPaymentJournal — bound action
          // `Microsoft.NAV.post` posts the batch.
          const done = await bc(`${owner}(${String(journal.id)})/Microsoft.NAV.post`, { method: "POST" });
          if (!done.ok) return failure(done);
          const posted = await postedEntries(draft.id);
          if (typeof posted === "string") return lost(`the posted entries were not read back: ${posted}`);
          if (posted.length === 0) return lost(`Business Central answered no entries of ${draft.id}`);
          return { ok: true, remote: postedEntryRemote(posted, p, draft.id) };
        },
      };
    },
  };
}
