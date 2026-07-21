-- SPDX-License-Identifier: 0BSD
-- Kiosk devices + member badges (epic: wall-mounted tablet mode). NOT YET
-- applied to the hosted reference project — the orchestrator applies it
-- after review.
--
-- A KIOSK is a dedicated member account signed in permanently on a
-- wall-mounted tablet. Its app locks to the plan view; it can see
-- occupancy but never act as itself. A real member acts THROUGH the kiosk
-- by presenting a BADGE (QR/barcode or NFC tag): the kiosk calls
-- kiosk_act with the badge's one-time-issued secret token, the server
-- resolves the member and performs the reserve/check-in/check-out AS that
-- member — stateless, so there is nothing to sign out of and nothing is
-- ever cached on the device.
--
-- Badge tokens are generated server-side and returned RAW exactly once
-- (the QR the owner prints / the member shows); the server stores only
-- the SHA-256 hash.

-- 1. the kiosk member type
alter table public.members
  add column is_kiosk boolean not null default false;

-- 2. badges
create table public.member_badges (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  token_hash text not null unique,
  label text not null default '' check (char_length(label) <= 60),
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);
create index member_badges_member_idx on public.member_badges (member_id);

alter table public.member_badges enable row level security;
-- admins manage badges; a member sees their own (their profile shows the
-- badge QR). No direct writes — issuing goes through the RPC so the raw
-- token is minted server-side.
create policy member_badges_select on public.member_badges
  for select using (
    public.is_admin_of(workspace_id)
    or exists (select 1 from public.members m
                where m.id = member_id and m.user_id = auth.uid())
  );

-- Pure hashing helper (fully-qualified extension call, no definer needed).
create or replace function public.badge_token_hash(p_token text)
returns text language sql immutable set search_path = public as $$
  select encode(extensions.digest(p_token, 'sha256'), 'hex');
$$;
revoke execute on function public.badge_token_hash(text) from public, anon;

-- 3. issue / revoke (owner or admin)
create or replace function public.issue_member_badge(
  p_workspace_id uuid, p_member_id uuid, p_label text default ''
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_token text;
  v_id uuid;
begin
  if not public.is_admin_of(p_workspace_id) then
    raise exception 'not an admin of this workspace';
  end if;
  if not exists (select 1 from public.members
                  where id = p_member_id and workspace_id = p_workspace_id
                    and status = 'active' and not is_kiosk) then
    raise exception 'unknown member';
  end if;
  -- 32 random bytes, hex — shown once as the badge QR payload.
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.member_badges (workspace_id, member_id, token_hash, label)
  values (p_workspace_id, p_member_id, public.badge_token_hash(v_token),
          coalesce(p_label, ''))
  returning id into v_id;
  return jsonb_build_object('badge_id', v_id, 'token', v_token);
end;
$$;
revoke execute on function public.issue_member_badge(uuid, uuid, text) from public, anon;

create or replace function public.revoke_member_badge(p_badge_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_ws uuid;
begin
  select workspace_id into v_ws from public.member_badges where id = p_badge_id;
  if v_ws is null then raise exception 'unknown badge'; end if;
  if not public.is_admin_of(v_ws) then
    raise exception 'not an admin of this workspace';
  end if;
  update public.member_badges set revoked_at = now()
    where id = p_badge_id and revoked_at is null;
end;
$$;
revoke execute on function public.revoke_member_badge(uuid) from public, anon;

-- 4. the kiosk toggle (owner-only, like the subscription update path the
-- members screen uses — plain UPDATE under owner RLS would also work, but
-- the RPC keeps the invariant that a kiosk holds no badges/bookings roles)
create or replace function public.set_member_kiosk(
  p_member_id uuid, p_is_kiosk boolean
) returns void language plpgsql security definer set search_path = public as $$
declare v_member public.members;
begin
  select * into v_member from public.members where id = p_member_id;
  if v_member.id is null then raise exception 'unknown member'; end if;
  if not exists (select 1 from public.members
                  where workspace_id = v_member.workspace_id
                    and user_id = auth.uid() and is_owner and status = 'active') then
    raise exception 'not the owner of this workspace';
  end if;
  if v_member.is_owner then raise exception 'the owner cannot be a kiosk'; end if;
  update public.members set is_kiosk = p_is_kiosk where id = p_member_id;
end;
$$;
revoke execute on function public.set_member_kiosk(uuid, boolean) from public, anon;

-- 5. kiosk_act: a kiosk performs one action AS the badge's member.
-- Stateless per call — the "session" begins and ends inside this function,
-- which is what "automatically checked out once the operation is done"
-- means server-side. Seat-level actions only (wall tablets don't book
-- whole offices).
create or replace function public.kiosk_act(
  p_workspace_id uuid,
  p_badge_token text,
  p_action text,             -- 'reserve' | 'check_in' | 'check_out'
  p_seat_id uuid default null,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_kiosk public.members;
  v_badge public.member_badges;
  v_subject public.members;
  v_seat public.seats;
  v_office_id uuid;
  v_res public.reservations;
  v_id uuid;
begin
  -- caller must be an active kiosk member of this workspace
  select * into v_kiosk from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active' and is_kiosk;
  if v_kiosk.id is null then raise exception 'not a kiosk of this workspace'; end if;

  -- resolve the badge → subject member
  select * into v_badge from public.member_badges
    where workspace_id = p_workspace_id
      and token_hash = public.badge_token_hash(p_badge_token)
      and revoked_at is null;
  if v_badge.id is null then
    -- the client pins this substring
    raise exception 'badge not recognized';
  end if;
  select * into v_subject from public.members
    where id = v_badge.member_id and status = 'active';
  if v_subject.id is null then raise exception 'badge member not active'; end if;

  if p_action = 'check_out' then
    -- complete the subject's current checked-in reservation (on the seat
    -- when given, else whichever is active).
    select r.* into v_res from public.reservations r
      where r.member_id = v_subject.id and r.status = 'checked_in'
        and (p_seat_id is null or r.seat_id = p_seat_id)
      order by r.checked_in_at desc limit 1;
    if v_res.id is null then raise exception 'not checked in'; end if;
    update public.reservations
      set status = 'completed', checked_out_at = now(),
          ends_at = least(ends_at, now())
      where id = v_res.id;
    return jsonb_build_object('action', 'check_out', 'reservation_id', v_res.id);
  end if;

  if p_action not in ('reserve', 'check_in') then
    raise exception 'unknown kiosk action';
  end if;
  if p_seat_id is null or p_starts_at is null or p_ends_at is null then
    raise exception 'seat and window required';
  end if;

  select * into v_seat from public.seats
    where id = p_seat_id and workspace_id = p_workspace_id;
  if v_seat.id is null then raise exception 'unknown seat'; end if;

  if p_action = 'check_in' then
    -- an existing reserved booking covering now checks in instead of
    -- creating a duplicate walk-up
    select r.* into v_res from public.reservations r
      where r.member_id = v_subject.id and r.seat_id = p_seat_id
        and r.status = 'reserved'
        and r.starts_at <= now() and r.ends_at > now()
      limit 1;
    if v_res.id is not null then
      update public.reservations
        set status = 'checked_in', checked_in_at = now()
        where id = v_res.id;
      return jsonb_build_object('action', 'check_in', 'reservation_id', v_res.id);
    end if;
  end if;

  -- fresh booking (reserve, or walk-up check-in): same guards as
  -- create_reservation's seat path
  perform public.enforce_booking_rules(
    p_workspace_id, p_starts_at, p_ends_at, p_action = 'check_in');
  if tstzrange(coalesce(v_seat.blocked_from, '-infinity'::timestamptz),
               coalesce(v_seat.blocked_to, 'infinity'::timestamptz))
     && tstzrange(p_starts_at, p_ends_at)
     and (v_seat.blocked_from is not null or v_seat.blocked_to is not null) then
    raise exception 'seat is blocked in that period';
  end if;
  select d.office_id into v_office_id from public.desks d where d.id = v_seat.desk_id;
  if exists (
    select 1 from public.reservations r
    where r.office_id = v_office_id
      and r.status in ('reserved','checked_in')
      and tstzrange(r.starts_at, r.ends_at) && tstzrange(p_starts_at, p_ends_at)
  ) then
    raise exception 'office is reserved as a whole in that period';
  end if;

  insert into public.reservations
    (workspace_id, seat_id, member_id, starts_at, ends_at, status, checked_in_at)
  values (
    p_workspace_id, p_seat_id, v_subject.id, p_starts_at, p_ends_at,
    case when p_action = 'check_in' then 'checked_in' else 'reserved' end,
    case when p_action = 'check_in' then now() end
  )
  returning id into v_id;
  perform public.assert_member_quota(v_subject.id, p_starts_at);
  return jsonb_build_object('action', p_action, 'reservation_id', v_id);
end;
$$;
revoke execute on function public.kiosk_act(uuid, text, text, uuid, timestamptz, timestamptz)
  from public, anon;
