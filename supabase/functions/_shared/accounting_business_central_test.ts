// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2374 — the Business Central adapter through the delivery kit against a
// played company: a year's documents become one sales invoice per invoice
// with its legal number as externalDocumentNumber, net lines with the mapped
// tax code and Business Central's own totals equal to the document's, each
// created as a draft and then posted; the credit memo names and is applied
// to its posted invoice; the receipt is one customer payment applied to the
// posted invoice; a write-off is a balanced journal; a second run creates
// nothing. A token is asked for with the tenant's client credentials and
// every call names the company by its id. A lost post is read back (one
// invoice, acknowledged); a refused post leaves the draft sent, never
// acknowledged; a draft changed since its delivery is a conflict and is not
// posted. What is checked before anything is sent creates nothing at all
// (zero writes). No request leaves the test.
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
import { businessCentral, EXTERNAL_NUMBER_LENGTH, PARTY_NUMBER_LENGTH } from "./accounting_business_central.ts";

/** The rules of `record_accounting_delivery` the kit relies on, with the
 * remote id and version a `sent` draft leaves. */
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
    if (remote && row.remote_id && remote.id !== row.remote_id) {
      row.status = "conflict";
      row.error = `the remote holds ${row.remote_id} and answered ${remote.id}`;
      return Promise.resolve({ ...row, outcome: "conflict" as const });
    }
    row.status = status;
    row.error = status === "conflict" || status === "failed" ? error : "";
    if (remote && status !== "conflict") {
      row.remote_id = remote.id;
      if (remote.version) row.remote_version = remote.version;
    }
    return Promise.resolve({ ...row, outcome: "updated" as const });
  }
}

type Row = Record<string, unknown>;

const cents = (v: unknown) => Math.round(Number(v) * 100);
const major = (c: number) => c / 100;

const TENANT = "contoso.onmicrosoft.com";
const ENVIRONMENT = "Sandbox_DE";
const COMPANY = "7c3e8a1f-2b4d-4e6a-9f10-1a2b3c4d5e6f";
const CLIENT_ID = "0f1e2d3c-4b5a-4968-8776-655443322110";
const SECRET = "Xy8Q~secret.value_with-chars";

/** The rate behind each tax code of the played company: Business Central
 * computes the tax from its posting groups, not from what it is sent. */
const RATES: Record<string, number> = { STANDARD: 19, ZERO: 0 };

const LOCAL_CURRENCY: Record<string, string> = { DE: "EUR", FR: "EUR", CH: "CHF", GB: "GBP", US: "USD", CA: "CAD" };

/** A Business Central company keeping what it is sent. */
function company(
  opts: {
    country?: string;
    companyId?: string;
    rateDelta?: number;
    postAnswer?: "posted" | "forbidden" | "lost";
    loseWrite?: number;
    limitAfter?: number;
    noApplication?: boolean;
  } = {},
) {
  const held: Record<string, Row[]> = {
    customers: [],
    vendors: [],
    salesInvoices: [],
    salesCreditMemos: [],
    customerPayments: [],
    journalLines: [],
    generalLedgerEntries: [],
  };
  const calls: { method: string; path: string; headers: Record<string, string>; body?: unknown }[] = [];
  const st: { writes: number; limitAfter?: number; postAnswer: string } = {
    writes: 0,
    limitAfter: opts.limitAfter,
    postAnswer: opts.postAnswer ?? "posted",
  };
  let next = 100;
  let entry = 1;
  const id = () => `00000000-0000-4000-8000-${String(next++).padStart(12, "0")}`;
  const etag = () => `W/"JzE${next++};"`;
  const list = (rows: Row[]) => Response.json({ value: rows });
  const problem = (status: number, code: string, message: string) => Response.json({ error: { code, message } }, { status });
  /** `field eq 'value'` of a `$filter`. */
  const filterOf = (url: URL): [string, string] | null => {
    const m = /^(\w+) eq '(.*)'$/.exec(url.searchParams.get("$filter") ?? "");
    return m ? [m[1], m[2].replace(/''/g, "'")] : null;
  };
  const where = (rows: Row[], url: URL) => {
    const f = filterOf(url);
    return f ? rows.filter((r) => r[f[0]] === f[1]) : rows;
  };
  const totals = (doc: Row, lines: Row[]) => {
    const net = lines.reduce((s, l) => s + cents(l.unitPrice) * Number(l.quantity), 0);
    const tax = lines.reduce(
      (s, l) => s + Math.round(cents(l.unitPrice) * Number(l.quantity) * (RATES[String(l.taxCode)] + (opts.rateDelta ?? 0)) / 100),
      0,
    );
    Object.assign(doc, {
      totalAmountExcludingTax: major(net),
      totalTaxAmount: major(tax),
      totalAmountIncludingTax: major(net + tax),
    });
  };
  const ledger = (number: string, lines: { account: string; amount: number }[]) => {
    for (const l of lines) {
      held.generalLedgerEntries.push({
        entryNumber: entry++,
        documentNumber: number,
        accountNumber: l.account,
        debitAmount: l.amount > 0 ? major(l.amount) : 0,
        creditAmount: l.amount < 0 ? major(-l.amount) : 0,
      });
    }
  };
  const write = () => {
    if (++st.writes === opts.loseWrite) throw new TypeError("connection reset");
  };
  /** The posted invoice a payment or credit memo settles [amount] of. */
  const settle = (invoiceId: unknown, amount: number) => {
    const invoice = held.salesInvoices.find((d) => d.id === invoiceId)!;
    const owed = cents(invoice.remainingAmount);
    const done = Math.min(owed, amount);
    invoice.remainingAmount = major(owed - done);
    if (owed - done === 0) invoice.status = "Paid";
    return done;
  };
  const companyPath = `companies(${opts.companyId ?? COMPANY})`;
  const fetcher = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input));
    const method = init?.method ?? "GET";
    const headers = (init?.headers ?? {}) as Record<string, string>;
    const raw = init?.body ? String(init.body) : undefined;
    calls.push({ method, path: url.pathname, headers, body: raw && raw.startsWith("{") ? JSON.parse(raw) : raw });
    if (url.host === "login.microsoftonline.com") {
      const form = new URLSearchParams(raw ?? "");
      if (form.get("client_secret") !== SECRET || form.get("client_id") !== CLIENT_ID) {
        return Response.json({ error: "invalid_client", error_description: "AADSTS7000215: Invalid client secret" }, { status: 401 });
      }
      return Response.json({ access_token: "bc-token", expires_in: 3599 });
    }
    if (st.limitAfter !== undefined && calls.length > st.limitAfter) {
      return new Response("", { status: 429, headers: { "Retry-After": "60" } });
    }
    const prefix = `/v2.0/${TENANT}/${ENVIRONMENT}/api/v2.0/`;
    assert(url.pathname.startsWith(prefix), url.pathname);
    const path = decodeURIComponent(url.pathname.slice(prefix.length));
    if (path === "$batch") {
      const body = JSON.parse(raw!) as { requests: { url: string; body: Row }[] };
      const answers = body.requests.map((r) => {
        const line = { ...r.body, id: id(), "@odata.etag": etag() };
        held.journalLines.push(line);
        return { id: "1", status: 201, body: line };
      });
      write();
      return Response.json({ responses: answers });
    }
    if (!path.startsWith(companyPath)) return problem(404, "BadRequest_ResourceNotFound", "Resource not found");
    const rest = path.slice(companyPath.length).replace(/^\//, "");
    if (method === "GET") {
      if (rest === "") return Response.json({ id: COMPANY, name: "CRONUS" });
      if (rest === "companyInformation") {
        return list([{ countryRegionCode: opts.country ?? "DE", currencyCode: LOCAL_CURRENCY[opts.country ?? "DE"] }]);
      }
      if (rest === "accounts") {
        return list(["8400", "8300", "1400", "6930", "4970", "1200"].map((n) => ({ id: `acc-${n}`, number: n, blocked: false, accountType: "Posting" })));
      }
      if (rest === "bankAccounts") return list([{ id: "bank-1", number: "B010" }]);
      if (rest === "taxGroups") return list(Object.keys(RATES).map((code) => ({ id: `tax-${code}`, code })));
      if (rest === "journals") return list([{ id: "jnl-od", code: "OD" }, { id: "jnl-bq", code: "BQ" }]);
      if (rest === "customerPaymentJournals") return list([{ id: "pay-bq", code: "BQ" }]);
      if (rest === "customers" || rest === "vendors" || rest === "generalLedgerEntries") return list(where(held[rest], url));
      if (rest === "salesInvoices" || rest === "salesCreditMemos") return list(where(held[rest], url));
      const one = /^(salesInvoices|salesCreditMemos)\((.+)\)$/.exec(rest);
      if (one) {
        const doc = held[one[1]].find((d) => d.id === one[2]);
        return doc ? Response.json(doc) : problem(404, "BadRequest_NotFound", "not found");
      }
      if (rest === "customerPaymentJournals(pay-bq)/customerPayments") return list(where(held.customerPayments, url));
      if (rest === "journals(jnl-od)/journalLines" || rest === "journals(jnl-bq)/journalLines") {
        return list(where(held.journalLines, url));
      }
      return problem(404, "BadRequest_NotFound", rest);
    }
    const action = /^(salesInvoices|salesCreditMemos)\((.+)\)\/Microsoft\.NAV\.post$/.exec(rest);
    if (action) {
      const doc = held[action[1]].find((d) => d.id === action[2])!;
      if (headers["If-Match"] !== doc["@odata.etag"]) {
        return problem(412, "Request_EntityChanged", "Another user has already changed the record.");
      }
      if (st.postAnswer === "forbidden") {
        return problem(403, "Internal_PermissionDenied", "You do not have permission to post sales documents.");
      }
      const gross = cents(doc.totalAmountIncludingTax);
      Object.assign(doc, { status: "Open", number: `10${next++}`, remainingAmount: major(gross), "@odata.etag": etag() });
      if (action[1] === "salesCreditMemos" && doc.invoiceId && !opts.noApplication) {
        const applied = settle(doc.invoiceId, gross);
        doc.remainingAmount = major(gross - applied);
        doc.status = gross - applied === 0 ? "Paid" : "Open";
      }
      write();
      if (st.postAnswer === "lost") throw new TypeError("timeout");
      return new Response(null, { status: 204 });
    }
    if (rest === "customerPaymentJournals(pay-bq)/Microsoft.NAV.post") {
      for (const pay of held.customerPayments.splice(0)) {
        const amount = -cents(pay.amount);
        settle(pay.appliesToInvoiceId, amount);
        ledger(String(pay.documentNumber), [{ account: "1200", amount }, { account: "1400", amount: -amount }]);
      }
      write();
      return new Response(null, { status: 204 });
    }
    if (rest === "journals(jnl-od)/Microsoft.NAV.post" || rest === "journals(jnl-bq)/Microsoft.NAV.post") {
      const lines = held.journalLines.splice(0);
      ledger(String(lines[0].documentNumber), lines.map((l) => ({ account: String(l.accountNumber), amount: cents(l.amount) })));
      write();
      return new Response(null, { status: 204 });
    }
    const body = JSON.parse(raw!) as Row;
    if (rest === "customers") {
      const row = { ...body, id: id(), currencyCode: "", "@odata.etag": etag() };
      held.customers.push(row);
      write();
      return Response.json(row, { status: 201 });
    }
    const sale = /^(salesInvoices|salesCreditMemos)$/.exec(rest);
    if (sale) {
      const linesKey = sale[1] === "salesInvoices" ? "salesInvoiceLines" : "salesCreditMemoLines";
      const customer = held.customers.find((c) => c.id === body.customerId)!;
      const doc: Row = {
        ...body,
        id: id(),
        number: `D${next++}`,
        customerNumber: customer.number,
        status: "Draft",
        "@odata.etag": etag(),
      };
      totals(doc, body[linesKey] as Row[]);
      held[sale[1]].push(doc);
      write();
      return Response.json(doc, { status: 201 });
    }
    if (rest === "customerPaymentJournals(pay-bq)/customerPayments") {
      const row = { ...body, id: id(), "@odata.etag": etag() };
      held.customerPayments.push(row);
      write();
      return Response.json(row, { status: 201 });
    }
    return problem(400, "BadRequest", rest);
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

const posting = (kind: string, id: string, number: string, date: string, lines: Posting["lines"], currency = "EUR"): Posting => ({
  journal: kind === "invoice" || kind === "credit_note" ? "sales" : kind === "receipt" || kind === "refund" ? "bank" : "other",
  kind,
  date,
  documentId: id,
  documentNumber: number,
  currency,
  lines,
});

/** A German year: a two-rate invoice, its partial payment, a credit note on
 * it, and a written-off rest. */
const invoice = posting("invoice", INV, "RE-2026-0001", "2026-01-31", [
  line("customers", null, 13900, 0),
  line("revenue", "standard", 0, 10000),
  line("revenue", "zero", 0, 2000),
  line("vat_output", "standard", 0, 1900),
]);
const receipt = posting("receipt", INV, "RE-2026-0001", "2026-02-10", [
  line("bank", null, 6000, 0),
  line("customers", null, 0, 6000),
]);
const credit = posting("credit_note", CRN, "GS-2026-0001", "2026-02-14", [
  line("customers", null, 0, 2380),
  line("revenue", "standard", 2000, 0),
  line("vat_output", "standard", 380, 0),
]);
const writeOff = posting("write_off", INV, "RE-2026-0001", "2026-03-31", [
  line("write_off", null, 5520, 0),
  line("customers", null, 0, 5520),
]);
const year = [invoice, receipt, credit, writeOff];

const party: PostingParty = { kind: "member", number: "M7", name: "Ada Lovelace" };

const maps: AccountingMap[] = [
  { kind: "account", key: "revenue:standard", remoteId: "", remoteCode: "8400" },
  { kind: "account", key: "revenue:zero", remoteId: "", remoteCode: "8300" },
  { kind: "item", key: "vat_output:standard", remoteId: "", remoteCode: "STANDARD" },
  { kind: "item", key: "vat_output:zero", remoteId: "", remoteCode: "ZERO" },
  { kind: "account", key: "write_off", remoteId: "", remoteCode: "6930" },
];

async function run(
  s: ReturnType<typeof company>,
  log: Log,
  postings: Posting[],
  opts: { targetId?: string; maps?: AccountingMap[]; credited?: Record<string, string>; party?: PostingParty; tenant?: string; secret?: string } = {},
) {
  const useMaps = opts.maps ?? maps;
  const adapter = businessCentral({
    fetch: s.fetcher,
    secrets: { access_token: `${CLIENT_ID}:${opts.secret ?? SECRET}` },
    tenant: opts.tenant ?? `${TENANT}/${ENVIRONMENT}/${COMPANY}`,
    targetId: opts.targetId ?? "business_central_de",
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
    }, useMaps, log, adapter.remote(p, opts.party ?? party, useMaps, (opts.credited ?? { [CRN]: "RE-2026-0001" })[p.documentId]));
    statuses.push(result.status);
  }
  return { refused: null, statuses };
}

const writes = (s: ReturnType<typeof company>) =>
  s.calls.filter((c) => c.method !== "GET" && !c.path.endsWith("/oauth2/v2.0/token"));
const errorOf = (log: Log) => [...log.rows.values()].map((r) => r.error).join(" | ");

Deno.test("a year becomes one posted Business Central document per document, and a second run creates nothing", async () => {
  const s = company();
  const log = new Log();
  assertEquals((await run(s, log, year)).statuses, year.map(() => "acknowledged"));
  const [sale] = s.held.salesInvoices;
  assertEquals([sale.externalDocumentNumber, sale.invoiceDate, sale.postingDate, sale.status], [
    "RE-2026-0001",
    "2026-01-31",
    "2026-01-31",
    "Open",
  ]);
  // Net lines on the mapped accounts with the mapped tax codes; Business
  // Central's own total equals the issued gross.
  assertEquals((sale.salesInvoiceLines as Row[]).map((l) => [l.lineType, l.lineObjectNumber, l.taxCode, l.unitPrice, l.quantity]), [
    ["Account", "8400", "STANDARD", 100, 1],
    ["Account", "8300", "ZERO", 20, 1],
  ]);
  assertEquals(sale.totalAmountIncludingTax, 139);
  const [memo] = s.held.salesCreditMemos;
  assertEquals([memo.externalDocumentNumber, memo.invoiceId, memo.status], ["GS-2026-0001", sale.id, "Paid"]);
  // One customer payment applied to the posted invoice, then posted: its
  // G/L entries carry the delivery's document number.
  const payment = s.calls.find((c) => c.method === "POST" && c.path.endsWith("/customerPayments"))!.body as Row;
  assertEquals([payment.appliesToInvoiceId, payment.amount, payment.externalDocumentNumber], [sale.id, -60, "RE-2026-0001"]);
  assert(String(payment.documentNumber).startsWith("DK"));
  assertEquals(String(payment.documentNumber).length, 20);
  // The write-off: a balanced journal, the customer's line on the customer.
  const batch = s.calls.find((c) => c.path.endsWith("/$batch"))!;
  assertEquals(batch.headers.Isolation, "snapshot");
  assertEquals((batch.body as { requests: { body: Row }[] }).requests.map((r) => [r.body.accountType, r.body.accountNumber, r.body.amount]), [
    ["G/L Account", "6930", 55.2],
    ["Customer", "M7", -55.2],
  ]);
  assertEquals(sale.remainingAmount, 55.2, "the payment and the credit memo were applied to the invoice");
  assertEquals(s.held.customers.map((c) => [c.number, c.displayName]), [["M7", "Ada Lovelace"]]);
  // The token came from the tenant's client credentials; every API call
  // carries it and names the company by its id.
  const token = s.calls.find((c) => c.path === `/${TENANT}/oauth2/v2.0/token`)!;
  const form = new URLSearchParams(String(token.body));
  assertEquals([form.get("grant_type"), form.get("scope")], ["client_credentials", "https://api.businesscentral.dynamics.com/.default"]);
  const api = s.calls.filter((c) => c.path.startsWith("/v2.0/"));
  assert(api.every((c) => c.headers.authorization === "Bearer bc-token"));
  assert(api.filter((c) => !c.path.endsWith("$batch")).every((c) => c.path.includes(`companies(${COMPANY})`)));
  // Posting is never sending.
  assert(s.calls.every((c) => !c.path.includes("postAndSend")));
  const before = writes(s).length;
  assertEquals((await run(s, log, year)).statuses, year.map(() => "unchanged"));
  assertEquals(writes(s).length, before);
});

Deno.test("a post with no answer is read back: one invoice, acknowledged", async () => {
  const s = company({ postAnswer: "lost" });
  const log = new Log();
  assertEquals((await run(s, log, [invoice])).statuses, ["conflict"]);
  assert(errorOf(log).includes("no answer after post"), errorOf(log));
  s.st.postAnswer = "posted";
  assertEquals((await run(s, log, [invoice])).statuses, ["acknowledged"]);
  assertEquals(s.held.salesInvoices.length, 1);
  assertEquals(s.calls.filter((c) => c.path.endsWith("Microsoft.NAV.post")).length, 1, "posted once");
});

Deno.test("a refused post leaves the draft sent, never acknowledged; once allowed, the same draft is posted", async () => {
  const s = company({ postAnswer: "forbidden" });
  const log = new Log();
  assertEquals((await run(s, log, [invoice])).statuses, ["sent"]);
  const row = [...log.rows.values()][0];
  assertEquals([row.status, s.held.salesInvoices[0].status], ["sent", "Draft"]);
  assertEquals((await run(s, log, [invoice])).statuses, ["sent"]);
  s.st.postAnswer = "posted";
  assertEquals((await run(s, log, [invoice])).statuses, ["acknowledged"]);
  assertEquals(s.held.salesInvoices.length, 1);
  assertEquals(s.held.salesInvoices[0].status, "Open");
});

Deno.test("a delivered draft changed in Business Central is a conflict and is not posted", async () => {
  const s = company({ postAnswer: "forbidden" });
  const log = new Log();
  assertEquals((await run(s, log, [invoice])).statuses, ["sent"]);
  // Someone edits the draft: its ETag moves.
  s.held.salesInvoices[0]["@odata.etag"] = 'W/"JzEdited;"';
  s.st.postAnswer = "posted";
  const posts = s.calls.filter((c) => c.path.endsWith("Microsoft.NAV.post")).length;
  assertEquals((await run(s, log, [invoice])).statuses, ["conflict"]);
  assert(errorOf(log).includes("changed since it was delivered"), errorOf(log));
  assertEquals(s.calls.filter((c) => c.path.endsWith("Microsoft.NAV.post")).length, posts, "no post after the change");
  assertEquals(s.held.salesInvoices[0].status, "Draft");
});

Deno.test("a credit note whose invoice is not posted, or a receipt whose invoice is missing, creates nothing", async () => {
  for (const p of [credit, receipt]) {
    const s = company();
    const log = new Log();
    assertEquals((await run(s, log, [p])).statuses, ["failed"]);
    assert(errorOf(log).includes("the invoice RE-2026-0001 is not posted in Business Central yet"), errorOf(log));
    assertEquals(writes(s).length, 0);
  }
});

Deno.test("deferred tax and another currency are refused by name before anything is sent", async () => {
  const deferred = posting("invoice", INV, "RE-2026-0002", "2026-01-31", [
    line("customers", null, 11900, 0),
    line("revenue", "standard", 0, 10000),
    line("vat_pending", null, 0, 1900),
  ]);
  for (const [p, words] of [[deferred, "vat_pending"], [{ ...invoice, currency: "USD" }, "keeps its books in EUR"]] as const) {
    const s = company();
    const log = new Log();
    assertEquals((await run(s, log, [p])).statuses, ["failed"]);
    assert(errorOf(log).includes(words), errorOf(log));
    assertEquals(writes(s).length, 0);
  }
});

Deno.test("a tax code or account the company does not hold stops the document with the key named; an unmapped one blocks", async () => {
  for (
    const [key, remote, named] of [
      ["vat_output:standard", "NINE", "item vat_output:standard"],
      ["revenue:standard", "9999", "account revenue:standard"],
    ]
  ) {
    const s = company();
    const log = new Log();
    const wrong = maps.map((m) => (m.key === key ? { ...m, remoteCode: remote } : m));
    assertEquals((await run(s, log, [invoice], { maps: wrong })).statuses, ["failed"]);
    assert(errorOf(log).includes(named), errorOf(log));
    assertEquals(writes(s).length, 0);
  }
  const s = company();
  const log = new Log();
  assertEquals((await run(s, log, [invoice], { maps: maps.filter((m) => m.key !== "vat_output:zero") })).statuses, ["blocked"]);
  assert(errorOf(log).includes("item vat_output:zero"));
  assertEquals(writes(s).length, 0);
});

Deno.test("another issuer's document with the same external number is a conflict, nothing is created", async () => {
  const s = company();
  s.held.salesInvoices.push({
    id: "other",
    externalDocumentNumber: "RE-2026-0001",
    customerNumber: "K-OTHER",
    status: "Open",
    totalAmountExcludingTax: 120,
    totalTaxAmount: 19,
    totalAmountIncludingTax: 139,
    remainingAmount: 139,
  });
  const log = new Log();
  assertEquals((await run(s, log, [invoice])).statuses, ["conflict"]);
  assert(errorOf(log).includes("already holds RE-2026-0001"), errorOf(log));
  assertEquals(writes(s).length, 0);
});

Deno.test("a tax Business Central computes otherwise is a conflict, and the draft is never posted", async () => {
  const s = company({ rateDelta: 1 });
  const log = new Log();
  assertEquals((await run(s, log, [invoice])).statuses, ["conflict"]);
  assert(errorOf(log).includes("totalTaxAmount"), errorOf(log));
  assertEquals(s.held.salesInvoices[0].status, "Draft");
  assert(s.calls.every((c) => !c.path.endsWith("Microsoft.NAV.post")));
});

Deno.test("a lost create answer is read back and posted, never created twice", async () => {
  // Writes: the customer, then the invoice whose answer is lost.
  const s = company({ loseWrite: 2 });
  const log = new Log();
  assertEquals((await run(s, log, [invoice])).statuses, ["conflict"]);
  assertEquals((await run(s, log, [invoice])).statuses, ["acknowledged"]);
  assertEquals(s.held.salesInvoices.length, 1);
  assertEquals(s.held.salesInvoices[0].status, "Open");
});

Deno.test("a credit memo Business Central did not apply stays a conflict while both still owe", async () => {
  const s = company({ noApplication: true });
  const log = new Log();
  assertEquals((await run(s, log, [invoice, credit])).statuses, ["acknowledged", "conflict"]);
  assert(errorOf(log).includes("not applied to RE-2026-0001"), errorOf(log));
  const before = writes(s).length;
  assertEquals((await run(s, log, [invoice, credit])).statuses, ["unchanged", "conflict"]);
  assertEquals(writes(s).length, before);
  assertEquals(s.held.salesCreditMemos.length, 1);
});

Deno.test("a lost payment post and a lost journal post are read back from the G/L entries: one entry each", async () => {
  for (const p of [receipt, writeOff]) {
    // Writes: the customer, the invoice, its post, the line(s), then the
    // journal's post whose answer is lost: the fifth.
    const s = company({ loseWrite: 5 });
    const log = new Log();
    assertEquals((await run(s, log, [invoice, p])).statuses, ["acknowledged", "conflict"]);
    assertEquals((await run(s, log, [invoice, p])).statuses, ["unchanged", "acknowledged"]);
    const numbers = new Set(s.held.generalLedgerEntries.map((e) => e.documentNumber));
    assertEquals(numbers.size, 1, p.kind);
  }
});

Deno.test("a journal holding lines this delivery did not write is refused before anything is added", async () => {
  const s = company();
  const log = new Log();
  await run(s, log, [invoice]);
  s.held.journalLines.push({ id: "x", documentNumber: "MANUAL-1", amount: 10 });
  const before = writes(s).length;
  assertEquals((await run(s, log, [invoice, writeOff])).statuses, ["unchanged", "failed"]);
  assert(errorOf(log).includes("the general journal OD holds 1 lines"), errorOf(log));
  assertEquals(writes(s).length, before);
});

Deno.test("numbers longer than Business Central keeps are refused, never cut", async () => {
  for (
    const [p, who, bound] of [
      [{ ...invoice, documentNumber: "R".repeat(EXTERNAL_NUMBER_LENGTH + 1) }, party, EXTERNAL_NUMBER_LENGTH],
      [invoice, { ...party, number: "M".repeat(PARTY_NUMBER_LENGTH + 1) }, PARTY_NUMBER_LENGTH],
    ] as const
  ) {
    const s = company();
    const log = new Log();
    assertEquals((await run(s, log, [p], { party: who })).statuses, ["failed"]);
    assert(errorOf(log).includes(`${bound} characters`), errorOf(log));
    assertEquals(writes(s).length, 0);
  }
});

Deno.test("in the US a customer is never created: its tax area is Business Central's", async () => {
  const s = company({ country: "US" });
  const log = new Log();
  const dollars = { ...invoice, currency: "USD" };
  assertEquals((await run(s, log, [dollars], { targetId: "business_central_us" })).statuses, ["failed"]);
  assert(errorOf(log).includes("its tax area is set there"), errorOf(log));
  assertEquals(writes(s).length, 0);
  s.held.customers.push({ id: "c-us", number: "M7", displayName: "Ada Lovelace", currencyCode: "" });
  assertEquals((await run(s, new Log(), [dollars], { targetId: "business_central_us" })).statuses, ["acknowledged"]);
});

Deno.test("the company is checked before anything: its localisation, its id, the application's credentials", async () => {
  const fr = company({ country: "FR" });
  assert((await run(fr, new Log(), year)).refused?.includes("this Business Central company is in FR; the connection is for DE"));
  assertEquals(writes(fr).length, 0);
  assertEquals((await run(company({ country: "FR" }), new Log(), [], { targetId: "business_central_fr" })).refused, null);
  const elsewhere = company({ companyId: "11111111-2222-4333-8444-555555555555" });
  assert((await run(elsewhere, new Log(), year)).refused?.includes(`the company ${COMPANY} is not in the environment ${ENVIRONMENT}`));
  const wrong = company();
  assert((await run(wrong, new Log(), year, { secret: "nope" })).refused?.includes("AADSTS7000215"));
  assert((await run(company(), new Log(), year, { tenant: "CRONUS" })).refused?.includes("tenant/environment/company id"));
});

Deno.test("Business Central's call limit stops the run's remaining calls", async () => {
  const s = company({ limitAfter: 12 });
  const log = new Log();
  const { statuses } = await run(s, log, year);
  assert(statuses.some((x) => x !== "acknowledged"));
  assert(errorOf(log).includes("call limit"), errorOf(log));
  assertEquals(s.calls.length, 13);
});
