-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4167 (detail, 0832): the obligation rows behind a business's payables. One
-- currency, optionally one creditor kind; keyset-paged so every row is reached once
-- beyond one page; a cancelled obligation is not a row; the rows sum to what the
-- aggregates say; nothing of another business; and only the finance or purchases
-- right of THAT business reads (never a member, another owner or an assistant).
begin;
select plan(10);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select x, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bp4167-' || x || '@deskilo.test', '', now(), now(), now()
  from unnest(array['00000000-0000-4000-8000-000000004941','00000000-0000-4000-8000-000000004942','00000000-0000-4000-8000-000000004943']::uuid[]) x;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values ('00000000-0000-4000-8000-000000004950', 'Payables A', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000004941', '{"moneyTab":true,"purchases":true}'),
       ('00000000-0000-4000-8000-000000004951', 'Payables B', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000004943', '{"moneyTab":true,"purchases":true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values ('00000000-0000-4000-8000-000000004961', '00000000-0000-4000-8000-000000004950', '00000000-0000-4000-8000-000000004941', true, true, 'active', now()),
       ('00000000-0000-4000-8000-000000004962', '00000000-0000-4000-8000-000000004950', '00000000-0000-4000-8000-000000004942', false, false, 'active', now()),
       ('00000000-0000-4000-8000-000000004963', '00000000-0000-4000-8000-000000004951', '00000000-0000-4000-8000-000000004943', true, true, 'active', now());
insert into public.suppliers (id, workspace_id, supplier_number, name)
values ('00000000-0000-4000-8000-000000004968', '00000000-0000-4000-8000-000000004950', '1', 'Supplier A');
-- supplier bills: 100.00 + 25.00 held + 5.00 in euros, 30.00 in pounds; a member's
-- 40.00 expense in euros; a cancelled supplier bill; and the other business's
insert into public.purchase_documents (id, workspace_id, kind, state, currency, supplier_id, submitter_member_id, payer_kind, decided_by_member_id)
values ('00000000-0000-4000-8000-000000004970', '00000000-0000-4000-8000-000000004950', 'bill', 'approved', 'EUR', '00000000-0000-4000-8000-000000004968', '00000000-0000-4000-8000-000000004961', 'unpaid', '00000000-0000-4000-8000-000000004961'),
       ('00000000-0000-4000-8000-000000004971', '00000000-0000-4000-8000-000000004950', 'bill', 'approved', 'EUR', '00000000-0000-4000-8000-000000004968', '00000000-0000-4000-8000-000000004961', 'unpaid', '00000000-0000-4000-8000-000000004961'),
       ('00000000-0000-4000-8000-000000004972', '00000000-0000-4000-8000-000000004950', 'bill', 'approved', 'EUR', '00000000-0000-4000-8000-000000004968', '00000000-0000-4000-8000-000000004961', 'unpaid', '00000000-0000-4000-8000-000000004961'),
       ('00000000-0000-4000-8000-000000004973', '00000000-0000-4000-8000-000000004950', 'bill', 'approved', 'GBP', '00000000-0000-4000-8000-000000004968', '00000000-0000-4000-8000-000000004961', 'unpaid', '00000000-0000-4000-8000-000000004961'),
       ('00000000-0000-4000-8000-000000004975', '00000000-0000-4000-8000-000000004950', 'bill', 'approved', 'EUR', '00000000-0000-4000-8000-000000004968', '00000000-0000-4000-8000-000000004961', 'unpaid', '00000000-0000-4000-8000-000000004961');
insert into public.purchase_documents (id, workspace_id, kind, state, currency, submitter_member_id, payer_kind, payer_member_id, decided_by_member_id)
values ('00000000-0000-4000-8000-000000004974', '00000000-0000-4000-8000-000000004950', 'member_receipt', 'approved', 'EUR', '00000000-0000-4000-8000-000000004962', 'member', '00000000-0000-4000-8000-000000004962', '00000000-0000-4000-8000-000000004961');
insert into public.purchase_documents (id, workspace_id, kind, state, currency, supplier_id, submitter_member_id, payer_kind, decided_by_member_id)
values ('00000000-0000-4000-8000-000000004976', '00000000-0000-4000-8000-000000004951', 'bill', 'approved', 'EUR', null, '00000000-0000-4000-8000-000000004963', 'unpaid', '00000000-0000-4000-8000-000000004963');
insert into public.purchase_obligations (id, workspace_id, purchase_id, creditor_kind, creditor_supplier_id, creditor_member_id, amount_cents, currency, state, created_datetime)
values ('00000000-0000-4000-8000-000000004980', '00000000-0000-4000-8000-000000004950', '00000000-0000-4000-8000-000000004970', 'supplier', '00000000-0000-4000-8000-000000004968', null, 10000, 'EUR', 'open', '2026-10-01 10:00+00'),
       ('00000000-0000-4000-8000-000000004981', '00000000-0000-4000-8000-000000004950', '00000000-0000-4000-8000-000000004971', 'supplier', '00000000-0000-4000-8000-000000004968', null, 2500, 'EUR', 'held', '2026-10-02 10:00+00'),
       ('00000000-0000-4000-8000-000000004982', '00000000-0000-4000-8000-000000004950', '00000000-0000-4000-8000-000000004972', 'supplier', '00000000-0000-4000-8000-000000004968', null, 500, 'EUR', 'open', '2026-10-05 10:00+00'),
       ('00000000-0000-4000-8000-000000004983', '00000000-0000-4000-8000-000000004950', '00000000-0000-4000-8000-000000004973', 'supplier', '00000000-0000-4000-8000-000000004968', null, 3000, 'GBP', 'open', '2026-10-03 10:00+00'),
       ('00000000-0000-4000-8000-000000004984', '00000000-0000-4000-8000-000000004950', '00000000-0000-4000-8000-000000004974', 'member', null, '00000000-0000-4000-8000-000000004962', 4000, 'EUR', 'open', '2026-10-05 10:00+00'),
       ('00000000-0000-4000-8000-000000004985', '00000000-0000-4000-8000-000000004950', '00000000-0000-4000-8000-000000004975', 'supplier', '00000000-0000-4000-8000-000000004968', null, 999, 'EUR', 'cancelled', '2026-10-04 10:00+00');

create or replace function pg_temp.act_as(p_user text, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    (json_build_object('sub', p_user, 'role', 'authenticated')::jsonb
      || case when p_client is null then '{}'::jsonb else jsonb_build_object('client_id', p_client) end)::text, true);
  perform set_config('request.jwt.claim.sub', p_user, true);
end $$;
grant execute on function pg_temp.act_as(text, text) to authenticated;

select pg_temp.act_as('00000000-0000-4000-8000-000000004941');
set local role authenticated;
select is((select count(*)::int from jsonb_array_elements(public.business_payables_page_v1('00000000-0000-4000-8000-000000004950', 'EUR')->'rows')), 4,
  'the euro rows of both directions: three supplier obligations and one member expense, the cancelled one left out');
select is((select count(*)::int from jsonb_array_elements(public.business_payables_page_v1('00000000-0000-4000-8000-000000004950', 'EUR', 'member')->'rows') r
            where r#>>'{obligation,creditor_kind}' = 'member'), 1, 'a creditor kind filters the rows');
select is((select sum((r#>>'{obligation,remaining_cents}')::bigint)::text from jsonb_array_elements(public.business_payables_page_v1('00000000-0000-4000-8000-000000004950', 'EUR', 'supplier')->'rows') r),
  '13000', 'the supplier rows sum to what the supplier aggregate says, held 25.00 included once');
select is((select count(*)::int from jsonb_array_elements(public.business_payables_page_v1('00000000-0000-4000-8000-000000004950', 'GBP')->'rows')), 1, 'pounds are their own rows');
create temp table pages on commit drop as
  select 1 as n, public.business_payables_page_v1('00000000-0000-4000-8000-000000004950', 'EUR', null, null, null, 2) j;
insert into pages select 2, public.business_payables_page_v1('00000000-0000-4000-8000-000000004950', 'EUR', null,
  ((select j from pages where n = 1)->'next'->>'created')::timestamptz,
  ((select j from pages where n = 1)->'next'->>'id')::uuid, 2);
select is((select count(distinct r#>>'{obligation,id}')::int from pages, jsonb_array_elements(j->'rows') r), 4,
  'two pages of two reach every obligation once, with a tied date');
select is((select j->'next' from pages where n = 2), 'null'::jsonb, 'the last page has no continuation');
select throws_ok($$select public.business_payables_page_v1('00000000-0000-4000-8000-000000004950', 'EUR', 'payroll')$$, '22023', 'unknown creditor kind', 'an unknown creditor kind is refused');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000004942');
set local role authenticated;
select throws_ok($$select public.business_payables_page_v1('00000000-0000-4000-8000-000000004950', 'EUR')$$, '42501', 'business payables are not available', 'an ordinary member is refused');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000004943');
set local role authenticated;
select throws_ok($$select public.business_payables_page_v1('00000000-0000-4000-8000-000000004950', 'EUR')$$, '42501', 'business payables are not available', 'another business''s owner is refused');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000004941', 'delegate');
set local role authenticated;
select throws_ok($$select public.business_payables_page_v1('00000000-0000-4000-8000-000000004950', 'EUR')$$, '42501', 'business payables are not available', 'an assistant session is refused');
reset role;

select * from finish();
rollback;
