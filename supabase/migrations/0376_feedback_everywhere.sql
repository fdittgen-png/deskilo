-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0376 (#2185) -- favourites and ratings on every resource but people.
--
--   * services and accessories join the places a member can favourite and
--     rate (a seat, a desk, an office, a level, a service, an accessory);
--   * a WORKSPACE can be favourited and rated too, by anybody signed in
--     who can see it (a member, or any listed workspace): those are the
--     person's own, not a member's, so they live beside the person and
--     travel with them across workspaces. Everybody reads a workspace's
--     average and count, never who gave which.

alter table public.resource_favorites drop constraint resource_favorites_kind_check;
alter table public.resource_favorites add constraint resource_favorites_kind_check
  check (kind in ('seat', 'desk', 'office', 'level', 'service', 'accessory'));
alter table public.resource_ratings drop constraint resource_ratings_kind_check;
alter table public.resource_ratings add constraint resource_ratings_kind_check
  check (kind in ('seat', 'desk', 'office', 'level', 'service', 'accessory'));

create or replace function public.place_feedback_member(
  p_workspace uuid, p_kind text, p_resource uuid)
returns public.members
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_member public.members;
  v_found boolean;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  begin
    v_member := public.my_active_member(p_workspace);
  exception when others then
    raise exception 'not a member of this workspace';
  end;
  if v_member.id is null or v_member.is_kiosk then
    raise exception 'not a member of this workspace';
  end if;
  if not public.feature_effective(p_workspace, 'placeFeedback') then
    raise exception 'favourites and ratings are off in this workspace';
  end if;
  if not public.has_permission(p_workspace, 'makeReservations') then
    raise exception 'not allowed to use reservations';
  end if;
  v_found := case p_kind
    when 'seat' then exists (select 1 from public.seats x where x.id = p_resource and x.workspace_id = p_workspace)
    when 'desk' then exists (select 1 from public.desks x where x.id = p_resource and x.workspace_id = p_workspace)
    when 'office' then exists (select 1 from public.offices x where x.id = p_resource and x.workspace_id = p_workspace)
    when 'level' then exists (select 1 from public.levels x where x.id = p_resource and x.workspace_id = p_workspace)
    when 'service' then exists (select 1 from public.services x where x.id = p_resource and x.workspace_id = p_workspace)
    when 'accessory' then exists (select 1 from public.accessories x where x.id = p_resource and x.workspace_id = p_workspace)
    else false end;
  if not coalesce(v_found, false) then raise exception 'unknown place'; end if;
  return v_member;
end;
$fn$;
revoke execute on function public.place_feedback_member(uuid, text, uuid) from public, anon, authenticated;

create table public.workspace_favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  primary key (user_id, workspace_id)
);
select public.ensure_system_columns('workspace_favorites');
alter table public.workspace_favorites enable row level security;
revoke all on public.workspace_favorites from public, anon, authenticated;
grant select on public.workspace_favorites to authenticated;
create policy workspace_favorites_own on public.workspace_favorites
  for select to authenticated using (user_id = (select auth.uid()));
create policy mcp_delegated_deny on public.workspace_favorites as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create table public.workspace_ratings (
  user_id uuid not null references auth.users(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  stars smallint not null check (stars between 0 and 5),
  primary key (user_id, workspace_id)
);
select public.ensure_system_columns('workspace_ratings');
alter table public.workspace_ratings enable row level security;
revoke all on public.workspace_ratings from public, anon, authenticated;
grant select on public.workspace_ratings to authenticated;
create policy workspace_ratings_own on public.workspace_ratings
  for select to authenticated using (user_id = (select auth.uid()));
create policy mcp_delegated_deny on public.workspace_ratings as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create index workspace_ratings_workspace on public.workspace_ratings (workspace_id);

-- A workspace the caller may favourite and rate: one they belong to, or any
-- listed one (the public directory).
create or replace function public.workspace_feedback_check(p_workspace uuid)
returns void
language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not (public.is_member_of(p_workspace)
          or exists (select 1 from public.workspaces w
                      where w.id = p_workspace and w.visibility_set_at is not null)) then
    raise exception 'unknown workspace';
  end if;
end;
$fn$;
revoke execute on function public.workspace_feedback_check(uuid) from public, anon, authenticated;

create or replace function public.workspace_feedback_summary(p_workspace uuid)
returns jsonb
language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'average', (select round(avg(r.stars)::numeric, 2) from public.workspace_ratings r where r.workspace_id = p_workspace),
    'count', (select count(*) from public.workspace_ratings r where r.workspace_id = p_workspace),
    'mine', (select r.stars from public.workspace_ratings r where r.workspace_id = p_workspace and r.user_id = auth.uid()),
    'favorite', exists (select 1 from public.workspace_favorites f
                         where f.workspace_id = p_workspace and f.user_id = auth.uid()));
$fn$;
revoke execute on function public.workspace_feedback_summary(uuid) from public, anon, authenticated;

create or replace function public.set_workspace_favorite(p_workspace uuid, p_on boolean default true)
returns jsonb
language plpgsql security definer set search_path = public as $fn$
begin
  perform public.mcp_require_native();
  perform public.workspace_feedback_check(p_workspace);
  if coalesce(p_on, true) then
    insert into public.workspace_favorites (user_id, workspace_id) values (auth.uid(), p_workspace)
    on conflict (user_id, workspace_id) do nothing;
  else
    delete from public.workspace_favorites where user_id = auth.uid() and workspace_id = p_workspace;
  end if;
  return public.workspace_feedback_summary(p_workspace);
end;
$fn$;
revoke execute on function public.set_workspace_favorite(uuid, boolean) from public, anon;
grant execute on function public.set_workspace_favorite(uuid, boolean) to authenticated;

create or replace function public.set_workspace_rating(p_workspace uuid, p_stars integer)
returns jsonb
language plpgsql security definer set search_path = public as $fn$
begin
  perform public.mcp_require_native();
  perform public.workspace_feedback_check(p_workspace);
  if p_stars is not null and p_stars not between 0 and 5 then
    raise exception 'a rating is from 0 to 5 stars';
  end if;
  if p_stars is null then
    delete from public.workspace_ratings where user_id = auth.uid() and workspace_id = p_workspace;
  else
    insert into public.workspace_ratings (user_id, workspace_id, stars) values (auth.uid(), p_workspace, p_stars)
    on conflict (user_id, workspace_id) do update set stars = excluded.stars;
  end if;
  return public.workspace_feedback_summary(p_workspace);
end;
$fn$;
revoke execute on function public.set_workspace_rating(uuid, integer) from public, anon;
grant execute on function public.set_workspace_rating(uuid, integer) to authenticated;

-- A screenful of listed workspaces at once: id -> {average, count, mine, favorite}.
create or replace function public.workspace_feedback_of(p_ids uuid[])
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return coalesce((
    select jsonb_object_agg(w.id::text, public.workspace_feedback_summary(w.id))
      from public.workspaces w
     where w.id = any (coalesce(p_ids, '{}'::uuid[]))
       and (w.visibility_set_at is not null or public.is_member_of(w.id))), '{}'::jsonb);
end;
$fn$;
revoke execute on function public.workspace_feedback_of(uuid[]) from public, anon;
grant execute on function public.workspace_feedback_of(uuid[]) to authenticated;

-- The subject-access export returns the person's own workspace marks too.
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $export$
declare
  v_def text;
  v_next text;
begin
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  if position('workspace_favorites' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def, $a$    'exported_at', now(),$a$, $a$    'exported_at', now(),
    'workspace_favorites', (select coalesce(jsonb_agg(jsonb_build_object('workspace_id', f.workspace_id, 'created', f.created_datetime)), '[]'::jsonb)
                              from public.workspace_favorites f where f.user_id = auth.uid()),
    'workspace_ratings', (select coalesce(jsonb_agg(jsonb_build_object('workspace_id', r.workspace_id, 'stars', r.stars, 'created', r.created_datetime)), '[]'::jsonb)
                            from public.workspace_ratings r where r.user_id = auth.uid()),$a$);
    if v_next is null then raise exception '0376: export anchor missing'; end if;
    execute v_next;
  end if;
end;
$export$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(376);
