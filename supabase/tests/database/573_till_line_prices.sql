-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4476 (0963, 0964): a till line's price is the item's price unless a discount within the business's limit or the right
-- to change a price, with a reason, sets another. A cashier sells at the item's price (none sent, or the same one sent);
-- a cashier's other price, or a line priced by hand, is refused (DKN01); the owner's other price needs a reason (DKL02)
-- and keeps it with the list price; a discount is refused beyond the limit, taken off the item's price within it, and
-- never beside a price; a body claiming to come offline gets no tolerance; a base quantity changes nothing of the price
-- judged; the same request answers again. Rolled back.
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
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tprice-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Till prices FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{"member": ["issueInvoices"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(299), pg_temp.u(101), pg_temp.u(2), false, false, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key) values
  (pg_temp.u(801), pg_temp.u(101), 'Standard', 20, 'S', true, 'standard');
insert into public.setting_values (scope, workspace_id, key, value) values
  ('workspace', pg_temp.u(101), 'counter.fiscal_obligation', '"none"'::jsonb);
insert into public.services (id, workspace_id, name, price_cents, active) values
  (pg_temp.u(301), pg_temp.u(101), 'Croissant', 500, true);
create or replace function pg_temp.item(p_extra text default '') returns text language sql as $f$
  select format('{"lines": [{"item_id": "%s", "quantity": "1"%s}]}', pg_temp.u(301), p_extra)
$f$;
create or replace function pg_temp.total(p text) returns text language sql immutable as $f$
  select case when p like '{%' then p::jsonb #>> '{totals,gross_minor}' else p end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- the cashier: the item's price, sent or not
select is(pg_temp.total(pg_temp.draft(2, 101, 901, null, null, pg_temp.item())), '500', 'a cashier sells at the item''s price');
select is(pg_temp.total(pg_temp.draft(2, 101, 902, null, null, pg_temp.item(', "unit_price": "5"'))), '500', 'and sends it as it is');
select is(pg_temp.draft(2, 101, 903, null, null, pg_temp.item(', "unit_price": "1", "price_reason": "friend"')), 'ERR DKN01 {"reason": "price"}', 'another price is not the cashier''s to set');
select is(pg_temp.draft(2, 101, 904, null, null, '{"lines": [{"description": "Cake", "quantity": "1", "unit_price": "1", "supply": "general"}]}'), 'ERR DKN01 {"reason": "price"}', 'nor a line priced by hand');

-- the owner holds the right: another price says why, and keeps the list price beside it
select is(pg_temp.draft(1, 101, 905, null, null, pg_temp.item(', "unit_price": "4"')), 'ERR DKL02 {"reason": "price_reason"}', 'another price needs its reason');
select set_config('t.o', pg_temp.draft(1, 101, 906, null, null, pg_temp.item(', "unit_price": "4", "price_reason": "  end of day  "')), false);
select is(pg_temp.total(current_setting('t.o')), '400', 'with a reason the owner sells at 4.00');
select is((select frozen #>> '{input,list_price}' || ' / ' || (frozen #>> '{input,price_reason}') from public.counter_receipt_lines
            where receipt_id = pg_temp.f(current_setting('t.o'), 'receipt_id')::uuid), '5 / end of day', 'and the line keeps the list price and the reason, trimmed');
select is(pg_temp.f(pg_temp.draft(1, 101, 906, null, null, pg_temp.item(', "unit_price": "4", "price_reason": "  end of day  "')), 'receipt_id') || ' ' || pg_temp.f(pg_temp.draft(1, 101, 906, null, null, pg_temp.item(', "unit_price": "4", "price_reason": "  end of day  "')), 'replayed'),
          pg_temp.f(current_setting('t.o'), 'receipt_id') || ' true', 'the same request answers again with the same receipt');

-- a discount: refused beyond the business's limit, taken off the item's price within it, never beside a price
select is(pg_temp.draft(2, 101, 907, null, null, pg_temp.item(', "discount_percent": "10"')), 'ERR DKN01 {"max": 0, "reason": "discount_limit"}', 'with no limit set there is no discount at the till');
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.max_discount_percent', '10'::jsonb);
select is(pg_temp.total(pg_temp.draft(2, 101, 908, null, null, pg_temp.item(', "discount_percent": "10"'))), '450', 'within the limit 10 % off 5.00 is 4.50');
select is(left(pg_temp.draft(2, 101, 909, null, null, pg_temp.item(', "discount_percent": "15"')), 9), 'ERR DKN01', 'beyond it the discount is refused');
select is(pg_temp.draft(1, 101, 910, null, null, pg_temp.item(', "discount_percent": "5", "unit_price": "4", "price_reason": "x"')), 'ERR DKL02 {"reason": "price_and_discount"}', 'a line takes a discount or a price, not both');

-- the offline tolerance is the sync's own (555 and 570 run it); a body that only says it came offline gets none
insert into public.setting_values (scope, workspace_id, key, value) values ('workspace', pg_temp.u(101), 'counter.offline_price_tolerance_percent', '10'::jsonb);
select is(pg_temp.draft(2, 101, 911, null, null, '{"source_kind": "offline_till", "lines": [{"item_id": "' || pg_temp.u(301) || '", "quantity": "1", "unit_price": "5.2"}]}'), 'ERR DKN01 {"reason": "price"}', 'a body that says it came offline gets no tolerance');

-- the price of one base unit is what is judged: a base quantity is no way around it
select is(pg_temp.draft(2, 101, 912, null, null, pg_temp.item(', "base_quantity": "10"')), 'ERR DKN01 {"reason": "price"}', 'the item''s price over ten base units is another price');
select is(pg_temp.total(pg_temp.draft(2, 101, 913, null, null, pg_temp.item(', "unit_price": "50", "base_quantity": "10"'))), '500', 'ten base units at ten times the price is the item''s price');
select is(pg_temp.total(pg_temp.draft(2, 101, 914, null, null, pg_temp.item(', "discount_percent": "10", "base_quantity": "10"'))), '450', 'a discount sells per one base unit, whatever base quantity is sent');

select * from finish();
rollback;
