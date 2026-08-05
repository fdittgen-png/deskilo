-- SPDX-License-Identifier: 0BSD
-- Deleting a PAST or CHECKED-IN reservation is a REQUEST, not an action
-- (#492): the member asks, an owner/admin decides — was the check-in
-- forgotten (keep it, it was attended) or was the booking simply unused
-- (confirm, it disappears)? Future untouched bookings keep the direct
-- cancel. Routed through the events spine as a new 'reservation_delete'
-- type under the standard validation policy.
--
-- The event deliberately does NOT set events.reservation_id: on that
-- column a REJECT cancels the reservation (the 0007 tentative-booking
-- contract) — here reject must KEEP it. The id travels in the payload.

alter table public.events drop constraint events_type_check;
alter table public.events add constraint events_type_check check (type in
  ('reservation','payment','expense','adjustment','service_charge',
   'quota','role_change','member_join','space_reservation',
   'invoice_payment','reservation_delete'));

create or replace function public.request_reservation_deletion(
  p_reservation_id uuid, p_reason text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_member public.members;
  v_id uuid;
begin
  select * into v_res from public.reservations where id = p_reservation_id;
  if v_res.id is null then raise exception 'unknown reservation'; end if;
  select * into v_member from public.members
    where workspace_id = v_res.workspace_id and user_id = auth.uid()
      and status = 'active';
  if v_member.id is null then raise exception 'not an active member'; end if;
  if v_res.member_id <> v_member.id then
    raise exception 'only your own reservation';
  end if;
  if v_res.status not in ('reserved','checked_in','completed') then
    raise exception 'nothing to delete';
  end if;
  if v_res.status = 'reserved' and v_res.starts_at > now() then
    raise exception 'cancel directly — this booking has not started';
  end if;
  if exists (select 1 from public.events
              where type = 'reservation_delete' and status = 'pending'
                and (payload->>'reservation_id')::uuid = p_reservation_id) then
    raise exception 'deletion already requested';
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status)
  values (
    v_res.workspace_id, 'reservation_delete', 'submitted',
    v_member.id, v_member.id,
    jsonb_build_object(
      'reservation_id', v_res.id,
      'starts_at', v_res.starts_at,
      'ends_at', v_res.ends_at,
      'was_checked_in', v_res.status <> 'reserved',
      'reason', left(coalesce(p_reason, ''), 300)
    ),
    'pending'
  )
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function
  public.request_reservation_deletion(uuid, text) from public, anon;

-- respond_to_event v-next: the 0086 body verbatim + the
-- reservation_delete apply branch (confirm → the booking is cancelled;
-- reject → nothing happens, the booking stays and bills).
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
    -- #434 (owner rule): NOBODY validates their own event — the #107
    -- solo escape hatch (actor admitted when the pool was empty) is
    -- gone. A pool that collapses to the actor leaves the event pending
    -- until it expires: never granted silently, never self-granted.
    and v_caller.id <> v_event.actor_member_id;
  if v_pool_size = 0
     and v_caller.id <> v_event.actor_member_id
     and (v_caller.is_owner or (v_caller.is_admin and v_policy.admins_may_validate)) then
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
      update public.members set status = 'exited'
        where id = v_event.subject_member_id and status = 'pending';
    end if;
    if v_event.type = 'invoice_payment' then
      delete from public.ledger_entries
        where id = (select credit_ledger_id from public.invoice_matches
                     where event_id = v_event.id);
      delete from public.invoice_matches where event_id = v_event.id;
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
      -- 0070: the payer's own date and target month when the payload
      -- carries them; the old behaviour (today, current month) when not.
      insert into public.ledger_entries
        (workspace_id, member_id, kind, category, amount_cents, description,
         period, event_id, occurred_on)
      values (
        v_event.workspace_id, v_event.subject_member_id, 'credit',
        case when v_event.type = 'payment' then 'payment' else 'expense' end,
        (v_event.payload->>'amount_cents')::int,
        coalesce(v_event.payload->>'note', ''),
        coalesce(v_event.payload->>'period', to_char(now(), 'YYYY-MM')),
        v_event.id,
        (v_event.payload->>'paid_on')::date
      );
    elsif v_event.type = 'service_charge' then
      insert into public.ledger_entries
        (workspace_id, member_id, kind, category, amount_cents, description,
         period, event_id, vat_percent)
      values (
        v_event.workspace_id, v_event.subject_member_id, 'charge', 'service',
        (v_event.payload->>'amount_cents')::int,
        (v_event.payload->>'name') || ' x' || (v_event.payload->>'quantity'),
        coalesce(v_event.payload->>'period', to_char(now(), 'YYYY-MM')),
        v_event.id,
        (v_event.payload->>'vat_percent')::numeric
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
    elsif v_event.type = 'invoice_payment' then
      update public.invoice_matches set status = 'confirmed'
        where event_id = v_event.id;
    elsif v_event.type = 'reservation_delete' then
      -- #492 — the validated deletion: the booking is cancelled and no
      -- longer bills; a forgotten check-in that was ATTENDED should be
      -- rejected instead, keeping the booking on the record.
      update public.reservations set status = 'cancelled'
        where id = (v_event.payload->>'reservation_id')::uuid
          and status in ('reserved','checked_in','completed');
    end if;
  end if;
end;
$$;
