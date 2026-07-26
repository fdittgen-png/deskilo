-- SPDX-License-Identifier: 0BSD
-- Co-owners. NOT YET applied to the hosted reference project — the
-- orchestrator applies it after review.
--
-- Field request: a member/admin can become a CO-OWNER.
--   · ACTIVE co-owner — owner permissions NOW (is_owner_of counts them,
--     so every owner-gated RPC accepts them), plus automatic
--     succession.
--   · PASSIVE co-owner — no extra permissions; becomes owner when the
--     owner activates them (activate_co_owner) or when the last owner
--     leaves (succession below).
-- Succession lives INSIDE protect_last_owner: where the guard used to
-- refuse removing the last owner, it now first promotes the best
-- co-owner (active before passive) and lets the owner go — a workspace
-- never loses its last owner AND an owner with a co-owner can leave.
-- Deliberate exception: validation "owner sign-off" quorum rules keep
-- meaning LITERAL owners.

-- 1. The role flavor.
alter table public.members
  add column if not exists co_owner text not null default 'none'
    check (co_owner in ('none', 'active', 'passive'));

-- 2. Active co-owners pass every owner gate that flows through the
-- helper (that is: almost all of them).
create or replace function public.is_owner_of(ws uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members m
    where m.workspace_id = ws and m.user_id = auth.uid()
      and m.status = 'active' and (m.is_owner or m.co_owner = 'active')
  );
$$;

-- 3. Succession in the last-owner guard.
create or replace function public.protect_last_owner()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  remaining int;
  v_successor uuid;
begin
  if old.is_owner and old.status = 'active'
     and (tg_op = 'DELETE' or (not new.is_owner or new.status <> 'active')) then
    select count(*) into remaining from public.members
    where workspace_id = old.workspace_id and is_owner and status = 'active' and id <> old.id;
    if remaining = 0 then
      -- Promote the best co-owner: active first, then passive; oldest
      -- appointment order is not tracked, so id keeps it deterministic.
      select id into v_successor from public.members
        where workspace_id = old.workspace_id and status = 'active'
          and id <> old.id and co_owner <> 'none'
        order by (co_owner = 'active') desc, id
        limit 1;
      if v_successor is null then
        raise exception 'cannot remove the last owner of a workspace';
      end if;
      update public.members
        set is_owner = true, is_admin = true, co_owner = 'none'
        where id = v_successor;
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

-- 4. Appoint / change / clear a co-owner. Owner-gated via the extended
-- helper, so an active co-owner can manage co-owners too ("same
-- permissions as the owner").
create or replace function public.set_co_owner(
  p_member_id uuid, p_status text
) returns void language plpgsql security definer set search_path = public as $$
declare v_subject public.members;
begin
  if p_status not in ('none', 'active', 'passive') then
    raise exception 'unknown co-owner status';
  end if;
  select * into v_subject from public.members where id = p_member_id;
  if v_subject.id is null then raise exception 'unknown member'; end if;
  if not public.is_owner_of(v_subject.workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  if v_subject.is_owner then
    raise exception 'owners need no co-owner status';
  end if;
  if v_subject.is_kiosk then raise exception 'a kiosk cannot co-own'; end if;
  if v_subject.status <> 'active' then
    raise exception 'not an active member';
  end if;
  update public.members
    set co_owner = p_status,
        -- Owner permissions NOW: the active flavor also joins the admin
        -- surfaces its new rights operate through.
        is_admin = case when p_status = 'active' then true else is_admin end
    where id = p_member_id;
end;
$$;
revoke execute on function public.set_co_owner(uuid, text) from public, anon;

-- 5. "The owner activates it": a co-owner (active or passive) becomes a
-- FULL owner right now, alongside the current owner.
create or replace function public.activate_co_owner(p_member_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_subject public.members;
begin
  select * into v_subject from public.members where id = p_member_id;
  if v_subject.id is null then raise exception 'unknown member'; end if;
  if not public.is_owner_of(v_subject.workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  if v_subject.co_owner = 'none' then
    raise exception 'not a co-owner';
  end if;
  if v_subject.status <> 'active' then
    raise exception 'not an active member';
  end if;
  update public.members
    set is_owner = true, is_admin = true, co_owner = 'none'
    where id = p_member_id;
end;
$$;
revoke execute on function public.activate_co_owner(uuid) from public, anon;

-- 6. The two owner gates that check is_owner INLINE instead of through
-- the helper now accept active co-owners too.
create or replace function public.set_member_kiosk(p_member_id uuid, p_is_kiosk boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_member public.members;
begin
  select * into v_member from public.members where id = p_member_id;
  if v_member.id is null then raise exception 'unknown member'; end if;
  if not public.is_owner_of(v_member.workspace_id) then
    raise exception 'not the owner of this workspace';
  end if;
  if v_member.is_owner then raise exception 'the owner cannot be a kiosk'; end if;
  if v_member.co_owner <> 'none' then
    raise exception 'a co-owner cannot be a kiosk';
  end if;
  update public.members set is_kiosk = p_is_kiosk where id = p_member_id;
end;
$$;
revoke execute on function public.set_member_kiosk(uuid, boolean) from public, anon;

-- 7. admin_create_reservation_for v4: the level-assign OWNER bypass
-- accepts active co-owners (0050 body, one guard widened).
create or replace function public.admin_create_reservation_for(
  p_workspace_id uuid,
  p_subject_member_id uuid,
  p_seat_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_level_id uuid default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_res_id uuid;
  v_event_id uuid;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not exists (
    select 1 from public.members
    where id = p_subject_member_id and workspace_id = p_workspace_id and status = 'active'
  ) then raise exception 'unknown subject member'; end if;
  if (p_seat_id is null) = (p_level_id is null) then
    raise exception 'exactly one of seat or level required';
  end if;
  perform public.enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at);

  if p_level_id is not null then
    if not public.level_booking_enabled(p_workspace_id) then
      raise exception 'level booking is not enabled';
    end if;
    if not (v_actor.is_owner or v_actor.co_owner = 'active')
       and not coalesce(
      (select w.feature_flags -> 'adminLevelAssign' = to_jsonb(true)
         from public.workspaces w where w.id = p_workspace_id), false) then
      raise exception 'admins may not assign level reservations here';
    end if;
    if not exists (
      select 1 from public.levels l
      where l.id = p_level_id and l.workspace_id = p_workspace_id
        and l.bookable_as_whole
    ) then
      raise exception 'level not bookable as a whole';
    end if;
    if public.level_has_conflict(p_level_id, p_starts_at, p_ends_at) then
      raise exception 'the level has reservations in that period';
    end if;
  else
    perform public.assert_seat_not_blocked(p_seat_id, p_starts_at, p_ends_at);
  end if;

  insert into public.reservations
    (workspace_id, seat_id, level_id, member_id, starts_at, ends_at, status)
  values (p_workspace_id, p_seat_id, p_level_id, p_subject_member_id,
          p_starts_at, p_ends_at, 'reserved')
  returning id into v_res_id;
  perform public.assert_member_quota(p_subject_member_id, p_starts_at);

  update public.events set actor_member_id = v_actor.id, status = 'pending'
    where reservation_id = v_res_id and action = 'created';

  select id into v_event_id from public.events
    where reservation_id = v_res_id and action = 'created';
  return v_event_id;
end;
$$;
