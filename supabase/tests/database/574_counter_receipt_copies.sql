-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4476 (0966): a copy of a counter receipt is counted, never numbered again. A cashier prints copies 1 and 2 of a
-- finalized receipt and the receipt sequence does not move; the same request answers the same copy; a draft, another
-- business's receipt and a member who works no counter are refused; a copy is never edited or deleted. Rolled back.
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
create or replace function pg_temp.copy(p_user int, p_ws int, p_req int, p_receipt uuid) returns text language sql as $f$
  select pg_temp.run_as(pg_temp.u(p_user), format('select public.counter_receipt_copy_v1(%L, %L, %L)::text',
    pg_temp.u(p_ws), pg_temp.u(p_req), p_receipt))
$f$;
create or replace function pg_temp.line(p_desc text, p_qty text, p_price text) returns text language sql as $f$
  select format('{"description": "%s", "quantity": "%s", "unit_price": "%s", "supply": "general", "unit": {"code": "unit", "label": "unit", "un_ece_code": "C62"}}', p_desc, p_qty, p_price)
$f$;
create or replace function pg_temp.seq() returns text language sql stable as $f$
  select coalesce((select next_value::text from public.number_sequences where workspace_id = pg_temp.u(101) and journal = 'receipt'), 'none')
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ccopy-' || n || '@deskilo.test', '', now(), now(), now() from generate_series(1, 3) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, vat_regime, feature_flags, role_permissions) values
  (pg_temp.u(101), 'Copies FR', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{"member": ["issueInvoices"]}'),
  (pg_temp.u(102), 'Copies other', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'vat_registered',
   '{"services": true, "invoicing": true, "standaloneInvoicing": true, "counterReceipts": true}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
  (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(202), pg_temp.u(102), pg_temp.u(1), true, true, 'active'),
  (pg_temp.u(299), pg_temp.u(101), pg_temp.u(2), false, false, 'active'),
  (pg_temp.u(298), pg_temp.u(102), pg_temp.u(3), false, false, 'active');
insert into public.vat_rates (id, workspace_id, label, percent, category, is_default, group_key)
select pg_temp.u(800 + w), pg_temp.u(100 + w), 'Standard', 20, 'S', true, 'standard' from generate_series(1, 2) w;
insert into public.setting_values (scope, workspace_id, key, value)
select 'workspace', pg_temp.u(100 + w), 'counter.fiscal_obligation', '"none"'::jsonb from generate_series(1, 2) w;

-- a sale finalized, and one left a draft
select set_config('t.r', pg_temp.f(pg_temp.draft(1, 101, 901, null, null, '{"lines": [' || pg_temp.line('Cut', '1', '12') || ']}'), 'receipt_id'), false);
select set_config('t.n', pg_temp.f(pg_temp.fin(1, 101, 902, current_setting('t.r')::uuid, 1, '[{"kind": "cash", "amount_minor": 1200}]'), 'number'), false);
select set_config('t.d', pg_temp.f(pg_temp.draft(1, 101, 903, null, null, '{"lines": [' || pg_temp.line('Wash', '1', '3') || ']}'), 'receipt_id'), false);
select set_config('t.seq', pg_temp.seq(), false);

select is(pg_temp.f(pg_temp.copy(2, 101, 911, current_setting('t.r')::uuid), 'copy_no'), '1', 'the cashier prints copy 1 of the finalized receipt');
select is(pg_temp.f(pg_temp.copy(2, 101, 912, current_setting('t.r')::uuid), 'copy_no'), '2', 'and copy 2');
select is(pg_temp.f(pg_temp.copy(2, 101, 911, current_setting('t.r')::uuid), 'copy_no') || ' ' || pg_temp.f(pg_temp.copy(2, 101, 911, current_setting('t.r')::uuid), 'replayed'),
          '1 true', 'the same request answers the same copy');
select is(pg_temp.seq(), current_setting('t.seq'), 'no copy draws a receipt number');
select is((select count(*)::int from public.counter_receipt_copies where receipt_id = current_setting('t.r')::uuid), 2, 'two copies are counted');
select is(pg_temp.copy(2, 101, 913, current_setting('t.d')::uuid), 'ERR DKL04 {"reason": "receipt"}', 'a draft has no copy');
select is(pg_temp.copy(1, 102, 914, current_setting('t.r')::uuid), 'ERR DKL04 {"reason": "receipt"}', 'nor another business''s receipt');
select is(left(pg_temp.copy(3, 102, 915, current_setting('t.r')::uuid), 9), 'ERR DKN01', 'a member who works no counter prints none');
create or replace function pg_temp.try(p_sql text) returns text language plpgsql as $f$
begin
  execute p_sql;
  return 'done';
exception when others then
  return sqlstate;
end
$f$;
select is(pg_temp.try('delete from public.counter_receipt_copies') || ' ' || pg_temp.try('update public.counter_receipt_copies set copy_no = 9'),
          'DKL03 DKL03', 'a copy is never deleted or edited');

select * from finish();
rollback;
