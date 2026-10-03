-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1924 — the first finance KPIs: invoiced and collected over whole
-- months, equal to the money report (workspace_status) to the cent, as
-- exact decimal strings; voided invoices and settlements left out, credit
-- notes named apart; collected by the month of the match on the
-- workspace clock; a currency mix is unavailable, the running month
-- partial; viewAnalytics AND viewFinances, the feature on, nobody else.
begin;
select plan(18);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-00000019240a';
  u_a uuid := '00000000-0000-4000-8000-00000019240b';
  u_m uuid := '00000000-0000-4000-8000-00000019240c';
  u_x uuid := '00000000-0000-4000-8000-00000019240d';
  ws uuid; ws2 uuid; m uuid; inv uuid; pay uuid; pay2 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'finkpi-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a, u_m, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Finance', 'FR', 'EUR', 'Europe/Paris', u_o) returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Elsewhere', 'FR', 'EUR', 'Europe/Paris', u_x) returning id into ws2;
  -- The admin role here reads analytics but not finances: the
  -- operational reader. The owner holds every right.
  update public.workspaces
     set feature_flags = coalesce(feature_flags, '{}'::jsonb)
                         || '{"invoicing": true, "workspaceStatus": true}',
         role_permissions = coalesce(role_permissions, '{}'::jsonb)
                            || '{"admin": ["viewAnalytics"]}'
   where id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true) returning id into m;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_a, false, true), (ws, u_m, false, false), (ws2, u_x, true, true);

  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title,
                               lines, total_cents, currency, member_name, workspace_name,
                               issuer_name, signature, period, kind)
  values (ws, m, m, 'F-1', 'May', '[]', 123456, 'EUR', 'M', 'Finance', 'M', 's', '2025-05', 'full')
  returning id into inv;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title,
                               lines, total_cents, currency, member_name, workspace_name,
                               issuer_name, signature, period, kind, voided_at)
  values (ws, m, m, 'F-2', 'Credit', '[]', -15000, 'EUR', 'M', 'Finance', 'M', 's', '2025-05', 'usage', null),
         (ws, m, m, 'F-3', 'Void', '[]', 99999, 'EUR', 'M', 'Finance', 'M', 's', '2025-05', 'subscription', now()),
         (ws, m, m, 'F-4', 'Settle', '[]', 77777, 'EUR', 'M', 'Finance', 'M', 's', '2025-05', 'settlement', null),
         (ws, m, m, 'F-5', 'June', '[]', 50000, 'EUR', 'M', 'Finance', 'M', 's', '2025-06', 'full', null),
         (ws, m, m, 'F-6', 'Dollars', '[]', 1000, 'USD', 'M', 'Finance', 'M', 's', '2025-08', 'full', null),
         (ws, m, m, 'F-7', 'Now', '[]', 1000, 'EUR', 'M', 'Finance', 'M', 's',
          to_char(now() at time zone 'Europe/Paris', 'YYYY-MM'), 'full', null);

  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (ws, m, 'credit', 'payment', 98765, 'bank transfer', '2025-05')
  returning id into pay;
  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (ws, m, 'credit', 'payment', 1000, 'bank transfer', '2025-05')
  returning id into pay2;
  -- 98 765 matched in May; 1 000 matched at 23:30 UTC on 31 May, which is
  -- already June on the workspace clock (Paris, UTC+2).
  insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id,
                                             amount_cents, resolution, matched_at)
  values (ws, inv, pay, 98765, 'exact', '2025-05-20 10:00+00'),
         (ws, inv, pay2, 1000, 'exact', '2025-05-31 23:30+00');

  perform set_config('fk.ws', ws::text, false);
  perform set_config('fk.owner', u_o::text, false);
  perform set_config('fk.admin', u_a::text, false);
  perform set_config('fk.member', u_m::text, false);
  perform set_config('fk.stranger', u_x::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    case when p_who = 'anonymous' then '{"role": "anon"}'
         else json_build_object('sub', current_setting('fk.' || p_who),
                                'role', 'authenticated')::text end, true);
end
$act$;

-- The summary as p_who, or the SQLSTATE that refused it.
create or replace function pg_temp.kpi(p_who text, p_from text, p_to text) returns jsonb
language plpgsql as $k$
begin
  perform pg_temp.act_as(p_who);
  return public.kpi_finance_summary(current_setting('fk.ws')::uuid, p_from, p_to);
exception when others then
  return jsonb_build_object('refused', sqlstate);
end
$k$;

select pg_temp.seed();

select is(pg_temp.kpi('owner', '2025-05', '2025-05') ->> 'invoiced_minor', '123456',
          'invoiced: positive totals, voided and settlement left out, as an exact string');
select is(pg_temp.kpi('owner', '2025-05', '2025-05') ->> 'credit_notes_minor', '15000',
          'credit notes are named apart, not netted');
select is(pg_temp.kpi('owner', '2025-05', '2025-05') ->> 'collected_minor', '98765',
          'collected: matched in May on the workspace clock');
select is(pg_temp.kpi('owner', '2025-06', '2025-06') ->> 'collected_minor', '1000',
          'a match at 23:30 UTC on 31 May is June in Paris');
select is(pg_temp.kpi('owner', '2025-05', '2025-06') ->> 'invoiced_minor', '173456',
          'a range of months adds whole months');

select pg_temp.act_as('owner');
select is((pg_temp.kpi('owner', '2025-05', '2025-05') ->> 'invoiced_minor')::bigint,
          (public.workspace_status(current_setting('fk.ws')::uuid, '2025-05', '2025-05')
             -> 'revenue' ->> 'invoiced_cents')::bigint,
          'invoiced equals the money report to the cent');
select is((pg_temp.kpi('owner', '2025-05', '2025-06') ->> 'collected_minor')::bigint,
          (public.workspace_status(current_setting('fk.ws')::uuid, '2025-05', '2025-06')
             -> 'payments' ->> 'matched_cents')::bigint,
          'collected equals the money report''s matched payments');

select is(pg_temp.kpi('owner', '2025-07', '2025-07') ->> 'invoiced_minor', '0',
          'a month with no invoice is a measured zero');
select is(pg_temp.kpi('owner', '2025-08', '2025-08') -> 'reasons', '["currency_mix"]'::jsonb,
          'another currency in the period is refused as a mix, not summed');
select ok((pg_temp.kpi('owner', to_char(now() at time zone 'Europe/Paris', 'YYYY-MM'),
                                to_char(now() at time zone 'Europe/Paris', 'YYYY-MM')) -> 'quality') ? 'partial',
          'the running month is partial');

select is(pg_temp.kpi('admin', '2025-05', '2025-05') ->> 'refused', '42501',
          'an analytics reader without viewFinances reads no amount');
select is(pg_temp.kpi('member', '2025-05', '2025-05') ->> 'refused', '42501',
          'nor does a member');
select is(pg_temp.kpi('stranger', '2025-05', '2025-05') ->> 'refused', '42501',
          'nor the owner of another workspace');
select is(pg_temp.kpi('anonymous', '2025-05', '2025-05') ->> 'refused', '42501',
          'nor anyone signed out');
select is(pg_temp.kpi('owner', '2025-13', '2025-13') ->> 'refused', '22023',
          'a manipulated month is refused');
select is(pg_temp.kpi('owner', '2023-01', '2025-01') ->> 'refused', '22023',
          'and so is a range beyond 24 months');

update public.workspaces set feature_flags = feature_flags || '{"workspaceStatus": false}'
 where id = current_setting('fk.ws')::uuid;
select is(pg_temp.kpi('owner', '2025-05', '2025-05') ->> 'refused', '42501',
          'with the feature off nothing is read');

select is(public.kpi_registry() -> 'finance.invoiced' -> 'permissions',
          '["viewAnalytics", "viewFinances"]'::jsonb,
          'the registry names both rights');

select * from finish();
rollback;
