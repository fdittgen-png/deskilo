-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (a new table filled by the one stock path; stock_pieces_apply becomes a wrapper of stock_pieces_move; one
--  function patched at an asserted anchor, the export restated)
--
-- #4432 (G18, first of three files) -- a movement records the pieces it carried. Until now a piece kept only its
-- current place and state (0886), so where it had been, and by which movements, was lost. The one stock path
-- (`stock_apply_lines`) now writes, in the same transaction as the movement, one row per piece the movement moved:
-- `stock_movement_units` (movement, piece). A piece's history is the list of its rows, in movement order; the
-- trace of G18 and the as-of-date location of G19 read it.
--
--   * `stock_pieces_move` is the body of `stock_pieces_apply` (0887, with the DKG26 detail of 0917), unchanged,
--     returning the pieces it moved or made. `stock_pieces_apply` stays, as a wrapper, for its existing callers.
--   * Each piece is linked to the movement of its own line whose lot is the piece's lot (the part the stock path
--     took), or to the line's first movement.
--   * The table is read like the pieces (viewStock or manageStock, the stockTags feature) and written by the stock
--     path only. It is exported with the business's records.
--   * History starts with this migration: a piece made before it has no rows for its earlier movements.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0922: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- ── the link ─────────────────────────────────────────────────────────────
create table public.stock_movement_units (
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  movement_id uuid not null,
  unit_id uuid not null,
  primary key (movement_id, unit_id),
  foreign key (workspace_id, unit_id) references public.stock_tagged_units (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('stock_movement_units');
create index stock_movement_units_unit on public.stock_movement_units (workspace_id, unit_id);

alter table public.stock_movement_units enable row level security;
revoke all on public.stock_movement_units from public, anon, authenticated;
grant select on public.stock_movement_units to authenticated;
create policy stock_movement_units_select on public.stock_movement_units for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockTags'));
create policy mcp_delegated_deny on public.stock_movement_units as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the pieces a movement moves, returned ────────────────────────────────
-- restates 0887 (stock_pieces_apply, as patched by 0917) under a new name, returning the pieces
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_pieces_apply(uuid, uuid, uuid, uuid, jsonb, uuid, uuid, text, numeric)'::regprocedure);
  v_next text := v_def;
begin
  v_next := pg_temp.anchor_once(v_next, 'FUNCTION public.stock_pieces_apply(', 'FUNCTION public.stock_pieces_move(', 'the name');
  v_next := pg_temp.anchor_once(v_next, E' RETURNS void\n', E' RETURNS uuid[]\n', 'the result type');
  -- an item not tracked piece by piece moves no piece
  v_next := replace(v_next, E'    end if;\n    return;\n  end if;', E'    end if;\n    return array[]::uuid[];\n  end if;');
  v_next := pg_temp.anchor_once(v_next, E'  end loop;\nend;\n', E'  end loop;\n  return v_ids;\nend;\n', 'the end of the loop');
  if (length(v_next) - length(replace(v_next, 'return array[]::uuid[];', ''))) / length('return array[]::uuid[];') <> 2 then
    raise exception '0922: the two early returns of stock_pieces_apply are not found' using errcode = 'P0001';
  end if;
  execute v_next;
end
$patch$;
revoke execute on function public.stock_pieces_move(uuid, uuid, uuid, uuid, jsonb, uuid, uuid, text, numeric) from public, anon, authenticated;

-- restates 0887: the old name, kept for its callers
create or replace function public.stock_pieces_apply(
  p_workspace_id uuid, p_item_id uuid, p_variant uuid, p_lot uuid, p_line jsonb, p_from uuid, p_to uuid,
  p_reason text, p_qty numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.stock_pieces_move(p_workspace_id, p_item_id, p_variant, p_lot, p_line, p_from, p_to, p_reason, p_qty);
end;
$$;
revoke execute on function public.stock_pieces_apply(uuid, uuid, uuid, uuid, jsonb, uuid, uuid, text, numeric) from public, anon, authenticated;

-- ── the one stock path links each piece to its movement ──────────────────
-- restates 0887 (the pieces call of stock_apply_lines, as patched by 0889)
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure);
begin
  execute pg_temp.anchor_once(v_def,
    E'      perform public.stock_pieces_apply(p_workspace_id, v_item.id, v_var, v_lot, e, v_from.id, v_to.id, p_reason, v_qty);\n',
    E'      -- #4432: the pieces moved, then (a second statement, which sees the pieces made) each linked to the\n' ||
    E'      -- movement of its line that carries its lot, else the first\n' ||
    E'      declare\n' ||
    E'        v_moved uuid[];\n' ||
    E'      begin\n' ||
    E'        v_moved := public.stock_pieces_move(p_workspace_id, v_item.id, v_var, v_lot, e, v_from.id, v_to.id, p_reason, v_qty);\n' ||
    E'        insert into public.stock_movement_units (workspace_id, movement_id, unit_id)\n' ||
    E'        select p_workspace_id, m.id, u.id\n' ||
    E'          from unnest(v_moved) x (unit_id)\n' ||
    E'          join public.stock_tagged_units u on u.id = x.unit_id\n' ||
    E'          cross join lateral (\n' ||
    E'            select (o ->> ''id'')::uuid id from jsonb_array_elements(v_out) o\n' ||
    E'             where (o ->> ''line_no'')::int = v_no\n' ||
    E'             order by ((o ->> ''lot_id'') is not distinct from u.lot_id::text) desc, (o ->> ''part'')::int\n' ||
    E'             limit 1) m;\n' ||
    E'      end;\n',
    'the pieces call of stock_apply_lines');
end
$patch$;

-- ── exported with the business's records ─────────────────────────────────
-- restates 0907
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
    -- #4184 the counter's receipts, their lines and their tenders
    'counter_receipts', 'counter_receipt_lines', 'counter_tenders', 'counter_refunds',
    -- #4367 the tills, their sessions, the cash entries and the day closes
    'counter_tills', 'counter_till_sessions', 'counter_cash_entries', 'counter_day_closes',
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
    if v_table in ('counter_till_sessions', 'counter_cash_entries', 'counter_day_closes') and not public.has_permission(p_workspace_id, 'viewFinances') then
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
select public.set_deskilo_schema_version(922);
