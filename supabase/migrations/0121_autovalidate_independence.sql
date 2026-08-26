-- SPDX-License-Identifier: 0BSD
-- #636 — the two auto-validation switches (#629, migration 0119) become
-- INDEPENDENT. NOT YET applied to the hosted reference project — the
-- orchestrator applies it after review.
--
-- THE DEFECT. 0119's request_reservation_deletion v3 decided:
--
--   v_auto := (v_member.is_owner and coalesce(v_policy.auto_validate_owner, false))
--          or (v_member.is_admin and coalesce(v_policy.auto_validate_admin, false));
--
-- Every owner also carries is_admin = true — the founding member is
-- seeded with both (0001) and promote_to_owner sets both (0058). So the
-- admin arm matched the owner too: switching on "admins delete without
-- validation" ALONE also auto-settled the OWNER's own requests, and the
-- owner switch was redundant whenever the admin one was on. The two
-- labels in the validation-rules screen, and the guide, promise two
-- controls that can be turned on one without the other.
--
-- THE FIX, and nothing else: the admin arm excludes owners.
--
--   (v_member.is_admin and not v_member.is_owner and coalesce(..., false))
--
-- An owner is now auto-settled by the OWNER switch and only by it; a
-- plain admin by the ADMIN switch and only by it. Nothing else in the
-- body moves — the pending/settled insert, the decided_by_system
-- decision row, the #562 supersede and every guard are byte-identical
-- to 0119.
--
-- The DESIGN NOTE at the head of 0119 still governs this function: it
-- is a deliberate, owner-configured exception to the 0086 rule that
-- nobody validates their own event, scoped to reservation deletions
-- ONLY (the lookup below reads the workspace's own 'reservation_delete'
-- policy row and deliberately ignores the null fallback row), both
-- booleans default FALSE, and the settled event carries
-- payload.auto_validated = true so the feed and the audit trail can
-- always tell a self-settled deletion from a peer-reviewed one. It must
-- NEVER be generalized silently to other event types.
--
-- Body GENERATED from its latest prior definition:
--   request_reservation_deletion  v3 → v4  from 0119

create or replace function public.request_reservation_deletion(
  p_reservation_id uuid, p_reason text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_res public.reservations;
  v_member public.members;
  v_id uuid;
  v_policy public.validation_policies;
  v_auto boolean := false;
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
  -- #629 — the owner-configured auto-validation exception, decided
  -- BEFORE the insert. Scoped to the workspace's OWN reservation_delete
  -- policy row: the null fallback row is deliberately NOT consulted, so
  -- the exception can never leak to another event type.
  select * into v_policy from public.validation_policies
    where workspace_id = v_res.workspace_id
      and event_type = 'reservation_delete';
  -- #636 — the two switches are INDEPENDENT. Every owner is also an
  -- admin (0001 seeds both, 0058 sets both), so an admin arm that did
  -- not exclude owners made the admin switch settle the owner's own
  -- requests and left the owner switch with nothing of its own to do.
  -- Owners answer to auto_validate_owner, plain admins to
  -- auto_validate_admin — neither implies the other.
  v_auto := (v_member.is_owner and coalesce(v_policy.auto_validate_owner, false))
         or (v_member.is_admin and not v_member.is_owner
             and coalesce(v_policy.auto_validate_admin, false));

  -- #562: supersede, don't refuse — a fresh PENDING insert re-triggers
  -- the validator notification (an auto-validated request never asks).
  update public.events
     set status = 'expired'
   where type = 'reservation_delete' and status = 'pending'
     and (payload->>'reservation_id')::uuid = p_reservation_id;

  -- Auto-validated requests are born SETTLED. Inserting them pending
  -- and confirming a statement later would emit a real "please
  -- validate" ping (realtime + the pending push mirror) for something
  -- already decided — validators chasing a closed question. The audit
  -- keeps everything that matters: the event, its actor, a system
  -- decision row and the payload flag.
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values (
    v_res.workspace_id, 'reservation_delete', 'submitted',
    v_member.id, v_member.id,
    jsonb_build_object(
      'reservation_id', v_res.id,
      'starts_at', v_res.starts_at,
      'ends_at', v_res.ends_at,
      'was_checked_in', v_res.status <> 'reserved',
      'reason', left(coalesce(p_reason, ''), 300)
    ) || case when v_auto
           then jsonb_build_object('auto_validated', true)
           else '{}'::jsonb end,
    case when v_auto then 'confirmed' else 'pending' end,
    case when v_auto then now() end
  )
  returning id into v_id;

  if v_auto then
    -- The 0017 idiom for a decision no human made: member_id null,
    -- decided_by_system true. Attributing it to the requester would
    -- forge exactly the peer review that 0086 forbids — the rule
    -- settled this, not a colleague.
    insert into public.event_decisions
      (event_id, member_id, decision, decided_by_system)
      values (v_id, null, 'accept', true);
    -- Same effect as respond_to_event's reservation_delete confirm
    -- branch (0101): the booking goes away.
    update public.reservations set status = 'cancelled'
      where id = v_res.id
        and status in ('reserved','checked_in','completed');
  end if;
  return v_id;
end;
$$;

revoke execute on function
  public.request_reservation_deletion(uuid, text) from public, anon;
