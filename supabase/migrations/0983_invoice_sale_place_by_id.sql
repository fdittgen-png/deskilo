-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
--
-- #4495 (audit STK-01) -- the goods of an invoice leave the place the business PICKED, not the first place that carries a code. Place codes
-- are unique only among the places of one parent (0855), so a business with two sites that each have a SHOP could not say which one
-- `stock.invoice_sale_place` meant, and the posting (0942) took the one created first.
--   * the setting now holds the place's ID (a text of 36 characters, picked in the app as site › place). A value that is a code (every
--     installation until now) still reads as the code of one place when exactly one eligible place carries it; several or none are named,
--     never guessed: the posting refuses (`stock_sale_place`) until a place is picked,
--     and the setting says which problem it is (`invoice_sale_place`: ambiguous, none or gone).
--   * `invoice_sale_place_eligible(workspace, place)`: a place of the business that is in use, holds stock (not a virtual kind) and is not
--     the transit place. `invoice_sale_place(workspace)` is THE answer (the place and, when there is none, the problem) and the posting
--     reads it; the value is checked again at every posting, so a place archived since the pick is refused with its reason.
--   * `set_setting` checks the value when it is saved (`invoice_sale_place_value`): empty (the code MAIN stays the default), the id of an
--     eligible place, or a code that names exactly one eligible place (stored as that place's id); anything else is refused.
--   * installations whose stored code matches exactly one eligible place are migrated to its id here; the others keep the code and are said.
-- Anchored patches of the live `standalone_invoice_goods_post` (0942) and `set_setting` (0428), each anchor asserted once.

create or replace function pg_temp.anchor_once(p_def text, p_old text, p_new text, p_what text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    raise exception '0983: % is not found exactly once', p_what using errcode = 'P0001';
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_once(text, text, text, text) from public;

create or replace function public.invoice_sale_place_eligible(p_workspace_id uuid, p_place uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.stock_locations sl
                  where sl.id = p_place and sl.workspace_id = p_workspace_id and sl.active
                    and not public.stock_place_is_virtual(sl.id)
                    and sl.id is distinct from public.stock_transit_place(p_workspace_id));
$fn$;
revoke execute on function public.invoice_sale_place_eligible(uuid, uuid) from public, anon, authenticated;

-- the place goods sold on an invoice leave: its id, or the problem (`stock_sale_place` none or unusable, `stock_sale_place_ambiguous`)
create or replace function public.invoice_sale_place(p_workspace_id uuid)
returns table (place_id uuid, problem text)
language plpgsql stable security definer set search_path = public as $fn$
declare
  v text := nullif(btrim(public.setting_value(p_workspace_id, 'stock.invoice_sale_place') #>> '{}'), '');
  v_ids uuid[];
begin
  if v ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    if public.invoice_sale_place_eligible(p_workspace_id, v::uuid) then
      return query select v::uuid, null::text;
    else
      return query select null::uuid, 'stock_sale_place'::text;
    end if;
    return;
  end if;
  -- a code (every installation until now, and the default MAIN): one eligible place carries it, or it is not a choice
  select coalesce(array_agg(sl.id order by sl.created_datetime), '{}') into v_ids
    from public.stock_locations sl
   where sl.workspace_id = p_workspace_id and sl.code = coalesce(v, 'MAIN')
     and public.invoice_sale_place_eligible(p_workspace_id, sl.id);
  if cardinality(v_ids) = 1 then
    return query select v_ids[1], null::text;
  elsif cardinality(v_ids) > 1 then
    return query select null::uuid, 'stock_sale_place_ambiguous'::text;
  else
    return query select null::uuid, 'stock_sale_place'::text;
  end if;
end;
$fn$;
revoke execute on function public.invoice_sale_place(uuid) from public, anon, authenticated;

-- the value to store for what a member (or a script) set: '' stays, an id of an eligible place stays, a code naming one eligible place
-- becomes its id; anything else is refused (nothing is guessed)
create or replace function public.invoice_sale_place_value(p_workspace_id uuid, p_value jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v text := btrim(coalesce(p_value #>> '{}', ''));
  v_ids uuid[];
begin
  if v = '' then
    return to_jsonb(''::text);
  end if;
  if v ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    if not public.invoice_sale_place_eligible(p_workspace_id, v::uuid) then
      perform public.stock_config_refuse('stock.invoice_sale_place', 'place_unusable');
    end if;
    return to_jsonb(lower(v));
  end if;
  select coalesce(array_agg(sl.id), '{}') into v_ids
    from public.stock_locations sl
   where sl.workspace_id = p_workspace_id and sl.code = v and public.invoice_sale_place_eligible(p_workspace_id, sl.id);
  if cardinality(v_ids) <> 1 then
    perform public.stock_config_refuse('stock.invoice_sale_place', case when cardinality(v_ids) = 0 then 'place_unknown' else 'place_ambiguous' end);
  end if;
  return to_jsonb(v_ids[1]::text);
end;
$fn$;
revoke execute on function public.invoice_sale_place_value(uuid, jsonb) from public, anon, authenticated;

do $migration$
declare
  v_def text;
  r record;
  v_ids uuid[];
begin
  select pg_get_functiondef('public.standalone_invoice_goods_post(uuid,uuid,uuid)'::regprocedure) into v_def;
  if position('invoice_sale_place(' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def,
      $o$  v_code := coalesce(nullif(btrim(public.setting_value(p_workspace_id, 'stock.invoice_sale_place') #>> '{}'), ''), 'MAIN');
  select sl.id into v_from from public.stock_locations sl
   where sl.workspace_id = p_workspace_id and sl.code = v_code and sl.active
     and not public.stock_place_is_virtual(sl.id)
     and sl.id is distinct from public.stock_transit_place(p_workspace_id)
   order by sl.created_datetime limit 1;$o$,
      $n$  select p.place_id, p.problem into v_from, v_code from public.invoice_sale_place(p_workspace_id) p;$n$,
      'the place lookup');
    execute v_def;
  end if;

  select pg_get_functiondef('public.set_setting(uuid,text,jsonb,text)'::regprocedure) into v_def;
  if position('invoice_sale_place_value' in v_def) = 0 then
    v_def := pg_temp.anchor_once(v_def, $o$  v_changed := public.store_setting(p_workspace, p_key, p_value, p_note, auth.uid());$o$,
      $n$  if p_key = 'stock.invoice_sale_place' and p_workspace is not null then
    p_value := public.invoice_sale_place_value(p_workspace, p_value);
  end if;
  v_changed := public.store_setting(p_workspace, p_key, p_value, p_note, auth.uid());$n$, 'the store');
    execute v_def;
  end if;

  -- an installation whose stored code names exactly one eligible place is moved to its id; the others keep the code
  for r in select s.workspace_id, btrim(s.value #>> '{}') as code from public.setting_values s
            where s.scope = 'workspace' and s.key = 'stock.invoice_sale_place' and s.valid_to is null
              and btrim(s.value #>> '{}') <> ''
              and btrim(s.value #>> '{}') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' loop
    select coalesce(array_agg(sl.id), '{}') into v_ids from public.stock_locations sl
     where sl.workspace_id = r.workspace_id and sl.code = r.code and public.invoice_sale_place_eligible(r.workspace_id, sl.id);
    if cardinality(v_ids) = 1 then
      perform public.store_setting(r.workspace_id, 'stock.invoice_sale_place', to_jsonb(v_ids[1]::text), 'the place code ' || r.code || ' moved to the place (#4495)', null);
    end if;
  end loop;
end
$migration$;

update public.setting_definitions
   set note = 'The place goods sold on an invoice leave from, picked as site › place (#4495). A code set before the place was picked by id still works while exactly one place carries it.'
 where key = 'stock.invoice_sale_place';

select public.set_deskilo_schema_version(983);
