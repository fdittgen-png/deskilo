-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0332 (#2012 B) -- the plan-media objects nobody points at any more.
--
-- Storage and the database are two calls, never one transaction, so a
-- plan-media write that failed half-way can leave an object no row
-- references: a candidate background whose reference never moved, the
-- old background after a removal that failed, a plan image whose row
-- insert answer was lost. Nothing is ever deleted on the database side.
-- This function only NAMES them, for the workspace's owner, so the client
-- removes them through Storage's own policies (0036).
--
-- Bounded and conservative:
--   * only the two plan shapes -- `<ws>/img/<uuid>` and
--     `<ws>/<level uuid>[.<uuid>]`; report images (`<ws>/report/...`) and
--     anything else in the bucket are never named;
--   * only objects older than a day, so an upload in flight or an object
--     published a moment ago is never a candidate;
--   * never an object a plan image or a level references now;
--   * at most 100 per call, oldest first; a repeated call is safe.

create or replace function public.plan_media_orphans(p_workspace_id uuid, p_limit integer default 100)
returns setof text language sql stable security definer set search_path = public as $fn$
  select o.name from storage.objects o
   where public.is_owner_of(p_workspace_id)
     and o.bucket_id = 'floor-plans'
     and o.name ~ ('^' || p_workspace_id::text
                   || '/(img/[0-9a-f-]{36}|[0-9a-f-]{36}(\.[0-9a-f-]{36})?)$')
     and o.created_at < now() - interval '1 day'
     and not exists (select 1 from public.plan_images i
                      where i.workspace_id = p_workspace_id and i.storage_path = o.name)
     and not exists (select 1 from public.levels l
                      where l.workspace_id = p_workspace_id and l.background_path = o.name)
   order by o.created_at, o.name
   limit least(greatest(coalesce(p_limit, 100), 0), 100);
$fn$;

revoke execute on function public.plan_media_orphans(uuid, integer) from public, anon;
grant execute on function public.plan_media_orphans(uuid, integer) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(332);
