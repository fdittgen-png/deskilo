-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4161 (0833, A1): the stock reads a screen can page. Quantities are exact
-- text; a page is bounded and says what follows; equal sort keys neither
-- repeat nor skip; a row added ahead of a walk appears once; another
-- business, an unauthenticated caller, a delegated session, a caller
-- without the right and a business with the feature off read nothing; a bad
-- page size or cursor is refused, never clamped. Rolled back.
begin;
select plan(30);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;

create or replace function pg_temp.run_as(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    case when p_user is null then '' else
    (jsonb_build_object('sub', p_user, 'role', 'authenticated')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text end, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;

create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;

create or replace function pg_temp.line(p_item int, p_qty numeric, p_from text, p_to text,
                                        p_unit text default null, p_extra jsonb default '{}'::jsonb)
returns jsonb language sql stable as $f$
  select jsonb_build_object('item_id', pg_temp.u(p_item), 'quantity', p_qty,
           'from', pg_temp.loc(p_from), 'to', pg_temp.loc(p_to))
         || case when p_unit is null then '{}'::jsonb else jsonb_build_object('unit', p_unit) end
         || p_extra
$f$;

create or replace function pg_temp.move(p_request int, p_lines jsonb, p_at timestamptz default null)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format(
    'select public.stock_move_v1(%L, %L, %L::jsonb, ''receipt'', %L)::text',
    pg_temp.u(101), pg_temp.u(p_request), p_lines, p_at))
$f$;

create or replace function pg_temp.page(p_fn text, p_user int, p_args text, p_delegated boolean default false)
returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.%s(%L%s)::text', p_fn, pg_temp.u(101), p_args), p_delegated)
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- A (101): owner 1, member 2 who may see the stock, user 5 who is no member; B (102):
-- owner 3, on; C (103): owner 4, the feature off.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'pages-' || n || '@deskilo.test', '', now(), now(), now()
  from generate_series(1, 5) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Pages A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"stockManagement": false}', '{"member": []}'),
  (pg_temp.u(102), 'Pages B', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(3), '{"stockManagement": true}', '{}'),
  (pg_temp.u(103), 'Pages C', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), '{}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(203), pg_temp.u(102), pg_temp.u(3), true, true, 'active'),
  (pg_temp.u(204), pg_temp.u(103), pg_temp.u(4), true, true, 'active');
update public.workspaces set role_permissions = '{"member": ["viewStock"]}' where id = pg_temp.u(101);
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Beans', 100, true, null, 'piece', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Rice', 100, true, 0, 'kg', 'none', true),
  (pg_temp.u(303), pg_temp.u(101), 'Wine', 500, true, null, 'l', 'none', true),
  (pg_temp.u(304), pg_temp.u(101), 'Juice', 300, true, null, 'piece', 'lot', true),
  (pg_temp.u(305), pg_temp.u(102), 'Tea', 200, true, null, 'piece', 'none', true);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den)
values (pg_temp.u(101), pg_temp.u(303), 'third', 1, 3);

update public.workspaces set feature_flags = '{"stockManagement": true}' where id = pg_temp.u(101);
insert into public.stock_locations (workspace_id, kind, code, parent_id)
values (pg_temp.u(101), 'shelf', 'SHELF-A', pg_temp.loc('MAIN'));

-- Stock: beans and rice, wine in three thirds, juice in two lots, all at MAIN.
select pg_temp.move(501, jsonb_build_array(pg_temp.line(301, 7, 'SUPPLIER', 'MAIN')), '2026-03-01 10:00+01');
select pg_temp.move(502, jsonb_build_array(pg_temp.line(302, 0.5, 'SUPPLIER', 'MAIN')), '2026-03-02 10:00+01');
select pg_temp.move(503, jsonb_build_array(pg_temp.line(303, 1, 'SUPPLIER', 'MAIN', 'third')), '2026-03-03 10:00+01');
select pg_temp.move(504, jsonb_build_array(pg_temp.line(303, 1, 'SUPPLIER', 'MAIN', 'third')), '2026-03-03 10:00+01');
select pg_temp.move(505, jsonb_build_array(pg_temp.line(303, 1, 'SUPPLIER', 'MAIN', 'third')), '2026-03-03 10:00+01');
select pg_temp.move(506, jsonb_build_array(
         pg_temp.line(304, 4, 'SUPPLIER', 'MAIN', null, '{"new_lot": {"code": "A", "total_cost_minor": 400}}'),
         pg_temp.line(304, 6, 'SUPPLIER', 'MAIN', null, '{"new_lot": {"code": "B", "total_cost_minor": 900}}')), '2026-03-04 10:00+01');
select pg_temp.move(507, jsonb_build_array(pg_temp.line(301, 2, 'MAIN', 'SHELF-A')), '2026-03-05 10:00+01');

-- Exact quantities, as text.
select is(pg_temp.page('stock_on_hand_page_v1', 1, format(', %L', pg_temp.u(303))) :: jsonb #>> '{rows,0,quantity}',
  '0.999999', 'three thirds of a litre persisted at 0.333333 sum to 0.999999 on hand, as text');
select is((select count(*) from public.stock_movements where item_id = pg_temp.u(303) and quantity = 0.333333)::int, 3,
  'and each stored movement is 0.333333, converted once');
select is(pg_temp.page('stock_on_hand_page_v1', 1, format(', %L', pg_temp.u(302))) :: jsonb #>> '{rows,0,quantity}'
          || ' ' || (select coalesce(stock, -1) from public.services where id = pg_temp.u(302))::text,
  '0.500000 0', '0.5 kg reads as 0.5 even when the legacy shelf count says 0');
select is((select string_agg(r ->> 'location_code', ' ' order by r ->> 'location_code')
             from jsonb_array_elements(pg_temp.page('stock_on_hand_page_v1', 1, format(', %L', pg_temp.u(301))) :: jsonb -> 'rows') r),
  'MAIN SHELF-A', 'stock on two places is shown at each, not as one number at MAIN');

-- Pages are bounded and say what follows.
select is(jsonb_array_length(pg_temp.page('stock_on_hand_page_v1', 1, ', null, null, 3') :: jsonb -> 'rows') = 3
          and (pg_temp.page('stock_on_hand_page_v1', 1, ', null, null, 3') :: jsonb ->> 'complete') = 'false'
          and (pg_temp.page('stock_on_hand_page_v1', 1, ', null, null, 3') :: jsonb -> 'next' ->> 'version') = '1', true,
  'a page of 3 holds 3 rows, is not complete and carries its cursor');

-- A full walk, two rows at a time: every balance once.
create temp table walk (n int, row jsonb);
do $w$
declare v_page jsonb; v_after jsonb := null; v_n int := 0; v_guard int := 0;
begin
  loop
    v_page := pg_temp.page('stock_on_hand_page_v1', 1,
      format(', null, null, 2, %L::jsonb', v_after))::jsonb;
    insert into walk select v_n + ordinality::int, r from jsonb_array_elements(v_page -> 'rows') with ordinality as t(r, ordinality);
    v_n := v_n + jsonb_array_length(v_page -> 'rows');
    exit when (v_page ->> 'complete') = 'true';
    v_after := v_page -> 'next';
    v_guard := v_guard + 1; exit when v_guard > 20;
  end loop;
end $w$;
select is((select count(*) from walk)::int,
          (select count(*)::int from public.stock_balances b join public.stock_locations l on l.id = b.location_id
            join public.stock_location_kinds k on k.key = l.kind
            where b.workspace_id = pg_temp.u(101) and not k.virtual and b.quantity <> 0),
  'walking two at a time returns every balance');
select is((select count(distinct (row ->> 'item_id') || (row ->> 'location_id') || coalesce(row ->> 'lot_id', ''))::int from walk),
          (select count(*)::int from walk), 'and none twice');

-- Equal sort keys: the two lots of one item at one place, one row per page.
select is((select string_agg(coalesce(r ->> 'lot_code', '-'), ',' order by r ->> 'lot_code')
             from (select jsonb_array_elements(
                     (pg_temp.page('stock_on_hand_page_v1', 1, format(', %L, null, 1', pg_temp.u(304))) :: jsonb) -> 'rows') as r
                   union all
                   select jsonb_array_elements(
                     (pg_temp.page('stock_on_hand_page_v1', 1, format(', %L, null, 1, %L::jsonb', pg_temp.u(304),
                       (pg_temp.page('stock_on_hand_page_v1', 1, format(', %L, null, 1', pg_temp.u(304))) :: jsonb) -> 'next')) :: jsonb) -> 'rows')) x),
  'A,B', 'two lots of one item at one place come one per page, neither repeated nor skipped');

-- A row added ahead of the cursor appears once; the rows already read are not repeated.
select set_config('t.p1', pg_temp.page('stock_on_hand_page_v1', 1, ', null, null, 2'), false);
select pg_temp.move(508, jsonb_build_array(pg_temp.line(301, 1, 'SUPPLIER', 'SHELF-A')), '2026-03-06 10:00+01');
select is((select count(*) from (
            select (r ->> 'item_id') || (r ->> 'location_id') || coalesce(r ->> 'lot_id', '') k
              from jsonb_array_elements(current_setting('t.p1')::jsonb -> 'rows') r
            union all
            select (r ->> 'item_id') || (r ->> 'location_id') || coalesce(r ->> 'lot_id', '')
              from jsonb_array_elements(pg_temp.page('stock_on_hand_page_v1', 1,
                format(', null, null, 50, %L::jsonb', current_setting('t.p1')::jsonb -> 'next'))::jsonb -> 'rows') r) z)::int,
  (select count(*)::int from public.stock_balances b join public.stock_locations l on l.id = b.location_id
     join public.stock_location_kinds k on k.key = l.kind
    where b.workspace_id = pg_temp.u(101) and not k.virtual and b.quantity <> 0),
  'a balance changed between two page reads leaves the walk with every row once');

-- The movements, newest first; equal timestamps do not repeat.
select is((pg_temp.page('stock_movements_page_v1', 1, ', null, null, 2') :: jsonb #>> '{rows,0,reason}') || ' ' ||
          (pg_temp.page('stock_movements_page_v1', 1, ', null, null, 2') :: jsonb ->> 'complete'),
  'receipt false', 'the movements page is newest first and says it continues');
create temp table mwalk (id text);
do $w$
declare v_page jsonb; v_after jsonb := null; v_guard int := 0;
begin
  loop
    v_page := pg_temp.page('stock_movements_page_v1', 1, format(', null, null, 1, %L::jsonb', v_after))::jsonb;
    insert into mwalk select r ->> 'id' from jsonb_array_elements(v_page -> 'rows') r;
    exit when (v_page ->> 'complete') = 'true';
    v_after := v_page -> 'next';
    v_guard := v_guard + 1; exit when v_guard > 30;
  end loop;
end $w$;
select is((select count(*)::int from mwalk) || ' ' || (select count(distinct id)::int from mwalk),
          (select count(*)::int from public.stock_movements where workspace_id = pg_temp.u(101))::text || ' '
          || (select count(*)::int from public.stock_movements where workspace_id = pg_temp.u(101))::text,
  'one movement per page, three with the same instant among them: every movement once');
select is(pg_temp.page('stock_movements_page_v1', 1, format(', %L, null, 1', pg_temp.u(301))) :: jsonb #>> '{rows,0,unit_cost}',
  null, 'an unknown valuation (a movement without a lot) is null, not zero');

-- Bounds and cursors are refused, never clamped.
select is(pg_temp.page('stock_on_hand_page_v1', 1, ', null, null, 0') || ' ' || pg_temp.page('stock_on_hand_page_v1', 1, ', null, null, 201')
          || ' ' || pg_temp.page('stock_movements_page_v1', 1, ', null, null, null'),
  'ERR DKG09 ERR DKG09 ERR DKG09', 'a page size of 0, of 201 or none is refused with DKG09');
select is(pg_temp.page('stock_on_hand_page_v1', 1, $$, null, null, 5, '{"version": 2}'::jsonb$$)
          || ' ' || pg_temp.page('stock_movements_page_v1', 1, $$, null, null, 5, '{"version": 1, "id": "x"}'::jsonb$$),
  'ERR DKG09 ERR DKG09', 'another cursor version or a malformed cursor is refused with DKG09');

-- Who reads.
select is(pg_temp.page('stock_on_hand_page_v1', 2, ', null, null, 1') :: jsonb ->> 'complete',
  'false', 'a member who may see the stock reads it');
select is(pg_temp.page('stock_on_hand_page_v1', 5, '') || ' ' || pg_temp.page('stock_movements_page_v1', 3, '')
          || ' ' || pg_temp.run_as(null, format('select public.stock_on_hand_page_v1(%L)::text', pg_temp.u(101))),
  'ERR DKN01 ERR DKN01 ERR DKN01',
  'a user who is no member, another business and an unauthenticated caller are refused with DKN01');
select is(pg_temp.page('stock_on_hand_page_v1', 1, '', true) || ' ' || pg_temp.page('stock_movements_page_v1', 1, '', true),
  'ERR DKN01 ERR DKN01', 'a delegated assistant session reads nothing');
select is((pg_temp.run_as(pg_temp.u(3), format('select public.stock_on_hand_page_v1(%L, %L)::text', pg_temp.u(102), pg_temp.u(301)))::jsonb -> 'rows')::text,
  '[]', 'another business asking for this business''s item id sees no row');
select is(pg_temp.run_as(pg_temp.u(4), format('select public.stock_on_hand_page_v1(%L)::text', pg_temp.u(103))),
  'ERR DKG01', 'with stockManagement off the read refuses with DKG01');

-- Purchase cost is finance data: a reader who only sees the stock gets null (not zero),
-- a reader with finance rights gets it; the released trace is held to the same rule.
create or replace function pg_temp.last304() returns uuid language sql stable as $f$
  select id from public.stock_movements where item_id = pg_temp.u(304) order by occurred_at desc, id desc limit 1
$f$;
select is((pg_temp.page('stock_movements_page_v1', 2, format(', %L, null, 1', pg_temp.u(304))) :: jsonb -> 'rows' -> 0)
          - 'item_name' - 'lot_code' - 'from_location_code' - 'to_location_code' - 'id' - 'item_id' - 'lot_id'
          - 'from_location_id' - 'to_location_id' - 'quantity' - 'unit' - 'entered_quantity' - 'entered_unit'
          - 'occurred_at' - 'reason' - 'actor_member_id' - 'event_id' - 'invoice_id' - 'workspace_id',
  '{"unit_cost": null, "receipt_line_id": null, "purchase_line_id": null}'::jsonb,
  'a member who only sees the stock reads no cost, receipt or purchase cause: null, not zero');
select ok((pg_temp.page('stock_movements_page_v1', 1, format(', %L, null, 1', pg_temp.u(304))) :: jsonb -> 'rows' -> 0 ->> 'unit_cost') is not null,
  'the owner, who holds viewFinances, reads the cost of a lot movement');
select is(pg_temp.run_as(pg_temp.u(2), format($q$select ((public.stock_movement_trace_v1(%L, %L) -> 'movement') ? 'unit_cost')::text
            || ' ' || ((public.stock_movement_trace_v1(%L, %L) -> 'lot') ? 'total_cost_minor')::text$q$,
            pg_temp.u(101), pg_temp.last304(), pg_temp.u(101), pg_temp.last304())),
  'false false', 'the trace leaves the cost of the movement and of the lot out for a reader of the stock');
select is(pg_temp.run_as(pg_temp.u(1), format($q$select ((public.stock_movement_trace_v1(%L, %L) -> 'movement') ? 'unit_cost')::text
            || ' ' || ((public.stock_movement_trace_v1(%L, %L) -> 'lot') ? 'total_cost_minor')::text$q$,
            pg_temp.u(101), pg_temp.last304(), pg_temp.u(101), pg_temp.last304())),
  'true true', 'and keeps them for a caller with finance rights, as before');

-- A movement at its own address: the same row as the page, or none for an id of nothing or of another business.
select is((pg_temp.page('stock_movements_page_v1', 1, format(', null, null, 5, null, %L', pg_temp.last304())) :: jsonb -> 'rows' -> 0 ->> 'id')::uuid,
  pg_temp.last304(), 'a movement is read by its id, with its names');
select is(jsonb_array_length(pg_temp.page('stock_movements_page_v1', 1, ', null, null, 5, null, ' || quote_literal('00000000-0000-4000-8000-0000000fffff')) :: jsonb -> 'rows')::text
          || ' ' || jsonb_array_length(pg_temp.run_as(pg_temp.u(3), format('select public.stock_movements_page_v1(%L, null, null, 5, null, %L)::text', pg_temp.u(102), pg_temp.last304())) :: jsonb -> 'rows')::text,
  '0 0', 'an id of nothing, and a movement of another business, read as none');

-- The tables do not give the cost away either: the cost columns are not selectable by the signed-in role.
select is(pg_temp.run_as(pg_temp.u(2), 'select unit_cost::text from public.stock_movements limit 1')
          || ' ' || pg_temp.run_as(pg_temp.u(2), 'select receipt_line_id::text from public.stock_movements limit 1')
          || ' ' || pg_temp.run_as(pg_temp.u(2), 'select total_cost_minor::text from public.stock_lots limit 1')
          || ' ' || pg_temp.run_as(pg_temp.u(1), 'select unit_cost::text from public.stock_movements limit 1'),
  'ERR 42501 ERR 42501 ERR 42501 ERR 42501',
  'a stock-only member, and the owner too, cannot select a cost column straight from the tables');
select is(pg_temp.run_as(pg_temp.u(2), format('select count(quantity)::text from public.stock_movements where workspace_id = %L', pg_temp.u(101)))
          = (select count(*)::text from public.stock_movements where workspace_id = pg_temp.u(101))
          and (pg_temp.page('stock_movements_page_v1', 1, format(', %L, null, 1', pg_temp.u(304))) :: jsonb -> 'rows' -> 0 ->> 'unit_cost') is not null, true,
  'the other columns stay readable under RLS, and the owner still reads the cost through the RPC');

-- The value on hand is the cost of the goods: refused to a reader of the stock, answered to the owner.
select ok(pg_temp.run_as(pg_temp.u(2), format('select public.stock_value_at_v1(%L, now())::text', pg_temp.u(101))) = 'ERR DKN01'
          and (pg_temp.run_as(pg_temp.u(1), format('select public.stock_value_at_v1(%L, now())::text', pg_temp.u(101))) :: jsonb ->> 'total_minor') is not null,
  'the value of the stock is refused to a reader of the stock (DKN01) and answered to the owner');

-- A delegated assistant session and an unauthenticated caller read neither the trace nor the value, as the paged reads.
select is(pg_temp.run_as(pg_temp.u(1), format('select public.stock_movement_trace_v1(%L, %L)::text', pg_temp.u(101), pg_temp.last304()), true)
          || ' ' || pg_temp.run_as(null, format('select public.stock_movement_trace_v1(%L, %L)::text', pg_temp.u(101), pg_temp.last304())),
  'ERR DKN01 ERR DKN01', 'a delegated assistant session and an unauthenticated caller read no trace');
select is(pg_temp.run_as(pg_temp.u(1), format('select public.stock_value_at_v1(%L, now())::text', pg_temp.u(101)), true)
          || ' ' || pg_temp.run_as(null, format('select public.stock_value_at_v1(%L, now())::text', pg_temp.u(101))),
  'ERR DKN01 ERR DKN01', 'a delegated assistant session and an unauthenticated caller read no value, even holding finance rights');

select * from finish();
rollback;
