-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4492 (row 1): stock equals its movements, asked of the database after every command instead of once per feature.
-- A business with two sites receives, transfers (in the inventory unit, by the box, by a third of a litre), loads and
-- receives between sites, takes out, returns, counts and packs a handling unit; after EACH command, accepted or
-- refused, five things are read back by query: every balance (item, variant, lot, place) is the sum of its movements,
-- one row per key; an item sums to zero over all places; no real place is below zero; no open unit holds more than its
-- place. Then: a command and its full correction leave every balance as it was (a converted quantity, a take-out over
-- two lots, a receipt, a count, in slices, and a correction corrected); a line is its entered quantity at its frozen
-- factor; the item's shelf count follows; the two statements of the stock's value agree with the balances; the rule for
-- less than nothing is one rule at every door, with the setting off and on. One part is a measurement, not a wish: a
-- conversion with no finite decimal (a third) is rounded at each movement, so three thirds moved one by one are
-- 0.999999 and a whole litre cannot be taken back (U03 to U05; the decision is #4492's). Rolled back.
begin;
select plan(44);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.z(p uuid) returns uuid language sql immutable as $f$
  select coalesce(p, '00000000-0000-0000-0000-000000000000'::uuid)
$f$;
create or replace function pg_temp.today() returns date language sql stable security definer as $f$
  select public.workspace_today(pg_temp.u(101))
$f$;

-- the answer of a statement run as a person, the deferred checks included: its value, or ERR, its code, its detail and its message
create or replace function pg_temp.run_as(p_user uuid, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
    set constraints all immediate;
    set constraints all deferred;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || ' ' || coalesce(nullif(d, ''), '-') || ' ' || sqlerrm;
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
  select pg_temp.u(case p_code when 'BEANS' then 301 when 'MUGS' then 302 when 'SYRUP' then 303 when 'HONEY' then 304 end)
$f$;
create or replace function pg_temp.lot(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_lots where workspace_id = pg_temp.u(101) and lot_code = p_code
$f$;
-- the request number of a row: an opening (O1 -> 901), a step (S01 -> 1001), a there-and-back (R01 -> 2001), a unit
-- row (U01 -> 3001), a row of the rule for less than nothing (N01 -> 4001)
create or replace function pg_temp.req(p_row text) returns int language sql immutable as $f$
  select (case left(p_row, 1) when 'O' then 900 when 'S' then 1000 when 'R' then 2000 when 'U' then 3000 else 4000 end) + substr(p_row, 2)::int
$f$;
-- the lines of a spec: `ITEM QTY FROM>TO [UNIT|- [LOT]]` (or `ITEM QTY FROM ...`) joined by `;`
create or replace function pg_temp.lines(p_spec text) returns jsonb language sql stable as $f$
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'item_id', pg_temp.item(t[1]), 'quantity', t[2],
           'from', pg_temp.loc(split_part(t[3], '>', 1)),
           'to', pg_temp.loc(nullif(split_part(t[3], '>', 2), '')),
           'unit', nullif(t[4], '-'), 'lot_id', pg_temp.lot(t[5]))) order by n), '[]'::jsonb)
    from (select n, regexp_split_to_array(trim(l), '\s+') as t
            from unnest(string_to_array(p_spec, ';')) with ordinality as x(l, n)) y
$f$;
-- an answer in one word: ok, short (DKG03), `refused REASON FIELD` (DKG11), or `code DKGnn` and what it said
create or replace function pg_temp.outcome(r text) returns text language sql immutable as $f$
  select case
    when r is null or r not like 'ERR %' then 'ok'
    when r like 'ERR DKG11 {%' then 'refused ' || coalesce(substring(r from '"reason": ?"([a-z_]+)"'), '?') || ' ' || coalesce(substring(r from '"field": ?"([^"]+)"'), '?')
    when r like 'ERR DKG03%' then 'short'
    else 'code ' || substr(r, 5) end
$f$;
create or replace function pg_temp.call(p_sql text) returns text language sql as $f$
  select pg_temp.outcome(pg_temp.run_as(pg_temp.u(1), p_sql))
$f$;
-- The reads below are volatile on purpose: a stable function reads with the snapshot of the statement that calls it,
-- and would not see what a command run earlier in the same statement wrote.
-- `ITEM@PLACE=QTY ...` with what the business holds there now, lots together
create or replace function pg_temp.bal(p_spec text) returns text language sql as $f$
  select string_agg(split_part(k, '=', 1) || '=' || (
           select trim_scale(coalesce(sum(b.quantity), 0))::text from public.stock_balances b
            where b.workspace_id = pg_temp.u(101) and b.item_id = pg_temp.item(split_part(split_part(k, '=', 1), '@', 1))
              and b.location_id = pg_temp.loc(split_part(split_part(k, '=', 1), '@', 2))), ' ' order by n)
    from unnest(string_to_array(p_spec, ' ')) with ordinality as x(k, n)
$f$;
-- every balance of the business that is not zero, the places outside it included, as one digest
create or replace function pg_temp.snap() returns text language sql as $f$
  select coalesce(md5(string_agg(b.item_id::text || '|' || pg_temp.z(b.variant_id)::text || '|' || pg_temp.z(b.lot_id)::text || '|'
                                 || b.location_id::text || '=' || trim_scale(b.quantity)::text, ','
                                 order by b.item_id, pg_temp.z(b.variant_id), pg_temp.z(b.lot_id), b.location_id)), 'nothing')
    from public.stock_balances b where b.workspace_id = pg_temp.u(101) and b.quantity <> 0
$f$;

-- THE INVARIANT, read from the tables: what is wrong, or nothing
create or replace function pg_temp.broken(p_below_zero_allowed boolean default false) returns text language sql as $f$
  with mv as (
    select x.item_id, pg_temp.z(x.variant_id) as v, pg_temp.z(x.lot_id) as l, x.place, sum(x.q) as q
      from (select item_id, variant_id, lot_id, to_location_id as place, quantity as q
              from public.stock_movements where workspace_id = pg_temp.u(101)
            union all
            select item_id, variant_id, lot_id, from_location_id, -quantity
              from public.stock_movements where workspace_id = pg_temp.u(101)) x
     group by 1, 2, 3, 4),
  bal as (
    select b.item_id, pg_temp.z(b.variant_id) as v, pg_temp.z(b.lot_id) as l, b.location_id as place, sum(b.quantity) as q, count(*) as n
      from public.stock_balances b where b.workspace_id = pg_temp.u(101) group by 1, 2, 3, 4),
  kinds as (
    select sl.id, k.virtual from public.stock_locations sl join public.stock_location_kinds k on k.key = sl.kind
     where sl.workspace_id = pg_temp.u(101)),
  packed as (
    select hl.item_id, pg_temp.z(hl.variant_id) as v, pg_temp.z(hl.lot_id) as l, hu.location_id as place, sum(hl.quantity) as q
      from public.stock_handling_unit_lines hl
      join public.stock_handling_units hu on hu.workspace_id = hl.workspace_id and hu.id = hl.unit_id
     where hl.workspace_id = pg_temp.u(101) and hu.state = 'open' group by 1, 2, 3, 4)
  select coalesce(concat_ws('; ',
    (select 'a balance is not the sum of its movements: ' || count(*) from mv m full join bal b using (item_id, v, l, place)
      where coalesce(m.q, 0) <> coalesce(b.q, 0) having count(*) > 0),
    (select 'two balance rows for one item, variant, lot and place: ' || count(*) from bal where n > 1 having count(*) > 0),
    (select 'an item does not sum to zero over all places: ' || count(*)
       from (select item_id, v, l from bal group by 1, 2, 3 having sum(q) <> 0) x having count(*) > 0),
    (select 'below zero at a real place: ' || count(*) from bal b join kinds k on k.id = b.place
      where not k.virtual and b.q < 0 and not p_below_zero_allowed having count(*) > 0),
    (select 'an open unit holds more than its place: ' || count(*) from packed p left join bal b using (item_id, v, l, place)
      where p.q > coalesce(b.q, 0) having count(*) > 0)), '')
$f$;
-- the lines whose movements, parts together, are not the entered quantity at the frozen factor, to six decimals
create or replace function pg_temp.unfaithful_lines() returns text language sql as $f$
  select coalesce(string_agg(x.reason || ' ' || x.unit || ' entered ' || trim_scale(x.entered)::text || ' x ' || x.num || '/' || x.den
                             || ' recorded ' || trim_scale(x.q)::text, '; ' order by x.reason, x.unit, x.q), '')
    from (select m.request_id, m.line_no, min(m.reason) as reason, min(m.entered_unit) as unit, min(m.entered_quantity) as entered,
                 min(m.entered_factor_num) as num, min(m.entered_factor_den) as den, sum(m.quantity) as q
            from public.stock_movements m where m.workspace_id = pg_temp.u(101) group by 1, 2) x
   where x.num is null or x.den is null or x.q <> round(x.entered * x.num / x.den, 6)
$f$;
-- the items whose shelf count (services.stock) is not the whole part of what the real places hold, never below zero
create or replace function pg_temp.stale_counts() returns text language sql as $f$
  select coalesce(string_agg(s.name || ' says ' || coalesce(s.stock::text, 'null') || ', holds ' || trim_scale(h.q)::text, '; ' order by s.name), '')
    from public.services s
    cross join lateral (select coalesce(sum(b.quantity), 0) as q from public.stock_balances b
                          join public.stock_locations sl on sl.id = b.location_id
                          join public.stock_location_kinds k on k.key = sl.kind
                         where b.item_id = s.id and not k.virtual) h
   where s.workspace_id = pg_temp.u(101)
     and exists (select 1 from public.stock_movements m where m.item_id = s.id)
     and s.stock is distinct from greatest(0, floor(h.q))::int
$f$;
-- the value the two reads state, and the same sum taken from the balances: lot by lot, what is left at its recorded cost
create or replace function pg_temp.stock_values() returns text language plpgsql as $f$
declare a text; b text; c text;
begin
  a := pg_temp.run_as(pg_temp.u(1), format('select trim_scale((public.stock_valuation_v1(%L) ->> ''known_total_minor'')::numeric)::text', pg_temp.u(101)));
  b := pg_temp.run_as(pg_temp.u(1), format('select trim_scale((public.stock_value_at_v1(%L, null) ->> ''total_minor'')::numeric)::text', pg_temp.u(101)));
  select trim_scale(coalesce(sum(round(x.q * l.total_cost_minor / l.quantity_received)), 0))::text into c
    from (select bl.lot_id, sum(bl.quantity) as q from public.stock_balances bl
            join public.stock_locations sl on sl.id = bl.location_id
            join public.stock_location_kinds k on k.key = sl.kind
           where bl.workspace_id = pg_temp.u(101) and not k.virtual and bl.lot_id is not null group by 1) x
    join public.stock_lots l on l.id = x.lot_id
   where l.cost_state = 'known' and x.q <> 0;
  return a || '|' || b || '|' || c;
end
$f$;

-- one row's command, through the RPC a member calls
create or replace function pg_temp.run(p_row text, p_kind text, p_spec text, p_arg text) returns text language plpgsql as $f$
declare
  ws uuid := pg_temp.u(101);
  n int := pg_temp.req(p_row);
  t text[] := regexp_split_to_array(trim(p_spec), '\s+');
  v_transfer uuid := pg_temp.u(999001);
  v_line uuid := pg_temp.u(999002);
  v_unit public.stock_handling_units;
  v_out text;
begin
  if p_kind = 'move' then
    return pg_temp.call(format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', ws, pg_temp.u(n), pg_temp.lines(p_spec), p_arg));
  elsif p_kind = 'transfer' then
    return pg_temp.call(format('select public.stock_transfer_v1(%L, %L, %L::jsonb)::text', ws, pg_temp.u(n), pg_temp.lines(p_spec)));
  elsif p_kind = 'load' then
    return pg_temp.call(format('select public.stock_transfer_load_v1(%L, %L, %L, %L::jsonb)::text',
      ws, pg_temp.u(n), pg_temp.loc(p_arg), pg_temp.lines(p_spec)));
  elsif p_kind = 'receive' then
    select x.transfer_id, x.id into v_transfer, v_line from public.stock_transfer_lines x
      join public.stock_transfers tr on tr.id = x.transfer_id
     where tr.workspace_id = ws and tr.request_id = pg_temp.u(pg_temp.req(p_arg)) order by x.id limit 1;
    return pg_temp.call(format('select public.stock_transfer_receive_v1(%L, %L, %L, %L::jsonb)::text', ws, pg_temp.u(n), v_transfer,
      jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('line_id', v_line, 'quantity', t[1], 'to', pg_temp.loc(t[2]))))));
  elsif p_kind = 'take_out' then
    return pg_temp.call(format('select public.%s(%L, %L, %L::jsonb)::text',
      case p_arg when 'consumption' then 'stock_consume_v1' else 'stock_loss_v1' end, ws, pg_temp.u(n), pg_temp.lines(p_spec)));
  elsif p_kind = 'return' then
    return pg_temp.call(format('select public.stock_return_v1(%L, %L, %L, %L, %L::jsonb)::text', ws, pg_temp.u(n), pg_temp.u(n + 10000),
      split_part(p_arg, ':', 1), jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        'return_line_id', pg_temp.u(n + 20000),
        'source_movement_id', (select m.id from public.stock_movements m
                                where m.workspace_id = ws and m.request_id = pg_temp.u(pg_temp.req(split_part(p_arg, ':', 2)))
                                order by m.line_no, m.part limit 1),
        'quantity', t[1], 'location', pg_temp.loc(t[2]))))));
  elsif p_kind = 'count' then
    v_out := pg_temp.call(format('select public.stock_count_record_v1(%L, %L, %L, %L::jsonb, %L)::text', ws, pg_temp.u(n), pg_temp.u(n + 10000),
      jsonb_build_object('item_id', pg_temp.item(t[1]), 'location_id', pg_temp.loc(t[2])), t[3]));
    if v_out <> 'ok' then return 'the count: ' || v_out; end if;
    return pg_temp.call(format('select public.stock_count_decide_v1(%L, %L, %L, ''apply'')::text', ws, pg_temp.u(n + 40000), pg_temp.u(n + 10000)));
  elsif p_kind = 'pack' then
    -- `CODE PLACE ITEM QTY [LOT]`: a unit made at a place from loose stock
    return pg_temp.call(format('select public.stock_hu_make_v1(%L, %L, %L::jsonb)::text', ws, pg_temp.u(n),
      jsonb_build_object('code', t[1], 'kind', 'pallet', 'location_id', pg_temp.loc(t[2]), 'lines', jsonb_build_array(jsonb_strip_nulls(
        jsonb_build_object('item_id', pg_temp.item(t[3]), 'quantity', t[4], 'lot_id', pg_temp.lot(t[5])))))));
  elsif p_kind in ('unit_move', 'unpack') then
    select * into v_unit from public.stock_handling_units where workspace_id = ws and code = t[1];
    if p_kind = 'unit_move' then
      return pg_temp.call(format('select public.stock_hu_move_v1(%L, %L, %L, %L, %s)::text', ws, pg_temp.u(n), v_unit.id, pg_temp.loc(p_arg), v_unit.revision));
    end if;
    return pg_temp.call(format('select public.stock_hu_unpack_v1(%L, %L, %L, %s)::text', ws, pg_temp.u(n), v_unit.id, v_unit.revision));
  end if;
  raise exception 'no such command: %', p_kind;
end
$f$;
-- one correction of one movement, as its own return
create or replace function pg_temp.correct(p_request int, p_source uuid, p_quantity text) returns text language sql as $f$
  select pg_temp.call(format('select public.stock_return_v1(%L, %L, %L, ''correction'', %L::jsonb)::text', pg_temp.u(101), pg_temp.u(p_request),
    pg_temp.u(p_request + 10000), jsonb_build_array(jsonb_build_object('return_line_id', pg_temp.u(p_request + 20000),
      'source_movement_id', p_source, 'quantity', p_quantity))))
$f$;
-- the first movement a request wrote
create or replace function pg_temp.moved(p_request int) returns uuid language sql as $f$
  select m.id from public.stock_movements m where m.workspace_id = pg_temp.u(101) and m.request_id = pg_temp.u(p_request)
   order by m.line_no, m.part limit 1
$f$;
-- a command, then every movement it wrote corrected in full by one return: the command's answer, how many movements it
-- wrote, the return's answer, and whether every balance is what it was before the command
create or replace function pg_temp.there_and_back(p_row text, p_kind text, p_spec text, p_arg text) returns text language plpgsql as $f$
declare
  n int := pg_temp.req(p_row);
  s0 text := pg_temp.snap();
  s1 text;
  v_before uuid[];
  v_out text;
  v_back text;
  v_lines jsonb;
begin
  select coalesce(array_agg(m.id), '{}') into v_before from public.stock_movements m where m.workspace_id = pg_temp.u(101);
  v_out := pg_temp.run(p_row, p_kind, p_spec, p_arg);
  s1 := pg_temp.snap();
  select jsonb_agg(jsonb_build_object('return_line_id', pg_temp.u(70000000 + n * 100 + r.k::int), 'source_movement_id', r.id,
                                      'quantity', trim_scale(r.quantity)::text) order by r.k)
    into v_lines
    from (select m.id, m.quantity, row_number() over (order by m.line_no, m.part, m.id) as k
            from public.stock_movements m where m.workspace_id = pg_temp.u(101) and not (m.id = any (v_before))) r;
  if v_lines is null then
    return v_out || ' / nothing moved';
  end if;
  v_back := pg_temp.call(format('select public.stock_return_v1(%L, %L, %L, ''correction'', %L::jsonb)::text', pg_temp.u(101),
    pg_temp.u(n + 50000), pg_temp.u(n + 60000), v_lines));
  return v_out || ' / ' || jsonb_array_length(v_lines) || ' moved / back ' || v_back || ' / '
    || case when s1 = s0 then 'the command changed nothing' when pg_temp.snap() = s0 then 'as before' else 'NOT as before' end;
end
$f$;
-- a row as one line: its answer, the balances it names, and what is wrong (nothing)
create or replace function pg_temp.step(p_row text, p_kind text, p_spec text, p_arg text, p_balances text) returns text language plpgsql as $f$
declare v_out text;
begin
  v_out := pg_temp.run(p_row, p_kind, p_spec, p_arg);
  return v_out || ' | ' || pg_temp.bal(p_balances) || ' | ' || pg_temp.broken();
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ledger-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Ledger', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
   '{"services": true, "invoicing": true, "stockManagement": true, "stockLots": true, "stockTags": true, "stockHandlingUnits": true, "stockTakeOut": true, "stockReturns": true, "stockCounts": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Coffee beans', 900, true, null, 'kg', 'none', true),
  (pg_temp.u(302), pg_temp.u(101), 'Mugs', 600, true, null, 'piece', 'none', true),
  (pg_temp.u(303), pg_temp.u(101), 'Syrup', 400, true, null, 'l', 'none', true),
  (pg_temp.u(304), pg_temp.u(101), 'Honey', 800, true, null, 'piece', 'lot', true);
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values
  (pg_temp.u(101), pg_temp.u(302), 'box', 6, 1),
  (pg_temp.u(101), pg_temp.u(303), 'third', 1, 3);
insert into public.stock_locations (workspace_id, kind, code, name, parent_id) values
  (pg_temp.u(101), 'shelf', 'SHELF', 'Shelf', pg_temp.loc('MAIN')),
  (pg_temp.u(101), 'warehouse', 'BRANCH', 'Branch', null);
insert into public.stock_locations (workspace_id, kind, code, name, parent_id) values
  (pg_temp.u(101), 'shelf', 'BRANCH-S1', 'Branch shelf', pg_temp.loc('BRANCH'));

-- ── the openings: received from the supplier, honey and a part of the beans in lots with their cost ──
select is(
  (select string_agg(pg_temp.run(o, 'move', l, 'receipt'), ' ' order by o)
     from (values ('O1', 'BEANS 10 SUPPLIER>MAIN'), ('O2', 'MUGS 24 SUPPLIER>SHELF'), ('O3', 'SYRUP 2 SUPPLIER>MAIN')) v(o, l))
  || ' ' || pg_temp.call(format('select public.stock_move_v1(%L, %L, %L::jsonb, ''receipt'')::text', pg_temp.u(101), pg_temp.u(904), jsonb_build_array(
       jsonb_build_object('item_id', pg_temp.u(304), 'quantity', '12', 'from', pg_temp.loc('SUPPLIER'), 'to', pg_temp.loc('MAIN'),
                          'new_lot', jsonb_build_object('code', 'H-EARLY', 'expires_on', pg_temp.today() + 30, 'total_cost_minor', 1200)),
       jsonb_build_object('item_id', pg_temp.u(304), 'quantity', '12', 'from', pg_temp.loc('SUPPLIER'), 'to', pg_temp.loc('MAIN'),
                          'new_lot', jsonb_build_object('code', 'H-LATE', 'expires_on', pg_temp.today() + 90, 'total_cost_minor', 1800)),
       jsonb_build_object('item_id', pg_temp.u(301), 'quantity', '5', 'from', pg_temp.loc('SUPPLIER'), 'to', pg_temp.loc('MAIN'),
                          'new_lot', jsonb_build_object('code', 'B-1', 'total_cost_minor', 4500)))))
  || ' | ' || pg_temp.bal('BEANS@MAIN=15 MUGS@SHELF=24 SYRUP@MAIN=2 HONEY@MAIN=24') || ' | ' || pg_temp.broken(),
  'ok ok ok ok | BEANS@MAIN=15 MUGS@SHELF=24 SYRUP@MAIN=2 HONEY@MAIN=24 | ', 'the openings are received, and the ledger is whole');

-- ── a day of commands: after each, the balances it names and nothing wrong ──
select is(pg_temp.step('S01', 'transfer', 'MUGS 1 SHELF>MAIN box', '', 'MUGS@SHELF=18 MUGS@MAIN=6'),
  'ok | MUGS@SHELF=18 MUGS@MAIN=6 | ', 'S01 a box is moved as its 6 pieces');
select is(pg_temp.step('S02', 'transfer', 'SYRUP 1 MAIN>SHELF third', '', 'SYRUP@MAIN=1.666667 SYRUP@SHELF=0.333333'),
  'ok | SYRUP@MAIN=1.666667 SYRUP@SHELF=0.333333 | ', 'S02 a third of a litre is moved, to six decimals');
select is(pg_temp.step('S03', 'transfer', 'HONEY 12 MAIN>SHELF - H-EARLY; HONEY 2 MAIN>SHELF - H-LATE', '', 'HONEY@MAIN=10 HONEY@SHELF=14'),
  'ok | HONEY@MAIN=10 HONEY@SHELF=14 | ', 'S03 two lots of a tracked item are moved in one request');
select is(pg_temp.step('S04', 'load', 'MUGS 4 SHELF', 'BRANCH', 'MUGS@SHELF=14 MUGS@TRANSIT=4'),
  'ok | MUGS@SHELF=14 MUGS@TRANSIT=4 | ', 'S04 goods are loaded for the other site');
select is(pg_temp.step('S05', 'receive', '1 BRANCH-S1', 'S04', 'MUGS@TRANSIT=3 MUGS@BRANCH-S1=1'),
  'ok | MUGS@TRANSIT=3 MUGS@BRANCH-S1=1 | ', 'S05 a part is received');
select is(pg_temp.step('S06', 'receive', '3', 'S04', 'MUGS@TRANSIT=0 MUGS@BRANCH=3'),
  'ok | MUGS@TRANSIT=0 MUGS@BRANCH=3 | ', 'S06 the rest is received');
select is(pg_temp.step('S07', 'take_out', 'BEANS 12 MAIN', 'consumption', 'BEANS@MAIN=3'),
  'ok | BEANS@MAIN=3 | ', 'S07 a take-out larger than the loose stock takes the rest from the lot');
select is(pg_temp.step('S08', 'take_out', 'HONEY 1 SHELF - H-EARLY', 'loss', 'HONEY@SHELF=13'),
  'ok | HONEY@SHELF=13 | ', 'S08 a jar of a lot is written off');
select is(pg_temp.step('S09', 'return', '1', 'correction:S07', 'BEANS@MAIN=4'),
  'ok | BEANS@MAIN=4 | ', 'S09 a correction takes back a part of the take-out');
select is(pg_temp.step('S10', 'return', '1 MAIN', 'supplier:O1', 'BEANS@MAIN=3'),
  'ok | BEANS@MAIN=3 | ', 'S10 a kilo goes back to the supplier');
select is(pg_temp.step('S11', 'count', 'BEANS MAIN 5', '', 'BEANS@MAIN=5'),
  'ok | BEANS@MAIN=5 | ', 'S11 a count above the books adds exactly the difference');
select is(pg_temp.step('S12', 'count', 'MUGS MAIN 4', '', 'MUGS@MAIN=4'),
  'ok | MUGS@MAIN=4 | ', 'S12 a count below the books removes exactly the difference');
select is(pg_temp.step('S13', 'transfer', 'MUGS 100 SHELF>MAIN', '', 'MUGS@SHELF=14 MUGS@MAIN=4'),
  'short | MUGS@SHELF=14 MUGS@MAIN=4 | ', 'S13 a refused command leaves the ledger whole');
select is(pg_temp.step('S14', 'transfer', 'MUGS 1 SHELF>MAIN; MUGS 100 SHELF>MAIN', '', 'MUGS@SHELF=14 MUGS@MAIN=4'),
  'short | MUGS@SHELF=14 MUGS@MAIN=4 | ', 'S14 and so does a request refused at its second line');
select is(pg_temp.step('S15', 'pack', 'P1 SHELF HONEY 5 H-EARLY', '', 'HONEY@SHELF=13 HONEY@MAIN=10'),
  'ok | HONEY@SHELF=13 HONEY@MAIN=10 | ', 'S15 a unit is packed from loose stock: nothing moves');
select is(pg_temp.step('S16', 'unit_move', 'P1', 'MAIN', 'HONEY@SHELF=8 HONEY@MAIN=15'),
  'ok | HONEY@SHELF=8 HONEY@MAIN=15 | ', 'S16 the unit moves with its content');
select is(pg_temp.step('S17', 'transfer', 'HONEY 1 MAIN>SHELF - H-EARLY', '', 'HONEY@SHELF=8 HONEY@MAIN=15'),
  'short | HONEY@SHELF=8 HONEY@MAIN=15 | ', 'S17 what is packed in a unit is not taken loose');
select is(pg_temp.step('S18', 'unpack', 'P1', '', 'HONEY@SHELF=8 HONEY@MAIN=15'),
  'ok | HONEY@SHELF=8 HONEY@MAIN=15 | ', 'S18 the unit is unpacked: nothing moves');
select is(pg_temp.step('S19', 'transfer', 'HONEY 1 MAIN>SHELF - H-EARLY', '', 'HONEY@SHELF=9 HONEY@MAIN=14'),
  'ok | HONEY@SHELF=9 HONEY@MAIN=14 | ', 'S19 and what was in it moves loose again');

-- ── what the day left ──
select is(pg_temp.unfaithful_lines(), '', 'every line is its entered quantity at the factor frozen with it');
select is(pg_temp.stale_counts(), '', 'every item''s shelf count is the whole part of what its real places hold');
select is(pg_temp.stock_values(), '5600|5600|5600',
  'the two reads of the stock''s value agree with the balances: 11 jars at 1.00, 12 at 1.50 and 3 kg at 9.00');

-- ── a command and its full correction leave every balance as it was ──
select is(pg_temp.there_and_back('R01', 'transfer', 'SYRUP 1 MAIN>SHELF third', ''), 'ok / 1 moved / back ok / as before',
  'R01 a converted quantity (a third)');
select is(pg_temp.there_and_back('R02', 'take_out', 'BEANS 4 MAIN', 'consumption'), 'ok / 2 moved / back ok / as before',
  'R02 a take-out over loose stock and a lot');
select is(pg_temp.there_and_back('R03', 'take_out', 'HONEY 2 SHELF - H-LATE', 'loss'), 'ok / 1 moved / back ok / as before',
  'R03 a loss of a tracked lot');
select is(pg_temp.there_and_back('R04', 'transfer', 'MUGS 2 SHELF>MAIN box', ''), 'ok / 1 moved / back ok / as before',
  'R04 two boxes');
select is(pg_temp.there_and_back('R05', 'move', 'MUGS 6 SUPPLIER>SHELF', 'receipt'), 'ok / 1 moved / back ok / as before',
  'R05 a receipt');
select is(pg_temp.there_and_back('R06', 'count', 'MUGS SHELF 10', ''), 'ok / 1 moved / back ok / as before',
  'R06 the adjustment of a count');
select is(pg_temp.broken(), '', 'and the ledger is whole after the six');
-- in slices: three ninths take a third back, and nothing is left to take
do $d$ begin perform set_config('t.s0', pg_temp.snap(), false); end $d$;
select is(pg_temp.run('R08', 'transfer', 'SYRUP 1 MAIN>SHELF third', '') || ' ' || pg_temp.correct(2081, pg_temp.moved(2008), '0.111111')
          || ' ' || pg_temp.correct(2082, pg_temp.moved(2008), '0.111111') || ' ' || pg_temp.correct(2083, pg_temp.moved(2008), '0.111111')
          || ' ' || (pg_temp.snap() = current_setting('t.s0'))::text,
  'ok ok ok ok true', 'R08 a movement corrected in three slices is corrected exactly');
select is(left(pg_temp.correct(2084, pg_temp.moved(2008), '0.000001'), 10), 'code DKG17', 'R08 and not by a millionth more');
-- a correction corrected: the goods are where the command put them
do $d$ begin
  perform set_config('t.s0', pg_temp.snap(), false);
  perform set_config('t.r9', pg_temp.run('R09', 'transfer', 'MUGS 1 SHELF>MAIN', ''), false);
  perform set_config('t.s1', pg_temp.snap(), false);
end $d$;
select is(current_setting('t.r9') || ' ' || pg_temp.correct(2091, pg_temp.moved(2009), '1') || ' ' || (pg_temp.snap() = current_setting('t.s0'))::text,
  'ok ok true', 'R09 a transfer corrected is as before');
select is(pg_temp.correct(2092, pg_temp.moved(2091), '1') || ' ' || (pg_temp.snap() = current_setting('t.s1'))::text || ' ' || pg_temp.broken(),
  'ok true ', 'R09 and its correction corrected is the transfer again');

-- ── units: there and back ──
do $d$ begin perform set_config('t.s0', pg_temp.snap(), false); end $d$;
select is(pg_temp.run('U01', 'transfer', 'MUGS 1 SHELF>MAIN box', '') || ' ' || pg_temp.run('U02', 'transfer', 'MUGS 6 MAIN>SHELF', '')
          || ' ' || (pg_temp.snap() = current_setting('t.s0'))::text, 'ok ok true', 'U01 a box out and six pieces back is nothing');
select is(pg_temp.run('U03', 'transfer', 'SYRUP 1 MAIN>SHELF third', '') || ' ' || pg_temp.run('U04', 'transfer', 'SYRUP 1 SHELF>MAIN third', '')
          || ' ' || (pg_temp.snap() = current_setting('t.s0'))::text, 'ok ok true', 'U02 a third out and a third back is nothing');
-- MEASURED, not wished (#4492 row 1): a third has no finite decimal and is rounded at each movement, so the thirds do
-- not add up to the litre they came from. The decision (refuse an inexact conversion, or keep the rounding) is open.
select is(pg_temp.run('U05', 'transfer', 'SYRUP 1 MAIN>SHELF third', '') || ' ' || pg_temp.run('U06', 'transfer', 'SYRUP 1 MAIN>SHELF third', '')
          || ' | ' || pg_temp.bal('SYRUP@MAIN=1.000001 SYRUP@SHELF=0.999999') || ' | ' || pg_temp.broken(),
  'ok ok | SYRUP@MAIN=1.000001 SYRUP@SHELF=0.999999 | ', 'U03 today: three thirds moved one by one are 0.999999 of a litre on the shelf');
select is(pg_temp.run('U07', 'transfer', 'SYRUP 1 SHELF>MAIN', '') || ' ' || pg_temp.run('U08', 'transfer', 'SYRUP 3 SHELF>MAIN third', ''),
  'short short', 'U04 today: neither the litre nor three thirds at once can be taken back from them');
select is(pg_temp.run('U09', 'transfer', 'SYRUP 0.999999 SHELF>MAIN', '') || ' | ' || pg_temp.bal('SYRUP@MAIN=2 SYRUP@SHELF=0') || ' | ' || pg_temp.unfaithful_lines(),
  'ok | SYRUP@MAIN=2 SYRUP@SHELF=0 | ', 'U05 today: only the rounded quantity itself brings the litre back; each line is still its rounded conversion');

-- ── less than nothing: one rule at every door ──
do $d$ begin perform set_config('t.s0', pg_temp.snap(), false); end $d$;
select is(concat_ws(' ',
    pg_temp.run('N01', 'transfer', 'MUGS 100 SHELF>MAIN', ''),
    pg_temp.run('N02', 'load', 'MUGS 100 SHELF', 'BRANCH'),
    pg_temp.run('N03', 'take_out', 'BEANS 100 MAIN', 'consumption'),
    pg_temp.run('N04', 'take_out', 'MUGS 100 SHELF', 'loss'),
    pg_temp.run('N05', 'return', '20 SHELF', 'supplier:O2'),
    pg_temp.run('N06', 'return', '6', 'correction:S01'),
    pg_temp.run('N07', 'pack', 'P9 MAIN MUGS 100', ''),
    pg_temp.run('N08', 'transfer', 'HONEY 100 SHELF>MAIN - H-LATE', '')),
  'short short short short short short short short',
  'with the setting off, a transfer, a load, a consumption, a loss, a supplier return, a correction, a unit and a lot are all short');
select is((pg_temp.snap() = current_setting('t.s0'))::text || ' ' || pg_temp.broken(), 'true ', 'and none of them moved anything');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'stock.allow_negative', 'true'::jsonb);
select is(concat_ws(' ',
    pg_temp.run('N11', 'transfer', 'MUGS 100 SHELF>MAIN', ''),
    pg_temp.run('N12', 'load', 'MUGS 100 SHELF', 'BRANCH'),
    pg_temp.run('N13', 'take_out', 'BEANS 100 MAIN', 'consumption'),
    pg_temp.run('N14', 'take_out', 'MUGS 100 SHELF', 'loss'),
    pg_temp.run('N15', 'return', '20 SHELF', 'supplier:O2'),
    pg_temp.run('N16', 'transfer', 'HONEY 100 SHELF>MAIN - H-LATE', ''),
    pg_temp.run('N17', 'transfer', 'BEANS 4 MAIN>SHELF - B-1', '')),
  'ok ok ok ok ok short short',
  'with the setting on, the same doors let an untracked item go below zero, and a lot never does');
select is(pg_temp.broken(true) || '|' || (select count(*) from public.stock_balances b
            join public.stock_locations sl on sl.id = b.location_id join public.stock_location_kinds k on k.key = sl.kind
           where b.workspace_id = pg_temp.u(101) and not k.virtual and b.quantity < 0 and b.lot_id is not null),
  '|0', 'the ledger below zero is still the sum of its movements, and no lot is below zero');
select is(pg_temp.stale_counts(), '', 'and the shelf count of an item below zero is zero');

select * from finish();
rollback;
