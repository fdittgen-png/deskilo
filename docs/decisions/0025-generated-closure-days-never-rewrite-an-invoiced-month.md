# ADR 0025 — Generated closure days never rewrite an invoiced month

**Status:** accepted · **Date:** 2026-09-16

## Context

#1274 generates a year's public holidays as closure days. The
association's entitlement table is `weekdays(month) − public holidays`,
and the app already computes exactly that from `closure_days`.

A closure day is not a label. `assert_member_quota` and `member_statement`
subtract it from the month's open weekdays, so adding one to a past month
changes `open_days`, therefore `included_half_days`, therefore that
member's overage, therefore their bill. A bill that was already issued.

Measured on the development project: generating FR 2026 into a workspace
that had invoiced July and August would have touched both months, because
14 July and 15 August are holidays. This is not a hypothetical.

## Decision

**A month that already carries an invoice row is skipped, and named.**

- Enforced in `generate_closure_days`, a `SECURITY DEFINER` RPC — not in
  the client, because it is a rule and not a hint (ADR 0020).
- "Already carries an invoice" means **any** invoice row for that
  workspace and period. `invoices` has no status column; voided rows
  count, because they were issued.
- The refused months are returned as `locked_months` and shown before the
  owner confirms. Skipping silently would be the same defect wearing a
  different face.
- Preview and apply are **one function** with an `p_apply` flag, so the
  list an owner confirms is the list that gets written.

The alternative — refusing the whole year when any month is invoiced —
was rejected: a workspace that has ever invoiced could then never
generate holidays at all, which would leave the entitlement table wrong
for the months that are still open.

## Consequences

- An owner can generate 2026 in July and get nine days rather than
  eleven, with July and August named on screen.
- Correcting an invoiced month stays a deliberate act: add the closure
  day by hand, and deal with the invoice.
- `closure_days` is a **deployable entity** (`deployable_entities()`), and
  a mirror import replaces the target's rows. Generated holidays travel
  and can be replaced by a deployment like any other configuration; that
  is existing behaviour of that entity, not something this decision
  changes, but it is worth knowing before generating into a workspace
  that is a deployment target.
- The generator itself is SQL (`public_holidays(country, year)`) so that
  `apply_workspace_template` can use it. A second implementation in Dart
  would be a second source of truth, and the two would disagree about an
  Easter eventually.
