-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (event_types_in_view restated whole; same signature, same rows, same ACL)
--
-- 0612 (#3099 slice D, PERF-2 of the performance audit) -- the RLS helper
-- of events and event_decisions cost 104 ms of a 135 ms 100-row events
-- page (audit EXPLAIN). The final join evaluated
-- event_type_view_permissions(type) once per (held permission x event
-- type) pair: 22 workspaces x 10 permissions x ~60 types. Now each type
-- maps to its permissions ONCE (type_perms, materialized) and the join is
-- a plain equality. Rows are identical (dev, the busiest owner: 594 rows,
-- 0 differing); 131 ms -> 70 ms for that call. The 0400 body is otherwise
-- unchanged: the type list still comes from events_type_check, the
-- permission test is still has_permission_raw.

create or replace function public.event_types_in_view()
returns table(ws_id uuid, event_type text)
language sql stable security definer set search_path = public as $fn$
  with types as materialized (
    select (regexp_matches(pg_get_constraintdef(c.oid), '''([a-z_]+)''', 'g'))[1] as type_name
      from pg_constraint c
     where c.conname = 'events_type_check' and c.conrelid = 'public.events'::regclass
  ), type_perms as materialized (
    select types.type_name, unnest(public.event_type_view_permissions(types.type_name)) as perm
      from types
  ), wanted as materialized (
    select distinct type_perms.perm from type_perms
  ), held as materialized (
    select m.workspace_id, wanted.perm
      from public.members m cross join wanted
     where m.user_id = auth.uid() and m.status = 'active'
       and (public.has_permission_raw(m.workspace_id, wanted.perm)
            or (wanted.perm = 'deployToDev'
                and public.has_permission_raw(m.workspace_id, 'deployToProd')))
  )
  select distinct held.workspace_id, type_perms.type_name
    from held join type_perms on type_perms.perm = held.perm;
$fn$;
revoke execute on function public.event_types_in_view() from public, anon;
grant execute on function public.event_types_in_view() to authenticated;

select public.set_deskilo_schema_version(612);
