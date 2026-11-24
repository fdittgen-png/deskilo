-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4436 (0939): a sale of a traced good names the track IDs it was received with. A lot-traced line names the lot the stock path
-- took (both, with their quantities, when it took from two) by its supplier code; a piece-traced line names each piece by its tag
-- code; the codes are copied when the stock moves, so a later recode never alters an issued receipt; the rows are never edited
-- (DKL03), are read like the receipt lines, and a replay writes nothing twice. Rolled back.
begin;
select plan(16);

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
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.f(p text, k text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb ->> k else p end
$f$;
create or replace function pg_temp.draft(p_user int, p_ws int, p_req int, p_receipt uuid, p_rev int, p_body text, p_delegated boolean default false) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_draft_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), p_receipt, p_rev, p_body), p_delegated)
$f$;
create or replace function pg_temp.fin(p_user int, p_ws int, p_req int, p_receipt uuid, p_rev int, p_tenders text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_finalize_v1(%L, %L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), p_receipt, p_rev, p_tenders))
$f$;
create or replace function pg_temp.corr(p_user int, p_ws int, p_req int, p_orig uuid, p_body text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_correct_v1(%L, %L, %L, %L::jsonb)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), p_orig, p_body))
$f$;
create or replace function pg_temp.line(p_desc text, p_qty text, p_price text, p_extra text default '') returns text language sql as $f$
  select format('{"description": "%s", "quantity": "%s", "unit_price": "%s", "supply": "general", "unit": {"code": "unit", "label": "unit", "un_ece_code": "C62"}%s}', p_desc, p_qty, p_price, p_extra)
$f$;
create or replace function pg_temp.goodsline(p_item int, p_qty text) returns text language sql as $f$
  select format('{"item_id": "%s", "quantity": "%s", "supply": "goods"}', pg_temp.u(p_item), p_qty)
$f$;
create or replace function pg_temp.try(p_sql text) returns text language plpgsql as $f$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end
$f$;
create or replace function pg_temp.codes(p_receipt text) returns text language sql stable as $f$
  select coalesce(string_agg(t.track_kind || ':' || t.track_code || ':' || trim_scale(t.quantity)::text, ' ' order by t.track_code), 'none')
    from public.counter_line_tracks t where t.receipt_id = p_receipt::uuid
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ctrack-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Track FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "stockManagement": true, "stockLots": true, "stockTags": true}', '{"member": ["manageStock"]}'),
  (pg_temp.u(105), 'Track other', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(4), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true, "stockManagement": true, "stockLots": true, "stockTags": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(205), pg_temp.u(105), pg_temp.u(4), true, true, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
select pg_temp.u(800 + w), pg_temp.u(w), 'Standard', 20, 'S', true, 'standard' from (values (101), (105)) v(w);
insert into public.setting_values (scope, workspace_id, key, value)
select 'workspace', pg_temp.u(w), 'counter.fiscal_obligation', '"none"'::jsonb from (values (101), (105)) v(w);
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Lot item', 500, true, 'piece', 'lot', true),
  (pg_temp.u(302), pg_temp.u(101), 'Piece item', 700, true, 'piece', 'serial', true),
  (pg_temp.u(303), pg_temp.u(101), 'Plain item', 300, true, 'piece', 'none', true);
update public.services set tag_mode = 'per_unit' where id = pg_temp.u(302);
create or replace function pg_temp.recv(p_req int, p_lines text) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(1), format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, 'receipt'))
$f$;
grant execute on function pg_temp.recv(int, text) to authenticated, anon;
select pg_temp.recv(1400, format('[{"item_id": "%s", "quantity": "5", "from": "%s", "to": "%s", "new_lot": {"total_cost_minor": 500, "code": "SUP-A"}},
  {"item_id": "%s", "quantity": "5", "from": "%s", "to": "%s", "new_lot": {"total_cost_minor": 500, "code": "SUP-B"}}]',
  pg_temp.u(301), (select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = 'supplier' limit 1), (select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = 'MAIN'),
  pg_temp.u(301), (select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = 'supplier' limit 1), (select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = 'MAIN')));
select pg_temp.recv(1402, format('[{"item_id": "%s", "quantity": "5", "from": "%s", "to": "%s", "new_lot": {"total_cost_minor": 500, "code": "SUP-C"}},
  {"item_id": "%s", "quantity": "5", "from": "%s", "to": "%s", "new_lot": {"total_cost_minor": 500, "code": "SUP-D"}}]',
  pg_temp.u(303), (select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = 'supplier' limit 1), (select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = 'MAIN'),
  pg_temp.u(303), (select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = 'supplier' limit 1), (select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = 'MAIN')));
select pg_temp.recv(1401, format('[{"item_id": "%s", "quantity": "2", "from": "%s", "to": "%s", "new_lot": {"total_cost_minor": 800, "code": "PL-1"}, "units": [{"tag": "AABBCCDD01"}, {"tag": "AABBCCDD02"}]}]',
  pg_temp.u(302), (select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = 'supplier' limit 1), (select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = 'MAIN')));

select is((select count(*)::int from public.stock_lots where workspace_id = pg_temp.u(101)) || ' ' || (select count(*)::int from public.stock_tagged_units where workspace_id = pg_temp.u(101)), '5 2', 'fixture: five lots (two of the batch item, two of the plain item, one of the piece item), two tagged pieces');
select is((select count(*)::int from public.counter_line_tracks), 0, 'receiving stock for the shop writes no track row: only a sale line does');

-- a. a sale of the batch item that names its lot: the line carries the lot's supplier code
select set_config('t.a', pg_temp.f(pg_temp.draft(1, 101, 1405, null, null, '{"source_ref": "t-0", "lines": [' ||
  format('{"item_id": "%s", "quantity": "3", "supply": "goods", "lot_id": "%s"}', pg_temp.u(301), (select id from public.stock_lots where workspace_id = pg_temp.u(101) and lot_code = 'SUP-A')) || ']}'), 'receipt_id'), false);
select is(left(pg_temp.fin(1, 101, 1406, current_setting('t.a')::uuid, 1, '[{"kind": "cash", "amount_minor": 1500}]'), 3) <> 'ERR', true, 'a sale of the batch item that names its lot is issued');
select is(pg_temp.codes(current_setting('t.a')), 'lot:SUP-A:3', 'the line names the lot it took, by the supplier''s code, with the quantity');

-- b. a line that takes from two lots (the stock path splits an untraced item over its cost lots): both, with their quantities
select set_config('t.d', pg_temp.draft(1, 101, 1410, null, null, '{"source_ref": "t-1", "lines": [' || pg_temp.goodsline(303, '7') || ']}'), false);
select set_config('t.r', pg_temp.f(current_setting('t.d'), 'receipt_id'), false);
select set_config('t.f', pg_temp.fin(1, 101, 1411, current_setting('t.r')::uuid, 1, '[{"kind": "cash", "amount_minor": 2100}]'), false);
select is(left(current_setting('t.f'), 3) <> 'ERR', true, 'a sale that takes from two lots is issued');
select is((select count(*)::int from public.stock_movements m join public.counter_receipt_lines l on l.id = m.counter_line_id where m.counter_receipt_id = current_setting('t.r')::uuid and l.line_no = 1), 2, 'the sale''s movements name the receipt line they leave for');
select is(pg_temp.codes(current_setting('t.r')), 'lot:SUP-C:5 lot:SUP-D:2', 'the line names both lots the stock path took, as received, with their quantities');

-- d. the lot is recoded afterwards: the issued receipt keeps the code it left with
update public.stock_lots set lot_code = 'RECODED' where workspace_id = pg_temp.u(101) and lot_code in ('SUP-A', 'SUP-C');
select is(pg_temp.codes(current_setting('t.r')) || ' / ' || pg_temp.codes(current_setting('t.a')), 'lot:SUP-C:5 lot:SUP-D:2 / lot:SUP-A:3', 'after the lots'' codes change, the receipts still hold the old codes');

-- g. a replay writes nothing twice
select is(pg_temp.f(pg_temp.fin(1, 101, 1411, current_setting('t.r')::uuid, 1, '[{"kind": "cash", "amount_minor": 2100}]'), 'replayed') || ' ' || (select count(*)::int from public.counter_line_tracks where receipt_id = current_setting('t.r')::uuid), 'true 2', 'a replay of the finalize writes no second row');

-- e. never edited
select is(pg_temp.try(format('update public.counter_line_tracks set track_code = %L where receipt_id = %L', 'X', current_setting('t.r'))), 'DKL03', 'an update of a track row is refused with DKL03');
select is(pg_temp.try(format('update public.counter_line_tracks set quantity = 1 where receipt_id = %L', current_setting('t.r'))), 'DKL03', 'a quantity is not edited either');

-- c. pieces: the finalize names none, so the stock path is called as the counter's own command would, with the line's link
select set_config('t.p', pg_temp.draft(1, 101, 1420, null, null, '{"source_ref": "t-2", "lines": [' || pg_temp.goodsline(301, '1') || ']}'), false);
select set_config('t.pr', pg_temp.f(current_setting('t.p'), 'receipt_id'), false);
select set_config('t.pl', (select id::text from public.counter_receipt_lines where receipt_id = current_setting('t.pr')::uuid and line_no = 1), false);
select set_config('deskilo.counter_links', 'on', false);
select public.stock_apply_lines(pg_temp.u(101), pg_temp.u(201), pg_temp.u(1421),
  jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(302), 'quantity', '2', 'lot_id', (select id from public.stock_lots where workspace_id = pg_temp.u(101) and lot_code = 'PL-1'), 'from', (select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = 'MAIN'),
    'to', (select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = 'customer' limit 1),
    'units', jsonb_build_array(jsonb_build_object('tag', 'AABBCCDD01'), jsonb_build_object('tag', 'AABBCCDD02')), 'counter_line_id', current_setting('t.pl'))),
  'sale', now(), jsonb_build_object('counter_receipt_id', current_setting('t.pr')), 'generic');
select set_config('deskilo.counter_links', 'off', false);
select is(pg_temp.codes(current_setting('t.pr')), 'piece:AABBCCDD01:1 piece:AABBCCDD02:1 lot:PL-1:2', 'a piece-traced line names each piece by its tag code (and its lot)');

-- f. who reads
select is(pg_temp.run_as(pg_temp.u(1), 'select count(*)::text from public.counter_line_tracks'), '6', 'the seller reads the track rows');
select is(pg_temp.run_as(pg_temp.u(2), 'select count(*)::text from public.counter_line_tracks'), '0', 'a member without issueInvoices or viewFinances reads none');
select is(pg_temp.run_as(pg_temp.u(4), 'select count(*)::text from public.counter_line_tracks'), '0', 'another business reads none');
select is(left(pg_temp.run_as(pg_temp.u(1), 'insert into public.counter_line_tracks (workspace_id, receipt_id, line_id, movement_id, track_kind, track_code, quantity) select workspace_id, receipt_id, line_id, gen_random_uuid(), ''lot'', ''Z'', 1 from public.counter_line_tracks limit 1'), 9), 'ERR 42501', 'no one writes a track row directly');

select * from finish();
rollback;
