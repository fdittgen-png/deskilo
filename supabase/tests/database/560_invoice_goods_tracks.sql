-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4436 (0945): a goods line of an issued invoice freezes the track IDs of what it took: the lot code as received with
-- the quantity taken from each lot, and the tag code of each piece, in the issue's own transaction. A later change of a
-- lot code never alters them, a row is never edited or deleted, a replay writes nothing twice, whoever may read the
-- invoice reads them, and the business's export carries them. Rolled back.
begin;
select plan(14);

create function pg_temp.u(n int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-00004436' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.today() returns date language sql stable security definer as $$
  select public.workspace_today(pg_temp.u(101))
$$;
-- the answer of a statement run as a user, or ERR, its code and its detail
create function pg_temp.run_as(n int, p_sql text) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
  begin
    execute p_sql into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '');
  end;
  execute 'reset role';
  return coalesce(v, 'null');
end $f$;
create function pg_temp.loc(p_code text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and code = p_code
$f$;
create function pg_temp.place(p_kind text) returns uuid language sql stable as $f$
  select id from public.stock_locations where workspace_id = pg_temp.u(101) and kind = p_kind order by created_datetime limit 1
$f$;
create function pg_temp.on_hand(p_item int, p_code text default 'MAIN') returns numeric language sql stable as $f$
  select coalesce(sum(quantity), 0) from public.stock_balances where item_id = pg_temp.u(p_item) and location_id = pg_temp.loc(p_code)
$f$;
create function pg_temp.goods(p_item int, p_qty text, p_extra jsonb default '{}') returns jsonb language sql as $$
  select jsonb_build_object('description', 'Goods', 'quantity', p_qty, 'unit_price', '10', 'basis', 'net',
    'supply', 'goods', 'item_id', pg_temp.u(p_item), 'unit', jsonb_build_object('code', 'piece', 'label', 'pc', 'un_ece_code', 'C62'))
    || p_extra
$$;
create function pg_temp.save(p_lines jsonb, p_subject int default 203) returns uuid language plpgsql as $f$
begin
  return (pg_temp.run_as(1, format($$select public.save_standalone_invoice_draft_v1(%L, null, null, %L, %L, %L, '', '', %L)::text$$,
    pg_temp.u(101), pg_temp.u(p_subject), pg_temp.today(), pg_temp.today() + 30, p_lines))::jsonb ->> 'draft_id')::uuid;
end $f$;
create function pg_temp.issue(p_draft uuid, p_req int) returns text language sql as $$
  select pg_temp.run_as(1, format('select public.issue_standalone_invoice_v1(%L, %L, 1, %L)::text', pg_temp.u(101), p_draft, pg_temp.u(p_req)))
$$;
create function pg_temp.preview(p_draft uuid) returns jsonb language sql as $$
  select pg_temp.run_as(1, format('select public.preview_standalone_invoice_v1(%L, %L, 1)::text', pg_temp.u(101), p_draft))::jsonb
$$;
create function pg_temp.mv(p_req int, p_lines jsonb, p_reason text) returns text language sql as $$
  select pg_temp.run_as(1, format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(p_req), p_lines, p_reason))
$$;
create function pg_temp.invoices() returns int language sql stable as $$
  select count(*)::int from public.invoices where workspace_id = pg_temp.u(101)
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'tracks' || n || '@example.test', '', now(), now(), now() from generate_series(1, 4) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions,
                               vat_regime, vat_id, legal_id, street, city, postal_code, address)
values (pg_temp.u(101), 'Tracks 4436', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"invoicing": true, "standaloneInvoicing": true, "services": true, "stockManagement": true, "stockLots": true, "stockTags": true}',
        '{"admin": ["manageStock"]}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active', '2026-01-01'),
       (pg_temp.u(204), pg_temp.u(101), pg_temp.u(4), false, false, 'active', '2026-01-01');
update public.profiles set display_name = 'Ana Martin', company = 'Martin SAS', street = '1 rue X',
       postal_code = '75001', city = 'Paris', country_code = 'FR', legal_id = '12345678900012'
 where id = pg_temp.u(3);
update public.profiles set display_name = 'Jan Berger', company = 'Berger GmbH', street = 'Hauptstr. 1',
       postal_code = '10115', city = 'Berlin', country_code = 'DE', vat_id = 'DE123456789'
 where id = pg_temp.u(4);
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, active, valid_from)
values (pg_temp.u(301), pg_temp.u(101), 'Normal 20 %', 20, 'S', true, true, '2000-01-01'),
       (pg_temp.u(302), pg_temp.u(101), 'Reduced 5.5 %', 5.5, 'S', false, true, '2000-01-01');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable, tag_mode, vat_rate_id) values
  (pg_temp.u(401), pg_temp.u(101), 'Mugs', 1000, true, 'piece', 'none', true, 'none', pg_temp.u(302)),
  (pg_temp.u(402), pg_temp.u(101), 'Honey', 800, true, 'piece', 'expiry', true, 'none', null),
  (pg_temp.u(403), pg_temp.u(101), 'Baskets', 4000, true, 'piece', 'serial', true, 'per_unit', null),
  (pg_temp.u(404), pg_temp.u(101), 'Advice', 5000, true, 'piece', 'none', false, 'none', null);
-- a statement run as the server's own role: its answer, or ERR and its code
create function pg_temp.try(p_sql text) returns text language plpgsql as $f$
begin
  execute p_sql;
  return 'done';
exception when others then
  return 'ERR ' || sqlstate;
end $f$;
grant execute on function pg_temp.try(text) to authenticated, anon;

-- ── the stock: 5 mugs, honey in two lots (the later expiry received first), one basket piece ──
select ok(pg_temp.mv(901, jsonb_build_array(
  jsonb_build_object('item_id', pg_temp.u(401), 'quantity', '5', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN')),
  jsonb_build_object('item_id', pg_temp.u(402), 'quantity', '3', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN'),
                     'new_lot', jsonb_build_object('code', 'LATE', 'expires_on', pg_temp.today() + 90, 'total_cost_minor', 900)),
  jsonb_build_object('item_id', pg_temp.u(402), 'quantity', '3', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN'),
                     'new_lot', jsonb_build_object('code', 'EARLY', 'expires_on', pg_temp.today() + 10, 'total_cost_minor', 900)),
  jsonb_build_object('item_id', pg_temp.u(403), 'quantity', '1', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN'),
                     'units', jsonb_build_array(jsonb_build_object('tag', 'E28068940000401561D68F01')),
                     'new_lot', jsonb_build_object('total_cost_minor', 3000))), 'receipt') like '{%', 'fixture: the goods are received at MAIN');

-- one invoice: untraced mugs, 4 honey (the stock path takes 3 from the lot that expires first, 1 from the other), a basket
select set_config('d.a', pg_temp.save(jsonb_build_array(
  pg_temp.goods(401, '1'), pg_temp.goods(402, '4'),
  pg_temp.goods(403, '1', jsonb_build_object('units', jsonb_build_array(jsonb_build_object('tag', 'E28068940000401561D68F01')))))
  )::text, false);
select set_config('i.a', pg_temp.issue(current_setting('d.a')::uuid, 701), false);
select ok(current_setting('i.a') like '{%', 'the invoice with three goods lines is issued: ' || current_setting('i.a'));
select set_config('i.a', current_setting('i.a')::jsonb ->> 'invoice_id', false);
create function pg_temp.line_id(p_pos int) returns text language sql stable as $f$
  select (l.v #>> '{commercial,line_id}') from public.invoices i, jsonb_array_elements(i.lines) with ordinality l (v, o)
   where i.id = current_setting('i.a')::uuid and l.o = p_pos
$f$;
create function pg_temp.codes(p_pos int) returns text language sql stable as $f$
  select string_agg(coalesce(t.v ->> 'code', '-') || ':' || coalesce(t.v ->> 'quantity', '-'), ',' order by t.o)
    from public.invoice_line_tracks x, jsonb_array_elements(x.tracks) with ordinality t (v, o)
   where x.invoice_id = current_setting('i.a')::uuid and x.line_id = pg_temp.line_id(p_pos) and t.v ->> 'kind' = 'lot'
$f$;

select is((select count(*)::int from public.invoice_line_tracks where invoice_id = current_setting('i.a')::uuid), 2,
  'two lines took something traced: the untraced mugs froze nothing');
select is((select count(*)::int from public.invoice_line_tracks where invoice_id = current_setting('i.a')::uuid and line_id = pg_temp.line_id(1)), 0,
  'the mugs have no row');
select is(pg_temp.codes(2), 'EARLY:3,LATE:1', 'the honey names both lots it took, as received, with their quantities');
select is((select string_agg(t ->> 'kind' || ':' || (t ->> 'code'), ',') from public.invoice_line_tracks x, jsonb_array_elements(x.tracks) t
            where x.invoice_id = current_setting('i.a')::uuid and x.line_id = pg_temp.line_id(3) and t ->> 'kind' = 'piece'),
  'piece:E28068940000401561D68F01', 'the basket names its piece by its tag code');

-- ── frozen ──
update public.stock_lots set lot_code = 'CHANGED' where workspace_id = pg_temp.u(101) and lot_code = 'EARLY';
select is(pg_temp.codes(2), 'EARLY:3,LATE:1', 'a later change of a lot code does not alter the issued invoice');
select is(pg_temp.try(format('update public.invoice_line_tracks set tracks = %L::jsonb where invoice_id = %L', '[]', current_setting('i.a')::uuid)),
  'ERR P0001', 'a track row is never edited');
select is(pg_temp.try(format('delete from public.invoice_line_tracks where invoice_id = %L', current_setting('i.a')::uuid)),
  'ERR P0001', 'nor deleted');

-- ── a replay writes nothing twice ──
select is(pg_temp.issue(current_setting('d.a')::uuid, 701)::jsonb ->> 'replayed', 'true', 'the same request replays');
select is((select count(*)::int from public.invoice_line_tracks where invoice_id = current_setting('i.a')::uuid), 2,
  'and freezes nothing twice');

-- ── who reads them ──
select is(pg_temp.run_as(1, 'select count(*)::text from public.invoice_line_tracks'), '2', 'the owner reads them');
select is(pg_temp.run_as(4, 'select count(*)::text from public.invoice_line_tracks'), '0', 'a member who may not read the invoice reads none');
select is(pg_temp.run_as(1, format($$select (public.export_workspace_records(%L) @> '[{"table": "invoice_line_tracks"}]'::jsonb)::text$$, pg_temp.u(101))),
  'true', 'the business''s export carries the table');

select * from finish();
rollback;
