-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
--
-- #4476 -- a till line's price is the item's price, unless a discount within the business's limit or the right to change
-- a price (overrideTillPrice) with a reason sets another one. Every counter draft's lines pass counter_line_prices before
-- they are computed:
--
--   a line with a discount_percent   the item's price less that percent, rounded to the currency's minor unit; refused
--                                    beyond counter.max_discount_percent (DKN01 {"reason": "discount_limit"}), with a price
--                                    of its own (DKL02 {"reason": "price_and_discount"}) or without an item.
--   any other line                   judged by the price one base unit sells at (the unit_price sent, or the item's, over
--                                    the base_quantity sent); a discount sells per one base unit.
--   a line with its own unit_price   the item's price needs nothing more; another price needs overrideTillPrice (DKN01
--                                    {"reason": "price"}) and a price_reason of 1 to 200 characters (DKL02 {"reason":
--                                    "price_reason"}); a line without an item, priced by hand, needs overrideTillPrice.
--                                    A sale sent by the offline till keeps the tolerance of
--                                    counter.offline_price_tolerance_percent instead: only inside counter_offline_sync_v1,
--                                    patched below to mark its transaction (deskilo.counter_offline_sync); a body that
--                                    only says source_kind offline_till gets no tolerance.
--   every line                       keeps list_price (the item's price) beside the price sold, for the receipt.
-- The draft's digest is taken from the body as sent, so the same request answers again unchanged.

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

-- the draft passes its lines through the price rules first: an anchored patch of the live definition (0894, 0908)
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text) returns text language plpgsql as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    perform public.refuse('DKG11', jsonb_build_object('field', left(p_old, 60), 'reason', 'anchor_missing'), '0964: anchor not found exactly once');
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.counter_receipt_draft_v1(uuid,uuid,uuid,integer,jsonb)'::regprocedure);
begin
  execute pg_temp.anchor_replace(v_def,
    'v_calc := public.counter_lines_of(p_workspace_id, p_body -> ''lines'', v_cur, v_basis, v_tp);',
    'v_calc := public.counter_lines_of(p_workspace_id, public.counter_line_prices(p_workspace_id, v_kind, p_body -> ''lines''), v_cur, v_basis, v_tp);');
end
$patch$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.counter_offline_sync_v1(uuid,uuid,timestamp with time zone,jsonb)'::regprocedure);
begin
  execute pg_temp.anchor_replace(v_def,
    'v_draft := public.counter_receipt_draft_v1(p_workspace_id, v_req, null, null,',
    'perform set_config(''deskilo.counter_offline_sync'', ''on'', true);
        v_draft := public.counter_receipt_draft_v1(p_workspace_id, v_req, null, null,');
end
$patch$;

select public.set_deskilo_schema_version(964);
