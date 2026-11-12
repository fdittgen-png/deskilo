-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0738 — #3809 (part of #3657, i18n I11a): a room charge's line is a frozen
-- snapshot printed in the document's language. Until now the server wrote
-- `room · YYYY-MM-DD` as text, and every document printed that text whatever
-- its language.
--
-- `ledger_entries.text_facts` holds what a description says, as facts:
-- `{kind, version, values}`, frozen when the entry is written (the room's
-- name and the day as they were, never a live id). `description` stays as
-- it was, the fallback text: every reader that prints it keeps working, and
-- a reader that does not know a kind or version prints it. The line builder
-- and the issuer's annex carry the facts into the signed invoice snapshot
-- (`text` beside `label`, only when there are facts), so an issued line
-- never changes with a later rename. Rows written before keep their text.
--
-- Kinds: `room_day` {room, day} (the room charge, 0513) and `cancelled`
-- {of: the cancelled entry's facts} (its reversal).
--
-- 0168's 'Site' is a one-time backfill of 2025, already applied and never run
-- again: nothing to do (#3809).

alter table public.ledger_entries add column if not exists text_facts jsonb;
alter table public.ledger_entries
  drop constraint if exists ledger_entries_text_facts_check,
  add constraint ledger_entries_text_facts_check check (
    text_facts is null
    or (jsonb_typeof(text_facts) = 'object'
        and jsonb_typeof(text_facts -> 'kind') = 'string'
        and jsonb_typeof(text_facts -> 'version') = 'number'
        and jsonb_typeof(text_facts -> 'values') = 'object'));

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
    (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on, vat_percent,
     text_facts)
  values (new.workspace_id, new.member_id, 'charge', 'service', (v_units * v_fee)::int,
          v_desc, v_period, v_day, v_vat,
          -- #3809: the room and the day as they were; the document prints them
          -- in its own language, the description stays the fallback.
          jsonb_build_object('kind', 'room_day', 'version', 1,
            'values', jsonb_build_object('room', coalesce(v_name, ''), 'day', v_day::text)))
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

create or replace function public.reservation_charge_reverse(p_charge uuid)
returns void language plpgsql volatile security definer set search_path = public as $fn$
declare
  c public.reservation_charges;
  v_day date;
  v_credit uuid;
  v_facts jsonb;
begin
  select * into c from public.reservation_charges where id = p_charge and reversed_at is null for update;
  if c.id is null then return; end if;
  select le.occurred_on, le.text_facts into v_day, v_facts
    from public.ledger_entries le where le.id = c.ledger_charge_id;
  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on, vat_percent,
     text_facts)
  values (c.workspace_id, c.member_id, 'credit', 'adjustment', c.amount_cents,
          'Cancelled: ' || c.description, c.period, v_day, c.vat_percent,
          -- #3809: the cancelled charge, as its own facts said it.
          case when v_facts is null then null
               else jsonb_build_object('kind', 'cancelled', 'version', 1,
                                       'values', jsonb_build_object('of', v_facts)) end)
  returning id into v_credit;
  update public.reservation_charges
     set ledger_reversal_id = v_credit, reversed_at = now()
   where id = c.id;
end;
$fn$;
revoke execute on function public.reservation_charge_reverse(uuid) from public, anon, authenticated;

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  if position(p_old in p_def) = 0 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- The line builder carries the facts beside the label, only when there are
-- facts, so a line without them is exactly what it was.
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.invoice_lines_for(uuid, text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    'select kind, category, description,',
    'select kind, category, description, text_facts,');
  v_def := pg_temp.anchor_replace(v_def,
    E'    v_lines := v_lines || jsonb_build_object(\n      ''kind'', v_row.category,',
    E'    v_lines := v_lines || (jsonb_build_object(\n      ''kind'', v_row.category,');
  v_def := pg_temp.anchor_replace(v_def,
    E'                           else v_row.amount_cents end);\n  end loop;',
    E'                           else v_row.amount_cents end)\n'
    || E'      -- #3809: the description as facts, frozen into the signed line.\n'
    || E'      || case when v_row.text_facts is null then ''{}''::jsonb\n'
    || E'              else jsonb_build_object(''text'', v_row.text_facts) end);\n  end loop;');
  if v_def is null then
    raise exception 'invoice_lines_for: an anchor of #3809 was not found';
  end if;
  execute v_def;

  select pg_get_functiondef('public.create_invoice(uuid, uuid, text, uuid, boolean, text, boolean, text, text, text)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    E'            ''description'', le.description,\n            ''amount_cents'', case when le.kind = ''credit''\n                                 then -le.amount_cents\n                                 else le.amount_cents end)',
    E'            ''description'', le.description,\n            ''amount_cents'', case when le.kind = ''credit''\n                                 then -le.amount_cents\n                                 else le.amount_cents end)\n'
    || E'            -- #3809: the description as facts, in the signed annex.\n'
    || E'            || case when le.text_facts is null then ''{}''::jsonb\n'
    || E'                    else jsonb_build_object(''text'', le.text_facts) end');
  if v_def is null then
    raise exception 'create_invoice: the #3809 anchor was not found';
  end if;
  execute v_def;
end;
$migration$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(738);
