// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2377 — the bexio adapter through the delivery kit against an in-memory
// bexio: one kb_invoice per document with its legal number as document_nr,
// positions' tax ids and accounts from the connection's maps, issued; a
// second delivery creates nothing; an unmapped tax blocks before anything
// is sent; a send with no answer is read back, never created twice; a
// credit note is a kb_credit_voucher; a receipt is a payment on its
// invoice. No request leaves the test.

import { assertEquals } from "jsr:@std/assert@1";
import {
  type AccountingMap,
  deliver,
  type DeliveryJob,
  type DeliveryRow,
  type DeliveryStatus,
  type DeliveryStore,
  type RemoteDocument,
} from "./accounting_delivery.ts";
import {
  bexioAdapter,
  type BexioDocument,
  documentKey,
  needsOf,
} from "./accounting_bexio.ts";

const config = {
  base_url: "https://bexio.test",
  access_token: "t",
  user_id: "7",
};

const member = "member:00000000-0000-4000-8000-000000000001";
const tax81 = "VAT|CH|taxed|8.1|2024";
const tax26 = "VAT|CH|taxed|2.6|2024";

const maps: AccountingMap[] = [
  { kind: "party", key: member, remoteId: "501", remoteCode: "" },
  { kind: "tax", key: tax81, remoteId: "16", remoteCode: "UN81" },
  { kind: "tax", key: tax26, remoteId: "17", remoteCode: "UR26" },
  {
    kind: "account",
    key: "revenue:standard",
    remoteId: "340",
    remoteCode: "3400",
  },
  {
    kind: "account",
    key: "revenue:reduced",
    remoteId: "341",
    remoteCode: "3401",
  },
];

const invoice = (id: string, number: string): BexioDocument => ({
  id,
  kind: "invoice",
  number,
  date: "2026-03-02",
  dueDate: "2026-04-01",
  currency: "CHF",
  partyKey: member,
  title: `Desk ${number}`,
  lines: [
    {
      label: "Desk",
      netMinor: 100000,
      taxKey: tax81,
      accountKey: "revenue:standard",
    },
    {
      label: "Drinks",
      netMinor: 5000,
      taxKey: tax26,
      accountKey: "revenue:reduced",
    },
  ],
  totalMinor: 113230,
});

/** A bexio that keeps what it is sent. [silentOnce] lets the next create
 * land and answer nothing. */
function bexio() {
  const docs: Record<string, Record<string, unknown>[]> = {
    kb_invoice: [],
    kb_credit_voucher: [],
  };
  const payments: Record<string, unknown>[] = [];
  const calls: string[] = [];
  let next = 1000;
  let silentOnce = false;
  const answer = (input: RequestInfo | URL, init?: RequestInit): Response => {
    const url = new URL(String(input));
    const method = init?.method ?? "GET";
    const path = url.pathname.replace(/^\//, "");
    calls.push(`${method} ${path}`);
    const body = init?.body ? JSON.parse(String(init.body)) : null;
    const json = (b: unknown) => new Response(JSON.stringify(b));
    if (method === "GET" && path === "3.0/currencies") {
      return json([{ id: 1, name: "CHF" }, { id: 2, name: "EUR" }]);
    }
    const search = path.match(/^2\.0\/(kb_invoice|kb_credit_voucher)\/search$/);
    if (method === "POST" && search) {
      return json(
        docs[search[1]].filter((d) => d.document_nr === body[0].value),
      );
    }
    const create = path.match(/^2\.0\/(kb_invoice|kb_credit_voucher)$/);
    if (method === "POST" && create) {
      const net = body.positions as { unit_price: string; tax_id: number }[];
      // 26 and 27: the second company's own ids for the same two rates.
      const rate: Record<number, number> = {
        16: 0.081,
        17: 0.026,
        26: 0.081,
        27: 0.026,
      };
      const total = net.reduce(
        (s, p) =>
          s + Math.round(Number(p.unit_price) * 100 * (1 + rate[p.tax_id])),
        0,
      );
      const d = {
        id: next++,
        ...body,
        total: (total / 100).toFixed(2),
        kb_item_status_id: 7,
      };
      docs[create[1]].push(d);
      if (silentOnce) {
        silentOnce = false;
        throw new TypeError("connection reset");
      }
      return json(d);
    }
    const issue = path.match(
      /^2\.0\/(kb_invoice|kb_credit_voucher)\/(\d+)\/issue$/,
    );
    if (method === "POST" && issue) {
      const d = docs[issue[1]].find((x) => x.id === Number(issue[2]))!;
      d.kb_item_status_id = 8;
      return json({ success: true });
    }
    const pay = path.match(/^2\.0\/kb_invoice\/(\d+)\/payment$/);
    if (pay && method === "POST") {
      const p = { id: next++, invoice: Number(pay[1]), ...body };
      payments.push(p);
      return json(p);
    }
    if (pay && method === "GET") {
      return json(payments.filter((p) => p.invoice === Number(pay[1])));
    }
    return new Response("not found", { status: 404 });
  };
  const fetchImpl = (input: RequestInfo | URL, init?: RequestInit) => {
    try {
      return Promise.resolve(answer(input, init));
    } catch (error) {
      return Promise.reject(error);
    }
  };
  return {
    fetchImpl: fetchImpl as typeof fetch,
    docs,
    payments,
    calls,
    dropNextAnswer: () => (silentOnce = true),
  };
}

/** The store with the rules of `record_accounting_delivery`, as the kit's
 * own test keeps them: one row per identity, the key stored first, an
 * acknowledged digest a no-op. */
class MemoryStore implements DeliveryStore {
  rows = new Map<string, DeliveryRow & { sha: string }>();
  record(j: DeliveryJob, status: DeliveryStatus, remote?: RemoteDocument) {
    const identity =
      `${j.connectionId}:${j.documentKind}:${j.documentId}:${j.eventDate}`;
    const held = this.rows.get(identity);
    if (!held) {
      const row = {
        status,
        idempotency_key: `key-${j.documentId}`,
        remote_id: remote?.id ?? "",
        outcome: "created" as const,
        sha: j.payloadSha256,
      };
      this.rows.set(identity, row);
      return Promise.resolve({ ...row });
    }
    if (held.status === "acknowledged" && held.sha === j.payloadSha256) {
      return Promise.resolve({ ...held, outcome: "unchanged" as const });
    }
    if (status === "generated") {
      return Promise.resolve({ ...held, outcome: "existing" as const });
    }
    held.status = status;
    if (remote) held.remote_id = remote.id;
    return Promise.resolve({ ...held, outcome: "updated" as const });
  }
}

const jobOf = (doc: BexioDocument): DeliveryJob => ({
  connectionId: "c-bexio",
  documentKind: doc.kind,
  documentId: doc.id,
  eventDate: doc.date,
  documentNumber: doc.number,
  periodFrom: "2026-01-01",
  periodTo: "2026-12-31",
  payloadSha256: "b".repeat(64),
  needs: needsOf(doc),
});

async function deliverAll(
  docs: BexioDocument[],
  b: ReturnType<typeof bexio>,
  store: MemoryStore,
  with_ = maps,
) {
  const adapter = bexioAdapter(
    Object.fromEntries(docs.map((d) => [documentKey(d.kind, d.id), d])),
    {
      fetch: b.fetchImpl,
      config,
    },
  );
  const out = [];
  for (const d of docs) {
    out.push(await deliver(jobOf(d), with_, store, adapter));
  }
  return out;
}

Deno.test("one kb_invoice per document: its number, the mapped tax ids and accounts, issued", async () => {
  const b = bexio();
  const out = await deliverAll(
    [invoice("d1", "INV-101"), invoice("d2", "INV-102")],
    b,
    new MemoryStore(),
  );
  assertEquals(out.map((o) => o.status), ["acknowledged", "acknowledged"]);
  const held = b.docs.kb_invoice;
  assertEquals(held.map((d) => d.document_nr), ["INV-101", "INV-102"]);
  assertEquals(held.map((d) => d.api_reference), ["key-d1", "key-d2"]);
  const positions = held[0].positions as {
    tax_id: number;
    account_id: number;
    unit_price: string;
  }[];
  assertEquals(positions.map((p) => [p.tax_id, p.account_id, p.unit_price]), [
    [16, 340, "1000.00"],
    [17, 341, "50.00"],
  ]);
  assertEquals(held[0].contact_id, 501);
  assertEquals(held[0].user_id, 7);
  assertEquals(held[0].currency_id, 1);
  assertEquals([held[0].is_valid_from, held[0].is_valid_to], [
    "2026-03-02",
    "2026-04-01",
  ]);
  assertEquals(held.map((d) => d.kb_item_status_id), [8, 8]);
});

Deno.test("a second delivery creates nothing", async () => {
  const b = bexio();
  const store = new MemoryStore();
  const docs = [invoice("d1", "INV-101"), invoice("d2", "INV-102")];
  await deliverAll(docs, b, store);
  const calls = b.calls.length;
  const again = await deliverAll(docs, b, store);
  assertEquals(again.map((o) => o.status), ["unchanged", "unchanged"]);
  assertEquals(b.docs.kb_invoice.length, 2);
  assertEquals(b.calls.length, calls, "nothing is even asked of bexio");
});

Deno.test("an unmapped tax blocks before anything is sent, the key named", async () => {
  const b = bexio();
  const out = await deliverAll(
    [invoice("d1", "INV-101")],
    b,
    new MemoryStore(),
    maps.filter((m) => m.key !== tax26),
  );
  assertEquals(out[0], { status: "blocked", missing: [`tax ${tax26}`] });
  assertEquals(b.calls, []);
});

Deno.test("a create with no answer is read back by its number, never created twice", async () => {
  const b = bexio();
  const store = new MemoryStore();
  b.dropNextAnswer();
  const first = await deliverAll([invoice("d1", "INV-101")], b, store);
  assertEquals(first[0].status, "conflict");
  assertEquals(b.docs.kb_invoice.length, 1, "it landed");
  const second = await deliverAll([invoice("d1", "INV-101")], b, store);
  assertEquals(second[0].status, "acknowledged");
  assertEquals(b.docs.kb_invoice.length, 1, "read back, not created again");
});

Deno.test("a credit note is a kb_credit_voucher, not a kb_invoice", async () => {
  const b = bexio();
  const credit: BexioDocument = {
    ...invoice("c1", "CN-101"),
    kind: "credit_note",
    lines: [{
      label: "Desk",
      netMinor: -10000,
      taxKey: tax81,
      accountKey: "revenue:standard",
    }],
    totalMinor: 10810,
  };
  const out = await deliverAll([credit], b, new MemoryStore());
  assertEquals(out.map((o) => o.status), ["acknowledged"]);
  assertEquals(b.docs.kb_credit_voucher.map((d) => d.document_nr), ["CN-101"]);
  assertEquals(b.docs.kb_invoice, []);
  assertEquals(
    (b.docs.kb_credit_voucher[0].positions as { unit_price: string }[])[0]
      .unit_price,
    "100.00",
  );
});

Deno.test("a receipt is a payment on its invoice, found by its number", async () => {
  const b = bexio();
  const store = new MemoryStore();
  await deliverAll([invoice("d1", "INV-101")], b, store);
  const receipt: BexioDocument = {
    id: "d1",
    kind: "receipt",
    number: "INV-101",
    date: "2026-03-20",
    currency: "CHF",
    partyKey: member,
    title: "",
    lines: [],
    totalMinor: 113230,
  };
  const out = await deliverAll([receipt], b, store);
  assertEquals(out.map((o) => o.status), ["acknowledged"]);
  assertEquals(b.docs.kb_invoice.length, 1, "no second invoice");
  assertEquals(b.payments.map((p) => [p.invoice, p.date, p.value]), [[
    b.docs.kb_invoice[0].id,
    "2026-03-20",
    "1132.30",
  ]]);
});

// #2377 — two issuers (two workspaces, two bexio companies, two
// connections) whose local identifiers coincide: the same document id and
// number, the same member key, the same map keys. Through the delivery kit
// (`deliver`, with this file's store keyed by connection like the kit's own
// test; record_accounting_delivery itself is not executed here) each
// company receives its document once, on its own contact, tax and account
// ids, and neither issuer's acknowledgement stands for the other's.
Deno.test("separate issuers sharing local ids deliver independently, each on its own maps", async () => {
  const issuers = [
    {
      connection: "c-issuer-a",
      company: bexio(),
      contact: "501",
      tax81: "16",
      tax26: "17",
      acc: ["340", "341"],
    },
    {
      connection: "c-issuer-b",
      company: bexio(),
      contact: "902",
      tax81: "26",
      tax26: "27",
      acc: ["320", "321"],
    },
  ];
  const mapsOf = (i: (typeof issuers)[number]): AccountingMap[] => [
    { kind: "party", key: member, remoteId: i.contact, remoteCode: "" },
    { kind: "tax", key: tax81, remoteId: i.tax81, remoteCode: "UN81" },
    { kind: "tax", key: tax26, remoteId: i.tax26, remoteCode: "UR26" },
    {
      kind: "account",
      key: "revenue:standard",
      remoteId: i.acc[0],
      remoteCode: i.acc[0],
    },
    {
      kind: "account",
      key: "revenue:reduced",
      remoteId: i.acc[1],
      remoteCode: i.acc[1],
    },
  ];
  const doc = invoice("d1", "INV-101");
  const store = new MemoryStore();
  const run = async () => {
    const out = [];
    for (const i of issuers) {
      const adapter = bexioAdapter({ [documentKey(doc.kind, doc.id)]: doc }, {
        fetch: i.company.fetchImpl,
        config,
      });
      out.push(
        await deliver(
          { ...jobOf(doc), connectionId: i.connection },
          mapsOf(i),
          store,
          adapter,
        ),
      );
    }
    return out;
  };

  const first = await run();
  assertEquals(
    first.map((o) => o.status),
    ["acknowledged", "acknowledged"],
    "issuer B's identical local id is not taken for issuer A's delivery",
  );
  assertEquals(store.rows.size, 2, "one delivery row per connection");
  for (const i of issuers) {
    const held = i.company.docs.kb_invoice;
    assertEquals(
      held.map((d) => d.document_nr),
      ["INV-101"],
      `${i.connection} holds its invoice once`,
    );
    assertEquals(
      held[0].contact_id,
      Number(i.contact),
      `${i.connection}'s own contact`,
    );
    const positions = held[0].positions as {
      account_id: number;
      tax_id: number;
    }[];
    assertEquals(
      positions.map((p) => p.account_id),
      i.acc.map(Number),
      `${i.connection}'s own accounts`,
    );
    assertEquals(
      positions.map((p) => p.tax_id),
      [Number(i.tax81), Number(i.tax26)],
      `${i.connection}'s own tax ids`,
    );
  }

  const calls = issuers.map((i) => i.company.calls.length);
  const again = await run();
  assertEquals(again.map((o) => o.status), ["unchanged", "unchanged"]);
  assertEquals(
    issuers.map((i) => i.company.calls.length),
    calls,
    "nothing is asked of either company again",
  );
  assertEquals(issuers.map((i) => i.company.docs.kb_invoice.length), [1, 1]);
});
