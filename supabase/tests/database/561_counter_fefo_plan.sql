-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4436 (0947): the lots a counter sale draws, planned safely. The goods items are locked before their lots are planned
-- (two tills wait for each other; one session cannot show the wait, the lock order is the stock path's); two lines of one
-- lot-tracked item plan around each other and no lot goes below zero; too little that is good with expired goods there
-- is refused DKG03 with "reason": "expired" in the detail, and "not_enough" when nothing expired; a line taken from the
-- lots keeps its sale unit (a box from each lot, not six pieces). Rolled back.
begin;
select plan(10);

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
  -- the cash is the draft's total when none is given
  return pg_temp.run_as(pg_temp.u(1), format('select public.counter_receipt_finalize_v1(%L, %L, %L, 1, %L::jsonb)::text',
           pg_temp.u(101), pg_temp.u(p_req + 1), v_d::jsonb ->> 'receipt_id',
           format('[{"kind": "cash", "amount_minor": %s}]', coalesce(p_cash, (v_d::jsonb #>> '{totals,gross_minor}')::bigint))));
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
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'fefo-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Fefo FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "stockManagement": true, "stockLots": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
values (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb);
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode) values
  (pg_temp.u(301), pg_temp.u(101), 'Honey', 500, true, 'piece', 'lot', true, null),
  (pg_temp.u(302), pg_temp.u(101), 'Jam', 300, true, 'piece', 'lot', true, null),
  (pg_temp.u(303), pg_temp.u(101), 'Salt', 200, true, 'piece', 'lot', true, null),
  (pg_temp.u(304), pg_temp.u(101), 'Tea', 100, true, 'piece', 'lot', true, null),
  (pg_temp.u(305), pg_temp.u(101), 'Rice', 100, true, 'piece', 'lot', true, null);
-- a box of tea, and of rice, is six pieces
insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values
  (pg_temp.u(101), pg_temp.u(304), 'box', 6, 1), (pg_temp.u(101), pg_temp.u(305), 'box', 6, 1);

-- honey: an expired lot (OLD) and two good ones, SUP-A first to expire; jam: only an expired lot; salt: one good lot of one;
-- tea: a lot of six pieces (one box) and a lot of twelve (two boxes); rice: four pieces and eight
do $s$
declare
  v_line text := '{"item_id": "%s", "quantity": "%s", "from": "%s", "to": "%s", "expired_ack": true, "new_lot": {"code": "%s", "expires_on": "%s", "total_cost_minor": 100}}';
begin
  perform pg_temp.mv(1001, '[' || concat_ws(', ',
    format(v_line, pg_temp.u(301), '10', pg_temp.loc('supplier'), pg_temp.loc('MAIN'), 'OLD', '2020-01-01'),
    format(v_line, pg_temp.u(301), '2', pg_temp.loc('supplier'), pg_temp.loc('MAIN'), 'SUP-A', '2090-01-01'),
    format(v_line, pg_temp.u(301), '5', pg_temp.loc('supplier'), pg_temp.loc('MAIN'), 'SUP-B', '2091-01-01'),
    format(v_line, pg_temp.u(302), '3', pg_temp.loc('supplier'), pg_temp.loc('MAIN'), 'JAM-OLD', '2020-01-01'),
    format(v_line, pg_temp.u(303), '1', pg_temp.loc('supplier'), pg_temp.loc('MAIN'), 'SALT-1', '2090-01-01'),
    format(v_line, pg_temp.u(304), '6', pg_temp.loc('supplier'), pg_temp.loc('MAIN'), 'TEA-A', '2090-01-01'),
    format(v_line, pg_temp.u(304), '12', pg_temp.loc('supplier'), pg_temp.loc('MAIN'), 'TEA-B', '2091-01-01'),
    format(v_line, pg_temp.u(305), '4', pg_temp.loc('supplier'), pg_temp.loc('MAIN'), 'RICE-A', '2090-01-01'),
    format(v_line, pg_temp.u(305), '8', pg_temp.loc('supplier'), pg_temp.loc('MAIN'), 'RICE-B', '2091-01-01')) || ']');
end $s$;

select is((select count(*)::int from public.stock_lots where workspace_id = pg_temp.u(101)), 9, 'the fixture: nine lots received');

-- ── two lines of one lot-tracked item plan around each other ──
select set_config('t.s1', pg_temp.sell(1100, format('[{"item_id": "%s", "quantity": "2"}, {"item_id": "%s", "quantity": "2"}]', pg_temp.u(301), pg_temp.u(301)), null), false);
select is(pg_temp.codes(pg_temp.j(current_setting('t.s1')) #> '{lines,0,tracks}') || ' | ' || pg_temp.codes(pg_temp.j(current_setting('t.s1')) #> '{lines,1,tracks}'),
  'lot:SUP-Ax2 | lot:SUP-Bx2', 'the second line of the same item takes what the first left: the next lot, not the first one again');
select is((select string_agg(l.lot_code || '=' || trim_scale(s.quantity)::text, ' ' order by l.lot_code)
             from public.stock_balances s join public.stock_lots l on l.id = s.lot_id
            where s.workspace_id = pg_temp.u(101) and s.item_id = pg_temp.u(301) and s.location_id = pg_temp.loc('MAIN')),
  'OLD=10 SUP-A=0 SUP-B=3', 'no lot went below zero, and the expired one was not touched');
select is(left(pg_temp.sell(1200, format('[{"item_id": "%s", "quantity": "2"}, {"item_id": "%s", "quantity": "2"}]', pg_temp.u(301), pg_temp.u(301)), null), 9),
  'ERR DKG03', 'two lines that together ask more than the good lots hold are refused, though each alone would pass');

-- ── too little that is good: the refusal says why, by key ──
select set_config('t.s3', pg_temp.sell(1300, format('[{"item_id": "%s", "quantity": "1"}]', pg_temp.u(302)), null), false);
select is(left(current_setting('t.s3'), 9), 'ERR DKG03', 'all that is left of the jam is past its date: the sale is refused DKG03');
select is((substr(current_setting('t.s3'), 11)::jsonb - 'item_id'),
  '{"scope": "lots", "reason": "expired", "asked": "1", "held": "0", "expired": "3"}'::jsonb,
  'the detail says expired by key, with what is good and what is past its date');
select is(substr(pg_temp.sell(1400, format('[{"item_id": "%s", "quantity": "2"}]', pg_temp.u(303)), null), 11)::jsonb ->> 'reason',
  'not_enough', 'too little with nothing expired says not_enough');

-- ── the sale unit is kept ──
select set_config('t.s5', pg_temp.sell(1500, format('[{"item_id": "%s", "quantity": "2", "unit": {"code": "box", "label": "box", "un_ece_code": "BX"}}]', pg_temp.u(304)), null), false);
select is((select string_agg(l.lot_code || ':' || m.entered_unit || ':' || trim_scale(m.entered_quantity)::text || ':' || trim_scale(m.quantity)::text, ' ' order by l.lot_code)
             from public.stock_movements m join public.stock_lots l on l.id = m.lot_id
            where m.counter_line_id = (pg_temp.j(current_setting('t.s5')) #>> '{lines,0,line_id}')::uuid),
  'TEA-A:box:1:6 TEA-B:box:1:6', 'two boxes split over two lots are entered as one box from each, six pieces each');
select set_config('t.s6', pg_temp.sell(1600, format('[{"item_id": "%s", "quantity": "1", "unit": {"code": "box", "label": "box", "un_ece_code": "BX"}}]', pg_temp.u(304)), null), false);
select is((select string_agg(m.entered_unit || ':' || trim_scale(m.entered_quantity)::text, ' ')
             from public.stock_movements m where m.counter_line_id = (pg_temp.j(current_setting('t.s6')) #>> '{lines,0,line_id}')::uuid),
  'box:1', 'a line one lot takes whole (the last box of the second lot) is entered as the line was');
select set_config('t.s7', pg_temp.sell(1700, format('[{"item_id": "%s", "quantity": "1", "unit": {"code": "box", "label": "box", "un_ece_code": "BX"}}]', pg_temp.u(305)), null), false);
select is((select string_agg(l.lot_code || ':' || m.entered_unit || ':' || trim_scale(m.entered_quantity)::text || ':' || trim_scale(m.quantity)::text, ' ' order by l.lot_code)
             from public.stock_movements m join public.stock_lots l on l.id = m.lot_id
            where m.counter_line_id = (pg_temp.j(current_setting('t.s7')) #>> '{lines,0,line_id}')::uuid),
  'RICE-A:piece:4:4 RICE-B:piece:2:2', 'a part that is no exact quantity of a box is entered in pieces, never rounded');

select * from finish();
rollback;
