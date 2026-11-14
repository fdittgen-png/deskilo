-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0767 (#3843) -- what each booking of a period was or will be charged, as
-- the server holds it, for the desk calendar's bookings table:
--  * a room booking with its open charge: the amount, in the business's
--    currency;
--  * a booking paid by a pass, or by a carnet: said, with no amount of its
--    own;
--  * a booking that counts toward no quota (outside the counted hours, or a
--    place that is not a seat of the quota): free;
--  * any other booking is part of its member's month: covered by the
--    subscription when the month has no extra half-days, else it counts
--    toward the month's extra half-days -- with no amount, since the
--    statement does not say which booking of a month was the extra one.
-- Who reads it: the rule of the charge -- whoever reads the business's
-- finances reads every booking's; a member reads their own.

create or replace function public.booking_prices(p_workspace_id uuid, p_from timestamptz, p_to timestamptz)
returns table (reservation_id uuid, member_id uuid, kind text, amount_cents integer, currency text)
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_all boolean;
  v_me uuid;
  v_currency text;
  v_rules jsonb;
  v_tz text;
  v_r public.reservations;
  v_month text;
  v_extra jsonb := '{}'::jsonb;
  v_key text;
begin
  if not public.is_member_of(p_workspace_id) then
    raise exception 'not a member of this workspace' using errcode = 'DKN01';
  end if;
  if p_from is null or p_to is null or p_to <= p_from then
    raise exception 'a period ends after it starts' using errcode = '22023';
  end if;
  v_all := p_workspace_id in (select public.workspaces_permitting(array['viewFinances']));
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = (select auth.uid()) limit 1;
  select w.currency_code, w.booking_rules, coalesce(nullif(w.timezone, ''), 'UTC')
    into v_currency, v_rules, v_tz
    from public.workspaces w where w.id = p_workspace_id;

  for v_r in
    select r.* from public.reservations r
     where r.workspace_id = p_workspace_id
       and r.status in ('reserved', 'checked_in', 'completed')
       and r.starts_at < p_to and r.ends_at > p_from
       and (v_all or r.member_id = v_me)
     order by r.starts_at, r.id
  loop
    reservation_id := v_r.id;
    member_id := v_r.member_id;
    amount_cents := null;
    currency := null;
    select c.amount_cents into amount_cents from public.reservation_charges c
     where c.reservation_id = v_r.id and c.reversed_at is null;
    if amount_cents is not null then
      kind := 'charge';
      currency := v_currency;
    elsif exists (select 1 from public.guest_passes p
                   where p.workspace_id = p_workspace_id and p.revoked_at is null
                     and v_r.id = any(p.reservation_ids)) then
      kind := 'pass';
    elsif exists (select 1 from public.member_credit_uses u
                   where u.reservation_id = v_r.id and u.released_at is null) then
      kind := 'carnet';
    elsif not (public.reservation_counts_for_usage(v_r, v_rules, v_tz)
               and public.reservation_uses_seat_quota(v_r)) then
      kind := 'free';
    else
      -- the member's month, read once: its extra half-days
      v_month := to_char(v_r.starts_at at time zone v_tz, 'YYYY-MM');
      v_key := v_r.member_id::text || '/' || v_month;
      if not v_extra ? v_key then
        v_extra := v_extra || jsonb_build_object(v_key,
          coalesce((public.member_statement(v_r.member_id, v_month) ->> 'extra_half_days')::int, 0));
      end if;
      kind := case when (v_extra ->> v_key)::int > 0 then 'overage' else 'subscription' end;
    end if;
    return next;
  end loop;
end;
$fn$;
revoke execute on function public.booking_prices(uuid, timestamptz, timestamptz) from public, anon;
grant execute on function public.booking_prices(uuid, timestamptz, timestamptz) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(767);
