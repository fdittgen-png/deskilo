-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3659 (0736): "overdue" is the issuing business's day, not the device's.
-- my_finance_overview answers each invoice's business time zone, so a
-- person with invoices from Zurich and from Los Angeles reads each against
-- its own business's calendar; the rows, their order and their other fields
-- are what 0380 answered. Rolled back.
begin;
select plan(4);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000036590a1';
  u_m uuid := '00000000-0000-4000-8000-0000036590a2';
  ws_z uuid; ws_l uuid; m_oz uuid; m_ol uuid; m_z uuid; m_l uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'zone-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Zurich space', 'CH', 'CHF', 'Europe/Zurich', u_o, '{"moneyTab": true, "invoicing": true}'::jsonb)
  returning id into ws_z;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Los Angeles space', 'US', 'USD', 'America/Los_Angeles', u_o, '{"moneyTab": true, "invoicing": true}'::jsonb)
  returning id into ws_l;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws_z, u_o, true, true, 'active', '2026-01-01'), (ws_z, u_m, false, false, 'active', '2026-01-01'),
         (ws_l, u_o, true, true, 'active', '2026-01-01'), (ws_l, u_m, false, false, 'active', '2026-01-01');
  select id into m_oz from public.members where workspace_id = ws_z and user_id = u_o;
  select id into m_ol from public.members where workspace_id = ws_l and user_id = u_o;
  select id into m_z from public.members where workspace_id = ws_z and user_id = u_m;
  select id into m_l from public.members where workspace_id = ws_l and user_id = u_m;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  values (ws_z, m_z, m_oz, 'ZH-1', 'Zurich', '[]'::jsonb, 10000, 'CHF', 'Member', 'Zurich space', 'Owner', 'sig'),
         (ws_l, m_l, m_ol, 'LA-1', 'Los Angeles', '[]'::jsonb, 10000, 'USD', 'Member', 'Los Angeles space', 'Owner', 'sig');
  perform set_config('t.u', u_m::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.overview() returns jsonb language plpgsql as $f$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('t.u'), 'role', 'authenticated')::text, true);
  set local role authenticated;
  v := public.my_finance_overview();
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
create temporary table zone_overview on commit drop as select pg_temp.overview() as v;

select is((select count(*)::int from zone_overview, jsonb_array_elements(v -> 'invoices')), 2,
  'the member reads both invoices, one from each business');
select is((select e ->> 'workspace_timezone' from zone_overview, jsonb_array_elements(v -> 'invoices') e
            where e ->> 'number' = 'ZH-1'), 'Europe/Zurich',
  'the Zurich invoice answers its business''s time zone');
select is((select e ->> 'workspace_timezone' from zone_overview, jsonb_array_elements(v -> 'invoices') e
            where e ->> 'number' = 'LA-1'), 'America/Los_Angeles',
  'the Los Angeles invoice answers its own, not the other business''s');
select is((select e ->> 'currency' from zone_overview, jsonb_array_elements(v -> 'invoices') e
            where e ->> 'number' = 'LA-1'), 'USD',
  'the other fields are what they were');

select * from finish();
rollback;
