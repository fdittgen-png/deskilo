-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4005 (0778) -- the head adds a house abroad. In the same currency the
-- priced rows keep their amounts, in another they are 0; either way they
-- arrive inactive and with no rate, the head's rate category kept as a hint.
-- Closure days stay with their country. The head's other owners are copied
-- once as co-owners and a later change in the head is not followed. A
-- non-owner of the head, the feature off and an assistant are refused; the
-- same request id answers the same house; every amount column of a carried
-- table is fenced. A head with a twin gives a house without one; the
-- head's document design and documents stay with it. Rolled back.
begin;
select plan(26);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  owner_a uuid := '00000000-0000-4000-8000-000000004010';
  co_b uuid := '00000000-0000-4000-8000-000000004011';
  late_c uuid := '00000000-0000-4000-8000-000000004012';
  stranger uuid := '00000000-0000-4000-8000-000000004013';
  head uuid; org uuid; std uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'house-' || right(u::text, 4) || '@deskilo.test', '', now(), now(), now()
    from unnest(array[owner_a, co_b, late_c, stranger]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, environment)
  values ('HOUSE-HEAD-PARIS', 'FR', 'EUR', 'Europe/Paris', owner_a, 'prod') returning id into head;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (head, owner_a, true, true, '2026-01-01');
  insert into public.members (workspace_id, user_id, is_admin, co_owner, joined_at)
  values (head, co_b, true, 'active', '2026-01-01');
  insert into public.vat_rates (workspace_id, label, percent, category, is_default, active)
  values (head, 'TVA 20 %', 20, 'S', true, true) returning id into std;
  insert into public.plans (workspace_id, name, base_fee_cents, included_half_days, overage_fee_cents, active)
  values (head, 'Resident', 25000, 40, 1500, true);
  insert into public.services (workspace_id, name, price_cents, active, vat_rate_id)
  values (head, 'Coffee', 250, true, std);
  insert into public.packages (workspace_id, name, days, price_cents, active, vat_rate_id)
  values (head, 'Ten days', 10, 18000, true, std);
  insert into public.closure_days (workspace_id, day, reason) values (head, '2026-07-14', 'Fête nationale');
  -- below 500.00 a request needs no validation
  insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, min_amount_cents)
  values (head, 'lease_change', 1, true, 50000);
  -- the head has a development twin, and a design and a document of its own
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, pair_id, environment)
  values ('HOUSE-HEAD-PARIS (dev)', 'FR', 'EUR', 'Europe/Paris', owner_a, '00000000-0000-4000-8000-0000000040cc', 'dev');
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  select id, owner_a, true, true, '2026-01-01' from public.workspaces where name = 'HOUSE-HEAD-PARIS (dev)';
  update public.workspaces set pair_id = '00000000-0000-4000-8000-0000000040cc',
         invoice_pdf_template = '{"footer": "Atelier SAS - SIRET 123 456 789 00012"}'::jsonb
   where id = head;
  insert into public.workspace_documents (workspace_id, title, category, url)
  values (head, 'Statuts', 'statutes', 'https://example.org/statuts.pdf');
  insert into public.organisations (name, head_workspace_id) values ('Atelier group', head) returning id into org;
  update public.workspaces set organisation_id = org where id = head;
  perform set_config('deskilo.test.head', head::text, false);
  perform set_config('deskilo.test.org', org::text, false);
  perform set_config('deskilo.test.owner_a', owner_a::text, false);
  perform set_config('deskilo.test.co_b', co_b::text, false);
  perform set_config('deskilo.test.late_c', late_c::text, false);
  perform set_config('deskilo.test.stranger', stranger::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.id(p text) returns uuid language sql as $$
  select current_setting('deskilo.test.' || p)::uuid
$$;
create or replace function pg_temp.as_user(p text, p_assistant boolean default false) returns void language sql as $$
  select set_config('request.jwt.claims',
    (jsonb_build_object('sub', current_setting('deskilo.test.' || p), 'role', 'authenticated')
       || case when p_assistant then '{"client_id": "an-assistant"}'::jsonb else '{}'::jsonb end)::text, true)
$$;
create or replace function pg_temp.house(p_name text) returns uuid language sql as $$
  select id from public.workspaces where name = p_name and environment = 'prod'
$$;
grant execute on all functions in schema pg_temp to authenticated;

-- ── a house in Italy, the same currency ──
select pg_temp.as_user('owner_a');
set local role authenticated;
select set_config('deskilo.test.milan', (public.create_organisation_house_once(pg_temp.id('org'), 'HOUSE-MILAN',
  'IT', 'EUR', 'Europe/Rome', 'it', '00000000-0000-4000-8000-0000000040e1') ->> 'workspace_id'), false);
reset role;
select is((select organisation_id from public.workspaces where id = pg_temp.id('milan')), pg_temp.id('org'),
  'the house is placed in the organisation');
select is((select (country_code, currency_code, default_locale)::text from public.workspaces where id = pg_temp.id('milan')),
  '(IT,EUR,it)', 'with its country, currency and language');
select is((select (base_fee_cents, overage_fee_cents, active)::text from public.plans
            where workspace_id = pg_temp.id('milan') and name = 'Resident'),
  '(25000,1500,f)', 'in the same currency a plan keeps its amounts and arrives inactive');
select is((select (price_cents, active, vat_rate_id is null)::text from public.services
            where workspace_id = pg_temp.id('milan') and name = 'Coffee'),
  '(250,f,t)', 'a service arrives inactive with no rate');
select is((select carried -> 'rate_hints' ->> 'services:Coffee' from public.organisation_houses
            where workspace_id = pg_temp.id('milan')),
  'S', 'the head''s rate category is kept as a hint');
select is((select count(*)::int from public.closure_days where workspace_id = pg_temp.id('milan')), 0,
  'the public holidays of France stay in France');
select is((select prices_pending from public.organisation_houses where workspace_id = pg_temp.id('milan')), true,
  'its prices are still to be named');
select is((select (is_owner or co_owner = 'active') from public.members
            where workspace_id = pg_temp.id('milan') and user_id = pg_temp.id('co_b')),
  true, 'the head''s co-owner is a co-owner of the house');

select is((select pair_id is null and (select count(*) from public.workspaces x where x.name = 'HOUSE-MILAN') = 1
             from public.workspaces where id = pg_temp.id('milan')), true,
  'a head with a twin: the house has none');
select is((select (position('SIRET' in w.invoice_pdf_template::text) = 0, h.carried ->> 'document_design')::text
             from public.workspaces w join public.organisation_houses h on h.workspace_id = w.id
            where w.id = pg_temp.id('milan')),
  '(t,"not carried")', 'the head''s document design stays with the head');
select is((select count(*)::int from public.workspace_documents where workspace_id = pg_temp.id('milan')), 0,
  'and so do its documents');

-- the same request answers the same house
select pg_temp.as_user('owner_a');
set local role authenticated;
select is((public.create_organisation_house_once(pg_temp.id('org'), 'HOUSE-MILAN', 'IT', 'EUR', 'Europe/Rome', 'it',
  '00000000-0000-4000-8000-0000000040e1') ->> 'workspace_id')::uuid, pg_temp.id('milan'),
  'the same request id answers the same house');
reset role;

-- a later owner of the head is not followed
insert into public.members (workspace_id, user_id, is_admin, co_owner, joined_at)
values (pg_temp.id('head'), pg_temp.id('late_c'), true, 'active', '2026-02-01');
select is((select count(*)::int from public.members
            where workspace_id = pg_temp.id('milan') and user_id = pg_temp.id('late_c')), 0,
  'a later change in the head does not follow into the house');

-- ── a house in London, another currency ──
select pg_temp.as_user('owner_a');
set local role authenticated;
select set_config('deskilo.test.london', (public.create_organisation_house_once(pg_temp.id('org'), 'HOUSE-LONDON',
  'GB', 'GBP', 'Europe/London', 'en', '00000000-0000-4000-8000-0000000040e2') ->> 'workspace_id'), false);
reset role;
select is((select (base_fee_cents, overage_fee_cents, active)::text from public.plans
            where workspace_id = pg_temp.id('london') and name = 'Resident'),
  '(0,0,f)', 'in another currency a plan''s fees are 0');
select is((select (price_cents, active)::text from public.packages
            where workspace_id = pg_temp.id('london') and name = 'Ten days'),
  '(0,f)', 'and a package''s price');
select is((select carried ->> 'amounts_kept' from public.organisation_houses where workspace_id = pg_temp.id('london')),
  'false', 'the birth record says the amounts were not kept');

select is((select (count(*) > 0 and bool_and(min_amount_cents = 50000)) from public.validation_policies
            where workspace_id = pg_temp.id('milan')), true,
  'in the same currency a validation threshold travels as it is');
select is((select (count(*) > 0 and bool_and(min_amount_cents = 0)) from public.validation_policies
            where workspace_id = pg_temp.id('london')), true,
  'in another currency it is 0: every amount asks');

-- ── who is refused ──
select pg_temp.as_user('stranger');
set local role authenticated;
select throws_ok(format('select public.create_organisation_house_once(%L, %L, %L, %L, %L, %L, %L)',
    pg_temp.id('org'), 'HOUSE-X', 'DE', 'EUR', 'Europe/Berlin', 'de', gen_random_uuid()),
  '42501', 'only an owner of this business may do this', 'someone who does not own the head adds no house');
reset role;
select pg_temp.as_user('owner_a', true);
set local role authenticated;
select throws_ok(format('select public.create_organisation_house_once(%L, %L, %L, %L, %L, %L, %L)',
    pg_temp.id('org'), 'HOUSE-X', 'DE', 'EUR', 'Europe/Berlin', 'de', gen_random_uuid()),
  '42501', 'only an owner of this business may do this', 'nor does an assistant''s token');
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"organisation": false}'::jsonb
 where id = pg_temp.id('head');
select pg_temp.as_user('owner_a');
set local role authenticated;
select throws_ok(format('select public.create_organisation_house_once(%L, %L, %L, %L, %L, %L, %L)',
    pg_temp.id('org'), 'HOUSE-X', 'DE', 'EUR', 'Europe/Berlin', 'de', gen_random_uuid()),
  '55000', 'the organisation is off in this business', 'nor with the organisation off in the head');

reset role;
update public.workspaces set feature_flags = feature_flags || '{"organisation": true}'::jsonb
 where id = pg_temp.id('head');
-- a request id already used for another business answers no house
select pg_temp.as_user('owner_a');
set local role authenticated;
select public.create_workspace_once('00000000-0000-4000-8000-0000000040e3', 'HOUSE-PLAIN', 'DE', 'EUR',
  'Europe/Berlin', 'prod', false, null, null);
select throws_ok(format('select public.create_organisation_house_once(%L, %L, %L, %L, %L, %L, %L)',
    pg_temp.id('org'), 'HOUSE-Y', 'DE', 'EUR', 'Europe/Berlin', 'de', '00000000-0000-4000-8000-0000000040e3'),
  '22023', 'this request id already created another business',
  'a request id used for another business is refused');

select throws_ok(format('select public.create_organisation_house_once(%L, %L, %L, %L, %L, %L, %L)',
    pg_temp.id('org'), 'HOUSE-Z', 'DE', 'EUR', 'Europe/Berlin', 'xx', gen_random_uuid()),
  '22023', 'the language is one of en, fr, de, es, it', 'a language the documents do not speak is refused');

-- ── the prices are named ──
select lives_ok(format('select public.clear_house_prices_pending(%L)', pg_temp.id('milan')),
  'the owner closes the price step');
select lives_ok(format('select public.clear_house_prices_pending(%L)', pg_temp.id('milan')),
  'and closing it twice is no error');
reset role;

-- ── every amount of a carried table is fenced ──
select is((select coalesce(string_agg(c.table_name || '.' || c.column_name, ', ' order by c.table_name, c.column_name), '')
             from information_schema.columns c
            where c.table_schema = 'public'
              and c.table_name in (select jsonb_object_keys(public.organisation_house_fenced_amounts()))
              and c.column_name ~ '(cents|amount|price|fee)'
              and not (public.organisation_house_fenced_amounts() -> c.table_name) ? c.column_name),
  '', 'every amount column of a carried table is in the fenced list');

select * from finish();
rollback;
