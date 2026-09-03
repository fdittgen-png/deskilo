-- Copyright (c) 2026 Florian DITTGEN
-- SPDX-License-Identifier: 0BSD
--
-- #833 — a check-out leaves a trace, and the trace is readable.
--
-- Until now a check-out closed the reservation and the month's statement
-- counted what it counted. Which reservation a line came from, how long
-- the member was actually there, whether they turned up at all, whether
-- they left early — none of it was anything a member, an admin or an
-- owner could open and read.
--
-- Three things this settles, and one of them is already true today:
--
--   * A RESERVATION THAT WAS NEVER CHECKED INTO STILL BILLS. That is
--     already the behaviour — reservation_counts_for_usage (0118) never
--     looked at checked_in_at — but nothing said so out loud. The record
--     says it: reserved minutes counted, nobody came.
--
--   * WHAT BILLS IS THE RESERVED WINDOW. Booking is the commitment; a
--     short visit is not a discount. The record keeps the actual
--     presence beside it so the two can be compared.
--
--   * AN EARLY DEPARTURE CAN BE CORRECTED, through the validation
--     framework and never by the person asking. Accepting one moves the
--     RESERVATION'S OWN END to the moment of check-out, so the statement,
--     the quota and every derived line follow with no change to the
--     billing engine at all — and the record keeps the original window,
--     so both numbers stay readable side by side.
--
-- Writing the record is a TRIGGER on reservations rather than a patch to
-- complete_check_out and kiosk_act, because there are two check-out
-- paths today and the next one would silently write no record.
--
-- ONE EXISTING BEHAVIOUR HAD TO GO. complete_check_out (0116) shrank the
-- booking to the moment of check-out — `ends_at = least(ends_at, now())`
-- — so an early departure already reduced the bill, silently, with
-- nobody asked and the booked window destroyed. That is the opposite of
-- what #833 describes, and it made this correction impossible: there
-- would be no original left to correct FROM. Check-out now records the
-- departure and leaves the booking alone. Leaving early costs what was
-- booked until somebody validates otherwise — the same rule a no-show
-- already lived under.

-- Check-out v3: record the departure, keep the commitment.
create or replace function public.complete_check_out(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_start timestamptz;
begin
  select r.* into v_res from public.reservations r where r.id = p_reservation_id;
  if v_res.id is null then return; end if;
  -- The completed row must still describe a forward-running presence: an
  -- early same-day check-in (0113) can sit BEFORE starts_at, and that
  -- widening stays. What is gone is the narrowing of ends_at.
  v_start := least(v_res.starts_at, coalesce(v_res.checked_in_at, now()));
  update public.reservations
     set status = 'completed', checked_out_at = now(), starts_at = v_start
   where id = p_reservation_id;
end;
$$;
revoke execute on function public.complete_check_out(uuid)
  from public, anon, authenticated;

create table if not exists public.usage_records (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  reservation_id uuid unique references public.reservations(id) on delete cascade,
  period text not null,
  -- The window as it was RESERVED. A correction never rewrites these.
  reserved_from timestamptz not null,
  reserved_to timestamptz not null,
  checked_in_at timestamptz,
  checked_out_at timestamptz,
  -- What bills, in minutes. Starts as the reserved window.
  counted_minutes int not null,
  reserved_minutes int not null,
  -- Time actually present; null when nobody checked in.
  actual_minutes int,
  basis text not null default 'reserved'
    check (basis in ('reserved', 'corrected')),
  corrected_from_minutes int,
  corrected_at timestamptz,
  corrected_event_id uuid references public.events(id) on delete set null,
  space_label text not null default '',
  created_at timestamptz not null default now()
);

comment on table public.usage_records is
  '#833 — one row per counted reservation: reserved window, actual '
  'presence, what bills, and how a correction changed it.';

create index if not exists usage_records_member_period_idx
  on public.usage_records (member_id, period);
create index if not exists usage_records_workspace_period_idx
  on public.usage_records (workspace_id, period);

alter table public.usage_records enable row level security;

-- Everything is written through the SECURITY DEFINER functions below;
-- the policy exists so a direct read can never see somebody else's
-- presence. Money-visibility is the same gate the statement uses.
drop policy if exists usage_records_read on public.usage_records;
create policy usage_records_read on public.usage_records
  for select using (
    exists (select 1 from public.members m
             where m.id = usage_records.member_id
               and m.user_id = auth.uid())
    or public.may_view_member_finances(usage_records.member_id));

grant select on public.usage_records to authenticated;

-- Two new decided events: the member asking for their early departure to
-- count, and an admin removing a record.
alter table public.events drop constraint if exists events_type_check;
alter table public.events add constraint events_type_check
  check (type = any (array[
    'reservation', 'payment', 'expense', 'adjustment', 'service_charge',
    'quota', 'role_change', 'member_join', 'space_reservation',
    'invoice_payment', 'reservation_delete', 'invoice_writeoff',
    'invoice_reminder', 'price_negotiation', 'expense_schedule',
    'expense_repartition', 'usage_correction', 'usage_record_delete']));

-- The policy list had drifted from the event list: 0147 rebuilt it and
-- dropped 'expense_schedule', so a rule could not be configured for a
-- type that emits events. Both lists are written here, together, from
-- the same source.
alter table public.validation_policies
  drop constraint if exists validation_policies_event_type_check;
alter table public.validation_policies
  add constraint validation_policies_event_type_check
  check (event_type is null or event_type = any (array[
    'reservation', 'payment', 'expense', 'adjustment', 'service_charge',
    'quota', 'role_change', 'member_join', 'space_reservation',
    'invoice_payment', 'reservation_delete', 'invoice_writeoff',
    'invoice_reminder', 'price_negotiation', 'expense_schedule',
    'expense_repartition', 'usage_correction', 'usage_record_delete']));

-- A deletion is the ADMIN's act on the MEMBER's record, so the member is
-- the one who decides it — the same shape a payment recorded on someone
-- else's behalf already has.
do $patch$
declare
  v_def text;
  v_new text;
  v_old constant text :=
    '  v_subject_decides := v_event.type = ''reservation''' || E'\n'
    || '    or (v_event.type in (''payment'',''service_charge'')';
  v_ins constant text :=
    '  v_subject_decides := v_event.type = ''reservation''' || E'\n'
    || '    or (v_event.type in (''payment'',''service_charge'',''usage_record_delete'')';
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'respond_to_event';
  if v_def is null then
    raise exception 'respond_to_event is missing';
  end if;
  if position('usage_record_delete' in v_def) > 0 then
    return;
  end if;
  if position(v_old in v_def) = 0 then
    raise exception 'the subject-decides rule is not where 0086 left it';
  end if;
  v_new := replace(v_def, v_old, v_ins);
  if v_new = v_def then
    raise exception 'respond_to_event did not change';
  end if;
  execute v_new;
end;
$patch$;

-- The record, written or refreshed for one reservation.
create or replace function public.upsert_usage_record(p_reservation_id uuid)
returns uuid language plpgsql security definer
set search_path = public as $$
declare
  v_res public.reservations;
  v_rules jsonb;
  v_tz text;
  v_actual int;
  v_reserved int;
  v_id uuid;
begin
  select * into v_res from public.reservations where id = p_reservation_id;
  if v_res.id is null then return null; end if;
  select booking_rules, timezone into v_rules, v_tz
    from public.workspaces where id = v_res.workspace_id;
  v_tz := coalesce(v_tz, 'UTC');
  -- The same predicate the statement and the quota use (0118): a booking
  -- that does not count for usage leaves no record either, or the two
  -- would disagree about the same month.
  if not public.reservation_counts_for_usage(
           v_res, coalesce(v_rules, '{}'::jsonb), v_tz) then
    return null;
  end if;
  if v_res.status not in ('reserved', 'checked_in', 'completed') then
    return null;
  end if;

  v_reserved := greatest(0, (extract(epoch from
    (v_res.ends_at - v_res.starts_at)) / 60)::int);
  v_actual := case
    when v_res.checked_in_at is null then null
    else greatest(0, (extract(epoch from
      (coalesce(v_res.checked_out_at, v_res.ends_at)
       - v_res.checked_in_at)) / 60)::int)
  end;

  insert into public.usage_records
    (workspace_id, member_id, reservation_id, period,
     reserved_from, reserved_to, checked_in_at, checked_out_at,
     counted_minutes, reserved_minutes, actual_minutes, space_label)
  values
    (v_res.workspace_id, v_res.member_id, v_res.id,
     to_char(v_res.starts_at at time zone v_tz, 'YYYY-MM'),
     v_res.starts_at, v_res.ends_at, v_res.checked_in_at,
     v_res.checked_out_at, v_reserved, v_reserved, v_actual,
     coalesce(v_res.space_label, ''))
  on conflict (reservation_id) do update
    set checked_in_at = excluded.checked_in_at,
        checked_out_at = excluded.checked_out_at,
        actual_minutes = excluded.actual_minutes,
        space_label = excluded.space_label,
        -- A corrected record keeps its counted time; an uncorrected one
        -- tracks the reservation, which a validated correction moves.
        counted_minutes = case
          when public.usage_records.basis = 'corrected'
            then public.usage_records.counted_minutes
          else excluded.reserved_minutes end,
        reserved_minutes = case
          when public.usage_records.basis = 'corrected'
            then public.usage_records.reserved_minutes
          else excluded.reserved_minutes end
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.usage_record_on_reservation()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  -- Presence changed, or the booking did: refresh the trace either way.
  if new.checked_in_at is distinct from old.checked_in_at
     or new.checked_out_at is distinct from old.checked_out_at
     or new.status is distinct from old.status then
    perform public.upsert_usage_record(new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists reservations_usage_record on public.reservations;
create trigger reservations_usage_record
  after update on public.reservations
  for each row execute function public.usage_record_on_reservation();

-- Backfill: every ENDED reservation of a period that has no record yet.
-- Lazy, like the pending-event sweep, so reading a month is enough to
-- make its no-shows appear.
create or replace function public.ensure_usage_records(
  p_workspace_id uuid, p_period text)
returns int language plpgsql security definer
set search_path = public as $$
declare
  v_tz text;
  v_n int := 0;
  v_res public.reservations;
begin
  select timezone into v_tz from public.workspaces where id = p_workspace_id;
  v_tz := coalesce(v_tz, 'UTC');
  for v_res in
    select r.* from public.reservations r
     where r.workspace_id = p_workspace_id
       and r.ends_at < now()
       and r.status in ('reserved', 'checked_in', 'completed')
       and to_char(r.starts_at at time zone v_tz, 'YYYY-MM') = p_period
       and not exists (select 1 from public.usage_records u
                        where u.reservation_id = r.id)
  loop
    if public.upsert_usage_record(v_res.id) is not null then
      v_n := v_n + 1;
    end if;
  end loop;
  return v_n;
end;
$$;

-- The read. One month, one member or everybody the caller may see.
create or replace function public.usage_records_for(
  p_workspace_id uuid, p_period text, p_member_id uuid default null)
returns jsonb language plpgsql security definer
set search_path = public as $$
declare
  v_me public.members;
  v_rows jsonb;
begin
  select m.* into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid()
     and m.status = 'active';
  if v_me.id is null then raise exception 'not a member'; end if;

  perform public.ensure_usage_records(p_workspace_id, p_period);

  select coalesce(jsonb_agg(to_jsonb(u) order by u.reserved_from desc),
                  '[]'::jsonb)
    into v_rows
    from public.usage_records u
   where u.workspace_id = p_workspace_id
     and u.period = p_period
     and (p_member_id is null or u.member_id = p_member_id)
     -- Own records always; anybody else's only through the money gate.
     and (u.member_id = v_me.id
          or public.may_view_member_finances(u.member_id));
  return jsonb_build_object('records', v_rows);
end;
$$;

-- "I left early — bill the time I was actually here."
create or replace function public.request_usage_correction(
  p_record_id uuid, p_reason text default '')
returns uuid language plpgsql security definer
set search_path = public as $$
declare
  v_rec public.usage_records;
  v_me public.members;
  v_has_policy boolean;
  v_event uuid;
begin
  select * into v_rec from public.usage_records where id = p_record_id;
  if v_rec.id is null then raise exception 'unknown usage record'; end if;
  select m.* into v_me from public.members m
   where m.workspace_id = v_rec.workspace_id and m.user_id = auth.uid()
     and m.status = 'active';
  if v_me.id is null then raise exception 'not a member'; end if;
  -- Only the person who was there may ask for their own presence to
  -- count. An admin correcting somebody else's time is a different act
  -- and does not exist.
  if v_me.id <> v_rec.member_id then
    raise exception 'only the member concerned may ask for this';
  end if;
  if v_rec.basis = 'corrected' then
    raise exception 'already corrected';
  end if;
  if v_rec.checked_out_at is null or v_rec.actual_minutes is null then
    raise exception 'no check-out to correct to';
  end if;
  if v_rec.actual_minutes >= v_rec.reserved_minutes then
    raise exception 'nothing to reduce';
  end if;
  if exists (select 1 from public.events e
              where e.type = 'usage_correction' and e.status = 'pending'
                and (e.payload->>'record_id')::uuid = p_record_id) then
    raise exception 'already requested';
  end if;

  v_has_policy := exists (
    select 1 from public.validation_policies vp
     where vp.workspace_id = v_rec.workspace_id
       and (vp.event_type = 'usage_correction' or vp.event_type is null));

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     reservation_id, payload, status, decided_at)
  values
    (v_rec.workspace_id, 'usage_correction', 'submitted', v_me.id, v_me.id,
     null,
     jsonb_build_object(
       'record_id', p_record_id,
       'reservation_id', v_rec.reservation_id,
       'from_minutes', v_rec.counted_minutes,
       'to_minutes', v_rec.actual_minutes,
       'reason', btrim(coalesce(p_reason, ''))),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end)
  returning id into v_event;

  -- No rule: the correction stands at once. #840 keeps the actor out of
  -- the decision either way — with a rule, somebody else decides.
  if not v_has_policy then
    perform public.apply_usage_correction(p_record_id, v_event);
  end if;
  return v_event;
end;
$$;

-- Applying one: the RESERVATION's end moves, so every aggregation that
-- already reads reservations follows without being touched.
create or replace function public.apply_usage_correction(
  p_record_id uuid, p_event_id uuid default null)
returns void language plpgsql security definer
set search_path = public as $$
declare
  v_rec public.usage_records;
begin
  select * into v_rec from public.usage_records where id = p_record_id;
  if v_rec.id is null or v_rec.basis = 'corrected' then return; end if;
  if v_rec.checked_out_at is null or v_rec.actual_minutes is null then
    return;
  end if;

  update public.usage_records
     set counted_minutes = v_rec.actual_minutes,
         corrected_from_minutes = v_rec.counted_minutes,
         basis = 'corrected',
         corrected_at = now(),
         corrected_event_id = p_event_id
   where id = p_record_id;

  -- The billed period IS the reservation. Moving its end is what makes
  -- the statement, the quota and the invoice lines agree with the record
  -- without a single one of them learning about usage records.
  if v_rec.reservation_id is not null then
    update public.reservations
       set ends_at = v_rec.checked_out_at
     where id = v_rec.reservation_id
       and ends_at > v_rec.checked_out_at;
  end if;
end;
$$;

-- An admin removing a record; the member concerned decides it when a
-- rule says so (respond_to_event's subject-decides path, patched above).
create or replace function public.request_usage_record_delete(
  p_record_id uuid, p_reason text default '')
returns uuid language plpgsql security definer
set search_path = public as $$
declare
  v_rec public.usage_records;
  v_me public.members;
  v_has_policy boolean;
  v_event uuid;
begin
  select * into v_rec from public.usage_records where id = p_record_id;
  if v_rec.id is null then raise exception 'unknown usage record'; end if;
  select m.* into v_me from public.members m
   where m.workspace_id = v_rec.workspace_id and m.user_id = auth.uid()
     and m.status = 'active';
  if v_me.id is null then raise exception 'not a member'; end if;
  if not (v_me.is_owner or v_me.is_admin) then
    raise exception 'not allowed';
  end if;

  v_has_policy := exists (
    select 1 from public.validation_policies vp
     where vp.workspace_id = v_rec.workspace_id
       and (vp.event_type = 'usage_record_delete' or vp.event_type is null));

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values
    (v_rec.workspace_id, 'usage_record_delete', 'submitted', v_me.id,
     v_rec.member_id,
     jsonb_build_object(
       'record_id', p_record_id,
       'reservation_id', v_rec.reservation_id,
       'counted_minutes', v_rec.counted_minutes,
       'reason', btrim(coalesce(p_reason, ''))),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end)
  returning id into v_event;

  if not v_has_policy then
    delete from public.usage_records where id = p_record_id;
  end if;
  return v_event;
end;
$$;

create or replace function public.apply_usage_decision()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  if new.status = old.status then return new; end if;
  if new.type = 'usage_correction' and new.status = 'confirmed' then
    perform public.apply_usage_correction(
      (new.payload->>'record_id')::uuid, new.id);
  elsif new.type = 'usage_record_delete' and new.status = 'confirmed' then
    delete from public.usage_records
     where id = (new.payload->>'record_id')::uuid;
  end if;
  return new;
end;
$$;

drop trigger if exists events_apply_usage on public.events;
create trigger events_apply_usage
  after update on public.events
  for each row execute function public.apply_usage_decision();

revoke execute on function public.upsert_usage_record(uuid) from public, anon, authenticated;
revoke execute on function public.apply_usage_correction(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.ensure_usage_records(uuid, text) from public, anon, authenticated;
grant execute on function public.usage_records_for(uuid, text, uuid) to authenticated;
grant execute on function public.request_usage_correction(uuid, text) to authenticated;
grant execute on function public.request_usage_record_delete(uuid, text) to authenticated;
