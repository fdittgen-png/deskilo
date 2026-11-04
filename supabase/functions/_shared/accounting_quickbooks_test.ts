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
import { type Posting, type PostingParty, postingSha256, taxBreakdownOf } from "./accounting_postings.ts";
import { CUSTOM_NUMBERS_OFF, MINOR_VERSION, quickbooksOnline, setAssignmentStepsForTest } from "./accounting_quickbooks.ts";

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

/** A Quebec entry as 0423 freezes it: 14.975 % on [net], GST and QST. */
const qc = (net: number, gst: number, qst: number) => ({
  percent: 14.975,
  netCents: net,
  taxCents: gst + qst,
  components: [{ percent: 5, baseCents: net, taxCents: gst }, { percent: 9.975, baseCents: net, taxCents: qst }],
});

/** A single-rate entry: its own one component. */
const single = (percent: number, net: number, tax: number) => ({
  percent,
  netCents: net,
  taxCents: tax,
  components: [{ percent, baseCents: net, taxCents: tax }],
});

/** The Quebec code: GST 5 % and QST 9.975 %, two rates (#2371). */
const QC_RATES: Record<string, number> = { GST: 5, QST: 9.975 };

/** A QuickBooks company keeping what it is sent. It books a sale's tax as
 * QuickBooks does: one `TaxLine` per rate of each line's code, on the
 * line's net, each rate rounded on its own; [rates] are the realm's rate
 * values, [oneTaxLine] collapses a code's rates into one line, [book]
 * replaces what a code books. */
function realm(opts: {
  country?: string;
  customNumbers?: boolean;
  taxDelta?: number;
  rates?: Record<string, number>;
  oneTaxLine?: boolean;
  book?: (code: string, net: number) => { id: string; amount: number }[];
  codes?: Row[];
  noPercent?: boolean;
} = {}) {
  const rates = opts.rates ?? QC_RATES;
  const held: Record<string, Row[]> = {
    Invoice: [],
    CreditMemo: [],
    Payment: [],
    JournalEntry: [],
    Customer: [],
    TaxCode: [
      {
        Id: "TC-QC",
        Name: "GST/QST QC",
        SalesTaxRateList: {
          TaxRateDetail: Object.keys(QC_RATES).map((r, i) => ({ TaxRateRef: { value: r }, TaxOrder: i })),
        },
      },
      { Id: "TC-GST", Name: "GST", SalesTaxRateList: { TaxRateDetail: [{ TaxRateRef: { value: "GST" }, TaxOrder: 0 }] } },
      ...(opts.codes ?? []),
    ],
    TaxRate: Object.entries(rates).map(([id, value]) => ({ Id: id, RateValue: value })),
  };
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
        // The tax lines of each code, on the net its lines carry.
        const nets = new Map<string, number>();
        for (const l of body.Line as Row[]) {
          const code = String(((l.SalesItemLineDetail as Row).TaxCodeRef as Row).value);
          nets.set(code, (nets.get(code) ?? 0) + Number(l.Amount));
        }
        const taxLines: Row[] = [];
        for (const [code, net] of nets) {
          const c = held.TaxCode.find((t) => t.Id === code);
          if (!c) continue;
          const ids = ((c.SalesTaxRateList as Row).TaxRateDetail as Row[]).map((d) => String((d.TaxRateRef as Row).value));
          const split = opts.book
            ? opts.book(code, net)
            : ids.map((id) => ({ id, amount: Math.round(net * (rates[id] ?? 0)) / 100 }));
          const booked = opts.oneTaxLine
            ? [{ id: ids[0], amount: Math.round(split.reduce((x, t) => x + t.amount, 0) * 100) / 100 }]
            : split;
          for (const t of booked) {
            taxLines.push({
              Amount: t.amount,
              DetailType: "TaxLineDetail",
              TaxLineDetail: {
                TaxRateRef: { value: t.id },
                PercentBased: true,
                ...(opts.noPercent ? {} : { TaxPercent: rates[t.id] }),
                NetAmountTaxable: net,
              },
            });
          }
        }
        row.TxnTaxDetail = {
          ...(body.TxnTaxDetail as Row),
          TotalTax: tax,
          ...(taxLines.length > 0 ? { TaxLine: taxLines } : {}),
        };
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
  {
    ...posting("invoice", INV, "F-2026-0001", "2026-01-31", [
      line("customers", null, 11498, 0),
      line("revenue", "standard", 0, 10000),
      line("vat_output", "standard", 0, 1498),
    ]),
    // As frozen at issue (0423): GST 5 % on 100.00, QST 9.975 % the rest.
    taxBreakdown: [qc(10000, 500, 998)],
  },
  posting("receipt", INV, "F-2026-0001", "2026-02-10", [line("bank", null, 10000, 0), line("customers", null, 0, 10000)]),
  // 20.00 at 14.975 %: 2.995, half up 3.00 = GST 1.00 + QST 2.00 (#2371).
  {
    ...posting("credit_note", CRN, "A-2026-0001", "2026-02-14", [
      line("customers", null, 0, 2300),
      line("revenue", "standard", 2000, 0),
      line("vat_output", "standard", 300, 0),
    ]),
    taxBreakdown: [qc(2000, 100, 200)],
  },
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

Deno.test("#2371 a GST+QST code books two tax lines, one per rate, on the group's net, together the document's tax", async () => {
  const q = realm();
  assertEquals((await run(q, new Log(), [year[0]])).statuses, ["acknowledged"]);
  const lines = ((q.held.Invoice[0].TxnTaxDetail as Row).TaxLine as Row[]).map((t) => [
    ((t.TaxLineDetail as Row).TaxRateRef as Row).value,
    t.Amount,
    (t.TaxLineDetail as Row).NetAmountTaxable,
  ]);
  // 100.00 at 5 % and at 9.975 %: 5.00 + 9.98 = 14.98, the document's tax.
  assertEquals(lines, [["GST", 5, 100], ["QST", 9.98, 100]]);
});

Deno.test("#2371 a realm that splits the document's tax with another QST rate is a conflict, though its total tax agrees", async () => {
  // QuickBooks keeps the TotalTax sent (14.98) but books QST at 9.5 %:
  // 5.00 + 9.50 = 14.50 on the code.
  const q = realm({ rates: { GST: 5, QST: 9.5 } });
  const log = new Log();
  assertEquals((await run(q, log, [year[0]])).statuses, ["conflict"]);
  const [row] = log.rows.values();
  assert(row.error.includes("the tax code TC-QC of standard has no rate at 9.975 %"), row.error);
  assertEquals((q.held.Invoice[0].TxnTaxDetail as Row).TotalTax, 14.98);
});

Deno.test("#2371 a GST+QST code read back with one tax line is a conflict", async () => {
  const q = realm({ oneTaxLine: true });
  const log = new Log();
  assertEquals((await run(q, log, [year[0]])).statuses, ["conflict"]);
  const [row] = log.rows.values();
  assert(row.error.includes("QuickBooks booked no tax at rate QST, the document 9.98"), row.error);
});

Deno.test("#2371 a split that keeps the code's total but not its components is a conflict", async () => {
  // GST 4.00 + QST 10.98 = 14.98: the total agrees, the components do not.
  const wrong = realm({ book: () => [{ id: "GST", amount: 4 }, { id: "QST", amount: 10.98 }] });
  const log = new Log();
  assertEquals((await run(wrong, log, [year[0]])).statuses, ["conflict"]);
  const [row] = log.rows.values();
  assert(row.error.includes("QuickBooks tax 4.00 at rate GST, the document 5.00"), row.error);
  assert(row.error.includes("QuickBooks tax 10.98 at rate QST, the document 9.98"), row.error);
});

Deno.test("#2371 two GST lines and no QST for a two-rate code is a conflict, though the total agrees", async () => {
  const twice = realm({ book: () => [{ id: "GST", amount: 7.49 }, { id: "GST", amount: 7.49 }] });
  const log = new Log();
  assertEquals((await run(twice, log, [year[0]])).statuses, ["conflict"]);
  const [row] = log.rows.values();
  assert(row.error.includes("QuickBooks booked no tax at rate QST, the document 9.98"), row.error);
});

Deno.test("#2371 a mixed invoice, GST alone and GST with QST, reconciles: the shared GST is compared summed", async () => {
  const q = realm();
  const mixed: Posting = {
    ...year[0],
    documentNumber: "F-2026-0009",
    lines: [
      line("customers", null, 17748, 0),
      line("revenue", "standard", 0, 10000),
      line("revenue", "gst", 0, 5000),
      line("vat_output", "standard", 0, 1498),
      line("vat_output", "gst", 0, 250),
    ],
    taxBreakdown: [qc(10000, 500, 998), single(5, 5000, 250)],
  };
  const withGst = [
    ...maps,
    { kind: "item" as const, key: "revenue:gst", remoteId: "IT-3", remoteCode: "" },
    { kind: "item" as const, key: "vat_output:gst", remoteId: "TC-GST", remoteCode: "" },
  ];
  assertEquals((await run(q, new Log(), [mixed], "quickbooks_online_ca", withGst)).statuses, ["acknowledged"]);
  const gst = ((q.held.Invoice[0].TxnTaxDetail as Row).TaxLine as Row[])
    .filter((t) => ((t.TaxLineDetail as Row).TaxRateRef as Row).value === "GST");
  // GST on both codes: 5.00 on 100.00 and 2.50 on 50.00.
  assertEquals(gst.map((t) => t.Amount), [5, 2.5]);
});

Deno.test("#2371 a realm whose rates are misconfigured at 4 % and 10.98 % is a conflict, though it books the same total", async () => {
  // 100.00 at 4 % and 10.98 %: 4.00 + 10.98 = 14.98, the document's total,
  // but not its frozen split (GST 5 % 5.00, QST 9.975 % 9.98).
  const q = realm({ rates: { GST: 4, QST: 10.98 } });
  const log = new Log();
  assertEquals((await run(q, log, [year[0]])).statuses, ["conflict"]);
  const [row] = log.rows.values();
  assert(row.error.includes("the tax code TC-QC of standard has no rate at 5 %"), row.error);
  assert(row.error.includes("QuickBooks booked tax 10.98 at rate QST, which no mapped code of the document names"), row.error);
  assertEquals((q.held.Invoice[0].TxnTaxDetail as Row).TotalTax, 14.98);
});

Deno.test("#2371 a sole rate is checked too: a single-rate code booked at another rate is a conflict", async () => {
  const q = realm({ rates: { GST: 6, QST: 9.975 } });
  const gstOnly: Posting = {
    ...year[0],
    documentNumber: "F-2026-0011",
    lines: [line("customers", null, 5250, 0), line("revenue", "gst", 0, 5000), line("vat_output", "gst", 0, 250)],
    taxBreakdown: [single(5, 5000, 250)],
  };
  const withGst = [
    ...maps,
    { kind: "item" as const, key: "revenue:gst", remoteId: "IT-3", remoteCode: "" },
    { kind: "item" as const, key: "vat_output:gst", remoteId: "TC-GST", remoteCode: "" },
  ];
  const log = new Log();
  assertEquals((await run(q, log, [gstOnly], "quickbooks_online_ca", withGst)).statuses, ["conflict"]);
  const [row] = log.rows.values();
  assert(row.error.includes("the tax code TC-GST of gst has no rate at 5 %"), row.error);
});

Deno.test("#2371 a line on another code's rate is a conflict, though its percentage, base and amount are the GST's", async () => {
  // Ontario's 5 % GST-ON rate, which no mapped code of the invoice names,
  // books what the Quebec GST would: 5.00 at 5 % on 100.00.
  const elsewhere = realm({
    rates: { ...QC_RATES, "GST-ON": 5 },
    book: () => [{ id: "GST-ON", amount: 5 }, { id: "QST", amount: 9.98 }],
  });
  const log = new Log();
  assertEquals((await run(elsewhere, log, [year[0]])).statuses, ["conflict"]);
  const [row] = log.rows.values();
  assert(row.error.includes("QuickBooks booked tax 5.00 at rate GST-ON, which no mapped code of the document names"), row.error);
  assert(row.error.includes("QuickBooks booked no tax at rate GST, the document 5.00"), row.error);
});

Deno.test("#2371 a sale without its frozen breakdown, or one that does not explain its tax, leaves the split unverified", async () => {
  const log = new Log();
  const { taxBreakdown: _, ...bare } = year[0];
  assertEquals((await run(realm(), log, [bare])).statuses, ["conflict"]);
  assert([...log.rows.values()][0].error.includes("the tax split is unverified: the document's frozen breakdown was not read"));
  const log2 = new Log();
  assertEquals((await run(realm(), log2, [{ ...year[0], taxBreakdown: [] }])).statuses, ["conflict"]);
  assert([...log2.rows.values()][0].error.includes("the frozen breakdown does not explain the tax of standard"));
});

Deno.test("#2371 the frozen breakdown is read from vat_totals: entries with their components; absent is not empty", () => {
  assertEquals(
    taxBreakdownOf([
      {
        percent: 14.975, net_cents: 10000, vat_cents: 1498, gross_cents: 11498,
        components: [
          { scheme: "GST", authority: "CA", percent: 5, base_cents: 10000, tax_cents: 500 },
          { scheme: "QST", authority: "QC", percent: 9.975, base_cents: 10000, tax_cents: 998 },
        ],
      },
      { percent: 20, net_cents: -2000, vat_cents: -400, gross_cents: -2400 },
    ]),
    [qc(10000, 500, 998), single(20, 2000, 400)],
  );
  // An invoice that froze no tax says so; a breakdown that is not there is
  // not that.
  assertEquals(taxBreakdownOf([]), []);
  assertEquals(taxBreakdownOf(null), null);
  assertEquals(taxBreakdownOf(undefined), null);
  assertEquals(taxBreakdownOf([{ percent: 5 }]), null);
});

Deno.test("#2371 two rate groups with the same net and tax but other structures are told apart by their codes, in any order", async () => {
  // Both groups: 100.00 net, 15.00 tax. "single" is mapped to a 15 % code,
  // "split" to a code of 5 % + 10 %; the frozen entries come split first.
  const rates = { R15: 15, R5: 5, R10: 10 };
  const q = realm({
    rates,
    codes: [
      { Id: "TC-15", SalesTaxRateList: { TaxRateDetail: [{ TaxRateRef: { value: "R15" }, TaxOrder: 0 }] } },
      {
        Id: "TC-5-10",
        SalesTaxRateList: {
          TaxRateDetail: [{ TaxRateRef: { value: "R5" }, TaxOrder: 0 }, { TaxRateRef: { value: "R10" }, TaxOrder: 1 }],
        },
      },
    ],
  });
  const twins: Posting = {
    ...year[0],
    documentNumber: "F-2026-0015",
    lines: [
      line("customers", null, 23000, 0),
      line("revenue", "single", 0, 10000),
      line("revenue", "split", 0, 10000),
      line("vat_output", "single", 0, 1500),
      line("vat_output", "split", 0, 1500),
    ],
    taxBreakdown: [
      {
        percent: 15,
        netCents: 10000,
        taxCents: 1500,
        components: [{ percent: 5, baseCents: 10000, taxCents: 500 }, { percent: 10, baseCents: 10000, taxCents: 1000 }],
      },
      single(15, 10000, 1500),
    ],
  };
  const twinMaps = [
    ...maps,
    { kind: "item" as const, key: "revenue:single", remoteId: "IT-4", remoteCode: "" },
    { kind: "item" as const, key: "revenue:split", remoteId: "IT-5", remoteCode: "" },
    { kind: "item" as const, key: "vat_output:single", remoteId: "TC-15", remoteCode: "" },
    { kind: "item" as const, key: "vat_output:split", remoteId: "TC-5-10", remoteCode: "" },
  ];
  const log = new Log();
  assertEquals((await run(q, log, [twins], "quickbooks_online_ca", twinMaps)).statuses, ["acknowledged"]);
  // And the same, the entries in the other order.
  const q2 = realm({ rates, codes: (q.held.TaxCode as Row[]).filter((c) => String(c.Id).startsWith("TC-1") || String(c.Id).startsWith("TC-5")) });
  const flipped = { ...twins, documentNumber: "F-2026-0016", taxBreakdown: [...twins.taxBreakdown!].reverse() };
  assertEquals((await run(q2, new Log(), [flipped], "quickbooks_online_ca", twinMaps)).statuses, ["acknowledged"]);
});


Deno.test("#2371 three groups and entries C, A, A: a third assignment that moves C to other rates makes the split ambiguous", async () => {
  // Three groups of 100.00 / 15.00. x is mapped to code K1 (5 % + 10 %), y
  // and z to code K2 (5 % + 10 %, other rates). The frozen entries: C splits
  // 5.00 + 10.00, the two As 4.99 + 10.01. C on x and the As on y and z, in
  // either order, expect the same figures; C on y expects others (K1 would
  // book 4.99 + 10.01, K2 5.00 + 10.00 + 4.99 + 10.01): which one the
  // invoice meant cannot be told, so nothing is assumed.
  const rates = { A5: 5, A10: 10, B5: 5, B10: 10 };
  const code = (id: string, five: string, ten: string) => ({
    Id: id,
    SalesTaxRateList: {
      TaxRateDetail: [{ TaxRateRef: { value: five }, TaxOrder: 0 }, { TaxRateRef: { value: ten }, TaxOrder: 1 }],
    },
  });
  const q = realm({ rates, codes: [code("K1", "A5", "A10"), code("K2", "B5", "B10")] });
  const split = (five: number, ten: number) => ({
    percent: 15,
    netCents: 10000,
    taxCents: 1500,
    components: [{ percent: 5, baseCents: 10000, taxCents: five }, { percent: 10, baseCents: 10000, taxCents: ten }],
  });
  const three: Posting = {
    ...year[0],
    documentNumber: "F-2026-0017",
    lines: [
      line("customers", null, 34500, 0),
      ...["x", "y", "z"].flatMap((g) => [line("revenue", g, 0, 10000), line("vat_output", g, 0, 1500)]),
    ],
    taxBreakdown: [split(500, 1000), split(499, 1001), split(499, 1001)],
  };
  const threeMaps = [
    ...maps,
    ...["x", "y", "z"].flatMap((g) => [
      { kind: "item" as const, key: `revenue:${g}`, remoteId: `IT-${g}`, remoteCode: "" },
      { kind: "item" as const, key: `vat_output:${g}`, remoteId: g === "x" ? "K1" : "K2", remoteCode: "" },
    ]),
  ];
  const log = new Log();
  assertEquals((await run(q, log, [three], "quickbooks_online_ca", threeMaps)).statuses, ["conflict"]);
  const [row] = log.rows.values();
  assert(row.error.includes("the frozen breakdown fits the rate groups' codes in more than one way"), row.error);
});

Deno.test("#2371 twelve equivalent groups and entries are matched as one class, at once", async () => {
  // 12 groups of 10.00 at 5 % on one code: 12! orders, one assignment.
  const groups = Array.from({ length: 12 }, (_, i) => `g${i}`);
  const q = realm({ rates: { ...QC_RATES } });
  const many: Posting = {
    ...year[0],
    documentNumber: "F-2026-0018",
    lines: [
      line("customers", null, 12600, 0),
      ...groups.flatMap((g) => [line("revenue", g, 0, 1000), line("vat_output", g, 0, 50)]),
    ],
    taxBreakdown: groups.map(() => single(5, 1000, 50)),
  };
  const manyMaps = [
    ...maps,
    ...groups.flatMap((g) => [
      { kind: "item" as const, key: `revenue:${g}`, remoteId: `IT-${g}`, remoteCode: "" },
      { kind: "item" as const, key: `vat_output:${g}`, remoteId: "TC-GST", remoteCode: "" },
    ]),
  ];
  const started = performance.now();
  assertEquals((await run(q, new Log(), [many], "quickbooks_online_ca", manyMaps)).statuses, ["acknowledged"]);
  assert(performance.now() - started < 1000, "matched without walking the 12! orders");
});

Deno.test("#2371 past its step limit the matching stops and the split stays unverified", async () => {
  const was = setAssignmentStepsForTest(1);
  try {
    const log = new Log();
    assertEquals((await run(realm(), log, [year[0]])).statuses, ["conflict"]);
    assert(
      [...log.rows.values()][0].error.includes("too many ways onto the rate groups' codes to be verified"),
      [...log.rows.values()][0].error,
    );
  } finally {
    setAssignmentStepsForTest(was);
  }
});

/** A zero-rated sale: 100.00 net, no tax, frozen as one 0 % entry, its rate
 * group mapped to a zero-rated code. */
const zeroSale: Posting = {
  ...year[0],
  documentNumber: "F-2026-0019",
  lines: [line("customers", null, 10000, 0), line("revenue", "zero", 0, 10000)],
  taxBreakdown: [single(0, 10000, 0)],
};
const zeroMaps = [
  ...maps,
  { kind: "item" as const, key: "revenue:zero", remoteId: "IT-0", remoteCode: "" },
  { kind: "item" as const, key: "vat_output:zero", remoteId: "TC-Z", remoteCode: "" },
];
const zeroCode = { Id: "TC-Z", SalesTaxRateList: { TaxRateDetail: [{ TaxRateRef: { value: "Z0" }, TaxOrder: 0 }] } };

Deno.test("#2371 a zero-rated sale reconciles: no tax frozen, none booked", async () => {
  const q = realm({ rates: { ...QC_RATES, Z0: 0 }, codes: [zeroCode] });
  assertEquals((await run(q, new Log(), [zeroSale], "quickbooks_online_ca", zeroMaps)).statuses, ["acknowledged"]);
});

Deno.test("#2371 a zero-rated sale on which QuickBooks books tax is a conflict, though its total tax is the override", async () => {
  const q = realm({ rates: { ...QC_RATES, Z0: 0 }, codes: [zeroCode], book: () => [{ id: "Z0", amount: 5 }] });
  const log = new Log();
  assertEquals((await run(q, log, [zeroSale], "quickbooks_online_ca", zeroMaps)).statuses, ["conflict"]);
  const [row] = log.rows.values();
  assert(row.error.includes("QuickBooks booked tax 5.00 at rate Z0, which no mapped code of the document names"), row.error);
});
