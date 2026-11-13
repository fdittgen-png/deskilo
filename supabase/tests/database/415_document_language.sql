-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3850 (0753) -- an invoice's language is frozen at issue by the server.
--
-- The language a subdivision of the seller requires (French in Quebec), else
-- the customer's where the country's `document_language` row allows it, else
-- the business's document language (its own, else the country's first shipped
-- language, else English). The format locale pairs it with the seller's
-- country. The caller never chooses either, and neither changes afterwards.
-- Saving the business's language confirms the one 0753 gave it.
begin;
select plan(12);

create or replace function pg_temp.invoice(p_ws uuid, p_member uuid, p_number text, p_language text default null)
returns uuid language plpgsql as $f$
declare v_id uuid;
begin
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature, document_language)
  values (p_ws, p_member, p_member, p_number, 'November', '[]'::jsonb, 5000, 'EUR', 'Member',
          'Space', 'Member', 'sig', p_language) returning id into v_id;
  return v_id;
end;
$f$;

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  owner uuid := '00000000-0000-4000-8000-000000000415';
  customer uuid := '00000000-0000-4000-8000-000000000416';
  fr uuid; ch uuid; qc uuid; pl uuid;
  fr_owner uuid; fr_customer uuid; ch_owner uuid; ch_customer uuid;
  qc_owner uuid; qc_customer uuid; pl_owner uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'doc-owner@deskilo.test', '', now(), now(), now()),
         (customer, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'doc-customer@deskilo.test', '', now(), now(), now());
  -- The customer's document language is their own preference (0098).
  insert into public.profiles (id, preferred_locale) values (customer, 'de')
  on conflict (id) do update set preferred_locale = excluded.preferred_locale;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('DOC-FR', 'FR', 'EUR', 'Europe/Paris', owner) returning id into fr;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, default_locale)
  values ('DOC-CH', 'CH', 'CHF', 'Europe/Zurich', owner, 'it') returning id into ch;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, default_locale, invoice_legal)
  values ('DOC-QC', 'CA', 'CAD', 'America/Toronto', owner, 'en', '{"subdivision": "CA-QC"}'::jsonb) returning id into qc;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('DOC-PL', 'PL', 'PLN', 'Europe/Warsaw', owner) returning id into pl;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (fr, owner, true, true) returning id into fr_owner;
  insert into public.members (workspace_id, user_id) values (fr, customer) returning id into fr_customer;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ch, owner, true, true) returning id into ch_owner;
  insert into public.members (workspace_id, user_id) values (ch, customer) returning id into ch_customer;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (qc, owner, true, true) returning id into qc_owner;
  insert into public.members (workspace_id, user_id) values (qc, customer) returning id into qc_customer;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (pl, owner, true, true) returning id into pl_owner;
  perform set_config('deskilo.test.fr_customer', pg_temp.invoice(fr, fr_customer, 'F-1')::text, false);
  perform set_config('deskilo.test.fr_owner', pg_temp.invoice(fr, fr_owner, 'F-2', 'es')::text, false);
  perform set_config('deskilo.test.ch_customer', pg_temp.invoice(ch, ch_customer, 'F-3')::text, false);
  perform set_config('deskilo.test.qc_customer', pg_temp.invoice(qc, qc_customer, 'F-4')::text, false);
  perform set_config('deskilo.test.pl_owner', pg_temp.invoice(pl, pl_owner, 'F-5')::text, false);
  perform set_config('deskilo.test.ch', ch::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.frozen(p text) returns text language sql as $$
  select document_language || ' ' || format_locale from public.invoices
   where id = current_setting('deskilo.test.' || p)::uuid
$$;

select is((select count(*)::int from public.tax_reference
            where domain = 'document_language' and key = 'document'
              and public.tax_reference_valid(domain, value)),
  32, 'every country of the catalogue has a valid document_language row');

select ok(not public.tax_reference_valid('document_language', '{"languages": ["fr"]}'::jsonb)
      and not public.tax_reference_valid('document_language', '{"languages": [], "customer_language": true}'::jsonb)
      and not public.tax_reference_valid('document_language', '{"languages": ["FR"], "customer_language": true}'::jsonb)
      and not public.tax_reference_valid('document_language',
            '{"languages": ["en"], "customer_language": false, "required_by_subdivision": {"QC": "French"}}'::jsonb)
      and public.tax_reference_valid('document_language',
            '{"languages": ["en", "fr"], "customer_language": false, "required_by_subdivision": {"QC": "fr"}}'::jsonb),
  'the shape of a row: languages, whether the customer''s is allowed, a subdivision''s required language');

select is(pg_temp.frozen('fr_customer'), 'de de_FR',
  'France allows the customer''s language: a German-speaking customer''s invoice is in German, French formats region');

select is(pg_temp.frozen('fr_owner'), 'fr fr_FR',
  'a customer with no language gets the business''s (the country''s first), whatever the caller named');

select is(pg_temp.frozen('ch_customer'), 'it it_CH',
  'Switzerland names no customer-language rule: the business''s own document language');

select is(pg_temp.frozen('qc_customer'), 'fr fr_CA',
  'Quebec requires French, over the customer''s German and the business''s English');

select is(pg_temp.frozen('pl_owner'), 'en en_PL',
  'a country whose languages the app does not ship falls back to English');

select throws_ok(
  format($$update public.invoices set document_language = 'en' where id = %L$$,
         current_setting('deskilo.test.fr_customer')),
  'invoices are immutable',
  'an issued invoice''s language never changes');

select is(public.business_document_language('', 'BE', current_date), 'fr',
  'Belgium''s first shipped language is French (Dutch is not shipped)');

select is(public.business_document_language('', 'LU', current_date), 'fr',
  'Luxembourg''s first shipped language is French');

update public.workspaces set document_language_confirmed = false
 where id = current_setting('deskilo.test.ch')::uuid;
update public.workspaces set default_locale = 'it'
 where id = current_setting('deskilo.test.ch')::uuid;
select ok((select document_language_confirmed from public.workspaces
            where id = current_setting('deskilo.test.ch')::uuid),
  'saving the language, even unchanged, confirms the one 0753 gave');

update public.workspaces set document_language_confirmed = false
 where id = current_setting('deskilo.test.ch')::uuid;
update public.workspaces set name = 'DOC-CH 2'
 where id = current_setting('deskilo.test.ch')::uuid;
select ok(not (select document_language_confirmed from public.workspaces
                where id = current_setting('deskilo.test.ch')::uuid),
  'another change of the workspace confirms nothing');

select * from finish();
rollback;
