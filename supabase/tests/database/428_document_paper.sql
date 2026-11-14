-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3852 (0768) -- the paper a business's documents are printed on.
--
-- A country's row names its usual paper and the papers its documents may
-- use: Letter in the United States and Canada, A4 only in Switzerland, A4
-- and either elsewhere. A business follows its country unless it chooses
-- another paper the country allows; any other is refused in words, by every
-- door that writes the row. An invoice keeps the paper of its issue.
begin;
select plan(17);

create or replace function pg_temp.invoice(p_ws uuid, p_member uuid, p_number text, p_paper text default null)
returns uuid language plpgsql as $f$
declare v_id uuid;
begin
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature, paper)
  values (p_ws, p_member, p_member, p_number, 'November', '[]'::jsonb, 5000, 'EUR', 'Member',
          'Space', 'Member', 'sig', p_paper) returning id into v_id;
  return v_id;
end;
$f$;

create or replace function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  owner uuid := '00000000-0000-4000-8000-000000003852';
  fr uuid; us uuid; ch uuid; fr_owner uuid; us_owner uuid; ch_owner uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'paper-owner@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('PAPER-FR', 'FR', 'EUR', 'Europe/Paris', owner) returning id into fr;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('PAPER-US', 'US', 'USD', 'America/New_York', owner) returning id into us;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('PAPER-CH', 'CH', 'CHF', 'Europe/Zurich', owner) returning id into ch;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (fr, owner, true, true) returning id into fr_owner;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (us, owner, true, true) returning id into us_owner;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ch, owner, true, true) returning id into ch_owner;
  perform set_config('deskilo.test.fr', fr::text, false);
  perform set_config('deskilo.test.us', us::text, false);
  perform set_config('deskilo.test.ch', ch::text, false);
  perform set_config('deskilo.test.owner', owner::text, false);
  perform set_config('deskilo.test.fr_owner', fr_owner::text, false);
  perform set_config('deskilo.test.us_owner', us_owner::text, false);
  perform set_config('deskilo.test.ch_owner', ch_owner::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.id(p text) returns uuid language sql as $$
  select current_setting('deskilo.test.' || p)::uuid
$$;
create or replace function pg_temp.paper_of(p_invoice uuid) returns text language sql as $$
  select paper from public.invoices where id = p_invoice
$$;
grant execute on all functions in schema pg_temp to authenticated;

-- ── the country's row ──
select is(public.country_papers('US', current_date),
  '{"paper": "Letter", "papers": ["A4", "Letter"]}'::jsonb,
  'the United States print on Letter, and may print on A4');
select is(public.country_papers('CH', current_date),
  '{"paper": "A4", "papers": ["A4"]}'::jsonb,
  'Switzerland prints on A4 only');
select is(public.country_papers('FR', current_date),
  '{"paper": "A4", "papers": ["A4", "Letter"]}'::jsonb,
  'a row that names no paper: A4, and either may be chosen');
select is((select count(*)::int from public.tax_reference
            where domain = 'country' and key = 'catalogue' and country in ('CA', 'CH', 'US')
              and valid_to is null),
  3, 'the open row of each country carries its papers: no second version');
select is((select count(*)::int from public.tax_reference
            where domain = 'country' and key = 'catalogue'
              and not public.tax_reference_valid(domain, value)),
  0, 'every country row is valid');
select ok(public.tax_reference_valid('country',
            '{"currency": "USD", "time_zone": "America/New_York", "banking_scheme": "us", "paper": "Letter", "papers": ["Letter", "A4"]}'::jsonb)
      and not public.tax_reference_valid('country',
            '{"currency": "USD", "time_zone": "America/New_York", "banking_scheme": "us", "paper": "Legal"}'::jsonb)
      and not public.tax_reference_valid('country',
            '{"currency": "USD", "time_zone": "America/New_York", "banking_scheme": "us", "papers": []}'::jsonb)
      and not public.tax_reference_valid('country',
            '{"currency": "USD", "time_zone": "America/New_York", "banking_scheme": "us", "papers": ["A4", "A4"]}'::jsonb)
      and not public.tax_reference_valid('country',
            '{"currency": "USD", "time_zone": "America/New_York", "banking_scheme": "us", "paper": "Letter", "papers": ["A4"]}'::jsonb),
  'the shape of a row: a known paper, and a set of known papers that holds the usual one');

-- ── the business's paper ──
update public.workspaces set paper = 'Letter' where id = pg_temp.id('fr');
select is((select paper from public.workspaces where id = pg_temp.id('fr')), 'Letter',
  'a French business may print on Letter');
select throws_ok(format($$update public.workspaces set paper = 'Letter' where id = %L$$, pg_temp.id('ch')),
  '22023', 'documents of this country are not printed on Letter',
  'a Swiss business may not: its invoices end on a payment part printed on A4');
select throws_ok(format($$update public.workspaces set country_code = 'CH' where id = %L$$, pg_temp.id('fr')),
  '22023', 'documents of this country are not printed on Letter',
  'nor may a business on Letter move to a country that does not use it');

select pg_temp.act_as(pg_temp.id('owner'));
set local role authenticated;
select is((public.save_workspace_settings(pg_temp.id('fr'), null, '{"paper": ""}'::jsonb)
            #>> '{workspace,paper}'), null, 'the settings'' Save follows the country with an empty paper');
select is((public.save_workspace_settings(pg_temp.id('us'), null, '{"paper": "A4"}'::jsonb)
            #>> '{workspace,paper}'), 'A4', 'and keeps a paper the country allows');
select is((public.save_workspace_settings(pg_temp.id('us'), null, '{"address": "1 Main St"}'::jsonb)
            #>> '{workspace,paper}'), 'A4', 'a Save without the paper leaves it');
reset role;

-- ── the paper of an invoice ──
update public.workspaces set paper = null where id = pg_temp.id('us');
select is(pg_temp.paper_of(pg_temp.invoice(pg_temp.id('us'), pg_temp.id('us_owner'), 'P-1', 'A4')), 'Letter',
  'an American invoice is on Letter, whatever the insert carried');
update public.workspaces set paper = 'Letter' where id = pg_temp.id('fr');
select is(pg_temp.paper_of(pg_temp.invoice(pg_temp.id('fr'), pg_temp.id('fr_owner'), 'P-2')), 'Letter',
  'an invoice of a business that chose Letter is on Letter');
select is(pg_temp.paper_of(pg_temp.invoice(pg_temp.id('ch'), pg_temp.id('ch_owner'), 'P-3', 'Letter')), 'A4',
  'a Swiss invoice is on A4, never outside its country''s papers');
update public.workspaces set paper = 'A4' where id = pg_temp.id('fr');
select throws_ok(
  format($$update public.invoices set paper = 'A4' where number = 'P-2' and workspace_id = %L$$, pg_temp.id('fr')),
  'invoices are immutable',
  'an issued invoice keeps its paper when the business changes its own');

-- ── the configuration transfer ──
select is(public.export_workspace_configuration(pg_temp.id('fr')) #>> '{workspace,paper}', 'A4',
  'the configuration carries the paper');

select * from finish();
rollback;
