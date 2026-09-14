<!-- SPDX-License-Identifier: 0BSD -->
# The business invariants, and where each one is executed

#1248 asked for the invariants to be written down and executed rather
than believed. This is the list, and every row says which file runs it.
A row without a test file is a claim; this document exists so that is
visible rather than implicit.

| invariant | enforced by | executed by |
|---|---|---|
| a seat cannot hold two overlapping reservations | `exclude using gist` on `reservations` (0005) | `23_domain_invariants.sql` |
| a check-in is your own booking, inside its window | `check_in_reservation` | `23_domain_invariants.sql` |
| an issued invoice cannot be edited or deleted | trigger `invoices_no_mutation` (0060, revised 0061) | `20_money_invariants.sql` |
| a payment webhook delivered twice creates money once | `settle_online_payment`, `for update` + status guard (0205) | `20_money_invariants.sql`, `22_reconciliation.sql` |
| a webhook whose amount disagrees with the intent is refused | `settle_online_payment` (0205, #1138) | `22_reconciliation.sql` |
| workspace A never reads workspace B | 83 RLS policies | `10_tenancy_isolation.sql`, `11_tenancy_matrix.sql` |
| the server never *writes* a row across the tenancy line | nothing — it is checked after the fact | `reconcile_workspace()` (0213), `22_reconciliation.sql` |
| a posted ledger amount never changes | trigger `ledger_entries_no_rewrite` (0212) | `21_ledger_append_only.sql` |
| a ledger row leaves only as a provisional payment credit | same trigger | `21_ledger_append_only.sql` |
| every table with a `workspace_id` is isolated | its RLS policy | `11_tenancy_matrix.sql`, generated from the catalogue |
| no definer function is callable by `anon` | the `revoke execute` at the end of every migration | `00_schema_guarantees.sql` |
| every definer function pins its `search_path` | the `set search_path` clause | `00_schema_guarantees.sql` |

## Invoice immutability is a state machine, not a wall

`invoices_immutable()` raises unconditionally at the end, and three
branches return before it. Written out, the permitted transitions are:

```
issued ──── voided_at: null → now()          (+ voided_by_name) ──▶ voided
   │        every other column unchanged
   │
   ├─────── settled_by_invoice_id: null → id ──▶ settled by another invoice
   │        every other column unchanged
   │
   └─────── settled_by_invoice_id: id → null ──▶ that settlement undone
            every other column unchanged
```

Everything else — a total, a line, a name, a date, a DELETE — raises
*"invoices are immutable"*. The comparison ignores the six system
columns (#992), so a touch trigger moving `modified_datetime` is not a
mutation.

The set has been revised at least three times (`0060`, `0061`, and
"immutability v3 / two more transitions" at
`0144_money_validation_parity.sql:107`). It is written here so the fourth
revision is a diff against a stated set rather than a new branch in a
trigger nobody reads.

## Signatures issued before 0152 are permanently unverifiable

`verify_invoice_signature` (0174) recomputes the SHA-256 over the
document's own fields and compares. When it disagrees it returns
**`unverifiable`** rather than `altered` if `signature_algo` is null —
and that is honest rather than lenient.

Migrations up to 0152 rewrote signed columns of rows that had already
been signed: the signature covers `parties`, `vat_totals` and `details`,
and those were backfilled. The stored hash therefore cannot match, and no
amount of recomputation will tell you whether the difference was the
backfill or somebody's edit.

So: **every invoice issued on the pilot before 2026-09-04 returns
`unverifiable`, permanently.** That is not a bug to fix — recomputing the
signatures would destroy the only evidence that they were ever different
— and an auditor will ask. `signature_algo` has been stamped since 0152,
so every invoice issued after it answers `verified` or `altered`.

## What is still only prose

- **an unconfirmed delegated action cannot take effect** — enforced in
  `respond_to_event` and the `0017` system-decision idiom, covered by
  Dart-fake tests. The SQL path needs a workspace whose validation
  policies put the event in `pending`, which the fixtures here do not yet
  build.
- **nobody validates their own event** — `0086`, with the owner exception
  added in `0119`. Same gap, same reason.

Both are listed on #1248 and neither is claimed above.
