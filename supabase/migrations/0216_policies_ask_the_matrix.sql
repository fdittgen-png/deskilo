-- SPDX-License-Identifier: 0BSD
--
-- #1321 — ten row-level policies stop asking "admin or owner" and ask
-- the role matrix (#513, #982).
--
-- `is_admin_of` is "active member, and admin or owner". The matrix lets
-- an owner take a permission away from the admin row, and the client
-- honours it — but these ten policies never asked, so the rows still
-- came back from PostgREST. An owner who removed viewFinances from
-- admins hid the invoices and the ledger and left every payment intent
-- and every VAT declaration readable. A role granted a permission
-- through the matrix (#1287) could never pass them either.
--
-- Every gate below is a permission the admin row holds BY DEFAULT
-- (has_permission_raw's literal list), so a workspace that never edited
-- its matrix sees exactly what it saw before. Only a narrowed matrix
-- narrows. Each policy keeps its own self-access clause.
--
-- ## Once per statement, not once per row
--
-- The first draft called has_permission inside each policy, per row.
-- Correct, and 25 times slower on the events feed of the development
-- workspace (629 rows: 60 ms → 1 400 ms for five counts). So the policies
-- compare `workspace_id` against an UNCORRELATED subquery — the set of
-- workspaces where the caller holds the permission — which Postgres
-- evaluates once and hashes. Measured the same way after the change:
-- admin 59 → 55 ms, owner 58 → 107 ms, member 208 → 189 ms.

-- The workspaces in which the caller holds at least one of [p_perms].
-- Each check is has_permission itself, so owners (everything), co-owners
-- and custom matrix rows follow automatically.
create or replace function public.workspaces_permitting(p_perms text[])
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select m.workspace_id
    from public.members m
   where m.user_id = auth.uid() and m.status = 'active'
     and exists (select 1 from unnest(p_perms) as p(perm)
                  where public.has_permission(m.workspace_id, p.perm));
$$;
revoke execute on function public.workspaces_permitting(text[]) from public, anon;
grant execute on function public.workspaces_permitting(text[]) to authenticated;

-- Who may read an event, by its domain. The feed used to be "all of it"
-- for any admin; each domain now answers to the permission that governs
-- what the event is about. A type missing here falls back to
-- manageConfiguration (owners and co-owners), and
-- supabase/tests/database/13_matrix_policies.sql fails the build when a
-- type in events_type_check reaches that fallback.
create or replace function public.event_type_view_permissions(p_type text)
returns text[]
language sql
immutable
set search_path = public
as $$
  select case
    -- Money that moved or was claimed: the finances view, and whoever
    -- issues the invoices it lands on (the may_view_member_finances pair).
    when p_type in ('payment', 'adjustment', 'service_charge', 'invoice_payment',
                    'invoice_writeoff', 'invoice_reminder', 'invoice_issue',
                    'invoice_void', 'refund', 'usage_correction', 'usage_record_delete')
      then array['viewFinances', 'issueInvoices']
    -- Expenses are approved under approveExpenses and booked in the finances.
    when p_type in ('expense', 'expense_schedule', 'expense_repartition')
      then array['approveExpenses', 'viewFinances']
    -- Bookings, and the extra half-days that extend them.
    when p_type in ('reservation', 'space_reservation', 'reservation_delete')
      then array['manageReservations']
    when p_type = 'quota'
      then array['manageReservations', 'viewFinances', 'issueInvoices']
    -- The membership itself.
    when p_type in ('member_join', 'member_status_change', 'subscription_change', 'role_change')
      then array['manageMembers']
    when p_type = 'matrix_change'
      then array['manageRoles', 'manageMembers']
    -- A member's commercial agreement (#749, #881).
    when p_type = 'price_negotiation'
      then array['viewNegotiations']
    when p_type = 'payment_terms_change'
      then array['paymentTermsEdit', 'viewNegotiations']
    else array['manageConfiguration']
  end;
$$;
revoke execute on function public.event_type_view_permissions(text) from public, anon;
grant execute on function public.event_type_view_permissions(text) to authenticated;

-- (workspace, event type) pairs the caller may read. Types come from the
-- events_type_check constraint, so a new type is covered the day it is
-- added; has_permission runs once per distinct permission the mapping
-- names, not once per type.
create or replace function public.event_types_in_view()
returns table (ws_id uuid, event_type text)
language sql
stable
security definer
set search_path = public
as $$
  with types as (
    select (regexp_matches(pg_get_constraintdef(c.oid), '''([a-z_]+)''', 'g'))[1] as type_name
      from pg_constraint c
     where c.conname = 'events_type_check' and c.conrelid = 'public.events'::regclass
  ), wanted as (
    select distinct unnest(public.event_type_view_permissions(types.type_name)) as perm
      from types
  ), held as (
    select m.workspace_id, wanted.perm
      from public.members m cross join wanted
     where m.user_id = auth.uid() and m.status = 'active'
       and public.has_permission(m.workspace_id, wanted.perm)
  )
  select distinct held.workspace_id, types.type_name
    from held join types on held.perm = any (public.event_type_view_permissions(types.type_name));
$$;
revoke execute on function public.event_types_in_view() from public, anon;
grant execute on function public.event_types_in_view() to authenticated;

-- A payment intent belongs to one member's finances: the rule of their
-- invoices (may_view_member_finances), against the row's own workspace.
drop policy if exists payment_intents_select on public.payment_intents;
create policy payment_intents_select on public.payment_intents
  for select using (
    workspace_id in (select public.workspaces_permitting(array['viewFinances', 'issueInvoices']))
    or exists (select 1 from public.members m
                where m.id = member_id and m.user_id = auth.uid())
  );

-- The declarations are the workspace's finances, whole.
drop policy if exists vat_declarations_select on public.vat_declarations;
create policy vat_declarations_select on public.vat_declarations
  for select using (
    workspace_id in (select public.workspaces_permitting(array['viewFinances']))
  );

-- Extra half-days are billed (finances) and booked (reservations).
drop policy if exists quota_extensions_select on public.quota_extensions;
create policy quota_extensions_select on public.quota_extensions
  for select using (
    workspace_id in (select public.workspaces_permitting(
      array['manageReservations', 'viewFinances', 'issueInvoices']))
    or exists (select 1 from public.members m
                where m.id = member_id and m.user_id = auth.uid())
  );

-- Shares of an expense: approved under approveExpenses, booked in the
-- finances.
drop policy if exists expense_repartitions_select on public.expense_repartitions;
create policy expense_repartitions_select on public.expense_repartitions
  for select using (
    workspace_id in (select public.workspaces_permitting(array['approveExpenses', 'viewFinances']))
  );

-- The catalogue names manageServices "services, packages, fee bands".
-- Active packages stay readable to every active member, who buys them.
drop policy if exists packages_select on public.packages;
create policy packages_select on public.packages
  for select using (
    workspace_id in (select public.workspaces_permitting(array['manageServices']))
    or (active and exists (
      select 1 from public.members m
      where m.workspace_id = packages.workspace_id
        and m.user_id = auth.uid() and m.status = 'active'))
  );

-- Invitations are how members are added: manageMembers.
drop policy if exists invitations_select on public.invitations;
create policy invitations_select on public.invitations
  for select using (
    workspace_id in (select public.workspaces_permitting(array['manageMembers']))
  );

-- Badges are issued, registered and revoked under operateKiosk — the
-- permission issue_member_badge and revoke_member_badge already check.
drop policy if exists member_badges_select on public.member_badges;
create policy member_badges_select on public.member_badges
  for select using (
    workspace_id in (select public.workspaces_permitting(array['operateKiosk']))
    or exists (select 1 from public.members m
                where m.id = member_id and m.user_id = auth.uid())
  );

-- The events feed: each domain to its own permission (above), plus the
-- people the event is about and whoever the validation policy names as
-- its validator — both unchanged.
drop policy if exists events_select on public.events;
create policy events_select on public.events
  for select using (
    (workspace_id, type) in (select v.ws_id, v.event_type from public.event_types_in_view() v)
    or exists (select 1 from public.members m
                where m.user_id = auth.uid()
                  and m.id = any (array[events.actor_member_id, events.subject_member_id]))
    or public.may_validate_event_type(workspace_id, type)
  );

-- The accessory catalogue carries the priced supplements: a service of
-- the workspace, manageServices.
drop policy if exists accessories_write on public.accessories;
create policy accessories_write on public.accessories
  for all
  using (workspace_id in (select public.workspaces_permitting(array['manageServices'])))
  with check (workspace_id in (select public.workspaces_permitting(array['manageServices'])));

-- Which seat carries which accessory is part of the site's layout:
-- manageSites.
drop policy if exists seat_accessories_write on public.seat_accessories;
create policy seat_accessories_write on public.seat_accessories
  for all
  using (workspace_id in (select public.workspaces_permitting(array['manageSites'])))
  with check (workspace_id in (select public.workspaces_permitting(array['manageSites'])));
