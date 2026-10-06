-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0385 -- #1917: issuing a legal invoice is refused, at the server command,
-- where it used to degrade silently. Two keys join the essentials of 0365
-- (DKI01, listed in the refusal's DETAIL and in invoice_issue_readiness):
--   seller_country_unsupported -- the seller's country is not one the
--     legal clauses were reviewed for (FR, DE); issuing stays a manual
--     operator/accountant process elsewhere;
--   vat_rate_unresolved -- a VAT-registered seller whose default rate has
--     no active version in force today: it would have billed 0 %.
-- Previews, statements and member charges are untouched. An applied file
-- never changes; later fixes are new migrations.

create or replace function public.invoice_essentials_missing(
  p_workspace_id uuid, p_member_id uuid, p_parties jsonb, p_vat_totals jsonb
) returns text[]
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_missing text[] := '{}';
  v_seller jsonb := coalesce(p_parties -> 'seller', '{}'::jsonb);
  v_buyer jsonb := coalesce(p_parties -> 'buyer', '{}'::jsonb);
  v_capacity text;
  v_exempt_line boolean;
  v_reverse boolean;
  v_country text;
  v_rate uuid;
begin
  if btrim(coalesce(v_seller ->> 'street', '')) = ''
     and btrim(coalesce(v_seller ->> 'city', '')) = '' then
    v_missing := array_append(v_missing, 'seller_address'::text);
  end if;
  if v_seller ->> 'vat_regime' = 'vat_registered'
     and btrim(coalesce(v_seller ->> 'vat_id', '')) = '' then
    v_missing := array_append(v_missing, 'seller_vat_id'::text);
  end if;

  select coalesce(bool_or(t ->> 'category' in ('E', 'G')), false),
         coalesce(bool_or(t ->> 'category' = 'AE'), false)
    into v_exempt_line, v_reverse
    from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t;
  if v_exempt_line
     and btrim(coalesce(
           case when v_buyer ->> 'vat_treatment' in ('exempt', 'export')
                then v_buyer ->> 'tax_exemption_reason'
                else v_seller ->> 'tax_exemption_reason' end, '')) = '' then
    v_missing := array_append(v_missing, 'exemption_reason'::text);
  end if;
  if v_reverse and btrim(coalesce(v_buyer ->> 'vat_id', '')) = '' then
    v_missing := array_append(v_missing, 'buyer_vat_id'::text);
  end if;

  -- #1917 -- two things that used to degrade silently, now refuse issuing:
  -- a seller whose country is not one the legal clauses were reviewed for
  -- (FR, DE — what legalProfileOf says on the client), and a VAT-registered
  -- seller whose default rate does not resolve today (it would bill 0 %).
  v_country := public.invoice_legal_snapshot(p_workspace_id, p_member_id, p_parties)
                 ->> 'seller_country';
  if coalesce(v_country, '') not in ('FR', 'DE') then
    v_missing := array_append(v_missing, 'seller_country_unsupported'::text);
  end if;
  if v_seller ->> 'vat_regime' = 'vat_registered' then
    v_rate := public.workspace_default_vat_rate_id(p_workspace_id);
    if v_rate is null or public.vat_rate_percent_at(v_rate, current_date) is null then
      v_missing := array_append(v_missing, 'vat_rate_unresolved'::text);
    end if;
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
  return v_missing;
end;
$fn$;

revoke execute on function public.invoice_essentials_missing(uuid, uuid, jsonb, jsonb)
  from public, anon, authenticated;

select public.set_deskilo_schema_version(385);
