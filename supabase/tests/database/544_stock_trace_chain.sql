-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4432 (0923): the trace of a lot or a piece through every movement. Three baskets are received, two move to
-- FLOOR and one comes back: the lot's chain is the three movements in order with the delivery named; a piece's
-- chain is its own movements; a movement answers its lot's chain; one subject at a time; another business's lot
-- and an assistant are refused; the step limit truncates. Rolled back.
begin;
select plan(12);

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
create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create or replace function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
create or replace function pg_temp.mv(p_req int, p_lines text, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_reason))
$f$;
create or replace function pg_temp.trace(p_user int, p_args text, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_trace_chain_v1(%L, %s)::text', pg_temp.u(101), p_args), p_delegated)
$f$;
create or replace function pg_temp.reasons(p text) returns text language sql immutable as $f$
  -- one transaction gives every movement the same time: the steps are compared as a set, sorted
  select string_agg(s ->> 'reason', ' > ' order by s ->> 'reason') from jsonb_array_elements(p::jsonb -> 'steps') s
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'trace-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Trace A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true, "stockManagement": true, "stockLots": true, "stockTags": true, "stockItemGroups": true}', '{}'),
  (pg_temp.u(102), 'Trace B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2), '{"services": true, "stockManagement": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(102), pg_temp.u(2), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(303), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit');
insert into public.stock_locations (id, workspace_id, parent_id, kind, code) values (pg_temp.u(901), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'FLOOR');

select pg_temp.mv(910, format('[{"item_id": "%s", "quantity": "3", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D6BB01"}, {"tag": "E28068940000401561D6BB02"}, {"tag": "E28068940000401561D6BB03"}], "new_lot": {"total_cost_minor": 3000}}]',
  pg_temp.u(303), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt');
select set_config('t.lot', (select id::text from public.stock_lots where item_id = pg_temp.u(303) order by created_datetime limit 1), false);
select pg_temp.mv(911, format('[{"item_id": "%s", "lot_id": "%s", "quantity": "2", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D6BB01"}, {"tag": "E28068940000401561D6BB02"}]}]',
  pg_temp.u(303), current_setting('t.lot'), pg_temp.loc('MAIN'), pg_temp.loc('FLOOR')), 'transfer');
select pg_temp.mv(912, format('[{"item_id": "%s", "lot_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D6BB01"}]}]',
  pg_temp.u(303), current_setting('t.lot'), pg_temp.loc('FLOOR'), pg_temp.loc('MAIN')), 'transfer');
select set_config('t.piece2', (select piece_id::text from public.stock_tags where workspace_id = pg_temp.u(101) and code = 'E28068940000401561D6BB02'), false);
select set_config('t.move', (select id::text from public.stock_movements where workspace_id = pg_temp.u(101) and reason = 'receipt' limit 1), false);

select is(pg_temp.reasons(pg_temp.trace(1, format('p_lot_id => %L', current_setting('t.lot')))), 'receipt > transfer > transfer',
  'a lot''s chain is its three movements');
select is((select s ->> 'pieces' from jsonb_array_elements(pg_temp.trace(1, format('p_lot_id => %L', current_setting('t.lot')))::jsonb -> 'steps') s
            where s #>> '{from,code}' = 'MAIN' and s #>> '{to,code}' = 'FLOOR'),
  '2', 'each step names its places and the pieces it carried (MAIN to FLOOR, two)');
select is(pg_temp.reasons(pg_temp.trace(1, format('p_piece_id => %L', current_setting('t.piece2')))), 'receipt > transfer',
  'a piece''s chain is its own movements only');
select is(pg_temp.trace(1, format('p_piece_id => %L', current_setting('t.piece2')))::jsonb #>> '{piece,place,code}', 'FLOOR',
  'and says where the piece is now');
select is(pg_temp.reasons(pg_temp.trace(1, format('p_movement_id => %L', current_setting('t.move')))), 'receipt > transfer > transfer',
  'a movement answers its lot''s chain');
select is(pg_temp.trace(1, format('p_lot_id => %L', current_setting('t.lot')))::jsonb #>> '{origin,reason}', 'receipt',
  'the origin of the lot is its receipt');
select is((pg_temp.trace(1, format('p_lot_id => %L, p_limit => 2', current_setting('t.lot')))::jsonb ->> 'truncated') || ' ' ||
          jsonb_array_length(pg_temp.trace(1, format('p_lot_id => %L, p_limit => 2', current_setting('t.lot')))::jsonb -> 'steps'),
  'true 2', 'the step limit truncates and says so');
select is(left(pg_temp.trace(1, format('p_lot_id => %L, p_piece_id => %L', current_setting('t.lot'), current_setting('t.piece2'))), 9), 'ERR DKG11',
  'one subject at a time');
select is(left(pg_temp.trace(2, format('p_lot_id => %L', current_setting('t.lot'))), 9), 'ERR DKN01',
  'a member of another business reads nothing');
select is(left(pg_temp.trace(1, format('p_lot_id => %L', current_setting('t.lot')), true), 9), 'ERR DKN01',
  'an assistant reads nothing');

update public.workspaces set feature_flags = feature_flags || '{"stockTags": false}' where id = pg_temp.u(101);
select is(left(pg_temp.trace(1, format('p_piece_id => %L', current_setting('t.piece2'))), 9), 'ERR DKG01',
  'a business that does not use tags reads no piece''s trace');
update public.workspaces set feature_flags = feature_flags || '{"stockManagement": false}' where id = pg_temp.u(101);
select is(left(pg_temp.trace(1, format('p_lot_id => %L', current_setting('t.lot'))), 9), 'ERR DKG01',
  'a business that does not use the stock reads no trace');

select * from finish();
rollback;
