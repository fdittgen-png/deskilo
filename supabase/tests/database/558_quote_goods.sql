-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4433 (0940): a quote may offer goods, and the invoice it is converted into sells them: the quote line names its
-- stock item, the conversion issues the invoice through the one issuer, and the goods leave stock with a sale linked to
-- the invoice and the line that came from the quote. Rolled back.
begin;
select plan(9);

create function pg_temp.u(n int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-00004434' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.today() returns date language sql stable security definer as $$
  select public.workspace_today(pg_temp.u(101))
$$;
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
create function pg_temp.goods(p_item uuid) returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('description', 'Mugs', 'quantity', '2', 'unit_price', '10', 'basis', 'net',
    'supply', 'goods', 'item_id', p_item, 'base_quantity', '1',
    'unit', jsonb_build_object('code', 'piece', 'label', 'pc', 'un_ece_code', 'C62')))
$$;
create function pg_temp.save(p_lines jsonb) returns text language sql as $$
  select pg_temp.run_as(1, format($s$select public.save_customer_quote_draft_v1(%L, null, null, %L, null, null, '', '', 'Mugs', %L::jsonb)::text$s$,
    pg_temp.u(101), pg_temp.u(203), p_lines))
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'quotegoods' || n || '@example.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions,
                               vat_regime, vat_id, legal_id, street, city, postal_code, address)
values (pg_temp.u(101), 'Quote goods 4433', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"invoicing": true, "standaloneInvoicing": true, "customerQuotes": true, "services": true, "stockManagement": true}',
        '{"admin": ["manageStock"]}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120',
        '4 avenue de Castelnau, 34120 Pézenas');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active', '2026-01-01');
update public.profiles set display_name = 'Ana Martin', company = 'Martin SAS', street = '1 rue X',
       postal_code = '75001', city = 'Paris', country_code = 'FR', legal_id = '12345678900012'
 where id = pg_temp.u(3);
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, active, valid_from)
values (pg_temp.u(301), pg_temp.u(101), 'Normal 20 %', 20, 'S', true, true, '2000-01-01');
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(401), pg_temp.u(101), 'Mugs', 1000, true, 'piece', 'none', true);
select ok(pg_temp.run_as(1, format('select public.stock_move_v1(%L, %L, %L::jsonb, %L)::text', pg_temp.u(101), pg_temp.u(901),
  jsonb_build_array(jsonb_build_object('item_id', pg_temp.u(401), 'quantity', '5', 'from', pg_temp.place('supplier'), 'to', pg_temp.loc('MAIN'))),
  'receipt')) like '{%', 'fixture: 5 mugs at MAIN');

-- ── the quote ──
select is(pg_temp.save(jsonb_build_array(pg_temp.goods(null))), 'ERR DKQ06 line_1_item', 'a goods line of a quote names its item');
select set_config('q.a', pg_temp.save(jsonb_build_array(pg_temp.goods(pg_temp.u(401)))), false);
select set_config('q.id', current_setting('q.a')::jsonb ->> 'quote_id', false);
select is((select lines -> 0 ->> 'supply' || '|' || (lines -> 0 ->> 'item_id') from public.customer_quote_revisions
            where quote_id = current_setting('q.id')::uuid), 'goods|' || pg_temp.u(401), 'the quote keeps the goods line and its item');
select ok(pg_temp.run_as(1, format('select public.send_customer_quote_v1(%L, %L, 1, %s)::text', pg_temp.u(101), current_setting('q.id'),
  (select draft_version from public.customer_quote_revisions where quote_id = current_setting('q.id')::uuid and revision = 1))) like '{%',
  'it is sent: the real issuer reads the goods line');
select ok(pg_temp.run_as(1, format($s$select public.record_customer_quote_decision_v1(%L, %L, 1, 'accepted', %L, 'email', 'mail')::text$s$,
  pg_temp.u(101), current_setting('q.id'), pg_temp.today())) like '{%', 'and accepted');

-- ── the conversion ──
select set_config('c.a', pg_temp.run_as(1, format('select public.prepare_quote_conversion_v1(%L, %L, %L, %L)::text',
  pg_temp.u(101), current_setting('q.id'), pg_temp.today(), pg_temp.today() + 30)), false);
select is(current_setting('c.a')::jsonb #> '{preview,missing}', '[]'::jsonb, 'the preview of the conversion finds nothing missing');
select set_config('c.i', pg_temp.run_as(1, format('select public.convert_customer_quote_v1(%L, %L, %s, %L)::text',
  pg_temp.u(101), current_setting('q.id'), current_setting('c.a')::jsonb ->> 'draft_revision', pg_temp.u(902))), false);
select ok(current_setting('c.i') like '{%', 'the quote is converted into an invoice: ' || current_setting('c.i'));
select is((select m.reason || '|' || trim_scale(m.quantity)::text || '|' || m.invoice_line_id::text
             from public.stock_movements m where m.invoice_id = (current_setting('c.i')::jsonb ->> 'invoice_id')::uuid),
  'sale|2|' || (select lines -> 0 ->> 'line_id' from public.customer_quote_revisions where quote_id = current_setting('q.id')::uuid),
  'its goods leave with a sale linked to the invoice and to the line that came from the quote');
select is((select coalesce(sum(quantity), 0) from public.stock_balances where item_id = pg_temp.u(401) and location_id = pg_temp.loc('MAIN')),
  3::numeric, 'MAIN holds 3 mugs');

select * from finish();
rollback;
