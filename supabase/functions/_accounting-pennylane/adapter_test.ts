// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the Pennylane adapter against an in-memory Pennylane: one
// customer invoice per document with its legal number and its PDF, none
// on a second delivery, balanced ledger entries only, HTTP refusals as
// typed failures, amounts as exact decimal strings. No request leaves
// the test.

import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  amount,
  deliver,
  journalEntryPayload,
  PayloadRefusal,
  PennylaneDocument,
  requiredFields,
} from "./adapter.ts";

const config = {
  base_url: "https://pl.test/api/external/v2",
  access_token: "t",
};

/** A Pennylane that keeps what it is sent. */
function pennylane(failWith?: (path: string, method: string) => number | null) {
  const invoices: Record<string, unknown>[] = [];
  const customers: Record<string, unknown>[] = [];
  const attachments: string[] = [];
  const calls: string[] = [];
  let next = 100;
  const answer = (input: RequestInfo | URL, init?: RequestInit): Response => {
    const url = new URL(String(input));
    const method = init?.method ?? "GET";
    const path = url.pathname.replace("/api/external/v2/", "");
    calls.push(`${method} ${path}`);
    const status = failWith?.(path, method);
    if (status) {
      return new Response(JSON.stringify({ message: "nope" }), { status });
    }
    const filter = url.searchParams.get("filter");
    const wanted = filter ? JSON.parse(filter)[0].value : null;
    const json = (body: unknown) => new Response(JSON.stringify(body));
    if (method === "GET" && path === "customer_invoices") {
      return json({
        items: invoices.filter((i) => i.external_reference === wanted),
      });
    }
    if (method === "GET" && path === "customers") {
      return json({
        items: customers.filter((c) => c.external_reference === wanted),
      });
    }
    if (method === "POST" && path === "company_customers") {
      const c = { id: next++, ...JSON.parse(String(init!.body)) };
      customers.push(c);
      return json(c);
    }
    if (method === "POST" && path === "file_attachments") {
      const file = (init!.body as FormData).get("file") as File;
      attachments.push(file.name);
      return json({ id: next++ });
    }
    if (method === "POST" && path === "customer_invoices/import") {
      const i = { id: next++, ...JSON.parse(String(init!.body)) };
      invoices.push(i);
      return json(i);
    }
    return new Response("not found", { status: 404 });
  };
  const fetchImpl = (input: RequestInfo | URL, init?: RequestInit) =>
    Promise.resolve(answer(input, init));
  return {
    fetchImpl: fetchImpl as typeof fetch,
    invoices,
    customers,
    attachments,
    calls,
  };
}

const doc = (id: string, number: string): PennylaneDocument => ({
  id,
  number,
  kind: "invoice",
  issueDate: "2026-03-05",
  dueDate: "2026-04-04",
  currency: "EUR",
  customer: { number: "M-0001", name: "Ana Lopez", legalId: "123456789" },
  lines: [
    { label: "Desk", netMinor: 10000, vatMinor: 2000, vatRate: "20" },
    { label: "Coffee", netMinor: 10000, vatMinor: 550, vatRate: "5.5" },
  ],
  totalMinor: 22550,
  pdf: { fileName: `${number}.pdf`, bytes: new Uint8Array([37, 80, 68, 70]) },
});

Deno.test("one customer invoice per document, with its legal number and PDF", async () => {
  const pl = pennylane();
  const out = await deliver([doc("d1", "INV-1"), doc("d2", "INV-2")], {
    fetch: pl.fetchImpl,
    config,
  });
  assertEquals(out.map((d) => d.status), ["created", "created"]);
  assertEquals(pl.invoices.length, 2);
  assertEquals(pl.invoices.map((i) => i.invoice_number), ["INV-1", "INV-2"]);
  assertEquals(pl.invoices.map((i) => i.external_reference), ["d1", "d2"]);
  assertEquals(pl.attachments, ["INV-1.pdf", "INV-2.pdf"]);
  // The attachment id the upload answered is the one the invoice cites.
  assertEquals(typeof pl.invoices[0].file_attachment_id, "number");
  assertEquals(pl.invoices[0].currency_amount, "225.50");
  assertEquals(
    (pl.invoices[0].invoice_lines as { vat_rate: string }[]).map((l) =>
      l.vat_rate
    ),
    ["FR_200", "FR_55"],
  );
  // The customer is created once and read back the second time.
  assertEquals(pl.customers.length, 1);
});

Deno.test("a second delivery creates none", async () => {
  const pl = pennylane();
  const docs = [doc("d1", "INV-1"), doc("d2", "INV-2")];
  await deliver(docs, { fetch: pl.fetchImpl, config });
  const again = await deliver(docs, { fetch: pl.fetchImpl, config });
  assertEquals(again.map((d) => d.status), ["exists", "exists"]);
  assertEquals(pl.invoices.length, 2);
  assertEquals(pl.attachments.length, 2);
});

Deno.test("a payment's entry balances; an unbalanced one is refused", () => {
  const entry = {
    id: "p1",
    date: "2026-03-20",
    journalCode: "BQ",
    label: "Encaissement INV-1",
    documentReference: "INV-1",
    currency: "EUR",
    lines: [
      { account: "512000", debitMinor: 15550, creditMinor: 0 },
      { account: "411000", debitMinor: 0, creditMinor: 15550 },
    ],
  };
  const body = journalEntryPayload(entry, { "512000": 1, "411000": 2 }, 9);
  assertEquals(
    body.ledger_entry_lines,
    [
      {
        ledger_account_id: 1,
        label: "Encaissement INV-1",
        debit: "155.50",
        credit: "0.00",
      },
      {
        ledger_account_id: 2,
        label: "Encaissement INV-1",
        debit: "0.00",
        credit: "155.50",
      },
    ],
  );
  const unbalanced = {
    ...entry,
    lines: [entry.lines[0], { ...entry.lines[1], creditMinor: 15549 }],
  };
  const e = assertThrows(
    () => journalEntryPayload(unbalanced, { "512000": 1, "411000": 2 }, 9),
    PayloadRefusal,
  );
  assertEquals(e.failure.reason, "unbalanced");
});

Deno.test("HTTP refusals are typed failures, never thrown", async () => {
  for (
    const [status, reason] of [
      [401, "reauth_needed"],
      [422, "rejected"],
      [429, "retry_later"],
    ] as const
  ) {
    const pl = pennylane((path, method) =>
      method === "POST" && path === "customer_invoices/import" ? status : null
    );
    const [out] = await deliver([doc("d1", "INV-1")], {
      fetch: pl.fetchImpl,
      config,
    });
    assertEquals(out.status, "failed");
    assertEquals(out.error?.reason, reason);
  }
  const pl = pennylane((path, method) =>
    method === "POST" && path === "customer_invoices/import" ? 422 : null
  );
  const [out] = await deliver([doc("d1", "INV-1")], {
    fetch: pl.fetchImpl,
    config,
  });
  assertEquals(out.error?.detail, "422 nope");
  const down =
    (() =>
      Promise.reject(new TypeError("network down"))) as unknown as typeof fetch;
  const [lost] = await deliver([doc("d1", "INV-1")], { fetch: down, config });
  assertEquals(lost.error?.reason, "unreachable");
  const [noToken] = await deliver([doc("d1", "INV-1")], {
    fetch: down,
    config: { base_url: config.base_url },
  });
  assertEquals(noToken.error?.reason, "reauth_needed");
  assertEquals([...requiredFields], ["base_url", "access_token"]);
});

Deno.test("amounts are exact decimal strings from minor units", () => {
  assertEquals(amount(1999, "EUR"), "19.99");
  assertEquals(amount(-5000, "EUR"), "-50.00");
  assertEquals(amount(5, "EUR"), "0.05");
  assertEquals(amount(1000, "JPY"), "1000");
  assertEquals(amount(12345, "KWD"), "12.345");
  assertThrows(() => amount(100, "XYZ"), PayloadRefusal);
});

Deno.test("a rate Pennylane has no code for is refused for that document", async () => {
  const pl = pennylane();
  const odd = doc("d9", "INV-9");
  odd.lines = [{ label: "x", netMinor: 100, vatMinor: 7, vatRate: "7" }];
  odd.totalMinor = 107;
  const [out] = await deliver([odd], { fetch: pl.fetchImpl, config });
  assertEquals(out.error?.reason, "unsupported");
  assertEquals(pl.invoices.length, 0);
});
