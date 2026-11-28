-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4479 -- two audit items.
--   * A purchase order's line holds the VAT rate the person PICKED, by its id, like the service and the standalone invoice do:
--     `purchase_order_lines.vat_rate_id`. The server resolves the percent from that rate (an active rate of the business, or
--     `vat_rate_unknown`); a line sent with a percent alone keeps working as before (the replenishment draft, the MCP).
--   * An archived unit of measure is refused for a NEW association: an item's unit, a conversion, an order or bill line, a
--     line of a standalone invoice draft or of a quote revision. What is stored stays readable, and a line that already
--     holds a unit keeps it (an archive is refused while a unit is used, so no stored row holds an archived unit).
-- A refusal is the stock configuration's own (DKG11, the field and the reason in the detail): `vat_rate_unknown`, `unit_archived`.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0988: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- ── 1. the rate of an order line, by identity ────────────────────────────
-- audience: all row readers
alter table public.purchase_order_lines
  add column if not exists vat_rate_id uuid references public.vat_rates(id) on delete set null;

do $patch$
declare
  v_def text;
begin
  select pg_get_functiondef('public.save_purchase_order_v1(uuid,uuid,int,jsonb)'::regprocedure) into v_def;
  if position('v_rate_id' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, E'  v_rate numeric;\n', E'  v_rate numeric;\n  v_rate_id uuid;\n', 'the rate variable');
    v_def := pg_temp.anchor_once(v_def,
      E'    v_rate := nullif(e ->> ''vat_rate_percent'', '''')::numeric;\n',
      E'    v_rate := nullif(e ->> ''vat_rate_percent'', '''')::numeric;\n' ||
      E'    v_rate_id := nullif(e ->> ''vat_rate_id'', '''')::uuid;\n' ||
      E'    if v_rate_id is not null then\n' ||
      E'      select r.percent into v_rate from public.vat_rates r\n' ||
      E'       where r.id = v_rate_id and r.workspace_id = p_workspace_id and r.active;\n' ||
      E'      if not found then\n' ||
      E'        perform public.stock_config_refuse(format(''lines[%s].vat_rate_id'', n - 1), ''vat_rate_unknown'');\n' ||
      E'      end if;\n' ||
      E'    end if;\n', 'the rate of a line');
    v_def := pg_temp.anchor_once(v_def, E'unit_price_cents, vat_rate_percent)\n', E'unit_price_cents, vat_rate_percent, vat_rate_id)\n', 'the insert columns');
    v_def := pg_temp.anchor_once(v_def, 'v_price, v_rate);', 'v_price, v_rate, v_rate_id);', 'the insert values');
    execute v_def;
  end if;
end
$patch$;

-- ── 2. an archived unit is not picked again ─────────────────────────────
-- restates 0961
create or replace function public.unit_is_pickable(p_workspace uuid, p_unit text, p_item uuid default null)
returns boolean language sql stable security definer set search_path = public as $fn$
  select btrim(coalesce(p_unit, '')) = ''
      or exists (select 1 from public.workspace_units u
                  where u.workspace_id = p_workspace and u.code = btrim(p_unit) and not u.archived);
$fn$;
revoke execute on function public.unit_is_pickable(uuid, text, uuid) from public, anon, authenticated;

-- an archived unit among the codes: the code, or null
create or replace function public.unit_archived_among(p_workspace uuid, p_codes text[])
returns text language sql stable security definer set search_path = public as $fn$
  select u.code from public.workspace_units u
   where u.workspace_id = p_workspace and u.archived and u.code = any(p_codes)
   order by u.code limit 1;
$fn$;
revoke execute on function public.unit_archived_among(uuid, text[]) from public, anon, authenticated;

-- the unit codes a document's lines name
create or replace function public.document_line_units(p_lines jsonb)
returns text[] language sql immutable set search_path = public as $fn$
  select coalesce(array_agg(distinct c), '{}'::text[]) from (
    select jsonb_path_query(coalesce(p_lines, '[]'::jsonb), '$[*].unit.code') #>> '{}' as c
    union
    select jsonb_path_query(coalesce(p_lines, '[]'::jsonb), '$[*].commercial.unit.code') #>> '{}'
  ) x where c is not null;
$fn$;
revoke execute on function public.document_line_units(jsonb) from public, anon, authenticated;

-- an item's unit
create or replace function public.item_units_archived_guard()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if (tg_op = 'INSERT' or new.unit is distinct from old.unit)
     and public.unit_archived_among(new.workspace_id, array[new.unit]) is not null then
    perform public.stock_config_refuse('unit', 'unit_archived');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.item_units_archived_guard() from public, anon, authenticated;
create trigger item_units_archived before insert or update of unit on public.item_units
  for each row execute function public.item_units_archived_guard();

-- a conversion
create or replace function public.unit_conversions_archived_guard()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if (tg_op = 'INSERT' or (new.from_unit, new.to_unit) is distinct from (old.from_unit, old.to_unit))
     and public.unit_archived_among(new.workspace_id, array[new.from_unit, new.to_unit]) is not null then
    perform public.stock_config_refuse('unit', 'unit_archived');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.unit_conversions_archived_guard() from public, anon, authenticated;
create trigger unit_conversions_archived before insert or update of from_unit, to_unit on public.unit_conversions
  for each row execute function public.unit_conversions_archived_guard();

-- the lines of a draft or a revision: a unit the stored lines did not name already
create or replace function public.document_lines_archived_guard()
returns trigger language plpgsql set search_path = public as $fn$
declare
  v_new text[] := public.document_line_units(new.lines);
  v_old text[] := case when tg_op = 'UPDATE' then public.document_line_units(old.lines) else '{}'::text[] end;
begin
  if public.unit_archived_among(new.workspace_id, array(select unnest(v_new) except select unnest(v_old))) is not null then
    perform public.stock_config_refuse('lines', 'unit_archived');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.document_lines_archived_guard() from public, anon, authenticated;
create trigger standalone_invoice_drafts_archived_unit before insert or update of lines on public.standalone_invoice_drafts
  for each row execute function public.document_lines_archived_guard();
create trigger customer_quote_revisions_archived_unit before insert or update of lines on public.customer_quote_revisions
  for each row execute function public.document_lines_archived_guard();

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(988);
