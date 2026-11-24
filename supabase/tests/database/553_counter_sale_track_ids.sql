-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4436 (0932): a sale of a traced good names the track ID it was received with. A lot-tracked item sold without a lot
-- leaves from the lots on hand, the first to expire first and never an expired one, one movement per lot, each linked to
-- its receipt line; the line and the receipt freeze the lot codes with their quantities, and the pieces with their tags;
-- the finalize answers them and a replay answers the same; a later change of a lot never alters the issued receipt; the
-- version-1 reader keeps them; pieces named must be the quantity; too little on hand refuses the sale. Rolled back.
begin;
select plan(14);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;
create or replace function pg_temp.run_as(p_user uuid, p_sql text)
returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
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
create or replace function pg_temp.loc(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and (code = p_kind or kind = p_kind) order by (code = p_kind) desc, created_datetime limit 1
$f$;
create or replace function pg_temp.mv(p_req int, p_lines text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, 'receipt'))
$f$;
create or replace function pg_temp.sell(p_req int, p_lines text, p_cash bigint) returns text language plpgsql as $f$
declare v_d text;
begin
  v_d := pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_draft_v1(%L, %L, null, null, %L::jsonb)::text',
           pg_temp.u(101), pg_temp.u(p_req), '{"lines": ' || p_lines || '}'));
  if v_d like 'ERR%' then return v_d; end if;
  return pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_finalize_v1(%L, %L, %L, 1, %L::jsonb)::text',
           pg_temp.u(101), pg_temp.u(p_req + 1), v_d::jsonb ->> 'receipt_id', format('[{"kind": "cash", "amount_minor": %s}]', p_cash)));
end
$f$;
create or replace function pg_temp.codes(p jsonb) returns text language sql immutable as $f$
  select coalesce(string_agg((t ->> 'kind') || ':' || coalesce(t ->> 'code', '-') || coalesce('x' || (t ->> 'quantity'), ''), ' ' order by o), '')
    from jsonb_array_elements(p) with ordinality x (t, o)
$f$;
create or replace function pg_temp.j(p text) returns jsonb language sql immutable as $f$
  select case when p like '{%' then p::jsonb else jsonb_build_object('error', p) end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'track-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Track FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "stockManagement": true, "stockLots": true, "stockTags": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
values (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb);
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(301), pg_temp.u(101), 'Honey', 500, true, 'piece', 'lot', true, null),
  (pg_temp.u(302), pg_temp.u(101), 'Mug', 400, true, 'piece', 'none', true, null),
  (pg_temp.u(303), pg_temp.u(101), 'Basket', 1000, true, 'piece', 'serial', true, 'per_unit');

-- honey: an expired lot (OLD) and two good ones, SUP-A first to expire; three baskets of lot SUP-P; ten mugs
do $s$ begin
  perform pg_temp.mv(1001, format('[{"item_id": "%s", "quantity": "10", "from": "%s", "to": "%s", "expired_ack": true, "new_lot": {"code": "OLD", "expires_on": "2020-01-01", "total_cost_minor": 100}},
                                    {"item_id": "%s", "quantity": "2", "from": "%s", "to": "%s", "new_lot": {"code": "SUP-A", "expires_on": "2090-01-01", "total_cost_minor": 100}},
                                    {"item_id": "%s", "quantity": "5", "from": "%s", "to": "%s", "new_lot": {"code": "SUP-B", "expires_on": "2091-01-01", "total_cost_minor": 100}}]',
    pg_temp.u(301), pg_temp.loc('supplier'), pg_temp.loc('MAIN'), pg_temp.u(301), pg_temp.loc('supplier'), pg_temp.loc('MAIN'),
    pg_temp.u(301), pg_temp.loc('supplier'), pg_temp.loc('MAIN')));
  perform pg_temp.mv(1002, format('[{"item_id": "%s", "quantity": "3", "from": "%s", "to": "%s", "units": [{"tag": "E28068940000401561D6CC01"}, {"tag": "E28068940000401561D6CC02"}, {"tag": "E28068940000401561D6CC03"}], "new_lot": {"code": "SUP-P", "total_cost_minor": 300}},
                                    {"item_id": "%s", "quantity": "10", "from": "%s", "to": "%s"}]',
    pg_temp.u(303), pg_temp.loc('supplier'), pg_temp.loc('MAIN'), pg_temp.u(302), pg_temp.loc('supplier'), pg_temp.loc('MAIN')));
end $s$;

select is((select count(*)::int from public.stock_lots where workspace_id = pg_temp.u(101)), 4, 'the fixture: four lots received');

-- ── a lot-tracked item sold without a lot ──
select set_config('t.s1', pg_temp.sell(1100, format('[{"item_id": "%s", "quantity": "3"}]', pg_temp.u(301)), 1500), false);
select set_config('t.r1', pg_temp.j(current_setting('t.s1')) ->> 'receipt_id', false);
select set_config('t.l1', (select id::text from public.counter_receipt_lines where receipt_id = nullif(current_setting('t.r1'), '')::uuid and line_no = 1), false);
select is(pg_temp.codes((select frozen -> 'tracks' from public.counter_receipt_lines where id = nullif(current_setting('t.l1'), '')::uuid)),
  'lot:SUP-Ax2 lot:SUP-Bx1', 'a line that names no lot takes the first lot to expire first, then the next, never the expired one, and names both with their quantities');
select is((select count(*)::int || ' ' || count(distinct lot_id)::int from public.stock_movements
            where counter_line_id = nullif(current_setting('t.l1'), '')::uuid and reason = 'sale'), '2 2', 'one movement per lot, each linked to its receipt line');
select is(pg_temp.codes((select frozen #> '{lines,0,tracks}' from public.counter_receipts where id = nullif(current_setting('t.r1'), '')::uuid)),
  'lot:SUP-Ax2 lot:SUP-Bx1', 'the receipt''s frozen document carries the same track IDs');
select is(pg_temp.codes(pg_temp.j(current_setting('t.s1')) #> '{lines,0,tracks}') || ' ' || (pg_temp.j(current_setting('t.s1')) #>> '{lines,0,line_no}'),
  'lot:SUP-Ax2 lot:SUP-Bx1 1', 'the finalize answers the track IDs of its goods lines');
select is(pg_temp.codes(public.counter_receipt_decode(coalesce((select frozen from public.counter_receipts where id = nullif(current_setting('t.r1'), '')::uuid), '{"version": 1, "lines": [], "totals": {}, "currency": "EUR"}')) #> '{lines,0,tracks}'),
  'lot:SUP-Ax2 lot:SUP-Bx1', 'the version-1 reader keeps them');
select is(pg_temp.codes(pg_temp.j(pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_finalize_v1(%L, %L, %L, 1, %L::jsonb)::text',
            pg_temp.u(101), pg_temp.u(1101), current_setting('t.r1'), '[{"kind": "cash", "amount_minor": 1500}]'))) #> '{lines,0,tracks}') || ' ' ||
          (select count(*)::int from public.stock_movements where counter_line_id = nullif(current_setting('t.l1'), '')::uuid)::text,
  'lot:SUP-Ax2 lot:SUP-Bx1 2', 'a replay answers the same and moves nothing again');
update public.stock_lots set lot_code = 'RENAMED' where workspace_id = pg_temp.u(101) and lot_code = 'SUP-A';
select is(pg_temp.codes((select frozen #> '{lines,0,tracks}' from public.counter_receipts where id = nullif(current_setting('t.r1'), '')::uuid)),
  'lot:SUP-Ax2 lot:SUP-Bx1', 'a later change of the lot never alters the issued receipt');

-- ── a named lot, the pieces, an untracked item ──
select set_config('t.s2', pg_temp.sell(1200, format('[{"item_id": "%s", "quantity": "1", "lot_id": "%s"}, {"item_id": "%s", "quantity": "2", "units": [{"tag": "E28068940000401561D6CC02"}, {"tag": "E28068940000401561D6CC01"}]}, {"item_id": "%s", "quantity": "1"}]',
  pg_temp.u(301), (select id from public.stock_lots where lot_code = 'SUP-B' and workspace_id = pg_temp.u(101)), pg_temp.u(303), pg_temp.u(302)), 2900), false);
select is(pg_temp.codes(pg_temp.j(current_setting('t.s2')) #> '{lines,0,tracks}'), 'lot:SUP-Bx1', 'a line that names its lot takes that lot');
select is(pg_temp.codes(pg_temp.j(current_setting('t.s2')) #> '{lines,1,tracks}'),
  'lot:SUP-Px2 piece:E28068940000401561D6CC01 piece:E28068940000401561D6CC02', 'a line of named pieces names their lot and each piece by its tag');
select is((pg_temp.j(current_setting('t.s2')) #>> '{lines,2,tracks}') || ' ' ||
          (select count(*)::int from public.stock_movements where counter_line_id = (pg_temp.j(current_setting('t.s2')) #>> '{lines,2,line_id}')::uuid)::text,
  '[] 1', 'an untracked item names nothing, and its movement is linked to its line all the same');

-- ── refusals ──
select is(left(pg_temp.sell(1300, format('[{"item_id": "%s", "quantity": "2", "units": [{"tag": "E28068940000401561D6CC03"}]}]', pg_temp.u(303)), 2000), 9),
  'ERR DKG25', 'the pieces named must be the quantity of the line');
select set_config('t.seq', (select next_value::text from public.number_sequences where workspace_id = pg_temp.u(101) and journal = 'receipt'), false);
select is(left(pg_temp.sell(1400, format('[{"item_id": "%s", "quantity": "4"}]', pg_temp.u(301)), 2000), 9), 'ERR DKG03',
  'more than the good lots hold refuses the sale (the expired lot is not taken)');
select is((select next_value::text from public.number_sequences where workspace_id = pg_temp.u(101) and journal = 'receipt'), current_setting('t.seq'),
  'and no number is consumed');

select * from finish();
rollback;
