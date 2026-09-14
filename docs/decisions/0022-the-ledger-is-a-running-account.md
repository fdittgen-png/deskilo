# ADR 0022 — The ledger is a running account, and it is append-only

**Status:** accepted · **Date:** 2026-09-14

## Context

An external review of the project proposed `Σ debits = Σ credits` as
*the* financial invariant to make executable (#1229, under the #1225 A+
programme). It is the right invariant for a double-entry ledger. This is
not one, and the review could not have known that from the outside.

`public.ledger_entries` (0008) is:

```sql
kind         text check (kind in ('charge','credit'))
category     text check (category in ('subscription','overage','expense',
                                      'payment','adjustment','service','package'))
amount_cents int  check (amount_cents > 0)
period       text check (period ~ '^[0-9]{4}-[0-9]{2}$')
```

One row per movement. There is no paired entry, no journal or
transaction grouping column, and no link from a charge to the credit
that offsets it. A member's balance is the signed sum of their rows —
which is what a coworking statement is, and what
`member_statement(period)` computes.

So `Σ debits = Σ credits` is not merely unproven here; there is nothing
for the two sides to be sums *of*. Writing it would require a schema
that pairs every movement, which would mean rebuilding the statement,
the invoice matcher, the expense repartition and ten aggregations to
carry a bookkeeping formalism the workspace does not use.

Two facts about the ledger *were* defects, independent of the shape:

- **Seven functions insert into it** — `respond_to_event`,
  `match_invoice`, `buy_package`, `settle_online_payment`,
  `settle_credit_invoice`, `confirm_expense_occurrence`,
  `apply_expense_repartition`.
- **Two delete from it** — `release_invoice_payment` and
  `reset_workspace`.

The client could never write it: there is only a `ledger_select` policy,
so RLS refuses every client INSERT, UPDATE and DELETE. What was
unguarded is the server rewriting its own history.

## Decision

**1. The invariant is the one this ledger can carry:**

> A posted amount never changes, and a row leaves only by the one route
> that was always meant to remove it.

**2. It is enforced by a trigger on the table, not by a funnel
function.** #1229 suggested routing the seven writers through one
`post_ledger_entry(...)`. A funnel is a convention: the eighth writer is
one `insert into public.ledger_entries` away from bypassing it, and
nothing fails when they do. `ledger_entries_no_rewrite` (0212) cannot be
bypassed from inside the database. The invariant belongs to the table,
the way `invoices_no_mutation` belongs to `invoices`.

**3. The one deletion that stays is narrow and self-identifying.** A
payment match awaiting validation books a **provisional** credit;
rejecting or expiring the request takes it back. Such a credit is
recognisable while it is provisional — `invoice_matches` or
`invoice_match_payments` still points at it — and stops being deletable
the moment the match is gone. So the rule is not "nothing may be
deleted"; it is "only a provisional payment credit, and only while it is
provisional".

**4. `reset_workspace` announces itself.** The development affordance
that empties a workspace sets a transaction-local setting carrying the
table's own oid, so the exception cannot be left switched on and cannot
be aimed at another table.

## Consequences

- A correction is a new row, never an edit. That is the accounting
  practice anyway, and now the database agrees.
- A future function that deletes a settled credit fails at the table,
  loudly, with a message that says what to do instead.
- `supabase/tests/database/21_ledger_append_only.sql` executes all six
  cases — edit refused, reword refused, charge undeletable, settled
  credit undeletable, provisional credit released, reset still works.
- Reconciliation (#1230) becomes worth building: an append-only ledger
  is the thing a reconciliation engine can reconcile *against*.
- If double-entry is ever wanted, it is a new table beside this one with
  a migration that projects history into it — not a change to this one.
  See [ADR 0006](0006-quota-overage-billing.md) for why the running
  account was chosen in the first place.
