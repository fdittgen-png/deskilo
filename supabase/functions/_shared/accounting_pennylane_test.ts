// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the Pennylane adapter: balanced ledger entries only, amounts as
// exact decimal strings, and a readback that knows an entry by its day and
// its sums, so an entry edited at Pennylane is never taken for ours. No
// request leaves the test.

import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { amount, journalEntryPayload, PayloadRefusal, pennylaneLedger } from "./accounting_pennylane.ts";
import type { Posting } from "./accounting_postings.ts";

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
