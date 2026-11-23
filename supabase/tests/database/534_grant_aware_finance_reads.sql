-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4164 B1: the customer's own reads recognise a billing-access grant. The v2 overview and activity list the granted
-- subjects' invoices, each with its subject and the way it is reached, two subjects of one seller apart; the v1
-- readers (an older app) list none of them; a granted subject is not an acting member, so its payment state is
-- unavailable; a member keeps reading their own rows only; discovery lists the granted seller as a billing source;
-- a revoked grant is read nowhere. Rolled back.
begin;
select plan(11);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000041641a1';
  u_m uuid := '00000000-0000-4000-8000-0000041641a2';
  u_c uuid := '00000000-0000-4000-8000-0000041641a3';
  ws uuid; m_o uuid; m_m uuid; s1 uuid; s2 uuid;
  d date;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'grant-read-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m, u_c]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Grant reads', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "billingCustomers": true, "standaloneInvoicing": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_m, false, false, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_m from public.members where workspace_id = ws and user_id = u_m;
  insert into public.members (workspace_id, user_id, is_admin, status, origin, subscription_pct, overage_policy)
  values (ws, null, false, 'customer', 'delegated', 0, 'blocked') returning id into s1;
  insert into public.members (workspace_id, user_id, is_admin, status, origin, subscription_pct, overage_policy)
  values (ws, null, false, 'customer', 'delegated', 0, 'blocked') returning id into s2;
  insert into public.billing_parties (member_id, workspace_id, first_name, last_name) values (s1, ws, 'Clara', 'Client');
  insert into public.billing_parties (member_id, workspace_id, company) values (s2, ws, 'Client SARL');
  d := public.workspace_today(ws);
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                               member_name, workspace_name, issuer_name, signature, period, issued_at, kind,
                               source, service_date, due_on)
  values (ws, s1, m_o, 'GV-S1', 'S1', '[]'::jsonb, 1000, 'EUR', 'Clara Client', 'Grant reads', 'Owner', 'sig', null, d - 3, 'full', 'standalone', d - 3, d + 10),
         (ws, s2, m_o, 'GV-S2', 'S2', '[]'::jsonb, 2000, 'EUR', 'Client SARL', 'Grant reads', 'Owner', 'sig', null, d - 3, 'full', 'standalone', d - 3, d + 10),
         (ws, m_m, m_o, 'GV-M1', 'M1', '[]'::jsonb, 500, 'EUR', 'Mia', 'Grant reads', 'Owner', 'sig', '2026-10', '2026-10-01', 'full', 'monthly', null, null);
  -- Two accepted grants of the same account, as 0910's accept leaves them.
  insert into public.billing_access_grants (workspace_id, financial_subject_id, request_id, invited_by, principal_user_id, accepted_at)
  values (ws, s1, '00000000-0000-4000-8000-00000416b001', m_o, u_c, now()),
         (ws, s2, '00000000-0000-4000-8000-00000416b002', m_o, u_c, now());
  perform set_config('t.ws', ws::text, true);
  perform set_config('t.s1', s1::text, true);
  perform set_config('t.s2', s2::text, true);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.act(p_user text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000041641' || p_user, 'role', 'authenticated')::text, true);
end $$;
create or replace function pg_temp.numbers(p jsonb) returns text language sql as
  $$ select string_agg(x ->> 'number', ',' order by x ->> 'number') from jsonb_array_elements(p) x $$;
grant execute on all functions in schema pg_temp to authenticated;

select pg_temp.act('a3');
set local role authenticated;
select is(pg_temp.numbers(public.my_finance_overview_v2() -> 'invoices'), 'GV-S1,GV-S2',
  'the v2 overview lists both granted subjects'' invoices, and not the member''s');
select is((select count(distinct x ->> 'financial_subject_id')::int
             from jsonb_array_elements(public.my_finance_overview_v2() -> 'invoices') x), 2,
  'each with its own subject: two debtors of one seller stay apart');
select is((select string_agg(distinct x ->> 'access', ',')
             from jsonb_array_elements(public.my_finance_overview_v2() -> 'invoices') x), 'billing_grant',
  'reached through the grant');
select is((select string_agg(distinct x ->> 'claim_payment_state', ',')
             from jsonb_array_elements(public.my_finance_overview_v2() -> 'invoices') x), 'unavailable',
  'not an acting member: its payment is unavailable until the commands accept the grant');
select is(jsonb_array_length(public.my_finance_overview() -> 'invoices'), 0,
  'the v1 overview (an older app) lists none of them');
select is(jsonb_array_length(public.my_financial_activity_v2('invoices')), 2, 'the v2 activity lists both');
select is(jsonb_array_length(public.my_financial_activity('invoices')), 0, 'the v1 activity lists none');
select is((select count(*)::int from jsonb_array_elements(public.my_personal_workspace_refs_v1() -> 'billing_sources') x
            where x ->> 'workspace_id' = current_setting('t.ws')), 2,
  'discovery names the seller once per granted subject');

select pg_temp.act('a2');
select is(pg_temp.numbers(public.my_finance_overview_v2() -> 'invoices'), 'GV-M1',
  'a member reads their own invoice only');
select is((select x ->> 'access' from jsonb_array_elements(public.my_finance_overview_v2() -> 'invoices') x), 'member',
  'reached as a member');

reset role;
update public.billing_access_grants set revoked_at = now(), revoked_by_user_id = '00000000-0000-4000-8000-0000041641a1'
 where financial_subject_id = current_setting('t.s1')::uuid;
select pg_temp.act('a3');
set local role authenticated;
select is(pg_temp.numbers(public.my_finance_overview_v2() -> 'invoices'), 'GV-S2', 'a revoked grant is read nowhere');
reset role;

select * from finish();
rollback;
