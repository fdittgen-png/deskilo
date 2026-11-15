-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4007 (0780) -- the houses of an organisation side by side. The owner of
-- a house in euros and one in Swiss francs reads both, each in its own
-- currency, with one total per currency and none across them; the figures
-- equal the house's own analysis; a development twin is no house of its
-- own. A person with the analysis rights in one house reads its figures
-- and the other named without them. Someone outside and an assistant are
-- refused; the organisation switched off in the head changes nothing for
-- reading. Rolled back.
begin;
select plan(17);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  owner_o uuid := '00000000-0000-4000-8000-000000004070';
  reader_r uuid := '00000000-0000-4000-8000-000000004071';
  outsider_x uuid := '00000000-0000-4000-8000-000000004072';
  paris uuid; zurich uuid; twin uuid; org uuid; m_p uuid; m_z uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'overview-' || right(u::text, 4) || '@deskilo.test', '', now(), now(), now()
    from unnest(array[owner_o, reader_r, outsider_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, environment)
  values ('OVERVIEW-PARIS', 'FR', 'EUR', 'Europe/Paris', owner_o, 'prod') returning id into paris;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, environment)
  values ('OVERVIEW-ZURICH', 'CH', 'CHF', 'Europe/Zurich', owner_o, 'prod') returning id into zurich;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, environment, pair_id)
  values ('OVERVIEW-PARIS (dev)', 'FR', 'EUR', 'Europe/Paris', owner_o, 'dev',
          '00000000-0000-4000-8000-0000000040d1') returning id into twin;
  update public.workspaces set pair_id = '00000000-0000-4000-8000-0000000040d1' where id = paris;
  -- the analysis on in both; in Paris an admin reads the analysis but not the finances
  update public.workspaces
     set feature_flags = coalesce(feature_flags, '{}'::jsonb)
           || '{"invoicing": true, "workspaceStatus": true, "workspaceOverview": true, "organisation": true}',
         role_permissions = coalesce(role_permissions, '{}'::jsonb) || '{"admin": ["viewAnalytics", "accessProd"]}'
   where id in (paris, zurich, twin);
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (paris, owner_o, true, true, '2025-01-01') returning id into m_p;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (zurich, owner_o, true, true, '2025-01-01') returning id into m_z;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (paris, reader_r, false, true, '2025-01-01'),
         (zurich, reader_r, true, true, '2025-01-01');
  -- the twin has the same people (mirrored, or here when not yet)
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (twin, owner_o, true, true, '2025-01-01') on conflict do nothing;
  insert into public.organisations (name, head_workspace_id) values ('Overview group', paris) returning id into org;
  update public.workspaces set organisation_id = org where id in (paris, zurich, twin);

  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, period, kind)
  values (paris, m_p, m_p, 'OV-P1', 'May', '[]', 120000, 'EUR', 'M', 'Paris', 'M', 's', '2025-05', 'full'),
         (paris, m_p, m_p, 'OV-P2', 'May', '[]', 30000, 'EUR', 'M', 'Paris', 'M', 's', '2025-05', 'usage'),
         (zurich, m_z, m_z, 'OV-Z1', 'May', '[]', 90000, 'CHF', 'M', 'Zurich', 'M', 's', '2025-05', 'full');
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, period, kind)
  select twin, m.id, m.id, 'OV-T1', 'May', '[]', 777, 'EUR', 'M', 'Paris dev', 'M', 's', '2025-05', 'full'
    from public.members m where m.workspace_id = twin and m.user_id = owner_o;
  perform set_config('deskilo.ov.org', org::text, false);
  perform set_config('deskilo.ov.paris', paris::text, false);
  perform set_config('deskilo.ov.zurich', zurich::text, false);
  perform set_config('deskilo.ov.owner', owner_o::text, false);
  perform set_config('deskilo.ov.reader', reader_r::text, false);
  perform set_config('deskilo.ov.outsider', outsider_x::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.id(p text) returns uuid language sql as $$
  select current_setting('deskilo.ov.' || p)::uuid
$$;
create or replace function pg_temp.as_user(p text, p_assistant boolean default false) returns void language sql as $$
  select set_config('request.jwt.claims',
    (jsonb_build_object('sub', current_setting('deskilo.ov.' || p), 'role', 'authenticated')
       || case when p_assistant then '{"client_id": "an-assistant"}'::jsonb else '{}'::jsonb end)::text, true)
$$;
create or replace function pg_temp.house(p_view jsonb, p_name text) returns jsonb language sql as $$
  select h from jsonb_array_elements(p_view->'houses') h where h->>'name' = p_name
$$;
grant execute on all functions in schema pg_temp to authenticated;

-- ── the owner of both ──
select pg_temp.as_user('owner');
set local role authenticated;
select set_config('deskilo.ov.view', public.organisation_overview_v1(pg_temp.id('org'), '2025-05', '2025-05')::text, false);
select set_config('deskilo.ov.paris_own', public.kpi_finance_summary(pg_temp.id('paris'), '2025-05', '2025-05')::text, false);
select set_config('deskilo.ov.paris_overdue', public.kpi_overdue_receivables(pg_temp.id('paris'), '2025-05', '2025-05')::text, false);
reset role;
select is((select string_agg(h->>'name' || ':' || (h->>'currency'), ',' order by ord)
             from jsonb_array_elements(current_setting('deskilo.ov.view')::jsonb->'houses') with ordinality x(h, ord)),
  'OVERVIEW-PARIS:EUR,OVERVIEW-ZURICH:CHF', 'the owner reads both houses, the head first, each in its currency');
select is((pg_temp.house(current_setting('deskilo.ov.view')::jsonb, 'OVERVIEW-PARIS')->'figures'->'invoiced'->>'minor'),
  '150000', 'Paris invoiced 1,500.00 euros in May');
select is((pg_temp.house(current_setting('deskilo.ov.view')::jsonb, 'OVERVIEW-PARIS')->'figures'->'invoiced'->>'minor'),
  current_setting('deskilo.ov.paris_own')::jsonb->>'invoiced_minor', 'the same figure as the house''s own analysis');
select is((select (f->'collected'->>'minor', f->'overdue'->>'minor')::text
             from (select pg_temp.house(current_setting('deskilo.ov.view')::jsonb, 'OVERVIEW-PARIS')->'figures' f) x),
  (current_setting('deskilo.ov.paris_own')::jsonb->>'collected_minor',
   current_setting('deskilo.ov.paris_overdue')::jsonb->>'value')::text,
  'so are what it collected and what is overdue');
select is((select (f->'invoiced'->>'kind', f->'invoiced'->>'from', f->'overdue'->>'kind', f->'overdue' ? 'as_of')::text
             from (select pg_temp.house(current_setting('deskilo.ov.view')::jsonb, 'OVERVIEW-PARIS')->'figures' f) x),
  '(period,2025-05,state,t)', 'each figure says whether it is a period figure or a state as of a time');
select is((pg_temp.house(current_setting('deskilo.ov.view')::jsonb, 'OVERVIEW-ZURICH')->'figures'->'invoiced'->>'minor'),
  '90000', 'Zurich invoiced 900.00 francs');
select is((select string_agg((t->>'currency') || '=' || (t->'invoiced'->>'minor'), ',' order by t->>'currency')
             from jsonb_array_elements(current_setting('deskilo.ov.view')::jsonb->'totals') t),
  'CHF=90000,EUR=150000', 'one total per currency, nothing converted');
select is((select (jsonb_typeof(f->'invoiced'->'minor'), jsonb_typeof(f->'collected'->'minor'), jsonb_typeof(f->'overdue'->'minor'))::text
             from (select pg_temp.house(current_setting('deskilo.ov.view')::jsonb, 'OVERVIEW-PARIS')->'figures' f) x),
  '(number,number,number)', 'a house''s amounts are numbers');
select is((select (jsonb_typeof(t->'invoiced'->'minor'), jsonb_typeof(t->'collected'->'minor'), jsonb_typeof(t->'overdue'->'minor'),
                   t->'overdue'->>'kind', t->'overdue' ? 'as_of')::text
             from jsonb_array_elements(current_setting('deskilo.ov.view')::jsonb->'totals') t where t->>'currency' = 'EUR'),
  '(number,number,number,state,t)', 'so are a total''s, and its overdue says as of when');
select is((select count(*)::int from jsonb_object_keys(current_setting('deskilo.ov.view')::jsonb) k
            where k ~ '(invoiced|collected|overdue|total_minor)'), 0,
  'and no sum across currencies');
select is((select count(*)::int from jsonb_array_elements(current_setting('deskilo.ov.view')::jsonb->'houses') h
            where h->>'name' like '%(dev)%'), 0, 'a development twin is no house of its own');

-- ── a person who reads the finances of Zurich only ──
select pg_temp.as_user('reader');
set local role authenticated;
select set_config('deskilo.ov.rview', public.organisation_overview_v1(pg_temp.id('org'), '2025-05', '2025-05')::text, false);
reset role;
select is((pg_temp.house(current_setting('deskilo.ov.rview')::jsonb, 'OVERVIEW-PARIS') - 'workspace_id' - 'zone' - 'country' - 'is_head')::text,
  '{"name": "OVERVIEW-PARIS", "figures": null, "currency": "EUR", "withheld": "not_permitted"}',
  'a house whose finances they may not read is named without figures, and says why');
select is((pg_temp.house(current_setting('deskilo.ov.rview')::jsonb, 'OVERVIEW-ZURICH')->'figures'->'invoiced'->>'minor'),
  '90000', 'the house they may read gives its figures');
select is((select (t->>'incomplete') from jsonb_array_elements(current_setting('deskilo.ov.rview')::jsonb->'totals') t
            where t->>'currency' = 'EUR'), 'true', 'a total missing a house says it is incomplete');

-- ── who is refused ──
select pg_temp.as_user('outsider');
set local role authenticated;
select throws_ok(format('select public.organisation_overview_v1(%L, %L, %L)', pg_temp.id('org'), '2025-05', '2025-05'),
  '42501', 'only a member of a business of this organisation reads it', 'someone outside reads nothing');
reset role;
select pg_temp.as_user('owner', true);
set local role authenticated;
select throws_ok(format('select public.organisation_overview_v1(%L, %L, %L)', pg_temp.id('org'), '2025-05', '2025-05'),
  '42501', 'only a person reads an organisation''s figures', 'nor does an assistant''s token');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"organisation": false}'::jsonb where id = pg_temp.id('paris');
select pg_temp.as_user('owner');
set local role authenticated;
select lives_ok(format('select public.organisation_overview_v1(%L, %L, %L)', pg_temp.id('org'), '2025-05', '2025-05'),
  'with the organisation off in the head a member still reads it: the switch gates changes, not reading');
reset role;

select * from finish();
rollback;
