-- SPDX-License-Identifier: 0BSD
-- risk: transforming
--
-- 0237 (#1279 S3) — booking beyond the month's entitlement spends carnets,
-- and cancelling gives them back.
--
-- ## One trigger, not five callers
--
-- Reservation status is changed by eleven functions, a booking is moved
-- between months by `update_reservation`, and rows are deleted by
-- `reset_workspace`. Allocating credits in each caller would miss one. So
-- `reservations_rebalance_credits` — AFTER INSERT OR UPDATE OR DELETE on
-- `reservations` — recomputes, for each member-month a row touched, how
-- many half-days the member needs beyond their entitlement
-- (`member_quota_shortfall`, the SAME arithmetic `assert_member_quota`
-- uses, extracted from its live body) and how many live credit uses the
-- month already holds:
--
--   * need > held — allocate the difference to the booking that caused it,
--     from unexpired credits ordered soonest-expiring first, then oldest,
--     each row locked FOR UPDATE: two sessions racing for the last half-day
--     serialize, and the second finds nothing left;
--   * need < held — release the excess, the uses of bookings that stopped
--     counting first, then the most recent.
--
-- Pay-as-you-go members are skipped: their extra half-days are billed as
-- overage, and a carnet is not spent behind their back.
--
-- ## The check and the bill
--
--   * `assert_member_quota` refuses only when the shortfall exceeds the live
--     credit uses of the month. Its message is unchanged, byte for byte — a
--     member with no credits sees exactly what they saw before.
--   * `member_statement` no longer bills credit-covered half-days as
--     overage: they were paid for once, at the sale.
--
-- Spending posts nothing to the ledger. A retried idempotent booking (0214)
-- returns the existing reservation without inserting, so it cannot
-- allocate twice.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- ── the live credit uses of a member-month ─────────────────────────────
create or replace function public.member_credit_uses_in_period(
  p_member_id uuid, p_from timestamptz, p_to timestamptz)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(u.half_days), 0)::int
    from public.member_credit_uses u
    join public.reservations r on r.id = u.reservation_id
   where r.member_id = p_member_id
     and u.released_at is null
     and r.starts_at >= p_from and r.starts_at < p_to;
$$;

revoke execute on function public.member_credit_uses_in_period(uuid, timestamptz, timestamptz)
  from public, anon, authenticated;

do $migration$
declare
  v_def text;
  v_patched text;
  v_missing text[] := '{}';
begin
  -- 1. member_quota_shortfall: assert_member_quota's arithmetic, returning
  --    what it would refuse over instead of refusing.
  v_def := pg_get_functiondef('public.assert_member_quota(uuid, timestamptz)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    'FUNCTION public.assert_member_quota(p_member_id uuid, p_at timestamp with time zone)',
    'FUNCTION public.member_quota_shortfall(p_member_id uuid, p_at timestamp with time zone)');
  if v_patched is null then v_missing := v_missing || 'shortfall name'::text; else v_def := v_patched; end if;
  v_patched := pg_temp.anchor_replace(v_def, 'RETURNS void', 'RETURNS integer');
  if v_patched is null then v_missing := v_missing || 'shortfall returns'::text; else v_def := v_patched; end if;
  v_patched := pg_temp.anchor_replace(v_def,
    $a$if v_used > v_included + v_ext then
    -- pay-as-you-go members may go over; the overage bills at the band rate
    if coalesce(v_member.overage_policy, 'blocked') = 'payg' then
      return;
    end if;
    -- the client pins the substring 'half-day quota' of this message
    raise exception 'half-day quota exceeded — request additional half-days';
  end if;$a$,
    $a$return greatest(0, v_used - v_included - v_ext);$a$);
  if v_patched is null then v_missing := v_missing || 'shortfall tail'::text; else execute v_patched; end if;

  -- 2. assert_member_quota counts the month's live credit uses.
  v_def := pg_get_functiondef('public.assert_member_quota(uuid, timestamptz)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    'if v_used > v_included + v_ext then',
    'if v_used > v_included + v_ext + public.member_credit_uses_in_period(p_member_id, v_period_start, v_period_end) then');
  if v_patched is null then v_missing := v_missing || 'assert'::text; else execute v_patched; end if;

  -- 3. member_statement does not bill credit-covered half-days as overage.
  v_def := pg_get_functiondef('public.member_statement(uuid, text)'::regprocedure);
  v_patched := pg_temp.anchor_replace(v_def,
    'v_extra_half_days := greatest(0, v_used - v_included);',
    'v_extra_half_days := greatest(0, v_used - v_included - public.member_credit_uses_in_period(p_member_id, v_period_start, v_period_end));');
  if v_patched is null then v_missing := v_missing || 'statement'::text; else execute v_patched; end if;

  if cardinality(v_missing) > 0 then
    raise exception '0237: anchors did not match: %', array_to_string(v_missing, ', ');
  end if;
end
$migration$;

revoke execute on function public.member_quota_shortfall(uuid, timestamptz) from public, anon, authenticated;

-- ── rebalancing one member-month ───────────────────────────────────────
create or replace function public.rebalance_member_credits(
  p_member_id uuid, p_at timestamptz, p_reservation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_member public.members;
  v_tz text;
  v_period text;
  v_from timestamptz;
  v_to timestamptz;
  v_need int;
  v_held int;
  v_credit record;
  v_take int;
  v_excess int;
  v_use record;
  v_counted boolean;
begin
  select * into v_member from public.members where id = p_member_id;
  if v_member.id is null or coalesce(v_member.overage_policy, 'blocked') = 'payg' then
    return;
  end if;
  select timezone into v_tz from public.workspaces where id = v_member.workspace_id;
  v_period := to_char(p_at at time zone v_tz, 'YYYY-MM');
  v_from := to_timestamp(v_period || '-01', 'YYYY-MM-DD') at time zone v_tz;
  v_to := (to_timestamp(v_period || '-01', 'YYYY-MM-DD') + interval '1 month') at time zone v_tz;

  v_need := public.member_quota_shortfall(p_member_id, p_at);
  v_held := public.member_credit_uses_in_period(p_member_id, v_from, v_to);

  if v_need > v_held then
    select exists (select 1 from public.reservations r
                    where r.id = p_reservation_id and r.member_id = p_member_id
                      and r.status in ('reserved', 'checked_in', 'completed')
                      and r.starts_at >= v_from and r.starts_at < v_to)
      into v_counted;
    if not v_counted then
      return;
    end if;
    v_take := v_need - v_held;
    for v_credit in
      select c.id,
             c.half_days - coalesce((select sum(u.half_days) from public.member_credit_uses u
                                      where u.credit_id = c.id and u.released_at is null), 0) as left_over
        from public.member_credits c
       where c.member_id = p_member_id
         and (c.expires_at is null or c.expires_at > p_at)
       order by c.expires_at nulls last, c.purchased_at
         for update of c
    loop
      exit when v_take <= 0;
      continue when v_credit.left_over <= 0;
      insert into public.member_credit_uses (workspace_id, credit_id, reservation_id, half_days)
      values (v_member.workspace_id, v_credit.id, p_reservation_id, least(v_take, v_credit.left_over))
      on conflict (reservation_id, credit_id) where released_at is null
      do update set half_days = public.member_credit_uses.half_days + excluded.half_days;
      v_take := v_take - least(v_take, v_credit.left_over);
    end loop;
    -- What is still missing is assert_member_quota's to refuse.
  elsif v_need < v_held then
    v_excess := v_held - v_need;
    for v_use in
      select u.id, u.half_days
        from public.member_credit_uses u
        join public.reservations r on r.id = u.reservation_id
       where r.member_id = p_member_id
         and u.released_at is null
         and r.starts_at >= v_from and r.starts_at < v_to
       order by (r.status in ('reserved', 'checked_in', 'completed')) asc, u.created_at desc
    loop
      exit when v_excess <= 0;
      if v_use.half_days <= v_excess then
        update public.member_credit_uses set released_at = now() where id = v_use.id;
        v_excess := v_excess - v_use.half_days;
      else
        update public.member_credit_uses set half_days = half_days - v_excess where id = v_use.id;
        v_excess := 0;
      end if;
    end loop;
  end if;
end $fn$;

revoke execute on function public.rebalance_member_credits(uuid, timestamptz, uuid)
  from public, anon, authenticated;

create or replace function public.reservations_rebalance_credits()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    -- A booking that was cancelled, moved or deleted: its old member-month.
    perform public.rebalance_member_credits(old.member_id, old.starts_at, old.id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.rebalance_member_credits(new.member_id, new.starts_at, new.id);
  end if;
  return null;
end $fn$;

revoke execute on function public.reservations_rebalance_credits() from public, anon, authenticated;

drop trigger if exists reservations_rebalance_credits on public.reservations;
create trigger reservations_rebalance_credits
  after insert or update of status, starts_at, ends_at, member_id or delete on public.reservations
  for each row execute function public.reservations_rebalance_credits();

-- ── what else changes a member's need ──────────────────────────────────
-- A higher subscription, a switch of overage policy, or extra half-days
-- granted: bookings already held may no longer need their credits. Those
-- are given back for every month the member holds uses in. (A LOWER need
-- never allocates here — no booking is being made; the next one does.)
create or replace function public.members_rebalance_credits()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_at timestamptz;
begin
  for v_at in
    select min(r.starts_at)
      from public.member_credit_uses u
      join public.reservations r on r.id = u.reservation_id
     where r.member_id = coalesce(new.member_id, old.member_id)
       and u.released_at is null
     group by date_trunc('month', r.starts_at)
  loop
    perform public.rebalance_member_credits(coalesce(new.member_id, old.member_id), v_at, null);
  end loop;
  return null;
end $fn$;

revoke execute on function public.members_rebalance_credits() from public, anon, authenticated;

create or replace function public.member_rows_rebalance_credits()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_at timestamptz;
begin
  for v_at in
    select min(r.starts_at)
      from public.member_credit_uses u
      join public.reservations r on r.id = u.reservation_id
     where r.member_id = new.id
       and u.released_at is null
     group by date_trunc('month', r.starts_at)
  loop
    perform public.rebalance_member_credits(new.id, v_at, null);
  end loop;
  return null;
end $fn$;

revoke execute on function public.member_rows_rebalance_credits() from public, anon, authenticated;

drop trigger if exists members_rebalance_credits on public.members;
create trigger members_rebalance_credits
  after update of subscription_pct, overage_policy on public.members
  for each row execute function public.member_rows_rebalance_credits();

drop trigger if exists quota_extensions_rebalance_credits on public.quota_extensions;
create trigger quota_extensions_rebalance_credits
  after insert or delete on public.quota_extensions
  for each row execute function public.members_rebalance_credits();

select public.set_deskilo_schema_version(237);
