-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4185 (0894): the amounts of a counter receipt are exact and agree with its lines in a 0, a 2 and a 3 decimal
-- currency (JPY, EUR, KWD): the totals of a finalized receipt are the sums of its frozen lines, in minor units, and the
-- tenders add up to them. Rolled back.
begin;
select plan(9);

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
create or replace function pg_temp.seq() returns text language sql stable as $f$
  select coalesce((select next_value::text from public.number_sequences where workspace_id = pg_temp.u(101) and journal = 'receipt'), 'none')
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cproducer-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Counter FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}'),
  (pg_temp.u(102), 'Counter IT', 'IT', 'EUR', 'Europe/Rome', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}'),
  (pg_temp.u(103), 'Counter JP', 'FR', 'JPY', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}'),
  (pg_temp.u(104), 'Counter KW', 'FR', 'KWD', 'Europe/Paris', pg_temp.u(1), 'vat_registered', '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
select pg_temp.u(200 + w), pg_temp.u(100 + w), pg_temp.u(1), true, true, 'active' from generate_series(1, 4) w;
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values (pg_temp.u(299), pg_temp.u(101), pg_temp.u(2), false, false, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
select pg_temp.u(800 + w), pg_temp.u(100 + w), 'Standard', 20, 'S', true, 'standard' from generate_series(1, 4) w;
insert into public.setting_values (scope, workspace_id, key, value)
select 'workspace', pg_temp.u(100 + w), 'counter.fiscal_obligation', '"none"'::jsonb from generate_series(1, 4) w;


select set_config('t.j', pg_temp.draft(1, 103, 951, null, null, '{"lines": [' || pg_temp.line('Cut', '2', '1500') || ', ' || pg_temp.line('Wash', '1', '300') || ']}'), false);
select is(current_setting('t.j')::jsonb #>> '{totals,gross_minor}', '3300', 'in yen (no decimals) 2 x 1500 + 300 is 3300 minor units');
select is(pg_temp.f(pg_temp.fin(1, 103, 952, pg_temp.f(current_setting('t.j'), 'receipt_id')::uuid, 1, '[{"kind": "cash", "amount_minor": 3300}]'), 'number') is not null, true, 'and it is finalized with its tender');
select is((select (frozen #>> '{totals,gross_minor}')::bigint = (select sum(gross_minor) from public.counter_receipt_lines l where l.receipt_id = r.id) from public.counter_receipts r where id = pg_temp.f(current_setting('t.j'), 'receipt_id')::uuid), true, 'the total equals the sum of its lines');
select set_config('t.k', pg_temp.draft(1, 104, 953, null, null, '{"lines": [' || pg_temp.line('Cut', '3', '1.234') || ', ' || pg_temp.line('Wash', '1', '0.001') || ']}'), false);
select is(current_setting('t.k')::jsonb #>> '{totals,gross_minor}', '3703', 'in dinar (three decimals) 3 x 1.234 + 0.001 is 3703 minor units');
select is((current_setting('t.k')::jsonb #>> '{totals,net_minor}')::bigint + (current_setting('t.k')::jsonb #>> '{totals,tax_minor}')::bigint, 3703::bigint, 'and net plus tax is the gross, to the last unit');
select is(left(pg_temp.fin(1, 104, 954, pg_temp.f(current_setting('t.k'), 'receipt_id')::uuid, 1, '[{"kind": "cash", "amount_minor": 3700}]'), 9), 'ERR DKT06', 'a tender short by 3 units is refused');
select is(pg_temp.f(pg_temp.fin(1, 104, 955, pg_temp.f(current_setting('t.k'), 'receipt_id')::uuid, 1, '[{"kind": "cash", "amount_minor": 3000}, {"kind": "other", "amount_minor": 703}]'), 'tenders'), '2', 'two tenders adding to the total exactly settle it');
select set_config('t.e', pg_temp.draft(1, 101, 956, null, null, '{"lines": [' || pg_temp.line('Cut', '3', '12.34') || ', ' || pg_temp.line('Wash', '1', '0.01') || ']}'), false);
select is(current_setting('t.e')::jsonb #>> '{totals,gross_minor}', '3703', 'in euro 3 x 12.34 + 0.01 is 3703 minor units');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.e')::jsonb -> 'lines')), 2, 'and the preview carries each frozen line');

select * from finish();
rollback;
