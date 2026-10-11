# ADR 0039 — A filed VAT period is locked; later changes are corrections of the next return

**Status:** accepted · **Date:** 2026-10-11 · **Issue:** #2357 · **Extends:** migration 0402 (the server computes the VAT return)

## Context
Since 0402 the server computes a VAT return and a filed return never
changes. But the figures of a filed period can still move afterwards: an
invoice of that period is voided, a payment is recorded late with an
earlier date, a settlement's allocation changes. Recomputing the filed
period then gives other numbers than the ones the tax authority holds,
and no later return declared the difference. Every country the app serves
handles this the same way in substance: the filed return is not reopened,
the difference is declared in a later return — France as régularisations
(CA3 lines 15 and 21), Germany in the period of the change (§ 17 UStG),
the United Kingdom as an error correction on the next return.

## Options
1. **Derive from the aggregates.** A filed return stores lines per rate
   and category; the correction is "recompute the filed period, minus its
   stored lines, minus the corrections later returns already carried". No
   new table — but the stored lines cannot say which documents moved (the
   count printed beside a correction is unknowable), returns filed by an
   older client store figures the server never computed (every one of
   them would produce a spurious correction), and two filed returns that
   overlap cannot be told apart.
2. **A ledger of what each filing declared.** The filing records its
   amounts per document, tax point, rate and category. A correction is
   "what the filed period's tax points amount to now, minus every amount a
   filing declared for them" — per document, exact, auditable.

## Decision
Option 2.

1. `vat_return_entries` (0403): written once, by
   `mark_vat_declaration_submitted`, under the filing's writer token;
   never updated, never deleted except by the cascade of its return or
   workspace (a trigger refuses the rest). Readable by whoever reads the
   finances, like the declarations.
2. **The lock is the filed declaration's own period** — no separate lock
   table: `vat_declarations` with `status = 'filed'` already names the
   range and the filing time (`submitted_at`).
3. `vat_return_lines` (the SQL twin of `vatReturnAmountsOf` in
   `lib/features/money/domain/vat_period_lock.dart`): the return of a
   period is its own tax points that no filed return of ANOTHER period
   covers, plus, for every filed period that ended before it, one
   correction amount per (document, tax point, rate, category) where the
   current figure differs from what was declared. The correction keeps its
   original tax point and names the return it corrects (the earliest-filed
   one covering that day).
4. **Corrections land in the next return prepared after the filed
   period, whichever it is.** Two unfiled later periods both show them;
   the first one filed records them, and the other is then stale — the
   0402 check ("the period changed since this return was prepared")
   forces it to be prepared again without the correction.
5. A period that overlaps a filed one is refused at preparation and at
   filing; the exact filed period is refused as "already filed".
6. The declaration stores corrections as lines of their own
   (`correction: true`, `corrects`, `corrects_start`, `corrects_end`);
   the totals include them, so the period's net payable is right. The
   form mapping sends them to CA3 lines 15 (VAT due back) and 21 (VAT to
   deduct) in France and folds them into the rate boxes elsewhere.
7. **Returns filed before 0403** are locked with the ledger as it stood
   when the migration ran. What changed between their filing and that day
   cannot be attributed any more and is not corrected. That is the honest
   limit of a backfill; it is said here rather than guessed.
8. **No feature flag.** A lock is the correctness of an existing
   functionality (`vatDeclarations`), not a new one: a switch that let a
   filed period silently drift would be a switch to file wrong returns.

The filing period (month, quarter, annual) is a stored parameter of the
legal identity (`invoice_legal.vat_declaration_period`), so the
declarations screen offers periods of one length only and the overlap
refusal stays the exception, not the routine.

## Consequences
- `compute_vat_return` gained `correction` and `corrects` columns (its
  return type changed; it is dropped and recreated).
- The Dart engine applies the same rule; `vat_return_parity_test.dart`
  and pgTAP `168_vat_period_locks.sql` pin one fixture: a void after
  filing September is a −59.50 correction in October, the September row
  stays byte-identical, and November corrects nothing again.
- Input VAT (expenses) will join the same ledger as a second document
  source; per-country form mappings as data remain to be done.
