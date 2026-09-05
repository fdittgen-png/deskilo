-- SPDX-License-Identifier: 0BSD
-- 0157 — #895: intra-EU B2B is the customer's tax, not the seller's.
--
-- A VAT-registered seller invoicing a BUSINESS in another member state
-- charges no VAT: the customer self-assesses (Directive art. 196). The
-- document states category AE and carries the reverse-charge mention.
-- Until now every positive rate was category S whoever the buyer was.
--
-- The price is the tariff: no tax is added and none is extracted — the
-- amount billed IS the taxable base of the reverse-charged supply.
-- A workspace may opt out (`invoice_legal.reverse_charge = false`) when
-- it never invoices businesses abroad.
--
-- Harness-verified 2026-09-05: FR seller → DE business with a VAT id
-- gives one AE entry at 0 % (net = gross, no tax) and zero-rated lines;
-- the same customer at home keeps 20 % / category S; opted out keeps
-- 20 % across the border too.

create or replace function public.is_eu_country(p_code text) returns boolean
language sql immutable as $$
  select upper(btrim(coalesce(p_code, ''))) = any (array[
    'AT','BE','BG','CY','CZ','DE','DK','EE','ES','FI','FR','GR','EL','HR','HU',
    'IE','IT','LT','LU','LV','MT','NL','PL','PT','RO','SE','SI','SK']);
$$;

do $patch$
declare v_def text; v_anchor text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname='public' and p.proname='create_invoice';
  if v_def is null then raise exception '0157: create_invoice not found'; end if;

  -- A. the verdict, declared with the other locals.
  v_anchor := E'  v_member_phone text := '''';\n';
  if position(v_anchor in v_def) = 0 then raise exception '0157: anchor A missing'; end if;
  v_def := replace(v_def, v_anchor, v_anchor || E'  v_reverse_charge boolean := false;\n');

  -- B. decide it, and zero the lines, before the breakdown is computed.
  v_anchor := E'  with charges as (\n';
  if position(v_anchor in v_def) = 0 then raise exception '0157: anchor B missing'; end if;
  v_def := replace(v_def, v_anchor,
       E'  -- #895 — intra-EU B2B: a VAT-registered seller invoicing a business\n'
    || E'  -- in ANOTHER member state charges no tax; the customer self-assesses\n'
    || E'  -- (art. 196). The workspace may opt out.\n'
    || E'  v_reverse_charge :=\n'
    || E'        coalesce(v_workspace.vat_regime, ''not_subject'') = ''vat_registered''\n'
    || E'    and coalesce((v_workspace.invoice_legal->>''reverse_charge'')::boolean, true)\n'
    || E'    and btrim(coalesce(v_member_vat, '''')) <> ''''\n'
    || E'    and public.is_eu_country(v_workspace.country_code)\n'
    || E'    and public.is_eu_country(v_member_country)\n'
    || E'    and upper(btrim(v_member_country)) <> upper(btrim(v_workspace.country_code));\n'
    || E'  if v_reverse_charge then\n'
    || E'    select coalesce(jsonb_agg(l || jsonb_build_object(''vat_percent'', 0)), ''[]''::jsonb)\n'
    || E'      into v_lines from jsonb_array_elements(v_lines) l;\n'
    || E'  end if;\n'
    || v_anchor);

  -- C. the breakdown names the category EN 16931 wants.
  v_anchor := E'      ''category'', case when percent > 0 then ''S'' else v_zero_category end,\n';
  if position(v_anchor in v_def) = 0 then raise exception '0157: anchor C missing'; end if;
  v_def := replace(v_def, v_anchor,
    E'      ''category'', case when v_reverse_charge then ''AE''\n'
 || E'                       when percent > 0 then ''S'' else v_zero_category end,\n');
  execute v_def;
end
$patch$;
