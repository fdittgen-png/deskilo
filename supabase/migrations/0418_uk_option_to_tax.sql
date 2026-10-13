-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0418 (#2359) — land is exempt in the United Kingdom unless the owner
-- opted to tax it (VAT Act 1994 Sch 9 Group 1, Sch 10; VAT Notice 742).
--
-- A licence to occupy a desk or an office is a supply of land: exempt, with
-- no right to reclaim input VAT on the costs of making it, unless the
-- seller opted to tax the building (the option has a date and an HMRC
-- notification reference) or supplies a serviced package of facilities,
-- which is standard-rated. The treatment is a choice of the workspace, so
-- it lives in `workspaces.invoice_legal`:
--   option_to_tax            'true' once opted
--   option_to_tax_date       ISO date the option took effect (empty: always)
--   option_to_tax_reference  HMRC's notification reference
--   facilities_package       'true' for serviced-office packages
--
--   * `workspace_taxes_land(workspace, date)` answers the choice at a tax
--     point;
--   * `supply_vat_category_for` wraps the place-of-supply rule of 0403:
--     a property line of a VAT-registered UK seller is E unless the land
--     is taxed. The general-service lines (supply_class 'general') are
--     unaffected: they are standard-rated.
--   * `create_invoice` asks the wrapper (anchored patch) and the legal
--     snapshot of a UK invoice freezes the choice (`land_taxation`), so a
--     later change of the setting never rewrites an issued invoice.
--
-- The exempt line's reason (Sch 9 Group 1) is the workspace's own exempt
-- rate (0416), seeded by the catalogue.

create or replace function public.workspace_taxes_land(p_workspace_id uuid, p_on date)
returns boolean
language sql stable security definer set search_path = public as $fn$
  select coalesce(l ->> 'facilities_package', '') = 'true'
      or (coalesce(l ->> 'option_to_tax', '') = 'true'
          and (coalesce(l ->> 'option_to_tax_date', '') !~ '^\d{4}-\d{2}-\d{2}$'
               or (l ->> 'option_to_tax_date')::date <= p_on))
    from (select coalesce(w.invoice_legal, '{}'::jsonb) as l
            from public.workspaces w where w.id = p_workspace_id) s;
$fn$;
revoke execute on function public.workspace_taxes_land(uuid, date)
  from public, anon, authenticated;

create or replace function public.supply_vat_category_for(
  p_workspace_id uuid, p_on date, p_treatment text, p_supply text,
  p_seller_regime text, p_seller_country text, p_buyer_country text,
  p_buyer_capacity text, p_reverse_charge_on boolean
) returns text
language sql stable security definer set search_path = public as $fn$
  select case
    when b = ''
         and coalesce(p_supply, 'property') <> 'general'
         and upper(btrim(coalesce(p_seller_country, ''))) = 'GB'
         and coalesce(p_seller_regime, '') = 'vat_registered'
         and coalesce(p_treatment, 'auto') in ('auto', 'domestic')
         and not coalesce(public.workspace_taxes_land(p_workspace_id, p_on), false)
    then 'E' else b end
    from (select public.supply_vat_category(
            p_treatment, p_supply, p_seller_regime, p_seller_country,
            p_buyer_country, p_buyer_capacity, p_reverse_charge_on) as b) s;
$fn$;
revoke execute on function public.supply_vat_category_for(uuid, date, text, text, text, text, text, text, boolean)
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
  -- create_invoice: each line's category through the wrapper.
  select pg_get_functiondef('public.create_invoice(uuid,uuid,text,uuid,boolean,text,boolean,text,text,text)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$public.supply_vat_category(
               v_treatment, k.supply,$a$,
    $a$public.supply_vat_category_for(
               p_workspace_id, public.vat_tax_point(p_period), v_treatment, k.supply,$a$);
  if v_def is null then raise exception '0418: create_invoice category anchor missing'; end if;
  execute v_def;

  -- the legal snapshot freezes the choice of a UK seller.
  select pg_get_functiondef('public.invoice_legal_snapshot(uuid,uuid,jsonb)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$  -- #2354: the VIES check of the buyer's number, as evidence of its$a$,
    $a$  -- #2359: the option to tax the building (VAT Notice 742), as chosen
  -- on this invoice's day.
  if v_body ->> 'seller_country' = 'GB' then
    v_body := v_body || jsonb_build_object('land_taxation', jsonb_build_object(
      'option_to_tax', coalesce(v_legal ->> 'option_to_tax', '') = 'true',
      'option_to_tax_date', coalesce(v_legal ->> 'option_to_tax_date', ''),
      'option_to_tax_reference', btrim(coalesce(v_legal ->> 'option_to_tax_reference', '')),
      'facilities_package', coalesce(v_legal ->> 'facilities_package', '') = 'true'));
  end if;
  -- #2354: the VIES check of the buyer's number, as evidence of its$a$);
  if v_def is null then raise exception '0418: invoice_legal_snapshot anchor missing'; end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(418);
