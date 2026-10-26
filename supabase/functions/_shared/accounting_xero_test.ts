// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Xero adapter through the delivery kit against a played organisation:
// a year's documents become one ACCREC invoice per invoice with its legal
// number and the document's tax to the cent, one ACCRECCREDIT credit note
// allocated to the invoice it corrects, one Payment against its invoice and
// a balanced manual journal; every write carries the Idempotency-Key and
// every call the tenant; a second run creates nothing. A TaxType the
// organisation does not hold, or one its account's class refuses, stops the
// document with the key named; an unmapped one blocks it. A lost answer is
// read back, never created twice; a number another contact holds, a draft
// and a tax Xero computes otherwise are conflicts. The organisation's
// country, the sign-in's one organisation and Xero's call limit are
// checked. No request leaves the test.
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  type AccountingMap,
  deliver,
  type DeliveryJob,
  type DeliveryRow,
  type DeliveryStatus,
  type DeliveryStore,
  type RemoteDocument,
} from "./accounting_delivery.ts";
import { type Posting, type PostingParty, postingSha256 } from "./accounting_postings.ts";
import { CONNECTIONS_URL, IDEMPOTENCY_KEY_LENGTH, signedInTenant, xeroAccounting } from "./accounting_xero.ts";

/** The rules of `record_accounting_delivery` the kit relies on. */
class Log implements DeliveryStore {
  rows = new Map<string, DeliveryRow & { sha: string; error: string }>();
  record(j: DeliveryJob, status: DeliveryStatus, remote?: RemoteDocument, error = "") {
    const id = `${j.documentKind}:${j.documentId}:${j.eventDate}`;
    let row = this.rows.get(id);
    if (!row) {
      row = {
        status: status === "acknowledged" ? "sent" : status,
        idempotency_key: `${id.replace(/[^0-9a-f]/g, "")}${"e".repeat(64)}`.slice(0, 64),
        remote_id: "",
        outcome: "created",
        sha: j.payloadSha256,
        error,
      };
      this.rows.set(id, row);
      if (status !== "acknowledged") return Promise.resolve({ ...row });
    }
    if (row.status === "acknowledged" && row.sha === j.payloadSha256) {
      return Promise.resolve({ ...row, outcome: "unchanged" as const });
    }
    if (status === "generated") return Promise.resolve({ ...row, outcome: "existing" as const });
    row.status = status;
    row.error = status === "conflict" || status === "failed" ? error : "";
    if (status === "acknowledged" && remote) row.remote_id = remote.id;
    return Promise.resolve({ ...row, outcome: "updated" as const });
  }
}

type Row = Record<string, unknown>;

const cents = (v: unknown) => Math.round(Number(v) * 100);
const major = (c: number) => c / 100;

const TENANT = "70784a63-d24b-46a9-a4db-0e70a274b056";

const GB_RATES: Row[] = [
  { TaxType: "OUTPUT2", Status: "ACTIVE", EffectiveRate: 20, CanApplyToRevenue: true, CanApplyToExpenses: false },
  { TaxType: "ZERORATEDOUTPUT", Status: "ACTIVE", EffectiveRate: 0, CanApplyToRevenue: true },
  { TaxType: "INPUT2", Status: "ACTIVE", EffectiveRate: 20, CanApplyToRevenue: false, CanApplyToExpenses: true },
];

const ACCOUNTS: Row[] = [
  { AccountID: "a-200", Code: "200", Class: "REVENUE", Type: "REVENUE", Status: "ACTIVE" },
  { AccountID: "a-090", Code: "090", Class: "ASSET", Type: "BANK", Status: "ACTIVE" },
  { AccountID: "a-610", Code: "610", Class: "ASSET", Type: "CURRENT", Status: "ACTIVE" },
  { AccountID: "a-820", Code: "820", Class: "LIABILITY", Type: "CURRLIAB", Status: "ACTIVE" },
  { AccountID: "a-480", Code: "480", Class: "EXPENSE", Type: "EXPENSE", Status: "ACTIVE" },
];

/** A Xero organisation keeping what it is sent, answering a repeated
 * Idempotency-Key from its cache as Xero does. */
function organisation(opts: { country?: string; taxDelta?: number; status?: number; rates?: Row[]; limitAfter?: number } = {}) {
  const held: Record<string, Row[]> = { Invoices: [], CreditNotes: [], Payments: [], ManualJournals: [], Contacts: [] };
  const calls: { method: string; path: string; headers: Record<string, string>; body?: Row }[] = [];
  const cache = new Map<string, Response>();
  const st = { writes: 0, loseNextAnswer: false };
  let next = 100;
  const fetcher = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input));
    const method = init?.method ?? "GET";
    const headers = (init?.headers ?? {}) as Record<string, string>;
    const path = url.pathname.replace(/^\/api\.xro\/2\.0\//, "");
    const body = init?.body ? JSON.parse(String(init.body)) as Row : undefined;
    calls.push({ method, path, headers, body });
    if (opts.limitAfter !== undefined && calls.length > opts.limitAfter) {
      return new Response("{}", { status: 429, headers: { "Retry-After": "42", "X-Rate-Limit-Problem": "minute" } });
    }
    if (opts.status) return Response.json({ Title: "Unauthorized", Detail: "TokenExpired" }, { status: opts.status });
    if (method === "GET") {
      if (path === "Organisation") return Response.json({ Organisations: [{ CountryCode: opts.country ?? "GB" }] });
      if (path === "TaxRates") return Response.json({ TaxRates: opts.rates ?? GB_RATES });
      if (path === "Accounts") return Response.json({ Accounts: ACCOUNTS });
      if (path === "Invoices") {
        const numbers = (url.searchParams.get("InvoiceNumbers") ?? "").split(",");
        return Response.json({ Invoices: held.Invoices.filter((r) => numbers.includes(String(r.InvoiceNumber))) });
      }
      const m = /^(\w+)=="(.*)"$/.exec(url.searchParams.get("where") ?? "")!;
      return Response.json({ [path]: held[path].filter((r) => String(r[m[1]]) === m[2]) });
    }
    st.writes++;
    const key = headers["Idempotency-Key"];
    if (key && cache.has(key)) return cache.get(key)!.clone();
    const allocation = /^CreditNotes\/([^/]+)\/Allocations$/.exec(path);
    let answer: Response;
    if (allocation) {
      const credit = held.CreditNotes.find((c) => c.CreditNoteID === allocation[1])!;
      const a = (body!.Allocations as Row[])[0];
      const invoice = held.Invoices.find((i) => i.InvoiceID === (a.Invoice as Row).InvoiceID)!;
      invoice.AmountDue = major(cents(invoice.AmountDue) - cents(a.Amount));
      credit.RemainingCredit = major(cents(credit.RemainingCredit) - cents(a.Amount));
      credit.Allocations = [...(credit.Allocations as Row[] ?? []), a];
      answer = Response.json({ Allocations: [a] });
    } else {
      const row: Row = { ...(body![path] as Row[])[0], UpdatedDateUTC: `/Date(${next})/` };
      const id = String(next++);
      if (path === "Invoices" || path === "CreditNotes") {
        const lines = row.LineItems as Row[];
        const net = lines.reduce((s, l) => s + cents(l.UnitAmount) * Number(l.Quantity), 0);
        const tax = lines.reduce((s, l) => s + cents(l.TaxAmount), 0) + (opts.taxDelta ?? 0);
        row.TotalTax = major(tax);
        row.Total = major(net + tax);
        row[path === "Invoices" ? "AmountDue" : "RemainingCredit"] = major(net + tax);
        row[path === "Invoices" ? "InvoiceID" : "CreditNoteID"] = id;
      }
      if (path === "Payments") {
        row.PaymentID = id;
        row.Status = "AUTHORISED";
        const invoice = held.Invoices.find((i) => i.InvoiceID === (row.Invoice as Row).InvoiceID)!;
        invoice.AmountDue = major(cents(invoice.AmountDue) - cents(row.Amount));
      }
      if (path === "ManualJournals") row.ManualJournalID = id;
      if (path === "Contacts") row.ContactID = `contact-${id}`;
      held[path].push(row);
      answer = Response.json({ [path]: [row] });
    }
    if (key) cache.set(key, answer.clone());
    if (st.loseNextAnswer) {
      st.loseNextAnswer = false;
      throw new TypeError("connection reset");
    }
    return answer;
  }) as typeof fetch;
  return { held, calls, st, fetcher };
}

const INV = "44444444-4444-4444-8444-444444444444";
const CRN = "55555555-5555-4555-8555-555555555555";

const line = (role: string, qualifier: string | null, debit: number, credit: number) => ({
  role,
  qualifier,
  debitCents: debit,
  creditCents: credit,
});

const posting = (kind: string, id: string, number: string, date: string, lines: Posting["lines"]): Posting => ({
  journal: kind === "invoice" || kind === "credit_note" ? "sales" : kind === "receipt" ? "bank" : "other",
  kind,
  date,
  documentId: id,
  documentNumber: number,
  currency: "GBP",
  lines,
});

/** A British year: a two-rate invoice, its payment, a credit note on it
 * and a written-off rest. */
const year: Posting[] = [
  posting("invoice", INV, "F-2026-0001", "2026-01-31", [
    line("customers", null, 14000, 0),
    line("revenue", "standard", 0, 10000),
    line("revenue", "zero", 0, 2000),
    line("vat_output", "standard", 0, 2000),
  ]),
  posting("receipt", INV, "F-2026-0001", "2026-02-10", [line("bank", null, 6000, 0), line("customers", null, 0, 6000)]),
  posting("credit_note", CRN, "A-2026-0001", "2026-02-14", [
    line("customers", null, 0, 2400),
    line("revenue", "standard", 2000, 0),
    line("vat_output", "standard", 400, 0),
  ]),
  posting("write_off", INV, "F-2026-0001", "2026-03-31", [line("write_off", null, 5600, 0), line("customers", null, 0, 5600)]),
];

const party: PostingParty = { kind: "member", number: "M-7", name: "Ada Lovelace" };

const maps: AccountingMap[] = [
  { kind: "account", key: "revenue:standard", remoteId: "", remoteCode: "200" },
  { kind: "account", key: "revenue:zero", remoteId: "", remoteCode: "200" },
  { kind: "item", key: "vat_output:standard", remoteId: "", remoteCode: "OUTPUT2" },
  { kind: "item", key: "vat_output:zero", remoteId: "", remoteCode: "ZERORATEDOUTPUT" },
  { kind: "account", key: "bank", remoteId: "", remoteCode: "090" },
  { kind: "account", key: "customers", remoteId: "", remoteCode: "610" },
  { kind: "account", key: "write_off", remoteId: "", remoteCode: "480" },
];

async function run(
  x: ReturnType<typeof organisation>,
  log: Log,
  postings: Posting[],
  opts: { targetId?: string; maps?: AccountingMap[]; credited?: Record<string, string>; eu?: boolean } = {},
) {
  const useMaps = opts.maps ?? maps;
  const adapter = xeroAccounting({
    fetch: x.fetcher,
    secrets: { access_token: "XERO-secret" },
    tenant: TENANT,
    targetId: opts.targetId ?? "xero_gb",
    env: () => undefined,
    isEuCountry: (code) => Promise.resolve(opts.eu ?? code === "IE"),
  });
  const refused = await adapter.prepare();
  if (refused) return { refused, statuses: [] as string[] };
  const statuses: string[] = [];
  for (const p of postings) {
    const result = await deliver({
      connectionId: "c-1",
      documentKind: p.kind,
      documentId: p.documentId,
      eventDate: p.date,
      documentNumber: p.documentNumber,
      periodFrom: "2026-01-01",
      periodTo: "2026-01-31",
      payloadSha256: await postingSha256(p),
      needs: adapter.needs(p),
    }, useMaps, log, adapter.remote(p, party, useMaps, (opts.credited ?? { [CRN]: "F-2026-0001" })[p.documentId]));
    statuses.push(result.status);
  }
  return { refused: null, statuses };
}

const writes = (x: ReturnType<typeof organisation>) => x.calls.filter((c) => c.method !== "GET");

Deno.test("a year becomes one Xero object per document, and a second run creates nothing", async () => {
  const x = organisation();
  const log = new Log();
  assertEquals((await run(x, log, year)).statuses, ["acknowledged", "acknowledged", "acknowledged", "acknowledged"]);
  const [invoice] = x.held.Invoices;
  assertEquals(invoice.Type, "ACCREC");
  assertEquals(invoice.InvoiceNumber, "F-2026-0001");
  assertEquals(invoice.Status, "AUTHORISED");
  assertEquals(invoice.LineAmountTypes, "Exclusive");
  assertEquals(invoice.Reference, "2026-01");
  // The two-rate invoice: two lines under one number, the document's tax.
  const items = invoice.LineItems as Row[];
  assertEquals(items.map((l) => [l.AccountCode, l.TaxType, l.UnitAmount, l.TaxAmount]), [
    ["200", "OUTPUT2", 100, 20],
    ["200", "ZERORATEDOUTPUT", 20, 0],
  ]);
  assertEquals(invoice.TotalTax, 20);
  const [credit] = x.held.CreditNotes;
  assertEquals([credit.Type, credit.CreditNoteNumber, credit.TotalTax], ["ACCRECCREDIT", "A-2026-0001", 4]);
  // Allocated to the invoice it corrects.
  assertEquals((credit.Allocations as Row[]).map((a) => [(a.Invoice as Row).InvoiceID, a.Amount]), [[invoice.InvoiceID, 24]]);
  const [payment] = x.held.Payments;
  assertEquals([(payment.Invoice as Row).InvoiceID, (payment.Account as Row).Code, payment.Amount], [invoice.InvoiceID, "090", 60]);
  const [journal] = x.held.ManualJournals;
  assertEquals((journal.JournalLines as Row[]).map((l) => [l.AccountCode, l.LineAmount]), [["480", 56], ["610", -56]]);
  assertEquals(journal.Status, "POSTED");
  assertEquals(x.held.Contacts.map((c) => [c.Name, c.ContactNumber]), [["Ada Lovelace (M-7)", "M-7"]]);
  // Every call names the tenant; every write carries an Idempotency-Key.
  assert(x.calls.every((c) => c.headers["xero-tenant-id"] === TENANT));
  assert(writes(x).length > 0);
  for (const w of writes(x)) {
    assert(w.headers["Idempotency-Key"], `${w.method} ${w.path} without Idempotency-Key`);
    assert(w.headers["Idempotency-Key"].length <= IDEMPOTENCY_KEY_LENGTH);
  }
  // Xero's PUT creates and never updates.
  assert(writes(x).every((w) => w.method === "PUT"));
  const before = x.st.writes;
  assertEquals((await run(x, log, year)).statuses, ["unchanged", "unchanged", "unchanged", "unchanged"]);
  assertEquals(x.st.writes, before);
  assertEquals(x.held.Invoices.length, 1);
});

Deno.test("a TaxType the organisation does not hold stops the document with the key named", async () => {
  const x = organisation();
  const log = new Log();
  const wrong = maps.map((m) => m.key === "vat_output:standard" ? { ...m, remoteCode: "OUTPUT9" } : m);
  assertEquals((await run(x, log, [year[0]], { maps: wrong })).statuses, ["failed"]);
  const error = [...log.rows.values()][0].error;
  assert(error.includes("item vat_output:standard → OUTPUT9"), error);
  assertEquals(writes(x).length, 0);
});

Deno.test("a TaxType on an account class that refuses it is caught before sending", async () => {
  const x = organisation();
  const log = new Log();
  // INPUT2 is a purchase rate: Xero refuses it on a revenue account.
  const wrong = maps.map((m) => m.key === "vat_output:standard" ? { ...m, remoteCode: "INPUT2" } : m);
  assertEquals((await run(x, log, [year[0]], { maps: wrong })).statuses, ["failed"]);
  assert([...log.rows.values()][0].error.includes("class REVENUE"));
  assertEquals(writes(x).length, 0);
});

Deno.test("an unmapped TaxType blocks the document, nothing is sent", async () => {
  const x = organisation();
  const log = new Log();
  const partial = maps.filter((m) => m.key !== "vat_output:zero");
  const result = await run(x, log, [year[0]], { maps: partial });
  assertEquals(result.statuses, ["blocked"]);
  assert([...log.rows.values()][0].error.includes("item vat_output:zero"));
  assertEquals(writes(x).length, 0);
});

Deno.test("two organisations with the same account code 200 keep their own mappings", async () => {
  const gb = organisation();
  const ca = organisation({
    country: "CA",
    rates: [{ TaxType: "TAX005", Status: "ACTIVE", EffectiveRate: 13, CanApplyToRevenue: true }],
  });
  const caMaps = maps.map((m) => m.kind === "item" ? { ...m, remoteCode: "TAX005" } : m);
  await run(gb, new Log(), [year[0]]);
  await run(ca, new Log(), [{ ...year[0], currency: "CAD" }], { targetId: "xero_ca", maps: caMaps });
  const types = (x: ReturnType<typeof organisation>) => (x.held.Invoices[0].LineItems as Row[]).map((l) => [l.AccountCode, l.TaxType]);
  assertEquals(types(gb), [["200", "OUTPUT2"], ["200", "ZERORATEDOUTPUT"]]);
  assertEquals(types(ca), [["200", "TAX005"], ["200", "TAX005"]]);
});

Deno.test("a lost answer is read back by the legal number, never created twice", async () => {
  const x = organisation();
  const log = new Log();
  x.st.loseNextAnswer = true;
  // The contact is created first; the invoice's answer is the one lost.
  x.held.Contacts.push({ ContactID: "contact-1", Name: "Ada Lovelace (M-7)", ContactNumber: "M-7" });
  assertEquals((await run(x, log, [year[0]])).statuses, ["conflict"]);
  assertEquals(x.held.Invoices.length, 1);
  assertEquals((await run(x, log, [year[0]])).statuses, ["acknowledged"]);
  assertEquals(x.held.Invoices.length, 1);
  assertEquals(writes(x).filter((w) => w.path === "Invoices").length, 1);
});

Deno.test("a lost answer the organisation now holds as a draft is a conflict, not a posted sale", async () => {
  const x = organisation();
  const log = new Log();
  x.held.Contacts.push({ ContactID: "contact-1", Name: "Ada Lovelace (M-7)", ContactNumber: "M-7" });
  x.st.loseNextAnswer = true;
  await run(x, log, [year[0]]);
  x.held.Invoices[0].Status = "DRAFT";
  assertEquals((await run(x, log, [year[0]])).statuses, ["conflict"]);
  assert([...log.rows.values()][0].error.includes("DRAFT in Xero is not a posted sale"));
});

Deno.test("a number another contact holds is a conflict, and nothing is created", async () => {
  const x = organisation();
  x.held.Invoices.push({ InvoiceID: "i-7", Type: "ACCREC", InvoiceNumber: "F-2026-0001", Contact: { ContactID: "other" } });
  const log = new Log();
  assertEquals((await run(x, log, [year[0]])).statuses, ["conflict"]);
  assertEquals((await run(x, log, [year[0]])).statuses, ["conflict"]);
  assertEquals(x.held.Invoices.length, 1);
  assertEquals(writes(x).length, 0);
});

Deno.test("a tax Xero computes otherwise is a conflict, never acknowledged", async () => {
  const x = organisation({ taxDelta: 1 });
  const log = new Log();
  assertEquals((await run(x, log, [year[0]])).statuses, ["conflict"]);
  assert([...log.rows.values()][0].error.includes("Xero tax 20.01"));
});

Deno.test("a changed mapping after the acknowledgement creates no second invoice", async () => {
  const x = organisation();
  const log = new Log();
  await run(x, log, [year[0]]);
  const moved = maps.map((m) => m.key === "revenue:standard" ? { ...m, remoteCode: "201" } : m);
  assertEquals((await run(x, log, [year[0]], { maps: moved })).statuses, ["unchanged"]);
  assertEquals(x.held.Invoices.length, 1);
});

Deno.test("a credit note without the invoice it corrects stays an unallocated credit", async () => {
  const x = organisation();
  assertEquals((await run(x, new Log(), [year[0], year[2]], { credited: {} })).statuses, ["acknowledged", "acknowledged"]);
  assertEquals(x.held.CreditNotes[0].Allocations, undefined);
});

Deno.test("a payment waits for its invoice, and goes only to an account that takes payments", async () => {
  const x = organisation();
  assertEquals((await run(x, new Log(), [year[1]])).statuses, ["failed"]);
  assertEquals(writes(x).length, 0);
  const notBank = maps.map((m) => m.key === "bank" ? { ...m, remoteCode: "610" } : m);
  const log = new Log();
  assertEquals((await run(x, log, [year[0], year[1]], { maps: notBank })).statuses, ["acknowledged", "failed"]);
  assert([...log.rows.values()][1].error.includes("takes no payment"));
  assertEquals(x.held.Payments.length, 0);
});

Deno.test("an organisation in another country, or a revoked connection, is refused before anything", async () => {
  const us = organisation({ country: "US" });
  assert((await run(us, new Log(), year)).refused!.includes("is in US"));
  const revoked = organisation({ status: 401 });
  assert((await run(revoked, new Log(), year)).refused!.includes("TokenExpired"));
  assertEquals(writes(us).length + writes(revoked).length, 0);
});

Deno.test("the EU target takes an organisation in a member state of the tax reference", async () => {
  const ie = organisation({ country: "IE" });
  assertEquals((await run(ie, new Log(), [], { targetId: "xero_eu" })).refused, null);
  const gb = organisation({ country: "GB" });
  assert((await run(gb, new Log(), [], { targetId: "xero_eu" })).refused!.includes("an EU member state"));
});

Deno.test("Xero's call limit stops the run's remaining calls", async () => {
  const x = organisation({ limitAfter: 6 });
  const log = new Log();
  const { statuses } = await run(x, log, year);
  assert(statuses.includes("failed"));
  const calls = x.calls.length;
  assert([...log.rows.values()].some((r) => r.error.includes("minute limit was reached (retry after 42 s)")));
  assertEquals(calls, 7, "one refused call, then none");
});

/** An access token carrying the sign-in's authorisation event. */
const tokenOf = (event: string) => `h.${btoa(JSON.stringify({ authentication_event_id: event })).replace(/=+$/, "")}.s`;

Deno.test("the sign-in binds the one organisation it authorised", async () => {
  const connections = (rows: Row[]) =>
    ((input: string | URL | Request) => {
      assertEquals(String(input), CONNECTIONS_URL);
      return Promise.resolve(Response.json(rows));
    }) as typeof fetch;
  const earlier = { authEventId: "e-0", tenantId: "t-old", tenantType: "ORGANISATION" };
  const now = { authEventId: "e-1", tenantId: TENANT, tenantType: "ORGANISATION" };
  assertEquals(await signedInTenant(connections([earlier, now]), tokenOf("e-1")), { tenant: TENANT });
  const two = await signedInTenant(connections([now, { ...now, tenantId: "t-2" }]), tokenOf("e-1"));
  assert("refused" in two && two.refused.includes("2 organisations"));
  const none = await signedInTenant(connections([earlier, { ...now, tenantType: "PRACTICE" }]), tokenOf("e-1"));
  assert("refused" in none && none.refused.includes("no organisation"));
  const blind = await signedInTenant(connections([now]), "not-a-jwt");
  assert("refused" in blind);
});

Deno.test("a credit note whose answer was lost is not taken as allocated", async () => {
  const x = organisation();
  const log = new Log();
  await run(x, log, [year[0]]);
  x.st.loseNextAnswer = true;
  assertEquals((await run(x, log, [year[2]])).statuses, ["conflict"]);
  assertEquals((await run(x, log, [year[2]])).statuses, ["conflict"]);
  assert([...log.rows.values()][1].error.includes("not allocated to F-2026-0001"));
  assertEquals(x.held.CreditNotes.length, 1);
});
