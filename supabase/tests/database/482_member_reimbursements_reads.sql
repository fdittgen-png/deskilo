-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4167 (B, 0831): what a business owes its members back. The summary is the
-- complete per-currency aggregate of the member creditor kind (held is a subset
-- of remaining, a cancelled obligation owes nothing), the page reaches every
-- obligation once beyond one page, and only the finance or purchases right of
-- THAT business reads: never an ordinary member, another business's owner or an
-- assistant. A denied read is an error, not a zero.
begin;
select plan(13);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select x, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mr4167-' || x || '@deskilo.test', '', now(), now(), now()
  from unnest(array['00000000-0000-4000-8000-000000004841','00000000-0000-4000-8000-000000004842','00000000-0000-4000-8000-000000004843','00000000-0000-4000-8000-000000004844']::uuid[]) x;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values ('00000000-0000-4000-8000-000000004850', 'Reimbursements A', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000004841', '{"moneyTab":true,"purchases":true}'),
       ('00000000-0000-4000-8000-000000004851', 'Reimbursements B', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000004843', '{"moneyTab":true,"purchases":true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values ('00000000-0000-4000-8000-000000004861', '00000000-0000-4000-8000-000000004850', '00000000-0000-4000-8000-000000004841', true, true, 'active', now()),
       ('00000000-0000-4000-8000-000000004862', '00000000-0000-4000-8000-000000004850', '00000000-0000-4000-8000-000000004842', false, false, 'active', now()),
       ('00000000-0000-4000-8000-000000004863', '00000000-0000-4000-8000-000000004851', '00000000-0000-4000-8000-000000004843', true, true, 'active', now()),
       ('00000000-0000-4000-8000-000000004864', '00000000-0000-4000-8000-000000004850', '00000000-0000-4000-8000-000000004844', false, false, 'active', now());
-- six expenses a member paid: 100.00 and 25.00 held in euros, 30.00 in pounds,
-- a cancelled one, and two more in euros so the page needs three pages of two
insert into public.purchase_documents (id, workspace_id, kind, state, currency, submitter_member_id, payer_kind, payer_member_id, decided_by_member_id)
select x.id, '00000000-0000-4000-8000-000000004850', 'member_receipt', 'approved', x.cur, '00000000-0000-4000-8000-000000004862', 'member', '00000000-0000-4000-8000-000000004862', '00000000-0000-4000-8000-000000004861'
  from (values ('00000000-0000-4000-8000-000000004870'::uuid, 'EUR'), ('00000000-0000-4000-8000-000000004871'::uuid, 'EUR'), ('00000000-0000-4000-8000-000000004872'::uuid, 'GBP'),
               ('00000000-0000-4000-8000-000000004873'::uuid, 'EUR'), ('00000000-0000-4000-8000-000000004874'::uuid, 'EUR'), ('00000000-0000-4000-8000-000000004875'::uuid, 'EUR')) x(id, cur);
insert into public.purchase_documents (id, workspace_id, kind, state, currency, submitter_member_id, payer_kind, payer_member_id, decided_by_member_id)
values ('00000000-0000-4000-8000-000000004876', '00000000-0000-4000-8000-000000004851', 'member_receipt', 'approved', 'EUR', '00000000-0000-4000-8000-000000004863', 'member', '00000000-0000-4000-8000-000000004863', '00000000-0000-4000-8000-000000004863');
insert into public.purchase_obligations (id, workspace_id, purchase_id, creditor_kind, creditor_member_id, amount_cents, currency, state, created_datetime)
values ('00000000-0000-4000-8000-000000004880', '00000000-0000-4000-8000-000000004850', '00000000-0000-4000-8000-000000004870', 'member', '00000000-0000-4000-8000-000000004862', 10000, 'EUR', 'open', '2026-10-01 10:00+00'),
       ('00000000-0000-4000-8000-000000004881', '00000000-0000-4000-8000-000000004850', '00000000-0000-4000-8000-000000004871', 'member', '00000000-0000-4000-8000-000000004862', 2500, 'EUR', 'held', '2026-10-02 10:00+00'),
       ('00000000-0000-4000-8000-000000004882', '00000000-0000-4000-8000-000000004850', '00000000-0000-4000-8000-000000004872', 'member', '00000000-0000-4000-8000-000000004862', 3000, 'GBP', 'open', '2026-10-03 10:00+00'),
       ('00000000-0000-4000-8000-000000004883', '00000000-0000-4000-8000-000000004850', '00000000-0000-4000-8000-000000004873', 'member', '00000000-0000-4000-8000-000000004862', 999, 'EUR', 'cancelled', '2026-10-04 10:00+00'),
       ('00000000-0000-4000-8000-000000004884', '00000000-0000-4000-8000-000000004850', '00000000-0000-4000-8000-000000004874', 'member', '00000000-0000-4000-8000-000000004862', 500, 'EUR', 'open', '2026-10-05 10:00+00'),
       ('00000000-0000-4000-8000-000000004885', '00000000-0000-4000-8000-000000004850', '00000000-0000-4000-8000-000000004875', 'member', '00000000-0000-4000-8000-000000004862', 700, 'EUR', 'open', '2026-10-05 10:00+00'),
       ('00000000-0000-4000-8000-000000004886', '00000000-0000-4000-8000-000000004851', '00000000-0000-4000-8000-000000004876', 'member', '00000000-0000-4000-8000-000000004863', 88888, 'EUR', 'open', '2026-10-01 10:00+00');

create or replace function pg_temp.act_as(p_user text, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    (json_build_object('sub', p_user, 'role', 'authenticated')::jsonb
      || case when p_client is null then '{}'::jsonb else jsonb_build_object('client_id', p_client) end)::text, true);
  perform set_config('request.jwt.claim.sub', p_user, true);
end $$;
grant execute on function pg_temp.act_as(text, text) to authenticated;

select pg_temp.act_as('00000000-0000-4000-8000-000000004841');
set local role authenticated;
create temp table s on commit drop as
  select r from jsonb_array_elements(public.member_reimbursements_summary_v1('00000000-0000-4000-8000-000000004850')->'rows') r;
select is((select r->>'remaining_cents' from s where r->>'currency' = 'EUR'), '13700', 'the euros owed to members: 100.00 + 25.00 held + 5.00 + 7.00, the cancelled one owes nothing');
select is((select r->>'held_cents' from s where r->>'currency' = 'EUR'), '2500', 'the held part is a subset of the remainder, shown apart');
select is((select r->>'remaining_cents' from s where r->>'currency' = 'GBP'), '3000', 'pounds are their own row, never added to euros');
select is((select count(*)::int from s), 2, 'two currencies');
select is((select (r->>'obligations')::int from s where r->>'currency' = 'EUR'), 4, 'four euro obligations are still open (the cancelled one is not)');
create temp table pages on commit drop as
  select 1 as n, public.member_reimbursements_page_v1('00000000-0000-4000-8000-000000004850', null, null, 2) j;
insert into pages select 2, public.member_reimbursements_page_v1('00000000-0000-4000-8000-000000004850',
  ((select j from pages where n = 1)->'next'->>'created')::timestamptz,
  ((select j from pages where n = 1)->'next'->>'id')::uuid, 2);
insert into pages select 3, public.member_reimbursements_page_v1('00000000-0000-4000-8000-000000004850',
  ((select j from pages where n = 2)->'next'->>'created')::timestamptz,
  ((select j from pages where n = 2)->'next'->>'id')::uuid, 2);
select is((select jsonb_array_length(j->'rows') from pages where n = 1), 2, 'the first page holds its limit');
select is((select count(distinct r#>>'{obligation,id}')::int from pages, jsonb_array_elements(j->'rows') r), 6,
  'the pages reach every obligation of this business once, none of the other business');
select is((select j->'next' from pages where n = 3), 'null'::jsonb, 'the last page has no continuation');
select is((select sum((r#>>'{obligation,remaining_cents}')::bigint)::text from pages, jsonb_array_elements(j->'rows') r
            where r#>>'{obligation,currency}' = 'EUR'), '13700', 'the detail sums to the summary');
reset role;

select pg_temp.act_as('00000000-0000-4000-8000-000000004842');
set local role authenticated;
select throws_ok($$select public.member_reimbursements_summary_v1('00000000-0000-4000-8000-000000004850')$$, '42501', 'member reimbursements are not available', 'an ordinary member, even the creditor, reads no aggregate');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000004843');
set local role authenticated;
select throws_ok($$select public.member_reimbursements_page_v1('00000000-0000-4000-8000-000000004850')$$, '42501', 'member reimbursements are not available', 'another business''s owner is refused');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000004841', 'delegate');
set local role authenticated;
select throws_ok($$select public.member_reimbursements_summary_v1('00000000-0000-4000-8000-000000004850')$$, '42501', 'member reimbursements are not available', 'an assistant session is refused');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000004841');
set local role authenticated;
select throws_ok($$select public.member_reimbursements_page_v1('00000000-0000-4000-8000-000000004850', now(), null)$$, '22023', 'both cursor fields are required', 'half a cursor is refused');
reset role;

select * from finish();
rollback;
