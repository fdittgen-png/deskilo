-- SPDX-License-Identifier: MIT
-- DesKilo service consumption on the monthly bill (epic #121 task 5,
-- issue #129, ADR 0008). Members self-report consumed services; admins/
-- owner add for any member. A pending 'service_charge' event carries a
-- name+price snapshot; the ledger charge posts only on confirmation.
-- Decider (single-confirmer protocol, quorum arrives in 0017):
--   member self-reports  -> an admin decides (no self-approval, #107
--                           solo-admin escape hatch applies)
--   admin adds for member -> the member (subject) decides

alter table public.events drop constraint events_type_check;
alter table public.events add constraint events_type_check
  check (type in ('reservation','payment','expense','adjustment','service_charge'));

alter table public.ledger_entries drop constraint ledger_entries_category_check;
alter table public.ledger_entries add constraint ledger_entries_category_check
  check (category in ('subscription','overage','expense','payment','adjustment','service'));

create or replace function public.record_service_charge(
  p_workspace_id uuid,
  p_subject_member_id uuid,
  p_service_id uuid,
  p_quantity int,
  p_period text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_service public.services;
  v_period text;
  v_event_id uuid;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if v_actor.id <> p_subject_member_id and not (v_actor.is_admin or v_actor.is_owner) then
    raise exception 'only admins may add services for other members';
  end if;
  if not exists (
    select 1 from public.members
    where id = p_subject_member_id and workspace_id = p_workspace_id and status = 'active'
  ) then raise exception 'unknown subject member'; end if;

  select * into v_service from public.services
    where id = p_service_id and workspace_id = p_workspace_id;
  if v_service.id is null then raise exception 'unknown service'; end if;
  if not v_service.active then raise exception 'service is inactive'; end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 999 then
    raise exception 'quantity must be between 1 and 999';
  end if;
  v_period := coalesce(p_period, to_char(now(), 'YYYY-MM'));
  if v_period !~ '^\d{4}-\d{2}$' then raise exception 'period must be YYYY-MM'; end if;

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'service_charge', 'submitted', v_actor.id, p_subject_member_id,
    jsonb_build_object(
      'service_id', v_service.id,
      'name', v_service.name,
      'price_cents', v_service.price_cents,
      'quantity', p_quantity,
      'amount_cents', v_service.price_cents * p_quantity,
      'period', v_period
    ),
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$$;
revoke execute on function public.record_service_charge(uuid, uuid, uuid, int, text) from public, anon;

-- respond_to_event learns 'service_charge' (0011 body otherwise kept):
-- self-reported charges need an admin, admin-added ones need the subject;
-- on accept the ledger gets a CHARGE (kind) in category 'service' for the
-- snapshot amount, booked to the payload period.
create or replace function public.respond_to_event(
  p_event_id uuid,
  p_accept boolean
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_event public.events;
  v_caller public.members;
  v_needs_admin boolean;
  v_other_admin boolean;
begin
  select e.* into v_event from public.events e where e.id = p_event_id;
  if v_event.id is null then raise exception 'unknown event'; end if;
  if v_event.status <> 'pending' then raise exception 'already decided'; end if;

  select m.* into v_caller from public.members m
    where m.workspace_id = v_event.workspace_id and m.user_id = auth.uid()
      and m.status = 'active';
  if v_caller.id is null then raise exception 'not a member'; end if;

  v_needs_admin := v_event.type = 'expense'
    or (v_event.type in ('payment','service_charge')
        and v_event.actor_member_id = v_event.subject_member_id);

  if v_needs_admin then
    if not (v_caller.is_admin or v_caller.is_owner) then
      raise exception 'an admin must decide this event';
    end if;
    if v_caller.id = v_event.actor_member_id then
      select exists (
        select 1 from public.members m
        where m.workspace_id = v_event.workspace_id
          and m.status = 'active' and (m.is_admin or m.is_owner)
          and m.id <> v_caller.id
      ) into v_other_admin;
      if v_other_admin then
        raise exception 'another admin must decide this event';
      end if;
      -- solo-admin workspace: self-decision allowed (documented, #107)
    end if;
  else
    if v_caller.id <> v_event.subject_member_id then
      raise exception 'not the subject of this event';
    end if;
  end if;

  update public.events
    set status = case when p_accept then 'confirmed' else 'rejected' end,
        decided_at = now()
    where id = p_event_id;

  if not p_accept and v_event.reservation_id is not null then
    update public.reservations set status = 'cancelled'
      where id = v_event.reservation_id and status in ('reserved','checked_in');
  end if;

  if p_accept and v_event.type in ('payment','expense') then
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
  end if;

  if p_accept and v_event.type = 'service_charge' then
    insert into public.ledger_entries
      (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
    values (
      v_event.workspace_id, v_event.subject_member_id, 'charge', 'service',
      (v_event.payload->>'amount_cents')::int,
      (v_event.payload->>'name') || ' x' || (v_event.payload->>'quantity'),
      coalesce(v_event.payload->>'period', to_char(now(), 'YYYY-MM')),
      v_event.id
    );
  end if;
end;
$$;
revoke execute on function public.respond_to_event(uuid, boolean) from public, anon;
