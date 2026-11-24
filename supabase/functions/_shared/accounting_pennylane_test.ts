// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the Pennylane adapter: balanced ledger entries only, amounts as
// exact decimal strings, and a readback that knows an entry by its day and
// its sums, so an entry edited at Pennylane is never taken for ours. No
// request leaves the test.

import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { amount, journalEntryPayload, PayloadRefusal, pennylaneLedger } from "./accounting_pennylane.ts";
import { journalCodesOf, type Posting } from "./accounting_postings.ts";
import { asFetch } from "./testing/as_fetch.ts";

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

Deno.test("amounts are exact decimal strings from minor units", () => {
  assertEquals(amount(1999, "EUR"), "19.99");
  assertEquals(amount(-5000, "EUR"), "-50.00");
  assertEquals(amount(5, "EUR"), "0.05");
  assertEquals(amount(1000, "JPY"), "1000");
  assertEquals(amount(12345, "KWD"), "12.345");
  assertThrows(() => amount(100, "XYZ"), PayloadRefusal);
});

const posting: Posting = {
  journal: "bank",
  kind: "receipt",
  date: "2026-03-20",
  documentId: "d-1",
  documentNumber: "INV-1",
  currency: "EUR",
  lines: [
    { role: "bank", qualifier: null, debitCents: 15550, creditCents: 0 },
    { role: "customers", qualifier: null, debitCents: 0, creditCents: 15550 },
  ],
};

Deno.test("a readback knows an entry by its day and its sums", async () => {
  const held = (debit: string, date = "2026-03-20") => ({
    id: 7,
    date,
    ledger_entry_lines: [{ debit, credit: "0.00" }, { debit: "0.00", credit: debit }],
  });
  for (const [items, matches] of [
    [[held("155.50")], true],
    [[held("150.00")], false],
    [[held("155.50", "2026-03-21")], false],
    [[{ id: 7, date: "2026-03-20" }], false],
  ] as const) {
    const adapter = pennylaneLedger({
      fetch: (() => Promise.resolve(Response.json({ items }))) as unknown as typeof fetch,
      secrets: { access_token: "t" },
      tenant: "",
      targetId: "pennylane_api",
      env: () => undefined,
    });
    const found = await adapter.remote(posting, undefined, []).readback("k", {} as never);
    assertEquals(typeof found !== "string" && found[0].matches, matches);
  }
});

// ── the company the token reaches ──────────────────────────────────────────

const asked = (company: unknown, status = 200) =>
  ((url: string | URL | Request) =>
    Promise.resolve(
      String(url).endsWith("/me")
        ? new Response(JSON.stringify({ company }), { status })
        : Response.json({ items: [], has_more: false }),
    )) as typeof fetch;

const adapterFor = (tenant: string, company: unknown, status = 200) =>
  pennylaneLedger({
    fetch: asked(company, status),
    secrets: { access_token: "t" },
    tenant,
    targetId: "pennylane_api",
    env: () => undefined,
  });

Deno.test("the token's own company is read from /me", async () => {
  assertEquals(await adapterFor("", { id: 42 }).signedInTenant!(), { tenant: "42" });
  assertEquals("refused" in (await adapterFor("", {}).signedInTenant!()), true);
  assertEquals("refused" in (await adapterFor("", { id: 1 }, 401).signedInTenant!()), true);
});

Deno.test("a delivery is refused when the token reaches another company than the one named", async () => {
  assertEquals(await adapterFor("42", { id: 42 }).prepare(), null);
  assertEquals(await adapterFor("", { id: 42 }).prepare(), null);
  const refused = await adapterFor("41", { id: 42 }).prepare();
  assertEquals(typeof refused, "string");
});

// ── #4003: the business's own journals ─────────────────────────────────────

const journalAdapter = (journals: Record<string, string> | undefined, codes: [number, string][], sent: Record<string, unknown>[]) =>
  pennylaneLedger({
    fetch: asFetch((input: string | URL | Request, init?: RequestInit) => {
      const path = new URL(String(input)).pathname.replace(/^.*\/v2\//, "");
      if (path === "journals") {
        return Response.json({ items: codes.map(([id, code]) => ({ id, code })), has_more: false });
      }
      if (path === "ledger_entries" && init?.method === "POST") {
        const body = JSON.parse(String(init.body));
        sent.push(body);
        return Response.json({ ...body, id: 900 }, { status: 201 });
      }
      return Response.json({ items: [] });
    }),
    secrets: { access_token: "t" },
    tenant: "",
    targetId: "pennylane_api",
    env: () => undefined,
    journals,
  });

const bankMaps = [
  { kind: "account" as const, key: "bank", remoteId: "11", remoteCode: "" },
  { kind: "account" as const, key: "customers", remoteId: "12", remoteCode: "" },
];

const ownCodes = { sales: "VT", bank: "BNP", purchases: "ACH", other: "DIV" };

Deno.test("a delivery goes to the business's journal when it set one", async () => {
  const sent: Record<string, unknown>[] = [];
  const adapter = journalAdapter(ownCodes, [[1, "VE"], [2, "BQ"], [5, "VT"], [6, "BNP"]], sent);
  assertEquals(await adapter.prepare(), null);
  const created = await adapter.remote(posting, undefined, bankMaps).create("k-1", {} as never, bankMaps);
  assertEquals(created.ok, true);
  assertEquals(sent[0].journal_id, 6);
});

Deno.test("with no journals set the standard code is used; a code the company lacks is refused by name", async () => {
  const sent: Record<string, unknown>[] = [];
  const standard = journalAdapter(undefined, [[1, "VE"], [2, "BQ"], [6, "BNP"]], sent);
  await standard.prepare();
  assertEquals((await standard.remote(posting, undefined, bankMaps).create("k-1", {} as never, bankMaps)).ok, true);
  assertEquals(sent[0].journal_id, 2);
  const own = journalAdapter(ownCodes, [[1, "VE"], [2, "BQ"]], sent);
  await own.prepare();
  const refused = await own.remote(posting, undefined, bankMaps).create("k-2", {} as never, bankMaps);
  assertEquals(refused.ok, false);
  assertEquals(sent.length, 1);
  assertEquals(!refused.ok && refused.detail.includes("BNP"), true);
});

Deno.test("the stored journals are read whole or not at all, and an empty code is never taken", () => {
  const entry = (code: string) => ({ code, label: "L" });
  const stored = { sales: entry("VT"), bank: entry("BNP"), purchases: entry("ACH"), misc: entry("DIV") };
  assertEquals(journalCodesOf(stored), ownCodes);
  assertEquals(journalCodesOf({}), undefined);
  assertEquals(journalCodesOf(null), undefined);
  assertEquals(journalCodesOf({ ...stored, bank: undefined }), undefined);
  assertEquals(journalCodesOf({ ...stored, bank: entry(" ") }), undefined);
  assertEquals(journalCodesOf({ ...stored, misc: { code: "DIV" } }), undefined);
});
