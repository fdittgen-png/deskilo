-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0432 (#2480, C4 of #2476) -- the rated boxes of the DE, FR, ES and CH return
-- forms select their lines by fiscal group, never by a percent: the `form_box`
-- domain holds, per box, the wording it prints and the groups it adds up (or,
-- for the catch-all box, every group but these). Which boxes exist and how
-- they total stays in the app.
--
--   * tax_reference_valid   learns the `form_box` shape.
--   * the seed: the fifteen rated boxes of the UStVA, CA3, Modelo 303 and MWST.
--
-- compute_vat_return and vat_return_summary are not touched: the server
-- returns lines by rate and category, the boxes are filled from them in the app
-- (a line's group is read from the country's rate rows). A filed period keeps
-- the version of a box in force at its end: a change takes effect from its date.

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
('form_box', 'CH', 'mwst/303', '2024-01-01', '{"label":"Normalsatz 8,1 %","groups":["standard"]}'::jsonb, 'ESTV MWST-Abrechnung (effektive Methode): Ziffern 303, 313, 343; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'CH', 'mwst/313', '2024-01-01', '{"label":"Reduzierter Satz 2,6 %","groups":["reduced"]}'::jsonb, 'ESTV MWST-Abrechnung (effektive Methode): Ziffern 303, 313, 343; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'CH', 'mwst/343', '2024-01-01', '{"label":"Beherbergungssatz 3,8 %","groups":["intermediate"]}'::jsonb, 'ESTV MWST-Abrechnung (effektive Methode): Ziffern 303, 313, 343; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'DE', 'ustva/Kz 35/36', '2024-01-01', '{"label":"Umsätze, die anderen Steuersätzen unterliegen","exclude_groups":["standard","reduced"]}'::jsonb, 'ELSTER UStVA: Kennzahlen 81, 86, 35/36; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'DE', 'ustva/Kz 81', '2024-01-01', '{"label":"Steuerpflichtige Umsätze zum Steuersatz von 19 %","groups":["standard"]}'::jsonb, 'ELSTER UStVA: Kennzahlen 81, 86, 35/36; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'DE', 'ustva/Kz 86', '2024-01-01', '{"label":"Steuerpflichtige Umsätze zum Steuersatz von 7 %","groups":["reduced"]}'::jsonb, 'ELSTER UStVA: Kennzahlen 81, 86, 35/36; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'ES', 'modelo303/01/03', '2024-01-01', '{"label":"Régimen general 4 %","groups":["super_reduced"]}'::jsonb, 'AEAT Modelo 303: casillas 01-09; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'ES', 'modelo303/04/06', '2024-01-01', '{"label":"Régimen general 10 %","groups":["reduced"]}'::jsonb, 'AEAT Modelo 303: casillas 01-09; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'ES', 'modelo303/07/09', '2024-01-01', '{"label":"Régimen general 21 %","groups":["standard"]}'::jsonb, 'AEAT Modelo 303: casillas 01-09; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'ES', 'modelo303/Otros', '2024-01-01', '{"label":"Régimen general, otros tipos","exclude_groups":["standard","reduced","super_reduced"]}'::jsonb, 'AEAT Modelo 303: casillas 01-09; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'FR', 'ca3/08', '2024-01-01', '{"label":"Taux normal 20 %","groups":["standard"]}'::jsonb, 'DGFiP formulaire 3310-CA3-SD: lignes 08, 09, 9B, 11, 14; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'FR', 'ca3/09', '2024-01-01', '{"label":"Taux réduit 5,5 %","groups":["reduced"]}'::jsonb, 'DGFiP formulaire 3310-CA3-SD: lignes 08, 09, 9B, 11, 14; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'FR', 'ca3/11', '2024-01-01', '{"label":"Taux particulier 2,1 %","groups":["super_reduced"]}'::jsonb, 'DGFiP formulaire 3310-CA3-SD: lignes 08, 09, 9B, 11, 14; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'FR', 'ca3/14', '2024-01-01', '{"label":"Opérations imposables à un autre taux","exclude_groups":["standard","intermediate","reduced","super_reduced"]}'::jsonb, 'DGFiP formulaire 3310-CA3-SD: lignes 08, 09, 9B, 11, 14; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true),
('form_box', 'FR', 'ca3/9B', '2024-01-01', '{"label":"Taux réduit 10 %","groups":["intermediate"]}'::jsonb, 'DGFiP formulaire 3310-CA3-SD: lignes 08, 09, 9B, 11, 14; the group each box takes is the fiscal group of the rate it was written for in the code it replaces (#2480)', true)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(432);
