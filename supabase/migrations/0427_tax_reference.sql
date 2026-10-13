-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0427 (#2477, C1 of #2476) -- the tax reference store.
--
-- A VAT value the law decides (a rate, an exemption text, a VAT id pattern,
-- the EU member set) is a ROW with its source and its validity, not a
-- constant in Dart and a copy in SQL. One platform-level table, read by
-- every signed-in person, written only by the platform administrator
-- through a function that validates the value's shape, versions (a change
-- closes the version in force on the new one's first day -- never an edit)
-- and writes the append-only authority audit.
--
--   tax_reference_valid(domain, value)   the shape of each domain's value
--   tax_reference(domain, country, on)   the versions in force on a date
--   tax_reference_history(domain, country, key)   every version, newest first
--   set_tax_reference(...)               platform owners only
--
-- Seeded from the Dart constants by tool/build_tax_reference_seed.dart so
-- no value is retyped; every VAT behaviour stays exactly as it was (no
-- consumer reads the store yet -- C2..C5 move them). A value nobody
-- verified keeps confirmed = false.

-- The shape of a domain's value. A domain without a shape here cannot be
-- written: its checkpoint (C3..C5) adds the shape with its consumer.
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
      return p_value = '{}'::jsonb;
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

create table if not exists public.tax_reference (
  id uuid primary key default gen_random_uuid(),
  domain text not null,
  country text not null check (country = '*' or country ~ '^[A-Z]{2}$'),
  key text not null check (btrim(key) <> ''),
  valid_from date not null,
  valid_to date,
  value jsonb not null,
  source text not null check (btrim(source) <> ''),
  confirmed boolean not null default false,
  constraint tax_reference_period check (valid_to is null or valid_to > valid_from),
  constraint tax_reference_shape check (public.tax_reference_valid(domain, value)),
  constraint tax_reference_version unique (domain, country, key, valid_from),
  -- Versions of one value never overlap: the version in force on a date is exact.
  constraint tax_reference_no_overlap
    exclude using gist (domain with =, country with =, key with =,
                        daterange(valid_from, valid_to, '[)') with &&)
);
select public.ensure_system_columns('tax_reference');
alter table public.tax_reference enable row level security;
revoke all on table public.tax_reference from anon, authenticated;
grant select on table public.tax_reference to authenticated;
drop policy if exists tax_reference_select on public.tax_reference;
create policy tax_reference_select on public.tax_reference for select to authenticated using (true);
drop policy if exists mcp_delegated_deny on public.tax_reference;
create policy mcp_delegated_deny on public.tax_reference as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The versions in force on p_on (today when null). A country asks for its
-- own rows and the '*' rows every country shares; null asks for all.
create or replace function public.tax_reference(p_domain text, p_country text, p_on date)
returns table (id uuid, domain text, country text, key text, valid_from date, valid_to date,
               value jsonb, source text, confirmed boolean)
language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return query
    select t.id, t.domain, t.country, t.key, t.valid_from, t.valid_to, t.value, t.source, t.confirmed
      from public.tax_reference t
     where (p_domain is null or t.domain = p_domain)
       and (p_country is null or t.country = upper(btrim(p_country)) or t.country = '*')
       and t.valid_from <= coalesce(p_on, current_date)
       and (t.valid_to is null or t.valid_to > coalesce(p_on, current_date))
     order by t.domain, t.country, t.key;
end;
$fn$;
revoke execute on function public.tax_reference(text, text, date) from public, anon;
grant execute on function public.tax_reference(text, text, date) to authenticated;

-- Every version, newest first; each argument narrows when given.
create or replace function public.tax_reference_history(p_domain text, p_country text, p_key text)
returns table (id uuid, domain text, country text, key text, valid_from date, valid_to date,
               value jsonb, source text, confirmed boolean)
language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return query
    select t.id, t.domain, t.country, t.key, t.valid_from, t.valid_to, t.value, t.source, t.confirmed
      from public.tax_reference t
     where (p_domain is null or t.domain = p_domain)
       and (p_country is null or t.country = upper(btrim(p_country)))
       and (p_key is null or t.key = p_key)
     order by t.domain, t.country, t.key, t.valid_from desc;
end;
$fn$;
revoke execute on function public.tax_reference_history(text, text, text) from public, anon;
grant execute on function public.tax_reference_history(text, text, text) to authenticated;

-- A new version of one value from p_valid_from on. The version in force is
-- closed on that day (valid_to = p_valid_from); nothing is ever edited, and
-- a version cannot start before or on the day the current one started.
create or replace function public.set_tax_reference(
  p_domain text, p_country text, p_key text, p_value jsonb,
  p_source text, p_confirmed boolean, p_valid_from date)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_country text := upper(btrim(coalesce(p_country, '')));
  v_key text := btrim(coalesce(p_key, ''));
  v_last public.tax_reference;
  v_row public.tax_reference;
begin
  if auth.uid() is null or public.mcp_is_delegated() or not public.is_platform_owner() then
    raise exception 'platform owners only';
  end if;
  if v_country <> '*' and v_country !~ '^[A-Z]{2}$' then
    raise exception 'the country is an ISO code or *';
  end if;
  if v_key = '' then raise exception 'a key is required'; end if;
  if p_source is null or btrim(p_source) = '' then
    raise exception 'a source is required: a value without one is a guess';
  end if;
  if p_valid_from is null then raise exception 'valid_from is required'; end if;
  if not public.tax_reference_valid(p_domain, p_value) then
    raise exception 'the value does not have the shape of the domain %', p_domain;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('tax_reference:' || p_domain || ':' || v_country || ':' || v_key, 0));

  select * into v_last from public.tax_reference t
   where t.domain = p_domain and t.country = v_country and t.key = v_key
   order by t.valid_from desc limit 1;
  if found then
    if p_valid_from <= v_last.valid_from then
      raise exception 'a new version must start after %, when the current one started', v_last.valid_from;
    end if;
    if v_last.valid_to is null then
      update public.tax_reference set valid_to = p_valid_from where id = v_last.id;
    elsif p_valid_from < v_last.valid_to then
      raise exception 'the version overlaps the one that ended on %', v_last.valid_to;
    end if;
  end if;

  insert into public.tax_reference (domain, country, key, valid_from, value, source, confirmed)
  values (p_domain, v_country, v_key, p_valid_from, p_value, btrim(p_source), coalesce(p_confirmed, false))
  returning * into v_row;

  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'tax_reference_set', 'platform_owner:' || auth.uid(),
          jsonb_build_object('domain', p_domain, 'country', v_country, 'key', v_key,
                             'valid_from', p_valid_from, 'confirmed', v_row.confirmed,
                             'source', v_row.source));

  return jsonb_build_object('id', v_row.id, 'domain', v_row.domain, 'country', v_row.country,
                            'key', v_row.key, 'valid_from', v_row.valid_from, 'valid_to', v_row.valid_to,
                            'value', v_row.value, 'source', v_row.source, 'confirmed', v_row.confirmed);
end;
$fn$;
revoke execute on function public.set_tax_reference(text, text, text, jsonb, text, boolean, date) from public, anon;
grant execute on function public.set_tax_reference(text, text, text, jsonb, text, boolean, date) to authenticated;

-- The seed: today's constants, as rows.
-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('eu_member', 'AT', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'BE', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'BG', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'CY', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'CZ', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'DE', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'DK', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'EE', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'ES', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'FI', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'FR', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'GR', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'HR', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'HU', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'IE', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'IT', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'LT', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'LU', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'LV', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'MT', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'NL', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'PL', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'PT', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'RO', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'SE', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'SI', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('eu_member', 'SK', 'member', '1900-01-01', '{}'::jsonb, 'place_of_supply.dart (#2354): the member states of the European Union', true),
('exemption_text', '*', 'exempt', '1900-01-01', '{"regime":"exempt","text":"VAT exempt — Council Directive 2006/112/EC (small enterprise scheme, art. 282–292)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', '*', 'exigibility_invoices', '1900-01-01', '{"regime":"exigibility_invoices","text":"VAT accounted for on invoices (accrual accounting)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', '*', 'exigibility_receipts', '1900-01-01', '{"regime":"exigibility_receipts","text":"VAT accounted for on receipts (cash accounting)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', '*', 'export', '1900-01-01', '{"regime":"export","text":"VAT not applicable — service supplied outside the European Union (art. 44 of Council Directive 2006/112/EC)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', '*', 'not_subject', '1900-01-01', '{"regime":"not_subject","text":"Not subject to VAT — outside the scope of Council Directive 2006/112/EC."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', '*', 'reverse_charge', '1900-01-01', '{"regime":"reverse_charge","text":"Reverse charge — VAT due by the customer (art. 196 of Council Directive 2006/112/EC)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'AT', 'exempt', '1900-01-01', '{"regime":"exempt","text":"Umsatzsteuerbefreit gemäß § 6 Abs. 1 Z 27 UStG (Kleinunternehmer)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'AT', 'exigibility_invoices', '1900-01-01', '{"regime":"exigibility_invoices","text":"Umsatzsteuer nach vereinbarten Entgelten (Soll-Versteuerung)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'AT', 'exigibility_receipts', '1900-01-01', '{"regime":"exigibility_receipts","text":"Umsatzsteuer nach vereinnahmten Entgelten (Ist-Versteuerung)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'AT', 'export', '1900-01-01', '{"regime":"export","text":"Nicht im Inland steuerbare Leistung — Leistungsort außerhalb der EU (Art. 44 der Richtlinie 2006/112/EG)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'AT', 'reverse_charge', '1900-01-01', '{"regime":"reverse_charge","text":"Steuerschuldnerschaft des Leistungsempfängers (Art. 196 der Richtlinie 2006/112/EG)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'BE', 'exempt', '1900-01-01', '{"regime":"exempt","text":"Régime particulier de franchise des petites entreprises (art. 56bis CTVA) — TVA non applicable."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'CA', 'exempt', '1900-01-01', '{"regime":"exempt","text":"Small supplier — not registered for GST/HST (Excise Tax Act, s. 148). / Petit fournisseur — non inscrit à la TPS/TVH."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'DE', 'exempt', '1900-01-01', '{"regime":"exempt","text":"Steuerbefreiung für Kleinunternehmer, § 19 UStG."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'DE', 'exigibility_invoices', '1900-01-01', '{"regime":"exigibility_invoices","text":"Umsatzsteuer nach vereinbarten Entgelten (Soll-Versteuerung)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'DE', 'exigibility_receipts', '1900-01-01', '{"regime":"exigibility_receipts","text":"Umsatzsteuer nach vereinnahmten Entgelten (Ist-Versteuerung)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'DE', 'export', '1900-01-01', '{"regime":"export","text":"Nicht im Inland steuerbare Leistung — Leistungsort außerhalb der EU (Art. 44 der Richtlinie 2006/112/EG)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'DE', 'not_subject', '1900-01-01', '{"regime":"not_subject","text":"Nicht umsatzsteuerbar — kein Unternehmer im Sinne des § 2 UStG."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'DE', 'reverse_charge', '1900-01-01', '{"regime":"reverse_charge","text":"Steuerschuldnerschaft des Leistungsempfängers (Art. 196 der Richtlinie 2006/112/EG)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'ES', 'exempt', '1900-01-01', '{"regime":"exempt","text":"Operación exenta de IVA (régimen de franquicia, art. 163 quinquies Ley 37/1992)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'ES', 'exigibility_invoices', '1900-01-01', '{"regime":"exigibility_invoices","text":"Devengo del IVA según el criterio general."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'ES', 'exigibility_receipts', '1900-01-01', '{"regime":"exigibility_receipts","text":"Régimen especial del criterio de caja."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'ES', 'export', '1900-01-01', '{"regime":"export","text":"Operación no sujeta — localizada fuera de la Unión Europea (art. 44 de la Directiva 2006/112/CE)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'ES', 'reverse_charge', '1900-01-01', '{"regime":"reverse_charge","text":"Inversión del sujeto pasivo (art. 196 de la Directiva 2006/112/CE)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'FR', 'exempt', '1900-01-01', '{"regime":"exempt","text":"TVA non applicable, art. 293 B du CGI"}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'FR', 'exigibility_invoices', '1900-01-01', '{"regime":"exigibility_invoices","text":"Option pour le paiement de la taxe d''après les débits."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'FR', 'exigibility_receipts', '1900-01-01', '{"regime":"exigibility_receipts","text":"TVA acquittée sur les encaissements."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'FR', 'export', '1900-01-01', '{"regime":"export","text":"TVA non applicable — prestation de services située hors de l''Union européenne (art. 44 de la directive 2006/112/CE)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'FR', 'not_subject', '1900-01-01', '{"regime":"not_subject","text":"TVA non applicable — opération hors champ (art. 256 B du CGI)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'FR', 'reverse_charge', '1900-01-01', '{"regime":"reverse_charge","text":"Autoliquidation — TVA due par le preneur (art. 196 de la directive 2006/112/CE)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'IT', 'exempt', '1900-01-01', '{"regime":"exempt","text":"Operazione senza applicazione dell''IVA ai sensi dell''art. 1, commi 54-89, L. 190/2014."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'IT', 'exigibility_invoices', '1900-01-01', '{"regime":"exigibility_invoices","text":"IVA esigibile secondo il criterio ordinario."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'IT', 'exigibility_receipts', '1900-01-01', '{"regime":"exigibility_receipts","text":"IVA per cassa (art. 32-bis D.L. 83/2012)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'IT', 'export', '1900-01-01', '{"regime":"export","text":"Operazione non soggetta — territorialmente fuori dall''Unione europea (art. 44 della direttiva 2006/112/CE)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'IT', 'reverse_charge', '1900-01-01', '{"regime":"reverse_charge","text":"Inversione contabile — imposta assolta dal committente (art. 196 della direttiva 2006/112/CE)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'LU', 'exempt', '1900-01-01', '{"regime":"exempt","text":"Franchise de TVA, art. 57 de la loi TVA."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'NL', 'exempt', '1900-01-01', '{"regime":"exempt","text":"Vrijgesteld van btw (kleineondernemersregeling, art. 25 Wet OB)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'NL', 'reverse_charge', '1900-01-01', '{"regime":"reverse_charge","text":"Btw verlegd (art. 196 richtlijn 2006/112/EG)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('exemption_text', 'PT', 'reverse_charge', '1900-01-01', '{"regime":"reverse_charge","text":"Autoliquidação (art. 196.º da Diretiva 2006/112/CE)."}'::jsonb, 'vat_compliance.dart (#878, #2356): Council Directive 2006/112/EC and the member state''s own law; typed in code, not re-verified', false),
('rate', 'AT', 'intermediate', '1900-01-01', '{"label":"Ermäßigt 13 %","percent":13.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'AT', 'reduced', '1900-01-01', '{"label":"Ermäßigt 10 %","percent":10.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'AT', 'standard', '1900-01-01', '{"label":"Normalsatz 20 %","percent":20.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'BE', 'intermediate', '1900-01-01', '{"label":"Verlaagd 12 %","percent":12.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'BE', 'reduced', '1900-01-01', '{"label":"Verlaagd 6 %","percent":6.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'BE', 'standard', '1900-01-01', '{"label":"Standaard 21 %","percent":21.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'BG', 'reduced', '1900-01-01', '{"label":"Намалена 9 %","percent":9.0,"group":"reduced","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'BG', 'standard', '1900-01-01', '{"label":"Стандартна 20 %","percent":20.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CA', 'standard-13', '1900-01-01', '{"label":"HST 13 % (ON)","percent":13.0,"group":"standard","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CA', 'standard-14', '1900-01-01', '{"label":"HST 14 % (NS)","percent":14.0,"group":"standard","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CA', 'standard-14.975', '1900-01-01', '{"label":"GST 5 % + QST 9,975 % (QC)","percent":14.975,"group":"standard","category":"S","position":4}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CA', 'standard-15', '1900-01-01', '{"label":"HST 15 % (NB/NL/PE)","percent":15.0,"group":"standard","category":"S","position":3}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CA', 'standard-5', '1900-01-01', '{"label":"GST 5 % (AB/BC/MB/NT/NU/SK/YT)","percent":5.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CH', 'exempt', '1900-01-01', '{"label":"Ausgenommen (Vermietung)","percent":0.0,"group":"exempt","category":"E","exemption_reason":"Von der Steuer ausgenommen (Art. 21 Abs. 2 Ziff. 21 MWSTG)","position":3}'::jsonb, 'vat_catalogue.dart (#2359, #2360): the statutory reason of the exempt line; typed in code, not re-verified', false),
('rate', 'CH', 'intermediate', '2024-01-01', '{"label":"Hébergement 3,8 %","percent":3.8,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CH', 'reduced', '2024-01-01', '{"label":"Réduit 2,6 %","percent":2.6,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CH', 'standard', '2024-01-01', '{"label":"Normal 8,1 %","percent":8.1,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CY', 'intermediate', '1900-01-01', '{"label":"Reduced 9 %","percent":9.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CY', 'reduced', '1900-01-01', '{"label":"Reduced 5 %","percent":5.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CY', 'standard', '1900-01-01', '{"label":"Standard 19 %","percent":19.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CZ', 'reduced', '1900-01-01', '{"label":"Snížená 12 %","percent":12.0,"group":"reduced","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'CZ', 'standard', '1900-01-01', '{"label":"Základní 21 %","percent":21.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'DE', 'reduced', '1900-01-01', '{"label":"Ermäßigt 7 %","percent":7.0,"group":"reduced","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'DE', 'standard', '1900-01-01', '{"label":"Regelsatz 19 %","percent":19.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'DK', 'standard', '1900-01-01', '{"label":"Standard 25 %","percent":25.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'EE', 'intermediate', '1900-01-01', '{"label":"Vähendatud 13 %","percent":13.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'EE', 'reduced', '1900-01-01', '{"label":"Vähendatud 9 %","percent":9.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'EE', 'standard', '2025-07-01', '{"label":"Standardmäär 24 %","percent":24.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'ES', 'reduced', '1900-01-01', '{"label":"Reducido 10 %","percent":10.0,"group":"reduced","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'ES', 'standard', '1900-01-01', '{"label":"General 21 %","percent":21.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'ES', 'super_reduced', '1900-01-01', '{"label":"Superreducido 4 %","percent":4.0,"group":"super_reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'FI', 'intermediate', '2025-01-01', '{"label":"Alennettu 13,5 %","percent":13.5,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'FI', 'reduced', '1900-01-01', '{"label":"Alennettu 10 %","percent":10.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'FI', 'standard', '2024-09-01', '{"label":"Yleinen 25,5 %","percent":25.5,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'FR', 'intermediate', '1900-01-01', '{"label":"Intermédiaire 10 %","percent":10.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'FR', 'reduced', '1900-01-01', '{"label":"Réduit 5,5 %","percent":5.5,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'FR', 'standard', '1900-01-01', '{"label":"Standard 20 %","percent":20.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'FR', 'super_reduced', '1900-01-01', '{"label":"Particulier 2,1 %","percent":2.1,"group":"super_reduced","category":"S","position":3}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'GB', 'exempt', '1900-01-01', '{"label":"Exempt (land)","percent":0.0,"group":"exempt","category":"E","exemption_reason":"VAT Act 1994, Schedule 9, Group 1 (land)","position":3}'::jsonb, 'vat_catalogue.dart (#2359, #2360): the statutory reason of the exempt line; typed in code, not re-verified', false),
('rate', 'GB', 'reduced', '1997-09-01', '{"label":"Reduced 5 %","percent":5.0,"group":"reduced","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#2359): VAT Act 1994; not re-verified since the catalogue was written', false),
('rate', 'GB', 'standard', '2011-01-04', '{"label":"Standard 20 %","percent":20.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#2359): VAT Act 1994; not re-verified since the catalogue was written', false),
('rate', 'GB', 'zero', '1900-01-01', '{"label":"Zero 0 %","percent":0.0,"group":"zero","category":"Z","position":2}'::jsonb, 'vat_catalogue.dart (#2359): VAT Act 1994; not re-verified since the catalogue was written', false),
('rate', 'GR', 'intermediate', '1900-01-01', '{"label":"Μειωμένος 13 %","percent":13.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'GR', 'reduced', '1900-01-01', '{"label":"Μειωμένος 6 %","percent":6.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'GR', 'standard', '1900-01-01', '{"label":"Κανονικός 24 %","percent":24.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'HR', 'intermediate', '1900-01-01', '{"label":"Snižena 13 %","percent":13.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'HR', 'reduced', '1900-01-01', '{"label":"Snižena 5 %","percent":5.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'HR', 'standard', '1900-01-01', '{"label":"Standardna 25 %","percent":25.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'HU', 'intermediate', '1900-01-01', '{"label":"Kedvezményes 18 %","percent":18.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'HU', 'reduced', '1900-01-01', '{"label":"Kedvezményes 5 %","percent":5.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'HU', 'standard', '1900-01-01', '{"label":"Általános 27 %","percent":27.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'IE', 'intermediate', '1900-01-01', '{"label":"Reduced 13.5 %","percent":13.5,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'IE', 'reduced', '1900-01-01', '{"label":"Reduced 9 %","percent":9.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'IE', 'standard', '1900-01-01', '{"label":"Standard 23 %","percent":23.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'IE', 'super_reduced', '1900-01-01', '{"label":"Livestock 4.8 %","percent":4.8,"group":"super_reduced","category":"S","position":3}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'IT', 'intermediate', '1900-01-01', '{"label":"Ridotta 10 %","percent":10.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'IT', 'reduced', '1900-01-01', '{"label":"Ridotta 5 %","percent":5.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'IT', 'standard', '1900-01-01', '{"label":"Ordinaria 22 %","percent":22.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'IT', 'super_reduced', '1900-01-01', '{"label":"Minima 4 %","percent":4.0,"group":"super_reduced","category":"S","position":3}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'LT', 'intermediate', '1900-01-01', '{"label":"Lengvatinis 9 %","percent":9.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'LT', 'reduced', '1900-01-01', '{"label":"Lengvatinis 5 %","percent":5.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'LT', 'standard', '1900-01-01', '{"label":"Standartinis 21 %","percent":21.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'LU', 'intermediate', '1900-01-01', '{"label":"Intermédiaire 14 %","percent":14.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'LU', 'reduced', '1900-01-01', '{"label":"Réduit 8 %","percent":8.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'LU', 'standard', '1900-01-01', '{"label":"Normal 17 %","percent":17.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'LU', 'super_reduced', '1900-01-01', '{"label":"Super-réduit 3 %","percent":3.0,"group":"super_reduced","category":"S","position":3}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'LV', 'intermediate', '1900-01-01', '{"label":"Samazinātā 12 %","percent":12.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'LV', 'reduced', '1900-01-01', '{"label":"Samazinātā 5 %","percent":5.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'LV', 'standard', '1900-01-01', '{"label":"Standarta 21 %","percent":21.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'MT', 'intermediate', '1900-01-01', '{"label":"Reduced 7 %","percent":7.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'MT', 'reduced', '1900-01-01', '{"label":"Reduced 5 %","percent":5.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'MT', 'standard', '1900-01-01', '{"label":"Standard 18 %","percent":18.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'NL', 'reduced', '1900-01-01', '{"label":"Laag 9 %","percent":9.0,"group":"reduced","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'NL', 'standard', '1900-01-01', '{"label":"Hoog 21 %","percent":21.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'NO', 'intermediate', '1900-01-01', '{"label":"Næringsmidler 15 %","percent":15.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'NO', 'reduced', '1900-01-01', '{"label":"Redusert 12 %","percent":12.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'NO', 'standard', '1900-01-01', '{"label":"Alminnelig 25 %","percent":25.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'PL', 'intermediate', '1900-01-01', '{"label":"Obniżona 8 %","percent":8.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'PL', 'reduced', '1900-01-01', '{"label":"Obniżona 5 %","percent":5.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'PL', 'standard', '1900-01-01', '{"label":"Podstawowa 23 %","percent":23.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'PT', 'intermediate', '1900-01-01', '{"label":"Intermédia 13 %","percent":13.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'PT', 'reduced', '1900-01-01', '{"label":"Reduzida 6 %","percent":6.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'PT', 'standard', '1900-01-01', '{"label":"Normal 23 %","percent":23.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'RO', 'reduced', '2025-08-01', '{"label":"Redusă 11 %","percent":11.0,"group":"reduced","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'RO', 'standard', '2025-08-01', '{"label":"Standard 21 %","percent":21.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'SE', 'intermediate', '1900-01-01', '{"label":"Reducerad 12 %","percent":12.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'SE', 'reduced', '1900-01-01', '{"label":"Reducerad 6 %","percent":6.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'SE', 'standard', '1900-01-01', '{"label":"Standard 25 %","percent":25.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'SI', 'intermediate', '1900-01-01', '{"label":"Znižana 9,5 %","percent":9.5,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'SI', 'reduced', '1900-01-01', '{"label":"Znižana 5 %","percent":5.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'SI', 'standard', '1900-01-01', '{"label":"Splošna 22 %","percent":22.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'SK', 'intermediate', '2025-01-01', '{"label":"Znížená 19 %","percent":19.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'SK', 'reduced', '2025-01-01', '{"label":"Znížená 5 %","percent":5.0,"group":"reduced","category":"S","position":2}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('rate', 'SK', 'standard', '2025-01-01', '{"label":"Základná 23 %","percent":23.0,"group":"standard","category":"S","position":0}'::jsonb, 'vat_catalogue.dart (#534): verified 2026-08 against the Tax Foundation EU table, skatteetaten.no, estv.admin.ch and CRA', true),
('vat_id_pattern', 'AT', 'vat_id', '1900-01-01', '{"pattern":"U\\d{8}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'BE', 'vat_id', '1900-01-01', '{"pattern":"[01]\\d{9}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'BG', 'vat_id', '1900-01-01', '{"pattern":"\\d{9,10}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'CH', 'vat_id', '1900-01-01', '{"pattern":"E\\d{9}(MWST|TVA|IVA)?"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'CY', 'vat_id', '1900-01-01', '{"pattern":"\\d{8}[A-Z]"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'CZ', 'vat_id', '1900-01-01', '{"pattern":"\\d{8,10}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'DE', 'vat_id', '1900-01-01', '{"pattern":"\\d{9}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'DK', 'vat_id', '1900-01-01', '{"pattern":"\\d{8}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'EE', 'vat_id', '1900-01-01', '{"pattern":"\\d{9}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'EL', 'vat_id', '1900-01-01', '{"pattern":"\\d{9}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'ES', 'vat_id', '1900-01-01', '{"pattern":"[A-Z0-9]\\d{7}[A-Z0-9]"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'FI', 'vat_id', '1900-01-01', '{"pattern":"\\d{8}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'FR', 'vat_id', '1900-01-01', '{"pattern":"[A-Z0-9]{2}\\d{9}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'GB', 'vat_id', '1900-01-01', '{"pattern":"\\d{9}|\\d{12}|GD\\d{3}|HA\\d{3}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'HR', 'vat_id', '1900-01-01', '{"pattern":"\\d{11}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'HU', 'vat_id', '1900-01-01', '{"pattern":"\\d{8}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'IE', 'vat_id', '1900-01-01', '{"pattern":"\\d{7}[A-Z]{1,2}|\\d[A-Z+*]\\d{5}[A-Z]"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'IT', 'vat_id', '1900-01-01', '{"pattern":"\\d{11}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'LT', 'vat_id', '1900-01-01', '{"pattern":"\\d{9}|\\d{12}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'LU', 'vat_id', '1900-01-01', '{"pattern":"\\d{8}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'LV', 'vat_id', '1900-01-01', '{"pattern":"\\d{11}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'MT', 'vat_id', '1900-01-01', '{"pattern":"\\d{8}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'NL', 'vat_id', '1900-01-01', '{"pattern":"\\d{9}B\\d{2}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'PL', 'vat_id', '1900-01-01', '{"pattern":"\\d{10}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'PT', 'vat_id', '1900-01-01', '{"pattern":"\\d{9}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'RO', 'vat_id', '1900-01-01', '{"pattern":"\\d{2,10}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'SE', 'vat_id', '1900-01-01', '{"pattern":"\\d{12}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'SI', 'vat_id', '1900-01-01', '{"pattern":"\\d{8}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'SK', 'vat_id', '1900-01-01', '{"pattern":"\\d{10}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false),
('vat_id_pattern', 'XI', 'vat_id', '1900-01-01', '{"pattern":"\\d{9}|\\d{12}|GD\\d{3}|HA\\d{3}"}'::jsonb, 'vat_compliance.dart (#878, #2359, #2360): the VIES syntax of the identifier body; typed in code, not re-verified', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(427);
