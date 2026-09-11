-- SPDX-License-Identifier: 0BSD
-- 0203 — the platform-owner list shows a twin pair as two workspaces.
--
-- #987 taught the Profiles screen that a dev and a prod with the same
-- `pair_id` are ONE space with two sides, and the list of workspaces you
-- belong to renders them once, as a couple, with the DEV/PROD toggle.
--
-- The platform-owner section (#937) was written before that and never
-- learned it. It cannot learn it either, because `list_all_workspaces`
-- does not return `pair_id` — so the screen has no way to know the two
-- rows are the same space, and « zemare » appears twice, once as
-- "Development" and once as "Production", as though they were unrelated
-- workspaces belonging to different people.
--
-- One column. The grouping is the client's job; this is only what it
-- needs to do it.
--
-- A RETURNS TABLE cannot be widened by `create or replace` — PostgreSQL
-- refuses to change a function's result type — so this is a drop and a
-- re-create, which is safe here because nothing else calls it and the
-- body is otherwise unchanged.
drop function if exists public.list_all_workspaces();

create or replace function public.list_all_workspaces()
returns table (
  id uuid, name text, environment text, pair_id uuid,
  member_count bigint, owner_count bigint, is_member boolean
) language plpgsql stable security definer set search_path = public as $fn$
begin
  if not public.is_platform_owner() then raise exception 'platform owners only'; end if;
  return query
    select w.id, w.name, w.environment, w.pair_id,
           (select count(*) from public.members m where m.workspace_id = w.id and m.status = 'active'),
           (select count(*) from public.members m where m.workspace_id = w.id and m.is_owner),
           exists (select 1 from public.members m where m.workspace_id = w.id and m.user_id = auth.uid())
      from public.workspaces w
     -- The pair sorts together, dev before prod, so the client's
     -- grouping never has to reorder what it was handed.
     order by w.name, w.pair_id nulls first, w.environment;
end;
$fn$;
revoke execute on function public.list_all_workspaces() from public, anon;
