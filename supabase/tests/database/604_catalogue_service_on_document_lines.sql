-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4510 (0996): a line of a quote or of a standalone invoice may name the catalogue service it was picked from. A saved line
-- keeps `service_id`; a service that is unknown, of another business, kept in stock or retired is refused for a NEW line
-- (`line_<n>_service`), a line that already held a service retired since keeps it; a goods line names no service; the quote's
-- conversion carries it into the issued invoice's frozen line; a later change of the service's price changes no saved line
-- or issued invoice. Rolled back.
begin;
select plan(14);

create function pg_temp.u(n int) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-00004510' || lpad(n::text, 4, '0'))::uuid;
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
create function pg_temp.line(p_service uuid, p_id uuid default null, p_supply text default 'property', p_price text default '100') returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('description', 'Coaching', 'quantity', '2', 'unit_price', p_price, 'basis', 'gross',
    'supply', p_supply, 'base_quantity', '1', 'service_id', p_service, 'line_id', p_id,
    'unit', jsonb_build_object('code', 'hour', 'label', 'h', 'un_ece_code', 'HUR')))
$$;
create function pg_temp.qsave(p_lines jsonb, p_quote uuid default null, p_version int default null) returns text language sql as $$
  select pg_temp.run_as(1, format($s$select public.save_customer_quote_draft_v1(%L, %L, %L, %L, null, null, '', '', 'Coaching', %L::jsonb)::text$s$,
    pg_temp.u(101), p_quote, p_version, pg_temp.u(203), p_lines))
$$;
create function pg_temp.dsave(p_lines jsonb, p_draft uuid default null, p_rev int default null) returns text language sql as $$
  select pg_temp.run_as(1, format($s$select public.save_standalone_invoice_draft_v1(%L, %L, %L, %L, %L, %L, '', '', %L::jsonb)::text$s$,
    pg_temp.u(101), p_draft, p_rev, pg_temp.u(203), pg_temp.today(), pg_temp.today() + 30, p_lines))
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'catservice' || n || '@example.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, vat_regime, vat_id, legal_id,
                               street, city, postal_code, address)
values (pg_temp.u(101), 'Catalogue 4510', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"invoicing": true, "standaloneInvoicing": true, "customerQuotes": true, "services": true, "stockManagement": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120', '4 avenue de Castelnau, 34120 Pézenas'),
       (pg_temp.u(102), 'Other 4510', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"services": true}',
        'vat_registered', 'FR40303265045', '30326504500014', '4 avenue de Castelnau', 'Pézenas', '34120', '4 avenue de Castelnau, 34120 Pézenas');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, false, 'active', '2026-01-01');
update public.profiles set display_name = 'Ana Martin', company = 'Martin SAS', street = '1 rue X',
       postal_code = '75001', city = 'Paris', country_code = 'FR', legal_id = '12345678900012'
 where id = pg_temp.u(3);
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, active, valid_from)
values (pg_temp.u(301), pg_temp.u(101), 'Normal 20 %', 20, 'S', true, true, '2000-01-01');
insert into public.services (id, workspace_id, name, price_cents, active, stockable) values
  (pg_temp.u(401), pg_temp.u(101), 'Coaching', 10000, true, false),
  (pg_temp.u(402), pg_temp.u(101), 'Old workshop', 5000, false, false),
  (pg_temp.u(403), pg_temp.u(102), 'Foreign coaching', 10000, true, false);
insert into public.services (id, workspace_id, name, price_cents, active, inventory_unit, tracking, stockable) values
  (pg_temp.u(404), pg_temp.u(101), 'Mugs', 1000, true, 'piece', 'none', true);

-- ── a quote ──
select set_config('q.a', pg_temp.qsave(jsonb_build_array(pg_temp.line(pg_temp.u(401), pg_temp.u(501)))), false);
select ok(current_setting('q.a') like '{%', 'a quote line picked from the catalogue saves: ' || current_setting('q.a'));
select set_config('q.id', current_setting('q.a')::jsonb ->> 'quote_id', false);
select is((select lines -> 0 ->> 'service_id' from public.customer_quote_revisions where quote_id = current_setting('q.id')::uuid),
  pg_temp.u(401)::text, 'the quote keeps the identity of the service');
select is(pg_temp.qsave(jsonb_build_array(pg_temp.line(pg_temp.u(499)))), 'ERR DKQ06 line_1_service', 'an unknown service is refused');
select is(pg_temp.qsave(jsonb_build_array(pg_temp.line(pg_temp.u(403)))), 'ERR DKQ06 line_1_service', 'so is a service of another business');
select is(pg_temp.qsave(jsonb_build_array(pg_temp.line(pg_temp.u(404)))), 'ERR DKQ06 line_1_service', 'and one kept in stock, which is goods');
select is(pg_temp.qsave(jsonb_build_array(pg_temp.line(pg_temp.u(402)))), 'ERR DKQ06 line_1_service', 'and a retired service, for a new line');
select is(pg_temp.qsave(jsonb_build_array(pg_temp.line(pg_temp.u(401), null, 'goods'))), 'ERR DKQ06 line_1_item,line_1_service', 'a goods line names no service');

-- a service retired after the line was written stays on that line
select set_config('q.b', pg_temp.qsave(jsonb_build_array(pg_temp.line(pg_temp.u(402), pg_temp.u(502)))), false);
select is(current_setting('q.b'), 'ERR DKQ06 line_1_service', 'the retired service cannot start a line');
update public.services set active = false where id = pg_temp.u(401);
select ok(pg_temp.qsave(jsonb_build_array(pg_temp.line(pg_temp.u(401), pg_temp.u(501), 'property', '120')), current_setting('q.id')::uuid,
  (select draft_version from public.customer_quote_revisions where quote_id = current_setting('q.id')::uuid)) like '{%',
  'the line that already held the service keeps it after the service is retired');
update public.services set active = true where id = pg_temp.u(401);

-- ── the conversion carries it into the invoice, frozen ──
select ok(pg_temp.run_as(1, format('select public.send_customer_quote_v1(%L, %L, 1, %s)::text', pg_temp.u(101), current_setting('q.id'),
  (select draft_version from public.customer_quote_revisions where quote_id = current_setting('q.id')::uuid and revision = 1))) like '{%', 'the quote is sent');
select ok(pg_temp.run_as(1, format($s$select public.record_customer_quote_decision_v1(%L, %L, 1, 'accepted', %L, 'email', 'mail')::text$s$,
  pg_temp.u(101), current_setting('q.id'), pg_temp.today())) like '{%', 'and accepted');
select set_config('c.a', pg_temp.run_as(1, format('select public.prepare_quote_conversion_v1(%L, %L, %L, %L)::text',
  pg_temp.u(101), current_setting('q.id'), pg_temp.today(), pg_temp.today() + 30)), false);
update public.services set price_cents = 99900 where id = pg_temp.u(401);
select set_config('c.i', pg_temp.run_as(1, format('select public.convert_customer_quote_v1(%L, %L, %s, %L)::text',
  pg_temp.u(101), current_setting('q.id'), current_setting('c.a')::jsonb ->> 'draft_revision', pg_temp.u(902))), false);
select is((select (l #>> '{commercial,service_id}') || '|' || (l #>> '{commercial,unit_price,amount}')
             from public.invoices i, jsonb_array_elements(i.lines) l where i.id = (current_setting('c.i')::jsonb ->> 'invoice_id')::uuid),
  pg_temp.u(401)::text || '|120', 'the issued line names the service and keeps the price that was agreed, not the catalogue''s later one');

-- ── a standalone draft ──
select set_config('d.a', pg_temp.dsave(jsonb_build_array(pg_temp.line(pg_temp.u(401), pg_temp.u(503)))), false);
select ok(current_setting('d.a') like '{%', 'a standalone line picked from the catalogue saves');
select is(pg_temp.dsave(jsonb_build_array(pg_temp.line(pg_temp.u(403)))), 'ERR DKI01 line_1_service', 'a service of another business is refused on a draft');

select * from finish();
rollback;
