<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Bringing one workspace to its reported configuration

#1285. **A procedure, not a script that runs itself.** It operates on one
association's real members, bookings and invoices, so every target is
named explicitly, every step says what it changes and how to read the
change back, and the whole thing stops on the first surprise.

Two stages, and only the first is an engineering task:

- **S1** — this document, its preflight
  (`workspace_alignment_preflight.sql`) and a synthetic rehearsal.
- **S2** — running it against the association. That needs the owner's
  authorisation and a date. **Nothing below is executed against a live
  workspace without it.**

The target workspace id, its twin and the backend are in #1285's
implementation brief. They are never written into this file, and never
inferred from whichever connection happens to be open.

## Before anything: the preflight

`docs/guides/workspace_alignment_preflight.sql` reads, reports and
aborts. It takes ten parameters — backend, environment, workspace id,
twin id, template key, groups, the plan / package / level ids that may
change, and the holiday decision — and **stops when one is missing or
disagrees with the database**:

```
begin;
set local alignment.backend_system_id = '...';  -- from pg_control_system()
set local alignment.environment = 'prod';       -- … and the eight others,
set local alignment.workspace_id = '...';       -- all listed at the head
\i docs/guides/workspace_alignment_preflight.sql   -- of the file itself
rollback;
```

It ends in `PREFLIGHT CLEAR` or `PREFLIGHT STOP` with the reasons. Run it
**as the owner who will apply** — the change preview reads the
configuration through the export gate, and a packet without a preview is
not reviewable, so an unreadable preview is itself a stop.

Its report is the review packet: the target and its twin, the number of
workspaces sharing that name, the change preview per group, the levels
the template would *add*, every plan with the number of members pointing
at it, every package, every level, and the holiday months split into
eligible and locked. Keep it **outside the repository**.

### Stop and recovery

- `STOP` on the environment, the twin, the backend or a parameter: fix
  the packet, never the check. The twins carry the same name, and the
  half that holds the bookings is not necessarily the half labelled
  `prod` — that is exactly why the id and the environment are declared
  and compared.
- `STOP` on a plan id: a member still points at it. Deactivating it is
  out of scope here (see *What this does not touch*).
- After each step below, read it back. A read-back that disagrees means
  stop and undo **that step** — that is why they are separate.
- Recovery: the before-snapshot (step 0) restores configuration through
  `import_workspace_configuration`. It does not restore protected rows,
  which is why no step touches them.

## Step 0 — the before

```sql
select public.export_workspace_configuration(:'workspace_id');
```

Needs `exportData`. Store the output outside the repository with its
date, and store the preflight report beside it. Both are inputs to
step 7.

## Step 1 — apply the template, by group

`association_fr` carries the hours (07:00 / 13:00 / 19:00), the identity
defaults, the lexicon, the roles and the feature profile.

- **Always pass an explicit group list.** With `p_groups => null` the
  server refuses the whole template if it carries one entity this server
  does not deploy (`template_compatibility` → `not_supported`), and a
  `partial` verdict is a compatibility finding to read, not to dismiss.
- **Never select `space`.** It carries `floor_plan`, and
  `merge_floor_plan` matches levels **by name**: the template's own
  example levels — which are not this workspace's levels — would be
  *added* beside the real ones. The preflight refuses the group and
  lists the names it would add.
- **`roles_access` replaces the feature map outright.** That is the
  intent here (an all-flags-on workspace becomes the association
  profile), but it is a replacement, so read the preview per flag before
  ticking it. It is also what decides the holiday control in step 5.
- **`pricing_credits` deletes and re-inserts every fee band.** Select it
  only when the preview reports the group `matching`, or when the change
  it shows is the one intended; the reported bands are already correct,
  so it is normally left out.

The reviewed default is `wording,hours_booking,roles_access` — identity
and lexicon, the working hours, the roles and the feature profile.

**Read back:** hours 07:00 / 13:00 / 19:00 on *Availability*; the fee
bands unchanged; `default_locale` = `fr`; the level list unchanged in
length and in names.

## Step 2 — the obsolete plans, by id, unreferenced only

The older per-plan model is superseded by the fee bands. Deactivate,
never delete: `members.plan_id references plans(id) on delete set null`,
so a delete silently unassigns whoever points at it.

```sql
update public.plans set active = false
 where workspace_id = :'workspace_id'
   and id = any (:'plan_ids'::uuid[])
   and not exists (select 1 from public.members m where m.plan_id = plans.id);
```

The predicate is not decoration: it is the same condition the preflight
stops on, restated where the write happens. A plan a member still points
at **stays active** until a separately authorised member migration
exists. This procedure does not create one.

**Read back:** the listed ids read `active = false`; every other plan is
untouched; the number of members carrying a `plan_id` is what it was.

## Step 3 — the junk packages, by id

```sql
update public.packages set active = false
 where workspace_id = :'workspace_id' and id = any (:'package_ids'::uuid[]);
```

Ids, not names: a package someone once bought is referenced by what they
bought, so it is deactivated and never deleted.

**Read back:** the listed ids read `active = false`; no invoice changed.

## Step 4 — whole-level booking on the second floor

The report's *« supprimer la possibilité de réserver toute une table »*
is the **whole-level** booking on floor 2.

*Preconditions*, all three, checked by the preflight and restated in the
statement: the id belongs to this workspace, it currently reads
`bookable_as_whole = true`, and floor 1's id is **not** in the list.

```sql
update public.levels set bookable_as_whole = false
 where workspace_id = :'workspace_id'
   and id = any (:'level_ids'::uuid[])
   and bookable_as_whole;

select id, name, bookable_as_whole from public.levels
 where workspace_id = :'workspace_id' order by sort_order;
```

Floor 1 keeps whole-level booking unless the responsable says otherwise,
in writing, as a separate instruction. Existing reservations on either
level are unaffected: `reservations.level_id` is `on delete restrict`
and nothing here deletes a level.

## Step 5 — the holidays: three paths, and no silent one

The control lives on *Availability → Public holidays* behind the
`publicHolidays` feature, and **the association profile turns that
feature off**. So the runbook cannot say "generate the holidays" and
leave it there: the preflight prints `control_enabled_now`,
`control_after_the_feature_map` and whether `calendar_navigation` was
selected, and refuses to continue until `alignment.holiday_plan` names
one of:

- `skip` — no closure day is created. The entitlement table keeps the
  shape it has today. This is the default.
- `enable_control` — the responsable wants the control: turn
  `publicHolidays` on **after** the feature map is applied, and generate
  from the screen. The preflight stops if the same run would switch it
  off again.
- `apply_group` — let the template's `calendar_navigation` group create
  them. The server resolves the days for this workspace's country and
  **omits every month that already carries an invoice**. This must be
  ticked deliberately, never as a side effect of "apply everything".

## Step 6 — historical months: eligible, or deliberately left

Closure days are never created inside a month that already carries an
issued invoice (#1274). The consequence must be reported, not hidden:

- **eligible months** — no invoice for that period: the holidays are
  created and the entitlements reconcile.
- **locked months** — an invoice exists: nothing is created, and the
  entitlement for that month stays as issued.

The preflight prints both lists. The outcome recorded in #1285 names the
locked months one by one. *"All historical entitlements reconciled"* is
false whenever that list is non-empty — the honest sentence is "the
eligible months reconciled; these months were left as invoiced."

## Step 7 — prove that nothing protected moved

Run the preflight again, with the same parameters and empty id lists,
and compare it with step 0's report:

- `members`, `reservations`, `invoices`, `ledger_entries` — each carries
  a row count **and a digest over the full contents of every row**.
  Equal counts prove nothing; equal digests prove the rows are
  byte-identical.
- `members_on_a_plan`, `reservations_per_level` and
  `invoices_per_member` — the relationships, so a re-pointed foreign key
  is visible even when every row still exists.
- the level list, unchanged in length and in names — the template added
  none.

Then, as the owner:

```sql
select * from public.reconcile_workspace(:'workspace_id');
```

No rows means the invoices, the ledger and the matches still agree.

## What this does not touch

Members, reservations, invoices and the ledger. No member is moved
between plans, no subscription percentage is edited, nothing is deleted.
The floor-plan naming (`Bureau 1` twice) is handled in code by #1273 and
needs no data change. That `plans` and `fee_bands` can both be populated
is a real design wart with its own issue; it is not fixed here.

## The rehearsal

The procedure is proven on disposable fixtures before it is proposed for
a real workspace. One aborting transaction creates a `REHEARSAL …` twin
pair sharing a name, seeds plans (one referenced by a member, one not),
packages, two whole-bookable levels, a reservation, an invoice in a past
period and a ledger entry; fingerprints them; runs the preflight
verbatim through its stop and clear paths; runs steps 1–4; fingerprints
again; and asserts the four protected tables, their relationships, the
level names, the fee bands and the untouched configuration identical —
then raises, so nothing persists. The results are in #1285.
