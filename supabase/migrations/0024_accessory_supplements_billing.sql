-- SPDX-License-Identifier: MIT
-- DesKilo accessory supplements on monthly statements (epic #163,
-- issue #170). NOT YET applied to the hosted reference project — the
-- orchestrator applies it after review.
--
-- The owner activates the `accessorySupplements` feature toggle (default
-- OFF, Dart registry) and from that moment on every reserved half-day on
-- a seat whose ACTIVE accessories carry a supplement adds the sum of
-- those supplement_cents to the member's statement. NO retroactive
-- charging (maintainer decision): only reservations STARTING at or after
-- the activation timestamp are billed, so flipping the toggle never
-- reprices half-days that were booked while it was off.

-- ---------------------------------------------------------------------
-- Activation timestamp. feature_flags stays a pure {feature: bool} map
-- (resolveEnabledFeatures ignores non-bools, and the client always
-- writes the full boolean map), so the timestamp lives in a dedicated
-- column maintained by a BEFORE UPDATE trigger: stamped when the flag
-- flips false→true, cleared when it flips true→false, untouched
-- otherwise (the features screen rewrites the whole map on every
-- toggle, so an unchanged true must NOT re-stamp — that would silently
-- un-bill half-days booked since the first activation). The client
-- write path (plain UPDATE of workspaces.feature_flags under owner RLS)
-- stays unchanged.
-- ---------------------------------------------------------------------

alter table public.workspaces
  add column accessory_supplements_since timestamptz;

create or replace function public.stamp_accessory_supplements_since()
returns trigger language plpgsql as $$
declare
  v_old boolean := coalesce(
    old.feature_flags -> 'accessorySupplements' = to_jsonb(true), false);
  v_new boolean := coalesce(
    new.feature_flags -> 'accessorySupplements' = to_jsonb(true), false);
begin
  if v_new and not v_old then
    new.accessory_supplements_since := now();
  elsif v_old and not v_new then
    new.accessory_supplements_since := null;
  end if;
  return new;
end;
$$;
revoke execute on function public.stamp_accessory_supplements_since() from public, anon, authenticated;

create trigger stamp_accessory_supplements_since
before update of feature_flags on public.workspaces
for each row execute function public.stamp_accessory_supplements_since();

-- ---------------------------------------------------------------------
-- Statement v3: v2 (0015) + the accessory-supplement term. Body copied
-- verbatim from 0015; additions are marked with "#170". Auth rules,
-- band fee, entitlement and half-day usage counting are unchanged; the
-- supplement mirrors the usage query's half-day slot definition
-- (workspace-local day, slot 0 before 13:00, slot 1 from 13:00) and its
-- status filter, so cancelled/released reservations never bill.
-- Existing execute grants survive create-or-replace (0008 revoked
-- public/anon).
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
  -- #170: accessory supplements
  v_supp_on boolean := false;
  v_supp_since timestamptz;
  v_supplement int := 0;
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
         -- #170: feature flag + no-retroactivity activation timestamp
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

  -- #170: accessory supplements — for each distinct reserved half-day
  -- slot on a seat (same slot definition and status filter as v_used;
  -- office reservations carry no seat, hence no supplement), add the sum
  -- of the seat's ACTIVE priced accessories. Only reservations starting
  -- at/after the activation timestamp bill (no retroactive charging).
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
    'balance_cents', v_credits - v_base - v_overage - v_supplement
  );
end;
$$;
