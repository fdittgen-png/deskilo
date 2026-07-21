-- SPDX-License-Identifier: 0BSD
-- DesKilo billing v2 core: percentage subscriptions + fee bands
-- (epic #121 task 4, issue #128, ADR 0008). Fee bands REPLACE the plan
-- model: a member's subscription is an integer percentage 1-100; the
-- monthly fee is the band (from_pct, to_pct] the percentage falls into;
-- entitlement = ceil(open_days x 2 x pct / 100) half-days, overage at the
-- band rate. Plans stay on disk for history but are no longer seeded,
-- assigned, or billed.

-- Owner-curated subscription levels (ADR 0008): presets each individually
-- enabled, extra owner-defined values, optional negotiated free value.
alter table public.workspaces add column subscription_levels jsonb not null default
  '{"enabled_presets": [25, 50, 75, 100], "extra_levels": [], "allow_custom": false}'::jsonb;

alter table public.members add column subscription_pct int not null default 100
  check (subscription_pct between 1 and 100);

-- Migrate plan holders: unlimited plan -> 100, zero-base (Flex) -> 25,
-- quota+overage (Half) -> 50. Members without a plan keep the 100 default.
update public.members m
  set subscription_pct = case
    when p.included_half_days is null then 100
    when p.base_fee_cents = 0 then 25
    else 50
  end
  from public.plans p
  where m.plan_id = p.id;

create table public.fee_bands (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  -- band is (from_pct, to_pct]: inclusive-upper (ADR 0008)
  from_pct int not null check (from_pct between 0 and 99),
  to_pct int not null check (to_pct between 1 and 100),
  fee_cents int not null default 0 check (fee_cents >= 0),
  overage_fee_cents int not null default 0 check (overage_fee_cents >= 0),
  check (from_pct < to_pct),
  unique (workspace_id, from_pct)
);
create index fee_bands_workspace_idx on public.fee_bands (workspace_id);

alter table public.fee_bands enable row level security;
create policy fee_bands_select on public.fee_bands
  for select using (public.is_member_of(workspace_id));
create policy fee_bands_write on public.fee_bands
  for all using (public.is_owner_of(workspace_id))
  with check (public.is_owner_of(workspace_id));

-- Contiguity guard: at commit time every workspace's band set must tile
-- (0, 100] with no gaps or overlaps. Deferred so replace_fee_bands (and any
-- multi-statement owner edit in one transaction) can rebuild freely.
create or replace function public.assert_fee_bands_contiguous()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_ws uuid;
  v_expected int;
  r record;
begin
  v_ws := coalesce(new.workspace_id, old.workspace_id);
  -- a workspace may have zero bands only while it also has no members
  -- (freshly deleted); billing requires full coverage otherwise
  if not exists (select 1 from public.fee_bands where workspace_id = v_ws) then
    return null;
  end if;
  v_expected := 0;
  for r in select from_pct, to_pct from public.fee_bands
             where workspace_id = v_ws order by from_pct loop
    if r.from_pct <> v_expected then
      raise exception 'fee bands must be contiguous: expected a band starting at %, found %', v_expected, r.from_pct;
    end if;
    v_expected := r.to_pct;
  end loop;
  if v_expected <> 100 then
    raise exception 'fee bands must cover up to 100, last band ends at %', v_expected;
  end if;
  return null;
end;
$$;
revoke execute on function public.assert_fee_bands_contiguous() from public, anon, authenticated;

create constraint trigger fee_bands_contiguous
after insert or update or delete on public.fee_bands
deferrable initially deferred
for each row execute function public.assert_fee_bands_contiguous();

-- Atomic full replace with friendly validation (the owner band editor's
-- write path). p_bands: [{"from_pct":0,"to_pct":50,"fee_cents":12000,
-- "overage_fee_cents":500}, ...]
create or replace function public.replace_fee_bands(
  p_workspace_id uuid,
  p_bands jsonb
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_expected int := 0;
  b record;
begin
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only the owner may edit fee bands';
  end if;
  if p_bands is null or jsonb_typeof(p_bands) <> 'array' or jsonb_array_length(p_bands) = 0 then
    raise exception 'at least one band is required';
  end if;
  for b in
    select (x->>'from_pct')::int as from_pct, (x->>'to_pct')::int as to_pct,
           (x->>'fee_cents')::int as fee_cents,
           (x->>'overage_fee_cents')::int as overage_fee_cents
    from jsonb_array_elements(p_bands) x
    order by (x->>'from_pct')::int
  loop
    if b.from_pct <> v_expected then
      raise exception 'bands must be contiguous from 0 to 100 (gap or overlap at %)', b.from_pct;
    end if;
    if b.fee_cents < 0 or b.overage_fee_cents < 0 then
      raise exception 'fees must be >= 0';
    end if;
    v_expected := b.to_pct;
  end loop;
  if v_expected <> 100 then
    raise exception 'bands must cover up to 100 (last band ends at %)', v_expected;
  end if;

  delete from public.fee_bands where workspace_id = p_workspace_id;
  insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
  select p_workspace_id, (x->>'from_pct')::int, (x->>'to_pct')::int,
         coalesce((x->>'fee_cents')::int, 0), coalesce((x->>'overage_fee_cents')::int, 0)
  from jsonb_array_elements(p_bands) x;
end;
$$;
revoke execute on function public.replace_fee_bands(uuid, jsonb) from public, anon;

-- Seed bands mapping the old default plans' pricing intent:
-- (0,25] Flex-like, (25,50] Half-like, (50,100] Full-like.
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
select w.id, b.from_pct, b.to_pct, b.fee_cents, b.overage_fee_cents
from public.workspaces w
cross join (values (0, 25, 0, 1500), (25, 50, 15000, 800), (50, 100, 25000, 0))
  as b(from_pct, to_pct, fee_cents, overage_fee_cents)
where not exists (select 1 from public.fee_bands f where f.workspace_id = w.id);

-- New workspaces get default bands instead of plans (trigger name and
-- wiring from 0008 kept; plans are legacy from here on).
create or replace function public.seed_default_plans()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents) values
    (new.id, 0, 25, 0, 1500),
    (new.id, 25, 50, 15000, 800),
    (new.id, 50, 100, 25000, 0);
  return new;
end;
$$;

-- Statement v2: band fee + availability-scaled entitlement (ADR 0008).
-- Same auth rules and half-day usage counting as 0008.
create or replace function public.member_statement(
  p_member_id uuid,
  p_period text
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_member public.members;
  v_caller_is_admin boolean;
  v_band public.fee_bands;
  v_tz text;
  v_open int[];
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_month_first date;
  v_open_days int;
  v_pct int;
  v_included int;
  v_used int;
  v_base int := 0;
  v_overage int := 0;
  v_overage_rate int := 0;
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

  select timezone,
         coalesce((select array_agg(x::int)
                     from jsonb_array_elements_text(booking_rules->'open_weekdays') x),
                  array[1,2,3,4,5])
    into v_tz, v_open
    from public.workspaces where id = v_member.workspace_id;
  v_period_start := to_timestamp(p_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
  v_period_end := (to_timestamp(p_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;
  v_month_first := to_date(p_period || '-01', 'YYYY-MM-DD');

  v_pct := coalesce(v_member.subscription_pct, 100);
  select * into v_band from public.fee_bands
    where workspace_id = v_member.workspace_id
      and from_pct < v_pct and v_pct <= to_pct;
  if v_band.id is not null then
    v_base := v_band.fee_cents;
    v_overage_rate := v_band.overage_fee_cents;
  end if;

  -- entitlement basis: open weekdays minus closure days, x2 half-day slots
  select count(*) into v_open_days
  from generate_series(v_month_first,
                       (v_month_first + interval '1 month' - interval '1 day')::date,
                       interval '1 day') d
  where extract(isodow from d)::int = any(v_open)
    and not exists (select 1 from public.closure_days c
                     where c.workspace_id = v_member.workspace_id and c.day = d::date);
  v_included := ceil(v_open_days * 2 * v_pct / 100.0)::int;

  select count(distinct (date_trunc('day', r.starts_at at time zone v_tz)::date, s.slot))
  into v_used
  from public.reservations r
  cross join lateral (
    select case when extract(hour from r.starts_at at time zone v_tz) < 13 then 0 else 1 end as slot
  ) s
  where r.member_id = p_member_id
    and r.status in ('reserved','checked_in','completed')
    and r.starts_at >= v_period_start and r.starts_at < v_period_end;

  v_extra_half_days := greatest(0, v_used - v_included);
  v_overage := v_extra_half_days * v_overage_rate;

  select coalesce(sum(case when kind = 'credit' then amount_cents else -amount_cents end), 0)
  into v_credits
  from public.ledger_entries
  where member_id = p_member_id and period = p_period;

  return jsonb_build_object(
    'period', p_period,
    'subscription_pct', v_pct,
    'fee_cents', v_base,
    'included_half_days', v_included,
    'open_days', v_open_days,
    'used_half_days', v_used,
    'extra_half_days', v_extra_half_days,
    'overage_cents', v_overage,
    'credits_cents', v_credits,
    'balance_cents', v_credits - v_base - v_overage
  );
end;
$$;
