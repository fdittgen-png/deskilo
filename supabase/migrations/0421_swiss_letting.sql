-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0421 (#2360) — the letting of premises in Switzerland (MWSTG).
--
-- A bare letting of rooms is exempt without the right to deduct input tax
-- (art. 21 Abs. 2 Ziff. 21) unless the seller opted to tax it (art. 22:
-- the option is exercised by showing the tax openly on the invoice). The
-- ESTV treats an equipped office or business-centre package with services
-- as taxable (MWST-Branchen-Info 17). So the default of a Swiss workspace
-- is the package, taxed at the normal rate; the owner who only lets bare
-- rooms says so (`invoice_legal.letting_kind = 'bare'`) and then the
-- option, with its date, is what taxes the letting.
--
--   * `workspace_taxes_land` answers the choice at a tax point for CH too:
--     taxed unless the letting is bare, or the option is in force;
--   * `supply_vat_category_for` applies the same rule to a property line of
--     a VAT-registered Swiss seller: E (its rate's reason frozen by
--     create_invoice, 0440) when the letting is bare and not opted;
--   * the legal snapshot of a Swiss invoice freezes the choice
--     (`land_taxation`, with `bare_letting`) like a UK one does (0418).
--
-- A general-service line (supply_class 'general') is never affected.
-- Issued invoices are untouched.

create or replace function public.workspace_taxes_land(p_workspace_id uuid, p_on date)
returns boolean
language sql stable security definer set search_path = public as $fn$
  select case
    when s.cc = 'CH' then
      coalesce(s.l ->> 'letting_kind', '') <> 'bare'
      or (coalesce(s.l ->> 'option_to_tax', '') = 'true'
          and (coalesce(s.l ->> 'option_to_tax_date', '') !~ '^\d{4}-\d{2}-\d{2}$'
               or (s.l ->> 'option_to_tax_date')::date <= p_on))
    else
      coalesce(s.l ->> 'facilities_package', '') = 'true'
      or (coalesce(s.l ->> 'option_to_tax', '') = 'true'
          and (coalesce(s.l ->> 'option_to_tax_date', '') !~ '^\d{4}-\d{2}-\d{2}$'
               or (s.l ->> 'option_to_tax_date')::date <= p_on))
    end
    from (select coalesce(w.invoice_legal, '{}'::jsonb) as l,
                 upper(btrim(coalesce(w.country_code, ''))) as cc
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
         and upper(btrim(coalesce(p_seller_country, ''))) in ('GB', 'CH')
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
  -- the legal snapshot freezes the choice of a Swiss seller as well.
  select pg_get_functiondef('public.invoice_legal_snapshot(uuid,uuid,jsonb)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$if v_body ->> 'seller_country' = 'GB' then$a$,
    $a$if v_body ->> 'seller_country' in ('GB', 'CH') then$a$);
  if v_def is null then raise exception '0421: invoice_legal_snapshot country anchor missing'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$'facilities_package', coalesce(v_legal ->> 'facilities_package', '') = 'true'));$a$,
    $a$'facilities_package', coalesce(v_legal ->> 'facilities_package', '') = 'true')
      -- #2360: a Swiss seller's letting is bare or a package (art. 21 / 22 MWSTG).
      || case when v_body ->> 'seller_country' = 'CH'
              then jsonb_build_object('bare_letting', coalesce(v_legal ->> 'letting_kind', '') = 'bare')
              else '{}'::jsonb end);$a$);
  if v_def is null then raise exception '0421: invoice_legal_snapshot freeze anchor missing'; end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(421);
