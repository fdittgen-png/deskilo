-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (invoice_essentials_missing and tax_reference_valid restated whole;
-- the Spanish issuing gate gets a new version and its predecessor ends on
-- that day; no issued document, no filed period is touched)
--
-- 0600 (#2363) -- the remaining Spanish and Italian
-- invoice rules, as rows of the tax reference store:
--   * `threshold` learns three effects: `annual_operations` (the yearly
--     operations with one customer the modelo 347 lists, ES `modelo347`),
--     `simplified_invoice` (the total up to which a simplified invoice is
--     enough: ES 400 EUR, RD 1619/2012 art. 4; GB 250 GBP, the figure 0417
--     wrote into this function) and `stamp_duty` (the total of an Italian
--     document without VAT above which the imposta di bollo is due, the
--     row's `charge_cents` the duty), and the optional `charge_cents`;
--   * `exemption_text` IT `stamp_duty`: the line a document that owes the
--     duty prints (the FatturaPA's `DatiBollo` reads the same row);
--   * `issuing_gate` learns `outside_vat_postal_codes`: the postal-code
--     prefixes of sites where the State's VAT does not apply. Spain's new
--     version names the Canary Islands (35, 38: IGIC), Ceuta (51) and
--     Melilla (52: IPSI); a seller there is refused by name
--     (`territory_outside_vat`) until those taxes are modelled;
--   * invoice_essentials_missing reads the simplified-invoice line from the
--     row of the seller's country instead of a figure in its body.
-- Spain and Italy stay refused (`seller_country_unsupported`): the gates lift
-- with their national channels (Verifactu, SdI), not here.

-- ── 1. the shapes ─────────────────────────────────────────────────────
-- Restated whole (the body of 0433 with 0434, 0455, 0480 and 0599 applied):
-- `threshold` learns `charge_cents` and three effects, `issuing_gate` learns
-- `outside_vat_postal_codes`.
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
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['cents', 'effect', 'currency', 'charge_cents'])) then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'cents') = 'number' and (p_value ->> 'cents') ~ '^[1-9][0-9]*$'
         and (p_value ->> 'effect') = any (array['next_year', 'immediate', 'annual_operations', 'simplified_invoice', 'stamp_duty'])
         and jsonb_typeof(p_value -> 'currency') = 'string' and (p_value ->> 'currency') ~ '^[A-Z]{3}$'
         and (not p_value ? 'charge_cents'
              or (jsonb_typeof(p_value -> 'charge_cents') = 'number'
                  and (p_value ->> 'charge_cents') ~ '^[1-9][0-9]*$')), false);
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
                  where k <> all (array['supported', 'requires_tax_number', 'national_channel_required', 'currency', 'tax_system',
                           'outside_vat_postal_codes'])) then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'supported') = 'boolean'
         and jsonb_typeof(p_value -> 'requires_tax_number') = 'boolean'
         and jsonb_typeof(p_value -> 'national_channel_required') = 'boolean'
         and (not p_value ? 'currency'
              or (jsonb_typeof(p_value -> 'currency') = 'string' and (p_value ->> 'currency') ~ '^[A-Z]{3}$'))
         and (not p_value ? 'tax_system'
              or (jsonb_typeof(p_value -> 'tax_system') = 'string'
                  and (p_value ->> 'tax_system') = any (array['vat', 'sales_tax'])))
         and (not p_value ? 'outside_vat_postal_codes'
              or (jsonb_typeof(p_value -> 'outside_vat_postal_codes') = 'array'
                  and not exists (select 1 from jsonb_array_elements(p_value -> 'outside_vat_postal_codes') e
                                   where jsonb_typeof(e) <> 'string'
                                      or (e #>> '{}') !~ '^[0-9A-Z]{1,5}$'))), false);
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
         or (p_value ->> 'format') <> all (array['coa', 'fec', 'datev', 'sage', 'saf_t', 'ch_kmu']) then return false; end if;
      if jsonb_typeof(p_value -> 'role') is distinct from 'string'
         or btrim(p_value ->> 'role') = '' then return false; end if;
      if p_value ? 'label' and jsonb_typeof(p_value -> 'label') <> 'string' then return false; end if;
      if p_value ? 'account' and (jsonb_typeof(p_value -> 'account') <> 'string'
                                  or btrim(p_value ->> 'account') = '') then return false; end if;
      if p_value ? 'tax_code' and (jsonb_typeof(p_value -> 'tax_code') <> 'string'
                                   or btrim(p_value ->> 'tax_code') = '') then return false; end if;
      return p_value ? 'account' or p_value ? 'tax_code';
    when 'sales_tax' then
      -- The tax a postal code carries, one component per jurisdiction.
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['state', 'components'])) then return false; end if;
      if jsonb_typeof(p_value -> 'state') is distinct from 'string'
         or (p_value ->> 'state') !~ '^[A-Z]{2}$' then return false; end if;
      if jsonb_typeof(p_value -> 'components') is distinct from 'array'
         or jsonb_array_length(p_value -> 'components') = 0 then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where jsonb_typeof(c) <> 'object') then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where exists (select 1 from jsonb_object_keys(c) k
                                 where k <> all (array['level', 'label', 'percent']))) then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where jsonb_typeof(c -> 'level') is distinct from 'string'
                     or (c ->> 'level') <> all (array['state', 'county', 'city', 'district'])
                     or jsonb_typeof(c -> 'label') is distinct from 'string'
                     or btrim(c ->> 'label') = ''
                     or jsonb_typeof(c -> 'percent') is distinct from 'number') then return false; end if;
      return not exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                          where (c ->> 'percent')::numeric < 0 or (c ->> 'percent')::numeric > 20);
    when 'retention' then
      -- How long a kind of record is kept, and from when the clock runs.
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['years', 'from'])) then return false; end if;
      if jsonb_typeof(p_value -> 'years') is distinct from 'number'
         or (p_value ->> 'years') !~ '^[0-9]+$' then return false; end if;
      if (p_value ->> 'years')::int < 1 or (p_value ->> 'years')::int > 100 then return false; end if;
      return jsonb_typeof(p_value -> 'from') = 'string'
         and (p_value ->> 'from') = any (array['fiscal_year_end', 'document_date']);
    when 'rate_component' then
      -- The taxes inside a combined rate: they add up to the rate.
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['percent', 'components'])) then return false; end if;
      if jsonb_typeof(p_value -> 'percent') is distinct from 'number' then return false; end if;
      if (p_value ->> 'percent')::numeric <= 0 or (p_value ->> 'percent')::numeric > 99.999 then return false; end if;
      if jsonb_typeof(p_value -> 'components') is distinct from 'array'
         or jsonb_array_length(p_value -> 'components') = 0 then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where jsonb_typeof(c) <> 'object') then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where exists (select 1 from jsonb_object_keys(c) k
                                 where k <> all (array['scheme', 'authority', 'percent']))) then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where jsonb_typeof(c -> 'scheme') is distinct from 'string'
                     or btrim(c ->> 'scheme') = ''
                     or jsonb_typeof(c -> 'authority') is distinct from 'string'
                     or btrim(c ->> 'authority') = ''
                     or jsonb_typeof(c -> 'percent') is distinct from 'number') then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where (c ->> 'percent')::numeric <= 0) then return false; end if;
      return (select abs(sum((c ->> 'percent')::numeric) - (p_value ->> 'percent')::numeric) < 0.0000001
                from jsonb_array_elements(p_value -> 'components') c);
    when 'taxability' then
      -- Whether a kind of line is taxed in a state.
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> 'status') then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'status') = 'string'
         and (p_value ->> 'status') = any (array['taxable', 'exempt', 'not_applicable']), false);
    else
      return false;
  end case;
end;
$fn$;
revoke execute on function public.tax_reference_valid(text, jsonb) from public, anon, authenticated;

-- ── 2. the Spanish gate's version in force ends where its successor begins ──
do $migration$
declare
  v_rows int;
begin
  update public.tax_reference
     set valid_to = date '2026-10-25'
   where domain = 'issuing_gate' and country = 'ES' and key = 'gate'
     and valid_from = date '1900-01-01' and valid_to is null;
  get diagnostics v_rows = row_count;
  -- one open version ends; any other count would leave two in force or none
  if v_rows <> 1 then
    raise exception '0600: % open Spanish gate versions closed, expected 1', v_rows;
  end if;
end
$migration$;

-- ── 3. the rows ───────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('exemption_text', 'IT', 'stamp_duty', '1900-01-01', '{"regime":"stamp_duty","text":"Imposta di bollo assolta in modo virtuale ai sensi del D.M. 17 giugno 2014."}'::jsonb, 'DM 17 June 2014 art. 6 (the duty on electronic invoices paid virtually) (#2363); not yet confirmed', false),
('issuing_gate', 'ES', 'gate', '2026-10-25', '{"supported":true,"requires_tax_number":true,"national_channel_required":true,"outside_vat_postal_codes":["35","38","51","52"]}'::jsonb, '#2363: the gate as it stood, and the sites the State''s VAT does not reach by postal-code prefix: Las Palmas (35) and Santa Cruz de Tenerife (38) under the Canary Islands'' IGIC (Ley 20/1991), Ceuta (51) and Melilla (52) under the IPSI (Ley 8/1991), outside the VAT''s territory by art. 3 Ley 37/1992; not yet confirmed', false),
('threshold', 'ES', 'modelo347', '1900-01-01', '{"cents":300506,"effect":"annual_operations","currency":"EUR"}'::jsonb, 'RD 1065/2007 art. 33 (modelo 347): the operations with one person or entity above EUR 3,005.06 in the calendar year, VAT included (#2363); not yet confirmed', false),
('threshold', 'ES', 'simplified_invoice', '2013-01-01', '{"cents":40000,"effect":"simplified_invoice","currency":"EUR"}'::jsonb, 'RD 1619/2012 art. 4.1.a: a simplified invoice is enough up to EUR 400, VAT included (#2363); not yet confirmed', false),
('threshold', 'GB', 'simplified_invoice', '1900-01-01', '{"cents":25000,"effect":"simplified_invoice","currency":"GBP"}'::jsonb, 'VAT Notice 700 §16.4: a less detailed invoice is enough up to GBP 250 including VAT, the figure invoice_essentials_missing carried since 0417 (#2359, #2363); typed in code, not re-verified', false),
('threshold', 'IT', 'stamp_duty', '1900-01-01', '{"cents":7747,"effect":"stamp_duty","currency":"EUR","charge_cents":200}'::jsonb, 'DPR 642/1972, tariff art. 13 note 1, and DL 69/2013: EUR 2.00 on an invoice without VAT above EUR 77.47, the figures invoice_fatturapa.dart carried (#2438, #2363); typed in code, not re-verified', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

-- ── 4. a threshold of a country, in force today ───────────────────────
create or replace function public.tax_threshold_cents(p_country text, p_key text)
returns bigint language sql stable security definer set search_path = public as $fn$
  select (t.value ->> 'cents')::bigint
    from public.tax_reference t
   where t.domain = 'threshold' and t.key = p_key
     and t.country = public.eu_country_code(p_country)
     and t.valid_from <= current_date
     and (t.valid_to is null or t.valid_to > current_date)
   order by t.valid_from desc
   limit 1;
$fn$;
revoke execute on function public.tax_threshold_cents(text, text) from public, anon, authenticated;

-- ── 5. invoice_essentials_missing ─────────────────────────────────────
-- Restated whole (the body of 0426 with 0431 and 0434 applied): the
-- simplified-invoice line is the row of the seller's country, and a site
-- outside the State's VAT is refused by name.
create or replace function public.invoice_essentials_missing(
  p_workspace_id uuid, p_member_id uuid, p_parties jsonb, p_vat_totals jsonb
) returns text[]
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_missing text[] := '{}';
  v_seller jsonb := coalesce(p_parties -> 'seller', '{}'::jsonb);
  v_buyer jsonb := coalesce(p_parties -> 'buyer', '{}'::jsonb);
  v_regime text := coalesce(p_parties -> 'seller' ->> 'vat_regime', 'not_subject');
  v_capacity text;
  v_exempt_line boolean;
  v_reverse boolean;
  v_country text;
  v_cc text;
  v_buyer_cc text;
  v_national text;
  v_gate jsonb;
  v_own_exemption boolean;
  v_rate uuid;
  v_simplified boolean;
begin
  if btrim(coalesce(v_seller ->> 'street', '')) = ''
     and btrim(coalesce(v_seller ->> 'city', '')) = '' then
    v_missing := array_append(v_missing, 'seller_address'::text);
  end if;
  v_country := public.invoice_legal_snapshot(p_workspace_id, p_member_id, p_parties)
                 ->> 'seller_country';
  v_cc := public.eu_country_code(v_country);
  v_gate := public.issuing_gate_of(v_cc);
  -- #2362: a seller whose country's gate says `sales_tax` has a list of its
  -- own: no VAT regime, VAT id, EN 16931 gate or reverse charge applies.
  if coalesce(v_gate ->> 'tax_system', 'vat') = 'sales_tax' then
    if not coalesce((v_gate ->> 'supported')::boolean, false)
       or not public.feature_effective(p_workspace_id, 'salesTax') then
      v_missing := array_append(v_missing, 'seller_country_unsupported'::text);
    end if;
    v_national := nullif(v_gate ->> 'currency', '');
    if v_national is not null
       and exists (select 1 from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t
                    where coalesce((t ->> 'vat_cents')::bigint, 0) <> 0)
       and upper(coalesce((select w.currency_code from public.workspaces w
                            where w.id = p_workspace_id), '')) <> v_national then
      v_missing := array_append(v_missing, 'vat_national_currency'::text);
    end if;
    if btrim(coalesce(v_buyer ->> 'name', '')) = ''
       and btrim(coalesce(v_buyer ->> 'company', '')) = '' then
      v_missing := array_append(v_missing, 'buyer_name'::text);
    end if;
    return v_missing;
  end if;
  -- #2359/#2363 — up to the `simplified_invoice` threshold of the seller's
  -- country (VAT Notice 700 §16.4, RD 1619/2012 art. 4), VAT included, a less
  -- detailed invoice is enough, and it names no customer.
  v_simplified := coalesce((select sum((t ->> 'gross_cents')::bigint)
                    from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t), 0)
        <= coalesce(public.tax_threshold_cents(v_cc, 'simplified_invoice'), -1);
  -- #2359 — HMRC's number: GB or XI, then nine or twelve digits (or the
  -- GD/HA government and health codes). The Dart twin is `looksLikeEuVatId`.
  if v_cc = 'GB' and v_regime = 'vat_registered'
     and btrim(coalesce(v_seller ->> 'vat_id', '')) <> ''
     and upper(regexp_replace(v_seller ->> 'vat_id', '[\s.\-]', '', 'g'))
         !~ '^(GB|XI)(\d{9}|\d{12}|GD\d{3}|HA\d{3})$' then
    v_missing := array_append(v_missing, 'seller_vat_id_format'::text);
  end if;
  -- #2360 — the Swiss UID: CHE-123.456.789 and the MWST suffix (TVA, IVA)
  -- art. 26 Abs. 2 lit. a MWSTG, with the modulus-11 check digit.
  if v_cc = 'CH' and v_regime = 'vat_registered'
     and btrim(coalesce(v_seller ->> 'vat_id', '')) <> ''
     and not public.swiss_uid_valid(v_seller ->> 'vat_id', true) then
    v_missing := array_append(v_missing, 'seller_uid_format'::text);
  end if;
  -- #2361 — Canada: the business number with its RT account (ETA s. 169(4),
  -- Input Tax Credit Information Regulations: 123456789 RT0001) and, when the
  -- QST is charged, Revenu Québec's number beside it (1234567890 TQ0001, kept
  -- in the legal identification). Dart twins: `isValidCanadianBn`,
  -- `isValidQstNumber`.
  if v_cc = 'CA' and v_regime = 'vat_registered' then
    if btrim(coalesce(v_seller ->> 'vat_id', '')) <> ''
       and upper(regexp_replace(v_seller ->> 'vat_id', '[\s.\-]', '', 'g'))
           !~ '^\d{9}RT\d{4}$' then
      v_missing := array_append(v_missing, 'seller_bn_format'::text);
    end if;
    if exists (select 1
                 from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t,
                      jsonb_array_elements(coalesce(t -> 'components', '[]'::jsonb)) c
                where c ->> 'scheme' = 'QST')
       and upper(regexp_replace(coalesce(v_seller ->> 'legal_id', ''), '[\s.\-]', '', 'g'))
           !~ '^\d{10}TQ\d{4}$' then
      v_missing := array_append(v_missing, 'seller_qst_number'::text);
    end if;
  end if;
  -- A VAT-registered seller states its VAT number; so does an Italian
  -- forfettario (exempt), whose partita IVA is its only identifier.
  if (v_regime = 'vat_registered' or (v_cc = 'IT' and v_regime = 'exempt'))
     and btrim(coalesce(v_seller ->> 'vat_id', '')) = '' then
    v_missing := array_append(v_missing, 'seller_vat_id'::text);
  end if;
  -- #2356 — § 14 Abs. 4 Nr. 2 UStG / the Spanish NIF.
  if coalesce((v_gate ->> 'requires_tax_number')::boolean, false) and v_regime <> 'not_subject'
     and btrim(coalesce(v_seller ->> 'vat_id', '')) = ''
     and btrim(coalesce(v_seller ->> 'legal_id', '')) = '' then
    v_missing := array_append(v_missing, 'seller_tax_number'::text);
  end if;

  -- #2356 — the seller's own small-business exemption, not a buyer's.
  v_own_exemption := v_regime = 'exempt'
    and coalesce(v_buyer ->> 'vat_treatment', 'auto') in ('auto', 'domestic');
  -- #2440 — an E total that carries its own rate's reason (frozen by
  -- create_invoice) needs no seller-level text and is not unreviewed.
  select coalesce(bool_or(t ->> 'category' = 'G'
                          or (t ->> 'category' = 'E'
                              and btrim(coalesce(t ->> 'exemption_reason', '')) = '')), false),
         coalesce(bool_or(t ->> 'category' = 'AE'), false)
    into v_exempt_line, v_reverse
    from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t;
  if v_exempt_line and not v_own_exemption
     and btrim(coalesce(
           case when v_buyer ->> 'vat_treatment' in ('exempt', 'export')
                then v_buyer ->> 'tax_exemption_reason'
                else v_seller ->> 'tax_exemption_reason' end, '')) = '' then
    v_missing := array_append(v_missing, 'exemption_reason'::text);
  end if;
  if v_reverse and btrim(coalesce(v_buyer ->> 'vat_id', '')) = '' then
    v_missing := array_append(v_missing, 'buyer_vat_id'::text);
  end if;

  -- #2356 — every member state of the Union; outside it, not here. #2359:
  -- but the United Kingdom, whose rules are in this function (VRN shape,
  -- sterling, the simplified invoice, the option to tax in 0418). #2360:
  -- and Switzerland (UID with its MWST suffix, 0420; the letting, 0421;
  -- the return in francs). #2361: and Canada (GST/HST/QST as components, 0423;
  -- the business number and the QST number, 0424; the return, 0425).
  -- #2358: nor where the law routes every invoice through a national channel the
  -- app does not speak yet — Italy (SdI), Spain (Verifactu), Poland (KSeF)
  -- and Romania (e-Factura). Dart twin: `nationalChannelRequired`.
  if not coalesce((v_gate ->> 'supported')::boolean, false)
     or coalesce((v_gate ->> 'national_channel_required')::boolean, false) then
    v_missing := array_append(v_missing, 'seller_country_unsupported'::text);
  end if;
  -- #2363 — a site where the State's VAT does not apply (the Canary Islands'
  -- IGIC, Ceuta and Melilla's IPSI): its postal-code prefixes are the gate's.
  if exists (select 1
               from jsonb_array_elements_text(coalesce(v_gate -> 'outside_vat_postal_codes', '[]'::jsonb)) p
              where upper(btrim(coalesce(v_seller ->> 'postal_code', ''))) like p || '%') then
    v_missing := array_append(v_missing, 'territory_outside_vat'::text);
  end if;
  -- #2356 — art. 230: the VAT in the national currency; #2359: in sterling
  -- (VAT Notice 700 §16: the total VAT payable in pounds); #2360: in francs
  -- (the return of the MWST is in francs and the app converts nothing);
  -- #2361: in Canadian dollars (the GST/HST and QST returns are in dollars).
  v_national := nullif(v_gate ->> 'currency', '');
  if v_national is not null
     and exists (select 1 from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t
                  where coalesce((t ->> 'vat_cents')::int, 0) <> 0)
     and upper(coalesce((select w.currency_code from public.workspaces w
                          where w.id = p_workspace_id), '')) <> v_national then
    v_missing := array_append(v_missing, 'vat_national_currency'::text);
  end if;
  if v_regime = 'vat_registered' then
    v_rate := public.workspace_default_vat_rate_id(p_workspace_id);
    -- 0393: in force TODAY, inside its validity interval — an expired or
    -- not-yet-valid default no longer answers with its own percent.
    if v_rate is null or public.vat_rate_in_force(v_rate, current_date) is null then
      v_missing := array_append(v_missing, 'vat_rate_unresolved'::text);
    end if;
    -- 0393: a charge billed at 0 % with no buyer treatment explaining it
    -- (export, exemption, reverse charge) and no 0 % rate of the seller's
    -- (0407) is a rate that was missing when the line was priced.
    if exists (select 1 from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t
                where t ->> 'category' = 'O'
                  and coalesce((t ->> 'gross_cents')::int, 0) > 0) then
      v_missing := array_append(v_missing, 'vat_line_zero_unexplained'::text);
    end if;
  elsif exists (select 1 from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t
                 where coalesce((t ->> 'percent')::numeric, 0) > 0) then
    -- 0393: a seller that does not charge VAT never issues a line with VAT
    -- on it (a rate left on an accessory or on the subscription tariff).
    v_missing := array_append(v_missing, 'vat_charged_not_registered'::text);
  end if;

  if btrim(coalesce(v_buyer ->> 'name', '')) = ''
     and btrim(coalesce(v_buyer ->> 'company', '')) = ''
     and not v_simplified then
    v_missing := array_append(v_missing, 'buyer_name'::text);
  end if;
  v_capacity := public.invoice_legal_snapshot(p_workspace_id, p_member_id, p_parties)
                  ->> 'buyer_capacity';
  if v_capacity = 'business' and not v_simplified
     and btrim(coalesce(v_buyer ->> 'street', '')) = ''
     and btrim(coalesce(v_buyer ->> 'city', '')) = '' then
    v_missing := array_append(v_missing, 'buyer_address'::text);
  end if;
  -- #2356 — the customer's own identifier, where the seller's law asks.
  v_buyer_cc := public.eu_country_code(coalesce(nullif(v_buyer ->> 'country', ''), v_country));
  if btrim(coalesce(v_buyer ->> 'vat_id', '')) = ''
     and btrim(coalesce(v_buyer ->> 'legal_id', '')) = ''
     and (   (v_cc = 'ES' and v_regime <> 'not_subject' and v_capacity = 'business')
          or (v_cc = 'IT' and v_regime <> 'not_subject' and v_buyer_cc = 'IT')
          or (v_cc = 'FR' and v_regime <> 'not_subject' and v_capacity = 'business'
              and v_buyer_cc = 'FR')) then
    v_missing := array_append(v_missing, 'buyer_tax_id'::text);
  end if;
  -- #1917/#2354: reverse charge, export and a free-text exemption are not
  -- reviewed classifications; those documents stay with the external
  -- accountant and no client override qualifies them. A buyer abroad is
  -- no longer one of them: since 0403 each line's place of supply decides
  -- (a desk carries the seller's VAT wherever its customer lives). #2356:
  -- nor is the seller's own small-business exemption.
  if exists (select 1 from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t
              where t ->> 'category' in ('AE', 'G')
                 or (t ->> 'category' = 'E' and not v_own_exemption
                     and btrim(coalesce(t ->> 'exemption_reason', '')) = ''))
     or v_buyer ->> 'vat_treatment' in ('reverse_charge', 'export', 'exempt') then
    v_missing := array_append(v_missing, 'vat_treatment_unreviewed'::text);
  end if;
  return v_missing;
end;

$fn$;

revoke execute on function public.invoice_essentials_missing(uuid, uuid, jsonb, jsonb)
  from public, anon, authenticated;

select public.set_deskilo_schema_version(600);
