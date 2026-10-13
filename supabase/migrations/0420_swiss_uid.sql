-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0420 (#2360) — the Swiss UID of a VAT-registered seller has the shape
-- art. 26 Abs. 2 lit. a MWSTG prints: CHE-123.456.789 followed by MWST
-- (TVA in French, IVA in Italian), the ninth digit checking the first
-- eight (modulus 11, weights 5 4 3 2 7 6 5 4). `swiss_uid_valid` is the
-- check, `invoice_essentials_missing` refuses `seller_uid_format`. The Dart
-- twin is `isValidSwissUid`. Switzerland stays refused
-- (`seller_country_unsupported`) until the last slice. Issued invoices
-- are untouched.

create or replace function public.swiss_uid_valid(p_uid text, p_require_suffix boolean default true)
returns boolean
language plpgsql immutable set search_path = public as $fn$
declare
  v_id text := upper(regexp_replace(coalesce(p_uid, ''), '[\s.\-]', '', 'g'));
  v_m text[];
  v_sum int := 0;
  v_check int;
  i int;
  w int[] := array[5, 4, 3, 2, 7, 6, 5, 4];
begin
  v_m := regexp_match(v_id, '^CHE(\d{9})(MWST|TVA|IVA)?$');
  if v_m is null or (p_require_suffix and v_m[2] is null) then
    return false;
  end if;
  for i in 1..8 loop
    v_sum := v_sum + substr(v_m[1], i, 1)::int * w[i];
  end loop;
  v_check := 11 - v_sum % 11;
  if v_check = 10 then return false; end if;
  if v_check = 11 then v_check := 0; end if;
  return v_check = substr(v_m[1], 9, 1)::int;
end;
$fn$;
revoke execute on function public.swiss_uid_valid(text, boolean) from public, anon, authenticated;

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
  -- #2359 — VAT Notice 700 §16.4: up to £250 including VAT a less detailed
  -- invoice is enough, and it names no customer.
  v_simplified := v_cc = 'GB'
    and coalesce((select sum((t ->> 'gross_cents')::bigint)
                    from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t), 0)
        <= 25000;
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
  -- A VAT-registered seller states its VAT number; so does an Italian
  -- forfettario (exempt), whose partita IVA is its only identifier.
  if (v_regime = 'vat_registered' or (v_cc = 'IT' and v_regime = 'exempt'))
     and btrim(coalesce(v_seller ->> 'vat_id', '')) = '' then
    v_missing := array_append(v_missing, 'seller_vat_id'::text);
  end if;
  -- #2356 — § 14 Abs. 4 Nr. 2 UStG / the Spanish NIF.
  if v_cc in ('DE', 'ES') and v_regime <> 'not_subject'
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
  -- sterling, the simplified invoice, the option to tax in 0418).
  -- #2358: nor where the law routes every invoice through a national channel the
  -- app does not speak yet — Italy (SdI), Spain (Verifactu), Poland (KSeF)
  -- and Romania (e-Factura). Dart twin: `nationalChannelRequired`.
  if not (public.is_eu_country(v_country) or v_cc = 'GB')
     or v_cc in ('IT', 'ES', 'PL', 'RO') then
    v_missing := array_append(v_missing, 'seller_country_unsupported'::text);
  end if;
  -- #2356 — art. 230: the VAT in the national currency; #2359: in sterling
  -- (VAT Notice 700 §16: the total VAT payable in pounds).
  v_national := case v_cc when 'CZ' then 'CZK' when 'DK' then 'DKK'
                          when 'HU' then 'HUF' when 'PL' then 'PLN'
                          when 'RO' then 'RON' when 'SE' then 'SEK'
                          when 'GB' then 'GBP' end;
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

select public.set_deskilo_schema_version(420);
