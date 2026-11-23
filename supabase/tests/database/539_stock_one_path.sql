-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4398: one stock path. What a return and a count decision do to an item tracked piece by piece, measured before the refactor:
-- the piece rule hooked into stock_apply_lines (0887) must hold for every command that moves goods. Rolled back.
begin;
select plan(19);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', (jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2'))::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
    -- the deferred piece check is held at commit; a rolled-back harness holds it here
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
create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create or replace function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
create or replace function pg_temp.mv(p_user int, p_req int, p_lines text, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_reason))
$f$;
create or replace function pg_temp.apply(p_mode text, p_reason text, p_lines text, p_links text default '{}') returns text language plpgsql as $f$
begin
  perform public.stock_apply_lines(pg_temp.u(101), null, gen_random_uuid(), p_lines::jsonb, p_reason, now(), p_links::jsonb, p_mode);
  return 'ok';
exception when others then
  return sqlstate;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'path-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'One path', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockLots": true, "stockTakeOut": true, "stockTags": true, "stockItemGroups": true, "stockReturns": true, "stockCounts": true}',
   '{"admin": ["manageStock", "approveStockAdjustments"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(303), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit'),
  (pg_temp.u(304), pg_temp.u(101), 'Lot goods', 100, true, 'piece', 'lot', true, null),
  (pg_temp.u(305), pg_temp.u(101), 'Mugs', 100, true, 'piece', 'none', true, null),
  (pg_temp.u(306), pg_temp.u(101), 'Plain', 100, true, 'piece', 'none', true, null);
insert into public.item_variants (id, workspace_id, item_id, canonical, active) values (pg_temp.u(951), pg_temp.u(101), pg_temp.u(305), 'size:M', true);

select set_config('t.receipt', pg_temp.mv(3, 910, format('[{"item_id": "%s", "quantity": "3", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D679F1"}, {"tag": "E28068940000401561D679F2"}, {"tag": "E28068940000401561D679F3"}], "new_lot": {"total_cost_minor": 3000}}]',
  pg_temp.u(303), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt'), false);
select is(current_setting('t.receipt') like '{%', true, 'three baskets are received piece by piece');

-- a supplier return of one of them: the return line carries no pieces
select set_config('t.ret', pg_temp.run_as(pg_temp.u(3), format('select public.stock_return_v1(%L, %L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(920), pg_temp.u(921), 'supplier',
  format('[{"return_line_id": "%s", "source_movement_id": "%s", "quantity": "1", "location": "%s"}]', pg_temp.u(922), (select id from public.stock_movements where workspace_id = pg_temp.u(101) and item_id = pg_temp.u(303) and reason = 'receipt'), pg_temp.loc('MAIN')))), false);
select is(left(current_setting('t.ret'), 9), 'ERR DKG25', 'a return of a piece-tracked item that names no piece is refused at commit (DKG25)');
select set_config('t.ret2', pg_temp.run_as(pg_temp.u(3), format('select public.stock_return_v1(%L, %L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(923), pg_temp.u(924), 'supplier',
  format('[{"return_line_id": "%s", "source_movement_id": "%s", "quantity": "1", "location": "%s", "units": [{"tag": "E28068940000401561D679F1"}]}]', pg_temp.u(925), (select id from public.stock_movements where workspace_id = pg_temp.u(101) and item_id = pg_temp.u(303) and reason = 'receipt'), pg_temp.loc('MAIN')))), false);
select is(left(current_setting('t.ret2'), 7), '{"kind"', 'a return that names the piece is made');
select is((select u.state from public.stock_tagged_units u join public.stock_tags t on t.piece_id = u.id where t.code = 'E28068940000401561D679F1'), 'returned', 'and the piece is returned, at the supplier');

-- a count of 2 against 3 pieces: its decision adjusts the ledger without naming pieces
select set_config('t.count', pg_temp.run_as(pg_temp.u(3), format('select public.stock_count_record_v1(%L, %L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(930), pg_temp.u(931),
  format('{"item_id": "%s", "location_id": "%s", "lot_id": "%s"}', pg_temp.u(303), pg_temp.loc('MAIN'), (select id from public.stock_lots where item_id = pg_temp.u(303))), '1')), false);
select set_config('t.decide', pg_temp.run_as(pg_temp.u(1), format('select public.stock_count_decide_v1(%L, %L, %L, %L)::text', pg_temp.u(101), pg_temp.u(932), pg_temp.u(931), 'apply')), false);
select is(left(current_setting('t.decide'), 9), 'ERR DKG25', 'applying a count of a piece-tracked item names no piece and is refused at commit (DKG25), as before the refactor: ' || left(current_setting('t.count'), 160));

-- what the booking bridge, the opening stock and a return record, they record as given: today's master data does not refuse them
select is(pg_temp.apply('bridge', 'receipt', format('[{"item_id": "%s", "from": "%s", "to": "%s", "quantity": "2"}]', pg_temp.u(305), pg_temp.place('supplier'), pg_temp.loc('MAIN')), format('{"event_id": "%s"}', pg_temp.u(960))),
  'ok', 'a supply confirmed for an item that has variants records (the supply names none)');
select is(pg_temp.apply('generic', 'receipt', format('[{"item_id": "%s", "from": "%s", "to": "%s", "quantity": "2"}]', pg_temp.u(305), pg_temp.place('supplier'), pg_temp.loc('MAIN'))),
  'DKG12', 'while the generic door still asks for the variant');
select is(pg_temp.apply('bridge', 'receipt', format('[{"item_id": "%s", "from": "%s", "to": "%s", "quantity": "2"}]', pg_temp.u(304), pg_temp.place('supplier'), pg_temp.loc('MAIN')), format('{"event_id": "%s"}', pg_temp.u(961))),
  'ok', 'and for a lot-tracked item, which the supply names no lot for');
select is(pg_temp.apply('generic', 'receipt', format('[{"item_id": "%s", "from": "%s", "to": "%s", "quantity": "2"}]', pg_temp.u(304), pg_temp.place('supplier'), pg_temp.loc('MAIN'))),
  'DKG06', 'while the generic door still asks for the lot');
select is(pg_temp.apply('open', 'opening', format('[{"item_id": "%s", "from": "%s", "to": "%s", "quantity": "3"}]', pg_temp.u(304), pg_temp.place('opening'), pg_temp.loc('MAIN'))),
  'ok', 'the opening stock of a lot-tracked item is recorded, so stock management can be switched on');
select is((select count(*)::int from public.stock_movements where workspace_id = pg_temp.u(101) and item_id = pg_temp.u(304) and reason = 'opening' and lot_id is null), 1, 'as one movement, with the lot it was given: none');

-- a return of a movement without a lot records one part, and an insufficient balance is the ledger's refusal, as before
select pg_temp.mv(3, 970, format('[{"item_id": "%s", "quantity": "5", "from": "%s", "to": "%s"}]', pg_temp.u(306), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt');
select pg_temp.mv(3, 971, format('[{"item_id": "%s", "quantity": "4", "from": "%s", "to": "%s"}]', pg_temp.u(306), pg_temp.loc('MAIN'), pg_temp.place('loss')), 'loss');
select is(left(pg_temp.run_as(pg_temp.u(3), format('select public.stock_return_v1(%L, %L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(972), pg_temp.u(973), 'supplier',
  format('[{"return_line_id": "%s", "source_movement_id": "%s", "quantity": "3", "location": "%s"}]', pg_temp.u(974), (select id from public.stock_movements where workspace_id = pg_temp.u(101) and item_id = pg_temp.u(306) and reason = 'receipt'), pg_temp.loc('MAIN')))), 9),
  'ERR DKG03', 'returning more than the place holds is refused for lack of goods (DKG03), never made up from other lots');

-- the sale bridge records the lot it was given, an expired one included
select is(pg_temp.apply('bridge', 'sale', format('[{"item_id": "%s", "from": "%s", "to": "%s", "quantity": "1", "expired_ack": true}]', pg_temp.u(306), pg_temp.loc('MAIN'), pg_temp.place('customer')), format('{"event_id": "%s"}', pg_temp.u(962))),
  'ok', 'a sale of the stock a place holds is recorded as it was taken');

-- a correction never makes a piece from nothing: the tag it names is one the business knows
select set_config('t.retmv', (current_setting('t.ret2')::jsonb #>> '{lines,0,movement_id}'), false);
select is(left(pg_temp.run_as(pg_temp.u(3), format('select public.stock_return_v1(%L, %L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(980), pg_temp.u(981), 'correction',
  format('[{"return_line_id": "%s", "source_movement_id": "%s", "quantity": "1", "units": [{"tag": "E28068940000401561D67AAA"}]}]', pg_temp.u(982), current_setting('t.retmv')))), 9),
  'ERR DKG26', 'a correction of a return that names an unknown tag is refused (DKG26)');
select is(left(pg_temp.run_as(pg_temp.u(3), format('select public.stock_return_v1(%L, %L, %L, %L, %L::jsonb)::text', pg_temp.u(101), pg_temp.u(983), pg_temp.u(984), 'correction',
  format('[{"return_line_id": "%s", "source_movement_id": "%s", "quantity": "1", "units": [{"tag": "E28068940000401561D679F1"}]}]', pg_temp.u(985), current_setting('t.retmv')))), 7), '{"kind"',
  'and one that names the piece it returned puts it back');

-- the decision of a count records what the count recorded: today's variants and places do not refuse it (#4415, 0919)
select is(pg_temp.apply('count', 'adjustment', format('[{"item_id": "%s", "from": "%s", "to": "%s", "quantity": "1", "expired_ack": true}]', pg_temp.u(305), pg_temp.place('loss'), pg_temp.loc('MAIN'))),
  'ok', 'a count decided after its item gained variants is recorded (the generic door asks for the variant)');
insert into public.stock_locations (id, workspace_id, parent_id, kind, code, active) values (pg_temp.u(990), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'GONE', false);
select is(pg_temp.apply('count', 'adjustment', format('[{"item_id": "%s", "from": "%s", "to": "%s", "quantity": "1", "expired_ack": true}]', pg_temp.u(306), pg_temp.place('loss'), pg_temp.u(990))),
  'ok', 'and after its place was deactivated');

-- the acceptance of #4398: one function writes the ledger
select is((select string_agg(p.proname::text, ',' order by p.proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prosrc ~ 'stock_record\('), 'stock_apply_lines', 'exactly one function of the schema calls stock_record: stock_apply_lines');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname = 'stock_record'
              and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))), 0,
  'and no client role may call the writer itself');

select * from finish();
rollback;
