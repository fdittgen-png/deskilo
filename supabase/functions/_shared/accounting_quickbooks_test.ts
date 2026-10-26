// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The QuickBooks Online adapter through the delivery kit against a played
// realm: the company is refused without custom transaction numbers or in
// another country; a year's documents become one Invoice per invoice with
// its legal number, one CreditMemo per credit note, one Payment linked to
// its invoice and a balanced JournalEntry, and a second run creates
// nothing; a US realm gets TAX/NON lines and the tax override; a total
// QuickBooks computes otherwise, an edited SyncToken and a number another
// issuer holds are conflicts and nothing is sent over them. No request
// leaves the test.
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
import { CUSTOM_NUMBERS_OFF, MINOR_VERSION, quickbooksOnline } from "./accounting_quickbooks.ts";

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

/** A QuickBooks company keeping what it is sent. */
function realm(opts: { country?: string; customNumbers?: boolean; taxDelta?: number } = {}) {
  const held: Record<string, Row[]> = { Invoice: [], CreditMemo: [], Payment: [], JournalEntry: [], Customer: [] };
  const urls: string[] = [];
  const st = { posts: 0, loseNextAnswer: false };
  let next = 100;
  const fetcher = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input));
    urls.push(url.toString());
    const path = url.pathname.replace(/^\/v3\/company\/[^/]+\//, "");
    if (path.startsWith("companyinfo/")) return Response.json({ CompanyInfo: { Country: opts.country ?? "CA" } });
    if (path === "preferences") {
      return Response.json({ Preferences: { SalesFormsPrefs: { CustomTxnNumbers: opts.customNumbers ?? true } } });
    }
    if (path === "query") {
      const m = /^select \* from (\w+) where (\w+) = '(.*)'$/.exec(url.searchParams.get("query") ?? "")!;
      return Response.json({ QueryResponse: { [m[1]]: held[m[1]].filter((r) => String(r[m[2]]) === m[3]) } });
    }
    if (init?.method === "POST") {
      st.posts++;
      const entity = Object.keys(held).find((e) => e.toLowerCase() === path)!;
      const body = JSON.parse(String(init.body)) as Row;
      const row: Row = { ...body, Id: String(next++), SyncToken: "0" };
      if (entity === "Invoice" || entity === "CreditMemo") {
        const lines = (body.Line as Row[]).reduce((s, l) => s + Number(l.Amount), 0);
        const tax = Number((body.TxnTaxDetail as Row).TotalTax) + (opts.taxDelta ?? 0);
        row.TxnTaxDetail = { ...(body.TxnTaxDetail as Row), TotalTax: tax };
        row.TotalAmt = Math.round((lines + tax) * 100) / 100;
      }
      held[entity].push(row);
      if (st.loseNextAnswer) {
        st.loseNextAnswer = false;
        throw new TypeError("connection reset");
      }
      return Response.json({ [entity]: row });
    }
    return new Response("{}", { status: 404 });
  }) as typeof fetch;
  return { held, urls, st, fetcher };
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
  currency: "CAD",
  lines,
});

/** A Quebec year: an invoice (GST+QST in one code), its payment, a credit
 * note and a written-off rest. */
const year: Posting[] = [
  posting("invoice", INV, "F-2026-0001", "2026-01-31", [
    line("customers", null, 11498, 0),
    line("revenue", "standard", 0, 10000),
    line("vat_output", "standard", 0, 1498),
  ]),
  posting("receipt", INV, "F-2026-0001", "2026-02-10", [line("bank", null, 10000, 0), line("customers", null, 0, 10000)]),
  posting("credit_note", CRN, "A-2026-0001", "2026-02-14", [
    line("customers", null, 0, 2299),
    line("revenue", "standard", 2000, 0),
    line("vat_output", "standard", 299, 0),
  ]),
  posting("write_off", INV, "F-2026-0001", "2026-03-31", [line("write_off", null, 1498, 0), line("customers", null, 0, 1498)]),
];

const party: PostingParty = { kind: "member", number: "M-7", name: "Ada Lovelace" };

const maps: AccountingMap[] = [
  { kind: "item", key: "revenue:standard", remoteId: "IT-1", remoteCode: "" },
  { kind: "item", key: "vat_output:standard", remoteId: "TC-QC", remoteCode: "" },
  { kind: "account", key: "vat_output:standard", remoteId: "AC-25", remoteCode: "" },
  { kind: "account", key: "bank", remoteId: "AC-35", remoteCode: "" },
  { kind: "account", key: "customers", remoteId: "AC-84", remoteCode: "" },
  { kind: "account", key: "write_off", remoteId: "AC-90", remoteCode: "" },
];

async function run(
  q: ReturnType<typeof realm>,
  log: Log,
  postings: Posting[],
  targetId = "quickbooks_online_ca",
  useMaps = maps,
) {
  const adapter = quickbooksOnline({
    fetch: q.fetcher,
    secrets: { access_token: "QB-secret" },
    tenant: "9130350000000001",
    targetId,
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
      periodTo: "2026-12-31",
      payloadSha256: await postingSha256(p),
      needs: adapter.needs(p),
    }, useMaps, log, adapter.remote(p, party, useMaps));
    statuses.push(result.status);
  }
  return { refused: null, statuses };
}

Deno.test("a realm without custom transaction numbers, or in another country, is refused before anything", async () => {
  const off = realm({ customNumbers: false });
  assertEquals((await run(off, new Log(), year)).refused, CUSTOM_NUMBERS_OFF);
  assert(CUSTOM_NUMBERS_OFF.includes("Custom transaction numbers"));
  const elsewhere = realm({ country: "US" });
  assert((await run(elsewhere, new Log(), year)).refused!.includes("is in US"));
  assertEquals(off.st.posts + elsewhere.st.posts, 0);
});

Deno.test("a year becomes one object per document, and a second run creates nothing", async () => {
  const q = realm();
  const log = new Log();
  assertEquals((await run(q, log, year)).statuses, ["acknowledged", "acknowledged", "acknowledged", "acknowledged"]);
  const [invoice] = q.held.Invoice;
  assertEquals(invoice.DocNumber, "F-2026-0001");
  assertEquals((invoice.TxnTaxDetail as Record<string, unknown>).TotalTax, 14.98);
  assertEquals(invoice.TotalAmt, 114.98);
  assertEquals((invoice.Line as Record<string, Record<string, Record<string, string>>>[])[0].SalesItemLineDetail, {
    ItemRef: { value: "IT-1" },
    TaxCodeRef: { value: "TC-QC" },
  });
  assertEquals(q.held.CreditMemo.map((c) => c.DocNumber), ["A-2026-0001"]);
  const [payment] = q.held.Payment;
  assertEquals((payment.Line as Record<string, unknown>[])[0].LinkedTxn, [{ TxnId: invoice.Id, TxnType: "Invoice" }]);
  assertEquals(payment.DepositToAccountRef, { value: "AC-35" });
  const [entry] = q.held.JournalEntry;
  const lines = (entry.Line as Record<string, Record<string, unknown>>[]).map((l) => l.JournalEntryLineDetail);
  assertEquals(lines.map((l) => l.PostingType), ["Debit", "Credit"]);
  assertEquals((lines[1].Entity as Record<string, unknown>).Type, "Customer");
  assertEquals(q.held.Customer.map((c) => c.DisplayName), ["Ada Lovelace (M-7)"]);
  // Every call names the minor version; every create a requestid of at
  // most 50 characters.
  assert(q.urls.every((u) => new URL(u).searchParams.get("minorversion") === MINOR_VERSION));
  for (const u of q.urls.filter((u) => new URL(u).searchParams.has("requestid"))) {
    assert(new URL(u).searchParams.get("requestid")!.length <= 50);
  }
  const posts = q.st.posts;
  assertEquals((await run(q, log, year)).statuses, ["unchanged", "unchanged", "unchanged", "unchanged"]);
  assertEquals(q.st.posts, posts);
});

Deno.test("a US realm takes TAX and NON lines and the document's tax as the override", async () => {
  const q = realm({ country: "US" });
  const sale: Posting = {
    ...year[0],
    currency: "USD",
    lines: [
      line("customers", null, 10800, 0),
      line("revenue", "standard", 0, 8000),
      line("revenue", "zero", 0, 2000),
      line("vat_output", "standard", 0, 800),
    ],
  };
  const us = [...maps, { kind: "item" as const, key: "revenue:zero", remoteId: "IT-2", remoteCode: "" }];
  assertEquals((await run(q, new Log(), [sale], "quickbooks_online_us", us)).statuses, ["acknowledged"]);
  const [invoice] = q.held.Invoice;
  const codes = (invoice.Line as Record<string, Record<string, Record<string, string>>>[]).map((l) =>
    l.SalesItemLineDetail.TaxCodeRef.value
  );
  assertEquals(codes, ["TAX", "NON"]);
  assertEquals(invoice.TxnTaxDetail, { TxnTaxCodeRef: { value: "TC-QC" }, TotalTax: 8 });
  assertEquals(invoice.GlobalTaxCalculation, undefined);
});

Deno.test("a zero-rated group needs its realm tax code too: unmapped, the document is blocked", async () => {
  const q = realm({ country: "GB" });
  const sale: Posting = { ...year[0], currency: "GBP", lines: [line("customers", null, 2000, 0), line("revenue", "zero", 0, 2000)] };
  // The zero group's item is mapped; its realm tax code is not.
  const gb = [...maps, { kind: "item" as const, key: "revenue:zero", remoteId: "IT-2", remoteCode: "" }];
  assertEquals((await run(q, new Log(), [sale], "quickbooks_online_gb", gb)).statuses, ["blocked"]);
  assertEquals(q.st.posts, 0);
});

Deno.test("a tax QuickBooks books otherwise is a conflict, never acknowledged", async () => {
  const q = realm({ taxDelta: 0.01 });
  const log = new Log();
  assertEquals((await run(q, log, [year[0]])).statuses, ["conflict"]);
  assert([...log.rows.values()][0].error.includes("QuickBooks tax 14.99"));
  assertEquals((await run(q, log, [year[0]])).statuses, ["conflict"]);
  assertEquals(q.st.posts, 2, "the customer and the invoice, once");
});

Deno.test("a document edited in QuickBooks after a lost answer is a conflict and is not sent again", async () => {
  const q = realm();
  const log = new Log();
  q.held.Customer.push({ Id: "C-1", DisplayName: "Ada Lovelace (M-7)" });
  q.st.loseNextAnswer = true;
  assertEquals((await run(q, log, [year[2]])).statuses, ["conflict"]);
  const posts = q.st.posts;
  q.held.CreditMemo[0].SyncToken = "3";
  assertEquals((await run(q, log, [year[2]])).statuses, ["conflict"]);
  assert([...log.rows.values()][0].error.includes("SyncToken 3"));
  assertEquals(q.st.posts, posts);
  assertEquals(q.held.CreditMemo.length, 1);
});

Deno.test("a number another issuer already holds in the realm is a conflict, and nothing is created", async () => {
  const q = realm();
  q.held.Invoice.push({ Id: "7", DocNumber: "F-2026-0001", SyncToken: "0", TotalAmt: 50 });
  const log = new Log();
  assertEquals((await run(q, log, [year[0]])).statuses, ["conflict"]);
  assertEquals((await run(q, log, [year[0]])).statuses, ["conflict"]);
  assertEquals(q.held.Invoice.length, 1);
  assertEquals(q.st.posts, 0);
});

Deno.test("a payment waits for its invoice: refused, nothing created, not even its customer", async () => {
  const q = realm();
  assertEquals((await run(q, new Log(), [year[1]])).statuses, ["failed"]);
  assertEquals(q.held.Payment.length, 0);
  assertEquals(q.st.posts, 0);
});

Deno.test("a write-off with a tax line posts to the tax account, not the tax code", async () => {
  const q = realm();
  const log = new Log();
  const writeOff = posting("write_off", INV, "F-2026-0001", "2026-03-31", [
    line("write_off", null, 10000, 0),
    line("vat_output", "standard", 1498, 0),
    line("customers", null, 0, 11498),
  ]);
  assertEquals((await run(q, log, [year[0], writeOff])).statuses, ["acknowledged", "acknowledged"]);
  const sale = (q.held.Invoice[0].Line as Record<string, Record<string, Record<string, string>>>[])[0];
  assertEquals(sale.SalesItemLineDetail.TaxCodeRef.value, "TC-QC");
  const accounts = (q.held.JournalEntry[0].Line as Record<string, Record<string, Record<string, string>>>[]).map((l) =>
    l.JournalEntryLineDetail.AccountRef.value
  );
  assertEquals(accounts, ["AC-90", "AC-25", "AC-84"]);
});

Deno.test("a British company may read UK", async () => {
  const q = realm({ country: "UK" });
  assertEquals((await run(q, new Log(), [], "quickbooks_online_gb")).refused, null);
});

Deno.test("a customer is found again by the member number kept in its notes", async () => {
  const q = realm();
  q.held.Customer.push({ Id: "C-9", DisplayName: "Ada King (M-7)", Notes: "M-7" });
  await run(q, new Log(), [year[0]]);
  assertEquals((q.held.Invoice[0].CustomerRef as Record<string, string>).value, "C-9");
  assertEquals(q.held.Customer.length, 1);
});
