-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0309 (#1652) -- an invitation is looked at before it is used, and its
-- use answers what actually happened.
--
-- `join_workspace` answers a workspace id or raises one of three
-- sentences, so the app could only say "joined" or "something went
-- wrong": an expired personal invitation, a workspace code the owner had
-- changed, an invitation already used by another account and a person
-- who was already a member all looked the same. Two narrow functions sit
-- beside it; neither is a second admission engine:
--
--   invitation_preview(code)  reads only. The exact code's workspace
--                             name, environment and offered role, or the
--                             reason it cannot be used. No write, so a
--                             link scanner, a prefetch or a preview
--                             changes nothing.
--   join_by_invitation(code)  classifies the same way, and only for a
--                             usable code calls the EXISTING
--                             join_workspace -- the same pending member,
--                             the same member_join event, the same
--                             validators. A second call (double tap, lost
--                             response) finds the membership and answers
--                             already_member without writing again.
--
-- "Revoked" is only what the data can prove: a workspace code the owner
-- replaced. The old code is kept (without its workspace's name) so the
-- person holding it hears "withdrawn", not "never existed". Personal
-- invitations have no revocation, so they are never called revoked.
-- Nothing here searches other databases: a code is looked up here only.

create table public.retired_invite_codes (
  code text primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  retired_at timestamptz not null default now()
);
select public.ensure_system_columns('retired_invite_codes');
alter table public.retired_invite_codes enable row level security;
revoke all on public.retired_invite_codes from public, anon, authenticated;
create policy mcp_delegated_deny on public.retired_invite_codes
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create function public.retire_invite_code() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(old.invite_code, '') <> ''
     and old.invite_code is distinct from new.invite_code then
    insert into public.retired_invite_codes (code, workspace_id)
    values (old.invite_code, old.id)
    on conflict (code) do update
      set workspace_id = excluded.workspace_id, retired_at = now();
  end if;
  -- A code that is live again is no longer withdrawn.
  delete from public.retired_invite_codes where code = new.invite_code;
  return new;
end;
$$;
revoke execute on function public.retire_invite_code() from public, anon, authenticated;
create trigger retire_invite_code after update of invite_code on public.workspaces
  for each row execute function public.retire_invite_code();

-- The one classification both functions read. Not granted: it answers
-- for auth.uid() and is only reached through the two below.
create function public.invitation_state(p_code text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_code text := upper(trim(coalesce(p_code, '')));
  v_ws public.workspaces;
  v_inv public.invitations;
  v_member public.members;
  v_bound_user uuid;
  v_admin boolean := false;
  v_public jsonb;
begin
  if v_code = '' or char_length(v_code) > 64 then
    return jsonb_build_object('state', 'invalid');
  end if;
  select * into v_ws from public.workspaces where invite_code = v_code;
  if not found then
    select * into v_inv from public.invitations where code = v_code;
    if not found then
      if exists (select 1 from public.retired_invite_codes where code = v_code) then
        return jsonb_build_object('state', 'revoked');
      end if;
      return jsonb_build_object('state', 'invalid');
    end if;
    select * into v_ws from public.workspaces where id = v_inv.workspace_id;
    if not found then return jsonb_build_object('state', 'invalid'); end if;
    v_admin := v_inv.is_admin;
  end if;
  v_public := jsonb_build_object(
    'workspace_name', v_ws.name,
    'environment', v_ws.environment,
    'offered_role', case when v_admin then 'admin' else 'member' end);

  select * into v_member from public.members
   where workspace_id = v_ws.id and user_id = auth.uid();
  if found and v_member.status in ('active', 'pending') then
    return v_public || jsonb_build_object('state', 'already_member',
      'workspace_id', v_ws.id, 'member_status', v_member.status);
  end if;
  if found and v_member.status = 'paused' then
    return v_public || jsonb_build_object('state', 'paused',
      'workspace_id', v_ws.id, 'member_status', v_member.status);
  end if;

  if v_inv.id is not null then
    if v_inv.redeemed_at is not null then
      return jsonb_build_object('state',
        case when v_inv.redeemed_by = auth.uid() then 'invalid' else 'wrong_account' end);
    end if;
    if v_inv.expires_at <= now() then
      return jsonb_build_object('state', 'expired');
    end if;
    if v_inv.member_id is not null then
      select user_id into v_bound_user from public.members where id = v_inv.member_id;
      if not found then return jsonb_build_object('state', 'invalid'); end if;
      if v_bound_user is not null and v_bound_user <> auth.uid() then
        return jsonb_build_object('state', 'wrong_account');
      end if;
    end if;
  end if;
  -- Every join lands pending until the validators decide (0052).
  return v_public || jsonb_build_object('state', 'valid', 'requires_approval', true);
end;
$$;
revoke execute on function public.invitation_state(text) from public, anon, authenticated;

create function public.invitation_preview(p_code text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return public.invitation_state(p_code);
end;
$$;
revoke execute on function public.invitation_preview(text) from public, anon;
grant execute on function public.invitation_preview(text) to authenticated;

create function public.join_by_invitation(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v jsonb;
  v_ws uuid;
  v_status text;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  v := public.invitation_state(p_code);
  if v->>'state' <> 'valid' then return v; end if;
  begin
    v_ws := public.join_workspace(p_code);
  exception when raise_exception then
    -- A concurrent call used the invitation first: answer what is true now.
    return public.invitation_state(p_code);
  end;
  select status into v_status from public.members
   where workspace_id = v_ws and user_id = auth.uid();
  return (v - 'requires_approval') || jsonb_build_object(
    'state', case when v_status = 'active' then 'joined_active' else 'joined_pending' end,
    'workspace_id', v_ws, 'member_status', v_status);
end;
$$;
revoke execute on function public.join_by_invitation(text) from public, anon;
grant execute on function public.join_by_invitation(text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(309);
