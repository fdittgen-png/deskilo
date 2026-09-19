<!-- SPDX-License-Identifier: 0BSD -->
# Bringing one workspace to its reported configuration

#1285 (T13 of #1271). **A checklist, not a script.** This is customer
data: one association's real members, bookings and invoices. Nothing here
runs itself, every step says what it changes and how to see that it
worked, and the whole thing stops on the first surprise.

It is deliberately separate from every product issue: one-off customer
cleanup is not product architecture.

## What the workspace looks like today

Read on the dev project, **2026-09-19**, read-only. Re-read it before
executing: these numbers are the "before" the last step compares against.

| | COWORKONTI `5ffea179` | its twin `32b79123` |
|---|---|---|
| members | 11, all `active` | 11 |
| reservations | 270 | 7 |
| invoices | 72 | 1 |
| ledger entries | 18 | 0 |
| plans | 3 (`Full`, `Half`, `Flex`) | 3 |
| packages | 3 (`test`, `toto`, `titi`) | 3 |
| fee bands | 2 — 50 € / 100 € — **already correct** | 2 |
| closure days | 0 | 0 |
| feature flags on | 90 | 90 |
| working hours | unset: `booking_rules` carries no `work_start_minutes`, `work_end_minutes` or `half_boundary_minutes`, so the product defaults apply | same |
| default locale | empty | empty |
| levels | `1er étage`, `2e étage` — one office each, both bookable as a whole | same |

**There are two.** The pair is the environment twin (#987): the one with
270 reservations is the real one. Every statement below names an id;
a step without one is a bug.

**One member points at the `Half` plan.** `members.plan_id` is
`on delete set null`, so deleting that row would silently unassign them —
which is why nothing here deletes a plan.

## The order, and why

Each step is reversible on its own, and each is verified before the next
one starts. Stop on anything unexpected; a surprise here is data nobody
can reconstruct.

### 0 — Capture the before

```sql
select public.export_workspace_configuration('5ffea179-71ed-4f1e-801f-5106b5ac0dc5');
```

Store the output **outside the repository**, with the date. Also record
the five counts above; step 6 compares against them.

### 1 — Apply the association template

`association_fr` (#1282) carries the hours (07:00 / 13:00 / 19:00), the
tariffs, the identity defaults, the lexicon and the feature profile. Use
the app's own preview: *Library → Association de coworking (France) →
Preview changes*, and tick only what the preview says is **new** or a
**change** you intend.

Applying the template is the point of having built it, and this is its
first real test on a workspace with data. The merge never deletes
(#1276): fee bands and closure days that already exist are kept.

**Verify:** the hours read 07:00 / 13:00 / 19:00 on *Availability*; the
fee bands still read 50 € and 100 €; the reservation and invoice counts
are unchanged.

### 2 — The default language

The template sets `default_locale = 'fr'`. If it did not, set it from
*Workspace settings → Language*. Empty means invitations and documents
follow the sender's app language rather than the association's.

**Verify:** an invitation preview reads French.

### 3 — Feature flags: 90 → the association profile

The template's feature map is explicit for every flag (#1282's contract),
so this happens with step 1. What it leaves is the honest question: the
flags the association actually wants are the ones the template names, and
the rest are off.

**Verify:** the Features screen's process cards show only what the
association uses; nothing a member relied on disappeared — ask the
responsable before switching off anything the template does not mention.

### 4 — The obsolete pricing rows

Three `plans` (`Full`, `Half`, `Flex`) are the older per-plan model,
superseded by the fee bands, which are populated and correct. One member
still points at `Half`.

**Deactivate, never delete:**

```sql
update public.plans set active = false
 where workspace_id = '5ffea179-71ed-4f1e-801f-5106b5ac0dc5';
```

Then move the one member off it in the app (*Members → the member →
plan*), so nothing points at an inactive row.

**Verify:** `select count(*) from public.members where plan_id is not null
and workspace_id = '5ffea179…'` returns 0, and the member's subscription
percentage is unchanged.

That two pricing models can both be populated is a real design wart. It
is **not** fixed here: it deserves its own issue.

### 5 — The junk packages

`test`, `toto` and `titi` are leftovers from trying the product.

```sql
update public.packages set active = false
 where workspace_id = '5ffea179-71ed-4f1e-801f-5106b5ac0dc5'
   and name in ('test', 'toto', 'titi');
```

Deactivate rather than delete: a package a member once bought is
referenced by what they bought.

**Verify:** the Billing screen offers no packages; no invoice changed.

### 6 — Closure days

Generate the public holidays for the relevant years (#1274, *Availability
→ Public holidays*).

**The rule that bites here:** a closure day is never created inside a
month that already carries an issued invoice — the generator skips it and
names it. This workspace has 72 invoices, so expect skips, and read the
list rather than dismissing it.

**Verify:** the entitlement table for a 50 % member matches the fifteen
months of the report. That comparison is the whole point of the exercise;
if it does not match, stop and find out why before touching anything
else.

### 7 — Nothing was lost

```sql
select (select count(*) from public.members where workspace_id = '5ffea179-71ed-4f1e-801f-5106b5ac0dc5') as members,
       (select count(*) from public.reservations where workspace_id = '5ffea179-71ed-4f1e-801f-5106b5ac0dc5') as reservations,
       (select count(*) from public.invoices where workspace_id = '5ffea179-71ed-4f1e-801f-5106b5ac0dc5') as invoices,
       (select count(*) from public.ledger_entries where workspace_id = '5ffea179-71ed-4f1e-801f-5106b5ac0dc5') as ledger;
```

Every number equals step 0's. If one moved, the change that moved it is
the one to undo — that is why each step is verified as it happens rather
than all at the end.

Also run the reconciliation, as its owner:

```sql
select * from public.reconcile_workspace('5ffea179-71ed-4f1e-801f-5106b5ac0dc5');
```

No rows means the invoices, the ledger and the matches still agree.

## The rules this procedure may not break

- **Nothing destructive is automated.** Deactivate before deleting;
  prefer `active = false` for anything an invoice or a ledger entry could
  reference.
- **Never delete a `plans` row a member still points at.**
- **Never create a closure day in a month that already carries an issued
  invoice** without deciding what happens to that invoice (#1274).
- **Nothing from this workspace enters the builtin template** — no
  member, no name, no address, no price beyond the published tariff.
- **Every statement carries its `workspace_id`.** One without it is a bug,
  not a shortcut.
- **The twin is not this workspace.** Deploy to it deliberately (#988) or
  leave it alone; do not run these statements against both because the
  name matches.

## What is deliberately not here

The floor-plan naming (`Bureau 1` twice) is handled in code by #1273 and
needs no data change. Whether floor 1 keeps whole-level booking is a
question for the responsable, not a step: floor 2's
`bookable_as_whole = false` is the report's request, floor 1's is not.
