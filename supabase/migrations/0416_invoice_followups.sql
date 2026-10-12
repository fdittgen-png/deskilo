-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0416 (#2440, follow-up to #2356) — two things an invoice states that the
-- app used to leave to the owner or refuse.
--
--   * Spanish correction reason (RD 1619/2012 art. 15; AEAT TipoFactura
--     R1-R5: R1 error fundado en derecho and art. 80 uno, dos y seis LIVA,
--     R2 art. 80 tres, R3 art. 80 cuatro, R4 the rest, R5 simplified
--     invoices). `create_invoice` and `invoice_issue_readiness` take
--     `p_correction_reason`; a Spanish seller's replacement or credit note
--     without a valid code is refused (`correction_reason`), and the code is
--     frozen in `parties.correction_reason`, under the signature.
--   * Exemption per rate (§ 14 Abs. 4 Nr. 8 UStG, art. 226(11), BT-120 per
--     VAT category): a 0 % line priced by the seller's own exempt (E) rate
--     carries that rate's `exemption_reason` on its `vat_totals` entry. The
--     lines name only a percent, so the reason is frozen only when exactly
--     one reason answers for the E rates in force on the tax point; two
--     different reasons stay unattributed and refused as before. An E
--     total with its reason is no longer `vat_treatment_unreviewed`. A
--     buyer's exemption or export treatment never receives the rate's text.
--
-- Issued invoices are untouched (`invoices_immutable`).

create or replace function public.vat_zero_exemption_reason(
  p_workspace_id uuid, p_on date
) returns text
language sql stable security definer set search_path = public as $fn$
  select coalesce((
    select min(btrim(r.exemption_reason)) from public.vat_rates r
     where r.workspace_id = p_workspace_id and r.active and r.percent = 0
       and r.category = 'E' and btrim(r.exemption_reason) <> ''
       and r.valid_from <= p_on and (r.valid_to is null or r.valid_to > p_on)
    having count(distinct btrim(r.exemption_reason)) = 1
       and not exists (select 1 from public.vat_rates e
                        where e.workspace_id = p_workspace_id and e.active
                          and e.percent = 0 and e.category = 'E'
                          and btrim(e.exemption_reason) = ''
                          and e.valid_from <= p_on
                          and (e.valid_to is null or e.valid_to > p_on))), '');
$fn$;
revoke execute on function public.vat_zero_exemption_reason(uuid, date)
  from public, anon, authenticated;

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

  -- #2356 — every member state of the Union; outside it, not here. #2358:
  -- nor where the law routes every invoice through a national channel the
  -- app does not speak yet — Italy (SdI), Spain (Verifactu), Poland (KSeF)
  -- and Romania (e-Factura). Dart twin: `nationalChannelRequired`.
  if not public.is_eu_country(v_country)
     or v_cc in ('IT', 'ES', 'PL', 'RO') then
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
  select pg_get_functiondef('public.create_invoice(uuid,uuid,text,uuid,boolean,text,boolean,text,text)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$p_purchase_order text DEFAULT ''::text)$a$,
    $a$p_purchase_order text DEFAULT ''::text, p_correction_reason text DEFAULT ''::text)$a$);
  if v_def is null then raise exception '0416: create_invoice signature anchor missing'; end if;
  -- the rate's own reason, frozen on the 0 % E total
  v_def := pg_temp.anchor_replace(v_def,
    $a$'vat_cents', gross - net) order by percent desc, line_category)$a$,
    $a$'vat_cents', gross - net)
      || case when line_category = 'E' and percent = 0
                   and coalesce(v_workspace.vat_regime, 'not_subject') = 'vat_registered'
                   and coalesce(v_treatment, 'auto') in ('auto', 'domestic')
                   and public.vat_zero_exemption_reason(
                         p_workspace_id, public.vat_tax_point(p_period)) <> ''
              then jsonb_build_object('exemption_reason',
                     public.vat_zero_exemption_reason(
                       p_workspace_id, public.vat_tax_point(p_period)))
              else '{}'::jsonb end
      order by percent desc, line_category)$a$);
  if v_def is null then raise exception '0416: create_invoice vat_totals anchor missing'; end if;
  -- the Spanish correction reason, frozen with the parties
  v_def := pg_temp.anchor_replace(v_def,
    $a$  if p_detailed then$a$,
    $a$  -- #2440 — RD 1619/2012 art. 15: a Spanish correction names its reason.
  if public.eu_country_code(v_parties -> 'seller' ->> 'country') = 'ES'
     and (p_replaces is not null or v_total < 0)
     and upper(btrim(coalesce(p_correction_reason, ''))) in ('R1', 'R2', 'R3', 'R4', 'R5') then
    v_parties := v_parties || jsonb_build_object(
      'correction_reason', upper(btrim(p_correction_reason)));
  end if;

  if p_detailed then$a$);
  if v_def is null then raise exception '0416: create_invoice parties anchor missing'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  if v_capacity_unknown then$a$,
    $a$  if public.eu_country_code(v_parties -> 'seller' ->> 'country') = 'ES'
     and (p_replaces is not null or v_total < 0)
     and upper(btrim(coalesce(p_correction_reason, ''))) not in ('R1', 'R2', 'R3', 'R4', 'R5') then
    v_essentials := array_append(v_essentials, 'correction_reason'::text);
  end if;
  if v_capacity_unknown then$a$);
  if v_def is null then raise exception '0416: create_invoice essentials anchor missing'; end if;
  execute v_def;
end
$migration$;

drop function if exists public.create_invoice(uuid, uuid, text, uuid, boolean, text, boolean, text, text);
revoke execute on function public.create_invoice(uuid, uuid, text, uuid, boolean, text, boolean, text, text, text)
  from public, anon;
grant execute on function public.create_invoice(uuid, uuid, text, uuid, boolean, text, boolean, text, text, text)
  to authenticated, service_role;

-- ── the same question, without issuing ─────────────────────────────────
drop function if exists public.invoice_issue_readiness(uuid, uuid, text, text, uuid);
create or replace function public.invoice_issue_readiness(
  p_workspace_id uuid, p_member_id uuid, p_period text,
  p_kind text default 'full', p_replaces uuid default null,
  p_correction_reason text default ''
) returns text[]
language plpgsql security definer set search_path = public as $fn$
declare
  v_detail text;
begin
  if auth.uid() is null
     or not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'admins may not issue invoices here';
  end if;
  begin
    perform public.create_invoice(
      p_workspace_id, p_member_id, p_period, p_replaces, false, p_kind, true,
      '', '', p_correction_reason);
    -- Issued inside this block: undo it, nothing was missing.
    raise exception 'dry run' using errcode = 'DKI02';
  exception
    when sqlstate 'DKI01' then
      get stacked diagnostics v_detail = pg_exception_detail;
      return string_to_array(v_detail, ',');
    when sqlstate 'DKI02' then
      return '{}'::text[];
  end;
end;
$fn$;

revoke execute on function public.invoice_issue_readiness(uuid, uuid, text, text, uuid, text)
  from public, anon;
grant execute on function public.invoice_issue_readiness(uuid, uuid, text, text, uuid, text)
  to authenticated, service_role;

select public.set_deskilo_schema_version(416);
