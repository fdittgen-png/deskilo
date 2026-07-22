-- SPDX-License-Identifier: 0BSD
-- Personal invitations (#319): an invitation code is usable ONLY once,
-- only until it expires, and only for the role it was minted with — a
-- forwarded admin code must not mint admins forever. Replaces the static
-- workspace-wide admin secret of 0030:
--   * workspaces.invite_code stays the open member-level walk-in handle
--     (the printed on-site QR and the human-readable workspace ID).
--   * workspace_admin_invites is DROPPED — the static admin code is no
--     longer honored anywhere.
--   * Admin access is now granted exclusively through a personal
--     invitation minted by an owner (create_invitation), or by an owner
--     editing the member row (members_update_owner RLS, 0002).

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  code text not null unique default public.gen_invite_code(),
  is_admin boolean not null default false,
  invited_first_name text not null default '' check (char_length(invited_first_name) <= 120),
  invited_last_name text not null default '' check (char_length(invited_last_name) <= 120),
  created_by uuid not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '14 days',
  redeemed_by uuid,
  redeemed_at timestamptz
);

alter table public.invitations enable row level security;

-- Workspace admins see their workspace's invitations (pending + redeemed,
-- for an eventual invite-audit surface). No client write policies on
-- purpose (default-deny) — rows are minted and redeemed by the RPCs only.
create policy invitations_select on public.invitations
  for select using (public.is_admin_of(workspace_id));

-- create_invitation: admins mint member invites; ONLY owners mint admin
-- invites (mirrors 0030, where the admin secret was owner-readable).
create or replace function public.create_invitation(
  p_workspace_id uuid,
  p_is_admin boolean,
  p_first_name text default '',
  p_last_name text default ''
) returns text language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if p_is_admin then
    if not public.is_owner_of(p_workspace_id) then
      raise exception 'only owners may invite admins';
    end if;
  elsif not public.is_admin_of(p_workspace_id) then
    raise exception 'only admins may invite members';
  end if;
  insert into public.invitations
    (workspace_id, is_admin, invited_first_name, invited_last_name, created_by)
  values
    (p_workspace_id, p_is_admin,
     left(coalesce(p_first_name, ''), 120),
     left(coalesce(p_last_name, ''), 120),
     auth.uid())
  returning code into v_code;
  return v_code;
end;
$$;

revoke execute on function
  public.create_invitation(uuid, boolean, text, text) from public, anon;

-- join_workspace: the workspace member code stays an open user-level
-- join; otherwise the code must be an unredeemed, unexpired personal
-- invitation, claimed ATOMICALLY (the UPDATE is the single-use latch —
-- two concurrent redeems race on the row lock and the loser matches
-- nothing). The invitation row decides the role; is_owner is never
-- touched.
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
    update public.invitations
       set redeemed_by = auth.uid(), redeemed_at = now()
     where code = v_code
       and redeemed_at is null
       and expires_at > now()
    returning workspace_id, is_admin into ws_id, v_admin;
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

-- The static admin secret dies with its table. create_workspace (0030)
-- also minted a row here — recreate it without that insert.
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

-- set_workspace_code (0030) checked collisions against the admin table;
-- now it must not collide with any personal invitation instead.
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
  if exists (select 1 from public.invitations where code = v_code) then
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

drop table public.workspace_admin_invites;
