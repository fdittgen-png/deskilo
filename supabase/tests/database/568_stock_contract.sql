-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4403: ONE table of stock scenarios, run here against the RPCs and in test/parity/stock_contract_test.dart against
-- the domain's StockLedger (lib/features/stock/domain/stock_ledger.dart). The rows below are the table's rows to the
-- letter (test/parity/stock_scenarios.dart; the parity test finds each one here): the balances a row starts from,
-- its command and outcome, the balances after. The world: two sites, MAIN with SHELF under it and BRANCH with
-- BRANCH-S1 under it, and the server's own places; beans by the kg, mugs by the piece (a box is 6), syrup by the
-- litre (a third is 1/3); received at the opening: 10 kg of beans at MAIN (O1), 24 mugs on SHELF (O2), 2 l of syrup
-- at MAIN (O3). A row's outcome is `ok`, `short` (DKG03), `refused REASON FIELD` (DKG11) or `code DKGnn`. Rolled back.
begin;
select plan(89);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;

create or replace function pg_temp.run_as(p_user uuid, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;

-- a place of the business by its code (the in-transit place by its kind)
create or replace function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations
   where workspace_id = pg_temp.u(101) and case when p_code = 'TRANSIT' then kind = 'in_transit' else code = p_code end
   order by created_datetime limit 1
$f$;
create or replace function pg_temp.item(p_code text) returns uuid language sql immutable as $f$
  select pg_temp.u(case p_code when 'BEANS' then 301 when 'MUGS' then 302 when 'SYRUP' then 303 end)
$f$;
-- the request number of a row (S01 -> 1001) or of an opening (O1 -> 901)
create or replace function pg_temp.req(p_row text) returns int language sql immutable as $f$
  select (case left(p_row, 1) when 'O' then 900 else 1000 end) + substr(p_row, 2)::int
$f$;
-- the lines of a spec: `ITEM QTY FROM>TO [UNIT]` (or `ITEM QTY FROM`) joined by `;`
create or replace function pg_temp.lines(p_spec text) returns jsonb language sql stable as $f$
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'item_id', pg_temp.item(t[1]), 'quantity', t[2],
           'from', pg_temp.loc(split_part(t[3], '>', 1)),
           'to', pg_temp.loc(nullif(split_part(t[3], '>', 2), '')),
           'unit', t[4])) order by n), '[]'::jsonb)
    from (select n, regexp_split_to_array(trim(l), '\s+') as t
            from unnest(string_to_array(p_spec, ';')) with ordinality as x(l, n)) y
$f$;
-- an answer as the table words it
create or replace function pg_temp.outcome(r text) returns text language sql immutable as $f$
  select case
    when r is null or r not like 'ERR %' then 'ok'
    when r like 'ERR DKG11 %' then 'refused ' || (substr(r, 11)::jsonb ->> 'reason') || ' ' || (substr(r, 11)::jsonb ->> 'field')
    when r like 'ERR DKG03%' then 'short'
    else 'code ' || split_part(r, ' ', 2) end
$f$;
create or replace function pg_temp.call(p_sql text) returns text language sql as $f$
  select pg_temp.outcome(pg_temp.run_as(pg_temp.u(1), p_sql))
$f$;
-- `ITEM@PLACE=QTY ...` with what the business holds there now, lots and variants together
create or replace function pg_temp.bal(p_spec text) returns text language sql stable as $f$
  select string_agg(split_part(k, '=', 1) || '=' || (
           select trim_scale(coalesce(sum(b.quantity), 0))::text from public.stock_balances b
            where b.workspace_id = pg_temp.u(101) and b.item_id = pg_temp.item(split_part(split_part(k, '=', 1), '@', 1))
              and b.location_id = pg_temp.loc(split_part(split_part(k, '=', 1), '@', 2))), ' ' order by n)
    from unnest(string_to_array(p_spec, ' ')) with ordinality as x(k, n)
$f$;
-- one row's command, through the RPC a member calls
create or replace function pg_temp.run(p_row text, p_kind text, p_spec text, p_arg text) returns text language plpgsql as $f$
declare
  ws uuid := pg_temp.u(101);
  n int := pg_temp.req(p_row);
  t text[] := regexp_split_to_array(trim(p_spec), '\s+');
  v_transfer uuid := pg_temp.u(999001);
  v_line uuid := pg_temp.u(999002);
  v_out text;
begin
  if p_kind = 'transfer' then
    return pg_temp.call(format('select public.stock_transfer_v1(%L, %L, %L::jsonb)::text', ws, pg_temp.u(n), pg_temp.lines(p_spec)));
  elsif p_kind = 'load' then
    return pg_temp.call(format('select public.stock_transfer_load_v1(%L, %L, %L, %L::jsonb)::text',
      ws, pg_temp.u(n), pg_temp.loc(p_arg), pg_temp.lines(p_spec)));
  elsif p_kind = 'receive' then
    if p_arg <> 'none' then
      select x.transfer_id, x.id into v_transfer, v_line from public.stock_transfer_lines x
        join public.stock_transfers tr on tr.id = x.transfer_id
       where tr.workspace_id = ws and tr.request_id = pg_temp.u(pg_temp.req(p_arg)) order by x.id limit 1;
    end if;
    return pg_temp.call(format('select public.stock_transfer_receive_v1(%L, %L, %L, %L::jsonb)::text', ws, pg_temp.u(n), v_transfer,
      jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('line_id', v_line, 'quantity', t[1], 'to', pg_temp.loc(t[2]))))));
  elsif p_kind = 'take_out' then
    return pg_temp.call(format('select public.%s(%L, %L, %L::jsonb)::text',
      case p_arg when 'consumption' then 'stock_consume_v1' else 'stock_loss_v1' end, ws, pg_temp.u(n), pg_temp.lines(p_spec)));
  elsif p_kind = 'return' then
    return pg_temp.call(format('select public.stock_return_v1(%L, %L, %L, %L, %L::jsonb)::text', ws, pg_temp.u(n), pg_temp.u(n + 5000),
      split_part(p_arg, ':', 1), jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        'return_line_id', pg_temp.u(n + 6000),
        'source_movement_id', (select m.id from public.stock_movements m
                                where m.workspace_id = ws and m.request_id = pg_temp.u(pg_temp.req(split_part(p_arg, ':', 2)))
                                order by m.line_no, m.part limit 1),
        'quantity', t[1], 'location', pg_temp.loc(t[2]))))));
  elsif p_kind = 'count' then
    v_out := pg_temp.call(format('select public.stock_count_record_v1(%L, %L, %L, %L::jsonb, %L)::text', ws, pg_temp.u(n), pg_temp.u(n + 5000),
      jsonb_build_object('item_id', pg_temp.item(t[1]), 'location_id', pg_temp.loc(t[2])), t[3]));
    if v_out <> 'ok' then return v_out; end if;
    if p_arg <> '' then
      v_out := pg_temp.call(format('select public.stock_transfer_v1(%L, %L, %L::jsonb)::text', ws, pg_temp.u(n + 7000), pg_temp.lines(p_arg)));
      if v_out <> 'ok' then return 'the move between: ' || v_out; end if;
    end if;
    return pg_temp.call(format('select public.stock_count_decide_v1(%L, %L, %L, ''apply'')::text', ws, pg_temp.u(n + 8000), pg_temp.u(n + 5000)));
  end if;
  raise exception 'no such command: %', p_kind;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'contract-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Contract', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "invoicing": true, "stockManagement": true, "stockLots": true, "stockTakeOut": true, "stockReturns": true, "stockCounts": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Coffee beans', 900, true, null, 'kg', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Mugs', 600, true, null, 'piece', 'none', true),
  (pg_temp.u(303), pg_temp.u(101), 'Syrup', 400, true, null, 'l', 'none', true);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values
  (pg_temp.u(101), pg_temp.u(302), 'box', 6, 1),
  (pg_temp.u(101), pg_temp.u(303), 'third', 1, 3);
insert into public.stock_locations (workspace_id, kind, code, name, parent_id) values
  (pg_temp.u(101), 'shelf', 'SHELF', 'Shelf', pg_temp.loc('MAIN')),
  (pg_temp.u(101), 'warehouse', 'BRANCH', 'Branch', null);
insert into public.stock_locations (workspace_id, kind, code, name, parent_id) values
  (pg_temp.u(101), 'shelf', 'BRANCH-S1', 'Branch shelf', pg_temp.loc('BRANCH'));

-- the openings: received from the supplier (inside a block, so their answers print no line a TAP reader could count)
do $o$ begin
  perform pg_temp.call(format('select public.stock_move_v1(%L, %L, %L::jsonb, ''receipt'')::text', pg_temp.u(101), pg_temp.u(pg_temp.req(o)), pg_temp.lines(l)))
    from (values ('O1', 'BEANS 10 SUPPLIER>MAIN'), ('O2', 'MUGS 24 SUPPLIER>SHELF'), ('O3', 'SYRUP 2 SUPPLIER>MAIN')) v(o, l);
end $o$;
-- S01
select is(pg_temp.bal('MUGS@SHELF=24 MUGS@MAIN=0'), 'MUGS@SHELF=24 MUGS@MAIN=0', 'S01 given');
select is(pg_temp.run('S01', 'transfer', 'MUGS 4 SHELF>MAIN', ''), 'ok', 'S01 a transfer inside a site moves the goods');
select is(pg_temp.bal('MUGS@SHELF=20 MUGS@MAIN=4'), 'MUGS@SHELF=20 MUGS@MAIN=4', 'S01 then');

-- S02
select is(pg_temp.bal('MUGS@SHELF=20 MUGS@MAIN=4'), 'MUGS@SHELF=20 MUGS@MAIN=4', 'S02 given');
select is(pg_temp.run('S02', 'transfer', 'MUGS 1 SHELF>MAIN box', ''), 'ok', 'S02 a box is moved as its 6 pieces');
select is(pg_temp.bal('MUGS@SHELF=14 MUGS@MAIN=10'), 'MUGS@SHELF=14 MUGS@MAIN=10', 'S02 then');

-- S03
select is(pg_temp.bal('SYRUP@MAIN=2 SYRUP@SHELF=0'), 'SYRUP@MAIN=2 SYRUP@SHELF=0', 'S03 given');
select is(pg_temp.run('S03', 'transfer', 'SYRUP 1 MAIN>SHELF third', ''), 'ok', 'S03 a third of a litre is kept to six decimals');
select is(pg_temp.bal('SYRUP@MAIN=1.666667 SYRUP@SHELF=0.333333'), 'SYRUP@MAIN=1.666667 SYRUP@SHELF=0.333333', 'S03 then');

-- S04
select is(pg_temp.bal('MUGS@SHELF=14'), 'MUGS@SHELF=14', 'S04 given');
select is(pg_temp.run('S04', 'transfer', 'MUGS 100 SHELF>MAIN', ''), 'short', 'S04 more than is there is refused and moves nothing');
select is(pg_temp.bal('MUGS@SHELF=14 MUGS@MAIN=10'), 'MUGS@SHELF=14 MUGS@MAIN=10', 'S04 then');

-- S05
select is(pg_temp.bal('MUGS@SHELF=14 MUGS@MAIN=10'), 'MUGS@SHELF=14 MUGS@MAIN=10', 'S05 given');
select is(pg_temp.run('S05', 'transfer', 'MUGS 1 SHELF>MAIN; MUGS 100 SHELF>MAIN', ''), 'short', 'S05 one line short refuses the whole request');
select is(pg_temp.bal('MUGS@SHELF=14 MUGS@MAIN=10'), 'MUGS@SHELF=14 MUGS@MAIN=10', 'S05 then');

-- S06
select is(pg_temp.bal('MUGS@SHELF=14 MUGS@BRANCH-S1=0'), 'MUGS@SHELF=14 MUGS@BRANCH-S1=0', 'S06 given');
select is(pg_temp.run('S06', 'transfer', 'MUGS 1 SHELF>BRANCH-S1', ''), 'refused transfer_needs_transit lines[0]', 'S06 between two sites the goods go through transit');
select is(pg_temp.bal('MUGS@SHELF=14 MUGS@BRANCH-S1=0'), 'MUGS@SHELF=14 MUGS@BRANCH-S1=0', 'S06 then');

-- S07
select is(pg_temp.bal('MUGS@SHELF=14 MUGS@TRANSIT=0'), 'MUGS@SHELF=14 MUGS@TRANSIT=0', 'S07 given');
select is(pg_temp.run('S07', 'transfer', 'MUGS 1 SHELF>TRANSIT', ''), 'refused transit_is_system lines[0]', 'S07 the in-transit place is the two-step transfers alone');
select is(pg_temp.bal('MUGS@SHELF=14 MUGS@TRANSIT=0'), 'MUGS@SHELF=14 MUGS@TRANSIT=0', 'S07 then');

-- S08
select is(pg_temp.bal('MUGS@SHELF=14'), 'MUGS@SHELF=14', 'S08 given');
select is(pg_temp.run('S08', 'transfer', 'MUGS 1 SHELF>LOSS', ''), 'refused reason_places lines[0]', 'S08 a transfer goes between two real places');
select is(pg_temp.bal('MUGS@SHELF=14'), 'MUGS@SHELF=14', 'S08 then');

-- S09
select is(pg_temp.bal('MUGS@SHELF=14 MUGS@TRANSIT=0'), 'MUGS@SHELF=14 MUGS@TRANSIT=0', 'S09 given');
select is(pg_temp.run('S09', 'load', 'MUGS 4 SHELF', 'BRANCH'), 'ok', 'S09 goods loaded for another site wait in transit');
select is(pg_temp.bal('MUGS@SHELF=10 MUGS@TRANSIT=4'), 'MUGS@SHELF=10 MUGS@TRANSIT=4', 'S09 then');

-- S10
select is(pg_temp.bal('MUGS@SHELF=10'), 'MUGS@SHELF=10', 'S10 given');
select is(pg_temp.run('S10', 'load', 'MUGS 1 SHELF', 'MAIN'), 'refused same_site to_location_id', 'S10 inside one site a transfer is one step');
select is(pg_temp.bal('MUGS@SHELF=10 MUGS@TRANSIT=4'), 'MUGS@SHELF=10 MUGS@TRANSIT=4', 'S10 then');

-- S11
select is(pg_temp.bal('MUGS@SHELF=10 BEANS@MAIN=10'), 'MUGS@SHELF=10 BEANS@MAIN=10', 'S11 given');
select is(pg_temp.run('S11', 'load', 'MUGS 1 SHELF; BEANS 1 MAIN', 'BRANCH'), 'refused one_source lines', 'S11 a transfer has one source place');
select is(pg_temp.bal('MUGS@SHELF=10 BEANS@MAIN=10'), 'MUGS@SHELF=10 BEANS@MAIN=10', 'S11 then');

-- S12
select is(pg_temp.bal('MUGS@SHELF=10'), 'MUGS@SHELF=10', 'S12 given');
select is(pg_temp.run('S12', 'load', 'MUGS 1 SHELF', 'LOSS'), 'refused location_foreign to_location_id', 'S12 a transfer goes to a real place');
select is(pg_temp.bal('MUGS@SHELF=10'), 'MUGS@SHELF=10', 'S12 then');

-- S13
select is(pg_temp.bal('MUGS@SHELF=10'), 'MUGS@SHELF=10', 'S13 given');
select is(pg_temp.run('S13', 'load', 'MUGS 100 SHELF', 'BRANCH'), 'short', 'S13 more than is there is not loaded');
select is(pg_temp.bal('MUGS@SHELF=10 MUGS@TRANSIT=4'), 'MUGS@SHELF=10 MUGS@TRANSIT=4', 'S13 then');

-- S14
select is(pg_temp.bal('MUGS@TRANSIT=4 MUGS@BRANCH-S1=0'), 'MUGS@TRANSIT=4 MUGS@BRANCH-S1=0', 'S14 given');
select is(pg_temp.run('S14', 'receive', '1 BRANCH-S1', 'S09'), 'ok', 'S14 a part is received onto a place of the destination');
select is(pg_temp.bal('MUGS@TRANSIT=3 MUGS@BRANCH-S1=1'), 'MUGS@TRANSIT=3 MUGS@BRANCH-S1=1', 'S14 then');

-- S15
select is(pg_temp.bal('MUGS@TRANSIT=3'), 'MUGS@TRANSIT=3', 'S15 given');
select is(pg_temp.run('S15', 'receive', '5', 'S09'), 'refused receive_over lines[0].quantity', 'S15 never more than is still on its way');
select is(pg_temp.bal('MUGS@TRANSIT=3'), 'MUGS@TRANSIT=3', 'S15 then');

-- S16
select is(pg_temp.bal('MUGS@TRANSIT=3 MUGS@SHELF=10'), 'MUGS@TRANSIT=3 MUGS@SHELF=10', 'S16 given');
select is(pg_temp.run('S16', 'receive', '1 SHELF', 'S09'), 'refused wrong_site lines[0].to', 'S16 received at the destinations site only');
select is(pg_temp.bal('MUGS@TRANSIT=3 MUGS@SHELF=10'), 'MUGS@TRANSIT=3 MUGS@SHELF=10', 'S16 then');

-- S17
select is(pg_temp.bal('MUGS@TRANSIT=3'), 'MUGS@TRANSIT=3', 'S17 given');
select is(pg_temp.run('S17', 'receive', '0', 'S09'), 'refused quantity_invalid lines[0].quantity', 'S17 a quantity above zero is received');
select is(pg_temp.bal('MUGS@TRANSIT=3'), 'MUGS@TRANSIT=3', 'S17 then');

-- S18
select is(pg_temp.bal('MUGS@TRANSIT=3'), 'MUGS@TRANSIT=3', 'S18 given');
select is(pg_temp.run('S18', 'receive', '1', 'none'), 'refused transfer_unknown transfer', 'S18 a transfer of the business is received');
select is(pg_temp.bal('MUGS@TRANSIT=3'), 'MUGS@TRANSIT=3', 'S18 then');

-- S19
select is(pg_temp.bal('MUGS@TRANSIT=3 MUGS@BRANCH=0'), 'MUGS@TRANSIT=3 MUGS@BRANCH=0', 'S19 given');
select is(pg_temp.run('S19', 'receive', '3', 'S09'), 'ok', 'S19 the rest is received at the destination itself');
select is(pg_temp.bal('MUGS@TRANSIT=0 MUGS@BRANCH=3'), 'MUGS@TRANSIT=0 MUGS@BRANCH=3', 'S19 then');

-- S20
select is(pg_temp.bal('BEANS@MAIN=10'), 'BEANS@MAIN=10', 'S20 given');
select is(pg_temp.run('S20', 'take_out', 'BEANS 2 MAIN', 'consumption'), 'ok', 'S20 goods are taken out for use');
select is(pg_temp.bal('BEANS@MAIN=8'), 'BEANS@MAIN=8', 'S20 then');

-- S21
select is(pg_temp.bal('BEANS@MAIN=8'), 'BEANS@MAIN=8', 'S21 given');
select is(pg_temp.run('S21', 'take_out', 'BEANS 100 MAIN', 'loss'), 'short', 'S21 more than is there is not written off');
select is(pg_temp.bal('BEANS@MAIN=8'), 'BEANS@MAIN=8', 'S21 then');

-- S22
select is(pg_temp.bal('MUGS@TRANSIT=0'), 'MUGS@TRANSIT=0', 'S22 given');
select is(pg_temp.run('S22', 'take_out', 'MUGS 1 TRANSIT', 'loss'), 'refused transit_is_system lines[0]', 'S22 goods on the road are not written off');
select is(pg_temp.bal('MUGS@TRANSIT=0'), 'MUGS@TRANSIT=0', 'S22 then');

-- S23
select is(pg_temp.run('S23', 'take_out', 'MUGS 1 SUPPLIER', 'loss'), 'refused reason_places lines[0]', 'S23 a take-out leaves a real place');
select is(pg_temp.bal('MUGS@SHELF=10'), 'MUGS@SHELF=10', 'S23 then');

-- S24
select is(pg_temp.bal('BEANS@MAIN=8'), 'BEANS@MAIN=8', 'S24 given');
select is(pg_temp.run('S24', 'return', '1', 'correction:S20'), 'ok', 'S24 a correction takes back part of a take-out');
select is(pg_temp.bal('BEANS@MAIN=9'), 'BEANS@MAIN=9', 'S24 then');

-- S25
select is(pg_temp.bal('BEANS@MAIN=9'), 'BEANS@MAIN=9', 'S25 given');
select is(pg_temp.run('S25', 'return', '5', 'correction:S20'), 'code DKG17', 'S25 never more than the movement still allows');
select is(pg_temp.bal('BEANS@MAIN=9'), 'BEANS@MAIN=9', 'S25 then');

-- S26
select is(pg_temp.bal('MUGS@MAIN=10'), 'MUGS@MAIN=10', 'S26 given');
select is(pg_temp.run('S26', 'return', '1 MAIN', 'customer:S01'), 'code DKG18', 'S26 a customer return follows a sale');
select is(pg_temp.bal('MUGS@MAIN=10'), 'MUGS@MAIN=10', 'S26 then');

-- S27
select is(pg_temp.bal('BEANS@MAIN=9'), 'BEANS@MAIN=9', 'S27 given');
select is(pg_temp.run('S27', 'return', '1 MAIN', 'supplier:O1'), 'ok', 'S27 goods go back to the supplier of a receipt');
select is(pg_temp.bal('BEANS@MAIN=8'), 'BEANS@MAIN=8', 'S27 then');

-- S28
select is(pg_temp.bal('MUGS@TRANSIT=0'), 'MUGS@TRANSIT=0', 'S28 given');
select is(pg_temp.run('S28', 'return', '1', 'correction:S09'), 'code DKG18', 'S28 a leg of a transfer between sites is not corrected');
select is(pg_temp.bal('MUGS@TRANSIT=0 MUGS@SHELF=10'), 'MUGS@TRANSIT=0 MUGS@SHELF=10', 'S28 then');

-- S29
select is(pg_temp.bal('BEANS@MAIN=8'), 'BEANS@MAIN=8', 'S29 given');
select is(pg_temp.run('S29', 'count', 'BEANS MAIN 7', ''), 'ok', 'S29 an applied count moves exactly its difference');
select is(pg_temp.bal('BEANS@MAIN=7'), 'BEANS@MAIN=7', 'S29 then');

-- S30
select is(pg_temp.bal('MUGS@SHELF=10 MUGS@MAIN=10'), 'MUGS@SHELF=10 MUGS@MAIN=10', 'S30 given');
select is(pg_temp.run('S30', 'count', 'MUGS SHELF 9', 'MUGS 1 SHELF>MAIN'), 'code DKG20', 'S30 a count the stock moved since is counted again');
select is(pg_temp.bal('MUGS@SHELF=9 MUGS@MAIN=11'), 'MUGS@SHELF=9 MUGS@MAIN=11', 'S30 then');

select * from finish();
rollback;
