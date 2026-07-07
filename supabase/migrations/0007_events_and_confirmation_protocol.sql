-- SPDX-License-Identifier: MIT
-- DesKilo events + confirmation protocol (Epic #6, issue #56, spec §8).
-- Applied to the hosted reference project on 2026-07-07.

create table public.events (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  type text not null check (type in ('reservation','payment','expense','adjustment')),
  action text not null check (action in ('created','modified','cancelled','submitted','approved','rejected')),
  actor_member_id uuid not null references public.members(id) on delete restrict,
  subject_member_id uuid not null references public.members(id) on delete restrict,
  reservation_id uuid references public.reservations(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  -- 'applied' events need no confirmation (self-service or already decided)
  status text not null default 'applied'
    check (status in ('applied','pending','confirmed','rejected','expired')),
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create index events_workspace_created_idx on public.events (workspace_id, created_at desc);
create index events_subject_idx on public.events (subject_member_id);
create index events_pending_idx on public.events (workspace_id) where status = 'pending';

alter table public.events enable row level security;
-- workers see events they act in or are subject of; admins see all
create policy events_select on public.events
  for select using (
    public.is_admin_of(workspace_id)
    or exists (
      select 1 from public.members m
      where m.user_id = auth.uid()
        and m.id in (events.actor_member_id, events.subject_member_id)
    )
  );
-- writes via RPCs / triggers only

-- Audit feed: every self-service reservation action emits an applied event.
create or replace function public.log_reservation_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_action text;
begin
  if tg_op = 'INSERT' then
    v_action := 'created';
  elsif new.status = 'cancelled' and old.status <> 'cancelled' then
    v_action := 'cancelled';
  elsif new.status <> old.status or new.ends_at <> old.ends_at then
    v_action := 'modified';
  else
    return new;
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     reservation_id, payload, status)
  values
    (new.workspace_id, 'reservation', v_action, new.member_id, new.member_id,
     new.id,
     jsonb_build_object(
       'starts_at', new.starts_at, 'ends_at', new.ends_at,
       'status', new.status, 'seat_id', new.seat_id, 'office_id', new.office_id
     ),
     'applied');
  return new;
end;
$$;
create trigger reservations_log_event
after insert or update on public.reservations
for each row execute function public.log_reservation_event();
revoke execute on function public.log_reservation_event() from public, anon, authenticated;

-- Admin books FOR someone else: pending event + tentative reservation that
-- blocks the seat until the subject decides (spec §8.2).
create or replace function public.admin_create_reservation_for(
  p_workspace_id uuid,
  p_subject_member_id uuid,
  p_seat_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz
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
  perform public.enforce_booking_rules(p_workspace_id, p_starts_at, p_ends_at);

  -- tentative reservation: blocks the slot (exclusion constraint applies)
  insert into public.reservations
    (workspace_id, seat_id, member_id, starts_at, ends_at, status)
  values (p_workspace_id, p_seat_id, p_subject_member_id, p_starts_at, p_ends_at, 'reserved')
  returning id into v_res_id;

  -- the trigger just logged an 'applied' created event attributed to the
  -- subject; repoint that audit line to the actor and park the decision
  update public.events set actor_member_id = v_actor.id, status = 'pending'
    where reservation_id = v_res_id and action = 'created';

  select id into v_event_id from public.events
    where reservation_id = v_res_id and action = 'created';
  return v_event_id;
end;
$$;

-- Subject accepts or rejects a pending event (spec §8.2).
create or replace function public.respond_to_event(
  p_event_id uuid,
  p_accept boolean
) returns void language plpgsql security definer set search_path = public as $$
declare v_event public.events;
begin
  select e.* into v_event from public.events e
    join public.members m on m.id = e.subject_member_id
    where e.id = p_event_id and m.user_id = auth.uid();
  if v_event.id is null then raise exception 'not the subject of this event'; end if;
  if v_event.status <> 'pending' then raise exception 'already decided'; end if;

  update public.events
    set status = case when p_accept then 'confirmed' else 'rejected' end,
        decided_at = now()
    where id = p_event_id;

  if not p_accept and v_event.reservation_id is not null then
    -- void the tentative reservation, freeing the seat
    update public.reservations set status = 'cancelled'
      where id = v_event.reservation_id and status in ('reserved','checked_in');
  end if;
end;
$$;

-- Timeout sweep (spec §8.2): after 7 days pending non-destructive events
-- auto-confirm; destructive/debit events auto-expire. Invoked lazily by
-- clients when they fetch events (cheap, idempotent) until Epic #9 adds a
-- scheduled runner.
create or replace function public.sweep_pending_events(p_workspace_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_member_of(p_workspace_id) then
    raise exception 'not a member';
  end if;
  -- non-destructive (creations/modifications): auto-confirm
  update public.events
    set status = 'confirmed', decided_at = now()
    where workspace_id = p_workspace_id and status = 'pending'
      and action in ('created','modified')
      and created_at < now() - interval '7 days';
  -- destructive (cancellations) or debits: auto-expire and undo tentative
  update public.reservations r set status = 'cancelled'
    from public.events e
    where e.workspace_id = p_workspace_id and e.status = 'pending'
      and e.action not in ('created','modified')
      and e.created_at < now() - interval '7 days'
      and r.id = e.reservation_id and r.status in ('reserved','checked_in');
  update public.events
    set status = 'expired', decided_at = now()
    where workspace_id = p_workspace_id and status = 'pending'
      and action not in ('created','modified')
      and created_at < now() - interval '7 days';
end;
$$;

revoke execute on function public.admin_create_reservation_for(uuid, uuid, uuid, timestamptz, timestamptz) from public, anon;
revoke execute on function public.respond_to_event(uuid, boolean) from public, anon;
revoke execute on function public.sweep_pending_events(uuid) from public, anon;
