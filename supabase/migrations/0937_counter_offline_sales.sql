-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (one table, three functions; the drawer figure `counter_session_cash` is restated whole; nothing stored moves)
--
-- #4373 (CS11, second file) -- the server side of the offline cash sale (contract: docs/design/counter-receipt-contract.md section 7).
--
--   * `counter_offline_sales`: what the server received of the sales a till made offline, one row per device sequence number of a
--     till session: accepted (with its receipt) or refused (with its reason, listed for the owner). Never edited or deleted.
--   * `counter_offline_sync_v1(workspace, session, offline_since, sales)`: each sale runs, in its own sub-transaction, through the ordinary
--     draft (under the sale's request id) and finalize (under an id derived from it) commands with ONE cash tender of exactly its total; a refused sale does not stop the others. A sale is accepted only
--     for cash, in a session opened before the offline period and still open, within `counter.offline_max_minutes` of the start of the
--     offline period, within `counter.offline_max_sales` per session, at prices within `counter.offline_price_tolerance_percent` of the
--     items' current prices, for items still active. The same request id and content answers its first result; other content, or a
--     sequence number held by another request, is refused (DKL16). A sequence number missing between recorded ones is reported, never filled.
--     Two devices of one session sync one after the other (a lock on the session).
--   * `counter_offline_list_v1(workspace, session)`: the sales of a session as received, with the gaps; every receipt is listed as not
--     signed (the country's signing is decided elsewhere; nothing here claims compliance).
--   * `counter_session_cash` is restated whole: the cash of a REFUSED offline sale is in the drawer, so it is part of the expected cash and
--     is listed apart (`offline_refused_cash_minor`).
--   * `export_workspace_records` is restated whole: the table joins the business's export, the finances' to export.
--   Off (the feature `counterOfflineCash`): the sync and the list are refused (DKG01).

create table public.counter_offline_sales (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  till_session_id uuid not null,
  seq int not null check (seq >= 1),
  request_id uuid not null,
  digest text not null,
  occurred_at timestamptz not null,
  offline_since timestamptz not null,
  state text not null check (state in ('accepted', 'refused')),
  reason text check (reason is null or char_length(reason) <= 80),
  receipt_id uuid,
  number text,
  total_minor bigint check (total_minor is null or total_minor >= 0),
  cash_given_minor bigint not null check (cash_given_minor >= 0),
  change_minor bigint not null check (change_minor >= 0 and change_minor <= cash_given_minor),
  body jsonb not null,
  synced_by_member_id uuid,
  check ((state = 'accepted') = (receipt_id is not null and number is not null and total_minor is not null)),
  check ((state = 'refused') = (reason is not null)),
  unique (workspace_id, id),
  unique (workspace_id, till_session_id, seq),
  unique (workspace_id, request_id),
  foreign key (workspace_id, till_session_id) references public.counter_till_sessions (workspace_id, id),
  foreign key (workspace_id, receipt_id) references public.counter_receipts (workspace_id, id),
  foreign key (workspace_id, synced_by_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('counter_offline_sales');
create index counter_offline_sales_session on public.counter_offline_sales (till_session_id);

-- a received offline sale is never edited or deleted (the cascade of a business's own deletion passes)
create or replace function public.counter_offline_frozen_guard()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and pg_trigger_depth() > 1 and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  raise exception 'a received offline sale is never edited or deleted' using errcode = 'DKL03';
end;
$fn$;
revoke execute on function public.counter_offline_frozen_guard() from public, anon, authenticated;
create trigger counter_offline_sales_frozen before update or delete on public.counter_offline_sales
  for each row execute function public.counter_offline_frozen_guard();

alter table public.counter_offline_sales enable row level security;
revoke all on public.counter_offline_sales from public, anon, authenticated;
grant select on public.counter_offline_sales to authenticated;
create policy counter_offline_sales_select on public.counter_offline_sales for select to authenticated
  using (public.feature_effective(workspace_id, 'counterOfflineCash')
         and workspace_id in (select public.workspaces_permitting(array['viewFinances'])));
create policy mcp_delegated_deny on public.counter_offline_sales as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- the member who works the till with offline sales on
create or replace function public.counter_offline_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  v_me := public.counter_till_actor(p_workspace_id);
  if not public.feature_effective(p_workspace_id, 'counterOfflineCash') then
    raise exception 'selling offline is off in this business' using errcode = 'DKG01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.counter_offline_actor(uuid) from public, anon, authenticated;

-- the sequence numbers missing between the recorded ones of a session
create or replace function public.counter_offline_gaps(p_session_id uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select coalesce(jsonb_agg(g.n order by g.n), '[]'::jsonb)
    from generate_series(1, coalesce((select max(o.seq) from public.counter_offline_sales o where o.till_session_id = p_session_id), 0)) g(n)
   where not exists (select 1 from public.counter_offline_sales o where o.till_session_id = p_session_id and o.seq = g.n)
$fn$;
revoke execute on function public.counter_offline_gaps(uuid) from public, anon, authenticated;

-- restates 0907
create or replace function public.counter_session_cash(p_session_id uuid)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'float_minor', s.float_minor,
    'cash_sales_minor', coalesce((select sum(t.amount_minor) from public.counter_tenders t join public.counter_receipts r on r.id = t.receipt_id
                                   where r.till_session_id = s.id and r.state = 'finalized' and r.kind = 'sale' and t.kind = 'cash' and t.state = 'accepted'), 0),
    'cash_refunds_minor', coalesce((select sum(f.amount_minor) from public.counter_refunds f where f.till_session_id = s.id and f.kind = 'cash'), 0),
    'paid_in_minor', coalesce((select sum(e.amount_minor) from public.counter_cash_entries e where e.session_id = s.id and e.kind = 'paid_in'), 0),
    'paid_out_minor', coalesce((select sum(e.amount_minor) from public.counter_cash_entries e where e.session_id = s.id and e.kind = 'paid_out'), 0),
    'offline_refused_cash_minor', coalesce((select sum(o.cash_given_minor - o.change_minor) from public.counter_offline_sales o
                                              where o.till_session_id = s.id and o.state = 'refused'), 0),
    'unresolved_card_minor', coalesce((select sum(t.amount_minor) from public.counter_tenders t join public.counter_receipts r on r.id = t.receipt_id
                                        where r.till_session_id = s.id and t.kind = 'card' and t.state in ('requested', 'unknown')), 0))
         || jsonb_build_object('expected_minor',
              s.float_minor
              + coalesce((select sum(t.amount_minor) from public.counter_tenders t join public.counter_receipts r on r.id = t.receipt_id
                           where r.till_session_id = s.id and r.state = 'finalized' and r.kind = 'sale' and t.kind = 'cash' and t.state = 'accepted'), 0)
              - coalesce((select sum(f.amount_minor) from public.counter_refunds f where f.till_session_id = s.id and f.kind = 'cash'), 0)
              + coalesce((select sum(o.cash_given_minor - o.change_minor) from public.counter_offline_sales o
                           where o.till_session_id = s.id and o.state = 'refused'), 0)
              + coalesce((select sum(e.amount_minor) from public.counter_cash_entries e where e.session_id = s.id and e.kind = 'paid_in'), 0)
              - coalesce((select sum(e.amount_minor) from public.counter_cash_entries e where e.session_id = s.id and e.kind = 'paid_out'), 0))
    from public.counter_till_sessions s where s.id = p_session_id
$fn$;
revoke execute on function public.counter_session_cash(uuid) from public, anon, authenticated;

-- the sales of a till session made offline, as the server received them
create or replace function public.counter_offline_list_v1(p_workspace_id uuid, p_session_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_sess public.counter_till_sessions;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to read the offline sales' using errcode = 'DKN01';
  end if;
  select m.id into v_me from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null or not public.feature_effective(p_workspace_id, 'counterOfflineCash') then
    raise exception 'selling offline is off in this business' using errcode = 'DKG01';
  end if;
  select * into v_sess from public.counter_till_sessions s where s.id = p_session_id and s.workspace_id = p_workspace_id;
  if v_sess.id is null then
    raise exception 'not allowed to read the offline sales' using errcode = 'DKN01';
  end if;
  if not public.has_permission(p_workspace_id, 'viewFinances')
     and not (public.has_permission(p_workspace_id, 'issueInvoices') and v_sess.opened_by_member_id = v_me) then
    raise exception 'not allowed to read the offline sales' using errcode = 'DKN01';
  end if;
  return jsonb_build_object(
    'sales', coalesce((select jsonb_agg(jsonb_build_object('seq', o.seq, 'state', o.state, 'reason', o.reason, 'receipt_id', o.receipt_id,
                'number', o.number, 'total_minor', o.total_minor, 'cash_given_minor', o.cash_given_minor, 'change_minor', o.change_minor,
                'occurred_at', o.occurred_at, 'fiscal', 'not_signed') order by o.seq)
                from public.counter_offline_sales o where o.till_session_id = v_sess.id), '[]'::jsonb),
    'gaps', public.counter_offline_gaps(v_sess.id));
end;
$fn$;
revoke execute on function public.counter_offline_list_v1(uuid, uuid) from public, anon;
grant execute on function public.counter_offline_list_v1(uuid, uuid) to authenticated;

-- the sales a till made offline, sent in the order they were made
create or replace function public.counter_offline_sync_v1(p_workspace_id uuid, p_session_id uuid, p_offline_since timestamptz, p_sales jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_sess public.counter_till_sessions;
  v_max_minutes int;
  v_max_sales int;
  v_tolerance int;
  v_digits int;
  v_cur text;
  e jsonb;
  l jsonb;
  v_seq int;
  v_req uuid;
  v_at timestamptz;
  v_given bigint;
  v_change bigint;
  v_body jsonb;
  v_digest text;
  v_old public.counter_offline_sales;
  v_reason text;
  v_draft jsonb;
  v_final jsonb;
  v_total bigint;
  v_item public.services;
  v_price numeric;
  v_results jsonb := '[]'::jsonb;
  v_accepted int := 0;
  v_refused int := 0;
  v_row public.counter_offline_sales;
begin
  v_me := public.counter_offline_actor(p_workspace_id);
  if p_session_id is null or p_offline_since is null or coalesce(jsonb_typeof(p_sales), '') <> 'array'
     or jsonb_array_length(p_sales) not between 1 and 200 then
    perform public.refuse('DKL02', null, 'offline_sale');
  end if;
  -- two devices of one session sync one after the other; a close (for update) waits for this transaction
  perform pg_advisory_xact_lock(hashtextextended('counter_offline:' || p_session_id::text, 0));
  select * into v_sess from public.counter_till_sessions s where s.id = p_session_id and s.workspace_id = p_workspace_id for share;
  if v_sess.id is null then
    raise exception 'not allowed to send sales for this session' using errcode = 'DKN01';
  end if;
  v_max_minutes := coalesce((public.setting_value(p_workspace_id, 'counter.offline_max_minutes') #>> '{}')::int, 240);
  v_max_sales := coalesce((public.setting_value(p_workspace_id, 'counter.offline_max_sales') #>> '{}')::int, 200);
  v_tolerance := coalesce((public.setting_value(p_workspace_id, 'counter.offline_price_tolerance_percent') #>> '{}')::int, 0);
  select upper(w.currency_code) into v_cur from public.workspaces w where w.id = p_workspace_id;
  v_digits := public.currency_minor_digits(v_cur);
  for e in select value from jsonb_array_elements(p_sales) loop
    if jsonb_typeof(e) <> 'object' or coalesce(jsonb_typeof(e -> 'body'), '') <> 'object' then
      perform public.refuse('DKL02', null, 'offline_sale');
    end if;
    begin
      v_seq := (e ->> 'seq')::int;
      v_req := (e ->> 'request_id')::uuid;
      v_at := (e ->> 'occurred_at')::timestamptz;
      v_given := (e ->> 'cash_given_minor')::bigint;
      v_change := (e ->> 'change_minor')::bigint;
    exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow or numeric_value_out_of_range then
      perform public.refuse('DKL02', null, 'offline_sale');
    end;
    if v_seq is null or v_seq < 1 or v_req is null or v_at is null or v_given is null or v_given < 0 or v_change is null
       or v_change < 0 or v_change > v_given then
      perform public.refuse('DKL02', null, 'offline_sale');
    end if;
    v_body := e -> 'body';
    v_digest := md5(p_session_id::text || '|' || v_seq || '|' || v_req || '|' || v_at::text || '|' || v_given || '|' || v_change || '|' || v_body::text);
    -- a sale already received answers what it answered; other content under its request id, or its number under another request, is refused
    select * into v_old from public.counter_offline_sales o
     where o.workspace_id = p_workspace_id and (o.request_id = v_req or (o.till_session_id = p_session_id and o.seq = v_seq));
    if v_old.id is not null then
      if v_old.request_id <> v_req or v_old.digest <> v_digest or v_old.till_session_id <> p_session_id then
        raise exception 'this request id or sequence number already holds another sale' using errcode = 'DKL16',
          detail = jsonb_build_object('seq', v_seq)::text;
      end if;
      v_results := v_results || jsonb_build_array(jsonb_build_object('seq', v_old.seq, 'request_id', v_old.request_id, 'state', v_old.state,
        'receipt_id', v_old.receipt_id, 'number', v_old.number, 'reason', v_old.reason, 'replayed', true));
      continue;
    end if;
    v_reason := null;
    v_total := null;
    v_draft := null;
    if v_sess.state <> 'open' then
      v_reason := 'session';
    elsif v_at > now() then
      v_reason := 'clock';
    elsif v_at < v_sess.opened_at or p_offline_since < v_sess.opened_at then
      v_reason := 'before_session';
    elsif v_at > p_offline_since + make_interval(mins => v_max_minutes) then
      v_reason := 'too_long';
    elsif (select count(*) from public.counter_offline_sales o where o.till_session_id = p_session_id and o.state = 'accepted') >= v_max_sales then
      v_reason := 'too_many';
    elsif coalesce(nullif(v_body ->> 'price_basis', ''), 'gross') <> 'gross' then
      v_reason := 'price';
    end if;
    -- the items and their prices
    if v_reason is null and coalesce(jsonb_typeof(v_body -> 'lines'), '') = 'array' then
      for l in select value from jsonb_array_elements(v_body -> 'lines') loop
        if jsonb_typeof(l) <> 'object' or coalesce(l ->> 'item_id', '') = '' then continue; end if;
        begin
          select * into v_item from public.services s where s.id = (l ->> 'item_id')::uuid and s.workspace_id = p_workspace_id;
        exception when invalid_text_representation then v_item := null;
        end;
        if v_item.id is null or not v_item.active then
          v_reason := 'item';
          exit;
        end if;
        if coalesce(l ->> 'unit_price', '') <> '' and coalesce(nullif(l ->> 'base_quantity', ''), '1') = '1' then
          begin v_price := (l ->> 'unit_price')::numeric * (10::numeric ^ v_digits);
          exception when invalid_text_representation or numeric_value_out_of_range then v_price := null;
          end;
          if v_price is null or abs(v_price - v_item.price_cents) * 100 > v_tolerance * v_item.price_cents then
            v_reason := 'price';
            exit;
          end if;
        end if;
      end loop;
    end if;
    -- the sale itself, through the ordinary commands, in its own sub-transaction: a refusal leaves nothing but its record
    if v_reason is null then
      begin
        v_draft := public.counter_receipt_draft_v1(p_workspace_id, v_req, null, null,
          v_body || jsonb_build_object('till_id', v_sess.till_id, 'source_kind', 'offline_till', 'source_ref', p_session_id::text || ':' || v_seq));
        v_total := (v_draft #>> '{totals,gross_minor}')::bigint;
        if v_given < v_total or v_change <> v_given - v_total then
          perform public.refuse('DKL06', null, 'tender_sum');
        end if;
        v_final := public.counter_receipt_finalize_v1(p_workspace_id, md5(v_req::text || ':finalize')::uuid, (v_draft ->> 'receipt_id')::uuid, (v_draft ->> 'revision')::int,
          jsonb_build_array(jsonb_build_object('kind', 'cash', 'amount_minor', v_total)));
        insert into public.counter_offline_sales (workspace_id, till_session_id, seq, request_id, digest, occurred_at, offline_since, state,
                                                  receipt_id, number, total_minor, cash_given_minor, change_minor, body, synced_by_member_id)
        values (p_workspace_id, p_session_id, v_seq, v_req, v_digest, v_at, p_offline_since, 'accepted',
                (v_draft ->> 'receipt_id')::uuid, v_final ->> 'number', v_total, v_given, v_change, v_body, v_me)
        returning * into v_row;
      -- the refusals of the commands (the DK codes of the counter and the stock); anything else is a fault and stops the call
      exception when sqlstate 'DKG01' or sqlstate 'DKG02' or sqlstate 'DKG03' or sqlstate 'DKG04' or sqlstate 'DKG05' or sqlstate 'DKG06' or sqlstate 'DKG07' or sqlstate 'DKG08' or sqlstate 'DKG09' or sqlstate 'DKG10' or sqlstate 'DKG11' or sqlstate 'DKG12' or sqlstate 'DKG13' or sqlstate 'DKG15' or sqlstate 'DKG16' or sqlstate 'DKG17' or sqlstate 'DKG18' or sqlstate 'DKG19' or sqlstate 'DKG20' or sqlstate 'DKG21' or sqlstate 'DKG22' or sqlstate 'DKG23' or sqlstate 'DKG24' or sqlstate 'DKG25' or sqlstate 'DKG26' or sqlstate 'DKGZZ' or sqlstate 'DKL01' or sqlstate 'DKL02' or sqlstate 'DKL03' or sqlstate 'DKL04' or sqlstate 'DKL05' or sqlstate 'DKL06' or sqlstate 'DKL07' or sqlstate 'DKL08' or sqlstate 'DKL09' or sqlstate 'DKL10' or sqlstate 'DKL11' or sqlstate 'DKL12' or sqlstate 'DKL13' or sqlstate 'DKL14' or sqlstate 'DKL15' or sqlstate 'DKL16' or sqlstate 'DKN01' then
        v_reason := case when sqlstate = 'DKL06' and sqlerrm = 'tender_sum' then 'cash' else 'refused:' || sqlstate end;
        v_row := null;
      end;
    end if;
    if v_row.id is not null and v_reason is null then
      v_accepted := v_accepted + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object('seq', v_seq, 'request_id', v_req, 'state', 'accepted',
        'receipt_id', v_row.receipt_id, 'number', v_row.number, 'reason', null, 'replayed', false));
    else
      insert into public.counter_offline_sales (workspace_id, till_session_id, seq, request_id, digest, occurred_at, offline_since, state, reason,
                                                cash_given_minor, change_minor, body, synced_by_member_id)
      values (p_workspace_id, p_session_id, v_seq, v_req, v_digest, v_at, p_offline_since, 'refused', v_reason, v_given, v_change, v_body, v_me);
      v_refused := v_refused + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object('seq', v_seq, 'request_id', v_req, 'state', 'refused',
        'receipt_id', null, 'number', null, 'reason', v_reason, 'replayed', false));
    end if;
    v_row := null;
  end loop;
  return jsonb_build_object('results', v_results, 'gaps', public.counter_offline_gaps(p_session_id), 'accepted', v_accepted, 'refused', v_refused);
end;
$fn$;
revoke execute on function public.counter_offline_sync_v1(uuid, uuid, timestamptz, jsonb) from public, anon;
grant execute on function public.counter_offline_sync_v1(uuid, uuid, timestamptz, jsonb) to authenticated;

-- restates 0922
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

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(937);
