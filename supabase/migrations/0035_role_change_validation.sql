-- SPDX-License-Identifier: 0BSD
-- Owner-initiated role changes, routed through the validation quorum.
-- Applied to the hosted reference project on 2026-07-19.
--
-- The owner promotes a member to admin or demotes an admin to a regular
-- member; the change does NOT apply immediately — it enters the events
-- spine as a new 'role_change' type and is confirmed by the workspace's
-- validators per its validation_policies rule (required_count, eligible
-- admins, owner_required), exactly like a payment or an expense. In a
-- solo-owner workspace the #107 escape hatch auto-applies it.

alter table public.events drop constraint events_type_check;
alter table public.events add constraint events_type_check
  check (type in ('reservation','payment','expense','adjustment',
                  'service_charge','quota','role_change'));

-- the owner requests a role change on a non-owner member
create or replace function public.request_role_change(
  p_workspace_id uuid, p_target_member_id uuid, p_make_admin boolean
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_owner public.members;
  v_target public.members;
  v_id uuid;
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only owners may change roles';
  end if;
  select * into v_owner from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid()
      and status = 'active';
  select * into v_target from public.members
    where id = p_target_member_id and workspace_id = p_workspace_id
      and status = 'active';
  if v_target.id is null then raise exception 'unknown member'; end if;
  if v_target.is_owner then
    raise exception 'owners keep their admin rights';
  end if;
  if v_target.is_admin = p_make_admin then
    raise exception 'member already has that role';
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status)
  values (
    p_workspace_id, 'role_change', 'submitted', v_owner.id,
    p_target_member_id,
    jsonb_build_object('make_admin', p_make_admin),
    'pending'
  )
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.request_role_change(uuid, uuid, boolean) from public, anon;

-- respond_to_event: body = 0031 verbatim + the role_change apply branch.
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
    -- pre-0017 behavior
    select null::uuid as id, v_event.workspace_id as workspace_id,
           null::text as event_type, 1 as required_count,
           true as admins_may_validate, '{}'::uuid[] as eligible_admin_ids,
           false as owner_required
      into v_policy;
  end if;

  -- admin-initiated events are accepted by their subject; self-initiated
  -- money events need validators
  v_subject_decides := v_event.type = 'reservation'
    or (v_event.type in ('payment','service_charge')
        and v_event.actor_member_id <> v_event.subject_member_id);

  -- validator pool: owners always; admins per policy; never the actor or
  -- subject. #107 escape hatch: an actor-admin alone in the pool may
  -- self-decide.
  select count(*) into v_pool_size from public.members m
    where m.workspace_id = v_event.workspace_id and m.status = 'active'
      and m.id not in (v_event.actor_member_id, v_event.subject_member_id)
      and (m.is_owner or (m.is_admin and v_policy.admins_may_validate
           and (cardinality(v_policy.eligible_admin_ids) = 0
                or m.id = any(v_policy.eligible_admin_ids))));

  -- the #107 escape hatch lifts BOTH exclusions on admin-decided events
  -- (a solo admin's own expense makes them actor AND subject); on
  -- subject-decides events the subject stays out of the pool — their
  -- mandatory accept is counted separately below
  v_in_pool := (v_caller.is_owner or (v_caller.is_admin and v_policy.admins_may_validate
                and (cardinality(v_policy.eligible_admin_ids) = 0
                     or v_caller.id = any(v_policy.eligible_admin_ids))))
    and (v_caller.id <> v_event.subject_member_id
         or (not v_subject_decides and v_pool_size = 0))
    and (v_caller.id <> v_event.actor_member_id or v_pool_size = 0);
  if v_pool_size = 0 and (v_caller.is_owner or (v_caller.is_admin and v_policy.admins_may_validate)) then
    -- solo-admin workspaces: the pool collapses to the actor (#107)
    v_pool_size := 1;
  end if;

  if v_subject_decides and v_caller.id = v_event.subject_member_id then
    null; -- the subject's decision is always admissible (and mandatory)
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
    return;
  end if;

  -- confirmation check: enough accepts, subject on board, owner on board
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
    elsif v_event.type = 'service_charge' then
      insert into public.ledger_entries
        (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
      values (
        v_event.workspace_id, v_event.subject_member_id, 'charge', 'service',
        (v_event.payload->>'amount_cents')::int,
        (v_event.payload->>'name') || ' x' || (v_event.payload->>'quantity'),
        coalesce(v_event.payload->>'period', to_char(now(), 'YYYY-MM')),
        v_event.id
      );
    elsif v_event.type = 'quota' then
      -- the granted extension raises the member's cap for that period;
      -- consumption beyond the base entitlement still bills at the
      -- band's overage rate (member_statement is unchanged)
      insert into public.quota_extensions
        (workspace_id, member_id, period, half_days, event_id)
      values (
        v_event.workspace_id, v_event.subject_member_id,
        v_event.payload->>'period',
        (v_event.payload->>'half_days')::int,
        v_event.id
      );
    elsif v_event.type = 'role_change' then
      -- the validated decision flips the target's admin flag; owners are
      -- untouched (request_role_change refuses them) and the last-owner
      -- trigger still guards the is_owner column separately.
      update public.members
        set is_admin = (v_event.payload->>'make_admin')::boolean
        where id = v_event.subject_member_id;
    end if;
  end if;
end;
$$;
revoke execute on function public.respond_to_event(uuid, boolean) from public, anon;
