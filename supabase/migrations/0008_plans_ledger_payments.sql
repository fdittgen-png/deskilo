-- SPDX-License-Identifier: MIT
-- DesKilo plans + ledger + payment recording (Epic #7, issue #60, ADR 0006).
-- Applied to the hosted reference project on 2026-07-07.

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  base_fee_cents int not null default 0 check (base_fee_cents >= 0),
  -- null = unlimited (Full plan)
  included_half_days int check (included_half_days >= 0),
  overage_fee_cents int not null default 0 check (overage_fee_cents >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index plans_workspace_idx on public.plans (workspace_id);

alter table public.members add column plan_id uuid references public.plans(id) on delete set null;

create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete restrict,
  -- charge = member owes the community; credit = community owes the member
  kind text not null check (kind in ('charge','credit')),
  category text not null check (category in ('subscription','overage','expense','payment','adjustment')),
  amount_cents int not null check (amount_cents > 0),
  description text not null default '',
  period text not null check (period ~ '^[0-9]{4}-[0-9]{2}$'),
  event_id uuid references public.events(id) on delete set null,
  created_at timestamptz not null default now()
);
create index ledger_member_period_idx on public.ledger_entries (member_id, period);
create index ledger_workspace_idx on public.ledger_entries (workspace_id);

alter table public.plans enable row level security;
alter table public.ledger_entries enable row level security;

create policy plans_select on public.plans
  for select using (public.is_member_of(workspace_id));
create policy plans_write on public.plans
  for all using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));

-- workers see their own ledger; admins see all; writes via RPC/trigger only
create policy ledger_select on public.ledger_entries
  for select using (
    public.is_admin_of(workspace_id)
    or exists (
      select 1 from public.members m
      where m.id = ledger_entries.member_id and m.user_id = auth.uid()
    )
  );

-- Default plans on workspace creation (spec §7.1 defaults).
create or replace function public.seed_default_plans()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.plans (workspace_id, name, base_fee_cents, included_half_days, overage_fee_cents) values
    (new.id, 'Full', 25000, null, 0),
    (new.id, 'Half', 15000, 22, 800),
    (new.id, 'Flex', 0, 0, 1500);
  return new;
end;
$$;
create trigger workspaces_seed_plans
after insert on public.workspaces
for each row execute function public.seed_default_plans();
revoke execute on function public.seed_default_plans() from public, anon, authenticated;

-- Payment recording (spec §7.4): always a pending event; the OTHER side
-- confirms. Member records own payment -> any admin decides; admin records
-- a received payment -> the member decides (existing respond path).
create or replace function public.record_payment(
  p_workspace_id uuid,
  p_member_id uuid,
  p_amount_cents int,
  p_note text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_event_id uuid;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_actor.id is null then raise exception 'not an active member'; end if;
  if p_amount_cents <= 0 then raise exception 'amount must be positive'; end if;
  if v_actor.id <> p_member_id and not (v_actor.is_admin or v_actor.is_owner) then
    raise exception 'only admins record payments for others';
  end if;
  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (
    p_workspace_id, 'payment', 'submitted', v_actor.id, p_member_id,
    jsonb_build_object('amount_cents', p_amount_cents, 'note', p_note),
    'pending'
  ) returning id into v_event_id;
  return v_event_id;
end;
$$;

-- Extend respond_to_event: payment events where actor = subject are decided
-- by an admin (the other side); confirmed payment events post the credit.
create or replace function public.respond_to_event(
  p_event_id uuid,
  p_accept boolean
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_event public.events;
  v_caller public.members;
begin
  select e.* into v_event from public.events e where e.id = p_event_id;
  if v_event.id is null then raise exception 'unknown event'; end if;
  if v_event.status <> 'pending' then raise exception 'already decided'; end if;

  select m.* into v_caller from public.members m
    where m.workspace_id = v_event.workspace_id and m.user_id = auth.uid()
      and m.status = 'active';
  if v_caller.id is null then raise exception 'not a member'; end if;

  if v_event.type = 'payment' and v_event.actor_member_id = v_event.subject_member_id then
    -- self-recorded payment: the other side = any admin (not the recorder)
    if not (v_caller.is_admin or v_caller.is_owner) or v_caller.id = v_event.actor_member_id then
      raise exception 'an admin must confirm this payment';
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

  if p_accept and v_event.type = 'payment' then
    insert into public.ledger_entries
      (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
    values (
      v_event.workspace_id, v_event.subject_member_id, 'credit', 'payment',
      (v_event.payload->>'amount_cents')::int,
      coalesce(v_event.payload->>'note', ''),
      to_char(now(), 'YYYY-MM'),
      v_event.id
    );
  end if;
end;
$$;

-- On-the-fly monthly statement (spec §7.3). Usage unit: half-day (decided);
-- a half-day = any presence in 00:00-13:00 / 13:00-24:00 workspace-local.
create or replace function public.member_statement(
  p_member_id uuid,
  p_period text
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_member public.members;
  v_caller_is_admin boolean;
  v_plan public.plans;
  v_tz text;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_used int;
  v_base int := 0;
  v_overage int := 0;
  v_credits int;
  v_extra_half_days int := 0;
begin
  select * into v_member from public.members where id = p_member_id;
  if v_member.id is null then raise exception 'unknown member'; end if;
  v_caller_is_admin := public.is_admin_of(v_member.workspace_id);
  if not v_caller_is_admin and not exists (
    select 1 from public.members m
    where m.id = p_member_id and m.user_id = auth.uid()
  ) then
    raise exception 'not your statement';
  end if;

  select timezone into v_tz from public.workspaces where id = v_member.workspace_id;
  v_period_start := to_timestamp(p_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
  v_period_end := (to_timestamp(p_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;

  select * into v_plan from public.plans where id = v_member.plan_id;
  if v_plan.id is not null then v_base := v_plan.base_fee_cents; end if;

  -- distinct half-day slots touched by active/past bookings in the period
  select count(distinct (date_trunc('day', r.starts_at at time zone v_tz)::date, s.slot))
  into v_used
  from public.reservations r
  cross join lateral (
    select case when extract(hour from r.starts_at at time zone v_tz) < 13 then 0 else 1 end as slot
  ) s
  where r.member_id = p_member_id
    and r.status in ('reserved','checked_in','completed')
    and r.starts_at >= v_period_start and r.starts_at < v_period_end;

  if v_plan.id is not null and v_plan.included_half_days is not null then
    v_extra_half_days := greatest(0, v_used - v_plan.included_half_days);
    v_overage := v_extra_half_days * v_plan.overage_fee_cents;
  end if;

  select coalesce(sum(case when kind = 'credit' then amount_cents else -amount_cents end), 0)
  into v_credits
  from public.ledger_entries
  where member_id = p_member_id and period = p_period;

  return jsonb_build_object(
    'period', p_period,
    'plan_name', coalesce(v_plan.name, ''),
    'base_fee_cents', v_base,
    'included_half_days', v_plan.included_half_days,
    'used_half_days', v_used,
    'extra_half_days', v_extra_half_days,
    'overage_cents', v_overage,
    'credits_cents', v_credits,
    'balance_cents', v_credits - v_base - v_overage
  );
end;
$$;

revoke execute on function public.record_payment(uuid, uuid, int, text) from public, anon;
revoke execute on function public.respond_to_event(uuid, boolean) from public, anon;
revoke execute on function public.member_statement(uuid, text) from public, anon;
