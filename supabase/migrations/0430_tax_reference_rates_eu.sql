-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0430 (#2478, C2 of #2476) -- the rate catalogue, the EU member set, the
-- statutory exemption texts and the VAT id patterns are READ from the tax
-- reference store; the SQL copy of the EU member list is gone.
--
--   * tax_reference_valid   learns the shapes of two domains the app reads
--                           (`catalogue_note`, `group_example`) and of the
--                           alias `eu_member` row ({alias_of}: Greece's VAT
--                           prefix EL is GR).
--   * eu_country_code / is_eu_country   answer from the `eu_member` rows in
--                           force today (the alias row replaces the
--                           `when 'EL' then 'GR'` branch, the table the
--                           27-code array). Same results for every input.
--                           security definer: a delegated (MCP) session is
--                           denied the table by its restrictive policy, and
--                           must still get the answer the person gets.
--   * supply_vat_category   was immutable and now calls a table reader:
--                           stable, body untouched.
--   * the seed adds only what 0427 did not hold: the alias row, the `EX`
--     small-enterprise text, the catalogue notes and the group examples.
--
-- Nothing else reads the store yet from SQL (C3 moves the issuing gate).

create or replace function public.tax_reference_valid(p_domain text, p_value jsonb)
returns boolean language plpgsql immutable set search_path = public as $fn$
declare
  v_allowed text[];
begin
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
      return p_value = '{}'::jsonb
          or (p_value ? 'alias_of'
              and not exists (select 1 from jsonb_object_keys(p_value) k where k <> 'alias_of')
              and jsonb_typeof(p_value -> 'alias_of') = 'string'
              and (p_value ->> 'alias_of') ~ '^[A-Z]{2}$');
    when 'catalogue_note' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> 'text') then return false; end if;
      return jsonb_typeof(p_value -> 'text') = 'string' and btrim(p_value ->> 'text') <> '';
    when 'group_example' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['group', 'text', 'position'])) then return false; end if;
      if jsonb_typeof(p_value -> 'group') is distinct from 'string'
         or (p_value ->> 'group') <> all (array['standard', 'intermediate', 'reduced', 'super_reduced',
                                               'zero', 'exempt', 'not_subject', 'deposit', 'excise']) then
        return false;
      end if;
      if p_value ? 'position' and (jsonb_typeof(p_value -> 'position') <> 'number'
                                   or (p_value ->> 'position') !~ '^[0-9]+$') then return false; end if;
      return jsonb_typeof(p_value -> 'text') = 'string' and btrim(p_value ->> 'text') <> '';
    when 'exemption_text' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['regime', 'text'])) then return false; end if;
      return jsonb_typeof(p_value -> 'regime') = 'string' and btrim(p_value ->> 'regime') <> ''
         and jsonb_typeof(p_value -> 'text') = 'string' and btrim(p_value ->> 'text') <> '';
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

-- ── one EU set, as rows ───────────────────────────────────────────────
create or replace function public.eu_country_code(p_code text)
returns text language sql stable security definer set search_path = public as $fn$
  select coalesce(
    (select t.value ->> 'alias_of'
       from public.tax_reference t
      where t.domain = 'eu_member' and t.key = 'alias'
        and t.country = upper(btrim(coalesce(p_code, '')))
        and t.valid_from <= current_date
        and (t.valid_to is null or t.valid_to > current_date)
      limit 1),
    upper(btrim(coalesce(p_code, ''))));
$fn$;
revoke execute on function public.eu_country_code(text) from public, anon;
grant execute on function public.eu_country_code(text) to authenticated, service_role;

create or replace function public.is_eu_country(p_code text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from public.tax_reference t
     where t.domain = 'eu_member' and t.key = 'member'
       and t.country = public.eu_country_code(p_code)
       and t.valid_from <= current_date
       and (t.valid_to is null or t.valid_to > current_date));
$fn$;
revoke execute on function public.is_eu_country(text) from public, anon;
grant execute on function public.is_eu_country(text) to authenticated, service_role;

alter function public.supply_vat_category(text, text, text, text, text, text, boolean) stable;

-- The seed: what 0427 did not hold.
-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('catalogue_note', 'CA', 'note', '1900-01-01', '{"text":"Canada taxes by province: keep the line for yours (GST, HST, or GST+PST/QST) and delete the rest."}'::jsonb, 'vat_catalogue.dart (#534, #2359, #2360, #2361): the caveat shown beside the seed button; typed in code, not re-verified', false),
('catalogue_note', 'CH', 'note', '1900-01-01', '{"text":"A package of services is taxed at the normal rate; a bare letting of rooms is exempt (art. 21 MWSTG) unless you opted (art. 22): say which on the legal identity. The 3.8 % special rate applies to accommodation only. If the vote of 29 November 2026 passes, 8.5 % and 4.0 % apply from 2028: change them by law then."}'::jsonb, 'vat_catalogue.dart (#534, #2359, #2360, #2361): the caveat shown beside the seed button; typed in code, not re-verified', false),
('catalogue_note', 'CH', 'note_vote_passed', '1900-01-01', '{"text":"The vote passed: \"Change by law\" proposes the new rate and its date."}'::jsonb, 'vat_catalogue.dart (#534, #2359, #2360, #2361): the caveat shown beside the seed button; typed in code, not re-verified', false),
('catalogue_note', 'GB', 'note', '1900-01-01', '{"text":"A bare desk or office licence is exempt (VAT Act 1994 Sch 9 Group 1) unless you opted to tax the building; a serviced package of facilities is standard-rated. Keep the lines that apply."}'::jsonb, 'vat_catalogue.dart (#534, #2359, #2360, #2361): the caveat shown beside the seed button; typed in code, not re-verified', false),
('catalogue_note', 'US', 'note', '1900-01-01', '{"text":"The US has no federal VAT — sales tax is set by state and locality. Add your local combined rate manually."}'::jsonb, 'vat_catalogue.dart (#534, #2359, #2360, #2361): the caveat shown beside the seed button; typed in code, not re-verified', false),
('eu_member', 'EL', 'alias', '1900-01-01', '{"alias_of":"GR"}'::jsonb, 'place_of_supply.dart (#2354): EL is Greece''s VAT-number prefix; the ISO code of the member state is GR', true),
('exemption_text', '*', 'exempt_ex', '1900-01-01', '{"regime":"exempt_ex","text":"VAT exempt — small enterprise scheme for a supplier established in another member state (art. 284 of Council Directive 2006/112/EC), identification number {vat_id}."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('group_example', '*', 'deposit', '1900-01-01', '{"group":"deposit","text":"Refundable deposit","position":3}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', '*', 'excise', '1900-01-01', '{"group":"excise","text":"Beer, spirits: excise inside the price, standard VAT","position":2}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', '*', 'exempt', '1900-01-01', '{"group":"exempt","text":"Exempt supplies","position":4}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', '*', 'not_subject', '1900-01-01', '{"group":"not_subject","text":"Not subject to VAT","position":5}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', '*', 'reduced', '1900-01-01', '{"group":"reduced","text":"Books, periodicals, food, non-alcoholic drinks","position":1}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', '*', 'standard', '1900-01-01', '{"group":"standard","text":"Services, alcoholic and sugar drinks","position":0}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'AT', 'excise', '1900-01-01', '{"group":"excise","text":"Bier, Spirituosen: Verbrauchsteuer im Preis, Regelsatz","position":2}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'AT', 'exempt', '1900-01-01', '{"group":"exempt","text":"Steuerfreie Umsätze (§ 4 UStG)","position":3}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'AT', 'not_subject', '1900-01-01', '{"group":"not_subject","text":"Kleinunternehmer (§ 19 UStG)","position":4}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'AT', 'reduced', '1900-01-01', '{"group":"reduced","text":"Bücher, Zeitungen, Lebensmittel zum Mitnehmen","position":1}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'AT', 'standard', '1900-01-01', '{"group":"standard","text":"Dienstleistungen, Getränke, Pfand (mit der Ware besteuert)","position":0}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'DE', 'excise', '1900-01-01', '{"group":"excise","text":"Bier, Spirituosen: Verbrauchsteuer im Preis, Regelsatz","position":2}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'DE', 'exempt', '1900-01-01', '{"group":"exempt","text":"Steuerfreie Umsätze (§ 4 UStG)","position":3}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'DE', 'not_subject', '1900-01-01', '{"group":"not_subject","text":"Kleinunternehmer (§ 19 UStG)","position":4}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'DE', 'reduced', '1900-01-01', '{"group":"reduced","text":"Bücher, Zeitungen, Lebensmittel zum Mitnehmen","position":1}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'DE', 'standard', '1900-01-01', '{"group":"standard","text":"Dienstleistungen, Getränke, Pfand (mit der Ware besteuert)","position":0}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'FR', 'deposit', '1900-01-01', '{"group":"deposit","text":"Consigne remboursable — hors champ de la TVA","position":5}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'FR', 'excise', '1900-01-01', '{"group":"excise","text":"Bière, spiritueux : accises dans le prix, TVA 20 %","position":4}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'FR', 'exempt', '1900-01-01', '{"group":"exempt","text":"Formation, opérations exonérées (art. 261 CGI)","position":6}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'FR', 'intermediate', '1900-01-01', '{"group":"intermediate","text":"Repas et boissons sans alcool consommés sur place","position":1}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'FR', 'not_subject', '1900-01-01', '{"group":"not_subject","text":"Association non assujettie (art. 293 B CGI)","position":7}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'FR', 'reduced', '1900-01-01', '{"group":"reduced","text":"Livres, boissons sans alcool à emporter, produits alimentaires","position":2}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'FR', 'standard', '1900-01-01', '{"group":"standard","text":"Prestations, boissons alcoolisées, sodas (taxe soda en sus)","position":0}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false),
('group_example', 'FR', 'super_reduced', '1900-01-01', '{"group":"super_reduced","text":"Presse","position":3}'::jsonb, 'vat_catalogue.dart (#947): starting points for the owner, not tax advice; typed in code, not re-verified', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(430);
