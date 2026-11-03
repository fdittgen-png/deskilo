-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- #2578: the capacity figure of a window costs time in the number of
-- reservations, not in the number of seats it answers for. Measured on a
-- dataset of 601,344 reservations and 1,500 seats, one month took 225 s
-- (about 123 million buffer touches): the reservations were joined to the
-- seats' history rows on four OR-ed keys (a nested loop with a join filter,
-- reservations x seats) and every seat then scanned the whole joined set
-- twice (a correlated range_agg and a correlated sum).
--
-- The same figure now joins on one key at a time (four hashable joins; a pair
-- that matches on several keys is still one row, as the OR join gave) and
-- aggregates per seat in one pass. The result is the same answer, row for row.
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

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.kpi_seat_capacity(uuid,timestamptz,timestamptz,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  ), bound as (
    select sc.seat_id,
           tstzmultirange(tstzrange(tg.starts_at, tg.ends_at, '[)')) * sc.held as rng
      from targets tg
      join scope sc
        on tg.seat_id = sc.seat_id or tg.desk_id = sc.desk_id
        or tg.office_id = sc.office_id or tg.level_id = sc.level_id
  ), per_seat as ($a$,
    $a$  ), bound as (
    select sc.seat_id,
           tstzmultirange(tstzrange(tg.starts_at, tg.ends_at, '[)')) * sc.held as rng
      from targets tg
      join scope sc on tg.seat_id = sc.seat_id
    union all
    select sc.seat_id,
           tstzmultirange(tstzrange(tg.starts_at, tg.ends_at, '[)')) * sc.held
      from targets tg
      join scope sc on tg.desk_id = sc.desk_id
     where not coalesce(tg.seat_id = sc.seat_id, false)
    union all
    select sc.seat_id,
           tstzmultirange(tstzrange(tg.starts_at, tg.ends_at, '[)')) * sc.held
      from targets tg
      join scope sc on tg.office_id = sc.office_id
     where not coalesce(tg.seat_id = sc.seat_id, false)
       and not coalesce(tg.desk_id = sc.desk_id, false)
    union all
    select sc.seat_id,
           tstzmultirange(tstzrange(tg.starts_at, tg.ends_at, '[)')) * sc.held
      from targets tg
      join scope sc on tg.level_id = sc.level_id
     where not coalesce(tg.seat_id = sc.seat_id, false)
       and not coalesce(tg.desk_id = sc.desk_id, false)
       and not coalesce(tg.office_id = sc.office_id, false)
  ), per_seat as ($a$);
  if v_def is null then raise exception '0662: kpi_seat_capacity bound anchor missing'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  ), measured as (
    select p.seat_id, p.open_time, p.offered,
           coalesce((select range_agg(b.rng) from bound b where b.seat_id = p.seat_id),
                    '{}'::tstzmultirange) as reserved,
           coalesce((select sum(public.kpi_multirange_hours(b.rng))
                       from bound b where b.seat_id = p.seat_id), 0) as raw_hours
      from per_seat p
  )$a$,
    $a$  ), bound_seat as (
    select b.seat_id, range_agg(b.rng) as reserved,
           sum(public.kpi_multirange_hours(b.rng)) as raw_hours
      from bound b
     group by b.seat_id
  ), measured as (
    select p.seat_id, p.open_time, p.offered,
           coalesce(bs.reserved, '{}'::tstzmultirange) as reserved,
           coalesce(bs.raw_hours, 0) as raw_hours
      from per_seat p
      left join bound_seat bs on bs.seat_id = p.seat_id
  )$a$);
  if v_def is null then raise exception '0662: kpi_seat_capacity measured anchor missing'; end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(662);
