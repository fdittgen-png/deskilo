-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4303 (0854): put-away goes through the one stock path. The put-away of a delivery makes
-- no lot and writes no movement itself: it describes its lots and parts and calls
-- stock_apply_lines, and the only function that inserts a lot is the one path. What a
-- put-away gives (lots with their cost state, balances, allocations, movements) is asserted
-- by 490, unchanged. Rolled back.
begin;
select plan(7);

create or replace function pg_temp.def(p_fn regprocedure) returns text language sql stable as $f$
  select regexp_replace(pg_get_functiondef(p_fn), '\s+', ' ', 'g')
$f$;

select ok(pg_temp.def('public.stock_put_away_apply(uuid, uuid, uuid, uuid, jsonb)'::regprocedure) like '%public.stock_apply_lines(%',
  'put-away calls the one path');
select ok(pg_temp.def('public.stock_put_away_apply(uuid, uuid, uuid, uuid, jsonb)'::regprocedure) not like '%insert into public.stock_lots%',
  'put-away makes no lot itself');
select ok(pg_temp.def('public.stock_put_away_apply(uuid, uuid, uuid, uuid, jsonb)'::regprocedure) not like '%stock_record(%',
  'put-away records no movement itself');
select is((select array_agg(p.proname::text order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prokind = 'f' and pg_get_functiondef(p.oid) ilike '%insert into public.stock_lots%'),
  array['stock_apply_lines'], 'the one path is the only function that inserts a lot');
select ok(pg_temp.def('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure) like '%''put_away''%',
  'the one path knows the put-away mode');
select ok(pg_temp.def('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure) like '%cost_state%'
          and pg_temp.def('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure) like '%lot_group%',
  'and makes a lot with a cost state, shared by the parts of one group');
-- the generic door keeps refusing what it refused: a new lot there needs its cost
select is(has_function_privilege('authenticated', 'public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)', 'execute'), false,
  'the one path is not callable by a client');

select * from finish();
rollback;
