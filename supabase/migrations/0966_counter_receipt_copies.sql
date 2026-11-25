-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4476 -- a copy of a counter receipt: printed again, marked as a copy and counted, never numbered again.
--
--   counter_receipt_copies       one row per copy of a finalized receipt: its number among the copies (1, 2, ...), who
--                                printed it and under which request. Never edited or deleted. Who printed it is a member
--                                reference: an erasure leaves the member row (exited, its personal data cleared), so the
--                                count of copies stays and the reference no longer names anyone.
--   counter_receipt_copy_v1      who works the counter (issueInvoices, where counter receipts are on) prints a copy of a
--                                finalized receipt of the business; anything else is refused (DKL04 {"reason": "receipt"});
--                                the same request answers the same copy again.

create table public.counter_receipt_copies (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  receipt_id uuid not null,
  copy_no int not null check (copy_no >= 1),
  actor_member_id uuid not null,
  request_id uuid not null,
  unique (workspace_id, id),
  unique (workspace_id, receipt_id, copy_no),
  unique (workspace_id, request_id),
  foreign key (workspace_id, receipt_id) references public.counter_receipts (workspace_id, id),
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('counter_receipt_copies');

create or replace function public.counter_receipt_copies_frozen() returns trigger
language plpgsql set search_path = public as $fn$
begin
  raise exception 'a copy of a receipt is never edited or deleted' using errcode = 'DKL03';
end;
$fn$;
revoke execute on function public.counter_receipt_copies_frozen() from public, anon, authenticated;
create trigger counter_receipt_copies_frozen before update or delete on public.counter_receipt_copies
  for each row execute function public.counter_receipt_copies_frozen();

alter table public.counter_receipt_copies enable row level security;
revoke all on public.counter_receipt_copies from public, anon, authenticated;
grant select on public.counter_receipt_copies to authenticated;
create policy counter_receipt_copies_select on public.counter_receipt_copies for select to authenticated
  using (public.feature_effective(workspace_id, 'counterReceipts')
         and workspace_id in (select public.workspaces_permitting(array['issueInvoices', 'viewFinances'])));
create policy mcp_delegated_deny on public.counter_receipt_copies as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

create or replace function public.counter_receipt_copy_v1(
  p_workspace_id uuid,
  p_request_id uuid,
  p_receipt_id uuid
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text := md5(coalesce(p_receipt_id::text, ''));
  v_done jsonb;
  v_no int;
begin
  v_me := public.command_actor(p_workspace_id, 'issueInvoices', 'counterReceipts', 'not allowed to work the counter',
    'counter receipts are off in this business', 'DKG01');
  if p_request_id is null then
    perform public.refuse('DKL02', '{"reason": "request"}'::jsonb, 'a copy is printed under a request id');
  end if;
  v_done := public.request_begin(p_workspace_id, p_request_id, 'counter_receipt_copy', v_digest);
  if v_done is not null then
    return v_done || '{"replayed": true}'::jsonb;
  end if;
  if not exists (select 1 from public.counter_receipts r
                  where r.id = p_receipt_id and r.workspace_id = p_workspace_id and r.state = 'finalized') then
    raise exception 'only a finalized receipt of this business has copies' using errcode = 'DKL04', detail = '{"reason": "receipt"}';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('counter_receipt_copy:' || p_receipt_id::text, 0));
  select coalesce(max(c.copy_no), 0) + 1 into v_no from public.counter_receipt_copies c
   where c.workspace_id = p_workspace_id and c.receipt_id = p_receipt_id;
  insert into public.counter_receipt_copies (workspace_id, receipt_id, copy_no, actor_member_id, request_id)
  values (p_workspace_id, p_receipt_id, v_no, v_me, p_request_id);
  return public.request_finish(p_workspace_id, p_request_id, 'counter_receipt_copy', v_digest,
    jsonb_build_object('receipt_id', p_receipt_id, 'copy_no', v_no)) || '{"replayed": false}'::jsonb;
end
$fn$;
revoke execute on function public.counter_receipt_copy_v1(uuid, uuid, uuid) from public, anon;
grant execute on function public.counter_receipt_copy_v1(uuid, uuid, uuid) to authenticated;

-- the copies go out with the business's records: export_workspace_records restated from 0951 (its live definition; nothing
-- patched it since) with 'counter_receipt_copies' added to its tables, nothing else changed
-- restates 0951
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
    'workspace_units',
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

select public.set_deskilo_schema_version(966);
