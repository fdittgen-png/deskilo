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
//     is mapped to (`item vat_output:<group>`, TAX_CODE_MAP).
//   * CA and GB realms: tax codes are realm objects (`HST ON`, `GST/QST QC`,
//     `20.0% S`, `0.0% Z`), so each line carries the code its rate group is
//     mapped to (`item vat_output:<group>`, a zero-rated group too) and
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

import { type AccountingMap, type CreateOutcome, DETAIL_LENGTH, type MapNeed, type RemoteDocument } from "./accounting_delivery.ts";
import {
  accountNeeds,
  type AdapterContext,
  mapped,
  type Posting,
  type PostingAdapter,
  type PostingLine,
  type PostingParty,
  roleKey,
  type TaxEntry,
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

/** The country of the realm each target is for, as `CompanyInfo.Country`
 * may read it: the first is the app descriptor's
 * (`accounting_targets_quickbooks.dart`; pinned by accounting_targets_test).
 * spec: the ISO code; a British company may read "UK" until a sandbox
 * settles it. */
export const REALM_COUNTRIES: Record<string, string[]> = {
  quickbooks_online_us: ["US"],
  quickbooks_online_ca: ["CA"],
  quickbooks_online_gb: ["GB", "UK"],
};

/** The mapping kind that names a rate group's realm `TaxCode`, keyed by
 * the group's tax role (`vat_output:<group>`). Not `account`: the same
 * role key names the tax ACCOUNT of a journal entry's tax line, and one key
 * must not mean both. Not `tax` either: a tax mapping is keyed by a tax
 * component (`VAT|GB|taxed|20|2011`) and the postings carry rate groups. */
const TAX_CODE_MAP = "item" as const;

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
    return { ok: false, detail: String(error).slice(0, DETAIL_LENGTH) };
  }
  const text = await res.text();
  if (!res.ok) return { ok: false, status: res.status, detail: `${res.status} ${faultOf(text).slice(0, DETAIL_LENGTH)}` };
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
  // By the number kept in Notes first, so a renamed member or supplier is
  // the same customer; then by the name it was created under.
  // spec: "Query operations" — whether Notes is filterable on Customer and
  // Vendor; a refused filter falls through to the name.
  const byNumber = party.number ? await query(fetchImpl, cfg, type, `Notes = ${quoted(party.number)}`) : [];
  if (Array.isArray(byNumber) && byNumber.length === 1) return { id: String(byNumber[0].Id), type };
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
export async function checkRealm(fetchImpl: typeof fetch, cfg: Cfg, countries: string[]): Promise<string | null> {
  if (!cfg.token) return "the connection holds no token";
  if (!cfg.realm) return "the sign-in named no QuickBooks company";
  const info = await qbo(fetchImpl, cfg, `companyinfo/${encodeURIComponent(cfg.realm)}`);
  if (!info.ok) return info.detail;
  const held = String((info.body.CompanyInfo as Record<string, unknown> | undefined)?.Country ?? "");
  if (!countries.includes(held)) {
    return `this QuickBooks company is in ${held || "no named country"}; the connection is for ${countries[0]}`;
  }
  const prefs = await qbo(fetchImpl, cfg, "preferences");
  if (!prefs.ok) return prefs.detail;
  // spec: Preferences.SalesFormsPrefs.CustomTxnNumbers.
  const sales = (prefs.body.Preferences as Record<string, unknown> | undefined)?.SalesFormsPrefs as
    | Record<string, unknown>
    | undefined;
  return sales?.CustomTxnNumbers === true ? null : CUSTOM_NUMBERS_OFF;
}

/** What the readback of [row] says of [p], [ours] when it carries [key];
 * [taxLines] are the differences of its tax lines (taxLineDifferences). */
function remoteOf(
  row: Record<string, unknown>,
  p: Posting,
  key: string,
  expected?: { total: number; tax?: number },
  taxLines: string[] = [],
): RemoteDocument {
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
  differences.push(...taxLines);
  return {
    id: String(row.Id ?? ""),
    number: String(row.DocNumber ?? row.PaymentRefNum ?? ""),
    version: sync,
    state: "posted",
    matches: differences.length === 0,
    difference: differences.length > 0 ? differences.join("; ") : undefined,
  };
}

/** #2371 — the most steps the readback spends matching a sale's frozen
 * breakdown to its rate groups' codes; past it, the split stays unverified.
 * Exported for the test of that path. */
export let ASSIGNMENT_STEPS = 10_000;

/** Sets [ASSIGNMENT_STEPS] for a test, answering the previous value. */
export function setAssignmentStepsForTest(steps: number): number {
  const was = ASSIGNMENT_STEPS;
  ASSIGNMENT_STEPS = steps;
  return was;
}

/** The key a percentage is compared under: 9.975 and 9.9750 alike. */
const percentKey = (p: number): string => Number(p).toFixed(6);

/** #2371 — what the tax lines QuickBooks booked for a sale [row] say of
 * [p], in a CA or GB realm (a US invoice carries one override code). A
 * combined code (`GST/QST QC`) is one rate group of the posting but books
 * one `TaxLine` per rate (GST, QST), so the posting's one tax line per rate
 * group says nothing of the split. The split is the document's own: its
 * breakdown as frozen at issue (`taxBreakdown`, `invoices.vat_totals`),
 * never recomputed from the realm's rates.
 *
 * Each frozen entry is the tax of one rate group: it is found by its net
 * and tax among the posting's groups, and each of its components must be
 * exactly one rate of the code that group is mapped to — the rate of its
 * percentage — so a rate of another code, another authority, is never
 * taken for it, whatever its figures. The expected tax and base are summed
 * per rate (two codes may share GST) and compared with what QuickBooks
 * booked per `TaxRateRef`; a booked rate no component claims is a
 * difference. A breakdown that was not read, an entry no group explains, a
 * taxed group no entry explains, a component its code has no (or several)
 * rates for: the split is unverified — reported, never assumed. A string
 * when the realm could not be asked.
 *
 * spec: TaxCode.SalesTaxRateList.TaxRateDetail[].TaxRateRef, TaxRate.RateValue
 * and TxnTaxDetail.TaxLine[] {Amount, TaxLineDetail {TaxRateRef,
 * NetAmountTaxable}} — Accounting API v3 reference, not verified against a
 * live realm. */
async function taxLineDifferences(
  fetchImpl: typeof fetch,
  cfg: Cfg,
  p: Posting,
  maps: AccountingMap[],
  row: Record<string, unknown>,
): Promise<string[] | string> {
  if (!p.taxBreakdown) return ["the tax split is unverified: the document's frozen breakdown was not read"];
  const differences: string[] = [];
  const unverified = (why: string) => differences.push(`the tax split is unverified: ${why}`);
  const values = new Map<string, string | null>();
  const taxed = [...taxedGroups(p)].map((group) => ({
    group,
    name: group ?? "the base rate",
    code: mapped(maps, TAX_CODE_MAP, taxKeyOf({ qualifier: group })),
    net: revenueLines(p).filter((l) => l.qualifier === group).reduce((s, l) => s + amountOf(l), 0),
    tax: p.lines
      .filter((l) => (l.role === ROLE.vatOutput || l.role === ROLE.vatPending) && l.qualifier === group)
      .reduce((s, l) => s + amountOf(l), 0),
    rates: [] as { id: string; percent: string | null }[],
  }));
  // Every taxed group's mapped code, with its rates and their values.
  const ratesOf = new Map<string, { id: string; percent: string | null }[]>();
  for (const g of taxed) {
    if (!ratesOf.has(g.code)) {
      const codes = await query(fetchImpl, cfg, "TaxCode", `Id = ${quoted(g.code)}`);
      if (typeof codes === "string") return codes;
      const list = (codes[0]?.SalesTaxRateList as Record<string, unknown> | undefined)?.TaxRateDetail;
      const rates: { id: string; percent: string | null }[] = [];
      for (const r of Array.isArray(list) ? list as Record<string, unknown>[] : []) {
        const id = String((r.TaxRateRef as Record<string, unknown> | undefined)?.value ?? "");
        if (!values.has(id)) {
          const found = await query(fetchImpl, cfg, "TaxRate", `Id = ${quoted(id)}`);
          if (typeof found === "string") return found;
          const v = found[0]?.RateValue;
          values.set(id, typeof v === "number" || typeof v === "string" ? percentKey(Number(v)) : null);
        }
        rates.push({ id, percent: values.get(id) ?? null });
      }
      ratesOf.set(g.code, rates);
    }
    g.rates = ratesOf.get(g.code)!;
  }
  // How [entry] lands on [g]'s code: one distinct rate per component, the
  // code's rates all used; null when it does not fit.
  const fit = (entry: TaxEntry, g: (typeof taxed)[number]): string[] | null => {
    if (g.net !== entry.netCents || g.tax !== entry.taxCents) return null;
    if (entry.components.length !== g.rates.length) return null;
    const used = new Set<string>();
    const ids: string[] = [];
    for (const c of entry.components) {
      const candidates = g.rates.filter((r) => r.percent === percentKey(c.percent) && !used.has(r.id));
      if (candidates.length !== 1) return null;
      used.add(candidates[0].id);
      ids.push(candidates[0].id);
    }
    return ids;
  };
  const entries = p.taxBreakdown.filter((e) => e.taxCents !== 0);
  // Every way to give each entry its own group whose code fits it: entries
  // with the same net and tax but another structure (15 % against 5 % +
  // 10 %) are told apart by their codes, whatever their order. Identical
  // entries (the same components) and identical groups (the same net, tax
  // and mapped code, so the same rates) are classes: an assignment is how
  // many of each entry class go to each group class, so swapping two equal
  // entries is never searched twice. The search keeps the first
  // assignment's expected figures and stops at one that expects others
  // (ambiguous); past [ASSIGNMENT_STEPS] steps it stops and the split stays
  // unverified, never assumed.
  const classOf = <T>(items: T[], key: (x: T) => string) => {
    const out = new Map<string, { rep: T; count: number }>();
    for (const x of items) {
      const k = key(x);
      const was = out.get(k);
      if (was) was.count++;
      else out.set(k, { rep: x, count: 1 });
    }
    return [...out.values()];
  };
  const entryClasses = classOf(entries, (e) =>
    JSON.stringify([e.netCents, e.taxCents, e.components.map((c) => [percentKey(c.percent), c.baseCents, c.taxCents])])
  );
  const groupClasses = classOf(taxed, (g) => JSON.stringify([g.net, g.tax, g.code]));
  // [count] entries of class [ei] onto group class [gi].
  type Placement = { ei: number; gi: number; count: number };
  const expectedOf = (placements: Placement[]) => {
    const out = new Map<string, { amount: number; base: number }>();
    for (const { ei, gi, count } of placements) {
      const e = entryClasses[ei].rep;
      const ids = fit(e, groupClasses[gi].rep)!;
      e.components.forEach((c, k) => {
        const was = out.get(ids[k]) ?? { amount: 0, base: 0 };
        out.set(ids[k], { amount: was.amount + c.taxCents * count, base: was.base + c.baseCents * count });
      });
    }
    return out;
  };
  const same = (x: Map<string, { amount: number; base: number }>, y: Map<string, { amount: number; base: number }>) =>
    x.size === y.size && [...x].every(([k, v]) => y.get(k)?.amount === v.amount && y.get(k)?.base === v.base);
  let first: Placement[] | null = null;
  let firstExpected: Map<string, { amount: number; base: number }> | null = null;
  let ambiguous = false;
  let steps = 0;
  let exhausted = false;
  const room = groupClasses.map((g) => g.count);
  const fits = entryClasses.map((e) => groupClasses.map((g) => fit(e.rep, g.rep) !== null));
  // Places entry class [ei] (with [left] of it still to place) from group
  // class [from] on.
  const walk = (ei: number, left: number, from: number, placed: Placement[]) => {
    if (ambiguous || exhausted) return;
    if (++steps > ASSIGNMENT_STEPS) {
      exhausted = true;
      return;
    }
    if (ei === entryClasses.length) {
      const found = expectedOf(placed);
      if (firstExpected === null) {
        firstExpected = found;
        first = [...placed];
      } else if (!same(firstExpected, found)) {
        ambiguous = true;
      }
      return;
    }
    if (left === 0) {
      walk(ei + 1, ei + 1 < entryClasses.length ? entryClasses[ei + 1].count : 0, 0, placed);
      return;
    }
    for (let gi = from; gi < groupClasses.length; gi++) {
      if (!fits[ei][gi] || room[gi] === 0) continue;
      for (let n = Math.min(left, room[gi]); n >= 1; n--) {
        room[gi] -= n;
        placed.push({ ei, gi, count: n });
        walk(ei, left - n, gi + 1, placed);
        placed.pop();
        room[gi] += n;
        if (ambiguous || exhausted) return;
      }
    }
  };
  if (entryClasses.length > 0) {
    walk(0, entryClasses[0].count, 0, []);
  } else if (taxed.length === 0) {
    // A sale without tax (zero-rated, exempt): nothing to place, nothing
    // expected; any tax QuickBooks books is still unexplained below.
    first = [];
    firstExpected = new Map();
  }
  // Why no assignment exists, in the terms a bookkeeper can act on.
  const diagnose = () => {
    for (const entry of entries) {
      const carriers = taxed.filter((g) => g.net === entry.netCents && g.tax === entry.taxCents);
      if (carriers.length === 0) {
        unverified(`no rate group of the document carries ${toMajor(entry.taxCents, p.currency)} at ${entry.percent} %`);
      } else if (!carriers.some((g) => fit(entry, g))) {
        const g = carriers[0];
        const missing = entry.components.find((c) => !g.rates.some((r) => r.percent === percentKey(c.percent)));
        unverified(
          missing
            ? `the tax code ${g.code} of ${g.name} has no rate at ${missing.percent} %`
            : `the tax code ${g.code} of ${g.name} does not have the rates of the frozen ${entry.percent} %`,
        );
      }
    }
    for (const g of taxed) {
      if (!entries.some((entry) => fit(entry, g))) {
        if (!entries.some((entry) => g.net === entry.netCents && g.tax === entry.taxCents)) {
          unverified(`the frozen breakdown does not explain the tax of ${g.name}`);
        }
      }
    }
  };
  let expected = new Map<string, { amount: number; base: number }>();
  if (exhausted) {
    unverified("the frozen breakdown has too many ways onto the rate groups' codes to be verified");
  } else if (entries.length !== taxed.length || first === null) {
    diagnose();
    if (!differences.length) unverified("no mapped tax code fits the frozen breakdown of every rate group");
  } else if (ambiguous) {
    unverified("the frozen breakdown fits the rate groups' codes in more than one way");
  } else {
    expected = expectedOf(first);
  }
  const booked = new Map<string, { amount: number; base: number }>();
  const detail = row.TxnTaxDetail as Record<string, unknown> | undefined;
  for (const t of Array.isArray(detail?.TaxLine) ? detail!.TaxLine as Record<string, unknown>[] : []) {
    const d = (t.TaxLineDetail ?? {}) as Record<string, unknown>;
    const amount = Math.abs(toMinor(String(t.Amount ?? 0), p.currency) ?? 0);
    if (amount === 0) continue;
    const id = String((d.TaxRateRef as Record<string, unknown> | undefined)?.value ?? "");
    const was = booked.get(id) ?? { amount: 0, base: 0 };
    booked.set(id, {
      amount: was.amount + amount,
      base: was.base + Math.abs(toMinor(String(d.NetAmountTaxable ?? 0), p.currency) ?? 0),
    });
  }
  for (const [id, want] of expected) {
    const got = booked.get(id);
    if (!got) {
      differences.push(`QuickBooks booked no tax at rate ${id}, the document ${toMajor(want.amount, p.currency)}`);
      continue;
    }
    if (got.amount !== want.amount) {
      differences.push(`QuickBooks tax ${toMajor(got.amount, p.currency)} at rate ${id}, the document ${toMajor(want.amount, p.currency)}`);
    }
    if (got.base !== want.base) {
      differences.push(`QuickBooks taxed ${toMajor(got.base, p.currency)} at rate ${id}, the document ${toMajor(want.base, p.currency)}`);
    }
  }
  for (const [id, got] of booked) {
    if (!expected.has(id)) {
      differences.push(`QuickBooks booked tax ${toMajor(got.amount, p.currency)} at rate ${id}, which no mapped code of the document names`);
    }
  }
  return differences;
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
    txnTaxCode = mapped(maps, TAX_CODE_MAP, taxKeyOf({ qualifier: [...groups][0] }));
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
          value: us ? (groups.has(l.qualifier) ? US_TAXABLE : US_NOT_TAXABLE) : mapped(maps, TAX_CODE_MAP, taxKeyOf(l)),
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
  const countries = REALM_COUNTRIES[ctx.targetId] ?? [];
  const country = countries[0] ?? "";
  const cfg: Cfg = {
    base: ctx.env(API_BASE_ENV) || API_BASE,
    token: ctx.secrets.access_token ?? "",
    realm: ctx.tenant,
  };
  const f = ctx.fetch;
  return {
    // #2371 — a CA or GB sale's tax lines are checked against the frozen split.
    needsFrozenTax: country !== "US",
    prepare: () =>
      country ? checkRealm(f, cfg, countries) : Promise.resolve(`no QuickBooks realm for ${ctx.targetId}`),
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
            ...new Set(taxKeys.map((k) => `${TAX_CODE_MAP} ${k}`)),
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
      // #2371 — a CA or GB sale is read back per tax line too.
      const saleTaxLines = async (r: Record<string, unknown>): Promise<string[] | string> =>
        (entity === "Invoice" || entity === "CreditMemo") && country !== "US"
          ? await taxLineDifferences(f, cfg, p, maps, r)
          : [];
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
          const out: RemoteDocument[] = [];
          for (const r of relevant) {
            const lines = await saleTaxLines(r);
            if (typeof lines === "string") return lines;
            out.push(remoteOf(r, p, key, expected, lines));
          }
          return out;
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
            // The invoice first: a payment that cannot be linked creates
            // nothing, not even its customer.
            const invoices = await query(f, cfg, "Invoice", `DocNumber = ${quoted(p.documentNumber)}`);
            if (typeof invoices === "string") return refused(invoices);
            if (invoices.length !== 1) {
              return refused(
                invoices.length === 0
                  ? `the invoice ${p.documentNumber} is not in QuickBooks yet: deliver it first`
                  : `QuickBooks holds ${invoices.length} invoices numbered ${p.documentNumber}`,
              );
            }
            const customer = await partyRef(f, cfg, party);
            if ("failure" in customer) return customer.failure;
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
          const lines = await saleTaxLines(row);
          return {
            ok: true,
            remote: remoteOf(row, p, key, expected, typeof lines === "string" ? [lines] : lines),
          };
        },
      };
    },
  };
}

