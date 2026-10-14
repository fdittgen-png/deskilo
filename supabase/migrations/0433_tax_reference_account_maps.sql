-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0433 (#2481, C5 of #2476) -- the accounts and tax codes the accounting
-- exports and the chart-of-accounts preview propose are READ from the tax
-- reference store: the `account_map` domain holds, per country, the suggested
-- chart (`coa/NN-<role>`, its `coa/00-chart` header), what the FEC asks beyond
-- the chart (`fec/vat_pending`) and the Sage nominal accounts and VAT codes
-- (`sage/<role>`). The workspace's own chart stays its `book_profile`; these
-- are the default proposal an accountant's correction always wins over.
--
--   * tax_reference_valid   learns the `account_map` shape.
--   * the seed: the eleven charts and the FEC and Sage rows.
--
-- No function, invoice or filed period is touched.

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
    when 'form_box' then
      -- A rated box of a return form: the wording it prints and the fiscal
      -- groups it adds up (or, for a catch-all box, every group but these).
      if exists (select 1 from jsonb_object_keys(p_value) k
                  where k <> all (array['label', 'groups', 'exclude_groups'])) then return false; end if;
      if jsonb_typeof(p_value -> 'label') is distinct from 'string'
         or btrim(p_value ->> 'label') = '' then return false; end if;
      declare
        v_known text[] := array['standard', 'intermediate', 'reduced', 'super_reduced',
                                'zero', 'exempt', 'not_subject', 'deposit', 'excise'];
        v_take text[] := '{}';
        v_left text[] := '{}';
      begin
        if p_value ? 'groups' then
          if jsonb_typeof(p_value -> 'groups') <> 'array'
             or exists (select 1 from jsonb_array_elements(p_value -> 'groups') e
                         where jsonb_typeof(e) <> 'string') then return false; end if;
          select coalesce(array_agg(e #>> '{}'), '{}') into v_take
            from jsonb_array_elements(p_value -> 'groups') e;
        end if;
        if p_value ? 'exclude_groups' then
          if jsonb_typeof(p_value -> 'exclude_groups') <> 'array'
             or exists (select 1 from jsonb_array_elements(p_value -> 'exclude_groups') e
                         where jsonb_typeof(e) <> 'string') then return false; end if;
          select coalesce(array_agg(e #>> '{}'), '{}') into v_left
            from jsonb_array_elements(p_value -> 'exclude_groups') e;
        end if;
        -- A box that selects nothing, a group nobody knows, or a group both
        -- taken and excluded is not a selector.
        return cardinality(v_take) + cardinality(v_left) > 0
           and v_take <@ v_known and v_left <@ v_known
           and not v_take && v_left;
      end;
    when 'account_map' then
      -- A default an accounting export or the chart preview proposes: an
      -- account number (or a chart's code) and/or the export's tax code.
      if exists (select 1 from jsonb_object_keys(p_value) k
                  where k <> all (array['format', 'role', 'account', 'tax_code', 'label'])) then return false; end if;
      if (p_value ->> 'format') is null
         or (p_value ->> 'format') <> all (array['coa', 'fec', 'datev', 'sage', 'saf_t']) then return false; end if;
      if jsonb_typeof(p_value -> 'role') is distinct from 'string'
         or btrim(p_value ->> 'role') = '' then return false; end if;
      if p_value ? 'label' and jsonb_typeof(p_value -> 'label') <> 'string' then return false; end if;
      if p_value ? 'account' and (jsonb_typeof(p_value -> 'account') <> 'string'
                                  or btrim(p_value ->> 'account') = '') then return false; end if;
      if p_value ? 'tax_code' and (jsonb_typeof(p_value -> 'tax_code') <> 'string'
                                   or btrim(p_value ->> 'tax_code') = '') then return false; end if;
      return p_value ? 'account' or p_value ? 'tax_code';
    else
      return false;
  end case;
end;
$fn$;
revoke execute on function public.tax_reference_valid(text, jsonb) from public, anon, authenticated;

-- The seed.
-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('account_map', '*', 'coa/00-chart', '1900-01-01', '{"format":"coa","role":"chart","account":"GEN","label":"Generic"}'::jsonb, 'the chart bookkeepers of this country conventionally use (GEN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', '*', 'coa/01-customers', '1900-01-01', '{"format":"coa","role":"customers","account":"1200","label":"Accounts receivable"}'::jsonb, 'the chart bookkeepers of this country conventionally use (GEN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', '*', 'coa/02-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"4000","label":"Service revenue"}'::jsonb, 'the chart bookkeepers of this country conventionally use (GEN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', '*', 'coa/03-bank', '1900-01-01', '{"format":"coa","role":"bank","account":"1000","label":"Bank"}'::jsonb, 'the chart bookkeepers of this country conventionally use (GEN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', '*', 'coa/04-vat', '1900-01-01', '{"format":"coa","role":"vat","account":"2200","label":"Sales tax payable"}'::jsonb, 'the chart bookkeepers of this country conventionally use (GEN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', '*', 'coa/05-expenses', '1900-01-01', '{"format":"coa","role":"expenses","account":"6500","label":"Übriger Betriebsaufwand"}'::jsonb, 'the chart bookkeepers of this country conventionally use (GEN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'AT', 'coa/00-chart', '1900-01-01', '{"format":"coa","role":"chart","account":"SKR03","label":"DATEV-Standardkontenrahmen 03"}'::jsonb, 'the chart bookkeepers of this country conventionally use (SKR03): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'AT', 'coa/01-customers', '1900-01-01', '{"format":"coa","role":"customers","account":"10000","label":"Debitoren"}'::jsonb, 'the chart bookkeepers of this country conventionally use (SKR03): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'AT', 'coa/02-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"8400","label":"Erlöse 19 % USt"}'::jsonb, 'the chart bookkeepers of this country conventionally use (SKR03): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'AT', 'coa/03-bank', '1900-01-01', '{"format":"coa","role":"bank","account":"1200","label":"Bank"}'::jsonb, 'the chart bookkeepers of this country conventionally use (SKR03): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'AT', 'coa/04-vat', '1900-01-01', '{"format":"coa","role":"vat","account":"1776","label":"Umsatzsteuer 19 %"}'::jsonb, 'the chart bookkeepers of this country conventionally use (SKR03): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'AT', 'coa/05-expenses', '1900-01-01', '{"format":"coa","role":"expenses","account":"4900","label":"Sonstige betriebliche Aufwendungen"}'::jsonb, 'the chart bookkeepers of this country conventionally use (SKR03): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'BE', 'coa/00-chart', '1900-01-01', '{"format":"coa","role":"chart","account":"PCMN","label":"Plan comptable minimum normalisé"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PCMN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'BE', 'coa/01-customers', '1900-01-01', '{"format":"coa","role":"customers","account":"400","label":"Clients"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PCMN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'BE', 'coa/02-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"700","label":"Prestations de services"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PCMN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'BE', 'coa/03-bank', '1900-01-01', '{"format":"coa","role":"bank","account":"550","label":"Établissements de crédit"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PCMN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'BE', 'coa/04-vat', '1900-01-01', '{"format":"coa","role":"vat","account":"451","label":"TVA à payer"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PCMN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'BE', 'coa/05-expenses', '1900-01-01', '{"format":"coa","role":"expenses","account":"610","label":"Services et biens divers"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PCMN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'CH', 'coa/00-chart', '1900-01-01', '{"format":"coa","role":"chart","account":"KMU","label":"Kontenrahmen KMU"}'::jsonb, 'the chart bookkeepers of this country conventionally use (KMU): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'CH', 'coa/01-customers', '1900-01-01', '{"format":"coa","role":"customers","account":"1100","label":"Forderungen aus Lieferungen und Leistungen"}'::jsonb, 'the chart bookkeepers of this country conventionally use (KMU): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'CH', 'coa/02-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"3400","label":"Dienstleistungsertrag zum Normalsatz"}'::jsonb, 'the chart bookkeepers of this country conventionally use (KMU): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'CH', 'coa/03-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"3401","label":"Dienstleistungsertrag zum reduzierten Satz und Beherbergung"}'::jsonb, 'the chart bookkeepers of this country conventionally use (KMU): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'CH', 'coa/04-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"3402","label":"Dienstleistungsertrag, von der Steuer ausgenommen"}'::jsonb, 'the chart bookkeepers of this country conventionally use (KMU): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'CH', 'coa/05-bank', '1900-01-01', '{"format":"coa","role":"bank","account":"1020","label":"Bank"}'::jsonb, 'the chart bookkeepers of this country conventionally use (KMU): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'CH', 'coa/06-vat', '1900-01-01', '{"format":"coa","role":"vat","account":"2200","label":"Geschuldete MWST"}'::jsonb, 'the chart bookkeepers of this country conventionally use (KMU): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'CH', 'coa/07-vat', '1900-01-01', '{"format":"coa","role":"vat","account":"2201","label":"Abrechnungskonto MWST"}'::jsonb, 'the chart bookkeepers of this country conventionally use (KMU): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'CH', 'coa/08-expenses', '1900-01-01', '{"format":"coa","role":"expenses","account":"6500","label":"Übriger Betriebsaufwand"}'::jsonb, 'the chart bookkeepers of this country conventionally use (KMU): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'DE', 'coa/00-chart', '1900-01-01', '{"format":"coa","role":"chart","account":"SKR03","label":"DATEV-Standardkontenrahmen 03"}'::jsonb, 'DATEV SKR03; the DATEV export defaults', true),
('account_map', 'DE', 'coa/01-customers', '1900-01-01', '{"format":"coa","role":"customers","account":"10000","label":"Debitoren"}'::jsonb, 'DATEV SKR03; the DATEV export defaults', true),
('account_map', 'DE', 'coa/02-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"8400","label":"Erlöse 19 % USt"}'::jsonb, 'DATEV SKR03; the DATEV export defaults', true),
('account_map', 'DE', 'coa/03-bank', '1900-01-01', '{"format":"coa","role":"bank","account":"1200","label":"Bank"}'::jsonb, 'DATEV SKR03; the DATEV export defaults', true),
('account_map', 'DE', 'coa/04-vat', '1900-01-01', '{"format":"coa","role":"vat","account":"1776","label":"Umsatzsteuer 19 %"}'::jsonb, 'DATEV SKR03; the DATEV export defaults', true),
('account_map', 'DE', 'coa/05-expenses', '1900-01-01', '{"format":"coa","role":"expenses","account":"4900","label":"Sonstige betriebliche Aufwendungen"}'::jsonb, 'DATEV SKR03; the DATEV export defaults', true),
('account_map', 'ES', 'coa/00-chart', '1900-01-01', '{"format":"coa","role":"chart","account":"PGC","label":"Plan General de Contabilidad"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PGC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'ES', 'coa/01-customers', '1900-01-01', '{"format":"coa","role":"customers","account":"430","label":"Clientes"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PGC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'ES', 'coa/02-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"705","label":"Prestaciones de servicios"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PGC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'ES', 'coa/03-bank', '1900-01-01', '{"format":"coa","role":"bank","account":"572","label":"Bancos"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PGC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'ES', 'coa/04-vat', '1900-01-01', '{"format":"coa","role":"vat","account":"477","label":"IVA repercutido"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PGC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'ES', 'coa/05-expenses', '1900-01-01', '{"format":"coa","role":"expenses","account":"629","label":"Otros servicios"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PGC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'FR', 'coa/00-chart', '1900-01-01', '{"format":"coa","role":"chart","account":"PCG","label":"Plan comptable général"}'::jsonb, 'Plan comptable général (arrêté du 4 juin 1999); the FEC export defaults', true),
('account_map', 'FR', 'coa/01-customers', '1900-01-01', '{"format":"coa","role":"customers","account":"411000","label":"Clients"}'::jsonb, 'Plan comptable général (arrêté du 4 juin 1999); the FEC export defaults', true),
('account_map', 'FR', 'coa/02-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"706000","label":"Prestations de services"}'::jsonb, 'Plan comptable général (arrêté du 4 juin 1999); the FEC export defaults', true),
('account_map', 'FR', 'coa/03-bank', '1900-01-01', '{"format":"coa","role":"bank","account":"512000","label":"Banques"}'::jsonb, 'Plan comptable général (arrêté du 4 juin 1999); the FEC export defaults', true),
('account_map', 'FR', 'coa/04-vat', '1900-01-01', '{"format":"coa","role":"vat","account":"445710","label":"TVA collectée"}'::jsonb, 'Plan comptable général (arrêté du 4 juin 1999); the FEC export defaults', true),
('account_map', 'FR', 'coa/05-expenses', '1900-01-01', '{"format":"coa","role":"expenses","account":"606000","label":"Achats non stockés de matières et fournitures"}'::jsonb, 'Plan comptable général (arrêté du 4 juin 1999); the FEC export defaults', true),
('account_map', 'FR', 'fec/vat_pending', '1900-01-01', '{"format":"fec","role":"vat_pending","account":"445740","label":"TVA collectée en attente"}'::jsonb, 'Plan comptable général 44574: the VAT an invoice carries before its tax point (the FEC export, #2355)', true),
('account_map', 'GB', 'sage/bank', '1900-01-01', '{"format":"sage","role":"bank","account":"1200"}'::jsonb, 'Sage 50 UK shipped chart and VAT codes (the Sage export)', true),
('account_map', 'GB', 'sage/debtors', '1900-01-01', '{"format":"sage","role":"debtors","account":"1100"}'::jsonb, 'Sage 50 UK shipped chart and VAT codes (the Sage export)', true),
('account_map', 'GB', 'sage/sales', '1900-01-01', '{"format":"sage","role":"sales","account":"4000"}'::jsonb, 'Sage 50 UK shipped chart and VAT codes (the Sage export)', true),
('account_map', 'GB', 'sage/tax_exempt', '1900-01-01', '{"format":"sage","role":"tax_exempt","tax_code":"T2"}'::jsonb, 'Sage 50 UK shipped chart and VAT codes (the Sage export)', true),
('account_map', 'GB', 'sage/tax_none', '1900-01-01', '{"format":"sage","role":"tax_none","tax_code":"T9"}'::jsonb, 'Sage 50 UK shipped chart and VAT codes (the Sage export)', true),
('account_map', 'GB', 'sage/tax_reduced', '1900-01-01', '{"format":"sage","role":"tax_reduced","tax_code":"T5"}'::jsonb, 'Sage 50 UK shipped chart and VAT codes (the Sage export)', true),
('account_map', 'GB', 'sage/tax_standard', '1900-01-01', '{"format":"sage","role":"tax_standard","tax_code":"T1"}'::jsonb, 'Sage 50 UK shipped chart and VAT codes (the Sage export)', true),
('account_map', 'GB', 'sage/tax_zero', '1900-01-01', '{"format":"sage","role":"tax_zero","tax_code":"T0"}'::jsonb, 'Sage 50 UK shipped chart and VAT codes (the Sage export)', true),
('account_map', 'IT', 'coa/00-chart', '1900-01-01', '{"format":"coa","role":"chart","account":"CC","label":"Codice civile — schema di bilancio"}'::jsonb, 'the chart bookkeepers of this country conventionally use (CC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'IT', 'coa/01-customers', '1900-01-01', '{"format":"coa","role":"customers","account":"1510","label":"Clienti"}'::jsonb, 'the chart bookkeepers of this country conventionally use (CC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'IT', 'coa/02-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"5810","label":"Ricavi per servizi"}'::jsonb, 'the chart bookkeepers of this country conventionally use (CC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'IT', 'coa/03-bank', '1900-01-01', '{"format":"coa","role":"bank","account":"1820","label":"Banca c/c"}'::jsonb, 'the chart bookkeepers of this country conventionally use (CC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'IT', 'coa/04-vat', '1900-01-01', '{"format":"coa","role":"vat","account":"2610","label":"IVA a debito"}'::jsonb, 'the chart bookkeepers of this country conventionally use (CC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'IT', 'coa/05-expenses', '1900-01-01', '{"format":"coa","role":"expenses","account":"7100","label":"Costi per servizi"}'::jsonb, 'the chart bookkeepers of this country conventionally use (CC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'LU', 'coa/00-chart', '1900-01-01', '{"format":"coa","role":"chart","account":"PCMN","label":"Plan comptable minimum normalisé"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PCMN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'LU', 'coa/01-customers', '1900-01-01', '{"format":"coa","role":"customers","account":"400","label":"Clients"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PCMN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'LU', 'coa/02-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"700","label":"Prestations de services"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PCMN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'LU', 'coa/03-bank', '1900-01-01', '{"format":"coa","role":"bank","account":"550","label":"Établissements de crédit"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PCMN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'LU', 'coa/04-vat', '1900-01-01', '{"format":"coa","role":"vat","account":"451","label":"TVA à payer"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PCMN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'LU', 'coa/05-expenses', '1900-01-01', '{"format":"coa","role":"expenses","account":"610","label":"Services et biens divers"}'::jsonb, 'the chart bookkeepers of this country conventionally use (PCMN): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'NL', 'coa/00-chart', '1900-01-01', '{"format":"coa","role":"chart","account":"RGS","label":"Referentie Grootboekschema"}'::jsonb, 'the chart bookkeepers of this country conventionally use (RGS): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'NL', 'coa/01-customers', '1900-01-01', '{"format":"coa","role":"customers","account":"1300","label":"Debiteuren"}'::jsonb, 'the chart bookkeepers of this country conventionally use (RGS): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'NL', 'coa/02-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"8000","label":"Opbrengst diensten"}'::jsonb, 'the chart bookkeepers of this country conventionally use (RGS): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'NL', 'coa/03-bank', '1900-01-01', '{"format":"coa","role":"bank","account":"1100","label":"Bank"}'::jsonb, 'the chart bookkeepers of this country conventionally use (RGS): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'NL', 'coa/04-vat', '1900-01-01', '{"format":"coa","role":"vat","account":"1500","label":"Af te dragen btw"}'::jsonb, 'the chart bookkeepers of this country conventionally use (RGS): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'NL', 'coa/05-expenses', '1900-01-01', '{"format":"coa","role":"expenses","account":"4000","label":"Algemene kosten"}'::jsonb, 'the chart bookkeepers of this country conventionally use (RGS): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'PT', 'coa/00-chart', '1900-01-01', '{"format":"coa","role":"chart","account":"SNC","label":"Sistema de Normalização Contabilística"}'::jsonb, 'the chart bookkeepers of this country conventionally use (SNC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'PT', 'coa/01-customers', '1900-01-01', '{"format":"coa","role":"customers","account":"211","label":"Clientes"}'::jsonb, 'the chart bookkeepers of this country conventionally use (SNC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'PT', 'coa/02-revenue', '1900-01-01', '{"format":"coa","role":"revenue","account":"721","label":"Prestações de serviços"}'::jsonb, 'the chart bookkeepers of this country conventionally use (SNC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'PT', 'coa/03-bank', '1900-01-01', '{"format":"coa","role":"bank","account":"12","label":"Depósitos à ordem"}'::jsonb, 'the chart bookkeepers of this country conventionally use (SNC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'PT', 'coa/04-vat', '1900-01-01', '{"format":"coa","role":"vat","account":"2433","label":"IVA liquidado"}'::jsonb, 'the chart bookkeepers of this country conventionally use (SNC): a suggestion the accountant re-points, as in the code it replaces (#671)', false),
('account_map', 'PT', 'coa/05-expenses', '1900-01-01', '{"format":"coa","role":"expenses","account":"62","label":"Fornecimentos e serviços externos"}'::jsonb, 'the chart bookkeepers of this country conventionally use (SNC): a suggestion the accountant re-points, as in the code it replaces (#671)', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(433);
