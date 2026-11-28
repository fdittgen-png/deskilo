-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4479 (0988): an order line holds the VAT rate the person PICKED, by its id: two active rates with one percentage are two choices, an
-- unknown or an inactive rate is refused, and a line sent with a percent alone keeps working. An archived unit is refused for a new
-- association: an order line, an item's unit, a conversion, a line of a standalone invoice draft (a quote revision carries the same guard);
-- an archived unit stays a readable row. Rolled back.
begin;
select plan(13);

create or replace function pg_temp.u(n int) returns uuid language sql immutable as $f$
  select format('00000000-0000-4000-8000-%s', lpad(n::text, 12, '0'))::uuid
$f$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pickedid-1@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Picked by identity', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"moneyTab":true,"services":true,"purchases":true,"purchaseOrders":true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active');
insert into public.suppliers (id, workspace_id, supplier_number, name, status) values (pg_temp.u(401), pg_temp.u(101), '1', 'Alpha', 'active');
update public.vat_rates set is_default = false where workspace_id = pg_temp.u(101);
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, active) values
  (pg_temp.u(501), pg_temp.u(101), 'Standard A', 20, 'S', false, true),
  (pg_temp.u(502), pg_temp.u(101), 'Standard B', 20, 'S', false, true),
  (pg_temp.u(503), pg_temp.u(101), 'Old', 7, 'S', false, false);
insert into public.workspace_units (workspace_id, code, label, dimension, factor_num, factor_den) values
  (pg_temp.u(101), 'carton', 'Carton', 'package', 1, 1),
  (pg_temp.u(101), 'pk1', 'Pack one', 'package', 1, 1),
  (pg_temp.u(101), 'pk2', 'Pack two', 'package', 1, 1);
insert into public.services (id, workspace_id, name, price_cents, active, stock, inventory_unit, tracking, stockable) values
  (pg_temp.u(301), pg_temp.u(101), 'Mugs', 100, true, null, 'piece', 'none', true);
update public.workspace_units set archived = true where workspace_id = pg_temp.u(101) and code = 'pk2';

create or replace function pg_temp.save(p_req int, p_line jsonb) returns text language plpgsql as $f$
declare v text; d text;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(1), 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    select public.save_purchase_order_v1(pg_temp.u(101), pg_temp.u(900 + p_req), 0,
      jsonb_build_object('supplier_id', pg_temp.u(401), 'expected_on', '2026-12-01', 'recipient_email', 'orders@alpha.test',
                         'lines', jsonb_build_array(p_line)))::text into v;
  exception when others then
    get stacked diagnostics d = pg_exception_detail;
    v := 'ERR ' || sqlstate || coalesce(' ' || d, '');
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create or replace function pg_temp.attempt(p_sql text) returns text language plpgsql as $f$
declare d text;
begin
  execute p_sql;
  return 'ok';
exception when others then
  get stacked diagnostics d = pg_exception_detail;
  return 'ERR ' || sqlstate || coalesce(' ' || d, '');
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.save(1, jsonb_build_object('description', 'by id A', 'quantity', 1, 'unit_price_cents', 100, 'vat_rate_id', pg_temp.u(501)));
select pg_temp.save(2, jsonb_build_object('description', 'by id B', 'quantity', 1, 'unit_price_cents', 100, 'vat_rate_id', pg_temp.u(502)));
select pg_temp.save(3, jsonb_build_object('description', 'by percent', 'quantity', 1, 'unit_price_cents', 100, 'vat_rate_percent', 20));

select is((select (vat_rate_percent = 20)::text || ' ' || (vat_rate_id = pg_temp.u(501))::text from public.purchase_order_lines where workspace_id = pg_temp.u(101) and description = 'by id A'),
  'true true', 'the line holds the rate that was picked, and its percent comes from it');
select is((select (vat_rate_id = pg_temp.u(502))::text from public.purchase_order_lines where workspace_id = pg_temp.u(101) and description = 'by id B'),
  'true', 'two rates with one percentage are two choices: the second is kept as the second');
select is((select coalesce(vat_rate_id::text, 'none') || ' ' || (vat_rate_percent = 20)::text from public.purchase_order_lines where workspace_id = pg_temp.u(101) and description = 'by percent'),
  'none true', 'a line sent with a percent alone keeps working, with no rate id');
select alike(pg_temp.save(4, jsonb_build_object('description', 'x', 'quantity', 1, 'unit_price_cents', 100, 'vat_rate_id', pg_temp.u(999))),
  'ERR DKG11%vat_rate_unknown%', 'a rate that is not the business''s is refused');
select alike(pg_temp.save(5, jsonb_build_object('description', 'x', 'quantity', 1, 'unit_price_cents', 100, 'vat_rate_id', pg_temp.u(503))),
  'ERR DKG11%vat_rate_unknown%', 'and so is a rate that is no longer active');
select alike(pg_temp.save(6, jsonb_build_object('description', 'x', 'quantity', 1, 'unit_price_cents', 100, 'unit', 'pk2')),
  'ERR DKG11%unit_unknown%', 'an archived unit is refused on an order line');
select is(pg_temp.save(7, jsonb_build_object('description', 'x', 'quantity', 1, 'unit_price_cents', 100, 'unit', 'carton'))::jsonb -> 'lines' -> 0 ->> 'unit',
  'carton', 'and a unit that is not archived is still taken');
select alike(pg_temp.attempt(format($q$insert into public.item_units (workspace_id, item_id, unit, factor_num, factor_den) values (%L, %L, 'pk2', 6, 1)$q$, pg_temp.u(101), pg_temp.u(301))),
  'ERR DKG11%unit_archived%', 'an item takes no archived unit');
select is((select archived::text from public.workspace_units where workspace_id = pg_temp.u(101) and code = 'pk2'), 'true', 'an archived unit stays a readable row');
select alike(pg_temp.attempt(format($q$insert into public.unit_conversions (workspace_id, from_unit, to_unit, factor_num, factor_den) values (%L, 'pk1', 'pk2', 1, 1)$q$, pg_temp.u(101))),
  'ERR DKG11%unit_archived%', 'a conversion takes no archived unit');
select alike(pg_temp.attempt(format($q$insert into public.standalone_invoice_drafts (workspace_id, subject_member_id, lines) values (%L, %L, '[{"unit": {"code": "pk2"}}]'::jsonb)$q$, pg_temp.u(101), pg_temp.u(201))),
  'ERR DKG11%unit_archived%', 'a draft line takes no archived unit');
select is(pg_temp.attempt(format($q$insert into public.standalone_invoice_drafts (workspace_id, subject_member_id, lines) values (%L, %L, '[{"unit": {"code": "carton"}}]'::jsonb)$q$, pg_temp.u(101), pg_temp.u(201))),
  'ok', 'and a unit that is not archived is taken on a draft line');
select is((select count(*)::text from pg_trigger where tgname in ('standalone_invoice_drafts_archived_unit', 'customer_quote_revisions_archived_unit') and not tgisinternal),
  '2', 'a quote revision carries the same guard as a draft');

select * from finish();
rollback;
