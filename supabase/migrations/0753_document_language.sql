-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0753 (#3850, I9a of #3655) -- an invoice's language is decided once, by
-- the server, when the invoice is issued.
--
-- Until now an invoice was printed in the language and number formats of
-- whoever pressed the button: one invoice, German from one administrator and
-- French from another. From now on:
--
--   1. A new domain of the tax reference store, `document_language`: one row
--      per country (key `document`) with the country's official languages,
--      its usual one first, whether an invoice may be written in its
--      customer's language, and a language a subdivision requires (French in
--      Quebec). The source of each row cites the rule; a row with no rule
--      found is unconfirmed and keeps the business's language.
--   2. `invoices.document_language` and `invoices.format_locale`, set by a
--      BEFORE INSERT trigger for every issuing path at once: the language a
--      subdivision of the seller requires, else the customer's language where
--      the row allows it and the app ships it, else the business's document
--      language. The format locale is that language paired with the seller's
--      country (`fr_CH`); the app maps the pair onto its number and date
--      conventions. The invoices guard refuses any later change. An invoice
--      issued before this migration keeps neither: it prints in the business's
--      document language.
--   3. The business's document language is `workspaces.default_locale`. A
--      business in a country with several shipped languages that has none
--      gets one now, once: its owner's language when the app ships it, else
--      the country's first shipped language. `document_language_confirmed`
--      stays false until an administrator saves the language, and the app
--      shows a to-do until then. Nothing blocks.

-- ── 1. the shape of a document_language row ───────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.tax_reference_valid(text,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$    when 'country' then$a$,
    $a$    when 'document_language' then
      -- The languages a document of a country may be written in.
      if exists (select 1 from jsonb_object_keys(p_value) k
                  where k <> all (array['languages', 'customer_language', 'required_by_subdivision'])) then return false; end if;
      if jsonb_typeof(p_value -> 'languages') is distinct from 'array'
         or jsonb_array_length(p_value -> 'languages') not between 1 and 10
         or exists (select 1 from jsonb_array_elements(p_value -> 'languages') l
                     where jsonb_typeof(l) <> 'string' or (l #>> '{}') !~ '^[a-z]{2}$') then return false; end if;
      if jsonb_typeof(p_value -> 'customer_language') is distinct from 'boolean' then return false; end if;
      return not (p_value ? 'required_by_subdivision')
         or (jsonb_typeof(p_value -> 'required_by_subdivision') = 'object'
             and not exists (select 1 from jsonb_each(p_value -> 'required_by_subdivision') s
                              where s.key !~ '^[A-Z0-9]{1,3}$' or jsonb_typeof(s.value) <> 'string'
                                 or (s.value #>> '{}') !~ '^[a-z]{2}$'));
    when 'country' then$a$);
  if v_def is null or position($a$when 'document_language' then$a$ in v_def) = 0 then
    raise exception '0753: tax_reference_valid country anchor missing' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

-- ── 2. the rows ───────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('document_language', 'AT', 'document', '1900-01-01', '{"languages":["de"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'BE', 'document', '1900-01-01', '{"languages":["nl","fr","de"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'BG', 'document', '1900-01-01', '{"languages":["bg"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'CA', 'document', '1900-01-01', '{"languages":["en","fr"],"customer_language":false,"required_by_subdivision":{"QC":"fr"}}'::jsonb, 'Charter of the French language (CQLR c C-11) s. 57: in Quebec an invoice or a receipt is written in French; another language may accompany a French version of comparable quality (Educaloi, language laws and doing business in Quebec). No rule outside Quebec is established here, so an invoice follows the business''s document language. Languages: Official Languages Act.', true),
('document_language', 'CH', 'document', '1900-01-01', '{"languages":["de","fr","it","rm"],"customer_language":false}'::jsonb, 'No rule on the language of an invoice is established here (the VAT Act art. 26 lists an invoice''s mentions, not its language), so an invoice follows the business''s document language. Languages: Federal Constitution art. 4 and 70.', false),
('document_language', 'CY', 'document', '1900-01-01', '{"languages":["el","tr"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'CZ', 'document', '1900-01-01', '{"languages":["cs"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'DE', 'document', '1900-01-01', '{"languages":["de"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'DK', 'document', '1900-01-01', '{"languages":["da"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'EE', 'document', '1900-01-01', '{"languages":["et"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'ES', 'document', '1900-01-01', '{"languages":["es"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'FI', 'document', '1900-01-01', '{"languages":["fi","sv"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'FR', 'document', '1900-01-01', '{"languages":["fr"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'GB', 'document', '1900-01-01', '{"languages":["en"],"customer_language":true}'::jsonb, 'VAT Regulations 1995 reg. 13B; HMRC VAT Traders'' Records Manual VATREC5070: a VAT invoice may be written in any language, and HMRC may ask for an English translation.', true),
('document_language', 'GR', 'document', '1900-01-01', '{"languages":["el"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'HR', 'document', '1900-01-01', '{"languages":["hr"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'HU', 'document', '1900-01-01', '{"languages":["hu"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'IE', 'document', '1900-01-01', '{"languages":["ga","en"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'IT', 'document', '1900-01-01', '{"languages":["it"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'LT', 'document', '1900-01-01', '{"languages":["lt"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'LU', 'document', '1900-01-01', '{"languages":["lb","fr","de"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'LV', 'document', '1900-01-01', '{"languages":["lv"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'MT', 'document', '1900-01-01', '{"languages":["mt","en"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'NL', 'document', '1900-01-01', '{"languages":["nl"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'NO', 'document', '1900-01-01', '{"languages":["nb","nn"],"customer_language":false}'::jsonb, 'No rule on the language of an invoice is established here, so an invoice follows the business''s document language.', false),
('document_language', 'PL', 'document', '1900-01-01', '{"languages":["pl"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'PT', 'document', '1900-01-01', '{"languages":["pt"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'RO', 'document', '1900-01-01', '{"languages":["ro"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'SE', 'document', '1900-01-01', '{"languages":["sv"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'SI', 'document', '1900-01-01', '{"languages":["sl"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'SK', 'document', '1900-01-01', '{"languages":["sk"],"customer_language":true}'::jsonb, 'VAT Directive 2006/112/EC art. 248a (Directive 2010/45/EU): a member state may ask for a translation of an invoice into its official language for control purposes in certain cases, never as a general requirement, so an invoice may be written in its customer''s language. Languages: the country''s official languages, the usual one first.', true),
('document_language', 'US', 'document', '1900-01-01', '{"languages":["en"],"customer_language":false}'::jsonb, 'No federal rule on the language of an invoice is established here, so an invoice follows the business''s document language.', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

-- ── 3. the resolution ─────────────────────────────────────────────────
-- The languages the app ships documents in (the five ARB bundles).
create or replace function public.document_language_supported(p_language text)
returns boolean
language sql immutable set search_path = public as $fn$
  select coalesce(p_language, '') in ('en', 'fr', 'de', 'es', 'it');
$fn$;

revoke execute on function public.document_language_supported(text) from public, anon, authenticated;

-- The `document_language` row of a country in force on a day, or null.
create or replace function public.document_language_facts(p_country text, p_on date)
returns jsonb
language sql stable security definer set search_path = public as $fn$
  select t.value
    from public.tax_reference t
   where t.domain = 'document_language' and t.key = 'document'
     and t.country = upper(btrim(coalesce(p_country, '')))
     and t.valid_from <= p_on and (t.valid_to is null or t.valid_to > p_on)
   order by t.valid_from desc
   limit 1;
$fn$;

revoke execute on function public.document_language_facts(text, date) from public, anon, authenticated;

-- The business's document language: its own when the app ships it, else the
-- country's first shipped language, else English.
create or replace function public.business_document_language(p_locale text, p_country text, p_on date)
returns text
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_language text;
begin
  if public.document_language_supported(p_locale) then
    return p_locale;
  end if;
  for v_language in
    select l from jsonb_array_elements_text(
      coalesce(public.document_language_facts(p_country, p_on) -> 'languages', '[]'::jsonb)) l
  loop
    if public.document_language_supported(v_language) then
      return v_language;
    end if;
  end loop;
  return 'en';
end;
$fn$;

revoke execute on function public.business_document_language(text, text, date) from public, anon, authenticated;

-- The language of an invoice: a language the seller's subdivision requires,
-- else the customer's where the country allows it, else the business's.
create or replace function public.invoice_document_language(
  p_workspace_id uuid, p_member_id uuid, p_country text, p_subdivision text, p_on date
) returns text
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_facts jsonb := public.document_language_facts(p_country, p_on);
  v_required text;
  v_customer text;
  v_locale text;
begin
  v_required := v_facts #>> array['required_by_subdivision',
    upper(regexp_replace(btrim(coalesce(p_subdivision, '')), '^[A-Za-z]{2}-', ''))];
  if public.document_language_supported(v_required) then
    return v_required;
  end if;
  if coalesce((v_facts ->> 'customer_language')::boolean, false) and p_member_id is not null then
    select coalesce(m.preferred_locale_override, p.preferred_locale)
      into v_customer
      from public.members m left join public.profiles p on p.id = m.user_id
     where m.id = p_member_id and m.workspace_id = p_workspace_id;
    if public.document_language_supported(v_customer) then
      return v_customer;
    end if;
  end if;
  select w.default_locale into v_locale from public.workspaces w where w.id = p_workspace_id;
  return public.business_document_language(v_locale, p_country, p_on);
end;
$fn$;

revoke execute on function public.invoice_document_language(uuid, uuid, text, text, date)
  from public, anon, authenticated;

-- ── 4. the frozen columns ─────────────────────────────────────────────
alter table public.invoices
  add column if not exists document_language text,
  add column if not exists format_locale text;

alter table public.invoices
  drop constraint if exists invoices_document_language_check,
  add constraint invoices_document_language_check
    check (document_language is null or public.document_language_supported(document_language)),
  drop constraint if exists invoices_format_locale_check,
  add constraint invoices_format_locale_check
    check (format_locale is null or format_locale ~ '^[a-z]{2}_[A-Z]{2}$');

comment on column public.invoices.document_language is
  '#3850 -- the language the invoice is written in, frozen at issue (null: issued before 0753, printed in the business''s document language).';
comment on column public.invoices.format_locale is
  '#3850 -- the document language paired with the seller''s country (fr_CH), frozen at issue: the number and date conventions of the document.';

-- Named after `invoice_legal_freeze` so it runs once the snapshot (and its
-- seller country) exists: BEFORE triggers fire in name order. It overwrites
-- whatever the insert carried: a caller never chooses the language.
create or replace function public.invoice_legal_language_freeze()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  v_country text;
  v_subdivision text;
  v_day date;
begin
  -- The rules in force on the invoice's own day of issue, in its business's
  -- zone: a replay decides what the issue decided.
  select upper(coalesce(nullif(new.legal_snapshot ->> 'seller_country', ''), w.country_code)),
         coalesce(nullif(new.parties #>> '{seller,subdivision}', ''), w.invoice_legal ->> 'subdivision', ''),
         (coalesce(new.issued_at, now()) at time zone w.timezone)::date
    into v_country, v_subdivision, v_day
    from public.workspaces w where w.id = new.workspace_id;
  new.document_language := public.invoice_document_language(
    new.workspace_id, new.member_id, v_country, v_subdivision, v_day);
  new.format_locale := new.document_language || '_' || v_country;
  return new;
end;
$fn$;

revoke execute on function public.invoice_legal_language_freeze() from public, anon, authenticated;

drop trigger if exists invoice_legal_language_freeze on public.invoices;
create trigger invoice_legal_language_freeze
  before insert on public.invoices
  for each row execute function public.invoice_legal_language_freeze();

-- ── 5. the business's document language ───────────────────────────────
alter table public.workspaces
  add column if not exists document_language_confirmed boolean not null default true;

comment on column public.workspaces.document_language_confirmed is
  '#3850 -- false while the document language 0753 gave a business of a country with several shipped languages waits for an administrator to confirm it.';

-- Whether a business of [p_country] chooses its document language: the
-- country's row names more than one shipped language.
create or replace function public.document_language_chosen(p_country text, p_on date)
returns boolean
language sql stable security definer set search_path = public as $fn$
  select coalesce((select count(*) > 1
                     from jsonb_array_elements_text(public.document_language_facts(p_country, p_on) -> 'languages') l
                    where public.document_language_supported(l)), false);
$fn$;

revoke execute on function public.document_language_chosen(text, date) from public, anon, authenticated;

-- The document language 0753 gives a business that has none: its owner's
-- language when the app ships it, else its country's first shipped one.
create or replace function public.workspace_document_language_default(p_workspace_id uuid, p_on date)
returns text
language sql stable security definer set search_path = public as $fn$
  select coalesce(
           (select p.preferred_locale from public.profiles p
             where p.id = w.created_by and public.document_language_supported(p.preferred_locale)),
           public.business_document_language('', w.country_code, p_on))
    from public.workspaces w where w.id = p_workspace_id;
$fn$;

revoke execute on function public.workspace_document_language_default(uuid, date)
  from public, anon, authenticated;

-- Every business of a country with several shipped languages and none of
-- them chosen gets its default once, waiting for confirmation. The rows are
-- read as on the day this rule was decided, so a replay gives the same.
update public.workspaces w
   set default_locale = public.workspace_document_language_default(w.id, date '2026-11-13'),
       document_language_confirmed = false
 where public.document_language_chosen(w.country_code, date '2026-11-13')
   and not public.document_language_supported(w.default_locale);

-- Saving the language is the confirmation.
create or replace function public.workspace_document_language_confirm()
returns trigger
language plpgsql set search_path = public as $fn$
begin
  new.document_language_confirmed := true;
  return new;
end;
$fn$;

revoke execute on function public.workspace_document_language_confirm() from public, anon, authenticated;

drop trigger if exists workspace_document_language_confirm on public.workspaces;
create trigger workspace_document_language_confirm
  before update of default_locale on public.workspaces
  for each row
  when (old.document_language_confirmed is false
        and new.document_language_confirmed is not distinct from old.document_language_confirmed)
  execute function public.workspace_document_language_confirm();

-- A delegated administrator saving the settings confirms the language too:
-- the guard of the owner's columns (0361) lets the flag through with the
-- settings it travels with, whatever order the triggers fire in.
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.workspaces_delegated_columns()'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$'address', 'whatsapp_group', 'desk_opacity'];$a$,
    $a$'address', 'whatsapp_group', 'desk_opacity', 'document_language_confirmed'];$a$);
  if v_def is null or position($a$'document_language_confirmed'];$a$ in v_def) = 0 then
    raise exception '0753: workspaces_delegated_columns anchor missing' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(753);
