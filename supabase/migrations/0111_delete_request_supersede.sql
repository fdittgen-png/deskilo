-- SPDX-License-Identifier: 0BSD
-- #562: re-requesting a deletion SUPERSEDES the pending request instead
-- of erroring. 0097 raised 'deletion already requested' — but from the
-- member's side a second demand means "my reason changed / nobody
-- reacted, ask again". The old pending event now EXPIRES (validators'
-- pending lists drop it, the audit trail keeps it) and a fresh event is
-- inserted — which re-fires the 0012 pending-event notification, so the
-- validators are pinged again. Body regenerated from 0097 with only
-- that guard replaced.

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
  -- #562: supersede, don't refuse — the fresh insert below re-triggers
  -- the validator notification.
  update public.events
     set status = 'expired'
   where type = 'reservation_delete' and status = 'pending'
     and (payload->>'reservation_id')::uuid = p_reservation_id;
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
