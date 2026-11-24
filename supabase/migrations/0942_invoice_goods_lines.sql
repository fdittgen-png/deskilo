-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (new functions; the standalone issuer and the quote's line check patched at asserted anchors; the issue, its preview
--  and the void restated whole; no table, no stored value moves)
--
-- #4433 (G18b, second of two files) -- goods sold on a customer invoice leave stock with a sale movement linked to the
-- invoice and its line. Until now the standalone issuer (0820) refused any line that was not a service (`general`) or
-- property, so goods were sold at the counter only (0894).
--
--   * A standalone line (and a quote line, which becomes one) may be goods: `supply` = `goods` and the stock item it
--     sells (`item_id`, with its `variant_id` where the item has variants). On a standalone draft it may also name a lot
--     (`lot_id`) and the pieces it sells (`units`, each a `tag` or a `piece_id`) of an item tracked piece by piece.
--     `standalone_invoice_goods_input` reads it: the goods ledger on (`goods_off`), an item of this business on sale and
--     kept in stock (`item`), its variant (`variant`), lot (`lot`), pieces (`units`) and a unit the item can be counted
--     in (`unit`). Its tax is the item's own VAT rate unless the line names one; it is computed as a supply in the
--     seller's country. Goods sold across a border (an intra-community supply, an export) are not interpreted by this
--     version and are refused (`goods_cross_border`), never invoiced as if they were domestic.
--   * The frozen line is marked goods (kind, supply) and keeps what it sells in `stock` (item, variant, lot, pieces).
--   * Issuing (`issue_standalone_invoice_v1`, and so the conversion of a quote) writes, in the issue's own transaction,
--     one `sale` per goods line through the one stock path (`stock_apply_lines`), from the place the setting
--     `stock.invoice_sale_place` names (0939) to the customer, linked to the invoice and the line, under a request id
--     made of the invoice and the line: the issue's own replay answers before anything moves, and nothing can move
--     twice. The lot is the one the line names, else the lot of the pieces it names, else the stock path's own choice
--     (`stock_take`: the earliest expiry first, a part per lot). What is not on hand follows the business's rule
--     (`stock.allow_negative`, an untracked item only); a refusal of the stock path rolls the issue back, number
--     included, and is answered as the line's missing fact (`line_<n>_stock_not_enough`, `_stock_pieces`, `_stock_lot`,
--     `_stock_lot_expired`, `_stock`), the way every other fact of the draft is.
--   * The preview runs the same posting in its rolled-back block, so a shortage is told before the issue.
--   * Voiding an invoice (the cancellation of an issued invoice) takes its goods back: one `return_in` per sale
--     movement of the invoice, from the customer to the place it left, with its lot and its pieces, linked to the
--     invoice and the line.
-- A monthly invoice carries no stock item and is unchanged.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0940: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

-- ── 1. a goods line, read ───────────────────────────────────────────────
-- Returns {input, missing}: the line with its tax rate taken from the item where it names none, or what it lacks.
create or replace function public.standalone_invoice_goods_input(
  p_workspace_id uuid, p_line jsonb, p_index integer, p_seller_country text, p_buyer_country text, p_treatment text)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_pre text := 'line_' || p_index || '_';
  v_uuid constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
  v_missing text[] := '{}';
  v_item public.services;
  v_var uuid;
  v_units jsonb := p_line -> 'units';
  v_in jsonb := p_line;
begin
  if not public.feature_effective(p_workspace_id, 'stockManagement') then
    return jsonb_build_object('input', null, 'missing', jsonb_build_array(v_pre || 'goods_off'));
  end if;
  if coalesce(p_line ->> 'item_id', '') ~ v_uuid then
    select * into v_item from public.services s
     where s.id = (p_line ->> 'item_id')::uuid and s.workspace_id = p_workspace_id and s.active and s.stockable;
  end if;
  if v_item.id is null then
    return jsonb_build_object('input', null, 'missing', jsonb_build_array(v_pre || 'item'));
  end if;
  -- an intra-community supply of goods or an export has its own rules: not read as a domestic sale
  if upper(btrim(coalesce(p_seller_country, ''))) <> upper(btrim(coalesce(p_buyer_country, '')))
     or coalesce(p_treatment, 'auto') not in ('auto', 'domestic') then
    v_missing := v_missing || (v_pre || 'goods_cross_border');
  end if;
  if nullif(p_line ->> 'variant_id', '') is not null then
    if (p_line ->> 'variant_id') !~ v_uuid
       or not exists (select 1 from public.item_variants x
                       where x.id = (p_line ->> 'variant_id')::uuid and x.workspace_id = p_workspace_id
                         and x.item_id = v_item.id and x.active) then
      v_missing := v_missing || (v_pre || 'variant');
    else
      v_var := (p_line ->> 'variant_id')::uuid;
    end if;
  elsif exists (select 1 from public.item_variants x where x.item_id = v_item.id and x.active) then
    v_missing := v_missing || (v_pre || 'variant');
  end if;
  if nullif(p_line ->> 'lot_id', '') is not null
     and ((p_line ->> 'lot_id') !~ v_uuid
          or not exists (select 1 from public.stock_lots x
                          where x.id = (p_line ->> 'lot_id')::uuid and x.workspace_id = p_workspace_id
                            and x.item_id = v_item.id and x.variant_id is not distinct from v_var)) then
    v_missing := v_missing || (v_pre || 'lot');
  end if;
  if v_units is not null
     and (jsonb_typeof(v_units) <> 'array' or jsonb_array_length(v_units) not between 1 and 200
          or exists (select 1 from jsonb_array_elements(v_units) x
                      where jsonb_typeof(x) <> 'object'
                         or (coalesce(x ->> 'piece_id', '') !~ v_uuid and public.stock_tag_normalize(x ->> 'tag') is null))) then
    v_missing := v_missing || (v_pre || 'units');
  end if;
  begin
    perform public.stock_to_inventory(v_item.id, nullif(p_line #>> '{unit,code}', ''), 1);
  exception when others then
    v_missing := v_missing || (v_pre || 'unit');
  end;
  if cardinality(v_missing) > 0 then
    return jsonb_build_object('input', null, 'missing', to_jsonb(v_missing));
  end if;
  if nullif(p_line ->> 'vat_rate_id', '') is null and v_item.vat_rate_id is not null then
    v_in := v_in || jsonb_build_object('vat_rate_id', v_item.vat_rate_id);
  end if;
  return jsonb_build_object('input', v_in, 'missing', '[]'::jsonb);
end
$fn$;
revoke execute on function public.standalone_invoice_goods_input(uuid, jsonb, integer, text, text, text)
  from public, anon, authenticated;

-- A frozen line marked goods, with what it sells.
create or replace function public.standalone_invoice_goods_mark(p_line jsonb, p_input jsonb)
returns jsonb language sql immutable set search_path = public as $fn$
  select jsonb_set(jsonb_set(jsonb_set(p_line, '{kind}', '"goods"'), '{supply}', '"goods"'), '{commercial,supply}', '"goods"')
         || jsonb_build_object('stock', jsonb_strip_nulls(jsonb_build_object(
              'item_id', p_input ->> 'item_id',
              'variant_id', nullif(p_input ->> 'variant_id', ''),
              'lot_id', nullif(p_input ->> 'lot_id', ''),
              'units', p_input -> 'units')))
$fn$;
revoke execute on function public.standalone_invoice_goods_mark(jsonb, jsonb) from public, anon, authenticated;

-- ── 2. the standalone issuer reads goods lines ──────────────────────────
-- restates 0820 (standalone_invoice_issue_core, as patched by 0822 and 0850), by anchored patch
do $patch$
declare
  v_def text := pg_get_functiondef('public.standalone_invoice_issue_core(uuid, public.members, public.standalone_invoice_drafts)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    $a$  v_reverse_charge boolean;
begin$a$,
    $b$  v_reverse_charge boolean;
  v_goods jsonb;
begin$b$, 'the declarations');
  v_def := pg_temp.anchor_once(v_def,
    $a$    v_supply := coalesce(v_in ->> 'supply', '');
    v_pct := 0;
$a$,
    $b$    v_supply := coalesce(v_in ->> 'supply', '');
    v_pct := 0;
    -- #4433: a goods line names a stock item of this business; it leaves stock when the invoice is issued
    if v_supply = 'goods' then
      v_goods := public.standalone_invoice_goods_input(p_workspace_id, v_in, v_idx, v_seller_country,
                                                       v_buyer_country, v_treatment);
      if jsonb_array_length(v_goods -> 'missing') > 0 then
        v_missing := v_missing || array(select jsonb_array_elements_text(v_goods -> 'missing'));
        continue;
      end if;
      v_in := v_goods -> 'input';
    end if;
$b$, 'the start of the line loop');
  v_def := pg_temp.anchor_once(v_def,
    $a$    v_cat := case when v_supply in ('general', 'property') then
                public.supply_vat_category_for(
                  p_workspace_id, v_tp, v_treatment, v_supply, v_regime,$a$,
    $b$    v_cat := case when v_supply in ('general', 'property', 'goods') then
                public.supply_vat_category_for(
                  p_workspace_id, v_tp, v_treatment,
                  case when v_supply = 'goods' then 'general' else v_supply end, v_regime,$b$, 'the tax category of a line');
  v_def := pg_temp.anchor_once(v_def,
    $a$    v_out := public.standalone_invoice_line_v1(
      v_in, v_idx,$a$,
    $b$    v_out := public.standalone_invoice_line_v1(
      case when v_supply = 'goods' then v_in || jsonb_build_object('supply', 'general') else v_in end, v_idx,$b$,
    'the line computation');
  v_def := pg_temp.anchor_once(v_def,
    $a$      v_lines := v_lines || jsonb_build_array(v_out -> 'line');$a$,
    $b$      if v_supply = 'goods' then
        v_out := jsonb_set(v_out, '{line}', public.standalone_invoice_goods_mark(v_out -> 'line', v_in));
      end if;
      v_lines := v_lines || jsonb_build_array(v_out -> 'line');$b$, 'the frozen line');
  execute v_def;
end
$patch$;

-- ── 3. a quote line may be goods ────────────────────────────────────────
-- restates 0828 (customer_quote_line_clean), by anchored patch
do $patch$
declare
  v_def text := pg_get_functiondef('public.customer_quote_line_clean(jsonb, integer)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    $a$  if v_supply not in ('general', 'property') then v_missing := v_missing || (v_pre || 'supply'); end if;$a$,
    $b$  if v_supply not in ('general', 'property', 'goods') then v_missing := v_missing || (v_pre || 'supply'); end if;
  -- #4433: a goods line names its stock item (and its variant); what is on hand is read when it is invoiced
  if v_supply = 'goods' and coalesce(p_line ->> 'item_id', '') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    v_missing := v_missing || (v_pre || 'item');
  end if;
  if v_supply = 'goods' and nullif(p_line ->> 'variant_id', '') is not null
     and (p_line ->> 'variant_id') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    v_missing := v_missing || (v_pre || 'variant');
  end if;$b$, 'the supply check of a quote line');
  v_def := pg_temp.anchor_once(v_def,
    $a$    'vat_rate_id', v_rate)));$a$,
    $b$    'vat_rate_id', v_rate,
    'item_id', case when v_supply = 'goods' then p_line ->> 'item_id' end,
    'variant_id', case when v_supply = 'goods' then nullif(p_line ->> 'variant_id', '') end)));$b$,
    'the stored quote line');
  execute v_def;
end
$patch$;

-- ── 4. the goods of an issued invoice leave stock ───────────────────────
-- One sale per goods line, through the one stock path, in the caller's transaction. A refusal of the stock path is
-- answered as the line's missing fact (DKI01), so the issue rolls back and the preview names it.
create or replace function public.standalone_invoice_goods_post(p_workspace_id uuid, p_actor uuid, p_invoice_id uuid)
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  v_inv public.invoices;
  v_code text;
  v_from uuid;
  v_to uuid;
  l jsonb;
  v_idx integer := 0;
  v_count integer := 0;
  v_item public.services;
  v_var uuid;
  v_lot uuid;
  v_qty numeric;
  v_inv_qty numeric;
  v_unit text;
  v_line_id text;
  v_units jsonb;
  v_base jsonb;
  v_parts jsonb;
  t record;
  v_state text;
  v_detail text;
  v_fact text;
begin
  select * into v_inv from public.invoices where id = p_invoice_id and workspace_id = p_workspace_id;
  if v_inv.id is null
     or not exists (select 1 from jsonb_array_elements(v_inv.lines) x where x ->> 'supply' = 'goods') then
    return 0;
  end if;
  if not public.feature_effective(p_workspace_id, 'stockManagement') then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'goods_off';
  end if;
  -- the place the business sells from: a place that holds stock and is in use
  v_code := coalesce(nullif(btrim(public.setting_value(p_workspace_id, 'stock.invoice_sale_place') #>> '{}'), ''), 'MAIN');
  select sl.id into v_from from public.stock_locations sl
   where sl.workspace_id = p_workspace_id and sl.code = v_code and sl.active
     and not public.stock_place_is_virtual(sl.id)
     and sl.id is distinct from public.stock_transit_place(p_workspace_id)
   order by sl.created_datetime limit 1;
  v_to := public.stock_place(p_workspace_id, 'customer');
  if v_from is null or v_to is null then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'stock_sale_place';
  end if;
  -- every item of the invoice locked first, in id order, as the stock path does: opposing requests cannot deadlock
  perform 1 from public.services s
   where s.workspace_id = p_workspace_id
     and s.id in (select (x #>> '{stock,item_id}')::uuid from jsonb_array_elements(v_inv.lines) x
                   where x ->> 'supply' = 'goods')
   order by s.id for update;
  perform set_config('deskilo.invoice_links', 'on', true);
  for l in select e from jsonb_array_elements(v_inv.lines) e loop
    v_idx := v_idx + 1;
    continue when coalesce(l ->> 'supply', '') <> 'goods';
    select * into v_item from public.services
     where id = (l #>> '{stock,item_id}')::uuid and workspace_id = p_workspace_id;
    v_var := nullif(l #>> '{stock,variant_id}', '')::uuid;
    v_lot := nullif(l #>> '{stock,lot_id}', '')::uuid;
    v_units := l #> '{stock,units}';
    v_qty := (l #>> '{commercial,quantity}')::numeric;
    v_unit := nullif(l #>> '{commercial,unit,code}', '');
    v_line_id := l #>> '{commercial,line_id}';
    v_base := jsonb_strip_nulls(jsonb_build_object('item_id', v_item.id, 'variant_id', v_var, 'from', v_from,
                                                   'to', v_to, 'invoice_line_id', v_line_id));
    begin
      v_parts := '[]'::jsonb;
      if v_item.tracking = 'none' or v_lot is not null then
        v_parts := jsonb_build_array(v_base || jsonb_strip_nulls(jsonb_build_object(
          'lot_id', v_lot, 'quantity', trim_scale(v_qty)::text, 'unit', v_unit, 'units', v_units)));
      else
        v_inv_qty := public.stock_to_inventory(v_item.id, v_unit, v_qty);
        if jsonb_typeof(v_units) = 'array' then
          -- the pieces named: each part is the lot its pieces carry
          if jsonb_array_length(v_units) <> v_inv_qty then
            raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'line_' || v_idx || '_stock_pieces';
          end if;
          select coalesce(jsonb_agg(v_base || jsonb_build_object('lot_id', g.lot_id, 'quantity', g.n::text,
                                    'unit', v_item.inventory_unit, 'units', g.units) order by g.first), '[]'::jsonb),
                 bool_or(g.lot_id is null)
            into v_parts, v_fact
            from (select p.lot_id, count(*) n, jsonb_agg(u.value order by u.o) units, min(u.o) first
                    from jsonb_array_elements(v_units) with ordinality u (value, o)
                    left join lateral (
                      select tu.lot_id from public.stock_tagged_units tu
                       where tu.workspace_id = p_workspace_id and tu.item_id = v_item.id
                         and tu.id = coalesce(
                               case when coalesce(u.value ->> 'piece_id', '') <> '' then (u.value ->> 'piece_id')::uuid end,
                               (select tg.piece_id from public.stock_tags tg
                                 where tg.workspace_id = p_workspace_id and tg.state = 'active' and tg.owner_kind = 'piece'
                                   and tg.code = public.stock_tag_normalize(u.value ->> 'tag')))) p on true
                   group by p.lot_id) g;
          if v_fact::boolean then
            raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'line_' || v_idx || '_stock_pieces';
          end if;
        else
          -- the stock path's own choice: the earliest expiry first, a part per lot
          for t in select * from public.stock_take(p_workspace_id, v_item.id, v_from, v_inv_qty, v_var) loop
            if t.lot_id is null then
              raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'line_' || v_idx || '_stock_not_enough';
            end if;
            v_parts := v_parts || jsonb_build_array(v_base || jsonb_build_object(
              'lot_id', t.lot_id, 'quantity', trim_scale(t.quantity)::text, 'unit', v_item.inventory_unit));
          end loop;
        end if;
      end if;
      perform public.stock_apply_lines(p_workspace_id, p_actor,
        md5('invoice_sale:' || p_invoice_id::text || ':' || v_line_id)::uuid, v_parts, 'sale', now(),
        jsonb_build_object('invoice_id', p_invoice_id), 'generic');
    exception when others then
      get stacked diagnostics v_state = returned_sqlstate, v_detail = pg_exception_detail;
      if v_state = 'DKI01' then
        raise;
      end if;
      v_fact := case
        when v_state = 'DKG03' then 'stock_not_enough'
        when v_state in ('DKG22', 'DKG23', 'DKG25', 'DKG26') then 'stock_pieces'
        when v_state = 'DKG06' then 'stock_lot'
        when v_state = 'DKG12' then 'variant'
        when v_state = 'DKG02' then 'unit'
        when v_state = 'DKG11' and coalesce(v_detail, '') like '%lot_expired%' then 'stock_lot_expired'
        when v_state = 'DKG11' and coalesce(v_detail, '') like '%units%' then 'stock_pieces'
        when v_state in ('DKG04', 'DKG05', 'DKG07', 'DKG11') then 'stock'
        end;
      if v_fact is null then
        raise;
      end if;
      raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'line_' || v_idx || '_' || v_fact;
    end;
    v_count := v_count + 1;
  end loop;
  perform set_config('deskilo.invoice_links', 'off', true);
  return v_count;
end
$fn$;
revoke execute on function public.standalone_invoice_goods_post(uuid, uuid, uuid) from public, anon, authenticated;

-- ── 5. a voided invoice takes its goods back ────────────────────────────
-- One return per sale the invoicing path wrote for the invoice: from the customer to the place it left, its lot and
-- its pieces, linked to the invoice and the line. The stock path's 'return' mode writes exactly that.
create or replace function public.invoice_goods_return(p_workspace_id uuid, p_actor uuid, p_invoice_id uuid)
returns integer language plpgsql security definer set search_path = public as $fn$
declare
  v_lines jsonb;
  v_tags boolean := public.feature_effective(p_workspace_id, 'stockTags');
begin
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'item_id', m.item_id, 'variant_id', m.variant_id, 'lot_id', m.lot_id,
           'from', m.to_location_id, 'to', m.from_location_id,
           'quantity', trim_scale(m.quantity)::text, 'line_no', m.rn, 'expired_ack', true,
           'invoice_line_id', m.invoice_line_id,
           'units', case when v_tags then (select jsonb_agg(jsonb_build_object('piece_id', mu.unit_id) order by mu.unit_id)
                                              from public.stock_movement_units mu where mu.movement_id = m.id) end))
           order by m.rn), '[]'::jsonb)
    into v_lines
    from (select x.*, row_number() over (order by x.request_id, x.line_no, x.part) rn
            from public.stock_movements x
           where x.workspace_id = p_workspace_id and x.invoice_id = p_invoice_id
             and x.reason = 'sale' and x.invoice_line_id is not null) m;
  if jsonb_array_length(v_lines) = 0 then
    return 0;
  end if;
  perform set_config('deskilo.invoice_links', 'on', true);
  perform public.stock_apply_lines(p_workspace_id, p_actor, md5('invoice_return:' || p_invoice_id::text)::uuid,
    v_lines, 'return_in', now(), jsonb_build_object('invoice_id', p_invoice_id), 'return');
  perform set_config('deskilo.invoice_links', 'off', true);
  return jsonb_array_length(v_lines);
end
$fn$;
revoke execute on function public.invoice_goods_return(uuid, uuid, uuid) from public, anon, authenticated;

-- ── 6. the commands ─────────────────────────────────────────────────────
-- restates 0820 (as patched by 0826): the preview runs the posting of the goods in its rolled-back block
create or replace function public.preview_standalone_invoice_v1(p_workspace_id uuid, p_draft_id uuid, p_revision integer)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_draft public.standalone_invoice_drafts;
  v_id uuid;
  v_detail text;
  v_inv public.invoices;
begin
  v_actor := public.issuing_member(p_workspace_id);

  if not public.feature_effective(p_workspace_id, 'standaloneInvoicing') then
    raise exception 'invoice_essentials_missing'
      using errcode = 'DKI01', detail = 'invoice_feature_disabled';
  end if;
  select * into v_draft from public.standalone_invoice_drafts d
   where d.id = p_draft_id and d.workspace_id = p_workspace_id;
  if v_draft.id is null then
    return jsonb_build_object('missing', jsonb_build_array('draft_unknown'), 'preview', null);
  end if;
  if v_draft.revision is distinct from p_revision then
    return jsonb_build_object('missing', jsonb_build_array('draft_stale'), 'preview', null);
  end if;
  begin
    v_id := public.standalone_invoice_issue_core(p_workspace_id, v_actor, v_draft);
    perform public.standalone_invoice_goods_post(p_workspace_id, v_actor.id, v_id);
    select * into v_inv from public.invoices where id = v_id;
    raise exception using message = 'dry run', errcode = 'DKI02', detail = jsonb_build_object(
      'lines', v_inv.lines, 'vat_totals', v_inv.vat_totals, 'parties', v_inv.parties,
      'total_cents', v_inv.total_cents, 'currency', v_inv.currency,
      'service_date', v_inv.service_date, 'due_on', v_inv.due_on)::text;
  exception
    when sqlstate 'DKI01' then
      get stacked diagnostics v_detail = pg_exception_detail;
      return jsonb_build_object('missing', to_jsonb(string_to_array(v_detail, ',')), 'preview', null);
    when sqlstate 'DKI02' then
      get stacked diagnostics v_detail = pg_exception_detail;
      return jsonb_build_object('missing', '[]'::jsonb, 'preview', v_detail::jsonb);
  end;
end $fn$;

-- restates 0820 (as patched by 0826): the goods leave stock in the issue's own transaction
create or replace function public.issue_standalone_invoice_v1(
  p_workspace_id uuid, p_draft_id uuid, p_revision integer, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_draft public.standalone_invoice_drafts;
  v_digest text;
  v_id uuid;
  v_number text;
begin
  v_actor := public.issuing_member(p_workspace_id);

  if not public.feature_effective(p_workspace_id, 'standaloneInvoicing') then
    raise exception 'invoice_essentials_missing'
      using errcode = 'DKI01', detail = 'invoice_feature_disabled';
  end if;
  if p_request_id is null then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'request_id_required';
  end if;
  v_digest := encode(sha256(convert_to(jsonb_build_object(
    'draft_id', p_draft_id, 'revision', p_revision)::text, 'UTF8')), 'hex');
  v_id := public.financial_receipt_replay_v1(p_workspace_id, v_actor.id, p_request_id,
    'standalone_invoice_issue', v_digest);
  if v_id is not null then
    select number into v_number from public.invoices where id = v_id;
    return jsonb_build_object('invoice_id', v_id, 'number', v_number, 'replayed', true);
  end if;
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  select * into v_draft from public.standalone_invoice_drafts d
   where d.id = p_draft_id and d.workspace_id = p_workspace_id for update;
  if v_draft.id is null then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'draft_unknown';
  end if;
  if v_draft.revision is distinct from p_revision then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'draft_stale';
  end if;
  v_id := public.standalone_invoice_issue_core(p_workspace_id, v_actor, v_draft);
  perform public.standalone_invoice_goods_post(p_workspace_id, v_actor.id, v_id);
  insert into public.financial_command_receipts
    (workspace_id, actor_member_id, request_id, command_kind, payload_digest, state, invoice_id)
  values (p_workspace_id, v_actor.id, p_request_id, 'standalone_invoice_issue', v_digest, 'applied', v_id);
  select number into v_number from public.invoices where id = v_id;
  return jsonb_build_object('invoice_id', v_id, 'number', v_number, 'replayed', false);
end $fn$;

-- restates 0144 (as patched by 0617 and 0742): a voided invoice takes back the goods it sold
create or replace function public.void_invoice(p_invoice_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_invoice public.invoices;
  v_actor public.members;
  v_actor_name text;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'not a member'; end if;
  v_actor := public.issuing_member(v_invoice.workspace_id);
  if exists (select 1 from public.invoice_matches
              where invoice_id = p_invoice_id) then
    raise exception 'invoice is matched' using errcode = 'DKI04';
  end if;
  if v_invoice.settled_by_invoice_id is not null then
    raise exception 'invoice is settled';
  end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice already voided';
  end if;
  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;
  update public.invoices
     set voided_at = now(), voided_by_name = v_actor_name
   where id = p_invoice_id;
  if v_invoice.kind = 'settlement' then
    update public.invoices set settled_by_invoice_id = null
      where settled_by_invoice_id = p_invoice_id;
  end if;
  -- #4433: the goods it sold come back to the place they left
  perform public.invoice_goods_return(v_invoice.workspace_id, v_actor.id, p_invoice_id);
end;
$fn$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(942);
