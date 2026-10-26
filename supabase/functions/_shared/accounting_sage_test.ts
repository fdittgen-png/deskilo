// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Sage Accounting adapter through the delivery kit against a played
// business: a year's documents become one sales invoice per invoice with its
// legal number as reference and the document's tax to the cent, one sales
// credit note naming and allocated to the invoice it corrects, one customer
// receipt and one refund allocated to their document, and a balanced
// journal; every call names the business; a second run creates nothing.
// What is checked before anything is sent creates nothing at all (zero
// writes): a credit note whose invoice is not in Sage, a payment whose
// document is not, deferred tax, another currency than the business's, a
// tax rate or ledger account the business does not hold, a contact number
// longer than Sage's reference. A lost answer is read back, never created
// twice; a reference another contact holds and a tax Sage computes otherwise
// are conflicts. The business's country, the sign-in's one business and
// Sage's call limit are checked. No request leaves the test.
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  type AccountingMap,
  deliver,
  DeliveryNotRecorded,
  type DeliveryJob,
  type DeliveryRow,
  type DeliveryStatus,
  type DeliveryStore,
  type RemoteDocument,
} from "./accounting_delivery.ts";
import { type Posting, type PostingParty, postingSha256 } from "./accounting_postings.ts";
import { CONTACT_REFERENCE_LENGTH, sageAccounting } from "./accounting_sage.ts";

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
    if (row.status === "acknowledged") throw new DeliveryNotRecorded("23514", "needs a correction");
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

const BUSINESS = "b0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5";

const BASE_CURRENCY: Record<string, string> = { GB: "GBP", IE: "EUR", CA: "CAD", US: "USD", FR: "EUR", DE: "EUR", ES: "EUR" };

const TAX_RATES: Row[] = [
  { id: "GB_STANDARD", percentage: "20.0" },
  { id: "GB_ZERO", percentage: "0.0" },
];

const LEDGER_ACCOUNTS: Row[] = [
  { id: "la-4000", nominal_code: 4000 },
  { id: "la-1200", nominal_code: 1200 },
  { id: "la-1100", nominal_code: 1100 },
  { id: "la-8100", nominal_code: 8100 },
];

const BANK_ACCOUNTS: Row[] = [{ id: "bank-1", ledger_account: { id: "la-1200" } }];

/** A Sage business keeping what it is sent. */
function business(
  opts: {
    country?: string;
    taxDelta?: number;
    status?: number;
    businesses?: string[];
    limitAfter?: number;
    loseWrite?: number;
    refuseAllocation?: boolean;
  } = {},
) {
  const held: Record<string, Row[]> = {
    sales_invoices: [],
    sales_credit_notes: [],
    contact_payments: [],
    contact_allocations: [],
    journals: [],
    contacts: [],
  };
  const calls: { method: string; path: string; headers: Record<string, string>; body?: Row }[] = [];
  const st: { writes: number; limitAfter?: number } = { writes: 0, limitAfter: opts.limitAfter };
  let next = 100;
  const list = (items: Row[]) => Response.json({ $items: items, $next: null });
  const fetcher = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input));
    const method = init?.method ?? "GET";
    const headers = (init?.headers ?? {}) as Record<string, string>;
    const path = url.pathname.replace(/^\/v3\.1\//, "");
    const body = init?.body ? JSON.parse(String(init.body)) as Row : undefined;
    calls.push({ method, path, headers, body });
    if (st.limitAfter !== undefined && calls.length > st.limitAfter) {
      return new Response("[]", { status: 429, headers: { "Retry-After": "60" } });
    }
    if (opts.status) {
      return Response.json([{ $severity: "error", $dataCode: "RecordInvalid", $message: "Token expired", $source: "" }], {
        status: opts.status,
      });
    }
    if (method === "GET") {
      const search = url.searchParams.get("search") ?? "";
      if (path === "businesses") return list((opts.businesses ?? [BUSINESS]).map((id) => ({ id })));
      if (path.startsWith("businesses/")) return Response.json({ id: BUSINESS, country: { id: opts.country ?? "GB" } });
      if (path === "financial_settings") {
        return Response.json({ base_currency: { id: BASE_CURRENCY[opts.country ?? "GB"] } });
      }
      if (path === "tax_rates") return list(TAX_RATES);
      if (path === "ledger_accounts") return list(LEDGER_ACCOUNTS);
      if (path === "bank_accounts") return list(BANK_ACCOUNTS);
      if (path === "contact_payments" || path === "journals") {
        const day = url.searchParams.get("from_date");
        return list(held[path].filter((r) => r.date === day));
      }
      return list(held[path].filter((r) => String(r.reference ?? "").includes(search)));
    }
    if (path === "contact_allocations" && opts.refuseAllocation) {
      return Response.json([{ $severity: "error", $dataCode: "RecordInvalid", $message: "Allocation not allowed", $source: "" }], {
        status: 422,
      });
    }
    const key = Object.keys(body!)[0];
    const row: Row = { ...(body![key] as Row), id: `${path}-${next++}`, updated_at: `2026-01-01T00:00:${next}Z` };
    if (path === "sales_invoices" || path === "sales_credit_notes") {
      const lines = (row.invoice_lines ?? row.credit_note_lines) as Row[];
      const net = lines.reduce((s, l) => s + cents(l.unit_price) * Number(l.quantity), 0);
      const tax = lines.reduce((s, l) => s + cents(l.tax_amount), 0) + (opts.taxDelta ?? 0);
      Object.assign(row, {
        contact: { id: row.contact_id },
        status: { id: "UNPAID" },
        tax_amount: major(tax).toFixed(2),
        total_amount: major(net + tax).toFixed(2),
        outstanding_amount: major(net + tax).toFixed(2),
      });
    }
    if (path === "contact_payments" || path === "contact_allocations") {
      for (const a of row.allocated_artefacts as Row[]) {
        const doc = [...held.sales_invoices, ...held.sales_credit_notes].find((d) => d.id === a.artefact_id)!;
        doc.outstanding_amount = major(cents(doc.outstanding_amount) - Math.abs(cents(a.amount))).toFixed(2);
      }
    }
    if (path === "journals") {
      row.journal_lines = (row.journal_lines as Row[]).map((l) => ({ ...l, debit: Number(l.debit).toFixed(2) }));
    }
    held[path].push(row);
    if (++st.writes === opts.loseWrite) throw new TypeError("connection reset");
    return Response.json(row);
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

const posting = (kind: string, id: string, number: string, date: string, lines: Posting["lines"], currency = "GBP"): Posting => ({
  journal: kind === "invoice" || kind === "credit_note" ? "sales" : kind === "receipt" || kind === "refund" ? "bank" : "other",
  kind,
  date,
  documentId: id,
  documentNumber: number,
  currency,
  lines,
});

/** A British year: a two-rate invoice, its payment, a credit note on it
 * refunded to the customer, and a written-off rest. */
const invoice = posting("invoice", INV, "F-2026-0001", "2026-01-31", [
  line("customers", null, 14000, 0),
  line("revenue", "standard", 0, 10000),
  line("revenue", "zero", 0, 2000),
  line("vat_output", "standard", 0, 2000),
]);
const receipt = posting("receipt", INV, "F-2026-0001", "2026-02-10", [
  line("bank", null, 6000, 0),
  line("customers", null, 0, 6000),
]);
const credit = posting("credit_note", CRN, "A-2026-0001", "2026-02-14", [
  line("customers", null, 0, 2400),
  line("revenue", "standard", 2000, 0),
  line("vat_output", "standard", 400, 0),
]);
const refund = posting("refund", CRN, "A-2026-0001", "2026-02-20", [
  line("customers", null, 1000, 0),
  line("bank", null, 0, 1000),
]);
const writeOff = posting("write_off", INV, "F-2026-0001", "2026-03-31", [
  line("write_off", null, 5600, 0),
  line("customers", null, 0, 5600),
]);
const year = [invoice, receipt, credit, refund, writeOff];

const party: PostingParty = { kind: "member", number: "M7", name: "Ada Lovelace" };

const maps: AccountingMap[] = [
  { kind: "account", key: "revenue:standard", remoteId: "", remoteCode: "4000" },
  { kind: "account", key: "revenue:zero", remoteId: "", remoteCode: "4000" },
  { kind: "item", key: "vat_output:standard", remoteId: "GB_STANDARD", remoteCode: "" },
  { kind: "item", key: "vat_output:zero", remoteId: "GB_ZERO", remoteCode: "" },
  { kind: "account", key: "bank", remoteId: "", remoteCode: "1200" },
  { kind: "account", key: "customers", remoteId: "", remoteCode: "1100" },
  { kind: "account", key: "write_off", remoteId: "", remoteCode: "8100" },
];

async function run(
  s: ReturnType<typeof business>,
  log: Log,
  postings: Posting[],
  opts: { targetId?: string; maps?: AccountingMap[]; credited?: Record<string, string>; party?: PostingParty } = {},
) {
  const useMaps = opts.maps ?? maps;
  const adapter = sageAccounting({
    fetch: s.fetcher,
    secrets: { access_token: "SAGE-secret" },
    tenant: BUSINESS,
    targetId: opts.targetId ?? "sage_business_cloud_gb",
    env: () => undefined,
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
    }, useMaps, log, adapter.remote(p, opts.party ?? party, useMaps, (opts.credited ?? { [CRN]: "F-2026-0001" })[p.documentId]));
    statuses.push(result.status);
  }
  return { refused: null, statuses };
}

const writes = (s: ReturnType<typeof business>) => s.calls.filter((c) => c.method !== "GET");
const errorOf = (log: Log) => [...log.rows.values()].map((r) => r.error).join(" | ");

Deno.test("a year becomes one Sage artefact per document, and a second run creates nothing", async () => {
  const s = business();
  const log = new Log();
  assertEquals((await run(s, log, year)).statuses, year.map(() => "acknowledged"));
  const [sale] = s.held.sales_invoices;
  assertEquals([sale.reference, sale.currency_id, sale.date], ["F-2026-0001", "GBP", "2026-01-31"]);
  // The two-rate invoice: two lines under one reference, the document's tax.
  assertEquals((sale.invoice_lines as Row[]).map((l) => [l.ledger_account_id, l.tax_rate_id, l.unit_price, l.tax_amount]), [
    ["la-4000", "GB_STANDARD", 100, 20],
    ["la-4000", "GB_ZERO", 20, 0],
  ]);
  const [creditNote] = s.held.sales_credit_notes;
  assertEquals([creditNote.reference, creditNote.original_invoice_id], ["A-2026-0001", sale.id]);
  // Allocated to the invoice it corrects, for what that invoice still owed.
  const [allocation] = s.held.contact_allocations;
  assertEquals((allocation.allocated_artefacts as Row[]).map((a) => [a.artefact_id, a.amount]), [
    [sale.id, 24],
    [creditNote.id, -24],
  ]);
  const [paid, refunded] = s.held.contact_payments;
  assertEquals([paid.transaction_type_id, paid.bank_account_id, paid.total_amount], ["CUSTOMER_RECEIPT", "bank-1", 60]);
  assertEquals((paid.allocated_artefacts as Row[])[0].artefact_id, sale.id);
  assertEquals([refunded.transaction_type_id, refunded.total_amount], ["CUSTOMER_REFUND", 10]);
  assertEquals((refunded.allocated_artefacts as Row[])[0].artefact_id, creditNote.id);
  const [journal] = s.held.journals;
  assertEquals((journal.journal_lines as Row[]).map((l) => [l.ledger_account_id, Number(l.debit), l.credit]), [
    ["la-8100", 56, 0],
    ["la-1100", 0, 56],
  ]);
  assertEquals(s.held.contacts.map((c) => [c.name, c.reference, (c.contact_type_ids as string[])[0]]), [
    ["Ada Lovelace", "M7", "CUSTOMER"],
  ]);
  // Every call names the business.
  assert(s.calls.every((c) => c.headers["X-Business"] === BUSINESS));
  const before = writes(s).length;
  assertEquals((await run(s, log, year)).statuses, year.map(() => "unchanged"));
  assertEquals(writes(s).length, before);
});

Deno.test("a credit note whose invoice is not in Sage creates nothing", async () => {
  const s = business();
  const log = new Log();
  assertEquals((await run(s, log, [credit])).statuses, ["failed"]);
  assert(errorOf(log).includes("the invoice F-2026-0001 is not in Sage yet"), errorOf(log));
  assertEquals(writes(s).length, 0);
});

Deno.test("a receipt or a refund whose document is not in Sage creates nothing, not even a contact", async () => {
  for (const p of [receipt, refund]) {
    const s = business();
    const log = new Log();
    assertEquals((await run(s, log, [p])).statuses, ["failed"]);
    assert(errorOf(log).includes("is not in Sage yet"), errorOf(log));
    assertEquals(writes(s).length, 0);
  }
});

Deno.test("deferred tax is refused by name, and nothing is sent", async () => {
  const s = business();
  const log = new Log();
  const deferred = posting("invoice", INV, "F-2026-0002", "2026-01-31", [
    line("customers", null, 12000, 0),
    line("revenue", "standard", 0, 10000),
    line("vat_pending", null, 0, 2000),
  ]);
  assertEquals((await run(s, log, [deferred])).statuses, ["failed"]);
  assert(errorOf(log).includes("vat_pending"), errorOf(log));
  assertEquals(writes(s).length, 0);
});

Deno.test("a document in another currency than the business's is refused", async () => {
  const s = business();
  const log = new Log();
  const euros = { ...invoice, currency: "EUR" };
  assertEquals((await run(s, log, [euros])).statuses, ["failed"]);
  assert(errorOf(log).includes("keeps its books in GBP"), errorOf(log));
  assertEquals(writes(s).length, 0);
});

Deno.test("a tax rate or ledger account the business does not hold stops the document with the key named", async () => {
  for (
    const [key, remote, named] of [
      ["vat_output:standard", "GB_NINE", "item vat_output:standard"],
      ["revenue:standard", "9999", "account revenue:standard"],
    ]
  ) {
    const s = business();
    const log = new Log();
    const wrong = maps.map((m) =>
      m.key === key ? { ...m, remoteId: m.kind === "item" ? remote : "", remoteCode: m.kind === "item" ? "" : remote } : m
    );
    assertEquals((await run(s, log, [invoice], { maps: wrong })).statuses, ["failed"]);
    assert(errorOf(log).includes(named), errorOf(log));
    assertEquals(writes(s).length, 0);
  }
});

Deno.test("an unmapped tax rate blocks the document, nothing is sent", async () => {
  const s = business();
  const log = new Log();
  const result = await run(s, log, [invoice], { maps: maps.filter((m) => m.key !== "vat_output:zero") });
  assertEquals(result.statuses, ["blocked"]);
  assert(errorOf(log).includes("item vat_output:zero"));
  assertEquals(writes(s).length, 0);
});

Deno.test("a number longer than a Sage contact reference is refused, never cut", async () => {
  const s = business();
  const log = new Log();
  const long = { ...party, number: "M".repeat(CONTACT_REFERENCE_LENGTH + 1) };
  assertEquals((await run(s, log, [invoice], { party: long })).statuses, ["failed"]);
  assert(errorOf(log).includes(`${CONTACT_REFERENCE_LENGTH} characters`), errorOf(log));
  assertEquals(writes(s).length, 0);
});

Deno.test("a lost answer is read back, never created twice", async () => {
  // The contact is the first write; the invoice's answer is the one lost.
  const s = business({ loseWrite: 2 });
  const log = new Log();
  assertEquals((await run(s, log, [invoice])).statuses, ["conflict"]);
  assertEquals((await run(s, log, [invoice])).statuses, ["acknowledged"]);
  assertEquals(s.held.sales_invoices.length, 1);
});

Deno.test("a reference another contact holds, or a tax Sage computes otherwise, is a conflict", async () => {
  const s = business();
  s.held.sales_invoices.push({
    id: "other",
    reference: "F-2026-0001",
    contact: { id: "someone-else" },
    status: { id: "UNPAID" },
    total_amount: "140.00",
    tax_amount: "20.00",
  });
  assertEquals((await run(s, new Log(), [invoice])).statuses, ["conflict"]);
  assertEquals(writes(s).length, 0);
  const t = business({ taxDelta: 1 });
  assertEquals((await run(t, new Log(), [invoice])).statuses, ["conflict"]);
});

Deno.test("a business of another country than the target's is refused before anything", async () => {
  const s = business({ country: "IE" });
  const { refused } = await run(s, new Log(), year);
  assert(refused?.includes("this Sage business is in IE; the connection is for GB"), refused ?? "");
  assertEquals(writes(s).length, 0);
  // The Irish target takes it.
  assertEquals((await run(business({ country: "IE" }), new Log(), [], { targetId: "sage_business_cloud_ie" })).refused, null);
});

Deno.test("the sign-in binds its one business, and refuses several", async () => {
  const one = sageAccounting({
    fetch: business().fetcher,
    secrets: { access_token: "t" },
    tenant: "",
    targetId: "sage_business_cloud_gb",
    env: () => undefined,
  });
  assertEquals(await one.signedInTenant!(), { tenant: BUSINESS });
  const several = sageAccounting({
    fetch: business({ businesses: ["a", "b"] }).fetcher,
    secrets: { access_token: "t" },
    tenant: "",
    targetId: "sage_business_cloud_gb",
    env: () => undefined,
  });
  const answer = await several.signedInTenant!();
  assert("refused" in answer && answer.refused.includes("2 businesses"));
});

Deno.test("Sage's call limit stops the run's remaining calls", async () => {
  const s = business({ limitAfter: 9 });
  const log = new Log();
  const { statuses } = await run(s, log, year);
  const calls = s.calls.length;
  assert(statuses.some((x) => x !== "acknowledged"));
  assert(errorOf(log).includes("call limit"), errorOf(log));
  // After the 429 nothing more is asked of Sage.
  assertEquals(calls, 10);
});

Deno.test("a credit note whose allocation was refused stays a conflict on the next run", async () => {
  const s = business({ refuseAllocation: true });
  const log = new Log();
  assertEquals((await run(s, log, [invoice, credit])).statuses, ["acknowledged", "conflict"]);
  const before = writes(s).length;
  assertEquals((await run(s, log, [invoice, credit])).statuses, ["unchanged", "conflict"]);
  assert(errorOf(log).includes("not allocated to F-2026-0001"), errorOf(log));
  assertEquals(s.held.sales_credit_notes.length, 1);
  assertEquals(writes(s).length, before);
});

Deno.test("an allocation applied but whose answer was lost is acknowledged on the next run", async () => {
  // Writes: the contact, the invoice, the credit note, its allocation.
  const s = business({ loseWrite: 4 });
  const log = new Log();
  assertEquals((await run(s, log, [invoice, credit])).statuses, ["acknowledged", "conflict"]);
  assertEquals((await run(s, log, [invoice, credit])).statuses, ["unchanged", "acknowledged"]);
  assertEquals(s.held.sales_credit_notes.length, 1);
  assertEquals(s.held.contact_allocations.length, 1);
});

Deno.test("the documents the call limit stopped are delivered by the next run", async () => {
  const s = business({ limitAfter: 9 });
  const log = new Log();
  const first = (await run(s, log, year)).statuses;
  assertEquals(first[0], "acknowledged");
  assert(first.slice(1).every((x) => x === "failed"), first.join(","));
  s.st.limitAfter = undefined;
  assertEquals((await run(s, log, year)).statuses, ["unchanged", "acknowledged", "acknowledged", "acknowledged", "acknowledged"]);
  assertEquals(s.held.sales_invoices.length, 1);
});

Deno.test("a lost payment answer and a lost journal answer are read back: one artefact each", async () => {
  for (const [p, lose, collection] of [[receipt, 3, "contact_payments"], [writeOff, 3, "journals"]] as const) {
    // Writes: the contact, the invoice, then the payment or the journal.
    const s = business({ loseWrite: lose });
    const log = new Log();
    assertEquals((await run(s, log, [invoice, p])).statuses, ["acknowledged", "conflict"]);
    assertEquals((await run(s, log, [invoice, p])).statuses, ["unchanged", "acknowledged"]);
    assertEquals(s.held[collection].length, 1, collection);
  }
});

Deno.test("two revenue lines of one rate group carry its tax once, on the first", async () => {
  const s = business();
  const twoLines = posting("invoice", INV, "F-2026-0003", "2026-01-31", [
    line("customers", null, 18000, 0),
    line("revenue", "standard", 0, 10000),
    line("revenue", "standard", 0, 5000),
    line("vat_output", "standard", 0, 3000),
  ]);
  assertEquals((await run(s, new Log(), [twoLines])).statuses, ["acknowledged"]);
  const lines = s.held.sales_invoices[0].invoice_lines as Row[];
  assertEquals(lines.map((l) => [l.unit_price, l.tax_amount]), [[100, 30], [50, 0]]);
  assertEquals(s.held.sales_invoices[0].tax_amount, "30.00");
});
