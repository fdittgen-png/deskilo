-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0321 (#1908) -- a reservation transition judges the state it changes.
--
-- cancel_reservation, check_in_reservation, check_out_reservation and
-- complete_check_out read the reservation, check its status, then update
-- it by id. Under READ COMMITTED two concurrent commands both read the
-- same committed status: a check-in arriving while a cancellation is
-- uncommitted saw `reserved`, waited only at its UPDATE, and then wrote
-- `checked_in` over the cancellation.
--
-- Each function's initial read now takes the row lock (`for update`): the
-- second command waits for the first to commit and then judges the state
-- the first left, refusing with its existing message. Patched in place at
-- an asserted anchor, which must occur exactly once in each body; the
-- rest of every function is unchanged.

do $patch$
declare
  v_fn record;
  v_def text;
  v_anchor text;
  v_count int;
begin
  for v_fn in
    select p.oid, p.proname
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('cancel_reservation', 'check_in_reservation',
                         'check_out_reservation', 'complete_check_out')
  loop
    v_def := pg_get_functiondef(v_fn.oid);
    v_anchor := case
      when position(E'select r.* into v_res from public.reservations r\n    where r.id = p_reservation_id;' in v_def) > 0
        then E'select r.* into v_res from public.reservations r\n    where r.id = p_reservation_id;'
      else 'select r.* into v_res from public.reservations r where r.id = p_reservation_id;'
    end;
    v_count := (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor);
    if v_count <> 1 then
      raise exception '0321: % carries the read anchor % times, expected once', v_fn.proname, v_count;
    end if;
    execute replace(v_def, v_anchor, replace(v_anchor, 'p_reservation_id;', 'p_reservation_id for update;'));
  end loop;
  -- Every one of the four was found and patched.
  if (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public'
         and p.proname in ('cancel_reservation', 'check_in_reservation',
                           'check_out_reservation', 'complete_check_out')
         and pg_get_functiondef(p.oid) like '%p_reservation_id for update;%') < 4 then
    raise exception '0321: not every transition takes the row lock';
  end if;
end;
$patch$;

select public.set_deskilo_schema_version(321);
