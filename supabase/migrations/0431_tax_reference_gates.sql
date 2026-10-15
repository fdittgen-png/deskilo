-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0431 (#2479, C3 of #2476) -- the turnover thresholds, the tax point policy,
-- the issuing gate and the e-invoicing mandate calendar are READ from the tax
-- reference store; the Dart/SQL twins are gone.
--
--   * tax_reference_valid   learns the four shapes (`threshold`, `tax_point`,
--                           `mandate`, `issuing_gate`), and answers false
--                           where it answered NULL: a missing key made a
--                           comparison NULL, and a CHECK passes on NULL, so
--                           a value without a required key was accepted.
--   * vat_tax_point_policy  answers from the `tax_point` rows in force today
--                           (a country's own row, the shared `*` row
--                           otherwise) instead of a CASE on the country. Same
--                           results for every input; stable and security
--                           definer like the other readers of the store.
--   * issuing_gate_of       the row of a seller's country (an alias such as
--                           EL resolved), or null.
--   * invoice_essentials_missing   reads the gate instead of
--                           `is_eu_country(...) or v_cc in ('GB','CH','CA')`,
--                           `v_cc in ('IT','ES','PL','RO')`,
--                           `v_cc in ('DE','ES')` and the national-currency
--                           CASE. A country with no row is refused as before
--                           (`seller_country_unsupported`); a row with
--                           national_channel_required stays refused whatever
--                           `supported` says. Anchored patch: every anchor is
--                           asserted, and the harness runs the whole matrix
--                           (country x regime x identifiers x currency)
--                           before and after: byte-identical results.
--   * the seed: thresholds, tax points, gates and mandates.
--
-- Issued documents and filed periods keep their frozen values: nothing here
-- rewrites an invoice, and the gate decides only the invoice being issued.

create or replace function public.tax_reference_valid(p_domain text, p_value jsonb)
returns boolean language plpgsql immutable set search_path = public as $fn$
declare
  v_allowed text[];
begin
  -- A missing key makes a comparison NULL, and a CHECK passes on NULL: every
  -- answer is coalesced to false (the shapes of 0427 and 0430 had the hole).
  if p_value is null or jsonb_typeof(p_value) <> 'object' then return false; end if;
  case p_domain
    when 'rate' then
      v_allowed := array['label', 'percent', 'group', 'category', 'exemption_reason', 'position'];
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (v_allowed)) then return false; end if;
      if jsonb_typeof(p_value -> 'label') is distinct from 'string'
         or btrim(p_value ->> 'label') = '' then return false; end if;
      if jsonb_typeof(p_value -> 'percent') is distinct from 'number' then return false; end if;
      if (p_value ->> 'percent')::numeric < 0 or (p_value ->> 'percent')::numeric > 99.999 then return false; end if;
      if jsonb_typeof(p_value -> 'group') is distinct from 'string'
         or (p_value ->> 'group') <> all (array['standard', 'intermediate', 'reduced', 'super_reduced',
                                               'zero', 'exempt', 'not_subject', 'deposit', 'excise']) then
        return false;
      end if;
      if jsonb_typeof(p_value -> 'category') is distinct from 'string'
         or (p_value ->> 'category') <> all (array['S', 'Z', 'E', 'O']) then return false; end if;
      if p_value ? 'exemption_reason' and jsonb_typeof(p_value -> 'exemption_reason') <> 'string' then return false; end if;
      if p_value ? 'position' and (jsonb_typeof(p_value -> 'position') <> 'number'
                                   or (p_value ->> 'position') !~ '^[0-9]+$') then return false; end if;
      return true;
    when 'eu_member' then
      -- A member state ({}), or another spelling of one ({alias_of}).
      return coalesce(p_value = '{}'::jsonb
          or (p_value ? 'alias_of'
              and not exists (select 1 from jsonb_object_keys(p_value) k where k <> 'alias_of')
              and jsonb_typeof(p_value -> 'alias_of') = 'string'
              and (p_value ->> 'alias_of') ~ '^[A-Z]{2}$'), false);
    when 'catalogue_note' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> 'text') then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'text') = 'string' and btrim(p_value ->> 'text') <> '', false);
    when 'group_example' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['group', 'text', 'position'])) then return false; end if;
      if jsonb_typeof(p_value -> 'group') is distinct from 'string'
         or (p_value ->> 'group') <> all (array['standard', 'intermediate', 'reduced', 'super_reduced',
                                               'zero', 'exempt', 'not_subject', 'deposit', 'excise']) then
        return false;
      end if;
      if p_value ? 'position' and (jsonb_typeof(p_value -> 'position') <> 'number'
                                   or (p_value ->> 'position') !~ '^[0-9]+$') then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'text') = 'string' and btrim(p_value ->> 'text') <> '', false);
    when 'threshold' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['cents', 'effect', 'currency'])) then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'cents') = 'number' and (p_value ->> 'cents') ~ '^[1-9][0-9]*$'
         and (p_value ->> 'effect') = any (array['next_year', 'immediate'])
         and jsonb_typeof(p_value -> 'currency') = 'string' and (p_value ->> 'currency') ~ '^[A-Z]{3}$', false);
    when 'tax_point' then
      if exists (select 1 from jsonb_object_keys(p_value) k
                  where k <> all (array['standard', 'invoice_option', 'cash_option', 'cash_backstop'])) then return false; end if;
      return coalesce((p_value ->> 'standard') = any (array['invoice', 'receipt', 'service_period', 'earlier_of'])
         and jsonb_typeof(p_value -> 'invoice_option') = 'boolean'
         and jsonb_typeof(p_value -> 'cash_option') = 'boolean'
         and (p_value ->> 'cash_backstop') = any (array['none', 'end_of_following_year', 'one_year_after_issue']), false);
    when 'mandate' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['duty', 'from'])) then return false; end if;
      if (p_value ->> 'duty') <> all (array['receive_all', 'issue_large', 'issue_all', 'e_reporting', 'invoice_records'])
         or (p_value ->> 'duty') is null then return false; end if;
      begin
        return coalesce(jsonb_typeof(p_value -> 'from') = 'string'
           and to_char((p_value ->> 'from')::date, 'YYYY-MM-DD') = (p_value ->> 'from'), false);
      exception when others then
        return false;
      end;
    when 'issuing_gate' then
      if exists (select 1 from jsonb_object_keys(p_value) k
                  where k <> all (array['supported', 'requires_tax_number', 'national_channel_required', 'currency'])) then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'supported') = 'boolean'
         and jsonb_typeof(p_value -> 'requires_tax_number') = 'boolean'
         and jsonb_typeof(p_value -> 'national_channel_required') = 'boolean'
         and (not p_value ? 'currency'
              or (jsonb_typeof(p_value -> 'currency') = 'string' and (p_value ->> 'currency') ~ '^[A-Z]{3}$')), false);
    when 'exemption_text' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['regime', 'text'])) then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'regime') = 'string' and btrim(p_value ->> 'regime') <> ''
         and jsonb_typeof(p_value -> 'text') = 'string' and btrim(p_value ->> 'text') <> '', false);
    when 'vat_id_pattern' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> 'pattern') then return false; end if;
      if jsonb_typeof(p_value -> 'pattern') is distinct from 'string' or btrim(p_value ->> 'pattern') = '' then return false; end if;
      -- A pattern the database cannot compile is not a pattern.
      begin
        perform '' ~ (p_value ->> 'pattern');
      exception when others then
        return false;
      end;
      return true;
    else
      return false;
  end case;
end;
$fn$;
revoke execute on function public.tax_reference_valid(text, jsonb) from public, anon, authenticated;

-- ── tax point policy, as rows ─────────────────────────────────────────
create or replace function public.vat_tax_point_policy(p_country text)
returns table (standard text, invoice_option boolean, cash_option boolean,
               cash_backstop text)
language sql stable security definer set search_path = public as $fn$
  select x.v ->> 'standard',
         coalesce((x.v ->> 'invoice_option')::boolean, false),
         coalesce((x.v ->> 'cash_option')::boolean, true),
         coalesce(x.v ->> 'cash_backstop', 'none')
    from (select t.value as v
            from public.tax_reference t
           where t.domain = 'tax_point' and t.key = 'policy'
             and t.country in (upper(btrim(coalesce(p_country, ''))), '*')
             and t.valid_from <= current_date
             and (t.valid_to is null or t.valid_to > current_date)
           order by (t.country = '*')
           limit 1) x;
$fn$;
revoke execute on function public.vat_tax_point_policy(text) from public, anon;

-- ── the issuing gate of a seller's country ────────────────────────────
create or replace function public.issuing_gate_of(p_country text)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select t.value
    from public.tax_reference t
   where t.domain = 'issuing_gate' and t.key = 'gate'
     and t.country = public.eu_country_code(p_country)
     and t.valid_from <= current_date
     and (t.valid_to is null or t.valid_to > current_date)
   limit 1;
$fn$;
revoke execute on function public.issuing_gate_of(text) from public, anon;
grant execute on function public.issuing_gate_of(text) to authenticated, service_role;

-- ── anchored patch ────────────────────────────────────────────────────
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
  v_step record;
begin
  select pg_get_functiondef('public.invoice_essentials_missing(uuid,uuid,jsonb,jsonb)'::regprocedure)
    into v_def;
  for v_step in
    select * from (values
      (1, 'declaration',
       $old$  v_national text;
$old$,
       $new$  v_national text;
  v_gate jsonb;
$new$),
      (2, 'the gate of the seller country',
       $old$  v_cc := public.eu_country_code(v_country);
$old$,
       $new$  v_cc := public.eu_country_code(v_country);
  v_gate := public.issuing_gate_of(v_cc);
$new$),
      (3, 'the tax number rule',
       $old$  if v_cc in ('DE', 'ES') and v_regime <> 'not_subject'
$old$,
       $new$  if coalesce((v_gate ->> 'requires_tax_number')::boolean, false) and v_regime <> 'not_subject'
$new$),
      (4, 'the supported countries and the national channels',
       $old$  if not (public.is_eu_country(v_country) or v_cc in ('GB', 'CH', 'CA'))
     or v_cc in ('IT', 'ES', 'PL', 'RO') then
$old$,
       $new$  if not coalesce((v_gate ->> 'supported')::boolean, false)
     or coalesce((v_gate ->> 'national_channel_required')::boolean, false) then
$new$),
      (5, 'the currency the VAT is stated in',
       $old$  v_national := case v_cc when 'CZ' then 'CZK' when 'DK' then 'DKK'
                          when 'HU' then 'HUF' when 'PL' then 'PLN'
                          when 'RO' then 'RON' when 'SE' then 'SEK'
                          when 'GB' then 'GBP' when 'CH' then 'CHF'
                          when 'CA' then 'CAD' end;
$old$,
       $new$  v_national := nullif(v_gate ->> 'currency', '');
$new$)
    ) as s(n, what, old_text, new_text) order by n
  loop
    v_def := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_def is null then
      raise exception '0431: invoice_essentials_missing anchor % (%) missing', v_step.n, v_step.what;
    end if;
  end loop;
  execute v_def;
end
$migration$;

-- The seed: what 0427 and 0430 did not hold.
-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('issuing_gate', 'AT', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'BE', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'BG', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'CA', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false,"currency":"CAD"}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'CH', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false,"currency":"CHF"}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'CY', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'CZ', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false,"currency":"CZK"}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'DE', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":true,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'DK', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false,"currency":"DKK"}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'EE', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'ES', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":true,"national_channel_required":true}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'FI', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'FR', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'GB', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false,"currency":"GBP"}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'GR', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'HR', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'HU', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false,"currency":"HUF"}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'IE', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'IT', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":true}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'LT', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'LU', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'LV', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'MT', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'NL', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'PL', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":true,"currency":"PLN"}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'PT', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'RO', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":true,"currency":"RON"}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'SE', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false,"currency":"SEK"}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'SI', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('issuing_gate', 'SK', 'gate', '1900-01-01', '{"supported":true,"requires_tax_number":false,"national_channel_required":false}'::jsonb, 'invoice_essentials_missing (0409, 0410, 0419, 0422, 0426) and einvoice_mandates.dart (#2358): the gate as it stood; the VAT currency is art. 230 of Directive 2006/112/EC (#2356), typed in code, not re-verified', false),
('mandate', 'BE', 'issue_all', '1900-01-01', '{"duty":"issue_all","from":"2026-01-01"}'::jsonb, 'einvoice_mandates.dart (#2358): loi du 6 février 2024, as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'BE', 'receive_all', '1900-01-01', '{"duty":"receive_all","from":"2026-01-01"}'::jsonb, 'einvoice_mandates.dart (#2358): loi du 6 février 2024, as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'DE', 'issue_all', '1900-01-01', '{"duty":"issue_all","from":"2028-01-01"}'::jsonb, 'einvoice_mandates.dart (#2358): Wachstumschancengesetz, as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'DE', 'issue_large', '1900-01-01', '{"duty":"issue_large","from":"2027-01-01"}'::jsonb, 'einvoice_mandates.dart (#2358): Wachstumschancengesetz, as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'DE', 'receive_all', '1900-01-01', '{"duty":"receive_all","from":"2025-01-01"}'::jsonb, 'einvoice_mandates.dart (#2358): Wachstumschancengesetz, as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'ES', 'invoice_records', '1900-01-01', '{"duty":"invoice_records","from":"2027-01-01"}'::jsonb, 'einvoice_mandates.dart (#2358): RD 1007/2023 as moved by RDL 15/2025, as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'FR', 'e_reporting', '1900-01-01', '{"duty":"e_reporting","from":"2026-09-01"}'::jsonb, 'einvoice_mandates.dart (#2358): loi de finances 2024, art. 91, as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'FR', 'issue_all', '1900-01-01', '{"duty":"issue_all","from":"2027-09-01"}'::jsonb, 'einvoice_mandates.dart (#2358): loi de finances 2024, art. 91, as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'FR', 'issue_large', '1900-01-01', '{"duty":"issue_large","from":"2026-09-01"}'::jsonb, 'einvoice_mandates.dart (#2358): loi de finances 2024, art. 91, as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'FR', 'receive_all', '1900-01-01', '{"duty":"receive_all","from":"2026-09-01"}'::jsonb, 'einvoice_mandates.dart (#2358): loi de finances 2024, art. 91, as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'IT', 'issue_all', '1900-01-01', '{"duty":"issue_all","from":"2019-01-01"}'::jsonb, 'einvoice_mandates.dart (#2358): 2019 (SdI), as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'PL', 'issue_all', '1900-01-01', '{"duty":"issue_all","from":"2026-04-01"}'::jsonb, 'einvoice_mandates.dart (#2358): KSeF, Ustawa of 5 August 2025, as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'PL', 'issue_large', '1900-01-01', '{"duty":"issue_large","from":"2026-02-01"}'::jsonb, 'einvoice_mandates.dart (#2358): KSeF, Ustawa of 5 August 2025, as the laws stood in October 2026; typed in code, not re-verified', false),
('mandate', 'RO', 'issue_all', '1900-01-01', '{"duty":"issue_all","from":"2024-07-01"}'::jsonb, 'einvoice_mandates.dart (#2358): OUG 120/2021, as the laws stood in October 2026; typed in code, not re-verified', false),
('tax_point', '*', 'policy', '1900-01-01', '{"standard":"invoice","invoice_option":false,"cash_option":true,"cash_backstop":"none"}'::jsonb, 'vat_tax_point.dart (#2355) and vat_tax_point_policy (0402): the invoice date, with a cash option, everywhere not named; typed in code, not re-verified', false),
('tax_point', 'CA', 'policy', '1900-01-01', '{"standard":"earlier_of","invoice_option":false,"cash_option":false,"cash_backstop":"none"}'::jsonb, 'vat_tax_point.dart (#2355) and vat_tax_point_policy (0402): Excise Tax Act s. 168; typed in code, not re-verified', false),
('tax_point', 'CH', 'policy', '1900-01-01', '{"standard":"invoice","invoice_option":false,"cash_option":true,"cash_backstop":"none"}'::jsonb, 'vat_tax_point.dart (#2355) and vat_tax_point_policy (0402): art. 39 MWSTG, vereinbarte Entgelte; typed in code, not re-verified', false),
('tax_point', 'DE', 'policy', '1900-01-01', '{"standard":"service_period","invoice_option":false,"cash_option":true,"cash_backstop":"none"}'::jsonb, 'vat_tax_point.dart (#2355) and vat_tax_point_policy (0402): § 13 UStG, Ist-Versteuerung § 20; typed in code, not re-verified', false),
('tax_point', 'ES', 'policy', '1900-01-01', '{"standard":"service_period","invoice_option":false,"cash_option":true,"cash_backstop":"end_of_following_year"}'::jsonb, 'vat_tax_point.dart (#2355) and vat_tax_point_policy (0402): art. 75 LIVA, criterio de caja art. 163 terdecies; typed in code, not re-verified', false),
('tax_point', 'FR', 'policy', '1900-01-01', '{"standard":"receipt","invoice_option":true,"cash_option":false,"cash_backstop":"none"}'::jsonb, 'vat_tax_point.dart (#2355) and vat_tax_point_policy (0402): CGI art. 269-2-c; typed in code, not re-verified', false),
('tax_point', 'GB', 'policy', '1900-01-01', '{"standard":"earlier_of","invoice_option":false,"cash_option":true,"cash_backstop":"none"}'::jsonb, 'vat_tax_point.dart (#2355) and vat_tax_point_policy (0402): VAT Regulations 1995 reg. 90; typed in code, not re-verified', false),
('tax_point', 'IT', 'policy', '1900-01-01', '{"standard":"earlier_of","invoice_option":false,"cash_option":true,"cash_backstop":"one_year_after_issue"}'::jsonb, 'vat_tax_point.dart (#2355) and vat_tax_point_policy (0402): art. 6 DPR 633/72, IVA per cassa art. 32-bis DL 83/2012; typed in code, not re-verified', false),
('tax_point', 'UK', 'policy', '1900-01-01', '{"standard":"earlier_of","invoice_option":false,"cash_option":true,"cash_backstop":"none"}'::jsonb, 'vat_tax_point.dart (#2355) and vat_tax_point_policy (0402): VAT Regulations 1995 reg. 90 (UK as an alias of GB); typed in code, not re-verified', false),
('threshold', 'DE', 'small_business_immediate', '2025-01-01', '{"cents":10000000,"effect":"immediate","currency":"EUR"}'::jsonb, 'small_business_threshold.dart (#2440): § 19 Abs. 1 UStG (JStG 2024)', true),
('threshold', 'DE', 'small_business_next_year', '2025-01-01', '{"cents":2500000,"effect":"next_year","currency":"EUR"}'::jsonb, 'small_business_threshold.dart (#2440): § 19 Abs. 1 UStG (JStG 2024)', true),
('threshold', 'FR', 'small_business_immediate', '1900-01-01', '{"cents":4125000,"effect":"immediate","currency":"EUR"}'::jsonb, 'small_business_threshold.dart (#2440): CGI art. 293 B (services, tolerance); the 2026 figure was not verified', false),
('threshold', 'FR', 'small_business_next_year', '1900-01-01', '{"cents":3750000,"effect":"next_year","currency":"EUR"}'::jsonb, 'small_business_threshold.dart (#2440): CGI art. 293 B (services); the 2026 figure was not verified', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(431);
