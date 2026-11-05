-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0684 (#3307, PR C) -- what arrived of a purchase order, and the bill that
-- charges it.
--
--   * `purchase_order_receipts`: one delivery of an order, on the day it
--     arrived, with a note; `purchase_order_receipt_lines`: how much of each
--     order line it brought (above zero). History: never edited.
--   * `record_purchase_order_receipt_v1` (managePurchases while `purchases`
--     and `purchaseOrders` are on): records a delivery of a sent or partly
--     received order at its revision. A line never receives more than was
--     ordered of it; the order's lines carry what has arrived so far; the
--     order is then partly received, or received when every line is
--     complete. A request id replays its answer.
--   * `purchase_documents.purchase_order_id`: the order a supplier bill
--     charges. `link_purchase_to_order_v1` (managePurchases) links a draft
--     bill of the space to an order of the space that is no longer a draft
--     and not cancelled, of the bill's supplier when the bill names one; a
--     null order unlinks it. The bill's own lines stay what the supplier
--     wrote.
--   * the data export carries the receipts and the order sendings (0683).

create table public.purchase_order_receipts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  order_id uuid not null references public.purchase_orders(id) on delete cascade,
  received_on date not null,
  note text not null default '' check (char_length(note) <= 500),
  actor_member_id uuid not null,
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('purchase_order_receipts');
create index purchase_order_receipts_order on public.purchase_order_receipts (order_id);

create table public.purchase_order_receipt_lines (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  receipt_id uuid not null references public.purchase_order_receipts(id) on delete cascade,
  order_line_id uuid not null references public.purchase_order_lines(id) on delete cascade,
  quantity numeric not null check (quantity > 0),
  unique (receipt_id, order_line_id)
);
select public.ensure_system_columns('purchase_order_receipt_lines');
create index purchase_order_receipt_lines_receipt on public.purchase_order_receipt_lines (receipt_id);

alter table public.purchase_order_receipts enable row level security;
alter table public.purchase_order_receipt_lines enable row level security;
revoke all on public.purchase_order_receipts, public.purchase_order_receipt_lines
  from public, anon, authenticated;
grant select on public.purchase_order_receipts, public.purchase_order_receipt_lines to authenticated;
create policy purchase_order_receipts_select on public.purchase_order_receipts for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['managePurchases', 'viewFinances'])));
create policy purchase_order_receipt_lines_select on public.purchase_order_receipt_lines for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['managePurchases', 'viewFinances'])));
create policy mcp_delegated_deny on public.purchase_order_receipts as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.purchase_order_receipt_lines as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.purchase_documents
  add column if not exists purchase_order_id uuid references public.purchase_orders(id) on delete set null;
create index if not exists purchase_documents_order on public.purchase_documents (purchase_order_id)
  where purchase_order_id is not null;

create or replace function public.record_purchase_order_receipt_v1(
  p_workspace_id uuid, p_order_id uuid, p_revision int, p_received_on date,
  p_lines jsonb, p_note text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_order public.purchase_orders;
  v_receipt uuid;
  e jsonb;
  v_line public.purchase_order_lines;
  v_qty numeric;
  v_complete boolean;
begin
  v_me := public.purchase_order_actor(p_workspace_id);
  if p_request_id is null or p_received_on is null then
    raise exception 'a delivery has its day and a request id' using errcode = '22023';
  end if;
  if coalesce(jsonb_typeof(p_lines), '') <> 'array' or jsonb_array_length(p_lines) not between 1 and 200 then
    raise exception 'a delivery brings at least one line' using errcode = '22023';
  end if;
  v_digest := md5(p_order_id::text || coalesce(p_revision, 0)::text || p_received_on::text
                  || p_lines::text || coalesce(p_note, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'order_receipt', v_digest);
  if v_done is not null then return v_done; end if;
  select * into v_order from public.purchase_orders
   where id = p_order_id and workspace_id = p_workspace_id for update;
  if v_order.id is null then raise exception 'unknown purchase order' using errcode = '22023'; end if;
  if v_order.state not in ('sent', 'partly_received') then
    raise exception 'only a sent order receives its goods' using errcode = '22023';
  end if;
  if v_order.revision <> coalesce(p_revision, -1) then
    raise exception 'stale revision' using errcode = '40001';
  end if;
  if p_received_on > (now() at time zone coalesce(
       (select nullif(w.timezone, '') from public.workspaces w where w.id = p_workspace_id), 'UTC'))::date then
    raise exception 'a delivery is not dated in the future' using errcode = '22023';
  end if;
  insert into public.purchase_order_receipts (workspace_id, order_id, received_on, note, actor_member_id)
  values (p_workspace_id, v_order.id, p_received_on, left(btrim(coalesce(p_note, '')), 500), v_me)
  returning id into v_receipt;
  for e in select value from jsonb_array_elements(p_lines) loop
    select * into v_line from public.purchase_order_lines
     where order_id = v_order.id and line_no = (e ->> 'line_no')::int for update;
    if v_line.id is null then raise exception 'unknown order line' using errcode = '22023'; end if;
    v_qty := nullif(e ->> 'quantity', '')::numeric;
    if v_qty is null or v_qty <= 0 then
      raise exception 'a line is received in a quantity above zero' using errcode = '22023';
    end if;
    if v_line.received_quantity + v_qty > v_line.quantity then
      raise exception 'line % would receive more than was ordered', v_line.line_no using errcode = '22023';
    end if;
    insert into public.purchase_order_receipt_lines (workspace_id, receipt_id, order_line_id, quantity)
    values (p_workspace_id, v_receipt, v_line.id, v_qty);
    update public.purchase_order_lines set received_quantity = received_quantity + v_qty
     where id = v_line.id;
  end loop;
  select bool_and(l.received_quantity >= l.quantity) into v_complete
    from public.purchase_order_lines l where l.order_id = v_order.id;
  update public.purchase_orders
     set state = case when v_complete then 'received' else 'partly_received' end,
         revision = revision + 1
   where id = v_order.id;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'order_receipt', v_digest,
    public.purchase_order_json(v_order.id) || jsonb_build_object('receipt_id', v_receipt));
end;
$fn$;
revoke execute on function public.record_purchase_order_receipt_v1(uuid, uuid, int, date, jsonb, text, uuid) from public, anon;
grant execute on function public.record_purchase_order_receipt_v1(uuid, uuid, int, date, jsonb, text, uuid) to authenticated;

create or replace function public.link_purchase_to_order_v1(
  p_workspace_id uuid, p_purchase_id uuid, p_order_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_doc public.purchase_documents;
  v_order public.purchase_orders;
begin
  perform public.purchase_order_actor(p_workspace_id);
  select * into v_doc from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id for update;
  if v_doc.id is null then raise exception 'unknown purchase' using errcode = '22023'; end if;
  if v_doc.kind <> 'bill' or v_doc.state <> 'draft' then
    raise exception 'only a draft supplier bill names its order' using errcode = '22023';
  end if;
  if p_order_id is not null then
    select * into v_order from public.purchase_orders
     where id = p_order_id and workspace_id = p_workspace_id;
    if v_order.id is null then raise exception 'unknown purchase order' using errcode = '22023'; end if;
    if v_order.state in ('draft', 'cancelled') then
      raise exception 'a bill charges an order that was sent' using errcode = '22023';
    end if;
    if v_doc.supplier_id is not null and v_doc.supplier_id <> v_order.supplier_id then
      raise exception 'the order is to another supplier' using errcode = '22023';
    end if;
  end if;
  update public.purchase_documents set purchase_order_id = p_order_id where id = v_doc.id;
  return jsonb_build_object('purchase_id', v_doc.id, 'purchase_order_id', p_order_id);
end;
$fn$;
revoke execute on function public.link_purchase_to_order_v1(uuid, uuid, uuid) from public, anon;
grant execute on function public.link_purchase_to_order_v1(uuid, uuid, uuid) to authenticated;

-- The workspace data export carries the deliveries and the sending attempts
-- of the orders (restated whole from 0682 with the three tables added; the
-- order mail settings are configuration, their key stays in the secret
-- store).
create or replace function public.export_workspace_records(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tables text[] := array[
    -- configuration, readable (the XML stays the re-importable copy)
    'sites', 'plans', 'fee_bands', 'packages', 'credit_products', 'vat_rates',
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
    'purchase_order_receipts', 'purchase_order_receipt_lines'];
  v_left_out text[] := public.system_column_names() || array['workspace_id', 'source_xml'];
  v_table text;
  v_columns text[];
  v_rows jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'only someone who may export this workspace''s data reads its records';
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

select public.set_deskilo_schema_version(684);
