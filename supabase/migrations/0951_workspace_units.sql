-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one new table, seeded for every business; new internal and exposed functions; export_workspace_records restated
-- whole with the table; stock, invoices and quotes keep reading what they read)
--
-- #4442 (first server bundle) -- each business keeps its own units of measure, and the owner and the admins maintain
-- them and their conversions (1 km = 1000 m). `stock_units` (0747) stays the installation-wide list the stock ledger is
-- bound to by its foreign keys; moving those onto this table is the next step (and it is why a custom unit cannot yet be
-- picked by an item: the screens that pick come after it). Nothing existing changes.
--
--   * `workspace_units(workspace_id, code, label, dimension, factor_num, factor_den, un_ece_code, built_in, archived,
--     sort_order)`: the dimension is count, mass, volume, length, area or time; the factor is the exact fraction to the
--     dimension's base unit (piece, g, ml, m, m2, min), reduced; a built-in unit has no label (the app names it in the
--     member's language) unless the business renamed it. Every business starts with the 13 built-ins: the six of 0747
--     plus mm, cm, m, km, m2, min and h; a business created later gets them by a trigger.
--   * The feature `unitsOfMeasure` (a registry row, asked for, requiring nothing) puts the screen in the app and gates the two
--     commands; the built-in units and the conversion are there whether it is on or not.
--   * Who maintains them: `workspaceSettings` (the owner and the admins, and a role the business gave it). A new
--     permission would be restated into the catalogue, the roles screen and the Dart enum for no new audience: units are
--     business configuration, used by invoice and quote lines of a business without any stock as much as by stock.
--   * One code, one meaning: a unit cannot be created with a code an item already uses for its own packaging unit (a box of
--     6), the reverse of 0952's rule that a packaging unit may not take the code of a unit of the business (`code_duplicate`).
--   * A unit is never deleted. A unit that is used (an item's inventory or purchase unit, an item unit or code, a purchase
--     line, a stock movement or receipt allocation, a tag, a supplier mapping, a draft, a quote or an issued invoice line) keeps
--     its code, its dimension and its factor, and cannot be archived: a correction is a new unit. A built-in unit keeps
--     its code, dimension and factor always; its label, UN/ECE code, order and archived state are the business's.
--   * `workspace_unit_save_v1` creates or edits, `workspace_unit_archive_v1` hides or shows; both go through
--     `command_actor` and `request_begin` / `request_finish` (0948), so a retried request answers once.
--   * `workspace_unit_convert` converts exactly through the base unit and answers the quantity as text; two dimensions
--     are refused, and so is an answer the six-decimal ledger cannot hold exactly.
--   * Refusals are the stock configuration's own (DKG11, the field and the reason in the detail, read by the app since
--     0836): the reasons code_malformed, factor_invalid, unit_unknown, dimension_mismatch, registry_unit (a built-in
--     unit's dimension and factor are fixed) and too_long have their words already; unit_in_use, unit_fixed,
--     dimension_invalid, label_required, ece_invalid and inexact read as "This is not valid." until the Settings
--     screen (the next bundle) gives them theirs. No new code: the lint that lists the codes the app does not read has
--     a ceiling that only falls.
--
-- restates 0945 (export_workspace_records): the table joins the business's export; restates 0936 (setup_level_catalogue):
-- the generated catalogue names the feature.

create table public.workspace_units (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  code text not null check (code ~ '^[a-z][a-z0-9_]{0,19}$'),
  label text check (label is null or char_length(btrim(label)) between 1 and 40),
  dimension text not null check (dimension in ('count', 'mass', 'volume', 'length', 'area', 'time')),
  factor_num bigint not null check (factor_num > 0),
  factor_den bigint not null check (factor_den > 0),
  un_ece_code text check (un_ece_code is null or un_ece_code ~ '^[A-Z0-9]{2,3}$'),
  built_in boolean not null default false,
  archived boolean not null default false,
  sort_order int not null default 1000 check (sort_order between 0 and 100000),
  check (built_in or label is not null),
  unique (workspace_id, code)
);
select public.ensure_system_columns('workspace_units');

-- the feature that puts the maintenance screen in the app: a row of the registry (0949), asked for, requiring nothing
-- BEGIN FEATURE REGISTRY ROWS (dart run tool/build_feature_registry_sql.dart)
insert into public.feature_registry_entries (feature_key, parent, default_on, core, countries) values
('unitsOfMeasure', null, false, false, null)
on conflict (feature_key) do update set parent = excluded.parent, default_on = excluded.default_on, core = excluded.core, countries = excluded.countries;
-- END FEATURE REGISTRY ROWS

-- the built-ins every business starts with: (code, dimension, factor, UN/ECE code, order)
create or replace function public.workspace_units_seed(p_workspace_id uuid)
returns void language sql security definer set search_path = public as $fn$
  insert into public.workspace_units (workspace_id, code, dimension, factor_num, factor_den, un_ece_code, built_in, sort_order)
  select p_workspace_id, b.code, b.dimension, b.num, b.den, b.ece, true, b.ord
    from (values
      ('piece', 'count', 1, 1, 'C62', 10),
      ('g', 'mass', 1, 1, 'GRM', 20), ('kg', 'mass', 1000, 1, 'KGM', 30),
      ('ml', 'volume', 1, 1, 'MLT', 40), ('cl', 'volume', 10, 1, 'CLT', 50), ('l', 'volume', 1000, 1, 'LTR', 60),
      ('mm', 'length', 1, 1000, 'MMT', 70), ('cm', 'length', 1, 100, 'CMT', 80), ('m', 'length', 1, 1, 'MTR', 90),
      ('km', 'length', 1000, 1, 'KMT', 100),
      ('m2', 'area', 1, 1, 'MTK', 110),
      ('min', 'time', 1, 1, 'MIN', 120), ('h', 'time', 60, 1, 'HUR', 130)
    ) as b (code, dimension, num, den, ece, ord)
  on conflict (workspace_id, code) do nothing;
$fn$;
revoke execute on function public.workspace_units_seed(uuid) from public, anon, authenticated;

select public.workspace_units_seed(w.id) from public.workspaces w;

create or replace function public.workspace_units_seed_trigger()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  perform public.workspace_units_seed(new.id);
  return new;
end;
$fn$;
revoke execute on function public.workspace_units_seed_trigger() from public, anon, authenticated;
create trigger workspaces_seed_units after insert on public.workspaces
  for each row execute function public.workspace_units_seed_trigger();

-- how many places of the business hold [p_code] as a unit: the units of its items, groups, lines, movements, tags and
-- documents. A unit with a count above zero is used, and used is frozen.
create or replace function public.workspace_unit_uses(p_workspace_id uuid, p_code text)
returns bigint language sql stable security definer set search_path = public as $fn$
  select (select count(*) from public.services where workspace_id = p_workspace_id and inventory_unit = p_code)
       + (select count(*) from public.item_groups where workspace_id = p_workspace_id and (inventory_unit = p_code or default_purchase_unit = p_code))
       + (select count(*) from public.item_units where workspace_id = p_workspace_id and unit = p_code)
       + (select count(*) from public.item_codes where workspace_id = p_workspace_id and unit = p_code)
       + (select count(*) from public.purchase_lines where workspace_id = p_workspace_id and unit = p_code)
       + (select count(*) from public.purchase_order_lines where workspace_id = p_workspace_id and unit = p_code)
       + (select count(*) from public.stock_movements where workspace_id = p_workspace_id and entered_unit = p_code)
       + (select count(*) from public.stock_receipt_allocations where workspace_id = p_workspace_id and entered_unit = p_code)
       + (select count(*) from public.stock_tags where workspace_id = p_workspace_id and unit_code = p_code)
       + (select count(*) from public.supplier_item_mappings where workspace_id = p_workspace_id and purchase_unit = p_code)
       + (select count(*) from public.invoices where workspace_id = p_workspace_id
           and jsonb_path_exists(lines, '$[*] ? (@.unit.code == $c || @.commercial.unit.code == $c)', jsonb_build_object('c', p_code)))
       + (select count(*) from public.customer_quote_revisions where workspace_id = p_workspace_id
           and jsonb_path_exists(lines, '$[*] ? (@.unit.code == $c || @.commercial.unit.code == $c)', jsonb_build_object('c', p_code)))
       + (select count(*) from public.standalone_invoice_drafts where workspace_id = p_workspace_id
           and jsonb_path_exists(lines, '$[*] ? (@.unit.code == $c || @.commercial.unit.code == $c)', jsonb_build_object('c', p_code)));
$fn$;
revoke execute on function public.workspace_unit_uses(uuid, text) from public, anon, authenticated;

-- the rules of a row: nothing is deleted, the code and the business never move, a built-in keeps its dimension and
-- factor, and a used unit keeps them and stays visible
create or replace function public.workspace_units_guard()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' then
    if pg_trigger_depth() > 1 and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
      return old;
    end if;
    perform public.stock_config_refuse('unit', 'unit_fixed');
  end if;
  if new.workspace_id <> old.workspace_id or new.code <> old.code or new.built_in <> old.built_in then
    perform public.stock_config_refuse('code', 'unit_fixed');
  end if;
  if (new.dimension, new.factor_num, new.factor_den) is distinct from (old.dimension, old.factor_num, old.factor_den) then
    if old.built_in then
      perform public.stock_config_refuse('factor', 'registry_unit');
    end if;
    if public.workspace_unit_uses(old.workspace_id, old.code) > 0 then
      perform public.stock_config_refuse('factor', 'unit_in_use');
    end if;
  end if;
  if new.archived and not old.archived and public.workspace_unit_uses(old.workspace_id, old.code) > 0 then
    perform public.stock_config_refuse('archived', 'unit_in_use');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.workspace_units_guard() from public, anon, authenticated;
create trigger workspace_units_rules before update or delete on public.workspace_units
  for each row execute function public.workspace_units_guard();

alter table public.workspace_units enable row level security;
revoke all on table public.workspace_units from public, anon, authenticated;
grant select on table public.workspace_units to authenticated;
create policy workspace_units_select on public.workspace_units for select to authenticated
  using (public.is_member_of(workspace_id));
create policy mcp_delegated_deny on public.workspace_units as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── writing: one command creates or edits, one hides or shows ──────────────────────────────────────────
create or replace function public.workspace_unit_save_v1(p_workspace_id uuid, p_request_id uuid, p_unit jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_code text := p_unit ->> 'code';
  v_row public.workspace_units;
  v_new boolean;
  v_num bigint;
  v_den bigint;
  v_g bigint;
  v_dim text;
  v_label text;
  v_ece text;
  v_out jsonb;
begin
  v_me := public.command_actor(p_workspace_id, 'workspaceSettings', 'unitsOfMeasure', 'not allowed to maintain the units', 'the units of measure are off');
  if jsonb_typeof(p_unit) <> 'object' or coalesce(v_code, '') !~ '^[a-z][a-z0-9_]{0,19}$' then
    perform public.stock_config_refuse('code', 'code_malformed');
  end if;
  v_digest := md5(p_workspace_id::text || '|' || p_unit::text);
  v_done := public.request_begin(p_workspace_id, p_request_id, 'workspace_unit_save', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_row from public.workspace_units where workspace_id = p_workspace_id and code = v_code for update;
  v_new := v_row.id is null;
  -- the fields as given, or as they were
  v_label := case when p_unit ? 'label' then nullif(btrim(p_unit ->> 'label'), '') else v_row.label end;
  v_dim := coalesce(p_unit ->> 'dimension', v_row.dimension);
  v_ece := case when p_unit ? 'un_ece_code' then nullif(btrim(p_unit ->> 'un_ece_code'), '') else v_row.un_ece_code end;
  v_num := coalesce(case when p_unit ? 'factor_num' then (p_unit ->> 'factor_num')::bigint end, v_row.factor_num);
  v_den := coalesce(case when p_unit ? 'factor_den' then (p_unit ->> 'factor_den')::bigint end, v_row.factor_den, 1);
  if v_dim is null or v_dim not in ('count', 'mass', 'volume', 'length', 'area', 'time') then
    perform public.stock_config_refuse('dimension', 'dimension_invalid');
  end if;
  if v_num is null or v_num <= 0 or v_den <= 0 then
    perform public.stock_config_refuse('factor', 'factor_invalid');
  end if;
  v_g := gcd(v_num, v_den);
  v_num := v_num / v_g;
  v_den := v_den / v_g;
  -- one code, one meaning: a code an item already uses for its own packaging (a box of 6) is not given to a unit of the business
  if v_new and exists (select 1 from public.item_units iu where iu.workspace_id = p_workspace_id and iu.unit = v_code) then
    perform public.stock_config_refuse('code', 'code_duplicate');
  end if;
  if v_new and v_label is null then
    perform public.stock_config_refuse('label', 'label_required');
  end if;
  if v_label is not null and char_length(v_label) > 40 then
    perform public.stock_config_refuse('label', 'too_long');
  end if;
  if v_ece is not null and v_ece !~ '^[A-Z0-9]{2,3}$' then
    perform public.stock_config_refuse('un_ece_code', 'ece_invalid');
  end if;
  if v_new then
    insert into public.workspace_units (workspace_id, code, label, dimension, factor_num, factor_den, un_ece_code, sort_order)
    values (p_workspace_id, v_code, v_label, v_dim, v_num, v_den, v_ece, coalesce((p_unit ->> 'sort_order')::int, 1000))
    returning * into v_row;
  else
    -- the guard refuses a fixed or used dimension and factor
    update public.workspace_units
       set label = v_label, dimension = v_dim, factor_num = v_num, factor_den = v_den, un_ece_code = v_ece,
           sort_order = coalesce((p_unit ->> 'sort_order')::int, sort_order)
     where id = v_row.id
    returning * into v_row;
  end if;
  v_out := jsonb_build_object('code', v_row.code, 'label', v_row.label, 'dimension', v_row.dimension,
                              'factor_num', v_row.factor_num, 'factor_den', v_row.factor_den,
                              'un_ece_code', v_row.un_ece_code, 'built_in', v_row.built_in,
                              'archived', v_row.archived, 'sort_order', v_row.sort_order);
  return public.request_finish(p_workspace_id, p_request_id, 'workspace_unit_save', v_digest, v_out);
end;
$fn$;
revoke execute on function public.workspace_unit_save_v1(uuid, uuid, jsonb) from public, anon;
grant execute on function public.workspace_unit_save_v1(uuid, uuid, jsonb) to authenticated;

create or replace function public.workspace_unit_archive_v1(p_workspace_id uuid, p_request_id uuid, p_code text, p_archived boolean)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_row public.workspace_units;
  v_out jsonb;
begin
  v_me := public.command_actor(p_workspace_id, 'workspaceSettings', 'unitsOfMeasure', 'not allowed to maintain the units', 'the units of measure are off');
  v_digest := md5(p_workspace_id::text || '|' || coalesce(p_code, '') || '|' || coalesce(p_archived::text, ''));
  v_done := public.request_begin(p_workspace_id, p_request_id, 'workspace_unit_archive', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_row from public.workspace_units where workspace_id = p_workspace_id and code = p_code for update;
  if v_row.id is null then
    perform public.stock_config_refuse('unit', 'unit_unknown');
  end if;
  update public.workspace_units set archived = coalesce(p_archived, true) where id = v_row.id returning * into v_row;
  v_out := jsonb_build_object('code', v_row.code, 'archived', v_row.archived);
  return public.request_finish(p_workspace_id, p_request_id, 'workspace_unit_archive', v_digest, v_out);
end;
$fn$;
revoke execute on function public.workspace_unit_archive_v1(uuid, uuid, text, boolean) from public, anon;
grant execute on function public.workspace_unit_archive_v1(uuid, uuid, text, boolean) to authenticated;

-- ── converting: exactly, through the dimension's base unit ──────────────────────────────────────────────
create or replace function public.workspace_unit_convert(p_workspace_id uuid, p_quantity text, p_from text, p_to text)
returns text language plpgsql stable security definer set search_path = public as $fn$
declare
  v_from public.workspace_units;
  v_to public.workspace_units;
  v_qty numeric;
  v_out numeric;
begin
  if not public.is_member_of(p_workspace_id) then
    raise exception 'not allowed to read the units of this business' using errcode = 'DKN01';
  end if;
  if coalesce(p_quantity, '') !~ '^-?[0-9]{1,12}(\.[0-9]{1,6})?$' then
    perform public.stock_config_refuse('quantity', 'out_of_range');
  end if;
  select * into v_from from public.workspace_units where workspace_id = p_workspace_id and code = p_from;
  select * into v_to from public.workspace_units where workspace_id = p_workspace_id and code = p_to;
  if v_from.id is null or v_to.id is null then
    perform public.stock_config_refuse('unit', 'unit_unknown');
  end if;
  if v_from.dimension <> v_to.dimension then
    perform public.stock_config_refuse('unit', 'dimension_mismatch');
  end if;
  v_qty := p_quantity::numeric;
  -- quantity x (from_num / from_den) / (to_num / to_den), kept as a fraction until the last division
  v_out := (v_qty * v_from.factor_num * v_to.factor_den) / (v_from.factor_den * v_to.factor_num);
  if v_out <> round(v_out, 6) then
    perform public.stock_config_refuse('quantity', 'inexact');
  end if;
  return trim_scale(round(v_out, 6))::text;
end;
$fn$;
revoke execute on function public.workspace_unit_convert(uuid, text, text, text) from public, anon;
grant execute on function public.workspace_unit_convert(uuid, text, text, text) to authenticated;

-- ── the export carries the table ────────────────────────────────────────────────────────────────────────
-- restates 0945
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
    'workspace_units'];
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

-- ── the setup levels name the feature (dart run tool/build_setup_steps.dart, #2923) ─────────────────────────────────────
-- restates 0936
create or replace function public.setup_level_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json${"processes":[{"process":"bookings","levels":[{"level":"none","features":[],"needs":[]},{"level":"simple","features":["seriesBooking","bookForOthers","spaceQrCodes","workingHours","planObjectDelete","bookingPolicies","seatDayTimeline","bookingGate","singleRoomLevelNames","calendarFileExport","placeFeedback","planDecor","placeBooking"],"needs":[]},{"level":"resources","features":["adminSeatBlocking","levelBooking","adminLevelAssign","planMemberPhotos","multiSite","publicHolidays","holidayImport","guestParticipation","meetingRooms","parking","externalRooms"],"needs":[]},{"level":"measured","features":["kioskMode","nfcBadges","autoCheckInOut","nfcSeatTags","qrBadges","kioskMemberPhotos","badgeSignIn","capacityKpi","kioskEnrolment"],"needs":[]}]},{"process":"community","levels":[{"level":"basic","features":["calendarTab","eventsTab","pushNotifications","membersDirectory","memberNotifications","deletionRequests","roleManagement","notificationGrouping","calendarHub","richMessageRefs","personalInfo","messageGestures","calendarViews","messagesHub","memberPage","messageForwarding","captureProtection","roleAssignment","messageMentions"],"needs":[]},{"level":"organised","features":["whatsappIntegration","coOwner","validationScopes","validationChain","calendarValidations","managedProfiles","managedProfileAccess","memberOrigin","customRoles","customFields"],"needs":[]}]},{"process":"money","levels":[{"level":"none","features":[],"needs":[]},{"level":"statements","features":["moneyTab","services","accessorySupplements","memberReports","dataAccessLog","financeFaces","priceNegotiations"],"needs":[]},{"level":"invoices","features":["invoicing","adminInvoicing","invoicePdfTemplate","invoiceAddressWindow","dunning","paymentReminders","usageRecords","reportDesignExchange","reportLayouts","numberSequences","workspaceStatus","memberPaymentTerms","reportTexts","usageReport","letterStandard","subscriptionInvoices","usageInvoices","invoiceSettlement","invoiceJourney","reportDesigner","invoicingWizard","settlementFold","carnets","guestPasses","reminderEmail","invoiceEmail","standaloneInvoicing","billingCustomers","customerQuotes","serviceFulfilment"],"needs":[]}]},{"process":"payments","levels":[{"level":"off","features":[],"needs":[]},{"level":"online","features":["onlinePayments"],"needs":[{"process":"money","level":"statements"}]}]},{"process":"tax","levels":[{"level":"none","features":[],"needs":[]},{"level":"vat","features":["vatManagement","vatDeclarations","vatGroups","vatRateHistory","vatCounterparty","vatReport","supplyClassification","viesVerification","recapitulativeStatement","inputVat","salesTax"],"needs":[{"process":"money","level":"invoices"}]},{"level":"books","features":["einvoiceCustomerDelivery","accountingBook","accountingPeriods","accountingConnectors","bankImport","mtdSubmission"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"purchases","levels":[{"level":"none","features":[],"needs":[]},{"level":"expenses","features":["supplyExpenses","expenseRepartitionWizard","scheduledExpenses","expenseRepartition"],"needs":[{"process":"money","level":"invoices"}]},{"level":"full","features":["purchases","premisesLease","assetRegister","purchaseAnalytics","foreignCurrencyPurchases","purchaseOrders","stockManagement","stockLots","stockReceiving","stockTakeOut","stockReorder","stockReturns","stockCounts","stockCycleCounts","stockItemGroups","stockTags","stockScanning","counterReceipts","counterTillSessions","stockTagReads","stockExpiryReport","stockHandlingUnits","counterOfflineCash","unitsOfMeasure"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"presentation","levels":[{"level":"basic","features":["uniqueMonograms"],"needs":[]},{"level":"branded","features":["workspaceVocabulary","workspaceBranding"],"needs":[]},{"level":"public","features":["publicListings","spaceInquiries"],"needs":[]}]},{"process":"operations","levels":[{"level":"basic","features":["pdfExport","dataExport","documents","formHelpHints","uiAnimations","regionalFormats","memberDataExport","navigationStyle","demoMode","memberAccountMenu","memberGettingStarted","setupGuide","dataReport","quickSearch","organisation"],"needs":[]},{"level":"insight","features":["decisionSurface","biReportDesigner","workspaceOverview"],"needs":[]},{"level":"advanced","features":["environmentPairs","deployments","configurationTransfer","instanceWizard","memberEnvironments","workspaceLibrary","configurableSettings"],"needs":[]}]},{"process":"assistant","levels":[{"level":"off","features":[],"needs":[]},{"level":"on","features":["recordingPrivacy","mcpAccess","taskRecorder","webMcp"],"needs":[]}]}],"presets":[{"preset":"essentiel","levels":[{"process":"bookings","level":"simple"},{"process":"community","level":"basic"},{"process":"money","level":"statements"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"none"},{"process":"presentation","level":"basic"},{"process":"operations","level":"basic"},{"process":"assistant","level":"off"}]},{"preset":"standard","levels":[{"process":"bookings","level":"resources"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"expenses"},{"process":"presentation","level":"branded"},{"process":"operations","level":"insight"},{"process":"assistant","level":"off"}]},{"preset":"complet","levels":[{"process":"bookings","level":"measured"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"online"},{"process":"tax","level":"books"},{"process":"purchases","level":"full"},{"process":"presentation","level":"public"},{"process":"operations","level":"advanced"},{"process":"assistant","level":"off"}]}]}$json$::jsonb;
$fn$;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;

-- ── the builtin association template writes the feature flags: it names the feature (dart run tool/build_builtin_templates.dart) ──
-- restates 0938
insert into public.workspace_templates
  (key, name, description, sort_order, visibility, schema_version, template_version,
   tags, entities, configuration, floor_plan)
values (
  'association_fr',
  'Association de coworking (France)',
  'Pour une association de coworking en France : demi-journées de 7 h à 13 h et de 13 h à 19 h du lundi au vendredi, jours fériés de l''année et de la suivante, cotisations à 50 % et 100 %, deux carnets prépayés pour qui ne cotise pas, les rôles du bureau, un calendrier où se prennent les validations, les mots de l''association, et deux étages prêts à réserver.',
  1,
  'builtin',
  1,
  1,
  array['association', 'coworking', 'france'],
  array['identity', 'tariffs', 'credit_products', 'floor_plan', 'booking_rules', 'closure_days', 'lexicon', 'workspace_roles', 'features'],
  $cfg${
  "workspace": {
    "default_locale": "fr",
    "vat_regime": "not_subject",
    "booking_rules": {
      "granularity": "half_day",
      "open_weekdays": [
        1,
        2,
        3,
        4,
        5
      ],
      "work_start_minutes": 420,
      "half_boundary_minutes": 780,
      "work_end_minutes": 1140,
      "max_series_days": 180,
      "advance_horizon_days": 90,
      "max_duration_minutes": 1440,
      "min_duration_minutes": 30
    },
    "subscription_levels": {
      "allow_custom": false,
      "extra_levels": [],
      "enabled_presets": [
        50,
        100
      ]
    },
    "feature_flags": {
      "accessorySupplements": false,
      "accountingBook": false,
      "accountingConnectors": false,
      "accountingPeriods": false,
      "adminInvoicing": false,
      "adminLevelAssign": false,
      "adminSeatBlocking": false,
      "assetRegister": false,
      "autoCheckInOut": false,
      "badgeSignIn": false,
      "bankImport": false,
      "biReportDesigner": false,
      "billingCustomers": false,
      "bookForOthers": true,
      "bookingGate": true,
      "bookingPolicies": true,
      "calendarFileExport": true,
      "calendarHub": true,
      "calendarTab": true,
      "calendarValidations": true,
      "calendarViews": true,
      "capacityKpi": false,
      "captureProtection": true,
      "carnets": true,
      "coOwner": false,
      "configurableSettings": false,
      "configurationTransfer": false,
      "counterOfflineCash": false,
      "counterReceipts": false,
      "counterTillSessions": false,
      "customFields": false,
      "customRoles": true,
      "customerQuotes": false,
      "dataAccessLog": false,
      "dataExport": true,
      "dataReport": true,
      "decisionSurface": false,
      "deletionRequests": true,
      "demoMode": false,
      "deployments": false,
      "documents": true,
      "dunning": false,
      "einvoiceCustomerDelivery": false,
      "environmentPairs": false,
      "eventsTab": false,
      "expenseRepartition": false,
      "expenseRepartitionWizard": false,
      "externalRooms": false,
      "financeFaces": true,
      "foreignCurrencyPurchases": false,
      "formHelpHints": true,
      "guestParticipation": false,
      "guestPasses": false,
      "holidayImport": false,
      "inputVat": false,
      "instanceWizard": false,
      "invoiceAddressWindow": false,
      "invoiceEmail": false,
      "invoiceJourney": false,
      "invoicePdfTemplate": false,
      "invoiceSettlement": false,
      "invoicing": true,
      "invoicingWizard": false,
      "kioskEnrolment": false,
      "kioskMemberPhotos": false,
      "kioskMode": false,
      "letterStandard": false,
      "levelBooking": false,
      "managedProfileAccess": false,
      "managedProfiles": false,
      "mcpAccess": false,
      "meetingRooms": false,
      "memberAccountMenu": false,
      "memberDataExport": true,
      "memberEnvironments": false,
      "memberGettingStarted": true,
      "memberNotifications": true,
      "memberOrigin": false,
      "memberPage": false,
      "memberPaymentTerms": false,
      "memberReports": false,
      "membersDirectory": false,
      "messageForwarding": true,
      "messageGestures": true,
      "messageMentions": true,
      "messagesHub": true,
      "moneyTab": true,
      "mtdSubmission": false,
      "multiSite": false,
      "navigationStyle": true,
      "nfcBadges": false,
      "nfcSeatTags": false,
      "notificationGrouping": false,
      "numberSequences": false,
      "onlinePayments": false,
      "organisation": true,
      "parking": false,
      "paymentReminders": false,
      "pdfExport": true,
      "personalInfo": true,
      "personalShell": false,
      "placeBooking": true,
      "placeFeedback": true,
      "planDecor": true,
      "planMemberPhotos": false,
      "planObjectDelete": true,
      "premisesLease": false,
      "priceNegotiations": false,
      "publicHolidays": false,
      "publicListings": false,
      "purchaseAnalytics": false,
      "purchaseOrders": false,
      "purchases": false,
      "pushNotifications": true,
      "qrBadges": false,
      "quickSearch": true,
      "recapitulativeStatement": false,
      "recordingPrivacy": false,
      "regionalFormats": true,
      "reminderEmail": false,
      "reportDesignExchange": false,
      "reportDesigner": false,
      "reportLayouts": false,
      "reportTexts": false,
      "richMessageRefs": true,
      "roleAssignment": true,
      "roleManagement": true,
      "salesTax": false,
      "scheduledExpenses": false,
      "seatDayTimeline": true,
      "seriesBooking": true,
      "serviceFulfilment": false,
      "services": true,
      "settlementFold": false,
      "setupGuide": true,
      "singleRoomLevelNames": true,
      "spaceInquiries": true,
      "spaceQrCodes": true,
      "standaloneInvoicing": false,
      "stockCounts": false,
      "stockCycleCounts": false,
      "stockExpiryReport": false,
      "stockHandlingUnits": false,
      "stockItemGroups": false,
      "stockLots": false,
      "stockManagement": false,
      "stockReceiving": false,
      "stockReorder": false,
      "stockReturns": false,
      "stockScanning": false,
      "stockTagReads": false,
      "stockTags": false,
      "stockTakeOut": false,
      "subscriptionInvoices": false,
      "supplyClassification": false,
      "supplyExpenses": false,
      "taskRecorder": false,
      "uiAnimations": true,
      "uniqueMonograms": true,
      "unitsOfMeasure": false,
      "usageInvoices": false,
      "usageRecords": false,
      "usageReport": false,
      "validationChain": false,
      "validationScopes": false,
      "vatCounterparty": false,
      "vatDeclarations": false,
      "vatGroups": false,
      "vatManagement": false,
      "vatRateHistory": false,
      "vatReport": false,
      "viesVerification": false,
      "webMcp": false,
      "whatsappIntegration": false,
      "workingHours": true,
      "workspaceBranding": false,
      "workspaceLibrary": false,
      "workspaceOverview": false,
      "workspaceStatus": false,
      "workspaceVocabulary": true
    },
    "lexicon": {
      "fr": {
        "spaceKindSeat": "Place",
        "spaceKindLevel": "Étage",
        "shellReserveButton": "Réservations"
      }
    }
  },
  "tables": {
    "fee_bands": [
      {
        "from_pct": 0,
        "to_pct": 50,
        "fee_cents": 5000,
        "overage_fee_cents": 0
      },
      {
        "from_pct": 50,
        "to_pct": 100,
        "fee_cents": 10000,
        "overage_fee_cents": 0
      }
    ],
    "workspace_roles": [
      {
        "key": "tresorier",
        "names": {
          "fr": "Trésorier·ère",
          "en": "Treasurer",
          "de": "Kassenwart",
          "es": "Tesorero/a",
          "it": "Tesoriere"
        },
        "permissions": [
          "viewFinances",
          "issueInvoices",
          "manageBilling",
          "approveExpenses",
          "exportData"
        ],
        "sort_order": 1,
        "active": true
      },
      {
        "key": "secretaire",
        "names": {
          "fr": "Secrétaire",
          "en": "Secretary",
          "de": "Schriftführer",
          "es": "Secretario/a",
          "it": "Segretario"
        },
        "permissions": [
          "manageMembers",
          "manageDocuments",
          "viewPersonalData"
        ],
        "sort_order": 2,
        "active": true
      },
      {
        "key": "referent_salle",
        "names": {
          "fr": "Référent·e de salle",
          "en": "Room steward",
          "de": "Raumverantwortlicher",
          "es": "Responsable de sala",
          "it": "Referente di sala"
        },
        "permissions": [
          "manageReservations",
          "manageValidation",
          "operateKiosk"
        ],
        "sort_order": 3,
        "active": true
      }
    ],
    "credit_products": [
      {
        "name": "Carnet 10 demi-journées",
        "half_days": 10,
        "price_cents": 5000,
        "validity_months": null,
        "active": true,
        "sort_order": 1
      },
      {
        "name": "Carnet 20 demi-journées",
        "half_days": 20,
        "price_cents": 8000,
        "validity_months": null,
        "active": true,
        "sort_order": 2
      }
    ]
  },
  "holidays": {
    "years": 2
  }
}$cfg$::jsonb,
  $tpl$[
  {
    "name": "Rez-de-chaussée",
    "sort_order": 0,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": [
      {
        "name": "Salle principale",
        "color": 0,
        "bookable_as_whole": true,
        "price_cents": 0,
        "x": 0,
        "y": 0,
        "w": 40,
        "h": 24,
        "desks": [
          {
            "name": "Table 1",
            "x": 2,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "A1",
                "x": 4,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "A2",
                "x": 12,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          },
          {
            "name": "Table 2",
            "x": 22,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "B1",
                "x": 24,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "B2",
                "x": 32,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          }
        ]
      }
    ]
  },
  {
    "name": "Étage",
    "sort_order": 1,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": [
      {
        "name": "Salle du haut",
        "color": 0,
        "bookable_as_whole": true,
        "price_cents": 0,
        "x": 0,
        "y": 0,
        "w": 40,
        "h": 24,
        "desks": [
          {
            "name": "Table 3",
            "x": 2,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "C1",
                "x": 4,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "C2",
                "x": 12,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          },
          {
            "name": "Table 4",
            "x": 22,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "D1",
                "x": 24,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "D2",
                "x": 32,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          }
        ]
      }
    ]
  }
]$tpl$::jsonb
)
on conflict (key) where owner_workspace_id is null do update
  set name = excluded.name,
      description = excluded.description,
      sort_order = excluded.sort_order,
      schema_version = excluded.schema_version,
      template_version = public.workspace_templates.template_version + 1,
      tags = excluded.tags,
      entities = excluded.entities,
      configuration = excluded.configuration,
      floor_plan = excluded.floor_plan;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(951);
