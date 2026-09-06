-- SPDX-License-Identifier: 0BSD
-- 0166 — #937: the platform owner sees every workspace, and who owns
-- the ones they are not in.
--
-- The account that operates the deployment needs an overview of the
-- whole database from inside the app. That is a PLATFORM role, not a
-- workspace one: it is held server-side in platform_admins (never an
-- e-mail check in a client), it bypasses no workspace rule, and every
-- read of another workspace's owners is written to platform_access_log,
-- which the workspace's own owners can read — the same transparency a
-- managed profile gets over who looked at it (0161).
--
-- An owner must always have an e-mail address: the operator's overview
-- is useless without one, and so is every notice the app sends. Every
-- current owner has one (199/199 at the time of writing), so the rule is
-- enforced from here on where ownership is granted — create_workspace
-- and activate_co_owner — with no backfill needed.
create table if not exists public.platform_admins (
  user_id  uuid primary key references auth.users(id) on delete cascade,
  added_at timestamptz not null default now()
);
alter table public.platform_admins enable row level security;
drop policy if exists platform_admins_self on public.platform_admins;
create policy platform_admins_self on public.platform_admins for select using (user_id = auth.uid());
insert into public.platform_admins (user_id) select id from auth.users where email = 'fdittgen@gmail.com' on conflict do nothing;

create or replace function public.is_platform_owner()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid());
$$;
grant execute on function public.is_platform_owner() to authenticated;

-- The sign-in e-mail or the profile's billing e-mail — either satisfies
-- the rule. Definer because auth.users is not readable by clients; not
-- callable by clients either, it is a guard's helper.
create or replace function public.user_has_email(p_user_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from auth.users u where u.id = p_user_id and coalesce(u.email, '') <> '')
      or exists (select 1 from public.profiles p where p.id = p_user_id and coalesce(p.email, '') <> '');
$$;
revoke execute on function public.user_has_email(uuid) from public, anon, authenticated;

create table if not exists public.platform_access_log (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  category     text not null check (category in ('owners')),
  at           timestamptz not null default now()
);
alter table public.platform_access_log enable row level security;
drop policy if exists platform_access_log_select on public.platform_access_log;
create policy platform_access_log_select on public.platform_access_log for select
  using (user_id = auth.uid() or public.is_owner_of(workspace_id));

-- Every workspace, with whether the caller is in it. Refuses — rather
-- than returning nothing — for anyone else, so an empty list can never
-- be mistaken for an empty database.
create or replace function public.list_all_workspaces()
returns table(id uuid, name text, environment text, member_count bigint, owner_count bigint, is_member boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_platform_owner() then raise exception 'platform owners only'; end if;
  return query
    select w.id, w.name, w.environment,
           (select count(*) from public.members m where m.workspace_id = w.id and m.status = 'active'),
           (select count(*) from public.members m where m.workspace_id = w.id and m.is_owner),
           exists (select 1 from public.members m where m.workspace_id = w.id and m.user_id = auth.uid())
      from public.workspaces w
     order by w.name;
end;
$$;
grant execute on function public.list_all_workspaces() to authenticated;

-- The owners of one workspace, name and e-mail. Volatile: the read is
-- logged before it is answered.
create or replace function public.workspace_owners(p_workspace_id uuid)
returns table(member_id uuid, name text, email text)
language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.is_platform_owner() then raise exception 'platform owners only'; end if;
  insert into public.platform_access_log (user_id, workspace_id, category)
  values (auth.uid(), p_workspace_id, 'owners');
  return query
    select m.id,
           coalesce(nullif(public.profile_full_name(p), ''), p.display_name, ''),
           coalesce(nullif(p.email, ''), u.email, '')
      from public.members m
      left join public.profiles p on p.id = m.user_id
      left join auth.users u on u.id = m.user_id
     where m.workspace_id = p_workspace_id and m.is_owner
     order by 2;
end;
$$;
grant execute on function public.workspace_owners(uuid) to authenticated;

-- Ownership is granted in two places; both now insist on an e-mail.
do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='create_workspace';
  v_old := E'raise exception ''not authenticated''; end if;\n';
  if position(v_old in v_def) = 0 then raise exception '0166: create_workspace anchor missing'; end if;
  execute replace(v_def, v_old, v_old || E'  if not public.user_has_email(auth.uid()) then raise exception ''an owner must have an e-mail address''; end if;\n');

  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='activate_co_owner';
  v_old := E'  update public.members\n    set is_owner = true, is_admin = true, co_owner = ''none''\n    where id = p_member_id;\n';
  if position(v_old in v_def) = 0 then raise exception '0166: activate_co_owner anchor missing'; end if;
  execute replace(v_def, v_old,
    E'  if not public.user_has_email((select user_id from public.members where id = p_member_id)) then\n    raise exception ''an owner must have an e-mail address'';\n  end if;\n' || v_old);
end
$patch$;
