-- SPDX-License-Identifier: 0BSD
-- Applied to the hosted reference project on 2026-07-18.
-- Role-scoped invites: every join carries an explicit role, derived from
-- WHICH secret code was used — never from a client-supplied parameter.
--   * workspaces.invite_code stays the member (plain-user) invite and the
--     human-readable workspace ID; printed QRs keep working.
--   * workspace_admin_invites holds one admin code per workspace,
--     readable by owners only.
--   * There is deliberately NO owner invite: ownership is only granted by
--     an owner editing the member row (members_update_owner RLS, 0002),
--     and the last-owner trigger (0001) still guards the other direction.

create table public.workspace_admin_invites (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  code text not null unique default public.gen_invite_code(),
  created_at timestamptz not null default now()
);

alter table public.workspace_admin_invites enable row level security;

-- owners read their workspace's admin code; no write policies on purpose
-- (default-deny) — rows are created by the RPCs below.
create policy workspace_admin_invites_select on public.workspace_admin_invites
  for select using (public.is_owner_of(workspace_id));

-- every existing workspace gets its admin code
insert into public.workspace_admin_invites (workspace_id)
select id from public.workspaces;

-- create_workspace: also mint the admin invite for new workspaces
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
  insert into public.workspace_admin_invites (workspace_id) values (ws_id);
  return ws_id;
end;
$$;

-- join_workspace: the matched code decides the role. A member code joins
-- (or reactivates) as-is; the admin code additionally grants is_admin —
-- possession of that secret IS the credential. is_owner is never touched.
create or replace function public.join_workspace(p_invite_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  ws_id uuid;
  v_code text;
  v_admin boolean := false;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  v_code := upper(trim(p_invite_code));
  select id into ws_id from public.workspaces where invite_code = v_code;
  if ws_id is null then
    select workspace_id into ws_id
    from public.workspace_admin_invites where code = v_code;
    if ws_id is not null then v_admin := true; end if;
  end if;
  if ws_id is null then raise exception 'invalid invite code'; end if;
  insert into public.members (workspace_id, user_id, is_admin)
  values (ws_id, auth.uid(), v_admin)
  on conflict (workspace_id, user_id) do update
    set status = 'active',
        is_admin = public.members.is_admin or excluded.is_admin
    where public.members.status = 'exited' or excluded.is_admin;
  return ws_id;
end;
$$;

-- set_workspace_code: a custom workspace ID must not collide with any
-- admin code either, or that workspace's admin invite would be shadowed
-- (member codes are matched first in join_workspace).
create or replace function public.set_workspace_code(
  p_workspace_id uuid,
  p_code text
) returns text language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only owners may change the workspace ID';
  end if;
  v_code := upper(trim(p_code));
  if v_code !~ '^[A-Z0-9]{4,20}$' then
    raise exception 'workspace ID must be 4-20 letters or digits';
  end if;
  if exists (select 1 from public.workspace_admin_invites where code = v_code) then
    raise exception 'workspace ID already taken';
  end if;
  begin
    update public.workspaces set invite_code = v_code where id = p_workspace_id;
  exception when unique_violation then
    raise exception 'workspace ID already taken';
  end;
  return v_code;
end;
$$;
