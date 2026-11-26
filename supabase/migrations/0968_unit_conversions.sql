-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
--
-- #4479 -- a conversion is DEFINED, never implied: "only the master data are used, and converting can be done if a unit conversion
-- (from -> to) is defined" (the owner, 25 Nov). One step, never chained; an item's own conversion wins over a general one; a
-- conversion also works in reverse at the inverse factor; no definition, no conversion.
--   * `unit_conversions`: the business's GENERAL conversions (1 kg = 1000 g), one row per pair of units, edited in Settings. A packaging
--     unit (0963, the `package` dimension) has none: it converts only through an item's own factor (`item_units`).
--   * backfilled for every business from what the dimension ratio converted until now (so nothing that converted stops), and kept in
--     step by a trigger: a unit made later gets its conversions to the units of its dimension (editable rows), a unit whose factor is
--     changed (only while unused) gets them again.
--   * `unit_factor` / `unit_convert`: THE one rule, which `stock_to_inventory`, `stock_unit_factor` and `workspace_unit_convert` now
--     use (restating 0747/0952/0963 and 0951/0963). The dimension step is gone from all three.
--   * `unit_conversion_save_v1` / `unit_conversion_delete_v1`: the commands of the Settings screen (the units of measure feature, the
--     workspace-settings right, a request id answers once).
--   * the business's export carries the table (`export_workspace_records` restated, 0966).
-- Refusals are the stock configuration's own (DKG11, field and reason in the detail): `unit_unknown`, `package_unit`,
-- `conversion_same_unit`, `factor_invalid`, `conversion_unknown`; a conversion that is not defined is DKG02 with the units named.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0968: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- ── 1. the table ────────────────────────────────────────────────────────
create table public.unit_conversions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  from_unit text not null,
  to_unit text not null,
  -- 1 from_unit = factor_num / factor_den to_unit
  factor_num bigint not null check (factor_num > 0),
  factor_den bigint not null check (factor_den > 0),
  check (from_unit <> to_unit),
  foreign key (workspace_id, from_unit) references public.workspace_units (workspace_id, code),
  foreign key (workspace_id, to_unit) references public.workspace_units (workspace_id, code)
);
select public.ensure_system_columns('unit_conversions');
-- one definition per pair of units, whichever way round it was written
create unique index unit_conversions_pair on public.unit_conversions
  (workspace_id, least(from_unit, to_unit), greatest(from_unit, to_unit));

alter table public.unit_conversions enable row level security;
revoke all on table public.unit_conversions from public, anon, authenticated;
grant select on table public.unit_conversions to authenticated;
create policy unit_conversions_select on public.unit_conversions for select to authenticated
  using (public.is_member_of(workspace_id));
create policy mcp_delegated_deny on public.unit_conversions as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── 2. a unit and its conversions to the units of its dimension ─────────
-- The larger unit converts to the smaller (the reverse is the inverse factor); equal ones by code. Rows that exist are kept.
create or replace function public.unit_conversions_link(p_workspace_id uuid, p_code text)
returns void language sql security definer set search_path = public as $fn$
  insert into public.unit_conversions (workspace_id, from_unit, to_unit, factor_num, factor_den)
  select a.workspace_id, a.code, b.code,
         (a.factor_num * b.factor_den) / gcd(a.factor_num * b.factor_den, a.factor_den * b.factor_num),
         (a.factor_den * b.factor_num) / gcd(a.factor_num * b.factor_den, a.factor_den * b.factor_num)
    from public.workspace_units a
    join public.workspace_units b
      on b.workspace_id = a.workspace_id and b.dimension = a.dimension and b.code <> a.code
   where a.workspace_id = p_workspace_id and a.dimension <> 'package' and (a.code = p_code or b.code = p_code)
     and (a.factor_num * b.factor_den > a.factor_den * b.factor_num
          or (a.factor_num * b.factor_den = a.factor_den * b.factor_num and a.code < b.code))
  on conflict do nothing;
$fn$;
revoke execute on function public.unit_conversions_link(uuid, text) from public, anon, authenticated;

-- every business, from what its dimensions converted until now
select public.unit_conversions_link(u.workspace_id, u.code) from public.workspace_units u where u.dimension <> 'package';

create or replace function public.workspace_units_relink()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if tg_op = 'UPDATE' then
    delete from public.unit_conversions where workspace_id = new.workspace_id and (from_unit = new.code or to_unit = new.code);
  end if;
  if new.dimension <> 'package' then
    perform public.unit_conversions_link(new.workspace_id, new.code);
  end if;
  return new;
end;
$fn$;
revoke execute on function public.workspace_units_relink() from public, anon, authenticated;
create trigger workspace_units_relink_insert after insert on public.workspace_units
  for each row execute function public.workspace_units_relink();
create trigger workspace_units_relink_update after update of dimension, factor_num, factor_den on public.workspace_units
  for each row when ((old.dimension, old.factor_num, old.factor_den) is distinct from (new.dimension, new.factor_num, new.factor_den))
  execute function public.workspace_units_relink();

-- ── 3. THE rule ─────────────────────────────────────────────────────────
-- One step from [p_from] to [p_to]: the same unit is 1/1; an item's own conversion (its unit and its inventory unit, either way round)
-- comes first; then the business's general one (either way round); none is no row.
create or replace function public.unit_factor(p_workspace_id uuid, p_item_id uuid, p_from text, p_to text)
returns table (num bigint, den bigint)
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_inventory text;
begin
  if p_from is null or p_to is null or p_from = p_to then
    return query select 1::bigint, 1::bigint;
    return;
  end if;
  if p_item_id is not null then
    select inventory_unit into v_inventory from public.services where id = p_item_id and workspace_id = p_workspace_id;
    if p_to = v_inventory then
      return query select i.factor_num, i.factor_den from public.item_units i where i.item_id = p_item_id and i.unit = p_from;
      if found then return; end if;
    elsif p_from = v_inventory then
      return query select i.factor_den, i.factor_num from public.item_units i where i.item_id = p_item_id and i.unit = p_to;
      if found then return; end if;
    end if;
  end if;
  return query select c.factor_num, c.factor_den from public.unit_conversions c
                where c.workspace_id = p_workspace_id and c.from_unit = p_from and c.to_unit = p_to;
  if found then return; end if;
  return query select c.factor_den, c.factor_num from public.unit_conversions c
                where c.workspace_id = p_workspace_id and c.from_unit = p_to and c.to_unit = p_from;
end;
$fn$;
revoke execute on function public.unit_factor(uuid, uuid, text, text) from public, anon, authenticated;

create or replace function public.unit_convert(p_workspace_id uuid, p_item_id uuid, p_from text, p_to text, p_quantity numeric)
returns numeric language plpgsql stable security definer set search_path = public as $fn$
declare
  v_num bigint;
  v_den bigint;
begin
  select f.num, f.den into v_num, v_den from public.unit_factor(p_workspace_id, p_item_id, p_from, p_to) f;
  if v_num is null then
    raise exception 'no conversion from % to % is defined for this item', p_from, p_to using errcode = 'DKG02';
  end if;
  return p_quantity * v_num / v_den;
end;
$fn$;
revoke execute on function public.unit_convert(uuid, uuid, text, text, numeric) from public, anon, authenticated;

-- restates 0747 (stock_to_inventory; patched by 0952 and 0963)
create or replace function public.stock_to_inventory(p_item_id uuid, p_unit text, p_quantity numeric)
returns numeric language plpgsql stable security definer set search_path = public as $fn$
declare
  v_inventory text;
  v_ws uuid;
begin
  select inventory_unit, workspace_id into v_inventory, v_ws from public.services where id = p_item_id;
  if v_inventory is null then
    raise exception 'unknown item' using errcode = 'DKG04';
  end if;
  if p_unit is null or p_unit = v_inventory then
    return p_quantity;
  end if;
  return public.unit_convert(v_ws, p_item_id, p_unit, v_inventory, p_quantity);
end;
$fn$;

-- restates 0836 (stock_unit_factor; patched by 0952 and 0963)
create or replace function public.stock_unit_factor(p_item_id uuid, p_unit text)
returns table (num bigint, den bigint)
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_inventory text;
  v_ws uuid;
begin
  select inventory_unit, workspace_id into v_inventory, v_ws from public.services where id = p_item_id;
  return query select f.num, f.den from public.unit_factor(v_ws, p_item_id, p_unit, v_inventory) f;
end;
$fn$;

-- restates 0951 (workspace_unit_convert; patched by 0963): the business's general conversions, no dimension step
create or replace function public.workspace_unit_convert(p_workspace_id uuid, p_quantity text, p_from text, p_to text)
returns text language plpgsql stable security definer set search_path = public as $fn$
declare
  v_num bigint;
  v_den bigint;
  v_qty numeric;
  v_out numeric;
begin
  if not public.is_member_of(p_workspace_id) then
    raise exception 'not allowed to read the units of this business' using errcode = 'DKN01';
  end if;
  if coalesce(p_quantity, '') !~ '^-?[0-9]{1,12}(\.[0-9]{1,6})?$' then
    perform public.stock_config_refuse('quantity', 'out_of_range');
  end if;
  if not exists (select 1 from public.workspace_units where workspace_id = p_workspace_id and code = p_from)
     or not exists (select 1 from public.workspace_units where workspace_id = p_workspace_id and code = p_to) then
    perform public.stock_config_refuse('unit', 'unit_unknown');
  end if;
  select f.num, f.den into v_num, v_den from public.unit_factor(p_workspace_id, null, p_from, p_to) f;
  if v_num is null then
    perform public.stock_config_refuse('unit', 'dimension_mismatch');
  end if;
  v_qty := p_quantity::numeric;
  v_out := (v_qty * v_num) / v_den;
  if v_out <> round(v_out, 6) then
    perform public.stock_config_refuse('quantity', 'inexact');
  end if;
  return trim_scale(round(v_out, 6))::text;
end;
$fn$;

revoke execute on function public.stock_to_inventory(uuid, text, numeric) from public, anon;
revoke execute on function public.stock_unit_factor(uuid, text) from public, anon;
revoke execute on function public.workspace_unit_convert(uuid, text, text, text) from public, anon;

-- ── 4. the commands of the Settings screen ──────────────────────────────
create or replace function public.unit_conversion_save_v1(p_workspace_id uuid, p_request_id uuid, p_conversion jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_from text := p_conversion ->> 'from_unit';
  v_to text := p_conversion ->> 'to_unit';
  v_num bigint;
  v_den bigint;
  v_g bigint;
  v_out jsonb;
begin
  v_me := public.command_actor(p_workspace_id, 'workspaceSettings', 'unitsOfMeasure', 'not allowed to maintain the units', 'the units of measure are off');
  if jsonb_typeof(p_conversion) <> 'object' then
    perform public.stock_config_refuse('conversion', 'unit_unknown');
  end if;
  v_digest := md5(p_workspace_id::text || '|' || p_conversion::text);
  v_done := public.request_begin(p_workspace_id, p_request_id, 'unit_conversion_save', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  if not exists (select 1 from public.workspace_units where workspace_id = p_workspace_id and code = v_from) then
    perform public.stock_config_refuse('from_unit', 'unit_unknown');
  end if;
  if not exists (select 1 from public.workspace_units where workspace_id = p_workspace_id and code = v_to) then
    perform public.stock_config_refuse('to_unit', 'unit_unknown');
  end if;
  if v_from = v_to then
    perform public.stock_config_refuse('to_unit', 'conversion_same_unit');
  end if;
  if exists (select 1 from public.workspace_units where workspace_id = p_workspace_id and code in (v_from, v_to) and dimension = 'package') then
    perform public.stock_config_refuse('from_unit', 'package_unit');
  end if;
  if coalesce(p_conversion ->> 'factor_num', '') !~ '^[0-9]{1,15}$' or coalesce(p_conversion ->> 'factor_den', '1') !~ '^[0-9]{1,15}$' then
    perform public.stock_config_refuse('factor', 'factor_invalid');
  end if;
  v_num := (p_conversion ->> 'factor_num')::bigint;
  v_den := coalesce((p_conversion ->> 'factor_den')::bigint, 1);
  if v_num <= 0 or v_den <= 0 then
    perform public.stock_config_refuse('factor', 'factor_invalid');
  end if;
  v_g := gcd(v_num, v_den);
  v_num := v_num / v_g;
  v_den := v_den / v_g;
  -- one definition per pair: the one that was, either way round, is replaced
  delete from public.unit_conversions
   where workspace_id = p_workspace_id
     and ((from_unit = v_from and to_unit = v_to) or (from_unit = v_to and to_unit = v_from));
  insert into public.unit_conversions (workspace_id, from_unit, to_unit, factor_num, factor_den)
  values (p_workspace_id, v_from, v_to, v_num, v_den);
  v_out := jsonb_build_object('from_unit', v_from, 'to_unit', v_to, 'factor_num', v_num, 'factor_den', v_den);
  return public.request_finish(p_workspace_id, p_request_id, 'unit_conversion_save', v_digest, v_out);
end;
$fn$;
revoke execute on function public.unit_conversion_save_v1(uuid, uuid, jsonb) from public, anon;
grant execute on function public.unit_conversion_save_v1(uuid, uuid, jsonb) to authenticated;

create or replace function public.unit_conversion_delete_v1(p_workspace_id uuid, p_request_id uuid, p_from text, p_to text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_n int;
  v_out jsonb;
begin
  v_me := public.command_actor(p_workspace_id, 'workspaceSettings', 'unitsOfMeasure', 'not allowed to maintain the units', 'the units of measure are off');
  v_digest := md5(p_workspace_id::text || '|' || coalesce(p_from, '') || '|' || coalesce(p_to, ''));
  v_done := public.request_begin(p_workspace_id, p_request_id, 'unit_conversion_delete', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  delete from public.unit_conversions
   where workspace_id = p_workspace_id
     and ((from_unit = p_from and to_unit = p_to) or (from_unit = p_to and to_unit = p_from));
  get diagnostics v_n = row_count;
  if v_n = 0 then
    perform public.stock_config_refuse('conversion', 'conversion_unknown');
  end if;
  v_out := jsonb_build_object('from_unit', p_from, 'to_unit', p_to);
  return public.request_finish(p_workspace_id, p_request_id, 'unit_conversion_delete', v_digest, v_out);
end;
$fn$;
revoke execute on function public.unit_conversion_delete_v1(uuid, uuid, text, text) from public, anon;
grant execute on function public.unit_conversion_delete_v1(uuid, uuid, text, text) to authenticated;

-- ── 5. the business's export carries the table ──────────────────────────
-- restates 0966 (export_workspace_records): the list of the tables written whole gains `unit_conversions`, 'counter_receipt_copies' stays
create or replace function public.export_workspace_records(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tables text[] := array[
    -- configuration, readable (the XML stays the re-importable copy)
    'sites', 'fee_bands', 'packages', 'credit_products', 'vat_rates',
    'accessories', 'seat_accessories', 'closure_days', 'validation_policies',
    'workspace_roles', 'workspace_role_members', 'workspace_field_definitions',
    'workspace_field_values', 'number_sequences', 'charging_stations',
    'plan_images', 'setting_values',
    -- member accounts
    'member_credits', 'member_credit_uses', 'price_negotiations',
    'quota_extensions', 'usage_records', 'invoice_matches', 'invoice_reminders',
    'invoice_dunning_holds', 'tax_exemption_certificates',
    -- purchases, premises, assets, books
    'suppliers', 'purchase_documents', 'purchase_lines', 'purchase_obligations',
    'outgoing_payments', 'expense_schedules', 'expense_occurrences',
    'expense_repartitions', 'premises_leases', 'lease_terms',
    'lease_settlements', 'room_rentals', 'room_rental_fees', 'workspace_assets',
    'asset_valuation_batches', 'asset_valuation_rows', 'book_profiles',
    'book_accounts', 'book_mappings', 'book_periods', 'vat_declarations',
    'einvoice_inbox',
    -- people the space is accountable to
    'guest_participations', 'rights_requests',
    -- #3307 the orders to the suppliers
    'purchase_orders', 'purchase_order_lines', 'purchase_order_sends',
    'purchase_order_receipts', 'purchase_order_receipt_lines',
    -- #3308 the passes the space sells and the passes it sold
    'guest_pass_offers', 'guest_passes',
    -- #3824 the goods ledger
    'item_units', 'item_codes', 'stock_locations', 'stock_lots', 'stock_movements',
    'stock_balances',
    -- #4362 the tags bound to items, places and pieces, and the named pieces
    'stock_tags', 'stock_tagged_units', 'stock_movement_units',
    'stock_handling_units', 'stock_handling_unit_lines', 'stock_handling_unit_pieces', 'stock_movement_handling_units',
    'stock_repacks', 'stock_repack_lines',
    -- #4184 the counter's receipts, their lines and their tenders
    'counter_receipts', 'counter_receipt_lines', 'counter_tenders', 'counter_refunds',
    -- #4367 the tills, their sessions, the cash entries and the day closes
    'counter_tills', 'counter_till_sessions', 'counter_cash_entries', 'counter_day_closes',
    -- #4373 the sales a till made offline, as the server received them
    'counter_offline_sales',
    -- #4164 the billing identity of each customer the business invoices
    'billing_parties',
    -- #4166 the customer quotes, their revisions, the decisions the issuer recorded and
    -- the conversions into invoices
    'customer_quotes', 'customer_quote_revisions', 'customer_quote_decisions',
    'customer_quote_conversions',
    -- #4169 the variants and the supplier's article
    'item_dimensions', 'item_dimension_values', 'item_variants', 'item_variant_values',
    'supplier_item_mappings',
    -- #4171 what was put away from a delivery
    'stock_receipt_allocations',
    -- #4170 the transfers between sites and what each loaded
    'stock_transfers', 'stock_transfer_lines',
    -- #4294 the reorder points
    'stock_reorder_points', 'item_groups', 'item_group_history',
    -- #4172 the returns, and what each line reversed
    'stock_returns', 'stock_reversals',
    -- #4172 the counts and their decisions
    'stock_counts',
    -- #4295 the plans, the tasks and their lines
    'stock_count_plans', 'stock_count_tasks', 'stock_count_task_lines',
    -- #4178 the engagements of the services ordered, their steps and the invoice
    -- lines that billed a direct commitment
    'service_fulfilments', 'service_fulfilment_transitions', 'service_fulfilment_invoice_links',
    -- #4436 the track IDs frozen on the goods lines of an issued invoice
    'invoice_line_tracks',
    -- #4442 the units of measure of the business and their conversions
    'workspace_units', 'unit_conversions',
    -- #4476 the copies printed of a counter receipt
    'counter_receipt_copies'];
  v_left_out text[] := public.system_column_names() || array['workspace_id', 'source_xml'];
  v_table text;
  v_columns text[];
  v_rows jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'only someone who may export this workspace''s data reads its records'
      using errcode = 'DKN01';
  end if;
  foreach v_table in array v_tables loop
    -- the sessions, their entries and the day closes carry the expected cash and the differences: the finances' to export
    if v_table in ('counter_till_sessions', 'counter_cash_entries', 'counter_day_closes', 'counter_offline_sales', 'invoice_line_tracks') and not public.has_permission(p_workspace_id, 'viewFinances') then
      continue;
    end if;
    select array_agg(c.column_name::text order by c.ordinal_position) into v_columns
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = v_table
       and c.column_name <> all (v_left_out);
    execute format(
      'select coalesce(jsonb_agg(jsonb_build_array(%s) order by created_datetime), ''[]''::jsonb)
         from public.%I where workspace_id = $1',
      (select string_agg(format('%I', c), ', ') from unnest(v_columns) c), v_table)
      into v_rows using p_workspace_id;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'table', v_table, 'columns', to_jsonb(v_columns), 'rows', v_rows));
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.export_workspace_records(uuid) from public, anon;
grant execute on function public.export_workspace_records(uuid) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(968);
