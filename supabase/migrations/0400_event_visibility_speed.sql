-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0400 -- reading the events stops costing an administrator a second.
--
-- Measured on the dev project (pg_stat_statements over 95 days): the
-- app's two slowest reads were `events` by workspace (mean 1 003 ms,
-- max 6.2 s) and `event_decisions` by event (mean 293 ms). EXPLAIN
-- ANALYZE as an administrator of a 748-event workspace put 886 of the
-- 926 ms into ONE call of event_types_in_view(), the first branch of
-- events_select (0216); event_decisions_select reads events, so it paid
-- the same again. The index scan itself took 40 ms; no index changes
-- that (index_advisor proposed none).
--
-- 0216 meant "has_permission runs once per distinct permission the
-- mapping names". The planner inlined the CTEs and applied
-- has_permission AFTER joining memberships to the event types: for a
-- person in 21 workspaces that was 21 x 43 = 903 calls of a nested
-- SECURITY DEFINER function, about 1 ms each, where 21 x 8 = 168 decide.
-- The CTEs are now MATERIALIZED, so each (workspace, permission) is
-- asked once, and the check calls has_permission_raw with
-- has_permission's own deployToDev rule beside it: the same answer,
-- one definer frame fewer.
--
-- Before/after on dev, rolled back: for every user with an active
-- membership the function returns the same 895 rows (0 differences);
-- 1 065 ms -> 170 ms over all of them; events 851 -> 99 ms and
-- event_decisions 811 -> 92 ms for that administrator.
--
-- Also: nine single-column indexes whose column leads a UNIQUE index on
-- the same table. Every lookup they served is served by the unique
-- index, which stays; each one only cost writes.

create or replace function public.event_types_in_view()
returns table (ws_id uuid, event_type text)
language sql
stable
security definer
set search_path = public
as $$
  with types as materialized (
    select (regexp_matches(pg_get_constraintdef(c.oid), '''([a-z_]+)''', 'g'))[1] as type_name
      from pg_constraint c
     where c.conname = 'events_type_check' and c.conrelid = 'public.events'::regclass
  ), wanted as materialized (
    select distinct unnest(public.event_type_view_permissions(types.type_name)) as perm
      from types
  ), held as materialized (
    select m.workspace_id, wanted.perm
      from public.members m cross join wanted
     where m.user_id = auth.uid() and m.status = 'active'
       and (public.has_permission_raw(m.workspace_id, wanted.perm)
            or (wanted.perm = 'deployToDev'
                and public.has_permission_raw(m.workspace_id, 'deployToProd')))
  )
  select distinct held.workspace_id, types.type_name
    from held join types on held.perm = any (public.event_type_view_permissions(types.type_name));
$$;
revoke execute on function public.event_types_in_view() from public, anon;
grant execute on function public.event_types_in_view() to authenticated;

drop index if exists public.accessories_workspace_idx;
drop index if exists public.expense_schedules_ws;
drop index if exists public.fee_bands_workspace_idx;
drop index if exists public.invoices_workspace_idx;
drop index if exists public.ledger_workspace_idx;
drop index if exists public.members_workspace_idx;
drop index if exists public.message_reactions_message_idx;
drop index if exists public.push_endpoints_member_idx;
drop index if exists public.validation_policies_workspace_idx;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(400);
