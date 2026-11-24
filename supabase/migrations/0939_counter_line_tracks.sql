-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one new table filled by two triggers on the stock ledger; the export restated with it)
--
-- #4436 (G21) -- a sale of a traced good names the track ID it was received with.
--   * `counter_line_tracks`: for each goods line of a counter receipt, the lot codes (as received) and the piece codes
--     the one stock path took, with their quantities. The codes are COPIED when the stock moves, so a later edit of a
--     lot or a retag of a piece never alters an issued receipt; the rows are never edited.
--   * Filled by triggers, not by the finalize: a movement that names a counter line and a lot writes the lot row
--     (the lot the stock path chose when the seller named none, one row per lot when a line took from two lots);
--     a piece bound to such a movement writes the piece row. Replays write nothing twice (the movement is written once).
--   * Read like the receipt lines (issueInvoices or viewFinances, with counterReceipts on); exported with the records.

create table public.counter_line_tracks (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  receipt_id uuid not null,
  line_id uuid not null,
  movement_id uuid not null,
  track_kind text not null check (track_kind in ('lot', 'piece')),
  lot_id uuid,
  unit_id uuid,
  -- the code as it was when the goods left: the supplier lot (or the lot's label) or the piece's tag
  track_code text not null check (char_length(track_code) between 1 and 128),
  quantity numeric(18, 6) not null check (quantity > 0),
  unique (workspace_id, id),
  unique nulls not distinct (movement_id, track_kind, lot_id, unit_id),
  check ((track_kind = 'lot') = (unit_id is null)),
  foreign key (workspace_id, receipt_id) references public.counter_receipts (workspace_id, id) on delete cascade,
  foreign key (workspace_id, line_id) references public.counter_receipt_lines (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('counter_line_tracks');
create index counter_line_tracks_line on public.counter_line_tracks (workspace_id, line_id);
create index counter_line_tracks_code on public.counter_line_tracks (workspace_id, track_code);

create or replace function public.counter_line_tracks_frozen()
returns trigger language plpgsql set search_path = public as $fn$
begin
  raise exception 'the track IDs of a receipt line are never edited' using errcode = 'DKL03';
end;
$fn$;
revoke execute on function public.counter_line_tracks_frozen() from public, anon, authenticated;
create trigger counter_line_tracks_frozen before update on public.counter_line_tracks
  for each row execute function public.counter_line_tracks_frozen();

-- a lot leaving for a counter line: its code as received, or its label when it has no supplier code
create or replace function public.counter_line_tracks_from_movement()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_code text;
begin
  if new.counter_line_id is null or new.lot_id is null then
    return new;
  end if;
  select coalesce(nullif(l.lot_code, ''), l.label_code) into v_code
    from public.stock_lots l where l.workspace_id = new.workspace_id and l.id = new.lot_id;
  if v_code is null then
    return new;
  end if;
  insert into public.counter_line_tracks (workspace_id, receipt_id, line_id, movement_id, track_kind, lot_id, track_code, quantity)
  values (new.workspace_id, new.counter_receipt_id, new.counter_line_id, new.id, 'lot', new.lot_id, v_code, new.quantity)
  on conflict do nothing;
  return new;
end;
$fn$;
revoke execute on function public.counter_line_tracks_from_movement() from public, anon, authenticated;
create trigger counter_line_tracks_from_movement after insert on public.stock_movements
  for each row execute function public.counter_line_tracks_from_movement();

-- a piece bound to a movement of a counter line: the code of its active piece tag (its id when it has none)
create or replace function public.counter_line_tracks_from_piece()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_receipt uuid;
  v_line uuid;
  v_code text;
begin
  select m.counter_receipt_id, m.counter_line_id into v_receipt, v_line
    from public.stock_movements m where m.id = new.movement_id;
  if v_line is null then
    return new;
  end if;
  select coalesce(
           (select t.code from public.stock_tags t
             where t.workspace_id = new.workspace_id and t.piece_id = new.unit_id and t.state = 'active'
             order by t.created_datetime limit 1),
           new.unit_id::text)
    into v_code;
  insert into public.counter_line_tracks (workspace_id, receipt_id, line_id, movement_id, track_kind, unit_id, track_code, quantity)
  values (new.workspace_id, v_receipt, v_line, new.movement_id, 'piece', new.unit_id, v_code, 1)
  on conflict do nothing;
  return new;
end;
$fn$;
revoke execute on function public.counter_line_tracks_from_piece() from public, anon, authenticated;
create trigger counter_line_tracks_from_piece after insert on public.stock_movement_units
  for each row execute function public.counter_line_tracks_from_piece();

-- rights: read like the receipt lines; no direct write
alter table public.counter_line_tracks enable row level security;
revoke all on public.counter_line_tracks from public, anon, authenticated;
grant select on public.counter_line_tracks to authenticated;
create policy counter_line_tracks_select on public.counter_line_tracks for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['issueInvoices', 'viewFinances']))
         and public.feature_effective(workspace_id, 'counterReceipts'));
create policy mcp_delegated_deny on public.counter_line_tracks as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the sale names its line ──────────────────────────────────────────────
-- restates 0894 (as patched by 0908): the goods movement of a sale names the receipt line it leaves for (0897 does it for
-- a return); without it the triggers above could not tell which line took the lot or the piece
do $patch$
declare
  v_def text := pg_get_functiondef('public.counter_receipt_finalize_v1(uuid, uuid, uuid, integer, jsonb)'::regprocedure);
  v_next text := v_def;
  v_olds text[] := array[
    E'  v_goods := \'[]\'::jsonb;\n  for r in select value from jsonb_array_elements(v_calc -> \'lines\') loop\n    if r #>> \'{line,supply}\' = \'goods\' then',
    E'\'lot_id\', nullif(r #>> \'{input,lot_id}\', \'\'))));'];
  v_news text[] := array[
    E'  v_goods := \'[]\'::jsonb;\n  v_no := 0;\n  for r in select value from jsonb_array_elements(v_calc -> \'lines\') loop\n    v_no := v_no + 1;\n    if r #>> \'{line,supply}\' = \'goods\' then',
    E'\'lot_id\', nullif(r #>> \'{input,lot_id}\', \'\'),\n        \'counter_line_id\', (select cl.id from public.counter_receipt_lines cl where cl.receipt_id = v_rec.id and cl.line_no = v_no))));'];
  k int;
begin
  for k in 1 .. array_length(v_olds, 1) loop
    if (length(v_def) - length(replace(v_def, v_olds[k], ''))) / length(v_olds[k]) <> 1 then
      raise exception '0939: anchor % not found exactly once in counter_receipt_finalize_v1', k using errcode = 'P0001';
    end if;
    v_next := replace(v_next, v_olds[k], v_news[k]);
  end loop;
  execute v_next;
end
$patch$;

-- ── exported with the business's records ─────────────────────────────────
-- restates 0937
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
    -- #4436 the track IDs each counter line took, frozen with the receipt
    'counter_line_tracks',
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
    'service_fulfilments', 'service_fulfilment_transitions', 'service_fulfilment_invoice_links'];
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
    if v_table in ('counter_till_sessions', 'counter_cash_entries', 'counter_day_closes', 'counter_offline_sales') and not public.has_permission(p_workspace_id, 'viewFinances') then
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

select public.set_deskilo_schema_version(939);
