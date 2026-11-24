-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one new helper; the declaration's engine reads it; no table, column or stored figure moves)
--
-- #4162 (X1.B) -- the VAT return reads the net the server froze on a commercial line.
--
-- `vat_return_amounts` (0402) is the SQL twin of the Dart tax-point engine (`taxPointsOf`,
-- vat_tax_point.dart). It summed every line's net as the legacy split of its gross at its rate.
-- A line issued under the `commercial` contract (version 1, the standalone invoice of 0820)
-- carries its authoritative amounts (`commercial.amounts.net_minor`): a reader never recomputes
-- a different net from the gross. `invoice_line_net_cents` is the one rule, read by the engine:
--   * a version 1 commercial line whose `net_minor` is an integer in text: that net;
--   * every other line (the monthly derivation, a credit, a line issued before 0820): the split
--     it always was, so every existing return keeps its figures to the cent.
-- The standalone producer freezes a net that its gross splits back to, so no stored return of
-- an issued standalone invoice changes either; the rule makes the frozen fact the authority
-- for any line where the two would differ. The Dart engine reads the same fact
-- (`InvoiceLine.authoritativeNetCents`); `vat_return_parity_test.dart` and
-- `559_tax_point_frozen_line_net.sql` pin both to one fixture.
--
-- patches 0402 (the only definer of vat_return_amounts)

create or replace function public.invoice_line_net_cents(p_line jsonb)
returns bigint
language sql
immutable
set search_path = public
as $fn$
  select case
    when jsonb_typeof(p_line -> 'commercial') = 'object'
     and p_line -> 'commercial' ->> 'version' = '1'
     and coalesce(p_line -> 'commercial' -> 'amounts' ->> 'net_minor', '') ~ '^-?[0-9]{1,15}$'
      then (p_line -> 'commercial' -> 'amounts' ->> 'net_minor')::bigint
    else public.vat_split_net((p_line ->> 'amount_cents')::numeric::bigint,
                              coalesce((p_line ->> 'vat_percent')::numeric, 0))
  end;
$fn$;
revoke execute on function public.invoice_line_net_cents(jsonb) from public, anon;

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

-- ── the engine sums the authoritative net of each line ──────────────────────
-- patches 0402
do $patch$
declare
  v_def text := pg_get_functiondef('public.vat_return_amounts(uuid, date, date)'::regprocedure);
  v_old text := E'sum(public.vat_split_net((l ->> \'amount_cents\')::numeric::bigint,\n'
             || E'                       coalesce((l ->> \'vat_percent\')::numeric, 0)))::bigint as n';
  v_new text := E'sum(public.invoice_line_net_cents(l))::bigint as n';
  v_next text;
begin
  v_next := pg_temp.anchor_replace(v_def, v_old, v_new);
  if v_next is null then
    raise exception '0943: the per-line net of vat_return_amounts was not found' using errcode = 'P0001';
  end if;
  if position('public.invoice_line_net_cents(l)' in v_next) = 0 then
    raise exception '0943: vat_return_amounts does not read the frozen line net' using errcode = 'P0001';
  end if;
  execute v_next;
end
$patch$;

select public.set_deskilo_schema_version(943);
