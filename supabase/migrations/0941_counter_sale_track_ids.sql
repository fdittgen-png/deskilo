-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (two new internal functions; counter_receipt_finalize_v1 restated whole; its answer gains a key)
--
-- #4436 (G21, first of two files) -- a sale of a traced good names the track ID it was received with. Until now a goods
-- line of a counter receipt left through the one stock path (0896) without naming its line, and a lot-tracked item
-- could be sold only when the seller named the lot. Now:
--
--   * Each goods movement of a sale names the receipt line that caused it (`counter_line_id`), so the trace reads the
--     sale line backwards (0923) and the line names what it took.
--   * A line of an item tracked by lot that names no lot is taken from the lots on hand at the place, the first to
--     expire first, an expired lot never; one movement per lot. A line that names its pieces (`units`, by tag or by
--     piece id) is taken lot by lot, as the pieces carry their lots; the pieces named must be the line's quantity.
--   * The track IDs of each goods line are frozen with the document, in the line (`tracks`) and in the receipt's
--     frozen lines, in the finalize's own transaction and before the receipt is finalized: the lot code as received
--     (else its label code) with the quantity taken from it, and each piece with its tag code. A later change of a lot
--     or a tag never alters an issued receipt. Pieces are named only where the business uses tags.
--   * The finalize answers the tracks of its goods lines (`lines`), so the till can say them; a replay answers the same.
--   * A call without its request id, receipt or tenders is refused with the counter's DKL02 (it was a bare 22023).
--   * Version 1 of the frozen receipt keeps its keys: `tracks` is an added key of a line, which the version-1 reader
--     passes through with the line.

-- the track IDs of the movements given: the lots (code as received, quantity taken) and the pieces (tag code)
create or replace function public.stock_tracks_of(p_workspace_id uuid, p_movements uuid[])
returns jsonb
language sql
stable
security definer
set search_path = public
as $fn$
  select coalesce((
    select jsonb_agg(x.t order by x.o, x.k)
      from (select min(m.line_no * 10000 + m.part) o, l.id::text k,
                   jsonb_strip_nulls(jsonb_build_object(
                     'kind', 'lot', 'lot_id', l.id,
                     'code', coalesce(nullif(l.lot_code, ''), l.label_code),
                     'label_code', l.label_code, 'expires_on', l.expires_on,
                     'quantity', trim_scale(sum(m.quantity))::text)) t
              from public.stock_movements m
              join public.stock_lots l on l.id = m.lot_id and l.workspace_id = p_workspace_id
             where m.workspace_id = p_workspace_id and m.id = any (coalesce(p_movements, array[]::uuid[]))
             group by l.id) x), '[]'::jsonb)
  || case when public.feature_effective(p_workspace_id, 'stockTags') then coalesce((
    select jsonb_agg(jsonb_strip_nulls(jsonb_build_object('kind', 'piece', 'piece_id', z.id, 'code', z.code, 'lot_id', z.lot_id))
                     order by z.code nulls last, z.id)
      from (select u.id, u.lot_id,
                   (select g.code from public.stock_tags g where g.workspace_id = p_workspace_id and g.piece_id = u.id
                     order by (g.state = 'active') desc, g.created_datetime desc limit 1) code
              from public.stock_movement_units mu
              join public.stock_tagged_units u on u.id = mu.unit_id and u.workspace_id = p_workspace_id
             where mu.workspace_id = p_workspace_id and mu.movement_id = any (coalesce(p_movements, array[]::uuid[]))
             group by u.id, u.lot_id) z), '[]'::jsonb)
    else '[]'::jsonb end
$fn$;
revoke execute on function public.stock_tracks_of(uuid, uuid[]) from public, anon, authenticated;

-- the parts a goods line of a sale leaves in: as named (a lot, or an untracked item, as before); a lot-tracked item
-- without a lot from the lots on hand, the first to expire first and never an expired one; named pieces lot by lot
create or replace function public.counter_goods_parts(
  p_workspace_id uuid, p_item_id uuid, p_variant_id uuid, p_from uuid, p_quantity text, p_unit text, p_input jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_item public.services;
  v_units jsonb := p_input -> 'units';
  v_named boolean := nullif(p_input ->> 'lot_id', '') is not null;
  v_lot uuid;
  v_qty numeric;
  v_left numeric;
  v_take numeric;
  v_parts jsonb := '[]'::jsonb;
  v_today date := public.workspace_today(p_workspace_id);
  b record;
begin
  select * into v_item from public.services where id = p_item_id and workspace_id = p_workspace_id;
  -- as before: the line as it was named, for the stock path to check
  if v_item.id is null or (coalesce(jsonb_typeof(v_units), '') <> 'array' and (v_named or v_item.tracking = 'none'))
     or coalesce(p_quantity, '') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' then
    return jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'quantity', p_quantity, 'unit', p_unit, 'lot_id', nullif(p_input ->> 'lot_id', ''), 'units', v_units)));
  end if;
  v_qty := public.stock_to_inventory(p_item_id, p_unit, p_quantity::numeric);
  if jsonb_typeof(v_units) = 'array' then
    if jsonb_array_length(v_units) <> v_qty then
      raise exception 'name the pieces: % named for a quantity of %', jsonb_array_length(v_units), trim_scale(v_qty)
        using errcode = 'DKG25';
    end if;
    v_lot := case when coalesce(p_input ->> 'lot_id', '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
                  then (p_input ->> 'lot_id')::uuid end;
    -- each piece goes with its own lot (a lot the line names wins, and the stock path checks it)
    select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
             'quantity', g.n::text, 'unit', v_item.inventory_unit, 'lot_id', g.lot, 'units', g.units)) order by g.first), '[]'::jsonb)
      into v_parts
      from (select p.lot, count(*) n, jsonb_agg(p.u order by p.ord) units, min(p.ord) first
              from (select x.u, x.ord,
                           coalesce(v_lot,
                             (select pc.lot_id from public.stock_tagged_units pc
                               where pc.workspace_id = p_workspace_id
                                 and pc.id::text = lower(coalesce(x.u ->> 'piece_id', ''))),
                             (select pc.lot_id from public.stock_tags t join public.stock_tagged_units pc on pc.id = t.piece_id
                               where t.workspace_id = p_workspace_id and t.owner_kind = 'piece' and t.state = 'active'
                                 and coalesce(x.u ->> 'piece_id', '') = ''
                                 and t.code = public.stock_tag_normalize(x.u ->> 'tag'))) lot
                      from jsonb_array_elements(v_units) with ordinality x (u, ord)) p
             group by p.lot) g;
    return v_parts;
  end if;
  -- a lot-tracked item, no lot named: the lots on hand, the first to expire first
  v_left := v_qty;
  for b in
    select s.lot_id, s.quantity
      from public.stock_balances s
      join public.stock_lots l on l.id = s.lot_id
     where s.workspace_id = p_workspace_id and s.item_id = p_item_id and s.variant_id is not distinct from p_variant_id
       and s.location_id = p_from and s.quantity > 0 and not public.stock_lot_expired(l.id, v_today)
     order by l.expires_on nulls last, l.created_datetime, l.id
  loop
    exit when v_left <= 0;
    v_take := least(b.quantity, v_left);
    v_left := v_left - v_take;
    v_parts := v_parts || jsonb_build_array(jsonb_build_object(
      'quantity', trim_scale(v_take)::text, 'unit', v_item.inventory_unit, 'lot_id', b.lot_id));
  end loop;
  if v_left > 0 then
    raise exception 'not that much on hand at this place' using errcode = 'DKG03';
  end if;
  return v_parts;
end;
$fn$;
revoke execute on function public.counter_goods_parts(uuid, uuid, uuid, uuid, text, text, jsonb) from public, anon, authenticated;

-- ── finalize: each goods line names its movements and is frozen with what it took ──
-- restates 0894 (counter_receipt_finalize_v1, as patched by 0908)
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
  v_sess public.counter_till_sessions;
  v_gno int;
  v_line_id uuid;
  p jsonb;
  v_tracks jsonb := '[]'::jsonb;
begin
  v_me := public.counter_actor(p_workspace_id);
  if p_request_id is null or p_receipt_id is null or coalesce(jsonb_typeof(p_tenders), '') <> 'array' then
    -- #4436: refused with the counter's code for a receipt that misses its essentials (was a bare 22023)
    perform public.refuse('DKL02', null, 'a receipt is finalized with a request id, its revision and its tenders');
  end if;
  v_digest := md5(p_receipt_id::text || '|' || coalesce(p_expected_revision::text, '') || '|' || p_tenders::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'counter_finalize', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_rec from public.counter_receipts x where x.id = p_receipt_id and x.workspace_id = p_workspace_id for update;
  if v_rec.id is null or v_rec.state <> 'draft' or v_rec.kind <> 'sale' then
    raise exception 'this receipt is not an open draft' using errcode = 'DKL04';
  end if;
  if p_expected_revision is distinct from v_rec.revision then
    raise exception 'this receipt changed meanwhile' using errcode = 'DKL10';
  end if;
  -- the session of the sale, share-locked: a close (for update) waits for this transaction, and a session closed first refuses it
  if public.feature_effective(p_workspace_id, 'counterTillSessions') then
    select * into v_sess from public.counter_till_sessions s where s.id = v_rec.till_session_id for share;
    if v_sess.id is null or v_sess.state <> 'open' then
      raise exception 'open the till first' using errcode = 'DKL12',
        detail = jsonb_build_object('reason', case when v_sess.id is null then 'till_open_first' else 'closed' end, 'till_id', v_sess.till_id)::text;
    end if;
  end if;
  -- the country operation first: nothing is numbered and nothing is taken where it is not supported
  v_op := public.counter_require_operation(p_workspace_id, 'issue_receipt');
  if jsonb_array_length(p_tenders) > 0 then
    perform public.counter_require_operation(p_workspace_id, 'reconcile_tender');
  end if;
  if v_rec.financial_subject_id is null and coalesce(public.setting_value(p_workspace_id, 'counter.customerless_sales') #>> '{}', 'allowed') = 'refused' then
    raise exception 'this business names a customer on every sale' using errcode = 'DKL05';
  end if;
  if v_rec.source_ref <> '' then
    select * into v_other from public.counter_receipts o
     where o.workspace_id = p_workspace_id and o.source_kind = v_rec.source_kind and o.source_ref = v_rec.source_ref
       and o.state = 'finalized' and o.kind = 'sale';
    if v_other.id is not null then
      raise exception 'a receipt was already issued for this source' using errcode = 'DKL04',
        detail = jsonb_build_object('receipt_id', v_other.id, 'number', v_other.number)::text;
    end if;
  end if;
  v_tp := public.workspace_today(p_workspace_id);
  for l in select * from public.counter_receipt_lines x where x.receipt_id = v_rec.id order by x.line_no loop
    v_input := v_input || jsonb_build_array(l.frozen -> 'input');
  end loop;
  v_calc := public.counter_lines_of(p_workspace_id, v_input, v_rec.currency, v_rec.price_basis, v_tp);
  if jsonb_array_length(v_calc -> 'missing') > 0 then
    raise exception 'receipt_essentials_missing' using errcode = 'DKL02',
      detail = (select string_agg(x, ',') from jsonb_array_elements_text(v_calc -> 'missing') x);
  end if;
  v_total := (v_calc #>> '{totals,gross_minor}')::bigint;
  v_tax := (v_calc #>> '{totals,tax_minor}')::bigint;
  v_net := (v_calc #>> '{totals,net_minor}')::bigint;
  if v_total <= 0 then
    raise exception 'receipt_essentials_missing' using errcode = 'DKL02', detail = 'total_not_positive';
  end if;
  -- the tenders: the cash and other ones named here, each of its own part, and the card ones already accepted on this
  -- receipt (named by id), adding to the total exactly; an authorization still open (requested or unknown) is never
  -- passed over, a refused one is not paid
  if exists (select 1 from public.counter_tenders t where t.receipt_id = v_rec.id
                and (t.state in ('requested', 'unknown') or (t.state = 'accepted' and t.reconciliation = 'needed'))) then
    raise exception 'a card authorization of this sale is still open' using errcode = 'DKL06', detail = 'tender_open';
  end if;
  if jsonb_array_length(p_tenders) = 0 and not exists (select 1 from public.counter_tenders t where t.receipt_id = v_rec.id and t.state = 'accepted') then
    raise exception 'a sale is settled by its tenders' using errcode = 'DKL06', detail = 'tenders_missing';
  end if;
  v_named := array[]::uuid[];
  for v_t in select value from jsonb_array_elements(p_tenders) loop
    if v_t ? 'tender_id' then
      select * into v_tender from public.counter_tenders t
       where t.id = nullif(v_t ->> 'tender_id', '')::uuid and t.receipt_id = v_rec.id and t.workspace_id = p_workspace_id;
      if v_tender.id is null or v_tender.kind <> 'card' or v_tender.state <> 'accepted' or v_tender.reconciliation = 'needed' or v_tender.id = any (v_named) then
        raise exception 'this tender is not an accepted card tender of this sale' using errcode = 'DKL06', detail = 'tender_state';
      end if;
      v_named := v_named || v_tender.id;
      v_sum := v_sum + v_tender.amount_minor;
      continue;
    end if;
    v_kind := v_t ->> 'kind';
    if v_kind is null or v_kind not in ('cash', 'other') then
      raise exception 'this tender is not taken here' using errcode = 'DKL06', detail = 'tender_kind';
    end if;
    if coalesce(v_t ->> 'amount_minor', '') !~ '^[0-9]{1,12}$' or (v_t ->> 'amount_minor')::bigint <= 0 then
      raise exception 'this tender has no amount' using errcode = 'DKL06', detail = 'tender_amount';
    end if;
    v_sum := v_sum + (v_t ->> 'amount_minor')::bigint;
  end loop;
  -- an accepted card tender of this receipt that the caller did not name is still money taken: it counts
  v_sum := v_sum + coalesce((select sum(t.amount_minor) from public.counter_tenders t
                              where t.receipt_id = v_rec.id and t.state = 'accepted' and not (t.id = any (v_named))), 0);
  if v_sum <> v_total then
    raise exception 'the tenders do not add up to the total' using errcode = 'DKL06', detail = 'tender_sum';
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
  select coalesce(max(t.part), 0) into v_part from public.counter_tenders t where t.receipt_id = v_rec.id;
  for v_t in select value from jsonb_array_elements(p_tenders) loop
    if v_t ? 'tender_id' then continue; end if;
    v_part := v_part + 1;
    insert into public.counter_tenders (workspace_id, receipt_id, part, kind, amount_minor, state, request_id, resolved_at, recorded_by_member_id)
    values (p_workspace_id, v_rec.id, v_part, v_t ->> 'kind', (v_t ->> 'amount_minor')::bigint, 'accepted', p_request_id, now(), v_me);
  end loop;
  -- goods: the movements of each goods line through the one stock path, in this transaction and under this request id,
  -- linked to this receipt and to the line: a line that cannot leave (not enough, expired, a variant, a lot or the pieces
  -- to name) rolls the whole sale back, number included; issuing the receipt moves nothing else, and a replay answers
  -- without moving anything again. #4436: a lot-tracked line without a lot leaves from the lots on hand, one movement per lot.
  v_goods := '[]'::jsonb;
  v_gno := 0;
  for r in select value from jsonb_array_elements(v_calc -> 'lines') loop
    v_gno := v_gno + 1;
    if r #>> '{line,supply}' = 'goods' then
      if not public.feature_effective(p_workspace_id, 'stockManagement') then
        raise exception 'goods are not sold here: the goods ledger is off' using errcode = 'DKL07', detail = 'goods_off';
      end if;
      v_main := coalesce(nullif(r #>> '{input,from_location_id}', '')::uuid,
                         (select sl.id from public.stock_locations sl where sl.workspace_id = p_workspace_id and sl.code = 'MAIN' limit 1));
      if v_main is null then
        raise exception 'no place to take the goods from' using errcode = 'DKL07', detail = 'from_place';
      end if;
      select x.id into v_line_id from public.counter_receipt_lines x where x.receipt_id = v_rec.id and x.line_no = v_gno;
      for p in select value from jsonb_array_elements(public.counter_goods_parts(p_workspace_id, (r ->> 'item_id')::uuid,
                 nullif(r #>> '{input,variant_id}', '')::uuid, v_main, r #>> '{line,commercial,quantity}',
                 r #>> '{line,commercial,unit,code}', r -> 'input')) loop
        v_goods := v_goods || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
          'item_id', r ->> 'item_id', 'variant_id', nullif(r #>> '{input,variant_id}', ''),
          'quantity', p ->> 'quantity', 'unit', p ->> 'unit',
          'from', v_main, 'to', public.stock_place(p_workspace_id, 'customer'), 'lot_id', p ->> 'lot_id',
          'units', p -> 'units', 'counter_line_id', v_line_id)));
      end loop;
    end if;
  end loop;
  if jsonb_array_length(v_goods) > 0 then
    perform set_config('deskilo.counter_links', 'on', true);
    perform public.stock_apply_lines(p_workspace_id, v_me, p_request_id, v_goods, 'sale', now(),
                                     jsonb_build_object('counter_receipt_id', v_rec.id), 'generic');
    perform set_config('deskilo.counter_links', 'off', true);
    -- #4436: what each goods line took, frozen with it while the receipt is still a draft
    for l in select * from public.counter_receipt_lines x where x.receipt_id = v_rec.id and x.frozen ->> 'supply' = 'goods' order by x.line_no loop
      update public.counter_receipt_lines x
         set frozen = x.frozen || jsonb_build_object('tracks', public.stock_tracks_of(p_workspace_id,
               array(select m.id from public.stock_movements m
                      where m.workspace_id = p_workspace_id and m.counter_line_id = l.id and m.reason = 'sale')))
       where x.id = l.id
       returning * into l;
      v_tracks := v_tracks || jsonb_build_array(jsonb_build_object('line_no', l.line_no, 'line_id', l.id, 'tracks', l.frozen -> 'tracks'));
    end loop;
    v_frozen := jsonb_set(v_frozen, '{lines}',
      (select jsonb_agg(x.frozen - 'input' order by x.line_no) from public.counter_receipt_lines x where x.receipt_id = v_rec.id));
  end if;
  update public.counter_receipts set state = 'finalized', number = v_number, frozen = v_frozen, total_minor = v_total, tax_minor = v_tax,
         operation_id = v_op.id, fiscal_assumption = v_regime, finalized_by_member_id = v_me, finalized_at = now()
   where id = v_rec.id;
  v_result := jsonb_build_object('receipt_id', v_rec.id, 'number', v_number, 'currency', v_rec.currency,
    'totals', v_calc -> 'totals', 'tenders', (select count(*) from public.counter_tenders t where t.receipt_id = v_rec.id and t.state = 'accepted'),
    'lines', v_tracks, 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'counter_finalize', v_digest, v_result);
end;
$fn$;
revoke execute on function public.counter_receipt_finalize_v1(uuid, uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.counter_receipt_finalize_v1(uuid, uuid, uuid, int, jsonb) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(941);
