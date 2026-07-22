-- SPDX-License-Identifier: 0BSD
-- New-member validation. Applied to the hosted reference project on
-- 2026-07-22 (an interim draft named 0051_single_use_invites_member_
-- validation carried parts of this earlier the same day and was
-- superseded by 0051_personal_invitations + this file; its leftover
-- invite_tokens table is dropped below).
--
-- Joining is no longer instant (field request): every join lands as a
-- PENDING membership. The new member sees only the workspace name (the
-- waiting screen) until owner/admins confirm — through the members
-- screen's quick decision or the SAME validation quorum as payments,
-- expenses and role changes (events type 'member_join', configurable
-- per workspace in Validation rules). Rejection exits the membership.

-- ---------------------------------------------------------------------
-- 0. Interim cleanup (staging-only artifacts of the superseded draft).
-- ---------------------------------------------------------------------
drop function if exists public.mint_invite_token(uuid, text);
drop table if exists public.invite_tokens;

-- ---------------------------------------------------------------------
-- 1. Pending membership status + visibility carve-outs.
-- ---------------------------------------------------------------------
alter table public.members drop constraint members_status_check;
alter table public.members add constraint members_status_check
  check (status in ('active','paused','pending','exited'));

-- Pending members are NOT members yet: no plan, no directory, no money.
create or replace function public.is_member_of(ws uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members m
    where m.workspace_id = ws and m.user_id = auth.uid()
      and m.status in ('active','paused')
  );
$$;

create or replace function public.shares_workspace_with(other uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.members me
    join public.members them on me.workspace_id = them.workspace_id
    where me.user_id = auth.uid() and them.user_id = other
      and me.status in ('active','paused')
      and them.status in ('active','paused')
  );
$$;

-- …but they may see the workspace's NAME (the waiting screen) and their
-- OWN membership row (status detection).
drop policy if exists workspaces_select_pending on public.workspaces;
create policy workspaces_select_pending on public.workspaces
  for select using (exists (
    select 1 from public.members m
    where m.workspace_id = workspaces.id and m.user_id = auth.uid()
      and m.status = 'pending'
  ));
drop policy if exists members_select_self on public.members;
create policy members_select_self on public.members
  for select using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- 2. The member_join event type.
-- ---------------------------------------------------------------------
alter table public.events drop constraint events_type_check;
alter table public.events add constraint events_type_check
  check (type in ('reservation','payment','expense','adjustment',
                  'service_charge','quota','role_change','member_join'));

-- ---------------------------------------------------------------------
-- 3. join_workspace v4: body = 0051 (personal invitations, atomic
--    redeem) + every join lands PENDING with a member_join event.
-- ---------------------------------------------------------------------
create or replace function public.join_workspace(p_invite_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  ws_id uuid;
  v_code text;
  v_admin boolean := false;
  v_member_id uuid;
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

  -- Every join is PENDING until the validators confirm (re-joins of
  -- exited members included); active/paused members re-joining keep
  -- their standing.
  insert into public.members (workspace_id, user_id, is_admin, status)
  values (ws_id, auth.uid(), v_admin, 'pending')
  on conflict (workspace_id, user_id) do update
    set status = case when public.members.status = 'exited'
                      then 'pending' else public.members.status end,
        is_admin = public.members.is_admin or excluded.is_admin
  returning id into v_member_id;

  if exists (select 1 from public.members
              where id = v_member_id and status = 'pending')
     and not exists (
       select 1 from public.events
       where subject_member_id = v_member_id
         and type = 'member_join' and status = 'pending') then
    insert into public.events
      (workspace_id, type, action, actor_member_id, subject_member_id,
       payload, status)
    values (ws_id, 'member_join', 'submitted', v_member_id, v_member_id,
            jsonb_build_object('as_admin', v_admin), 'pending');
  end if;
  return ws_id;
end;
$$;

-- ---------------------------------------------------------------------
-- 4. respond_to_event: + the member_join branches (confirm → active,
--    reject → exited). Body = 0035 verbatim otherwise.
-- ---------------------------------------------------------------------
create or replace function public.respond_to_event(
  p_event_id uuid,
  p_accept boolean
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_event public.events;
  v_caller public.members;
  v_policy record;
  v_subject_decides boolean;
  v_in_pool boolean;
  v_pool_size int;
  v_required int;
  v_accepts int;
  v_subject_ok boolean;
  v_owner_ok boolean;
begin
  select e.* into v_event from public.events e where e.id = p_event_id;
  if v_event.id is null then raise exception 'unknown event'; end if;
  if v_event.status <> 'pending' then raise exception 'already decided'; end if;

  select m.* into v_caller from public.members m
    where m.workspace_id = v_event.workspace_id and m.user_id = auth.uid()
      and m.status = 'active';
  if v_caller.id is null then raise exception 'not a member'; end if;
  if exists (select 1 from public.event_decisions d
              where d.event_id = p_event_id and d.member_id = v_caller.id) then
    raise exception 'you already decided this event';
  end if;

  select * into v_policy from public.validation_policies
    where workspace_id = v_event.workspace_id and event_type = v_event.type;
  if v_policy is null then
    select * into v_policy from public.validation_policies
      where workspace_id = v_event.workspace_id and event_type is null;
  end if;
  if v_policy is null then
    select null::uuid as id, v_event.workspace_id as workspace_id,
           null::text as event_type, 1 as required_count,
           true as admins_may_validate, '{}'::uuid[] as eligible_admin_ids,
           false as owner_required
      into v_policy;
  end if;

  v_subject_decides := v_event.type = 'reservation'
    or (v_event.type in ('payment','service_charge')
        and v_event.actor_member_id <> v_event.subject_member_id);

  select count(*) into v_pool_size from public.members m
    where m.workspace_id = v_event.workspace_id and m.status = 'active'
      and m.id not in (v_event.actor_member_id, v_event.subject_member_id)
      and (m.is_owner or (m.is_admin and v_policy.admins_may_validate
           and (cardinality(v_policy.eligible_admin_ids) = 0
                or m.id = any(v_policy.eligible_admin_ids))));

  v_in_pool := (v_caller.is_owner or (v_caller.is_admin and v_policy.admins_may_validate
                and (cardinality(v_policy.eligible_admin_ids) = 0
                     or v_caller.id = any(v_policy.eligible_admin_ids))))
    and (v_caller.id <> v_event.subject_member_id
         or (not v_subject_decides and v_pool_size = 0))
    and (v_caller.id <> v_event.actor_member_id or v_pool_size = 0);
  if v_pool_size = 0 and (v_caller.is_owner or (v_caller.is_admin and v_policy.admins_may_validate)) then
    v_pool_size := 1;
  end if;

  if v_subject_decides and v_caller.id = v_event.subject_member_id then
    null;
  elsif v_in_pool then
    null;
  else
    raise exception 'you are not an eligible validator for this event';
  end if;

  insert into public.event_decisions (event_id, member_id, decision)
  values (p_event_id, v_caller.id, case when p_accept then 'accept' else 'reject' end);

  if not p_accept then
    update public.events set status = 'rejected', decided_at = now()
      where id = p_event_id;
    if v_event.reservation_id is not null then
      update public.reservations set status = 'cancelled'
        where id = v_event.reservation_id and status in ('reserved','checked_in');
    end if;
    if v_event.type = 'member_join' then
      -- a refused join exits the pending membership
      update public.members set status = 'exited'
        where id = v_event.subject_member_id and status = 'pending';
    end if;
    return;
  end if;

  select count(*) into v_accepts from public.event_decisions
    where event_id = p_event_id and decision = 'accept';
  v_required := greatest(1, least(v_policy.required_count,
    v_pool_size + case when v_subject_decides then 1 else 0 end));
  v_subject_ok := not v_subject_decides or exists (
    select 1 from public.event_decisions d
    where d.event_id = p_event_id and d.decision = 'accept'
      and d.member_id = v_event.subject_member_id);
  v_owner_ok := not v_policy.owner_required or exists (
    select 1 from public.event_decisions d
    join public.members m on m.id = d.member_id
    where d.event_id = p_event_id and d.decision = 'accept' and m.is_owner);

  if v_accepts >= v_required and v_subject_ok and v_owner_ok then
    update public.events set status = 'confirmed', decided_at = now()
      where id = p_event_id;

    if v_event.type in ('payment','expense') then
      insert into public.ledger_entries
        (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
      values (
        v_event.workspace_id, v_event.subject_member_id, 'credit',
        case when v_event.type = 'payment' then 'payment' else 'expense' end,
        (v_event.payload->>'amount_cents')::int,
        coalesce(v_event.payload->>'note', ''),
        to_char(now(), 'YYYY-MM'),
        v_event.id
      );
    elsif v_event.type = 'service_charge' then
      insert into public.ledger_entries
        (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
      values (
        v_event.workspace_id, v_event.subject_member_id, 'charge', 'service',
        (v_event.payload->>'amount_cents')::int,
        (v_event.payload->>'name') || ' x' || (v_event.payload->>'quantity'),
        coalesce(v_event.payload->>'period', to_char(now(), 'YYYY-MM')),
        v_event.id
      );
    elsif v_event.type = 'quota' then
      insert into public.quota_extensions
        (workspace_id, member_id, period, half_days, event_id)
      values (
        v_event.workspace_id, v_event.subject_member_id,
        v_event.payload->>'period',
        (v_event.payload->>'half_days')::int,
        v_event.id
      );
    elsif v_event.type = 'role_change' then
      update public.members
        set is_admin = (v_event.payload->>'make_admin')::boolean
        where id = v_event.subject_member_id;
    elsif v_event.type = 'member_join' then
      -- the validated welcome: the pending membership becomes active
      update public.members set status = 'active'
        where id = v_event.subject_member_id and status = 'pending';
    end if;
  end if;
end;
$$;
revoke execute on function public.respond_to_event(uuid, boolean) from public, anon;

-- ---------------------------------------------------------------------
-- 5. Owner/admin quick decision from the members screen (the #107-style
--    explicit override next to the quorum path).
-- ---------------------------------------------------------------------
create or replace function public.decide_member_join(
  p_member_id uuid, p_approve boolean
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_subject public.members;
  v_actor public.members;
begin
  select * into v_subject from public.members where id = p_member_id;
  if v_subject.id is null then raise exception 'unknown member'; end if;
  if v_subject.status <> 'pending' then
    raise exception 'member is not pending';
  end if;
  select * into v_actor from public.members
    where workspace_id = v_subject.workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;

  update public.members
    set status = case when p_approve then 'active' else 'exited' end
    where id = p_member_id;
  update public.events
    set status = case when p_approve then 'confirmed' else 'rejected' end,
        decided_at = now()
    where subject_member_id = p_member_id
      and type = 'member_join' and status = 'pending';
end;
$$;
revoke execute on function public.decide_member_join(uuid, boolean) from public, anon;
