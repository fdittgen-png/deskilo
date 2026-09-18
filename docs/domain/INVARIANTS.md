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
| a booking replayed with the same client request id books once | `create_reservation_once` (0214) | `24_booking_idempotency.sql` |
| an issued invoice cannot be edited or deleted | trigger `invoices_no_mutation` (0060, revised 0061) | `20_money_invariants.sql` |
| a payment webhook delivered twice creates money once | `settle_online_payment`, `for update` + status guard (0205) | `20_money_invariants.sql`, `22_reconciliation.sql` |
| a webhook whose amount disagrees with the intent is refused | `settle_online_payment` (0205, #1138) | `22_reconciliation.sql` |
| a captured payment names the one credit it posted, and one credit settles one payment | `payment_intents.ledger_entry_id` + partial unique index + `payment_intents_ledger_matches` (0240, #1452) | `40_payment_ledger_association.sql` |
| workspace A never reads workspace B | 83 RLS policies | `10_tenancy_isolation.sql`, `11_tenancy_matrix.sql` |
| a financial row never points into another workspace (ledger, invoices, matches, payments, credits, reminders, transmissions, quota extensions, usage) | 22 composite foreign keys `(workspace_id, ref) → parent (workspace_id, id)` (0242, #1453), and 18 more on reservations, events, notes, badges, invitations, conversations, access log, negotiations, expenses, managed identities and booking requests (0243); `reconcile_workspace()` (0213) stays as defence in depth | `42_tenant_reference_integrity.sql`, `44_tenant_reference_people.sql`, `22_reconciliation.sql` |
| an unconfirmed delegated action cannot take effect: nothing moves until the configured quorum, a rejection moves nothing, a replayed decision applies nothing twice | `respond_to_event` quorum and status guard (0149), the `0181` apply trigger, no write policy on `events`/`event_decisions` | `43_event_validation_rules.sql` |
| a payment awaiting or refused validation posts no ledger credit | `respond_to_event` posts the credit only on confirmation | `43_event_validation_rules.sql` |
| nobody validates their own event; the owner alone may, and only where a rule says so | `respond_to_event` eligibility check (0086), `owner_may_self_validate` (0149), the reservation-deletion owner switch (0119, narrowed by 0121) | `43_event_validation_rules.sql` |
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

## What the populated upgrade proves, and what it cannot (#1338)

The replay from empty proves the migrations run; the restore drill
proves a current backup comes back whole. Neither said what the next
migrations do to an instance that already holds an archive — which is
how the paragraph above came to be written. Since #1338 the database job
installs a **supported populated baseline** (0226, the first schema that
writes its own marker), seeds `supabase/restore/archive_seed.sql` on it,
runs every later migration over it, and compares
(`scripts/populated_upgrade_check.sh`).

**Proven, on every run:**

- every signed field, stored hash, algorithm stamp, posting and payment
  relation of the archive is byte-equal before and after the upgrade;
- an invoice signed the modern way (`signature_algo` 7) reads `verified`
  after the upgrade, and a synthetic alteration behind the guard reads
  `altered`;
- a legacy invoice with no algorithm stamp reads `unverifiable` before
  AND after — no migration recomputed its hash to make it look better;
- the permitted transitions (void, settle) still work on the upgraded
  schema, and an edit or a delete still raises *"invoices are immutable"*;
- the 0240 association backfill associates a captured intent only when
  exactly one credit matches it and that credit matches nothing else; the
  ambiguous pair stays unassociated and `reconcile_workspace` names both;
- the comparison can fail: `supabase/restore/destructive_control.sql`
  "repairs" the legacy hash through the same apply path, and the check
  passes only when the snapshot diff names that invoice.

**Historical, and stays so:** the pilot's pre-0152 invoices. The check
prevents a recurrence; it cannot reconstruct evidence the backfills
already replaced, and it does not claim those invoices are anything but
`unverifiable`.

**Still unproved:** baselines other than 0226 (the baseline is a
parameter of the script, not a second script — add one when a supported
instance stands on another version), storage objects (a document's PDF
is not in the database), and an upgrade interrupted mid-way through the
populated schema (the lifecycle check proves the resume on an empty one).

## Event validation: what `43` proves, and what it does not

`43_event_validation_rules.sql` drives the real RPCs as `authenticated`
with seven distinct people (owner, acting admin, independent admin, the
member a change concerns, the member a payment credits, a member without
rights, the owner of another workspace) and asserts beforehand what each
of them actually holds. Its last section rewrites `respond_to_event`
inside the rolled-back transaction twice: once without the eligibility
refusal, once with the quorum forced to one. The admin then approves
their own request, and a single confirmation posts a credit. The earlier
refusals therefore come from those two lines and not from the fixture.

Executed there:

- a delegated membership change (`request_member_status_change`, applied
  by the `0181` trigger) and a recorded payment (`record_payment`, credit
  posted by `respond_to_event`) under rules requiring two accepts;
- refusal of the actor, the member concerned, a member without rights and
  a caller from another workspace; one validator cannot count twice; a
  settled event refuses every later decision;
- writing `events.status` or an `event_decisions` row directly as
  `authenticated` changes nothing;
- `owner_may_self_validate`: refused by default, allowed for the owner
  when set, still refused for an admin;
- the reservation-deletion owner switch settles the owner's own deletion
  as a system decision and leaves an admin's pending.

Still not executed in SQL, so not claimed:

- a payment recorded by an admin for a member is confirmed by that
  member **and** the quorum. The member's own accept counts towards it.
  That is the product rule, not an exception to self-validation, since
  the member did not record the payment;
- the expiry sweep (`sweep_pending_events`), `sequential` staging, and the
  `listed` and `members` validator scopes;
- the other apply paths: the remaining `0181` types, the expense,
  negotiation, usage, stock and payment-terms triggers, and the money RPCs
  that write their own event (`match_invoice`, `settle_credit_invoice`,
  `settle_invoices`, `distribute_expense`). They share the eligibility and
  quorum code proved here, but their effects are not asserted one by one;
- the reservation-deletion admin switch (`auto_validate_admin`) set on
  its own.
