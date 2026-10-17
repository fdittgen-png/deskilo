-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0455 (#2539, Refs #2476) -- the Canadian tax components and the Swiss planned
-- rate change are reference data, not code.
--
--   1. rate_component   a new domain of the tax reference store: the taxes
--      inside a combined rate, keyed by the combined percent as text, one row
--      per rate of `CA` (5 GST; 13, 14, 15 HST; 14.975 GST + QST; 12 and 11 the
--      legacy GST + PST). `tax_reference_valid` learns the shape (percent,
--      components of scheme / authority / percent that add up to it).
--   2. vat_percent_components(country, percent) now READS those rows (the
--      version in force today) instead of a `case`; it is `stable security
--      definer` because it reads a table, and `vat_components_entry` -- which
--      calls it -- is stable too. Same answers, same shape: pgTAP 180 and 182
--      stay green; `create_invoice` and the frozen `vat_totals` of an issued
--      invoice are untouched.
--   3. The Swiss 13th AHV pension change (VAT 8.1 -> 8.5 % and 3.8 -> 4.0 %
--      from 2028-01-01, subject to the popular vote of 2026-11-29) becomes two
--      dated `rate` versions, each PROPOSED (`confirmed = false`) with its
--      source. The versions in force are closed on 2028-01-01 here -- what
--      `set_tax_reference` does -- before the seed inserts the successors. The
--      platform owner confirms or withdraws them after the vote
--      (`confirm_tax_reference` / `withdraw_tax_reference`, 0438).

-- ── 1. the shape of a rate_component ──────────────────────────────────
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
  select pg_get_functiondef('public.tax_reference_valid(text,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$    when 'taxability' then$a$,
    $a$    when 'rate_component' then
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
    when 'taxability' then$a$);
  if v_def is null or position($a$when 'rate_component' then$a$ in v_def) = 0 then
    raise exception '0455: tax_reference_valid taxability anchor missing';
  end if;
  execute v_def;
end
$migration$;

-- ── 2. the readers ────────────────────────────────────────────────────
-- The taxes inside a combined rate of a seller's country, or null: the row of
-- the version in force today. Dart twin: vat_components.dart.
create or replace function public.vat_percent_components(p_country text, p_percent numeric)
returns jsonb
language sql stable security definer set search_path = public as $fn$
  select t.value -> 'components'
    from public.tax_reference t
   where t.domain = 'rate_component'
     and t.country = upper(btrim(coalesce(p_country, '')))
     and (t.value ->> 'percent')::numeric = p_percent
     and t.valid_from <= current_date
     and (t.valid_to is null or t.valid_to > current_date)
   order by t.valid_from desc
   limit 1;
$fn$;
revoke execute on function public.vat_percent_components(text, numeric)
  from public, anon, authenticated;

create or replace function public.vat_components_entry(
  p_country text, p_percent numeric, p_net bigint, p_vat bigint
) returns jsonb
language plpgsql stable set search_path = public as $fn$
declare
  v_def jsonb := public.vat_percent_components(p_country, p_percent);
  v_out jsonb := '[]'::jsonb;
  v_left bigint := p_vat;
  v_n int;
  v_c jsonb;
  v_tax bigint;
begin
  if v_def is null then return '{}'::jsonb; end if;
  v_n := jsonb_array_length(v_def);
  for i in 0 .. v_n - 1 loop
    v_c := v_def -> i;
    -- Each component is rounded on the same base; the last takes the rest
    -- so that the components always add up to the entry's tax.
    v_tax := case when i = v_n - 1 then v_left
                  else round(p_net * (v_c ->> 'percent')::numeric / 100)::bigint end;
    v_left := v_left - v_tax;
    v_out := v_out || jsonb_build_object(
      'scheme', v_c ->> 'scheme', 'authority', v_c ->> 'authority',
      'percent', (v_c ->> 'percent')::numeric, 'base_cents', p_net, 'tax_cents', v_tax);
  end loop;
  return jsonb_build_object('components', v_out);
end;
$fn$;
revoke execute on function public.vat_components_entry(text, numeric, bigint, bigint)
  from public, anon, authenticated;

-- ── 3. the Swiss versions in force end on the day their successors begin ──
update public.tax_reference
   set valid_to = date '2028-01-01'
 where domain = 'rate' and country = 'CH' and key in ('standard', 'intermediate')
   and valid_from = date '2024-01-01' and valid_to is null;

-- ── 4. the seed ───────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('rate', 'CH', 'intermediate', '2028-01-01', '{"label":"Hébergement 4,0 %","percent":4.0,"group":"intermediate","category":"S","position":1}'::jsonb, 'Federal Council voting explanations and BSV/admin.ch for the popular vote of 2026-11-29 on the financing of the 13th AHV pension by VAT (bsv.admin.ch/de/abstimmung-13-ahv-rente, admin.ch news release gZ4zhuBYFjyi): normal rate 8.1 to 8.5 %, special accommodation rate 3.8 to 4.0 %, reduced rate 2.6 % unchanged, from 2028-01-01 if the people say yes; NOT in force and NOT confirmed until the vote passes and the ESTV publishes the date (confirm or withdraw the version then)', false),
('rate', 'CH', 'standard', '2028-01-01', '{"label":"Normal 8,5 %","percent":8.5,"group":"standard","category":"S","position":0}'::jsonb, 'Federal Council voting explanations and BSV/admin.ch for the popular vote of 2026-11-29 on the financing of the 13th AHV pension by VAT (bsv.admin.ch/de/abstimmung-13-ahv-rente, admin.ch news release gZ4zhuBYFjyi): normal rate 8.1 to 8.5 %, special accommodation rate 3.8 to 4.0 %, reduced rate 2.6 % unchanged, from 2028-01-01 if the people say yes; NOT in force and NOT confirmed until the vote passes and the ESTV publishes the date (confirm or withdraw the version then)', false),
('rate_component', 'CA', '11', '1900-01-01', '{"percent":11,"components":[{"scheme":"GST","authority":"CA","percent":5},{"scheme":"PST","authority":"CA-PST","percent":6}]}'::jsonb, 'Excise Tax Act (Canada) s. 165, 169(4); Act respecting the Québec sales tax s. 425 (QST on the price excluding GST since 2013); CRA GST/HST Notice 342 (Nova Scotia HST 14 % from 2025-04-01); the split moved unchanged from vat_components.dart (#2361)', true),
('rate_component', 'CA', '12', '1900-01-01', '{"percent":12,"components":[{"scheme":"GST","authority":"CA","percent":5},{"scheme":"PST","authority":"CA-PST","percent":7}]}'::jsonb, 'Excise Tax Act (Canada) s. 165, 169(4); Act respecting the Québec sales tax s. 425 (QST on the price excluding GST since 2013); CRA GST/HST Notice 342 (Nova Scotia HST 14 % from 2025-04-01); the split moved unchanged from vat_components.dart (#2361)', true),
('rate_component', 'CA', '13', '1900-01-01', '{"percent":13,"components":[{"scheme":"HST","authority":"CA","percent":13}]}'::jsonb, 'Excise Tax Act (Canada) s. 165, 169(4); Act respecting the Québec sales tax s. 425 (QST on the price excluding GST since 2013); CRA GST/HST Notice 342 (Nova Scotia HST 14 % from 2025-04-01); the split moved unchanged from vat_components.dart (#2361)', true),
('rate_component', 'CA', '14', '1900-01-01', '{"percent":14,"components":[{"scheme":"HST","authority":"CA","percent":14}]}'::jsonb, 'Excise Tax Act (Canada) s. 165, 169(4); Act respecting the Québec sales tax s. 425 (QST on the price excluding GST since 2013); CRA GST/HST Notice 342 (Nova Scotia HST 14 % from 2025-04-01); the split moved unchanged from vat_components.dart (#2361)', true),
('rate_component', 'CA', '14.975', '1900-01-01', '{"percent":14.975,"components":[{"scheme":"GST","authority":"CA","percent":5},{"scheme":"QST","authority":"CA-QC","percent":9.975}]}'::jsonb, 'Excise Tax Act (Canada) s. 165, 169(4); Act respecting the Québec sales tax s. 425 (QST on the price excluding GST since 2013); CRA GST/HST Notice 342 (Nova Scotia HST 14 % from 2025-04-01); the split moved unchanged from vat_components.dart (#2361)', true),
('rate_component', 'CA', '15', '1900-01-01', '{"percent":15,"components":[{"scheme":"HST","authority":"CA","percent":15}]}'::jsonb, 'Excise Tax Act (Canada) s. 165, 169(4); Act respecting the Québec sales tax s. 425 (QST on the price excluding GST since 2013); CRA GST/HST Notice 342 (Nova Scotia HST 14 % from 2025-04-01); the split moved unchanged from vat_components.dart (#2361)', true),
('rate_component', 'CA', '5', '1900-01-01', '{"percent":5,"components":[{"scheme":"GST","authority":"CA","percent":5}]}'::jsonb, 'Excise Tax Act (Canada) s. 165, 169(4); Act respecting the Québec sales tax s. 425 (QST on the price excluding GST since 2013); CRA GST/HST Notice 342 (Nova Scotia HST 14 % from 2025-04-01); the split moved unchanged from vat_components.dart (#2361)', true)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(455);
