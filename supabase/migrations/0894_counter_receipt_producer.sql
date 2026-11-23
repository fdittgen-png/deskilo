-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (new functions; counter_adapters is restated so the registry's supported rows open)
--
-- #4184, #4185 (S2) -- the producer of a counter receipt: the first adapter, `counter_receipt_v1`.
--
--   * `counter_receipt_draft_v1` makes or replaces the lines of a draft under a request id and answers the preview
--     (each line's frozen facts, the totals, whether the operation is supported): nothing is numbered, nothing is taken.
--   * `counter_receipt_finalize_v1` is the one command that numbers a receipt and takes its tenders. It refuses BEFORE it
--     draws a number: an unsupported country operation (DKT01), a receipt that is not a draft (DKT04), a revision that
--     moved (DKT10), a sale with no customer where the business names one always (DKT05), a line whose tax treatment is
--     unknown or incomplete (DKT02), tenders that do not add up to the total or that this command does not take (DKT06).
--     It freezes the document (version 1: number, currency, price basis, lines in the `commercial` v1 shape, totals,
--     tax breakdown, the source, the operation it was issued under) and records the tenders in one transaction. The same
--     request id answers the same receipt; the same id with other content is refused; the same source finalizes once.
--   * `counter_receipt_correct_v1` makes a correction: a NEW receipt that cites the original and its lines, never an edit
--     of it, with quantities bounded by what the original line still has left (DKT08). It is the credit document only:
--     no refund is made by it.
--   * The line facts are computed by the standalone invoice's own line function (0820), so a service at the counter and
--     a standalone invoice freeze the same facts; goods lines are computed the same way and marked goods, and their
--     movement is made by the one stock path (0896) in the finalize's own transaction.

create or replace function public.counter_adapters()
returns text[] language sql immutable set search_path = public as $fn$
  select array['counter_receipt_v1']
$fn$;
revoke execute on function public.counter_adapters() from public, anon, authenticated;

-- the member who works the counter: a session of a person with the right to issue, the feature on
create or replace function public.counter_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to work the counter' using errcode = 'DKN01';
  end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null or not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'not allowed to work the counter' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'counterReceipts') then
    raise exception 'counter receipts are off in this business' using errcode = 'DKG01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.counter_actor(uuid) from public, anon, authenticated;

-- one line: its tax treatment from the business's own rates at the tax point, then the facts of the standalone line
create or replace function public.counter_line_compute(p_workspace_id uuid, p_line jsonb, p_index int, p_currency text, p_tax_point date)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ws public.workspaces;
  v_regime text;
  v_pct numeric := 0;
  v_rate uuid;
  v_default_rate uuid;
  v_item uuid;
  v_supply text := coalesce(p_line ->> 'supply', '');
  v_calc_supply text;
  v_cat text := '';
  v_zero text;
  v_out jsonb;
  v_line jsonb;
  v_pre text := 'line_' || p_index || '_';
begin
  if v_supply not in ('general', 'property', 'goods') then
    return jsonb_build_object('line', null, 'missing', jsonb_build_array(v_pre || 'supply'));
  end if;
  select * into v_ws from public.workspaces where id = p_workspace_id;
  v_regime := coalesce(v_ws.vat_regime, 'not_subject');
  v_zero := public.vat_zero_category(p_workspace_id, v_regime, p_tax_point);
  v_calc_supply := case when v_supply = 'goods' then 'general' else v_supply end;
  if v_regime <> 'not_subject' then
    begin v_item := nullif(p_line ->> 'item_id', '')::uuid; exception when others then v_item := null; end;
    select r.id into v_default_rate from public.vat_rates r
     where r.workspace_id = p_workspace_id and r.is_default and r.active order by r.valid_from desc limit 1;
    begin
      v_rate := coalesce(nullif(p_line ->> 'vat_rate_id', '')::uuid,
                         (select s.vat_rate_id from public.services s where s.id = v_item and s.workspace_id = p_workspace_id),
                         v_default_rate);
    exception when others then v_rate := null; end;
    if v_rate is null or not exists (select 1 from public.vat_rates r where r.id = v_rate and r.workspace_id = p_workspace_id) then
      return jsonb_build_object('line', null, 'missing', jsonb_build_array(v_pre || 'vat_rate'));
    end if;
    v_pct := public.vat_rate_percent_at(v_rate, p_tax_point);
    if v_pct is null then
      return jsonb_build_object('line', null, 'missing', jsonb_build_array(v_pre || 'vat_rate'));
    end if;
  end if;
  -- a counter sale is a domestic sale to a consumer, in the seller's own country
  v_cat := public.supply_vat_category_for(p_workspace_id, p_tax_point, 'domestic', v_calc_supply, v_regime,
             v_ws.country_code, v_ws.country_code, 'consumer', true);
  if v_cat <> '' then v_pct := 0; end if;
  v_out := public.standalone_invoice_line_v1(p_line || jsonb_build_object('supply', v_calc_supply), p_index, p_currency, v_pct,
             case when v_cat <> '' then v_cat when v_pct > 0 then 'S' else v_zero end, p_tax_point);
  if jsonb_array_length(v_out -> 'missing') > 0 then
    return v_out;
  end if;
  v_line := v_out -> 'line';
  if v_supply = 'goods' then
    v_line := jsonb_set(jsonb_set(jsonb_set(v_line, '{kind}', '"goods"'), '{supply}', '"goods"'), '{commercial,supply}', '"goods"');
  end if;
  return jsonb_build_object('missing', '[]'::jsonb, 'line', v_line);
end;
$fn$;
revoke execute on function public.counter_line_compute(uuid, jsonb, int, text, date) from public, anon, authenticated;

-- what an operation is for a business, without raising: 'supported' or the reason
create or replace function public.counter_operation_state(p_workspace_id uuid, p_operation text)
returns text language plpgsql stable security definer set search_path = public as $fn$
declare
  v_row public.counter_country_operations;
begin
  v_row := public.counter_operation_row(p_workspace_id, p_operation);
  if v_row.id is null then return 'no_row'; end if;
  if v_row.outcome <> 'supported' then return 'unavailable'; end if;
  if not (v_row.adapter = any (public.counter_adapters())) then return 'adapter_missing'; end if;
  return 'supported';
end;
$fn$;
revoke execute on function public.counter_operation_state(uuid, text) from public, anon, authenticated;

-- the lines a body names, read exactly and computed; returns {lines, missing, totals}
create or replace function public.counter_lines_of(p_workspace_id uuid, p_lines jsonb, p_currency text, p_basis text, p_tax_point date)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  e jsonb;
  v_idx int := 0;
  v_missing text[] := '{}';
  v_out jsonb;
  v_in jsonb;
  v_item public.services;
  v_item_id uuid;
  v_digits int := public.currency_minor_digits(p_currency);
  v_rows jsonb := '[]'::jsonb;
  v_net bigint := 0;
  v_tax bigint := 0;
  v_gross bigint := 0;
begin
  if coalesce(jsonb_typeof(p_lines), '') <> 'array' or jsonb_array_length(p_lines) not between 1 and 200 then
    return jsonb_build_object('lines', '[]'::jsonb, 'missing', jsonb_build_array('lines'), 'totals', null);
  end if;
  for e in select value from jsonb_array_elements(p_lines) loop
    v_idx := v_idx + 1;
    v_in := e;
    if jsonb_typeof(v_in) <> 'object' then
      v_missing := v_missing || ('line_' || v_idx);
      continue;
    end if;
    v_item := null;
    begin v_item_id := nullif(v_in ->> 'item_id', '')::uuid; exception when others then v_item_id := null; v_missing := v_missing || ('line_' || v_idx || '_item'); continue; end;
    if v_item_id is not null then
      select * into v_item from public.services s where s.id = v_item_id and s.workspace_id = p_workspace_id and s.active;
      if v_item.id is null then
        v_missing := v_missing || ('line_' || v_idx || '_item');
        continue;
      end if;
      if coalesce(v_in ->> 'description', '') = '' then v_in := v_in || jsonb_build_object('description', v_item.name); end if;
      if coalesce(v_in ->> 'unit_price', '') = '' then
        if p_basis <> 'gross' then
          v_missing := v_missing || ('line_' || v_idx || '_unit_price');
          continue;
        end if;
        v_in := v_in || jsonb_build_object('unit_price', trim_scale(v_item.price_cents::numeric / (10::numeric ^ v_digits))::text);
      end if;
      if (v_in -> 'unit') is null then
        v_in := v_in || jsonb_build_object('unit', jsonb_build_object('code', v_item.inventory_unit, 'label', v_item.inventory_unit,
                                                                      'un_ece_code', case when v_item.inventory_unit = 'piece' then 'C62' else '' end));
      end if;
      if coalesce(v_in ->> 'supply', '') = '' then
        v_in := v_in || jsonb_build_object('supply', case when v_item.stockable then 'goods' else 'general' end);
      end if;
    end if;
    if v_in ->> 'supply' = 'goods' and (v_item.id is null or not v_item.stockable) then
      v_missing := v_missing || ('line_' || v_idx || '_item');
      continue;
    end if;
    if coalesce(v_in ->> 'line_id', '') = '' then v_in := v_in || jsonb_build_object('line_id', gen_random_uuid()); end if;
    v_in := v_in || jsonb_build_object('basis', p_basis);
    v_out := public.counter_line_compute(p_workspace_id, v_in, v_idx, p_currency, p_tax_point);
    if jsonb_array_length(v_out -> 'missing') > 0 then
      v_missing := v_missing || array(select jsonb_array_elements_text(v_out -> 'missing'));
      continue;
    end if;
    v_rows := v_rows || jsonb_build_array(jsonb_build_object('input', v_in, 'line', v_out -> 'line', 'item_id', v_item_id,
                                                              'variant_id', nullif(v_in ->> 'variant_id', '')));
    v_net := v_net + (v_out #>> '{line,commercial,amounts,net_minor}')::bigint;
    v_tax := v_tax + (v_out #>> '{line,commercial,amounts,tax_minor}')::bigint;
    v_gross := v_gross + (v_out #>> '{line,commercial,amounts,gross_minor}')::bigint;
  end loop;
  if v_gross > 2000000000 then v_missing := v_missing || 'total_amount'::text; end if;
  return jsonb_build_object('lines', v_rows, 'missing', to_jsonb(v_missing),
    'totals', jsonb_build_object('net_minor', v_net::text, 'tax_minor', v_tax::text, 'gross_minor', v_gross::text, 'currency', p_currency));
end;
$fn$;
revoke execute on function public.counter_lines_of(uuid, jsonb, text, text, date) from public, anon, authenticated;

-- ── a draft, made or replaced ──────────────────────────────────────────
-- audience: all row readers
create or replace function public.counter_receipt_draft_v1(
  p_workspace_id uuid, p_request_id uuid, p_receipt_id uuid, p_expected_revision int, p_body jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_ws public.workspaces;
  v_rec public.counter_receipts;
  v_cur text;
  v_basis text;
  v_subject uuid;
  v_kind text;
  v_ref text;
  v_tp date;
  v_calc jsonb;
  r jsonb;
  v_no int := 0;
  v_id uuid;
  v_result jsonb;
  v_state text;
begin
  v_me := public.counter_actor(p_workspace_id);
  if p_request_id is null or coalesce(jsonb_typeof(p_body), '') <> 'object' then
    raise exception 'a draft is made with a request id and its fields' using errcode = '22023';
  end if;
  v_digest := md5(coalesce(p_receipt_id::text, '') || '|' || coalesce(p_expected_revision::text, '') || '|' || p_body::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_draft', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_ws from public.workspaces w where w.id = p_workspace_id;
  v_cur := upper(coalesce(nullif(p_body ->> 'currency', ''), v_ws.currency_code));
  v_basis := coalesce(nullif(p_body ->> 'price_basis', ''), 'gross');
  v_kind := coalesce(nullif(p_body ->> 'source_kind', ''), 'counter');
  v_ref := coalesce(p_body ->> 'source_ref', '');
  if v_basis not in ('gross', 'net') or v_cur !~ '^[A-Z]{3}$' or v_kind !~ '^[a-z_]{1,32}$' or char_length(v_ref) > 200 then
    raise exception 'receipt_essentials_missing' using errcode = 'DKT02', detail = 'header';
  end if;
  begin v_subject := nullif(p_body ->> 'financial_subject_id', '')::uuid; exception when others then
    raise exception 'receipt_essentials_missing' using errcode = 'DKT02', detail = 'financial_subject';
  end;
  if v_subject is not null and not exists (select 1 from public.members m where m.id = v_subject and m.workspace_id = p_workspace_id) then
    raise exception 'receipt_essentials_missing' using errcode = 'DKT02', detail = 'financial_subject';
  end if;
  v_tp := public.workspace_today(p_workspace_id);
  v_calc := public.counter_lines_of(p_workspace_id, p_body -> 'lines', v_cur, v_basis, v_tp);
  if jsonb_array_length(v_calc -> 'missing') > 0 then
    raise exception 'receipt_essentials_missing' using errcode = 'DKT02',
      detail = (select string_agg(x, ',') from jsonb_array_elements_text(v_calc -> 'missing') x);
  end if;
  if p_receipt_id is null then
    insert into public.counter_receipts (workspace_id, currency, price_basis, financial_subject_id, source_kind, source_ref, created_by_member_id,
                                         total_minor, tax_minor)
    values (p_workspace_id, v_cur, v_basis, v_subject, v_kind, v_ref, v_me,
            (v_calc #>> '{totals,gross_minor}')::bigint, (v_calc #>> '{totals,tax_minor}')::bigint)
    returning * into v_rec;
  else
    select * into v_rec from public.counter_receipts x where x.id = p_receipt_id and x.workspace_id = p_workspace_id for update;
    if v_rec.id is null or v_rec.state <> 'draft' or v_rec.kind <> 'sale' then
      raise exception 'this receipt is not an open draft' using errcode = 'DKT04';
    end if;
    if p_expected_revision is distinct from v_rec.revision then
      raise exception 'this receipt changed meanwhile' using errcode = 'DKT10';
    end if;
    update public.counter_receipts set currency = v_cur, price_basis = v_basis, financial_subject_id = v_subject,
           source_kind = v_kind, source_ref = v_ref, revision = revision + 1,
           total_minor = (v_calc #>> '{totals,gross_minor}')::bigint, tax_minor = (v_calc #>> '{totals,tax_minor}')::bigint
     where id = v_rec.id returning * into v_rec;
    delete from public.counter_receipt_lines where receipt_id = v_rec.id;
  end if;
  for r in select value from jsonb_array_elements(v_calc -> 'lines') loop
    v_no := v_no + 1;
    insert into public.counter_receipt_lines (workspace_id, receipt_id, line_no, item_id, variant_id, quantity, frozen, net_minor, tax_minor, gross_minor)
    values (p_workspace_id, v_rec.id, v_no, nullif(r ->> 'item_id', '')::uuid, nullif(r ->> 'variant_id', '')::uuid,
            (r #>> '{line,commercial,quantity}')::numeric, (r -> 'line') || jsonb_build_object('input', r -> 'input'),
            (r #>> '{line,commercial,amounts,net_minor}')::bigint, (r #>> '{line,commercial,amounts,tax_minor}')::bigint,
            (r #>> '{line,commercial,amounts,gross_minor}')::bigint);
  end loop;
  v_state := public.counter_operation_state(p_workspace_id, 'issue_receipt');
  v_result := jsonb_build_object('receipt_id', v_rec.id, 'revision', v_rec.revision, 'state', 'draft',
    'currency', v_cur, 'price_basis', v_basis, 'totals', v_calc -> 'totals',
    'lines', (select jsonb_agg(x -> 'line') from jsonb_array_elements(v_calc -> 'lines') x),
    'issue_receipt', v_state, 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_draft', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_receipt_draft_v1(uuid, uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.counter_receipt_draft_v1(uuid, uuid, uuid, int, jsonb) to authenticated;

-- ── finalize: the one command that numbers a receipt and takes its tenders ──
-- audience: all row readers
create or replace function public.counter_receipt_finalize_v1(
  p_workspace_id uuid, p_request_id uuid, p_receipt_id uuid, p_expected_revision int, p_tenders jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_rec public.counter_receipts;
  v_op public.counter_country_operations;
  v_regime text;
  v_tp date;
  v_input jsonb := '[]'::jsonb;
  l public.counter_receipt_lines;
  v_calc jsonb;
  v_total bigint;
  v_tax bigint;
  v_net bigint;
  v_number text;
  v_frozen jsonb;
  v_breakdown jsonb;
  v_t jsonb;
  v_sum bigint := 0;
  v_part int := 0;
  v_amount bigint;
  v_kind text;
  v_other public.counter_receipts;
  v_result jsonb;
  r jsonb;
  v_no int := 0;
  v_named uuid[];
  v_tender public.counter_tenders;
  v_goods jsonb;
  v_main uuid;
begin
  v_me := public.counter_actor(p_workspace_id);
  if p_request_id is null or p_receipt_id is null or coalesce(jsonb_typeof(p_tenders), '') <> 'array' then
    raise exception 'a receipt is finalized with a request id, its revision and its tenders' using errcode = '22023';
  end if;
  v_digest := md5(p_receipt_id::text || '|' || coalesce(p_expected_revision::text, '') || '|' || p_tenders::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_finalize', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_rec from public.counter_receipts x where x.id = p_receipt_id and x.workspace_id = p_workspace_id for update;
  if v_rec.id is null or v_rec.state <> 'draft' or v_rec.kind <> 'sale' then
    raise exception 'this receipt is not an open draft' using errcode = 'DKT04';
  end if;
  if p_expected_revision is distinct from v_rec.revision then
    raise exception 'this receipt changed meanwhile' using errcode = 'DKT10';
  end if;
  -- the country operation first: nothing is numbered and nothing is taken where it is not supported
  v_op := public.counter_require_operation(p_workspace_id, 'issue_receipt');
  if jsonb_array_length(p_tenders) > 0 then
    perform public.counter_require_operation(p_workspace_id, 'reconcile_tender');
  end if;
  if v_rec.financial_subject_id is null and coalesce(public.setting_value(p_workspace_id, 'counter.customerless_sales') #>> '{}', 'allowed') = 'refused' then
    raise exception 'this business names a customer on every sale' using errcode = 'DKT05';
  end if;
  if v_rec.source_ref <> '' then
    select * into v_other from public.counter_receipts o
     where o.workspace_id = p_workspace_id and o.source_kind = v_rec.source_kind and o.source_ref = v_rec.source_ref
       and o.state = 'finalized' and o.kind = 'sale';
    if v_other.id is not null then
      raise exception 'a receipt was already issued for this source' using errcode = 'DKT04',
        detail = jsonb_build_object('receipt_id', v_other.id, 'number', v_other.number)::text;
    end if;
  end if;
  v_tp := public.workspace_today(p_workspace_id);
  for l in select * from public.counter_receipt_lines x where x.receipt_id = v_rec.id order by x.line_no loop
    v_input := v_input || jsonb_build_array(l.frozen -> 'input');
  end loop;
  v_calc := public.counter_lines_of(p_workspace_id, v_input, v_rec.currency, v_rec.price_basis, v_tp);
  if jsonb_array_length(v_calc -> 'missing') > 0 then
    raise exception 'receipt_essentials_missing' using errcode = 'DKT02',
      detail = (select string_agg(x, ',') from jsonb_array_elements_text(v_calc -> 'missing') x);
  end if;
  v_total := (v_calc #>> '{totals,gross_minor}')::bigint;
  v_tax := (v_calc #>> '{totals,tax_minor}')::bigint;
  v_net := (v_calc #>> '{totals,net_minor}')::bigint;
  if v_total <= 0 then
    raise exception 'receipt_essentials_missing' using errcode = 'DKT02', detail = 'total_not_positive';
  end if;
  -- the tenders: the cash and other ones named here, each of its own part, and the card ones already accepted on this
  -- receipt (named by id), adding to the total exactly; an authorization still open (requested or unknown) is never
  -- passed over, a refused one is not paid
  if exists (select 1 from public.counter_tenders t where t.receipt_id = v_rec.id
                and (t.state in ('requested', 'unknown') or (t.state = 'accepted' and t.reconciliation = 'needed'))) then
    raise exception 'a card authorization of this sale is still open' using errcode = 'DKT06', detail = 'tender_open';
  end if;
  if jsonb_array_length(p_tenders) = 0 and not exists (select 1 from public.counter_tenders t where t.receipt_id = v_rec.id and t.state = 'accepted') then
    raise exception 'a sale is settled by its tenders' using errcode = 'DKT06', detail = 'tenders_missing';
  end if;
  v_named := array[]::uuid[];
  for v_t in select value from jsonb_array_elements(p_tenders) loop
    if v_t ? 'tender_id' then
      select * into v_tender from public.counter_tenders t
       where t.id = nullif(v_t ->> 'tender_id', '')::uuid and t.receipt_id = v_rec.id and t.workspace_id = p_workspace_id;
      if v_tender.id is null or v_tender.kind <> 'card' or v_tender.state <> 'accepted' or v_tender.reconciliation = 'needed' or v_tender.id = any (v_named) then
        raise exception 'this tender is not an accepted card tender of this sale' using errcode = 'DKT06', detail = 'tender_state';
      end if;
      v_named := v_named || v_tender.id;
      v_sum := v_sum + v_tender.amount_minor;
      continue;
    end if;
    v_kind := v_t ->> 'kind';
    if v_kind is null or v_kind not in ('cash', 'other') then
      raise exception 'this tender is not taken here' using errcode = 'DKT06', detail = 'tender_kind';
    end if;
    if coalesce(v_t ->> 'amount_minor', '') !~ '^[0-9]{1,12}$' or (v_t ->> 'amount_minor')::bigint <= 0 then
      raise exception 'this tender has no amount' using errcode = 'DKT06', detail = 'tender_amount';
    end if;
    v_sum := v_sum + (v_t ->> 'amount_minor')::bigint;
  end loop;
  -- an accepted card tender of this receipt that the caller did not name is still money taken: it counts
  v_sum := v_sum + coalesce((select sum(t.amount_minor) from public.counter_tenders t
                              where t.receipt_id = v_rec.id and t.state = 'accepted' and not (t.id = any (v_named))), 0);
  if v_sum <> v_total then
    raise exception 'the tenders do not add up to the total' using errcode = 'DKT06', detail = 'tender_sum';
  end if;
  -- everything is accepted: now the number
  v_number := public.next_document_number(p_workspace_id, 'receipt');
  select coalesce(jsonb_agg(jsonb_build_object('percent', g.pct, 'category', g.cat, 'gross_minor', g.gross::text,
                                               'net_minor', g.net::text, 'tax_minor', (g.gross - g.net)::text) order by g.pct desc, g.cat), '[]'::jsonb)
    into v_breakdown
    from (select (x #>> '{line,vat_percent}')::numeric pct, x #>> '{line,vat_category}' cat,
                 sum((x #>> '{line,commercial,amounts,gross_minor}')::bigint) gross,
                 sum((x #>> '{line,commercial,amounts,net_minor}')::bigint) net
            from jsonb_array_elements(v_calc -> 'lines') x group by 1, 2) g;
  v_regime := coalesce(public.setting_value(p_workspace_id, 'counter.fiscal_obligation') #>> '{}', 'register_required');
  v_frozen := jsonb_build_object(
    'version', 1, 'number', v_number, 'currency', v_rec.currency, 'price_basis', v_rec.price_basis,
    'issued_at', now(), 'tax_point', v_tp,
    'lines', (select jsonb_agg(x -> 'line') from jsonb_array_elements(v_calc -> 'lines') x),
    'totals', v_calc -> 'totals', 'tax_breakdown', v_breakdown,
    'source', jsonb_build_object('kind', v_rec.source_kind, 'ref', v_rec.source_ref),
    'financial_subject_id', v_rec.financial_subject_id,
    'operation', jsonb_build_object('country', v_op.country_code, 'operation', v_op.operation, 'regime', v_op.regime,
      'specification', v_op.specification, 'specification_version', v_op.specification_version,
      'effective_from', v_op.effective_from, 'adapter', v_op.adapter, 'confirmed', v_op.confirmed),
    'corrects', null);
  for r in select value from jsonb_array_elements(v_calc -> 'lines') loop
    v_no := v_no + 1;
    update public.counter_receipt_lines set frozen = (r -> 'line') || jsonb_build_object('input', r -> 'input'),
           net_minor = (r #>> '{line,commercial,amounts,net_minor}')::bigint, tax_minor = (r #>> '{line,commercial,amounts,tax_minor}')::bigint,
           gross_minor = (r #>> '{line,commercial,amounts,gross_minor}')::bigint, quantity = (r #>> '{line,commercial,quantity}')::numeric
     where receipt_id = v_rec.id and line_no = v_no;
  end loop;
  update public.counter_receipts set state = 'finalized', number = v_number, frozen = v_frozen, total_minor = v_total, tax_minor = v_tax,
         operation_id = v_op.id, fiscal_assumption = v_regime, finalized_by_member_id = v_me, finalized_at = now()
   where id = v_rec.id;
  select coalesce(max(t.part), 0) into v_part from public.counter_tenders t where t.receipt_id = v_rec.id;
  for v_t in select value from jsonb_array_elements(p_tenders) loop
    if v_t ? 'tender_id' then continue; end if;
    v_part := v_part + 1;
    insert into public.counter_tenders (workspace_id, receipt_id, part, kind, amount_minor, state, request_id, resolved_at, recorded_by_member_id)
    values (p_workspace_id, v_rec.id, v_part, v_t ->> 'kind', (v_t ->> 'amount_minor')::bigint, 'accepted', p_request_id, now(), v_me);
  end loop;
  -- goods: one movement per goods line through the one stock path, in this transaction and under this request id, linked to
  -- this receipt: a line that cannot leave (not enough, expired, a variant or a lot to name) rolls the whole sale back,
  -- number included; issuing the receipt moves nothing else, and a replay answers without moving anything again
  v_goods := '[]'::jsonb;
  for r in select value from jsonb_array_elements(v_calc -> 'lines') loop
    if r #>> '{line,supply}' = 'goods' then
      if not public.feature_effective(p_workspace_id, 'stockManagement') then
        raise exception 'goods are not sold here: the goods ledger is off' using errcode = 'DKT07', detail = 'goods_off';
      end if;
      v_main := coalesce(nullif(r #>> '{input,from_location_id}', '')::uuid,
                         (select sl.id from public.stock_locations sl where sl.workspace_id = p_workspace_id and sl.code = 'MAIN' limit 1));
      if v_main is null then
        raise exception 'no place to take the goods from' using errcode = 'DKT07', detail = 'from_place';
      end if;
      v_goods := v_goods || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        'item_id', r ->> 'item_id', 'variant_id', nullif(r #>> '{input,variant_id}', ''),
        'quantity', r #>> '{line,commercial,quantity}', 'unit', r #>> '{line,commercial,unit,code}',
        'from', v_main, 'to', public.stock_place(p_workspace_id, 'customer'), 'lot_id', nullif(r #>> '{input,lot_id}', ''))));
    end if;
  end loop;
  if jsonb_array_length(v_goods) > 0 then
    perform public.stock_apply_lines(p_workspace_id, v_me, p_request_id, v_goods, 'sale', now(),
                                     jsonb_build_object('counter_receipt_id', v_rec.id), 'generic');
  end if;
  v_result := jsonb_build_object('receipt_id', v_rec.id, 'number', v_number, 'currency', v_rec.currency,
    'totals', v_calc -> 'totals', 'tenders', (select count(*) from public.counter_tenders t where t.receipt_id = v_rec.id and t.state = 'accepted'), 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_finalize', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_receipt_finalize_v1(uuid, uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.counter_receipt_finalize_v1(uuid, uuid, uuid, int, jsonb) to authenticated;

-- ── a correction: a new receipt that cites the original, never an edit of it ──
-- audience: all row readers
create or replace function public.counter_receipt_correct_v1(
  p_workspace_id uuid, p_request_id uuid, p_original_id uuid, p_body jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_orig public.counter_receipts;
  v_op public.counter_country_operations;
  v_regime text;
  v_tp date;
  e jsonb;
  v_idx int := 0;
  v_ol public.counter_receipt_lines;
  v_qty numeric;
  v_left numeric;
  v_in jsonb;
  v_out jsonb;
  v_rows jsonb := '[]'::jsonb;
  v_net bigint := 0;
  v_tax bigint := 0;
  v_gross bigint := 0;
  v_number text;
  v_rec public.counter_receipts;
  v_frozen jsonb;
  v_breakdown jsonb;
  v_lineno int := 0;
  v_seen uuid[] := array[]::uuid[];
  v_result jsonb;
  r jsonb;
  v_prev_gross bigint;
  v_prev_tax bigint;
  v_line_gross bigint;
  v_line_tax bigint;
begin
  v_me := public.counter_actor(p_workspace_id);
  if p_request_id is null or p_original_id is null or coalesce(jsonb_typeof(p_body), '') <> 'object' or coalesce(jsonb_typeof(p_body -> 'lines'), '') <> 'array' then
    raise exception 'a correction is made with a request id, the original and its lines' using errcode = '22023';
  end if;
  v_digest := md5(p_original_id::text || '|' || p_body::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_correct', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_orig from public.counter_receipts x where x.id = p_original_id and x.workspace_id = p_workspace_id for update;
  if v_orig.id is null or v_orig.state <> 'finalized' or v_orig.kind <> 'sale' then
    raise exception 'only a finalized sale is corrected' using errcode = 'DKT04';
  end if;
  v_op := public.counter_require_operation(p_workspace_id, 'correct_receipt');
  v_tp := public.workspace_today(p_workspace_id);
  for e in select value from jsonb_array_elements(p_body -> 'lines') loop
    v_idx := v_idx + 1;
    select * into v_ol from public.counter_receipt_lines x
     where x.workspace_id = p_workspace_id and x.receipt_id = v_orig.id and x.id = nullif(e ->> 'corrects_line_id', '')::uuid;
    if v_ol.id is null or v_ol.id = any (v_seen) then
      raise exception 'this line is not a line of the original' using errcode = 'DKT08', detail = jsonb_build_object('line', v_idx, 'reason', 'line_unknown')::text;
    end if;
    v_seen := v_seen || v_ol.id;
    if coalesce(e ->> 'quantity', '') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' or (e ->> 'quantity')::numeric <= 0 then
      raise exception 'this quantity is not a quantity' using errcode = 'DKT08', detail = jsonb_build_object('line', v_idx, 'reason', 'quantity')::text;
    end if;
    v_qty := (e ->> 'quantity')::numeric;
    v_left := v_ol.quantity - coalesce((select sum(c.quantity) from public.counter_receipt_lines c
                                          join public.counter_receipts cr on cr.id = c.receipt_id and cr.state = 'finalized'
                                         where c.corrects_line_id = v_ol.id), 0);
    if v_qty > v_left then
      raise exception 'more is corrected than the original line has left' using errcode = 'DKT08',
        detail = jsonb_build_object('line', v_idx, 'reason', 'beyond_original', 'left', trim_scale(v_left)::text)::text;
    end if;
    -- the facts of the ORIGINAL line, not today's: its own price, unit, rate and category, at the original tax point,
    -- for the corrected quantity; a line that completes the original is exactly what is left of it
    v_in := (v_ol.frozen -> 'input') || jsonb_build_object('quantity', trim_scale(v_qty)::text, 'line_id', gen_random_uuid(),
                                                            'supply', case when (v_ol.frozen ->> 'supply') = 'goods' then 'general' else v_ol.frozen ->> 'supply' end);
    v_out := public.standalone_invoice_line_v1(v_in, v_idx, v_orig.currency, (v_ol.frozen ->> 'vat_percent')::numeric,
               v_ol.frozen ->> 'vat_category', (v_ol.frozen #>> '{commercial,tax_facts,tax_point}')::date);
    if jsonb_array_length(v_out -> 'missing') > 0 then
      raise exception 'receipt_essentials_missing' using errcode = 'DKT02',
        detail = (select string_agg(x, ',') from jsonb_array_elements_text(v_out -> 'missing') x);
    end if;
    select coalesce(sum(c.gross_minor), 0), coalesce(sum(c.tax_minor), 0) into v_prev_gross, v_prev_tax
      from public.counter_receipt_lines c join public.counter_receipts cr on cr.id = c.receipt_id and cr.state = 'finalized'
     where c.corrects_line_id = v_ol.id;
    v_line_gross := (v_out #>> '{line,commercial,amounts,gross_minor}')::bigint;
    if v_qty = v_left then
      v_line_gross := v_ol.gross_minor - v_prev_gross;
      v_line_tax := v_ol.tax_minor - v_prev_tax;
      v_out := jsonb_set(jsonb_set(jsonb_set(jsonb_set(v_out, '{line,commercial,amounts,gross_minor}', to_jsonb(v_line_gross::text)),
                 '{line,commercial,amounts,tax_minor}', to_jsonb(v_line_tax::text)),
                 '{line,commercial,amounts,net_minor}', to_jsonb((v_line_gross - v_line_tax)::text)),
                 '{line,amount_cents}', to_jsonb(v_line_gross));
    elsif v_prev_gross + v_line_gross > v_ol.gross_minor then
      raise exception 'more is corrected than the original line holds' using errcode = 'DKT08',
        detail = jsonb_build_object('line', v_idx, 'reason', 'amount_beyond')::text;
    end if;
    if (v_ol.frozen ->> 'supply') = 'goods' then
      v_out := jsonb_set(v_out, '{line}', jsonb_set(jsonb_set(jsonb_set(v_out -> 'line', '{kind}', '"goods"'), '{supply}', '"goods"'), '{commercial,supply}', '"goods"'));
    end if;
    v_rows := v_rows || jsonb_build_array(jsonb_build_object('input', v_in, 'line', v_out -> 'line', 'item_id', v_ol.item_id,
                                                              'variant_id', v_ol.variant_id, 'corrects_line_id', v_ol.id));
    v_net := v_net + (v_out #>> '{line,commercial,amounts,net_minor}')::bigint;
    v_tax := v_tax + (v_out #>> '{line,commercial,amounts,tax_minor}')::bigint;
    v_gross := v_gross + (v_out #>> '{line,commercial,amounts,gross_minor}')::bigint;
  end loop;
  if v_idx = 0 or v_gross <= 0 then
    raise exception 'a correction names at least one line' using errcode = 'DKT08', detail = jsonb_build_object('reason', 'empty')::text;
  end if;
  v_number := public.next_document_number(p_workspace_id, 'receipt');
  select coalesce(jsonb_agg(jsonb_build_object('percent', g.pct, 'category', g.cat, 'gross_minor', g.gross::text,
                                               'net_minor', g.net::text, 'tax_minor', (g.gross - g.net)::text) order by g.pct desc, g.cat), '[]'::jsonb)
    into v_breakdown
    from (select (x #>> '{line,vat_percent}')::numeric pct, x #>> '{line,vat_category}' cat,
                 sum((x #>> '{line,commercial,amounts,gross_minor}')::bigint) gross,
                 sum((x #>> '{line,commercial,amounts,net_minor}')::bigint) net
            from jsonb_array_elements(v_rows) y, lateral (select y as x) z group by 1, 2) g;
  v_regime := coalesce(public.setting_value(p_workspace_id, 'counter.fiscal_obligation') #>> '{}', 'register_required');
  v_frozen := jsonb_build_object(
    'version', 1, 'number', v_number, 'currency', v_orig.currency, 'price_basis', v_orig.price_basis,
    'issued_at', now(), 'tax_point', v_tp,
    'lines', (select jsonb_agg(x -> 'line') from jsonb_array_elements(v_rows) x),
    'totals', jsonb_build_object('net_minor', v_net::text, 'tax_minor', v_tax::text, 'gross_minor', v_gross::text, 'currency', v_orig.currency),
    'tax_breakdown', v_breakdown,
    'source', jsonb_build_object('kind', v_orig.source_kind, 'ref', v_orig.source_ref),
    'financial_subject_id', v_orig.financial_subject_id,
    'operation', jsonb_build_object('country', v_op.country_code, 'operation', v_op.operation, 'regime', v_op.regime,
      'specification', v_op.specification, 'specification_version', v_op.specification_version,
      'effective_from', v_op.effective_from, 'adapter', v_op.adapter, 'confirmed', v_op.confirmed),
    'corrects', jsonb_build_object('receipt_id', v_orig.id, 'number', v_orig.number, 'reason', left(coalesce(p_body ->> 'reason', ''), 200)));
  insert into public.counter_receipts (workspace_id, state, kind, currency, price_basis, financial_subject_id, source_kind, source_ref,
                                       corrects_receipt_id, number, frozen, total_minor, tax_minor, operation_id, fiscal_assumption,
                                       created_by_member_id, finalized_by_member_id, finalized_at)
  values (p_workspace_id, 'finalized', 'correction', v_orig.currency, v_orig.price_basis, v_orig.financial_subject_id, v_orig.source_kind, '',
          v_orig.id, v_number, v_frozen, v_gross, v_tax, v_op.id, v_regime, v_me, v_me, now())
  returning * into v_rec;
  for r in select value from jsonb_array_elements(v_rows) loop
    v_lineno := v_lineno + 1;
    insert into public.counter_receipt_lines (workspace_id, receipt_id, line_no, item_id, variant_id, corrects_line_id, quantity, frozen, net_minor, tax_minor, gross_minor)
    values (p_workspace_id, v_rec.id, v_lineno, nullif(r ->> 'item_id', '')::uuid, nullif(r ->> 'variant_id', '')::uuid, (r ->> 'corrects_line_id')::uuid,
            (r #>> '{line,commercial,quantity}')::numeric, (r -> 'line') || jsonb_build_object('input', r -> 'input'),
            (r #>> '{line,commercial,amounts,net_minor}')::bigint, (r #>> '{line,commercial,amounts,tax_minor}')::bigint,
            (r #>> '{line,commercial,amounts,gross_minor}')::bigint);
  end loop;
  v_result := jsonb_build_object('receipt_id', v_rec.id, 'number', v_number, 'corrects', v_orig.id, 'currency', v_orig.currency,
    'totals', v_frozen -> 'totals', 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_correct', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_receipt_correct_v1(uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.counter_receipt_correct_v1(uuid, uuid, uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(894);
