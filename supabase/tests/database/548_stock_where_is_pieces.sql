-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4434 (0927): the pieces of "where is it" at a past date, replayed from the movement-piece link: before they were received
-- there are none, after the receipt they are at the place they were received to, after a move the moved one is at its new place,
-- and now (as of this moment) is what the pieces are today; the answer carries the tags and says since when the link is kept.
-- Needs 0922 and 0926. Rolled back.
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


select ok(pg_temp.mv(920, format('[{"item_id": "%s", "quantity": "3", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D68F01"}, {"tag": "E28068940000401561D68F02"}, {"tag": "E28068940000401561D68F03"}], "new_lot": {"total_cost_minor": 3000}}]',
  pg_temp.u(303), pg_temp.place('supplier'), pg_temp.loc('MAIN')), 'receipt', 3) like '{%', 'fixture: three baskets received three days ago');
select set_config('t.lot', (select id::text from public.stock_lots where item_id = pg_temp.u(303) limit 1), false);
select ok(pg_temp.mv(921, format('[{"item_id": "%s", "quantity": "1", "from": "%s", "to": "%s", "lot_id": "%s", "units": [{"tag": "E28068940000401561D68F01"}]}]',
  pg_temp.u(303), pg_temp.loc('MAIN'), pg_temp.loc('FLOOR'), current_setting('t.lot')), 'transfer', 2) like '{%', 'fixture: one moved to FLOOR two days ago');

create or replace function pg_temp.pieces_at(p_ago text) returns jsonb language sql as $f$
  select pg_temp.where_is(3, 303, null, case when p_ago is null then null else (now() - p_ago::interval)::text end)::jsonb -> 'pieces'
$f$;
create or replace function pg_temp.where_of(p_pieces jsonb, p_code text) returns text language sql immutable as $f$
  select count(*)::text from jsonb_array_elements(p_pieces) e where e ->> 'location_code' = p_code
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select is(jsonb_array_length(pg_temp.pieces_at('3 days 12 hours')), 0, 'before they were received there are no pieces');
select is(pg_temp.where_of(pg_temp.pieces_at('2 days 12 hours'), 'MAIN'), '3', 'after the receipt all three were at MAIN');
select is(pg_temp.where_of(pg_temp.pieces_at('1 day 12 hours'), 'MAIN') || '/' || pg_temp.where_of(pg_temp.pieces_at('1 day 12 hours'), 'FLOOR'), '2/1', 'after the move two were at MAIN and one at FLOOR');
select is(pg_temp.pieces_at('2 days 12 hours') -> 0 ->> 'state', 'in_stock', 'a piece at a shelf is in stock');
select isnt(pg_temp.pieces_at('2 days 12 hours') -> 0 -> 'tags' ->> 0, null, 'a piece is given with its tag');
select is(pg_temp.where_of(pg_temp.pieces_at(null), 'MAIN') || '/' || pg_temp.where_of(pg_temp.pieces_at(null), 'FLOOR'), '2/1', 'now: two at MAIN and one at FLOOR');
select is(pg_temp.pieces_at('0 seconds') - 'x', pg_temp.pieces_at(null), 'replayed at this moment the pieces are the pieces of now');
select ok((pg_temp.where_is(3, 303, null, (now() - interval '1 day')::text)::jsonb ->> 'pieces_known_from') is not null, 'the answer says since when the link is kept');
select is(pg_temp.f(pg_temp.where_is(3, 303, null, (now() - interval '1 day 12 hours')::text), 'on_hand'), '3.000000', 'the places part is unchanged');
select is(jsonb_array_length(pg_temp.where_is(3, 303, null, (now() - interval '1 day 12 hours')::text)::jsonb -> 'pieces'), 3, 'three pieces at that date');

select * from finish();
rollback;
