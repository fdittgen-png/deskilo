-- SPDX-License-Identifier: 0BSD
-- DesKilo #107: solo-admin escape hatch, applied 2026-07-08. Expenses /
-- self-recorded payments are decided by ANOTHER admin (spec §9
-- no-self-approval) — but when the actor is the only active admin in the
-- workspace, that rule deadlocks; then the actor may decide their own event.
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
    or (v_event.type = 'payment' and v_event.actor_member_id = v_event.subject_member_id);

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
end;
$$;
revoke execute on function public.respond_to_event(uuid, boolean) from public, anon;
