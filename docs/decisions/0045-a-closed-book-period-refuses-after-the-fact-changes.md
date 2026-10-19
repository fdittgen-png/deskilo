# ADR 0045 — A closed book period refuses after-the-fact changes

**Status:** accepted · **Date:** 2026-10-19 · **Refs:** #2365, ADR 0039, ADR 0022

## Context
ADR 0039 locks a *filed VAT return*: its figures never move, and a later change
becomes a correction in the next return. The books handed to an accountant need
the same stability for whatever period they cover, whether or not a VAT return
was filed, and the accountant needs to know which file was handed over when.

## Decision
1. **A period is a closed date range of the space** (`book_periods`): closed by
   an owner, or automatically when a VAT return of that range is filed
   (`reason = vat_filed`). Two closed ranges never overlap. Reopening is the
   owner's, needs a reason, and keeps the row (`reopened_at`, `reopen_reason`):
   history is never deleted.
2. **What it refuses** (database triggers, so every path is covered): voiding an
   invoice issued inside it, and inserting or changing a payment match (or its
   write-off) dated inside it. The wording names the remedy: a credit note in
   the open period. Day = the workspace-local day.
3. **A period that has not ended cannot be closed.**
4. **The guards hold regardless of the flag.** `accountingPeriods` (platform,
   off, under `accountingBook`) gates closing, reopening, the log and the
   automatic close; a period that was closed stays closed if the flag is
   switched off.
5. **The export log** (`book_exports`) records format, period, sha256, bytes,
   rows, documents, who and when, and whether every day of the period was
   closed when the file was made. The client logs after the file is handed
   over; a failed log is traced and never fails the export (the file is already
   the accountant's). A closed period exported twice shows one sha256.
6. **Not in this decision:** the posting engine that makes the bytes identical
   (#2365's `compute_postings`), the accountant role, and per-format layouts.
   They read the closed state through `book_period_closed`.

## Consequences
- A late payment of an invoice of a closed year is matched today, in the open
  period; it does not rewrite the closed one.
- An invoice of a closed period is corrected by a credit note, not a void.
