-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one table, functions; the export function is restated whole)
--
-- #4185 (S3) -- a card tender is a durable state machine, and a refund is its own authorized act.
--
--   * `counter_tender_request_v1` records that an authorization was ASKED of the terminal or the provider, on an open
--     draft, under a request id, with a provider key that is the request id (so a recovery lookup names the same
--     request): state `requested`. `counter_tender_resolve_v1` records the answer: accepted, refused, or unknown (a
--     timeout, a lost answer). From `unknown` only the provider's own answer moves the tender, and no new request is
--     made for the sale while one is unknown (DKL11): the same-request recovery is the only way on. A declined or
--     unknown tender is never "paid".
--   * An authorization accepted after the offer moved (the draft was replaced since it was asked, or the receipt is no
--     longer an open draft) is money taken for another offer: it is recorded `accepted` with reconciliation `needed`,
--     and the sale cannot be finalized until a person with the right reconciles it explicitly
--     (`counter_tender_reconcile_v1`).
--   * `counter_refunds`: money given back is recorded against a CORRECTION receipt, by someone who may record outgoing
--     payments, and never beyond what the correction credits. A correction (0894) is the credit document; a refund
--     is not made by it, and a physical return of goods is not a refund either.

create or replace function public.counter_tender_request_v1(
  p_workspace_id uuid, p_request_id uuid, p_receipt_id uuid, p_kind text, p_amount_minor bigint)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_rec public.counter_receipts;
  v_part int;
  v_tender public.counter_tenders;
  v_held bigint;
  v_result jsonb;
begin
  v_me := public.counter_actor(p_workspace_id);
  if p_request_id is null or p_receipt_id is null or p_kind is distinct from 'card' or p_amount_minor is null or p_amount_minor <= 0 then
    raise exception 'an authorization is asked with a request id, a card and an amount' using errcode = '22023';
  end if;
  v_digest := md5(p_receipt_id::text || '|' || p_kind || '|' || p_amount_minor::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_tender_request', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_rec from public.counter_receipts x where x.id = p_receipt_id and x.workspace_id = p_workspace_id for update;
  if v_rec.id is null or v_rec.state <> 'draft' or v_rec.kind <> 'sale' then
    raise exception 'this receipt is not an open draft' using errcode = 'DKL04';
  end if;
  perform public.counter_require_operation(p_workspace_id, 'reconcile_tender');
  if exists (select 1 from public.counter_tenders t where t.receipt_id = v_rec.id and t.state = 'unknown') then
    raise exception 'an authorization of this sale is unknown: ask the provider about it, do not ask again' using errcode = 'DKL11';
  end if;
  select coalesce(sum(t.amount_minor), 0) into v_held from public.counter_tenders t where t.receipt_id = v_rec.id and t.state in ('requested', 'accepted');
  if v_held + p_amount_minor > coalesce(v_rec.total_minor, 0) then
    raise exception 'the tenders would exceed the total' using errcode = 'DKL06', detail = 'tender_sum';
  end if;
  select coalesce(max(t.part), 0) + 1 into v_part from public.counter_tenders t where t.receipt_id = v_rec.id;
  insert into public.counter_tenders (workspace_id, receipt_id, part, kind, amount_minor, state, provider_key, request_id, offered_revision, recorded_by_member_id)
  values (p_workspace_id, v_rec.id, v_part, 'card', p_amount_minor, 'requested', 'dk-' || p_request_id::text, p_request_id, v_rec.revision, v_me)
  returning * into v_tender;
  v_result := jsonb_build_object('tender_id', v_tender.id, 'part', v_part, 'state', 'requested', 'provider_key', v_tender.provider_key,
                                 'amount_minor', p_amount_minor, 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_tender_request', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_tender_request_v1(uuid, uuid, uuid, text, bigint) from public, anon;
grant execute on function public.counter_tender_request_v1(uuid, uuid, uuid, text, bigint) to authenticated;

create or replace function public.counter_tender_resolve_v1(
  p_workspace_id uuid, p_request_id uuid, p_tender_id uuid, p_outcome text, p_provider_ref text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_tender public.counter_tenders;
  v_rec public.counter_receipts;
  v_recon text;
  v_result jsonb;
begin
  v_me := public.counter_actor(p_workspace_id);
  if p_request_id is null or p_tender_id is null or p_outcome not in ('accepted', 'refused', 'unknown') or char_length(coalesce(p_provider_ref, '')) > 200 then
    raise exception 'an answer is recorded with a request id, a tender and its outcome' using errcode = '22023';
  end if;
  v_digest := md5(p_tender_id::text || '|' || p_outcome || '|' || coalesce(p_provider_ref, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_tender_resolve', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_tender from public.counter_tenders t where t.id = p_tender_id and t.workspace_id = p_workspace_id and t.kind = 'card' for update;
  if v_tender.id is null then
    raise exception 'not a card tender of this business' using errcode = 'DKL04';
  end if;
  perform public.counter_require_operation(p_workspace_id, 'reconcile_tender');
  -- from `unknown` only a person who may see the finances settles it: the cashier's own word is not the way out of a
  -- timeout (the provider's answer is read and entered by a supervisor, or arrives through a verified channel later)
  if v_tender.state = 'unknown' and not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'an unknown authorization is settled by someone who may see the finances' using errcode = 'DKN01';
  end if;
  if v_tender.state not in ('requested', 'unknown') then
    raise exception 'this authorization is already settled' using errcode = 'DKL11';
  end if;
  if v_tender.state = 'unknown' and p_outcome = 'unknown' then
    raise exception 'this authorization is already unknown' using errcode = 'DKL11';
  end if;
  select * into v_rec from public.counter_receipts x where x.id = v_tender.receipt_id for update;
  v_recon := null;
  if p_outcome = 'accepted' and (v_rec.state <> 'draft' or v_rec.revision <> v_tender.offered_revision) then
    v_recon := 'needed';
  end if;
  -- the provider key is the request's own and is never overwritten: the provider's reference is kept beside it
  update public.counter_tenders set state = p_outcome, provider_ref = nullif(p_provider_ref, ''), resolved_by_member_id = v_me,
         reconciliation = v_recon, resolved_at = case when p_outcome = 'unknown' then null else now() end
   where id = v_tender.id;
  v_result := jsonb_build_object('tender_id', v_tender.id, 'state', p_outcome, 'reconciliation', v_recon, 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_tender_resolve', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_tender_resolve_v1(uuid, uuid, uuid, text, text) from public, anon;
grant execute on function public.counter_tender_resolve_v1(uuid, uuid, uuid, text, text) to authenticated;

-- money taken for an offer that moved is reconciled explicitly, by someone who may see the finances
create or replace function public.counter_tender_reconcile_v1(p_workspace_id uuid, p_request_id uuid, p_tender_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_tender public.counter_tenders;
  v_result jsonb;
begin
  v_me := public.counter_actor(p_workspace_id);
  if not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'not allowed to reconcile a tender' using errcode = 'DKN01';
  end if;
  if p_request_id is null or p_tender_id is null then
    raise exception 'a tender is reconciled with a request id' using errcode = '22023';
  end if;
  v_digest := md5(p_tender_id::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_tender_reconcile', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_tender from public.counter_tenders t where t.id = p_tender_id and t.workspace_id = p_workspace_id for update;
  if v_tender.id is null or v_tender.state <> 'accepted' or v_tender.reconciliation is distinct from 'needed' then
    raise exception 'this tender does not wait for a reconciliation' using errcode = 'DKL11';
  end if;
  update public.counter_tenders set reconciliation = 'done' where id = v_tender.id;
  v_result := jsonb_build_object('tender_id', v_tender.id, 'reconciliation', 'done', 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_tender_reconcile', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_tender_reconcile_v1(uuid, uuid, uuid) from public, anon;
grant execute on function public.counter_tender_reconcile_v1(uuid, uuid, uuid) to authenticated;

-- ── refunds ────────────────────────────────────────────────────────────
create table public.counter_refunds (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  receipt_id uuid not null,
  part int not null default 1 check (part >= 1),
  kind text not null check (kind in ('cash', 'other')),
  amount_minor bigint not null check (amount_minor > 0),
  request_id uuid not null,
  refunded_by_member_id uuid,
  unique (receipt_id, part),
  unique (workspace_id, id),
  foreign key (workspace_id, receipt_id) references public.counter_receipts (workspace_id, id),
  foreign key (workspace_id, refunded_by_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('counter_refunds');
alter table public.counter_refunds enable row level security;
revoke all on public.counter_refunds from public, anon, authenticated;
grant select on public.counter_refunds to authenticated;
create policy counter_refunds_select on public.counter_refunds for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['issueInvoices', 'viewFinances']))
         and public.feature_effective(workspace_id, 'counterReceipts'));
create policy mcp_delegated_deny on public.counter_refunds as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create or replace function public.counter_refunds_frozen()
returns trigger language plpgsql set search_path = public as $fn$
begin
  raise exception 'a refund is never edited or deleted' using errcode = 'DKL03';
end;
$fn$;
revoke execute on function public.counter_refunds_frozen() from public, anon, authenticated;
create trigger counter_refunds_frozen before update or delete on public.counter_refunds
  for each row execute function public.counter_refunds_frozen();

create or replace function public.counter_refund_v1(p_workspace_id uuid, p_request_id uuid, p_correction_id uuid, p_refunds jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_rec public.counter_receipts;
  v_t jsonb;
  v_sum bigint := 0;
  v_given bigint;
  v_part int;
  v_result jsonb;
begin
  v_me := public.counter_actor(p_workspace_id);
  if not public.has_permission(p_workspace_id, 'recordOutgoingPayments') then
    raise exception 'not allowed to give money back' using errcode = 'DKN01';
  end if;
  if p_request_id is null or p_correction_id is null or coalesce(jsonb_typeof(p_refunds), '') <> 'array' or jsonb_array_length(p_refunds) = 0 then
    raise exception 'a refund is recorded with a request id, the correction and its parts' using errcode = '22023';
  end if;
  v_digest := md5(p_correction_id::text || '|' || p_refunds::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_refund', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_rec from public.counter_receipts x where x.id = p_correction_id and x.workspace_id = p_workspace_id for update;
  if v_rec.id is null or v_rec.kind <> 'correction' or v_rec.state <> 'finalized' then
    raise exception 'a refund follows a finalized correction' using errcode = 'DKL04';
  end if;
  perform public.counter_require_operation(p_workspace_id, 'reconcile_tender');
  for v_t in select value from jsonb_array_elements(p_refunds) loop
    if coalesce(v_t ->> 'kind', '') not in ('cash', 'other') or coalesce(v_t ->> 'amount_minor', '') !~ '^[0-9]{1,12}$' or (v_t ->> 'amount_minor')::bigint <= 0 then
      raise exception 'this refund is not taken here' using errcode = 'DKL06', detail = 'refund_part';
    end if;
    v_sum := v_sum + (v_t ->> 'amount_minor')::bigint;
  end loop;
  select coalesce(sum(r.amount_minor), 0), coalesce(max(r.part), 0) into v_given, v_part from public.counter_refunds r where r.receipt_id = v_rec.id;
  if v_given + v_sum > v_rec.total_minor then
    raise exception 'more is refunded than the correction credits' using errcode = 'DKL08',
      detail = jsonb_build_object('reason', 'refund_beyond', 'left', (v_rec.total_minor - v_given)::text)::text;
  end if;
  for v_t in select value from jsonb_array_elements(p_refunds) loop
    v_part := v_part + 1;
    insert into public.counter_refunds (workspace_id, receipt_id, part, kind, amount_minor, request_id, refunded_by_member_id)
    values (p_workspace_id, v_rec.id, v_part, v_t ->> 'kind', (v_t ->> 'amount_minor')::bigint, p_request_id, v_me);
  end loop;
  v_result := jsonb_build_object('correction_id', v_rec.id, 'refunded_minor', (v_given + v_sum)::text, 'left_minor', (v_rec.total_minor - v_given - v_sum)::text, 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_refund', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_refund_v1(uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.counter_refund_v1(uuid, uuid, uuid, jsonb) to authenticated;

-- the workspace export carries the receipts, their lines, their tenders and their refunds (#2860)
-- restates 0893
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
    'stock_tags', 'stock_tagged_units',
    -- #4184 the counter's receipts, their lines and their tenders
    'counter_receipts', 'counter_receipt_lines', 'counter_tenders', 'counter_refunds',
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
select public.set_deskilo_schema_version(895);
