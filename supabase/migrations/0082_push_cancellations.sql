-- SPDX-License-Identifier: 0BSD
-- Push for cancellations/overrules (#424). The 0012 pipeline pushes only
-- PENDING confirmations; an admin overruling a reservation (0079) left
-- the displaced member unnotified-by-push. Two obstacles fixed here:
--
--  * The 0007 log trigger stamps the CANCELLED event with
--    actor = the row's member — an overrule looked like a self-cancel.
--    cancel_reservation v3 re-attributes the event to the true actor
--    right after the cancel (the log trigger has already run, in the
--    same statement chain).
--  * notify_pending_event v2 grows a cancellation branch: when a
--    reservation event says cancelled BY SOMEONE ELSE, the displaced
--    member and every admin/owner (minus the actor) get a generic
--    {"kind":"reservation_cancelled"} ping — no names, no times, the
--    client localizes (0012 privacy doctrine). The trigger also fires
--    on actor_member_id updates, which is exactly the re-attribution.

-- 1. cancel_reservation v3 (0079 body + actor re-attribution).
create or replace function public.cancel_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_own boolean;
  v_actor public.members;
begin
  select r.* into v_res from public.reservations r
    where r.id = p_reservation_id;
  if v_res.id is null then raise exception 'not your reservation'; end if;

  select exists (
    select 1 from public.members m
    where m.id = v_res.member_id and m.user_id = auth.uid()
  ) into v_own;

  if not v_own and not public.is_admin_of(v_res.workspace_id) then
    raise exception 'not your reservation';
  end if;

  if v_res.status not in ('reserved','checked_in') then
    raise exception 'not cancellable';
  end if;
  update public.reservations set status = 'cancelled' where id = p_reservation_id;

  -- Overrule (#424): the log trigger just stamped the event with the
  -- displaced member as actor; attribute it to the admin who acted so
  -- the push fanout (below) and the feed tell the truth.
  if not v_own then
    select m.* into v_actor from public.members m
      where m.workspace_id = v_res.workspace_id
        and m.user_id = auth.uid() and m.status = 'active';
    if v_actor.id is not null then
      update public.events
        set actor_member_id = v_actor.id
        where reservation_id = p_reservation_id
          and type = 'reservation' and action = 'cancelled';
    end if;
  end if;
end;
$$;

-- 2. notify_pending_event v2: pending fanout (0012 rules) + the
--    cancellation branch.
create or replace function public.notify_pending_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_endpoint record;
begin
  if new.status = 'pending'
     and (tg_op = 'INSERT' or old.status <> 'pending') then
    for v_endpoint in
      select pe.endpoint
      from public.push_endpoints pe
      join public.members m on m.id = pe.member_id
      where m.workspace_id = new.workspace_id
        and m.status = 'active'
        and m.id <> new.actor_member_id
        and (
          case
            when new.type = 'expense'
                 or (new.type = 'payment'
                     and new.actor_member_id = new.subject_member_id)
              then (m.is_admin or m.is_owner)
            else m.id = new.subject_member_id
          end
        )
    loop
      begin
        perform net.http_post(
          url := v_endpoint.endpoint,
          body := jsonb_build_object(
            'kind', 'pending_request',
            'workspace_id', new.workspace_id
          ),
          timeout_milliseconds := 5000
        );
      exception when others then
        null;  -- best-effort: a dead endpoint never fails the event
      end;
    end loop;
    return new;
  end if;

  -- Cancelled by someone else (#424): the overrule directive — "the
  -- user and all admins/owners will be notified". Fires on the actor
  -- re-attribution (UPDATE) or on a direct insert with a true actor.
  if new.type = 'reservation' and new.action = 'cancelled'
     and new.actor_member_id <> new.subject_member_id
     and (tg_op = 'INSERT'
          or old.actor_member_id = old.subject_member_id) then
    for v_endpoint in
      select pe.endpoint
      from public.push_endpoints pe
      join public.members m on m.id = pe.member_id
      where m.workspace_id = new.workspace_id
        and m.status = 'active'
        and m.id <> new.actor_member_id
        and (m.id = new.subject_member_id or m.is_admin or m.is_owner)
    loop
      begin
        perform net.http_post(
          url := v_endpoint.endpoint,
          body := jsonb_build_object(
            'kind', 'reservation_cancelled',
            'workspace_id', new.workspace_id
          ),
          timeout_milliseconds := 5000
        );
      exception when others then
        null;
      end;
    end loop;
  end if;
  return new;
end;
$$;

-- The re-attribution is an UPDATE of actor_member_id — the trigger must
-- fire on it (0012 fired on insert + status only).
drop trigger if exists events_notify_pending on public.events;
create trigger events_notify_pending
after insert or update of status, actor_member_id on public.events
for each row execute function public.notify_pending_event();
