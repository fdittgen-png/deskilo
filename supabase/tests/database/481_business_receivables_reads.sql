-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4167 (A, 0830): what a business is still owed. One definition feeds the
-- per-currency summary and the paged detail; they agree beyond one page; a
-- draft-less, voided or replaced invoice is not counted; currencies and the
-- refund due stay apart; and only the finance right of THAT business reads,
-- never a member, a billed customer, another business's owner or an assistant.
begin;
select plan(21);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select x, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ar4167-' || x || '@deskilo.test', '', now(), now(), now()
  from unnest(array['00000000-0000-4000-8000-000000004801','00000000-0000-4000-8000-000000004802','00000000-0000-4000-8000-000000004803','00000000-0000-4000-8000-000000004804']::uuid[]) x;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values ('00000000-0000-4000-8000-000000004810', 'Receivables A', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000004801', '{"moneyTab":true,"invoicing":true}'),
       ('00000000-0000-4000-8000-000000004811', 'Receivables B', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000004803', '{"moneyTab":true,"invoicing":true}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values ('00000000-0000-4000-8000-000000004821', '00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004801', true, true, 'active', now()),
       ('00000000-0000-4000-8000-000000004822', '00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004802', false, false, 'active', now()),
       ('00000000-0000-4000-8000-000000004823', '00000000-0000-4000-8000-000000004811', '00000000-0000-4000-8000-000000004803', true, true, 'active', now()),
       ('00000000-0000-4000-8000-000000004824', '00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004804', false, false, 'active', now());

-- the business's book: I1 partly paid, I2 declared, I3 received and unmatched,
-- I4 in pounds, I5 a credit note owed back, I6 voided, I7 awaiting approval,
-- I8 replaced by I4 (a settlement), IB another business's.
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, issued_at)
values
 ('00000000-0000-4000-8000-000000004831', '00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004824', '00000000-0000-4000-8000-000000004821', 'AR-1', 'Work', '[]', 64200, 'EUR', 'Customer', 'A', 'Owner', 'fixture', '2026-10-01 10:00+00'),
 ('00000000-0000-4000-8000-000000004832', '00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004824', '00000000-0000-4000-8000-000000004821', 'AR-2', 'Work', '[]', 6000, 'EUR', 'Customer', 'A', 'Owner', 'fixture', '2026-10-05 10:00+00'),
 ('00000000-0000-4000-8000-000000004833', '00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004824', '00000000-0000-4000-8000-000000004821', 'AR-3', 'Work', '[]', 5000, 'EUR', 'Customer', 'A', 'Owner', 'fixture', '2026-10-05 10:00+00'),
 ('00000000-0000-4000-8000-000000004834', '00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004824', '00000000-0000-4000-8000-000000004821', 'AR-4', 'Work', '[]', 24000, 'GBP', 'London', 'A', 'Owner', 'fixture', '2026-10-02 10:00+00'),
 ('00000000-0000-4000-8000-000000004835', '00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004824', '00000000-0000-4000-8000-000000004821', 'AR-5', 'Credit', '[]', -2500, 'EUR', 'Customer', 'A', 'Owner', 'fixture', '2026-10-06 10:00+00'),
 ('00000000-0000-4000-8000-000000004836', '00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004824', '00000000-0000-4000-8000-000000004821', 'AR-6', 'Work', '[]', 9999, 'EUR', 'Customer', 'A', 'Owner', 'fixture', '2026-10-03 10:00+00'),
 ('00000000-0000-4000-8000-000000004837', '00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004824', '00000000-0000-4000-8000-000000004821', 'AR-7', 'Work', '[]', 1000, 'EUR', 'Customer', 'A', 'Owner', 'fixture', '2026-10-07 10:00+00'),
 ('00000000-0000-4000-8000-000000004838', '00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004824', '00000000-0000-4000-8000-000000004821', 'AR-8', 'Work', '[]', 7777, 'EUR', 'Customer', 'A', 'Owner', 'fixture', '2026-10-04 10:00+00'),
 ('00000000-0000-4000-8000-000000004839', '00000000-0000-4000-8000-000000004811', '00000000-0000-4000-8000-000000004823', '00000000-0000-4000-8000-000000004823', 'BR-1', 'Work', '[]', 100000, 'EUR', 'Other', 'B', 'Owner', 'fixture', '2026-10-01 10:00+00');
update public.invoices set voided_at = now() where id = '00000000-0000-4000-8000-000000004836';
update public.invoices set settled_by_invoice_id = '00000000-0000-4000-8000-000000004834' where id = '00000000-0000-4000-8000-000000004838';
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status, note, by_name)
values ('00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004831', 30000, 'under_accepted', 'confirmed', 'fixture', 'Owner'),
       ('00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004837', 1000, 'exact', 'pending', 'fixture', 'Owner');
-- I2: a declared payment waiting for the business.
insert into public.events (workspace_id, type, action, actor_member_id, status, subject_member_id, payload)
values ('00000000-0000-4000-8000-000000004810', 'payment', 'submitted', '00000000-0000-4000-8000-000000004824', 'pending', '00000000-0000-4000-8000-000000004824',
        jsonb_build_object('claim', jsonb_build_array(jsonb_build_object('invoice_id', '00000000-0000-4000-8000-000000004832'))));
-- I3: a payment arrived against it and waits for a person to match it.
do $f$ declare e uuid; begin
  insert into public.events (workspace_id, type, action, actor_member_id, status, subject_member_id, payload)
  values ('00000000-0000-4000-8000-000000004810', 'payment', 'submitted', '00000000-0000-4000-8000-000000004824', 'confirmed', '00000000-0000-4000-8000-000000004824',
          jsonb_build_object('claim', jsonb_build_array(jsonb_build_object('invoice_id', '00000000-0000-4000-8000-000000004833')),
          'claim_outcome', jsonb_build_object('left_out',
            jsonb_build_array(jsonb_build_object('invoice_id', '00000000-0000-4000-8000-000000004833', 'reason', 'error')))))
  returning id into e;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
  values ('00000000-0000-4000-8000-000000004810', '00000000-0000-4000-8000-000000004824', 'credit', 'payment', 5000, 'transfer', '2026-10', e);
end $f$;

create or replace function pg_temp.act_as(p_user text, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    (json_build_object('sub', p_user, 'role', 'authenticated')::jsonb
      || case when p_client is null then '{}'::jsonb else jsonb_build_object('client_id', p_client) end)::text, true);
  perform set_config('request.jwt.claim.sub', p_user, true);
end $$;
grant execute on function pg_temp.act_as(text, text) to authenticated;

-- the owner reads the summary
select pg_temp.act_as('00000000-0000-4000-8000-000000004801');
set local role authenticated;
create temp table s on commit drop as
  select r from jsonb_array_elements(public.business_receivables_summary_v1('00000000-0000-4000-8000-000000004810')->'rows') r;
grant select on s to authenticated;
select is((select r->>'to_collect_cents' from s where r->>'currency' = 'EUR'), '34200', 'the remainder of the part-paid invoice is still to collect');
select is((select r->>'declared_cents' from s where r->>'currency' = 'EUR'), '6000', 'a declared payment is awaiting confirmation, not collected');
select is((select r->>'received_unmatched_cents' from s where r->>'currency' = 'EUR'), '5000', 'a received, unmatched payment is its own state');
select is((select r->>'awaiting_cents' from s where r->>'currency' = 'EUR'), '1000', 'an amount awaiting approval is its own state');
select is((select r->>'refund_due_cents' from s where r->>'currency' = 'EUR'), '2500', 'a credit note is a refund due');
select is((select r->>'receivable_cents' from s where r->>'currency' = 'EUR'), '46200', 'the receivable is the four states, without the refund');
select is((select r->>'to_collect_cents' from s where r->>'currency' = 'GBP'), '24000', 'another currency is its own row');
select is((select count(*)::int from s), 2, 'two currencies, never added');
select is((select (r->>'invoices')::int from s where r->>'currency' = 'EUR'), 5, 'a voided or replaced invoice is not counted');

-- the detail agrees with the summary, beyond one page, with tied dates
create temp table p1 on commit drop as select public.business_receivables_page_v1('00000000-0000-4000-8000-000000004810', 'EUR', null, null, null, 2) j;
grant select on p1 to authenticated;
select is((select jsonb_array_length(j->'rows') from p1), 2, 'the first page holds its limit');
select ok((select j->'next' from p1) <> 'null'::jsonb, 'and names where the next starts');
select is((select count(*)::int from (
  select (r->>'invoice_id') from jsonb_array_elements(
    public.business_receivables_page_v1('00000000-0000-4000-8000-000000004810', 'EUR', null, null, null, 200)->'rows') r) z), 5,
  'the whole page holds the five invoices of the summary');
create temp table pages on commit drop as
  select 1 as n, public.business_receivables_page_v1('00000000-0000-4000-8000-000000004810', 'EUR', null, null, null, 2) j;
insert into pages select 2, public.business_receivables_page_v1('00000000-0000-4000-8000-000000004810', 'EUR', null,
  ((select j from pages where n = 1)->'next'->>'issued_at')::timestamptz,
  ((select j from pages where n = 1)->'next'->>'id')::uuid, 2);
insert into pages select 3, public.business_receivables_page_v1('00000000-0000-4000-8000-000000004810', 'EUR', null,
  ((select j from pages where n = 2)->'next'->>'issued_at')::timestamptz,
  ((select j from pages where n = 2)->'next'->>'id')::uuid, 2);
grant select on pages to authenticated;
select is((select count(distinct r->>'invoice_id')::int from pages, jsonb_array_elements(j->'rows') r), 5,
  'the pages reach every invoice once, none twice or missing, with tied dates');
select is((select (j->'next') from pages where n = 3), 'null'::jsonb, 'the last page has no continuation');
select is((select sum((r->>'still_due_cents')::bigint)::text from pages, jsonb_array_elements(j->'rows') r
            where r->>'state' = 'to_collect'), '34200', 'the detail sums to the summary');
select is((select count(*)::int from jsonb_array_elements(
  public.business_receivables_page_v1('00000000-0000-4000-8000-000000004810', 'EUR', 'declared')->'rows') r), 1, 'a state filters the detail');
select throws_ok($$select public.business_receivables_page_v1('00000000-0000-4000-8000-000000004810', 'EUR', 'nonsense')$$, '22023', 'unknown receivable state', 'an unknown state is refused');
reset role;

-- who may read
select pg_temp.act_as('00000000-0000-4000-8000-000000004802');
set local role authenticated;
select throws_ok($$select public.business_receivables_summary_v1('00000000-0000-4000-8000-000000004810')$$, '42501', 'business receivables are not available', 'an ordinary member is refused');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000004804');
set local role authenticated;
select throws_ok($$select public.business_receivables_page_v1('00000000-0000-4000-8000-000000004810', 'EUR')$$, '42501', 'business receivables are not available', 'a billed customer reads no book');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000004803');
set local role authenticated;
select throws_ok($$select public.business_receivables_summary_v1('00000000-0000-4000-8000-000000004810')$$, '42501', 'business receivables are not available', 'another business''s owner is refused');
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-000000004801', 'delegate');
set local role authenticated;
select throws_ok($$select public.business_receivables_summary_v1('00000000-0000-4000-8000-000000004810')$$, '42501', 'business receivables are not available', 'an assistant session is refused');
reset role;

select * from finish();
rollback;
