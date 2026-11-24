-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4434 (0926): "where is it". The places of an item add up to what it holds, now and at a past date replayed from the
-- movements; goods loaded for another site say from where to where; goods sold or lost are shown at their virtual place with
-- the movement that moved them; the pieces are listed with place, state and tags; a lot narrows the answer; the refusals are
-- proven (no right, the assistant, an unknown item or lot, a date in the future, the feature off). Rolled back.
begin;
select plan(35);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
    set constraints all immediate;
    set constraints all deferred;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.loc(p_code text, p_ws int default 101) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(p_ws) and code = p_code
$f$;
create or replace function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
create or replace function pg_temp.mv(p_req int, p_lines text, p_reason text, p_days int) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(3), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_reason, now() - make_interval(days => p_days)))
$f$;
create or replace function pg_temp.where_is(p_user int, p_item int, p_lot text default null, p_at text default null, p_delegated boolean default false) returns text language sql as $f$
  select rtrim(pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_where_is_v1(%L, %L, %L, %L)::text', pg_temp.u(101), pg_temp.u(p_item), p_lot, p_at), p_delegated))
$f$;
-- what a place holds in an answer
create or replace function pg_temp.held(p_answer text, p_code text) returns numeric language sql immutable as $f$
  select coalesce(sum((e ->> 'quantity')::numeric), 0) from jsonb_array_elements(p_answer::jsonb -> 'places') e where e ->> 'location_code' = p_code
$f$;
create or replace function pg_temp.f(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb ->> k else p end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'whereis-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Where A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockLots": true, "stockTags": true, "stockTakeOut": true, "stockTransfers": true, "stockItemGroups": true, "stockCounts": true, "stockReturns": true}',
   '{"member": ["countStock"], "admin": ["manageStock"]}'),
  (pg_temp.u(102), 'Where B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), '{"services": true, "stockManagement": false}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Mugs', 900, true, 'piece', 'lot', true);
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(303), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit');
insert into public.stock_locations (id, workspace_id, parent_id, kind, code) values
  (pg_temp.u(901), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'FLOOR'),
  (pg_temp.u(902), pg_temp.u(101), null, 'warehouse', 'ANNEX');

-- ten mugs received at MAIN three days ago (a lot of their own), four moved to FLOOR two days ago, one lost yesterday
select ok(pg_temp.mv(910, format('[{"item_id": "%s", "quantity": "10", "from": "%s", "to": "%s", "new_lot": {"total_cost_minor": 5000, "lot_code": "L-1"}}]',
  pg_temp.u(301), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt', 3) like '{%', 'fixture: the mugs are received');
select set_config('t.lot', (select id::text from public.stock_lots where item_id = pg_temp.u(301) order by created_datetime limit 1), false);
select ok(pg_temp.mv(911, format('[{"item_id": "%s", "quantity": "4", "from": "%s", "to": "%s", "lot_id": "%s"}]',
  pg_temp.u(301), pg_temp.loc('MAIN'), pg_temp.loc('FLOOR'), current_setting('t.lot')), 'transfer', 2) like '{%', 'fixture: four moved to FLOOR');
select ok(pg_temp.run_as(pg_temp.u(3), format($q$select public.stock_loss_v1(%L, %L, %L::jsonb, %L)::text$q$, pg_temp.u(101), pg_temp.u(912),
  format('[{"item_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "lot_id": "%s"}]', pg_temp.u(301), pg_temp.loc('FLOOR'), pg_temp.place('loss'), current_setting('t.lot')),
  now() - interval '1 day')) like '{%', 'fixture: one lost');
-- two more loaded for ANNEX and not yet received
select ok(pg_temp.run_as(pg_temp.u(3), format($q$select public.stock_transfer_load_v1(%L, %L, %L, %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(913), pg_temp.loc('ANNEX'),
  format('[{"item_id": "%s", "quantity": "2", "from": "%s", "to": "%s", "lot_id": "%s"}]', pg_temp.u(301), pg_temp.loc('MAIN'), pg_temp.loc('MAIN'), current_setting('t.lot')))) like '{%', 'fixture: two loaded for ANNEX');
-- three baskets, tagged, at MAIN
select ok(pg_temp.mv(920, format('[{"item_id": "%s", "quantity": "3", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D68F01"}, {"tag": "E28068940000401561D68F02"}, {"tag": "E28068940000401561D68F03"}], "new_lot": {"total_cost_minor": 3000}}]',
  pg_temp.u(303), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt', 3) like '{%', 'fixture: three baskets received');

select set_config('t.now', pg_temp.where_is(3, 301), false);

select is(pg_temp.held(current_setting('t.now'), 'MAIN'), 4::numeric, 'now: MAIN holds what is left after the move and the goods loaded for another site (10 - 4 - 2)');
select is(pg_temp.held(current_setting('t.now'), 'FLOOR'), 3::numeric, 'now: FLOOR holds the four moved less the one lost');
select is(pg_temp.held(current_setting('t.now'), 'TRANSIT'), 2::numeric, 'now: two are in transit');
select is(pg_temp.held(current_setting('t.now'), (select code from public.stock_locations where workspace_id = pg_temp.u(101) and kind = 'loss')), 1::numeric, 'now: the lost mug sits at the loss place');
select is((pg_temp.f(current_setting('t.now'), 'on_hand')), '9.000000', 'the places that are real add up to what the item holds');
select is((select sum(quantity)::text from public.stock_balances b join public.stock_locations l on l.id = b.location_id join public.stock_location_kinds k on k.key = l.kind
            where b.item_id = pg_temp.u(301) and not k.virtual), '9.000000', '... which is what the balances say');
select is(current_setting('t.now')::jsonb #>> '{transit,0,from_location_code}' || '>' || (current_setting('t.now')::jsonb #>> '{transit,0,to_location_code}') || ' ' || (current_setting('t.now')::jsonb #>> '{transit,0,quantity}'),
  'MAIN>ANNEX 2.000000', 'goods in transit say from which place to which');
select is(current_setting('t.now')::jsonb #>> '{documents,0,reason}', 'loss', 'the lost goods name the movement that moved them');

-- as of a past date: replayed from the movements
select set_config('t.d25', pg_temp.where_is(3, 301, null, (now() - interval '2 days 12 hours')::text), false);
select set_config('t.d15', pg_temp.where_is(3, 301, null, (now() - interval '1 day 12 hours')::text), false);
select is(pg_temp.held(current_setting('t.d25'), 'MAIN'), 10::numeric, 'two and a half days ago all ten were at MAIN');
select is(pg_temp.held(current_setting('t.d15'), 'FLOOR') || '/' || pg_temp.held(current_setting('t.d15'), 'MAIN'), '4.000000/6.000000', 'a day and a half ago four were at FLOOR');
select is(pg_temp.f(current_setting('t.d15'), 'on_hand'), '10.000000', 'the places at that date add up to what the item held');
select is(pg_temp.f(pg_temp.where_is(3, 301, null, now()::text), 'on_hand'), pg_temp.f(current_setting('t.now'), 'on_hand'), 'replayed at this moment, the movements give the balances');
select is(current_setting('t.d25')::jsonb -> 'transit', 'null'::jsonb, 'a past date does not claim to know the transit of a transfer');

-- a lot narrows the answer; the pieces are listed with their tags
select is(pg_temp.f(pg_temp.where_is(3, 301, current_setting('t.lot')), 'on_hand'), '9.000000', 'the lot holds all of it');
select is((pg_temp.where_is(3, 303))::jsonb #>> '{pieces,0,tags,0}' is not null, true, 'a piece is listed with its tag');
select is(jsonb_array_length(pg_temp.where_is(3, 303)::jsonb -> 'pieces'), 3, 'all three pieces are listed');

-- a count at FLOOR (the ledger holds 3, 2 are counted) and the correction of the lost mug: the answer still balances
select ok(pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_count_record_v1(%L, %L, %L, %L::jsonb, '2', 'shelf count')::text$q$, pg_temp.u(101), pg_temp.u(930), pg_temp.u(931),
  jsonb_build_object('item_id', pg_temp.u(301), 'location_id', pg_temp.loc('FLOOR'), 'lot_id', current_setting('t.lot'))::text)) like '{%', 'fixture: a count of 2 at FLOOR');
select ok(pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_count_decide_v1(%L, %L, %L, 'apply', 'ok')::text$q$, pg_temp.u(101), pg_temp.u(932), pg_temp.u(931))) like '{%', 'fixture: the count is applied');
select is(pg_temp.held(pg_temp.where_is(3, 301), 'FLOOR'), 2.000000::numeric, 'after the count FLOOR holds what was counted');
select is(pg_temp.f(pg_temp.where_is(3, 301), 'on_hand'),
  (select sum(b.quantity)::text from public.stock_balances b join public.stock_locations l on l.id = b.location_id join public.stock_location_kinds k on k.key = l.kind
    where b.item_id = pg_temp.u(301) and not k.virtual), 'after the count the places still add up to the balances');
select ok(pg_temp.run_as(pg_temp.u(1), format($q$select public.stock_return_v1(%L, %L, %L, 'correction', %L::jsonb)::text$q$, pg_temp.u(101), pg_temp.u(933), pg_temp.u(934),
  jsonb_build_array(jsonb_build_object('return_line_id', pg_temp.u(935), 'source_movement_id', (select id from public.stock_movements where request_id = pg_temp.u(912) order by line_no, part limit 1), 'quantity', '1'))::text)) like '{%', 'fixture: the loss is corrected');
select is(pg_temp.f(pg_temp.where_is(3, 301), 'on_hand'),
  (select sum(b.quantity)::text from public.stock_balances b join public.stock_locations l on l.id = b.location_id join public.stock_location_kinds k on k.key = l.kind
    where b.item_id = pg_temp.u(301) and not k.virtual), 'after the reversal the places still add up to the balances');
select is(pg_temp.f(pg_temp.where_is(3, 301, null, (now() - interval '1 day 12 hours')::text), 'on_hand'), '10.000000', 'and the past is not rewritten by what came after');

-- the refusals
select is(pg_temp.where_is(2, 301), 'ERR DKN01', 'a member who may only count has no right to see the stock');
select is(pg_temp.where_is(3, 301, null, null, true), 'ERR DKN01', 'the assistant has no right to');
select is(pg_temp.where_is(3, 999), 'ERR DKG04', 'an item that does not exist');
select is(pg_temp.where_is(3, 301, pg_temp.u(998)::text), 'ERR DKG04', 'a lot that does not exist');
select is(pg_temp.where_is(3, 301, null, (now() + interval '2 days')::text), 'ERR DKG07', 'a date in the future');
select is(rtrim(pg_temp.run_as(pg_temp.u(4), format('select public.stock_where_is_v1(%L, %L)::text', pg_temp.u(102), pg_temp.u(301)))), 'ERR DKG01', 'stock management off in the business');
select is(pg_temp.where_is(1, 301) is not null, true, 'the owner sees it too');

select * from finish();
rollback;
