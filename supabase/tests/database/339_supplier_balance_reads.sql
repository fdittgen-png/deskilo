-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3070: the aggregate matches authoritative obligation readback, and a
-- supplier-scoped cursor neither leaks another tenant nor truncates at 2000.
begin;
select plan(27);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values
 ('00000000-0000-4000-8000-000000003391', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'supplier339-owner@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-000000003392', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'supplier339-member@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-000000003393', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'supplier339-other@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values
 ('00000000-0000-4000-8000-000000003394', 'Supplier test A', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000003391', '{"moneyTab":true,"purchases":true}'),
 ('00000000-0000-4000-8000-000000003395', 'Supplier test B', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000003393', '{"moneyTab":true,"purchases":true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values
 ('00000000-0000-4000-8000-000000003396', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-000000003391', true, true, 'active', now()),
 ('00000000-0000-4000-8000-000000003397', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-000000003392', false, false, 'active', now()),
 ('00000000-0000-4000-8000-000000003398', '00000000-0000-4000-8000-000000003395', '00000000-0000-4000-8000-000000003393', true, true, 'active', now());
insert into public.suppliers (id, workspace_id, supplier_number, name)
values
 ('00000000-0000-4000-8000-000000003399', '00000000-0000-4000-8000-000000003394', '1', 'Supplier A'),
 ('00000000-0000-4000-8000-00000000339a', '00000000-0000-4000-8000-000000003395', '1', 'Supplier B');
insert into public.purchase_documents (id, workspace_id, kind, state, currency, supplier_id, submitter_member_id, payer_kind, decided_by_member_id)
values
 ('00000000-0000-4000-8000-0000000033a1', '00000000-0000-4000-8000-000000003394', 'bill', 'approved', 'EUR', '00000000-0000-4000-8000-000000003399', '00000000-0000-4000-8000-000000003396', 'unpaid', '00000000-0000-4000-8000-000000003396'),
 ('00000000-0000-4000-8000-0000000033a2', '00000000-0000-4000-8000-000000003394', 'bill', 'approved', 'EUR', '00000000-0000-4000-8000-000000003399', '00000000-0000-4000-8000-000000003396', 'unpaid', '00000000-0000-4000-8000-000000003396'),
 ('00000000-0000-4000-8000-0000000033a3', '00000000-0000-4000-8000-000000003394', 'bill', 'approved', 'GBP', '00000000-0000-4000-8000-000000003399', '00000000-0000-4000-8000-000000003396', 'unpaid', '00000000-0000-4000-8000-000000003396'),
 ('00000000-0000-4000-8000-0000000033a4', '00000000-0000-4000-8000-000000003394', 'bill', 'approved', 'EUR', '00000000-0000-4000-8000-000000003399', '00000000-0000-4000-8000-000000003396', 'unpaid', '00000000-0000-4000-8000-000000003396'),
 ('00000000-0000-4000-8000-0000000033a5', '00000000-0000-4000-8000-000000003394', 'credit_note', 'draft', 'EUR', '00000000-0000-4000-8000-000000003399', '00000000-0000-4000-8000-000000003396', 'unpaid', null),
 ('00000000-0000-4000-8000-0000000033a6', '00000000-0000-4000-8000-000000003394', 'bill', 'approved', 'EUR', '00000000-0000-4000-8000-000000003399', '00000000-0000-4000-8000-000000003396', 'unpaid', '00000000-0000-4000-8000-000000003396'),
 ('00000000-0000-4000-8000-0000000033a7', '00000000-0000-4000-8000-000000003394', 'bill', 'approved', 'CHF', '00000000-0000-4000-8000-000000003399', '00000000-0000-4000-8000-000000003396', 'unpaid', '00000000-0000-4000-8000-000000003396');
insert into public.purchase_obligations (id, workspace_id, purchase_id, creditor_kind, creditor_supplier_id, amount_cents, currency, state)
values
 ('00000000-0000-4000-8000-0000000033b1', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-0000000033a1', 'supplier', '00000000-0000-4000-8000-000000003399', 1000, 'EUR', 'open'),
 ('00000000-0000-4000-8000-0000000033b2', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-0000000033a2', 'supplier', '00000000-0000-4000-8000-000000003399', 250, 'EUR', 'held'),
 ('00000000-0000-4000-8000-0000000033b3', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-0000000033a3', 'supplier', '00000000-0000-4000-8000-000000003399', 300, 'GBP', 'open'),
 ('00000000-0000-4000-8000-0000000033b4', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-0000000033a4', 'supplier', '00000000-0000-4000-8000-000000003399', 200, 'EUR', 'cancelled'),
 ('00000000-0000-4000-8000-0000000033b5', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-0000000033a6', 'supplier', '00000000-0000-4000-8000-000000003399', 500, 'EUR', 'open'),
 ('00000000-0000-4000-8000-0000000033b6', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-0000000033a7', 'supplier', '00000000-0000-4000-8000-000000003399', 1000, 'CHF', 'open');
insert into public.outgoing_payments (id, workspace_id, payee_kind, payee_supplier_id, currency, amount_cents, method, reported_paid_on, state, actor_member_id, request_id)
values ('00000000-0000-4000-8000-0000000033c1', '00000000-0000-4000-8000-000000003394', 'supplier', '00000000-0000-4000-8000-000000003399', 'EUR', 200, 'bank_transfer', current_date, 'reported', '00000000-0000-4000-8000-000000003396', '00000000-0000-4000-8000-0000000033d1'),
 ('00000000-0000-4000-8000-0000000033c2', '00000000-0000-4000-8000-000000003394', 'supplier', '00000000-0000-4000-8000-000000003399', 'EUR', 500, 'bank_transfer', current_date, 'reported', '00000000-0000-4000-8000-000000003396', '00000000-0000-4000-8000-0000000033d5'),
 ('00000000-0000-4000-8000-0000000033c3', '00000000-0000-4000-8000-000000003394', 'supplier', '00000000-0000-4000-8000-000000003399', 'CHF', 1100, 'bank_transfer', current_date, 'reported', '00000000-0000-4000-8000-000000003396', '00000000-0000-4000-8000-0000000033d6');
insert into public.purchase_settlement_allocations (id, workspace_id, obligation_id, payment_id, kind, amount_cents, original_allocation_id, credit_document_id, request_id, actor_member_id)
values
 ('00000000-0000-4000-8000-0000000033e1', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-0000000033b1', '00000000-0000-4000-8000-0000000033c1', 'payment', 200, null, null, '00000000-0000-4000-8000-0000000033d2', '00000000-0000-4000-8000-000000003396'),
 ('00000000-0000-4000-8000-0000000033e2', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-0000000033b1', '00000000-0000-4000-8000-0000000033c1', 'reversal', -200, '00000000-0000-4000-8000-0000000033e1', null, '00000000-0000-4000-8000-0000000033d3', '00000000-0000-4000-8000-000000003396'),
 ('00000000-0000-4000-8000-0000000033e3', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-0000000033b1', null, 'credit', 100, null, '00000000-0000-4000-8000-0000000033a5', '00000000-0000-4000-8000-0000000033d4', '00000000-0000-4000-8000-000000003396'),
 ('00000000-0000-4000-8000-0000000033e4', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-0000000033b5', '00000000-0000-4000-8000-0000000033c2', 'payment', 500, null, null, '00000000-0000-4000-8000-0000000033d7', '00000000-0000-4000-8000-000000003396'),
 ('00000000-0000-4000-8000-0000000033e5', '00000000-0000-4000-8000-000000003394', '00000000-0000-4000-8000-0000000033b6', '00000000-0000-4000-8000-0000000033c3', 'payment', 1100, null, null, '00000000-0000-4000-8000-0000000033d8', '00000000-0000-4000-8000-000000003396');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000003391","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000003391', true);
set local role authenticated;
select is((select r->>'remaining_cents' from jsonb_array_elements(public.supplier_balances_v1('00000000-0000-4000-8000-000000003394')->'rows') r where r->>'currency' = 'EUR'), '1150', 'credit and reversal affect EUR, cancelled contributes zero');
select is((select r->>'held_cents' from jsonb_array_elements(public.supplier_balances_v1('00000000-0000-4000-8000-000000003394')->'rows') r where r->>'currency' = 'EUR'), '250', 'held amount remains distinct');
select is((select r->>'remaining_cents' from jsonb_array_elements(public.supplier_balances_v1('00000000-0000-4000-8000-000000003394')->'rows') r where r->>'currency' = 'GBP'), '300', 'currencies are separate');
select is((select r->>'remaining_cents' from jsonb_array_elements(public.supplier_balances_v1('00000000-0000-4000-8000-000000003394')->'rows') r where r->>'currency' = 'CHF'), '-100', 'negative producer amounts are not clamped');
select is((select r#>>'{obligation,remaining_cents}' from jsonb_array_elements(public.supplier_payables_page_v1('00000000-0000-4000-8000-000000003394','00000000-0000-4000-8000-000000003399')->'rows') r where r#>>'{obligation,id}' = '00000000-0000-4000-8000-0000000033b5'), '0', 'fully settled obligation has zero remaining');
select is(jsonb_array_length(public.supplier_payables_page_v1('00000000-0000-4000-8000-000000003394','00000000-0000-4000-8000-000000003399',null,null,2)->'rows'), 2, 'page respects its limit');
select ok(public.supplier_payables_page_v1('00000000-0000-4000-8000-000000003394','00000000-0000-4000-8000-000000003399',null,null,2)->'next' <> 'null'::jsonb, 'page exposes continuation');
select throws_ok($$select public.supplier_payables_page_v1('00000000-0000-4000-8000-000000003394','00000000-0000-4000-8000-000000003399',now(),null)$$, '22023', 'both cursor fields are required', 'half cursor refused');
select throws_ok($$select public.supplier_payables_page_v1('00000000-0000-4000-8000-000000003394','00000000-0000-4000-8000-00000000339a')$$, '22023', 'unknown supplier', 'foreign supplier refused');
select throws_ok($$select public.supplier_balances_v1('00000000-0000-4000-8000-000000003395')$$, '42501', 'supplier payables are not available', 'other workspace refused');
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000003392","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000003392', true);
set local role authenticated;
select throws_ok($$select public.supplier_balances_v1('00000000-0000-4000-8000-000000003394')$$, '42501', 'supplier payables are not available', 'ordinary member cannot read supplier aggregate');
select throws_ok($$select public.supplier_payables_page_v1('00000000-0000-4000-8000-000000003394','00000000-0000-4000-8000-000000003399')$$, '42501', 'supplier payables are not available', 'ordinary member cannot read supplier page');
reset role;
update public.workspaces set role_permissions = coalesce(role_permissions, '{}'::jsonb) || '{"member":["viewFinances"]}'::jsonb where id = '00000000-0000-4000-8000-000000003394';
set local role authenticated;
select is(jsonb_array_length(public.supplier_balances_v1('00000000-0000-4000-8000-000000003394')->'rows'), 3, 'viewFinances alone grants the complete currency aggregate');
select is(jsonb_array_length(public.supplier_payables_page_v1('00000000-0000-4000-8000-000000003394','00000000-0000-4000-8000-000000003399')->'rows'), 6, 'viewFinances alone receives supplier rows');
reset role;
update public.workspaces set role_permissions = role_permissions || '{"member":["managePurchases"]}'::jsonb where id = '00000000-0000-4000-8000-000000003394';
set local role authenticated;
select is(jsonb_array_length(public.supplier_balances_v1('00000000-0000-4000-8000-000000003394')->'rows'), 3, 'managePurchases alone grants the complete currency aggregate');
select is(jsonb_array_length(public.supplier_payables_page_v1('00000000-0000-4000-8000-000000003394','00000000-0000-4000-8000-000000003399')->'rows'), 6, 'managePurchases alone receives supplier rows');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"purchases":false}'::jsonb where id = '00000000-0000-4000-8000-000000003394';
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000003391","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000003391', true);
set local role authenticated;
select throws_ok($$select public.supplier_balances_v1('00000000-0000-4000-8000-000000003394')$$, '42501', 'supplier payables are not available', 'feature off refuses aggregate');
select throws_ok($$select public.supplier_payables_page_v1('00000000-0000-4000-8000-000000003394','00000000-0000-4000-8000-000000003399')$$, '42501', 'supplier payables are not available', 'feature off refuses page');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"purchases":true}'::jsonb where id = '00000000-0000-4000-8000-000000003394';
select is((select sum((public.purchase_obligation_json(o)->>'remaining_cents')::bigint)::text from public.purchase_obligations o where o.workspace_id = '00000000-0000-4000-8000-000000003394' and o.currency = 'EUR'), '1150', 'aggregate matches authoritative obligation serializer');
select is((select count(*)::int from public.purchase_obligations o where o.creditor_kind = 'supplier' and o.legacy_member_credit_id is not null), 0, 'supplier obligations cannot carry member invoice links');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000003391","role":"authenticated","client_id":"delegated"}', true);
set local role authenticated;
select throws_ok($$select public.supplier_balances_v1('00000000-0000-4000-8000-000000003394')$$, '42501', 'supplier payables are not available', 'delegated token cannot read aggregate');
select throws_ok($$select public.supplier_payables_page_v1('00000000-0000-4000-8000-000000003394','00000000-0000-4000-8000-000000003399')$$, '42501', 'supplier payables are not available', 'delegated token cannot read page');
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000003391","role":"authenticated"}', true);
-- Same transaction timestamp on every row deliberately exercises the id
-- tie-breaker. The real database page contract must traverse beyond 2000.
create temp table supplier339_bulk as
select gen_random_uuid() as purchase_id, gen_random_uuid() as obligation_id
  from generate_series(1, 2001);
insert into public.purchase_documents (id, workspace_id, kind, state, currency, supplier_id, submitter_member_id, payer_kind, decided_by_member_id)
select purchase_id, '00000000-0000-4000-8000-000000003394', 'bill', 'approved', 'EUR',
       '00000000-0000-4000-8000-000000003399', '00000000-0000-4000-8000-000000003396', 'unpaid',
       '00000000-0000-4000-8000-000000003396' from supplier339_bulk;
insert into public.purchase_obligations (id, workspace_id, purchase_id, creditor_kind, creditor_supplier_id, amount_cents, currency)
select obligation_id, '00000000-0000-4000-8000-000000003394', purchase_id, 'supplier',
       '00000000-0000-4000-8000-000000003399', 1, 'EUR' from supplier339_bulk;
create temp table supplier339_seen (id uuid primary key);
grant insert on supplier339_seen to authenticated;
create function pg_temp.supplier339_count() returns int language plpgsql as $$
declare
  v_page jsonb;
  v_after timestamptz;
  v_id uuid;
  v_count int := 0;
  v_calls int := 0;
begin
  loop
    v_page := public.supplier_payables_page_v1(
      '00000000-0000-4000-8000-000000003394',
      '00000000-0000-4000-8000-000000003399', v_after, v_id, 100);
    insert into supplier339_seen (id)
      select (r#>>'{obligation,id}')::uuid from jsonb_array_elements(v_page->'rows') r;
    v_count := v_count + jsonb_array_length(v_page->'rows');
    v_calls := v_calls + 1;
    if v_calls > 30 then raise exception 'cursor did not terminate'; end if;
    exit when v_page->'next' = 'null'::jsonb;
    v_after := (v_page#>>'{next,created}')::timestamptz;
    v_id := (v_page#>>'{next,id}')::uuid;
  end loop;
  return v_count;
end;
$$;
grant execute on function pg_temp.supplier339_count() to authenticated;
set local role authenticated;
select is(pg_temp.supplier339_count(), 2007, 'keyset continuation reads more than 2000 rows');
select is((select r->>'remaining_cents' from jsonb_array_elements(public.supplier_balances_v1('00000000-0000-4000-8000-000000003394')->'rows') r where r->>'currency' = 'EUR'), '3151', 'complete aggregate includes all 2001 additional obligations');
select is(jsonb_array_length(public.supplier_payables_page_v1('00000000-0000-4000-8000-000000003394','00000000-0000-4000-8000-000000003399')->'rows'), 100, 'page remains bounded');
select ok(not has_function_privilege('anon', 'public.supplier_balances_v1(uuid)', 'execute'), 'anonymous cannot execute aggregate');
select ok(not has_function_privilege('anon', 'public.supplier_payables_page_v1(uuid,uuid,timestamptz,uuid,integer)', 'execute'), 'anonymous cannot execute page');
select * from finish();
rollback;
