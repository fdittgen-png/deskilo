-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
--
-- #4478 -- a deposit returned at the till: the deposit item, at a quantity above zero, taken off the sale. Reviewed on the
-- issue (the owner of the invoice line contract): standalone_invoice_line_v1 is unchanged; the counter path computes the
-- returned line as the sale of the same deposit and negates every amount it carries.
--
--   constraints              a receipt line's amounts are >= 0, or <= 0 when its frozen kind is deposit_return (one check,
--                            both ways); the receipt's total is >= 0 once finalized (a draft may dip below while deposits
--                            are rung up first) and its tax is the finalize's to bound (a deposit taxed where the sale is not
--                            makes it negative). Looser: no row can fail them.
--   counter_lines_of         restated whole from its live definition (0894): a line `returned: true` must be a deposit
--                            item of an item or group, untracked, with no price, reason or discount of its own, its input
--                            rebuilt from the item (only the item, quantity and line id are the body's); kind is the
--                            server's (a client's `kind` is refused); the amounts are negated after the compute; the cap is
--                            on each line's absolute amount and on what is sold.
--   counter_line_prices      restated from 0965: a returned deposit needs the right to change a price, never offline.
--   finalize                 the tax within the total; a returned deposit comes back into stock (return_in, customer ->
--                            MAIN) under a request id derived from the sale's; no tracks are frozen for it.
--   counter_receipt_correct_v1   a returned line is corrected negated, capped by its absolute amount, keeping its kind.
--   counter_goods_return_v1  a returned deposit is not taken back again.
--   counter_day_close_v1     the day's returned deposits as their own figure.

alter table public.counter_receipts drop constraint counter_receipts_tax_minor_check;
-- a draft follows the basket as it is rung up: deposits brought back before anything is sold make it negative for a while;
-- a finalized receipt is never below zero (the finalize refuses a total <= 0)
alter table public.counter_receipts drop constraint counter_receipts_total_minor_check;
alter table public.counter_receipts add constraint counter_receipts_total_minor_sign
  check (total_minor is null or total_minor >= 0 or state = 'draft') not valid;
alter table public.counter_receipts validate constraint counter_receipts_total_minor_sign;
alter table public.counter_receipt_lines drop constraint counter_receipt_lines_net_minor_check;
alter table public.counter_receipt_lines drop constraint counter_receipt_lines_tax_minor_check;
alter table public.counter_receipt_lines drop constraint counter_receipt_lines_gross_minor_check;
alter table public.counter_receipt_lines add constraint counter_receipt_lines_amount_sign check (
  (frozen ->> 'kind' is distinct from 'deposit_return' and net_minor >= 0 and tax_minor >= 0 and gross_minor >= 0)
  or (frozen ->> 'kind' = 'deposit_return' and net_minor <= 0 and tax_minor <= 0 and gross_minor <= 0)) not valid;
alter table public.counter_receipt_lines validate constraint counter_receipt_lines_amount_sign;

-- restates 0894: the live definition (pg_get_functiondef on dev at schema 968), a returned deposit's rules added
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
  v_sold bigint := 0;
  v_ret boolean;
  v_line jsonb;
  v_g bigint;
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
    v_ret := v_in ->> 'returned' = 'true';
    begin v_item_id := nullif(v_in ->> 'item_id', '')::uuid; exception when others then v_item_id := null; v_missing := v_missing || ('line_' || v_idx || '_item'); continue; end;
    if v_item_id is not null then
      select * into v_item from public.services s where s.id = v_item_id and s.workspace_id = p_workspace_id and s.active;
      if v_item.id is null then
        v_missing := v_missing || ('line_' || v_idx || '_item');
        continue;
      end if;
      -- #4478: a returned deposit is a deposit item the business sells with an item or a group, at its own price, never
      -- a tracked one (the till cannot name its lot or tag); the server decides it, never the client's word
      if v_ret then
        if not exists (select 1 from public.services s where s.workspace_id = p_workspace_id and s.active and s.deposit_item_id = v_item.id)
           and not exists (select 1 from public.item_groups g where g.workspace_id = p_workspace_id and g.deposit_item_id = v_item.id) then
          v_missing := v_missing || ('line_' || v_idx || '_returned');
          continue;
        end if;
        -- its price is the deposit item's: the one this function filled in, read again by the finalize, and no other
        if (coalesce(e ->> 'unit_price', '') <> '' and e ->> 'unit_price' <> trim_scale(v_item.price_cents::numeric / (10::numeric ^ v_digits))::text)
           or coalesce(e ->> 'discount_percent', '') <> '' or coalesce(e ->> 'price_reason', '') <> '' then
          v_missing := v_missing || ('line_' || v_idx || '_returned_price');
          continue;
        end if;
        if coalesce(nullif(v_item.tracking, ''), (select g.tracking from public.item_groups g where g.id = v_item.group_id), 'none') <> 'none'
           or coalesce(v_item.tag_mode, 'none') not in ('', 'none') then
          v_missing := v_missing || ('line_' || v_idx || '_returned_tracked');
          continue;
        end if;
        -- only the item, its quantity and the line's own id come from the body: the deposit's price, unit, base quantity,
        -- rate and supply are the item's, filled below as for any line, so nothing sent can enlarge what is handed back
        v_in := jsonb_strip_nulls(jsonb_build_object('item_id', v_in -> 'item_id', 'quantity', v_in -> 'quantity', 'returned', true,
                                                     'line_id', v_in -> 'line_id'));
      elsif v_in ->> 'kind' = 'deposit_return' then
        v_missing := v_missing || ('line_' || v_idx || '_kind');
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
      -- a stockable item is goods, and only goods: it is never frozen as a service while its stock stays untouched
      if v_item.stockable and coalesce(v_in ->> 'supply', '') not in ('', 'goods') then
        v_missing := v_missing || ('line_' || v_idx || '_supply');
        continue;
      end if;
      if coalesce(v_in ->> 'supply', '') = '' then
        v_in := v_in || jsonb_build_object('supply', case when v_item.stockable then 'goods' else 'general' end);
      end if;
    end if;
    if v_ret and v_item.id is null then
      v_missing := v_missing || ('line_' || v_idx || '_returned');
      continue;
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
    v_line := v_out -> 'line';
    -- #4478: a returned deposit is computed as the sale of the same deposit, then every amount it carries is negated: it
    -- is exactly the opposite of that sale, and the finalize recomputes the same
    if v_ret then
      v_line := jsonb_set(jsonb_set(jsonb_set(jsonb_set(v_line,
        '{commercial,amounts,net_minor}', to_jsonb((-(v_line #>> '{commercial,amounts,net_minor}')::bigint)::text)),
        '{commercial,amounts,tax_minor}', to_jsonb((-(v_line #>> '{commercial,amounts,tax_minor}')::bigint)::text)),
        '{commercial,amounts,gross_minor}', to_jsonb((-(v_line #>> '{commercial,amounts,gross_minor}')::bigint)::text)),
        '{amount_cents}', to_jsonb(-(v_line ->> 'amount_cents')::bigint))
        || jsonb_build_object('kind', 'deposit_return', 'returned', true);
    end if;
    v_g := (v_line #>> '{commercial,amounts,gross_minor}')::bigint;
    if abs(v_g) > 2000000000 then
      v_missing := v_missing || ('line_' || v_idx || '_amount');
      continue;
    end if;
    v_rows := v_rows || jsonb_build_array(jsonb_build_object('input', v_in, 'line', v_line, 'item_id', v_item_id,
                                                              'variant_id', nullif(v_in ->> 'variant_id', '')));
    v_net := v_net + (v_line #>> '{commercial,amounts,net_minor}')::bigint;
    v_tax := v_tax + (v_line #>> '{commercial,amounts,tax_minor}')::bigint;
    v_gross := v_gross + v_g;
    if v_g > 0 then v_sold := v_sold + v_g; end if;
  end loop;
  -- the cap holds on what is sold, not on what is left once the returns are taken off
  if v_sold > 2000000000 then v_missing := v_missing || 'total_amount'::text; end if;
  return jsonb_build_object('lines', v_rows, 'missing', to_jsonb(v_missing),
    'totals', jsonb_build_object('net_minor', v_net::text, 'tax_minor', v_tax::text, 'gross_minor', v_gross::text, 'currency', p_currency));
end;
$fn$;
revoke execute on function public.counter_lines_of(uuid, jsonb, text, text, date) from public, anon, authenticated;

-- restates 0965: the live definition, a returned deposit's rules added before the price rules, nothing else changed
create or replace function public.counter_line_prices(p_workspace_id uuid, p_kind text, p_lines jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  e jsonb;
  v_out jsonb := '[]'::jsonb;
  v_item public.services;
  v_item_id uuid;
  v_digits int := public.currency_minor_digits((select w.currency_code from public.workspaces w where w.id = p_workspace_id));
  v_scale numeric;
  v_list numeric;
  v_price numeric;
  v_base numeric;
  v_pct numeric;
  v_max int := coalesce((public.setting_value(p_workspace_id, 'counter.max_discount_percent') #>> '{}')::int, 0);
  v_tolerance int := coalesce((public.setting_value(p_workspace_id, 'counter.offline_price_tolerance_percent') #>> '{}')::int, 0);
  v_reason text;
  -- the offline tolerance holds only for the server's own sync (0944), which marks its transaction; a body's word is not enough
  v_offline boolean := p_kind = 'offline_till' and coalesce(current_setting('deskilo.counter_offline_sync', true), '') = 'on';
begin
  if coalesce(jsonb_typeof(p_lines), '') <> 'array' then
    return p_lines;   -- counter_lines_of names what is missing
  end if;
  v_scale := 10::numeric ^ coalesce(v_digits, 2);
  for e in select value from jsonb_array_elements(p_lines) loop
    if jsonb_typeof(e) <> 'object' then
      v_out := v_out || jsonb_build_array(e);
      continue;
    end if;
    v_item := null;
    begin v_item_id := nullif(e ->> 'item_id', '')::uuid; exception when invalid_text_representation then v_item_id := null; end;
    if v_item_id is not null then
      select * into v_item from public.services s where s.id = v_item_id and s.workspace_id = p_workspace_id and s.active;
    end if;
    v_list := case when v_item.id is not null then v_item.price_cents::numeric / v_scale end;
    -- #4478: a returned deposit is money leaving the sale: the right to change a price, never offline; its price is the
    -- deposit item's, and counter_lines_of refuses any other
    if e ->> 'returned' = 'true' then
      if v_offline or p_kind = 'offline_till' then
        perform public.refuse('DKL02', '{"reason": "deposit_return_offline"}'::jsonb, 'a deposit is not returned offline');
      end if;
      if not public.has_permission(p_workspace_id, 'overrideTillPrice') then
        perform public.refuse('DKN01', '{"reason": "deposit_return"}'::jsonb, 'not allowed to return a deposit at the till');
      end if;
      v_out := v_out || jsonb_build_array(e);
      continue;
    end if;
    if coalesce(e ->> 'discount_percent', '') <> '' then
      if coalesce(e ->> 'unit_price', '') <> '' then
        perform public.refuse('DKL02', '{"reason": "price_and_discount"}'::jsonb, 'a till line takes a discount or a price, not both');
      end if;
      if v_list is null then
        perform public.refuse('DKL02', '{"reason": "discount"}'::jsonb, 'a discount is taken off an item''s price');
      end if;
      if (e ->> 'discount_percent') !~ '^[0-9]{1,3}(\.[0-9]{1,2})?$' then
        perform public.refuse('DKL02', '{"reason": "discount"}'::jsonb, 'a discount is a percentage');
      end if;
      v_pct := (e ->> 'discount_percent')::numeric;
      if v_pct <= 0 or v_pct > 100 then
        perform public.refuse('DKL02', '{"reason": "discount"}'::jsonb, 'a discount is a percentage');
      end if;
      if v_pct > v_max then
        perform public.refuse('DKN01', jsonb_build_object('reason', 'discount_limit', 'max', v_max), 'this discount is beyond what the business allows');
      end if;
      e := e || jsonb_build_object(
        'unit_price', trim_scale(round(v_item.price_cents * (100 - v_pct) / 100) / v_scale)::text,
        'base_quantity', '1',
        'list_price', trim_scale(v_list)::text);
    else
      -- the price one base unit sells at: the one sent, or the item's, over the base quantity sent (absent reads 1)
      begin
        v_base := coalesce(nullif(e ->> 'base_quantity', ''), '1')::numeric;
        v_price := case when v_base > 0 then coalesce(nullif(e ->> 'unit_price', '')::numeric, v_list) / v_base end;
      exception when invalid_text_representation or numeric_value_out_of_range or division_by_zero then
        v_price := null;   -- counter_lines_of refuses a price or a base quantity it cannot read
      end;
      if v_price is not null and (v_list is null or v_price <> v_list) then
        if v_offline and v_list is not null and v_list > 0 and abs(v_price - v_list) * 100 <= v_tolerance * v_list then
          null;   -- the offline till sold at the price it held, within the business's tolerance
        else
          if not public.has_permission(p_workspace_id, 'overrideTillPrice') then
            perform public.refuse('DKN01', '{"reason": "price"}'::jsonb, 'not allowed to change a price at the till');
          end if;
          -- an item's price changed says why; a line without an item has no price to change, only its own
          v_reason := btrim(coalesce(e ->> 'price_reason', ''));
          if v_list is not null and char_length(v_reason) not between 1 and 200 then
            perform public.refuse('DKL02', '{"reason": "price_reason"}'::jsonb, 'a changed price needs its reason');
          end if;
          if v_reason <> '' then e := e || jsonb_build_object('price_reason', left(v_reason, 200)); end if;
        end if;
      end if;
      if v_list is not null then
        e := e || jsonb_build_object('list_price', trim_scale(v_list)::text);
      end if;
    end if;
    v_out := v_out || jsonb_build_array(e);
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.counter_line_prices(uuid, text, jsonb) from public, anon, authenticated;

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    perform public.refuse('DKG11', jsonb_build_object('field', p_what, 'reason', 'anchor_missing'), '0973: anchor not found exactly once');
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;

-- finalize: patched at 5 asserted anchor(s) of its live definition
do $patch$
declare
  v_def text := pg_get_functiondef('public.counter_receipt_finalize_v1(uuid,uuid,uuid,integer,jsonb)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    '  v_goods jsonb;
',
    '  v_goods jsonb;
  v_back jsonb := ''[]''::jsonb;
', 'finalize');
  v_def := pg_temp.anchor_once(v_def,
    '  if v_total <= 0 then
    raise exception ''receipt_essentials_missing'' using errcode = ''DKL02'', detail = ''total_not_positive'';
  end if;',
    '  if v_total <= 0 then
    raise exception ''receipt_essentials_missing'' using errcode = ''DKL02'', detail = ''total_not_positive'';
  end if;
  -- #4478: a returned deposit taxed where the sale is not can make the tax negative; never beyond the total either way
  if abs(v_tax) > v_total then
    raise exception ''receipt_essentials_missing'' using errcode = ''DKL02'', detail = ''tax_beyond_total'';
  end if;', 'finalize');
  v_def := pg_temp.anchor_once(v_def,
    '    if r #>> ''{line,supply}'' = ''goods'' then
      if not public.feature_effective(p_workspace_id, ''stockManagement'') then',
    '    -- #4478: a returned deposit comes back into stock, from the customer to the place a sale takes from
    if r #>> ''{line,supply}'' = ''goods'' and r #>> ''{line,kind}'' = ''deposit_return'' then
      if not public.feature_effective(p_workspace_id, ''stockManagement'') then
        raise exception ''goods are not sold here: the goods ledger is off'' using errcode = ''DKL07'', detail = ''goods_off'';
      end if;
      v_main := coalesce(nullif(r #>> ''{input,from_location_id}'', '''')::uuid,
                         (select sl.id from public.stock_locations sl where sl.workspace_id = p_workspace_id and sl.code = ''MAIN'' limit 1));
      if v_main is null then
        raise exception ''no place to take the goods back to'' using errcode = ''DKL07'', detail = ''from_place'';
      end if;
      select x.id into v_line_id from public.counter_receipt_lines x where x.receipt_id = v_rec.id and x.line_no = v_gno;
      v_back := v_back || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        ''item_id'', r ->> ''item_id'', ''quantity'', r #>> ''{line,commercial,quantity}'', ''unit'', r #>> ''{line,commercial,unit,code}'',
        ''from'', public.stock_place(p_workspace_id, ''customer''), ''to'', v_main, ''counter_line_id'', v_line_id)));
    elsif r #>> ''{line,supply}'' = ''goods'' then
      if not public.feature_effective(p_workspace_id, ''stockManagement'') then', 'finalize');
  v_def := pg_temp.anchor_once(v_def,
    '  if jsonb_array_length(v_goods) > 0 then
    perform set_config(''deskilo.counter_links'', ''on'', true);',
    '  -- #4478: under a request id of their own, derived from the sale''s: a movement is keyed by its request and line
  if jsonb_array_length(v_back) > 0 then
    perform set_config(''deskilo.counter_links'', ''on'', true);
    perform public.stock_apply_lines(p_workspace_id, v_me, md5(p_request_id::text || '':deposit_return'')::uuid, v_back, ''return_in'', now(),
                                     jsonb_build_object(''counter_receipt_id'', v_rec.id), ''generic'');
    perform set_config(''deskilo.counter_links'', ''off'', true);
  end if;
  if jsonb_array_length(v_goods) > 0 then
    perform set_config(''deskilo.counter_links'', ''on'', true);', 'finalize');
  v_def := pg_temp.anchor_once(v_def,
    'x.receipt_id = v_rec.id and x.frozen ->> ''supply'' = ''goods'' order by x.line_no loop',
    'x.receipt_id = v_rec.id and x.frozen ->> ''supply'' = ''goods''
                       and x.frozen ->> ''kind'' is distinct from ''deposit_return'' order by x.line_no loop', 'finalize');
  execute v_def;
end
$patch$;

-- correction: patched at 3 asserted anchor(s) of its live definition
do $patch$
declare
  v_def text := pg_get_functiondef('public.counter_receipt_correct_v1(uuid,uuid,uuid,jsonb)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    '    v_line_gross := (v_out #>> ''{line,commercial,amounts,gross_minor}'')::bigint;
    if v_qty = v_left then',
    '    -- #4478: a returned deposit is corrected as it was frozen: the sale of the same deposit, every amount negated
    if v_ol.frozen ->> ''kind'' = ''deposit_return'' then
      v_out := jsonb_set(jsonb_set(jsonb_set(jsonb_set(v_out,
        ''{line,commercial,amounts,net_minor}'', to_jsonb((-(v_out #>> ''{line,commercial,amounts,net_minor}'')::bigint)::text)),
        ''{line,commercial,amounts,tax_minor}'', to_jsonb((-(v_out #>> ''{line,commercial,amounts,tax_minor}'')::bigint)::text)),
        ''{line,commercial,amounts,gross_minor}'', to_jsonb((-(v_out #>> ''{line,commercial,amounts,gross_minor}'')::bigint)::text)),
        ''{line,amount_cents}'', to_jsonb(-(v_out #>> ''{line,amount_cents}'')::bigint));
    end if;
    v_line_gross := (v_out #>> ''{line,commercial,amounts,gross_minor}'')::bigint;
    if v_qty = v_left then', 'correction');
  v_def := pg_temp.anchor_once(v_def,
    '    elsif v_prev_gross + v_line_gross > v_ol.gross_minor then',
    '    elsif abs(v_prev_gross + v_line_gross) > abs(v_ol.gross_minor) then', 'correction');
  v_def := pg_temp.anchor_once(v_def,
    '    v_rows := v_rows || jsonb_build_array(jsonb_build_object(''input'', v_in, ''line'', v_out -> ''line'', ''item_id'', v_ol.item_id,',
    '    if v_ol.frozen ->> ''kind'' = ''deposit_return'' then
      v_out := jsonb_set(v_out, ''{line}'', (v_out -> ''line'') || jsonb_build_object(''kind'', ''deposit_return'', ''returned'', true));
    end if;
    v_rows := v_rows || jsonb_build_array(jsonb_build_object(''input'', v_in, ''line'', v_out -> ''line'', ''item_id'', v_ol.item_id,', 'correction');
  execute v_def;
end
$patch$;

-- goods return: patched at 1 asserted anchor(s) of its live definition
do $patch$
declare
  v_def text := pg_get_functiondef('public.counter_goods_return_v1(uuid,uuid,uuid,jsonb)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    'or (v_line.frozen ->> ''supply'') <> ''goods'' or v_line.item_id is null then',
    'or (v_line.frozen ->> ''supply'') <> ''goods'' or v_line.item_id is null
       or v_line.frozen ->> ''kind'' = ''deposit_return'' then', 'goods return');
  execute v_def;
end
$patch$;

-- day close: patched at 1 asserted anchor(s) of its live definition
do $patch$
declare
  v_def text := pg_get_functiondef('public.counter_day_close_v1(uuid,uuid,uuid,date)'::regprocedure);
begin
  v_def := pg_temp.anchor_once(v_def,
    '    ''sales_total_minor'', (select coalesce(sum(r.total_minor), 0)::text from public.counter_receipts r where r.till_session_id = any (v_sessions) and r.state = ''finalized'' and r.kind = ''sale''),',
    '    ''sales_total_minor'', (select coalesce(sum(r.total_minor), 0)::text from public.counter_receipts r where r.till_session_id = any (v_sessions) and r.state = ''finalized'' and r.kind = ''sale''),
    ''deposits_returned_minor'', (select coalesce(-sum(l.gross_minor), 0)::text from public.counter_receipt_lines l join public.counter_receipts r on r.id = l.receipt_id
        where r.till_session_id = any (v_sessions) and r.state = ''finalized'' and r.kind = ''sale'' and l.frozen ->> ''kind'' = ''deposit_return''),', 'day close');
  execute v_def;
end
$patch$;

select public.set_deskilo_schema_version(973);
