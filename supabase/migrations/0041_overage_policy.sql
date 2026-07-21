-- SPDX-License-Identifier: 0BSD
-- Per-member over-consumption policy (epic: subscription over-consumption).
-- NOT YET applied to the hosted reference project — the orchestrator
-- applies it after review.
--
-- A member's monthly entitlement stays ceil(open_days x 2 x pct / 100)
-- half-days (ADR 0008). What happens once it is used up is now an owner
-- choice PER MEMBER:
--
--   'blocked' — the current behaviour and the default: no booking past
--               the entitlement (+ confirmed extensions). The member must
--               request extra half-days (0031) or buy a package.
--   'payg'    — pay-as-you-go: the member MAY book past the entitlement;
--               every extra half-day bills at the fee band's overage rate.
--   'package' — the member must buy a pre-defined package first. Until the
--               packages migration ships, this behaves like 'blocked'
--               (the guard still raises; buying is added next).
--
-- Only the overage GATE changes here. Overage PRICING already exists:
-- member_statement bills max(0, used - included) x band.overage_rate, so a
-- payg member's extra half-days are charged with no further change.

alter table public.members
  add column overage_policy text not null default 'blocked'
  check (overage_policy in ('blocked','payg','package'));

-- ---------------------------------------------------------------------
-- assert_member_quota: body = 0031 verbatim + the payg early-return. A
-- pay-as-you-go member is never blocked; their extra half-days bill at
-- the band rate (member_statement, unchanged). blocked/package still raise.
-- ---------------------------------------------------------------------
create or replace function public.assert_member_quota(
  p_member_id uuid, p_at timestamptz
) returns void language plpgsql stable security definer set search_path = public as $$
declare
  v_member public.members;
  v_tz text;
  v_open int[];
  v_pct int;
  v_period text;
  v_month_first date;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_open_days int;
  v_included int;
  v_ext int;
  v_used int;
begin
  select * into v_member from public.members where id = p_member_id;
  select timezone,
         coalesce((select array_agg(x::int)
                     from jsonb_array_elements_text(booking_rules->'open_weekdays') x),
                  array[1,2,3,4,5])
    into v_tz, v_open
    from public.workspaces where id = v_member.workspace_id;

  v_period := to_char(p_at at time zone v_tz, 'YYYY-MM');
  v_month_first := to_date(v_period || '-01', 'YYYY-MM-DD');
  v_period_start := to_timestamp(v_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
  v_period_end := (to_timestamp(v_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;

  v_pct := coalesce(v_member.subscription_pct, 100);
  select count(*) into v_open_days
  from generate_series(v_month_first,
                       (v_month_first + interval '1 month' - interval '1 day')::date,
                       interval '1 day') d
  where extract(isodow from d)::int = any(v_open)
    and not exists (select 1 from public.closure_days c
                     where c.workspace_id = v_member.workspace_id and c.day = d::date);
  v_included := ceil(v_open_days * 2 * v_pct / 100.0)::int;

  select coalesce(sum(half_days), 0) into v_ext from public.quota_extensions
    where member_id = p_member_id and period = v_period;

  select count(distinct (date_trunc('day', r.starts_at at time zone v_tz)::date, s.slot))
  into v_used
  from public.reservations r
  cross join lateral (
    select case when extract(hour from r.starts_at at time zone v_tz) < 13 then 0 else 1 end as slot
  ) s
  where r.member_id = p_member_id
    and r.status in ('reserved','checked_in','completed')
    and r.starts_at >= v_period_start and r.starts_at < v_period_end;

  if v_used > v_included + v_ext then
    -- pay-as-you-go members may go over; the overage bills at the band rate
    if coalesce(v_member.overage_policy, 'blocked') = 'payg' then
      return;
    end if;
    -- the client pins the substring 'half-day quota' of this message
    raise exception 'half-day quota exceeded — request additional half-days';
  end if;
end;
$$;
revoke execute on function public.assert_member_quota(uuid, timestamptz) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Statement v4: v3 (0024) + the granted-extension sum and three new
-- fields the app needs to show "N days included · X used · Y left" and
-- pick the right call-to-action (overage_policy). Body copied verbatim
-- from 0024; additions marked with "#overage". Balance formula unchanged.
-- ---------------------------------------------------------------------
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
  v_supp_on boolean := false;
  v_supp_since timestamptz;
  v_supplement int := 0;
  -- #overage: granted extensions + the resulting cap/remaining
  v_granted int := 0;
  v_cap int := 0;
  v_remaining int := 0;
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
                  array[1,2,3,4,5]),
         coalesce(feature_flags -> 'accessorySupplements' = to_jsonb(true), false),
         accessory_supplements_since
    into v_tz, v_open, v_supp_on, v_supp_since
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

  -- #overage: confirmed extensions raise the cap; remaining = cap - used
  select coalesce(sum(half_days), 0) into v_granted from public.quota_extensions
    where member_id = p_member_id and period = p_period;
  v_cap := v_included + v_granted;
  v_remaining := greatest(0, v_cap - v_used);

  if v_supp_on and v_supp_since is not null then
    select coalesce(sum(seat_supp.total_cents), 0) into v_supplement
    from (
      select distinct
        r.seat_id,
        date_trunc('day', r.starts_at at time zone v_tz)::date as day,
        case when extract(hour from r.starts_at at time zone v_tz) < 13 then 0 else 1 end as slot
      from public.reservations r
      where r.member_id = p_member_id
        and r.seat_id is not null
        and r.status in ('reserved','checked_in','completed')
        and r.starts_at >= greatest(v_period_start, v_supp_since)
        and r.starts_at < v_period_end
    ) hd
    join (
      select sa.seat_id, sum(a.supplement_cents)::int as total_cents
      from public.seat_accessories sa
      join public.accessories a on a.id = sa.accessory_id
      where a.active and a.supplement_cents > 0
      group by sa.seat_id
    ) seat_supp on seat_supp.seat_id = hd.seat_id;
  end if;

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
    'accessory_supplement_cents', v_supplement,
    'credits_cents', v_credits,
    'balance_cents', v_credits - v_base - v_overage - v_supplement,
    -- #overage
    'overage_policy', coalesce(v_member.overage_policy, 'blocked'),
    'overage_rate_cents', v_overage_rate,
    'granted_half_days', v_granted,
    'remaining_half_days', v_remaining
  );
end;
$$;
