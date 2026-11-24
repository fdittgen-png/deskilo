-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4431 (0921): the expiry report. One row per lot on hand (and per piece of a piece-tracked item), expired before the reference date or
-- expiring from it up to a horizon, sorted by date then place; a lot with nothing on hand is not listed; scoped to the business, to
-- whoever sees the stock, never to an assistant; bounded and paged. Rolled back.
begin;
select plan(21);

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
create or replace function pg_temp.today() returns date language sql stable as $f$
  select public.workspace_today(pg_temp.u(101))
$f$;
create or replace function pg_temp.day(p_offset int) returns text language sql stable as $f$
  select to_char(pg_temp.today() + p_offset, 'YYYY-MM-DD')
$f$;
create or replace function pg_temp.mv(p_user int, p_req int, p_lines text, p_reason text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_reason))
$f$;
-- the report as a member reads it: scope, horizon, place, group, limit, cursor
create or replace function pg_temp.report(p_user int, p_args text, p_ws int default 101, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.stock_expiry_report_v1(%L%s)::text', pg_temp.u(p_ws), case when p_args = '' then '' else ', ' || p_args end), p_delegated)
$f$;
-- the rows as 'name@days#tag', in the order they come, pieces of one lot in any order among themselves (their ids are random)
create or replace function pg_temp.names(p text) returns text language sql immutable as $f$
  select coalesce(string_agg(r ->> 'item_name' || '@' || (r ->> 'days') || case when r ->> 'tag' is null then '' else '#' || right(r ->> 'tag', 2) end, ','
           order by (r ->> 'expires_on'), r ->> 'location_code', r ->> 'item_name', r ->> 'tag'), '')
    from jsonb_array_elements(p::jsonb -> 'rows') as t(r)
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'expiry-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Expiry A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "stockManagement": true, "stockLots": true, "stockTags": true, "stockItemGroups": true, "stockExpiryReport": true}',
   '{"admin": ["manageStock"]}'),
  (pg_temp.u(102), 'Expiry B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4),
   '{"services": true, "stockManagement": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active'),
  (pg_temp.u(204), pg_temp.u(102), pg_temp.u(4), true, true, 'active');
insert into public.item_groups (id, workspace_id, name) values (pg_temp.u(801), pg_temp.u(101), 'Dairy');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode, group_id) values
  (pg_temp.u(303), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit', null),
  (pg_temp.u(304), pg_temp.u(101), 'Yogurt', 100, true, 'piece', 'lot', true, null, pg_temp.u(801)),
  (pg_temp.u(305), pg_temp.u(101), 'Cheese', 900, true, 'piece', 'lot', true, null, null);
insert into public.stock_locations (id, workspace_id, parent_id, kind, code) values
  (pg_temp.u(901), pg_temp.u(101), pg_temp.loc('MAIN'), 'zone', 'FLOOR');

-- Yogurt: five that expired 10 days ago and three that expire in 5 days, at MAIN
select pg_temp.mv(3, 910, format('[{"item_id": "%s", "quantity": "5", "from": "%s", "to": "%s", "new_lot": {"total_cost_minor": 500, "code": "Y-OLD", "expires_on": "%s"}}]',
  pg_temp.u(304), pg_temp.place('supplier'), pg_temp.loc('MAIN'), pg_temp.day(-10)), 'receipt');
select pg_temp.mv(3, 911, format('[{"item_id": "%s", "quantity": "3", "from": "%s", "to": "%s", "new_lot": {"total_cost_minor": 300, "code": "Y-NEW", "expires_on": "%s"}}]',
  pg_temp.u(304), pg_temp.place('supplier'), pg_temp.loc('MAIN'), pg_temp.day(5)), 'receipt');
-- Cheese: two that expire in 60 days, on the FLOOR; and a lot that expired 3 days ago and holds nothing now
select pg_temp.mv(3, 912, format('[{"item_id": "%s", "quantity": "2", "from": "%s", "to": "%s", "new_lot": {"total_cost_minor": 1800, "code": "C-FAR", "expires_on": "%s"}}]',
  pg_temp.u(305), pg_temp.place('supplier'), pg_temp.loc('FLOOR'), pg_temp.day(60)), 'receipt');
insert into public.stock_lots (id, workspace_id, item_id, lot_code, expires_on, total_cost_minor, quantity_received)
  values (pg_temp.u(711), pg_temp.u(101), pg_temp.u(305), 'C-GONE', pg_temp.today() - 3, 1800, 2);
insert into public.stock_balances (workspace_id, item_id, lot_id, location_id, quantity)
  values (pg_temp.u(101), pg_temp.u(305), pg_temp.u(711), pg_temp.loc('MAIN'), 0);
-- Baskets: three pieces of one lot that expires in 8 days, each with its tag
select pg_temp.mv(3, 915, format('[{"item_id": "%s", "quantity": "3", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D68F01"}, {"tag": "E28068940000401561D68F02"}, {"tag": "E28068940000401561D68F03"}], "new_lot": {"total_cost_minor": 3000, "code": "B-LOT", "expires_on": "%s"}}]',
  pg_temp.u(303), pg_temp.place('supplier'), pg_temp.loc('MAIN'), pg_temp.day(8)), 'receipt');

select set_config('t.both', pg_temp.report(3, ''), false);
select is(pg_temp.names(current_setting('t.both')), 'Yogurt@-10,Yogurt@5,Baskets@8#01,Baskets@8#02,Baskets@8#03',
  'both: what expired, then what expires within the setting''s 30 days, by date; pieces are listed one by one with their tag; the cheese at 60 days is beyond the horizon; the cheese thrown away is not listed');
select is((current_setting('t.both')::jsonb ->> 'as_of')::date, pg_temp.today(), 'the reference date is today on the business''s calendar');
select is(pg_temp.names(pg_temp.report(3, 'null, ''expired''')), 'Yogurt@-10', 'expired: only what expired before the reference date');
select is(pg_temp.names(pg_temp.report(3, 'null, ''expiring'', 90')), 'Yogurt@5,Baskets@8#01,Baskets@8#02,Baskets@8#03,Cheese@60', 'expiring with a horizon of 90 days adds the cheese');
select is(pg_temp.names(pg_temp.report(3, 'null, ''expiring'', 3')), '', 'a horizon of 3 days reaches nothing');
select is(pg_temp.names(pg_temp.report(3, format('null, ''expiring'', 90, %L', pg_temp.loc('FLOOR')))), 'Cheese@60', 'a place keeps only what it holds');
select is(pg_temp.names(pg_temp.report(3, format('null, ''both'', null, null, %L', pg_temp.u(801)))), 'Yogurt@-10,Yogurt@5', 'a group keeps only the items of it');
select is(pg_temp.names(pg_temp.report(3, format('%L, ''expired''', pg_temp.day(20)))), 'Yogurt@-30,Yogurt@-15,Baskets@-12#01,Baskets@-12#02,Baskets@-12#03', 'at a later date, what expires before it is expired, with the days past');
select is(((current_setting('t.both')::jsonb -> 'rows' -> 0) ->> 'quantity') || ' ' || ((current_setting('t.both')::jsonb -> 'rows' -> 0) ->> 'unit') || ' ' || ((current_setting('t.both')::jsonb -> 'rows' -> 0) ->> 'lot_code'), '5.000000 piece Y-OLD', 'a row says the lot, its quantity and its unit');
select is(((current_setting('t.both')::jsonb -> 'rows' -> 2) ->> 'quantity'), '1', 'a piece counts as one');

-- paged: two rows at a time, in the same order, complete at the end
select set_config('t.p1', pg_temp.report(3, 'null, ''both'', null, null, null, 2'), false);
select is((current_setting('t.p1')::jsonb ->> 'complete') || ' ' || jsonb_array_length(current_setting('t.p1')::jsonb -> 'rows'), 'false 2', 'a page of two says it is not complete');
select set_config('t.p2', pg_temp.report(3, format('null, ''both'', null, null, null, 2, %L::jsonb', current_setting('t.p1')::jsonb -> 'next')), false);
select set_config('t.p3', pg_temp.report(3, format('null, ''both'', null, null, null, 2, %L::jsonb', current_setting('t.p2')::jsonb -> 'next')), false);
select is(jsonb_array_length(current_setting('t.p1')::jsonb -> 'rows') || '/' || jsonb_array_length(current_setting('t.p2')::jsonb -> 'rows') || '/' || jsonb_array_length(current_setting('t.p3')::jsonb -> 'rows'), '2/2/1', 'the pages hold two, two and one');
select is((select string_agg(r ->> 'piece_id', ',' order by r ->> 'piece_id') from (select jsonb_array_elements(current_setting(k)::jsonb -> 'rows') r from unnest(array['t.p1', 't.p2', 't.p3']) k) q where r ->> 'piece_id' is not null),
  (select string_agg(r ->> 'piece_id', ',' order by r ->> 'piece_id') from jsonb_array_elements(current_setting('t.both')::jsonb -> 'rows') r where r ->> 'piece_id' is not null), 'the pages follow one another with no piece repeated or lost');
select is(current_setting('t.p3')::jsonb ->> 'complete', 'true', 'and the last one is complete');

-- who may read
select is(left(pg_temp.report(2, ''), 9), 'ERR DKN01', 'a member who may not see the stock is refused');
select is(left(pg_temp.report(4, ''), 9), 'ERR DKN01', 'a member of another business reads nothing of this one');
select is(left(pg_temp.report(3, '', 101, true), 9), 'ERR DKN01', 'an assistant session is refused');
select is(left(pg_temp.report(3, 'null, ''never'''), 9), 'ERR DKG09', 'a scope that is none of the three is refused');
select is(left(pg_temp.report(3, 'null, ''both'', null, null, null, 0'), 9), 'ERR DKG09', 'a page of none is refused, and one over 200 as well');
select is(pg_temp.report(4, '', 102)::jsonb, '{"as_of": null, "next": null, "rows": [], "complete": true}'::jsonb, 'with the feature off the answer is empty, not an error');
select is((select count(*)::int from information_schema.routine_privileges where routine_name = 'stock_expiry_report_v1' and grantee in ('anon', 'public', 'PUBLIC')), 0, 'neither anon nor the public may call it');

select * from finish();
rollback;
