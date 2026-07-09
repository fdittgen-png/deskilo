-- SPDX-License-Identifier: MIT
-- DesKilo quorum validation with per-validator audit trail (epic #121
-- task 6, issue #130, ADR 0008). The single-confirmer protocol of
-- 0007/0011/0016 generalizes to an owner-configurable quorum:
--   validation_policies — per event type (fallback row event_type null;
--     absent rows behave like today: 1 decision, all admins, owner not
--     required)
--   event_decisions — WHO decided WHAT and WHEN; sweeps write system rows
--     so the audit trail never has gaps.
-- Semantics preserved from before: no self-approval (with the #107
-- solo-admin escape hatch), subject-must-accept for admin-initiated
-- events (their accept counts toward the quorum), rejects close
-- immediately, ledger side effects post once on confirmation.

create table public.validation_policies (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  -- null = workspace default for types without their own row
  event_type text check (event_type in
    ('reservation','payment','expense','adjustment','service_charge')),
  required_count int not null default 1 check (required_count between 1 and 10),
  admins_may_validate boolean not null default true,
  -- empty = every admin; otherwise only these member ids (owners always may)
  eligible_admin_ids uuid[] not null default '{}',
  owner_required boolean not null default false,
  unique nulls not distinct (workspace_id, event_type)
);
create index validation_policies_workspace_idx on public.validation_policies (workspace_id);

alter table public.validation_policies enable row level security;
create policy validation_policies_select on public.validation_policies
  for select using (public.is_member_of(workspace_id));
create policy validation_policies_write on public.validation_policies
  for all using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));

create table public.event_decisions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  -- null = system (sweep timeout) decision
  member_id uuid references public.members(id) on delete restrict,
  decision text not null check (decision in ('accept','reject')),
  decided_by_system boolean not null default false,
  decided_at timestamptz not null default now()
);
create unique index event_decisions_one_per_member
  on public.event_decisions (event_id, member_id) where member_id is not null;
create index event_decisions_event_idx on public.event_decisions (event_id);

alter table public.event_decisions enable row level security;
create policy event_decisions_select on public.event_decisions
  for select using (exists (
    select 1 from public.events e
    where e.id = event_decisions.event_id and public.is_member_of(e.workspace_id)
  ));
-- writes via RPCs only

-- Quorum-aware decision RPC (replaces the 0016 body).
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
    end if;
  end if;
end;
$$;
revoke execute on function public.respond_to_event(uuid, boolean) from public, anon;

-- Sweep keeps its 7-day timeout but now leaves system decision rows so the
-- audit trail shows WHY an event closed.
create or replace function public.sweep_pending_events(p_workspace_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_member_of(p_workspace_id) then
    raise exception 'not a member';
  end if;
  -- non-destructive (creations/modifications): auto-confirm
  insert into public.event_decisions (event_id, member_id, decision, decided_by_system)
  select e.id, null, 'accept', true from public.events e
    where e.workspace_id = p_workspace_id and e.status = 'pending'
      and e.action in ('created','modified')
      and e.created_at < now() - interval '7 days';
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
  insert into public.event_decisions (event_id, member_id, decision, decided_by_system)
  select e.id, null, 'reject', true from public.events e
    where e.workspace_id = p_workspace_id and e.status = 'pending'
      and e.action not in ('created','modified')
      and e.created_at < now() - interval '7 days';
  update public.events
    set status = 'expired', decided_at = now()
    where workspace_id = p_workspace_id and status = 'pending'
      and action not in ('created','modified')
      and created_at < now() - interval '7 days';
end;
$$;
revoke execute on function public.sweep_pending_events(uuid) from public, anon;
