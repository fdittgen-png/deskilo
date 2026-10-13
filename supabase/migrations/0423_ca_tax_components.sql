-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0423 (#2361) — the tax of a Canadian invoice as components, not a sum.
--
-- A Quebec invoice states the GST and the QST as two amounts (ETA s. 169(4);
-- the Act respecting the QST, s. 425): GST 5 % and QST 9.975 % are both
-- levied on the price EXCLUDING GST (the QST has not compounded since 2013),
-- so the combined 14.975 % of the catalogue is the exact sum of the two on
-- the same base and the invoice total does not move. What changes is what
-- the invoice SHOWS: each total of `vat_totals` may now carry
--
--   "components": [{"scheme": "GST", "authority": "CA", "percent": 5,
--                   "base_cents": 100000, "tax_cents": 5000}, ...]
--
-- and the components add up to the entry's `vat_cents` to the cent (the last
-- one takes the rounding remainder). The key exists for a seller in Canada
-- only: every other seller's `vat_totals` is byte-identical to before.
--
--   * `vat_percent_components(country, percent)` is the catalogue as data:
--     5 GST (AB BC MB NT NU SK YT), 13/14/15 HST (ON; NS since 1 April 2025;
--     NB NL PE), 14.975 GST + QST (QC). The legacy "GST+PST" rows of 12 and
--     11 map to GST 5 + the provincial tax, so an invoice that still carries
--     one is honest about what it charges. Any other rate: no split.
--     Dart twin: `vat_components.dart`.
--   * `vat_components_entry(country, percent, net, vat)` is the object that
--     `create_invoice` appends to the entry (empty for any other country).
--   * `create_invoice` freezes it (anchored patch).

create or replace function public.vat_percent_components(p_country text, p_percent numeric)
returns jsonb
language sql immutable set search_path = public as $fn$
  select case
    when upper(btrim(coalesce(p_country, ''))) <> 'CA' then null
    when p_percent = 5 then '[{"scheme":"GST","authority":"CA","percent":5}]'::jsonb
    when p_percent in (13, 14, 15) then
      jsonb_build_array(jsonb_build_object('scheme', 'HST', 'authority', 'CA', 'percent', p_percent))
    when p_percent = 14.975 then
      '[{"scheme":"GST","authority":"CA","percent":5},{"scheme":"QST","authority":"CA-QC","percent":9.975}]'::jsonb
    when p_percent = 12 then
      '[{"scheme":"GST","authority":"CA","percent":5},{"scheme":"PST","authority":"CA-PST","percent":7}]'::jsonb
    when p_percent = 11 then
      '[{"scheme":"GST","authority":"CA","percent":5},{"scheme":"PST","authority":"CA-PST","percent":6}]'::jsonb
    else null
  end;
$fn$;
revoke execute on function public.vat_percent_components(text, numeric)
  from public, anon, authenticated;

create or replace function public.vat_components_entry(
  p_country text, p_percent numeric, p_net bigint, p_vat bigint
) returns jsonb
language plpgsql immutable set search_path = public as $fn$
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
  select pg_get_functiondef('public.create_invoice(uuid,uuid,text,uuid,boolean,text,boolean,text,text,text)'::regprocedure)
    into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$'vat_cents', gross - net)$a$,
    $a$'vat_cents', gross - net)
      -- #2361: a Canadian total states its GST / HST / QST apart.
      || public.vat_components_entry(v_seller_country, percent, net, gross - net)$a$);
  if v_def is null then raise exception '0423: create_invoice vat_totals anchor missing'; end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(423);
