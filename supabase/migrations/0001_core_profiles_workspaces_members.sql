-- SPDX-License-Identifier: 0BSD
-- DesKilo core schema (Epic #2, issue #23).
-- Applied to the hosted reference project on 2026-07-07 as migration
-- "core_profiles_workspaces_members". Self-hosters apply this file.
create extension if not exists pgcrypto;

-- profiles: 1:1 with auth.users, created by trigger on signup
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1), '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- invite code: 10 chars from an unambiguous alphabet
create or replace function public.gen_invite_code()
returns text
language sql
volatile
set search_path = public
as $$
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', (floor(random()*32))::int + 1, 1), '')
  from generate_series(1, 10);
$$;

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  timezone text not null,
  invite_code text not null unique default public.gen_invite_code(),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.members (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  is_admin boolean not null default false,
  is_owner boolean not null default false,
  status text not null default 'active' check (status in ('active','paused','exited')),
  joined_at timestamptz not null default now(),
  unique (workspace_id, user_id)
);
create index members_user_idx on public.members (user_id);
create index members_workspace_idx on public.members (workspace_id);

-- role helpers (security definer: also used by RLS policies without recursion)
create or replace function public.is_member_of(ws uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members m
    where m.workspace_id = ws and m.user_id = auth.uid() and m.status <> 'exited'
  );
$$;

create or replace function public.is_admin_of(ws uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members m
    where m.workspace_id = ws and m.user_id = auth.uid()
      and m.status = 'active' and (m.is_admin or m.is_owner)
  );
$$;

create or replace function public.is_owner_of(ws uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members m
    where m.workspace_id = ws and m.user_id = auth.uid()
      and m.status = 'active' and m.is_owner
  );
$$;

create or replace function public.shares_workspace_with(other uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.members me
    join public.members them on me.workspace_id = them.workspace_id
    where me.user_id = auth.uid() and them.user_id = other
      and me.status <> 'exited' and them.status <> 'exited'
  );
$$;

-- a workspace must never lose its last active owner (spec §2)
create or replace function public.protect_last_owner()
returns trigger language plpgsql security definer set search_path = public as $$
declare remaining int;
begin
  if old.is_owner and old.status = 'active'
     and (tg_op = 'DELETE' or (not new.is_owner or new.status <> 'active')) then
    select count(*) into remaining from public.members
    where workspace_id = old.workspace_id and is_owner and status = 'active' and id <> old.id;
    if remaining = 0 then
      raise exception 'cannot remove the last owner of a workspace';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger members_protect_last_owner
before update or delete on public.members
for each row execute function public.protect_last_owner();

-- RPCs (the only write path for workspaces/members besides owner updates)
create or replace function public.create_workspace(
  p_name text, p_country_code text, p_currency_code text, p_timezone text
) returns uuid language plpgsql security definer set search_path = public as $$
declare ws_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values (p_name, upper(p_country_code), upper(p_currency_code), p_timezone, auth.uid())
  returning id into ws_id;
  insert into public.members (workspace_id, user_id, is_admin, is_owner)
  values (ws_id, auth.uid(), true, true);
  return ws_id;
end;
$$;

create or replace function public.join_workspace(p_invite_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare ws_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select id into ws_id from public.workspaces where invite_code = upper(trim(p_invite_code));
  if ws_id is null then raise exception 'invalid invite code'; end if;
  insert into public.members (workspace_id, user_id)
  values (ws_id, auth.uid())
  on conflict (workspace_id, user_id)
    do update set status = 'active' where public.members.status = 'exited';
  return ws_id;
end;
$$;

create or replace function public.leave_workspace(p_workspace_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update public.members set status = 'exited'
  where workspace_id = p_workspace_id and user_id = auth.uid();
end;
$$;
