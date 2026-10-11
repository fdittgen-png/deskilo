-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0409 (#2356) — DesKilo issues for a seller in any EU member state.
--
-- Until now `seller_country_unsupported` refused every seller outside
-- France and Germany (0385). The four things a member state needed are in:
-- the statutory mention (Dart `defaultExemptionMention`, the Directive's
-- articles where no national wording is reviewed), the payment clauses
-- (Directive 2011/7/EU: the €40 indemnity is a claim against a business
-- debtor, never printed to a consumer — Dart `LegalProfile.euBusiness`),
-- the zero category (0407) and the currency rule below. Outside the EU the
-- refusal stays.
--
--   * Art. 230: a seller in a member state outside the euro (CZ, DK, HU,
--     PL, RO, SE) states the VAT in its national currency. The app has no
--     conversion at the tax point's ECB rate, so an invoice in another
--     currency with VAT on it is refused (`vat_national_currency`) rather
--     than issued without it. Bulgaria uses the euro since 2026-01-01.
--   * § 14 Abs. 4 Nr. 2 UStG and Spain's NIF: a German or Spanish seller
--     that is a taxable person states its VAT number or its tax number
--     (`seller_tax_number`, the registration field carries the
--     Steuernummer); an Italian forfettario has a partita IVA too.
--   * The buyer's identifier (`buyer_tax_id`): Spain's NIF of a business
--     customer (RD 1619/2012 art. 6), Italy's codice fiscale or partita
--     IVA of a customer in Italy, France's SIREN of a business customer in
--     France (CGI ann. II art. 242 nonies A, from 2026-09-01).
--   * An exempt seller's own small-business exemption (franchise, § 19
--     UStG, …) is a statutory regime with a statutory mention: its E lines
--     are no longer "unreviewed" (0395), and the mention prints by default.
--     An exemption from the buyer's treatment or from a rate still is.

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
begin
  if btrim(coalesce(v_seller ->> 'street', '')) = ''
     and btrim(coalesce(v_seller ->> 'city', '')) = '' then
    v_missing := array_append(v_missing, 'seller_address'::text);
  end if;
  v_country := public.invoice_legal_snapshot(p_workspace_id, p_member_id, p_parties)
                 ->> 'seller_country';
  v_cc := public.eu_country_code(v_country);
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
  select coalesce(bool_or(t ->> 'category' in ('E', 'G')), false),
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

  -- #2356 — every member state of the Union; outside it, not here.
  if not public.is_eu_country(v_country) then
    v_missing := array_append(v_missing, 'seller_country_unsupported'::text);
  end if;
  -- #2356 — art. 230: the VAT in the national currency.
  v_national := case v_cc when 'CZ' then 'CZK' when 'DK' then 'DKK'
                          when 'HU' then 'HUF' when 'PL' then 'PLN'
                          when 'RO' then 'RON' when 'SE' then 'SEK' end;
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
     and btrim(coalesce(v_buyer ->> 'company', '')) = '' then
    v_missing := array_append(v_missing, 'buyer_name'::text);
  end if;
  v_capacity := public.invoice_legal_snapshot(p_workspace_id, p_member_id, p_parties)
                  ->> 'buyer_capacity';
  if v_capacity = 'business'
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
                 or (t ->> 'category' = 'E' and not v_own_exemption))
     or v_buyer ->> 'vat_treatment' in ('reverse_charge', 'export', 'exempt') then
    v_missing := array_append(v_missing, 'vat_treatment_unreviewed'::text);
  end if;
  return v_missing;
end;
$fn$;

revoke execute on function public.invoice_essentials_missing(uuid, uuid, jsonb, jsonb)
  from public, anon, authenticated;

select public.set_deskilo_schema_version(409);
