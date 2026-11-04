# Demo finance, accounting and VAT audit — #3292

Run 2026-11-04 on master `ab52b8933` plus this change, in the in-memory Demo (`lib/core/demo`). Each row is pinned by
a focused test that recomputes its expectation from the seeded source records, at four Demo dates: the Demo's own clock
(2026-05-13 10:00), the last half hour of a quarter (2026-03-31 23:30), the first half hour of the next
(2026-04-01 00:30) and a new year (2027-01-01 10:00). Spaces: Pézenas (`ws-1`, Atelier du Marché, France, VAT on
receipts) and Leipzig (`ws-2`, Kontorhaus Plagwitz, Germany, exempt). London and New York share the reminder seed code
only (the guard below applies to them too); their own money is pinned by `demo_city_consistency_test` and
`demo_city_currency_test`.

| Flow | Space | Source | Expected | Observed | Test | Status |
|---|---|---|---|---|---|---|
| Invoice in its space, currency, to a member, unique number | both | `money.invoices`, the space's members | every invoice | every invoice | `demo_finance_audit_test` | PASS |
| Invoice total = sum of lines; VAT breakdown net + VAT = total | both | invoice lines, `vatTotals` | equal | equal | `demo_finance_audit_test` | PASS |
| Payment matched to an invoice of the space, never more than asked (refund aside) | both | `invoiceMatchesStore` | ≤ total, ≥ 0 | as expected | `demo_finance_audit_test` | PASS |
| Reminder after the due day, before the settling payment, never in the future | both | `invoiceReminders`, due days, matches | dated in the past | **future-dated reminders at 2026-04-01 and 2027-01-01** (F-2026-0302, F-2026-1202) | `demo_finance_audit_test`, `demo_year_test` | FIXED |
| Account ledger: the space's own members, credits are not subscriptions | both | `money.ledger` | as stated | as stated | `demo_finance_audit_test` | PASS |
| Correction: a replacement replaces a voided invoice; a credit note credits a valid invoice by no more than it asked, with no charge line | both | `replacesInvoiceId`, totals | as stated | as stated | `demo_finance_audit_test` | PASS |
| Shared expense: shares add up to the expense, to the space's members | both | `money.repartitions` | equal | equal | `demo_finance_audit_test` | PASS |
| VAT return: periods and dates in the past; totals = lines; net + VAT = gross | both | `vatDeclarations` | as stated | as stated | `demo_finance_audit_test` | PASS |
| French VAT returns on receipts: the seeded filed and prepared returns equal a fresh preparation; filed amounts retained; filing clock follows the Demo | Pézenas | tax-point ledger (receipts), `vatDeclared` | equal | equal (after the prepared change) | `demo_vat_consistency_test` | FIXED (the prepared local change, kept) |
| Leipzig exempt: no VAT on any invoice line, no VAT return | Leipzig | invoices, `vatRegime` | 0 % everywhere, none filed | as expected | `demo_finance_audit_test` | PASS |
| Books: every posting of the last twelve months balances; every issued, non-voided sale is posted; no blocker | Pézenas | `postingsOf` over the Demo's money and bills | balanced, complete | **every posting blocked: the main book had no chart of accounts** | `demo_finance_audit_test` | FIXED (PCG chart seeded) |
| Isolation: no invoice, match or ledger entry shared between the spaces | both | the two money repositories | none shared | none shared | `demo_finance_audit_test` | PASS |

Not covered here, and why: purchases, assets and leases are pinned by the existing purchase, supplier-balance and
`demo_year_test` purchase-side tests and were not re-audited row by row; the VAT figures are the application's
tax-point rules (`vatTaxPointLedger`), not a review of French or German tax law (non-goal). Live tax filing and
server-only enforcement are outside the Demo.
