-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0513 (#2575) -- what a member pays for a rented room is charged when the
-- booking lands, and the price they accepted is frozen.
--
-- 0496 told a member what one use of a rented room costs THEM (room_offer_v1)
-- but nothing billed it. The existing billing authority for a one-off sale is
-- the member ledger: a `charge` entry becomes an invoice line
-- (invoice_lines_for) and lowers the statement balance (member_statement), and
-- buy_package is the precedent. A booking in a rented room now writes such an
-- entry in the same transaction as the reservation, from the one place every
-- booking passes (an AFTER trigger on `reservations`, beside the rental
-- guard of 0496).
--
--   * The fee is the most specific one for the member (their member row, a
--     role, their plan, the general fee), per unit; when a rental defines
--     several units the cheapest total for this booking wins.
--   * The units follow the statement's own rule: half days by the workspace's
--     granularity (slots touched, or hours per day capped at two), hours
--     rounded up, days touched.
--   * `reservation_charges` keeps the quote (rental revision, unit, units,
--     unit fee, VAT) and points at the ledger entry. A later change of the
--     rental's fees never reprices a booking; a booking whose billable shape
--     changes (time, place, member) is re-quoted at that moment.
--   * The ledger is append-only: a booking that is cancelled, released or
--     deleted, or re-quoted, is reversed by a credit adjustment of the same
--     amount, VAT and period; the charge row keeps both ids.
--
-- Bookings made before this migration are not charged. Fees are net prices;
-- the workspace's default VAT is added at invoicing, as for a package.

create table public.reservation_charges (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  reservation_id uuid references public.reservations(id) on delete set null,
  member_id uuid not null,
  rental_id uuid references public.room_rentals(id) on delete set null,
  rental_revision int not null,
  unit text not null check (unit in ('half_day', 'hour', 'day')),
  units int not null check (units >= 1),
  unit_fee_cents bigint not null check (unit_fee_cents > 0),
  amount_cents int not null check (amount_cents > 0),
  vat_percent numeric not null check (vat_percent >= 0 and vat_percent < 100),
  period text not null check (period ~ '^[0-9]{4}-[0-9]{2}$'),
  description text not null,
  ledger_charge_id uuid not null,
  ledger_reversal_id uuid,
  reversed_at timestamptz,
  check (amount_cents = units * unit_fee_cents),
  check ((ledger_reversal_id is null) = (reversed_at is null)),
  foreign key (workspace_id, member_id) references public.members(workspace_id, id) on delete restrict,
  foreign key (workspace_id, ledger_charge_id) references public.ledger_entries(workspace_id, id),
  foreign key (workspace_id, ledger_reversal_id) references public.ledger_entries(workspace_id, id)
);
select public.ensure_system_columns('reservation_charges');
create unique index reservation_charges_open on public.reservation_charges (reservation_id)
  where reversed_at is null;
create index reservation_charges_member on public.reservation_charges (workspace_id, member_id, period);

alter table public.reservation_charges enable row level security;
revoke all on public.reservation_charges from public, anon, authenticated;
grant select on public.reservation_charges to authenticated;
-- A member reads what they were charged; finance readers read all of it.
create policy reservation_charges_select on public.reservation_charges for select to authenticated
  using (
    workspace_id in (select public.workspaces_permitting(array['viewFinances']))
    or member_id in (select m.id from public.members m where m.user_id = (select auth.uid()))
  );
create policy mcp_delegated_deny on public.reservation_charges as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the fee of a member ────────────────────────────────────────────────────
-- The same choice room_offer_v1 shows: per unit, the most specific fee.
create or replace function public.room_fees_for(p_rental uuid, p_member uuid)
returns table (unit text, fee_cents bigint)
language sql stable security definer set search_path = public as $fn$
  select distinct on (f.unit) f.unit, f.fee_cents
    from public.room_rental_fees f
   where f.rental_id = p_rental
     and (f.member_id = p_member
          or f.plan_id = (select m.plan_id from public.members m where m.id = p_member)
          or exists (select 1 from public.workspace_role_members rm
                      where rm.member_id = p_member and rm.role_id = f.role_id)
          or num_nonnulls(f.member_id, f.plan_id, f.role_id) = 0)
   order by f.unit, (f.member_id is not null) desc, (f.role_id is not null) desc,
            (f.plan_id is not null) desc;
$fn$;
revoke execute on function public.room_fees_for(uuid, uuid) from public, anon, authenticated;

-- ── how many units a booking is ────────────────────────────────────────────
-- hour: rounded up, at least one. day: the local days it touches. half_day:
-- with the 'hours' granularity, per local day ceil(minutes / half-day length)
-- capped at two and at least one (the statement's rule); otherwise the
-- half-day slots (before / after the boundary) the booking overlaps.
create or replace function public.room_use_units(
  p_unit text, p_start timestamptz, p_end timestamptz, p_tz text,
  p_bound int, p_gran text, p_half_minutes numeric
) returns int language sql stable set search_path = public as $fn$
  with l as (
    select (p_start at time zone p_tz) as s, (p_end at time zone p_tz) as e
  ), d as (
    select g::timestamp as d0
      from l, generate_series(l.s::date::timestamp, (l.e - interval '1 second')::date::timestamp, interval '1 day') g
  )
  select case p_unit
    when 'hour' then greatest(1, ceil(extract(epoch from (p_end - p_start)) / 3600.0)::int)
    when 'day' then (select count(*)::int from d)
    when 'half_day' then case when p_gran = 'hours' then
      (select coalesce(sum(least(2, greatest(1, ceil(
          extract(epoch from (least(l.e, d.d0 + interval '1 day') - greatest(l.s, d.d0))) / 60.0
            / p_half_minutes)::int))), 0)::int from d, l)
    else
      (select count(*)::int from d, l, (values (0), (1)) sl(slot)
        where (sl.slot = 0 and l.s < d.d0 + make_interval(mins => p_bound) and l.e > d.d0)
           or (sl.slot = 1 and l.s < d.d0 + interval '1 day' and l.e > d.d0 + make_interval(mins => p_bound)))
    end
  end;
$fn$;
revoke execute on function public.room_use_units(text, timestamptz, timestamptz, text, int, text, numeric) from public, anon, authenticated;

-- ── reversal ───────────────────────────────────────────────────────────────
create or replace function public.reservation_charge_reverse(p_charge uuid)
returns void language plpgsql volatile security definer set search_path = public as $fn$
declare
  c public.reservation_charges;
  v_day date;
  v_credit uuid;
begin
  select * into c from public.reservation_charges where id = p_charge and reversed_at is null for update;
  if c.id is null then return; end if;
  select le.occurred_on into v_day from public.ledger_entries le where le.id = c.ledger_charge_id;
  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on, vat_percent)
  values (c.workspace_id, c.member_id, 'credit', 'adjustment', c.amount_cents,
          'Cancelled: ' || c.description, c.period, v_day, c.vat_percent)
  returning id into v_credit;
  update public.reservation_charges
     set ledger_reversal_id = v_credit, reversed_at = now()
   where id = c.id;
end;
$fn$;
revoke execute on function public.reservation_charge_reverse(uuid) from public, anon, authenticated;

-- ── the trigger: charge when a booking lands, keep the price frozen ────────
create or replace function public.reservation_room_charge()
returns trigger language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_open public.reservation_charges;
  v_counts boolean := new.status in ('reserved', 'checked_in', 'completed');
  v_desk uuid;
  v_office uuid;
  v_rental public.room_rentals;
  v_tz text;
  v_rules jsonb;
  v_bound int;
  v_half numeric;
  v_unit text;
  v_units int;
  v_fee bigint;
  v_vat numeric;
  v_name text;
  v_day date;
  v_period text;
  v_desc text;
  v_charge uuid;
  v_want boolean := false;
begin
  select * into v_open from public.reservation_charges c
   where c.reservation_id = new.id and c.reversed_at is null;
  if not v_counts and v_open.id is null then return new; end if;
  -- A booking that still counts and has not changed shape keeps its charge:
  -- checking in, completing, or the rental ending afterwards unwind nothing.
  if tg_op = 'UPDATE' and v_counts and v_open.id is not null
     and (old.starts_at, old.ends_at, old.member_id, old.seat_id, old.desk_id, old.office_id, old.level_id)
         is not distinct from
         (new.starts_at, new.ends_at, new.member_id, new.seat_id, new.desk_id, new.office_id, new.level_id) then
    return new;
  end if;

  if v_counts then
    v_desk := coalesce(new.desk_id, (select s.desk_id from public.seats s where s.id = new.seat_id));
    v_office := coalesce(new.office_id, (select d.office_id from public.desks d where d.id = v_desk));
    select * into v_rental from public.room_rentals r
     where r.office_id = v_office and r.status = 'active' and new.level_id is null;
    v_want := v_rental.id is not null;
  end if;
  if not v_want and v_open.id is null then return new; end if;

  select w.timezone, w.booking_rules into v_tz, v_rules from public.workspaces w where w.id = new.workspace_id;
  v_bound := coalesce((v_rules->>'half_boundary_minutes')::int, 720);
  if v_bound <= 0 or v_bound >= 1440 then v_bound := 720; end if;
  v_half := greatest(1, coalesce((v_rules->>'half_day_hours')::int, 4)) * 60.0;

  if v_want then
    select q.unit, q.n, q.fee_cents into v_unit, v_units, v_fee
      from (select f.unit, f.fee_cents,
                   public.room_use_units(f.unit, new.starts_at, new.ends_at, v_tz, v_bound,
                                         v_rules->>'granularity', v_half) as n
              from public.room_fees_for(v_rental.id, new.member_id) f
             where f.fee_cents > 0) q
     order by q.n * q.fee_cents, q.unit
     limit 1;
    v_want := v_unit is not null;
  end if;

  -- The price the member accepted stays while the billable shape is the same.
  if v_want and v_open.id is not null
     and v_open.rental_id is not distinct from v_rental.id
     and v_open.member_id = new.member_id
     and v_open.unit = v_unit and v_open.units = v_units then
    return new;
  end if;

  if v_open.id is not null then
    perform public.reservation_charge_reverse(v_open.id);
  end if;
  if not v_want then return new; end if;

  v_day := (new.starts_at at time zone v_tz)::date;
  v_period := to_char(v_day, 'YYYY-MM');
  select o.name into v_name from public.offices o where o.id = v_office;
  v_desc := coalesce(v_name, '') || ' · ' || to_char(v_day, 'YYYY-MM-DD');
  if public.workspace_charges_vat(new.workspace_id) then
    v_vat := coalesce(public.workspace_default_vat_percent(new.workspace_id, v_day), 0);
  else
    v_vat := 0;
  end if;

  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on, vat_percent)
  values (new.workspace_id, new.member_id, 'charge', 'service', (v_units * v_fee)::int,
          v_desc, v_period, v_day, v_vat)
  returning id into v_charge;
  insert into public.reservation_charges
    (workspace_id, reservation_id, member_id, rental_id, rental_revision, unit, units,
     unit_fee_cents, amount_cents, vat_percent, period, description, ledger_charge_id)
  values (new.workspace_id, new.id, new.member_id, v_rental.id, v_rental.revision, v_unit, v_units,
          v_fee, (v_units * v_fee)::int, v_vat, v_period, v_desc, v_charge);
  return new;
end;
$fn$;
revoke execute on function public.reservation_room_charge() from public, anon, authenticated;
drop trigger if exists reservation_room_charge on public.reservations;
create trigger reservation_room_charge
  after insert or update of starts_at, ends_at, status, seat_id, desk_id, office_id, level_id, member_id
  on public.reservations
  for each row execute function public.reservation_room_charge();

-- A deleted booking takes its charge back before the row goes.
create or replace function public.reservation_room_charge_drop()
returns trigger language plpgsql volatile security definer set search_path = public as $fn$
declare v_open uuid;
begin
  select c.id into v_open from public.reservation_charges c
   where c.reservation_id = old.id and c.reversed_at is null;
  if v_open is not null then perform public.reservation_charge_reverse(v_open); end if;
  return old;
end;
$fn$;
revoke execute on function public.reservation_room_charge_drop() from public, anon, authenticated;
drop trigger if exists reservation_room_charge_drop on public.reservations;
create trigger reservation_room_charge_drop
  before delete on public.reservations
  for each row execute function public.reservation_room_charge_drop();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(513);
