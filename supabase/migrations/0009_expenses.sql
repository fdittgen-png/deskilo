-- SPDX-License-Identifier: MIT
-- DesKilo community expenses (Epic #8, issue #66, spec §9). Applied to the
-- hosted reference project on 2026-07-07.

-- Purchaser submits; another admin approves; approval credits the ledger.
create or replace function public.submit_expense(
  p_workspace_id uuid,
  p_amount_cents int,
  p_category text,
  p_description text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_event_id uuid;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if p_amount_cents <= 0 then raise exception 'amount must be positive'; end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'expense', 'submitted', v_actor.id, v_actor.id,
    jsonb_build_object(
      'amount_cents', p_amount_cents,
      'category', p_category,
      'note', p_description
    ),
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$$;

-- respond_to_event v3: expenses behave like self-recorded payments — the
-- OTHER side (an admin who is not the submitter) decides; approval posts
-- the ledger credit (category expense).
create or replace function public.respond_to_event(
  p_event_id uuid,
  p_accept boolean
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_event public.events;
  v_caller public.members;
  v_needs_admin boolean;
begin
  select e.* into v_event from public.events e where e.id = p_event_id;
  if v_event.id is null then raise exception 'unknown event'; end if;
  if v_event.status <> 'pending' then raise exception 'already decided'; end if;

  select m.* into v_caller from public.members m
    where m.workspace_id = v_event.workspace_id and m.user_id = auth.uid()
      and m.status = 'active';
  if v_caller.id is null then raise exception 'not a member'; end if;

  v_needs_admin := v_event.type = 'expense'
    or (v_event.type = 'payment' and v_event.actor_member_id = v_event.subject_member_id);

  if v_needs_admin then
    -- the other side = an admin who is not the submitter (no self-approval)
    if not (v_caller.is_admin or v_caller.is_owner) or v_caller.id = v_event.actor_member_id then
      raise exception 'another admin must decide this event';
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
end;
$$;

revoke execute on function public.submit_expense(uuid, int, text, text) from public, anon;
revoke execute on function public.respond_to_event(uuid, boolean) from public, anon;
