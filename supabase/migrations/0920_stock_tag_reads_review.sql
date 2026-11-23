-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (four functions restated whole, one helper dropped and made again with another answer; no table, no setting, no grant moves)
--
-- #4364 (G15, review of 0915-0917) --
--   * A bulk count counts a line only when a piece of that line's own item, variant and lot was read at its place; the other lines
--     stay pending (a read of one basket no longer records the crates of the same shelf as none).
--   * The first read of a line is final: the tags of a counted line come back as `already_counted`, to a blind counter too, because
--     it tells nothing of what was expected. The manual correction of a line stays the way to fix a count.
--   * A blank code or one over 200 characters is not dropped: both functions return it as {code, reason: 'invalid'}.
--   * The replay of a count read is looked up before any size check (a lowered limit never refuses the retry of a lost answer), and
--     the caller is part of its digest, so a replay is never handed to another member.
--   * The hard cap of a read is 5 times the setting, not 20.
--   * `missing` lists a piece once, whatever its tags.
--   * `stock_read_actor` asks for what the resolver needs (viewStock or manageStock), so the refusal comes first and names it; the
--     count read keeps the counting right.
--
-- restates 0917
drop function if exists public.stock_read_distinct(text[], int);

create or replace function public.stock_read_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to read tags in bulk' using errcode = 'DKN01';
  end if;
  select m.id into v_me from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null or not (public.has_permission(p_workspace_id, 'viewStock') or public.has_permission(p_workspace_id, 'manageStock')) then
    raise exception 'not allowed to read tags in bulk' using errcode = 'DKN01';
  end if;
  if not (public.feature_effective(p_workspace_id, 'stockManagement') and public.feature_effective(p_workspace_id, 'stockTags')
          and public.feature_effective(p_workspace_id, 'stockTagReads')) then
    raise exception 'reading tags in bulk is off in this business' using errcode = 'DKG01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.stock_read_actor(uuid) from public, anon, authenticated;

-- ── the codes of a read: the distinct ones, bounded, and the ones that cannot be read ──
-- p_invalid: [{code, reason: 'invalid'}] for a blank code or one over 200 characters (the first 50 of them); p_more: a further
-- distinct code was left out.
create or replace function public.stock_read_distinct(p_codes text[], p_limit int, out p_distinct text[], out p_invalid jsonb, out p_more boolean)
language plpgsql immutable set search_path = public as $fn$
declare
  v_raw text;
  v_code text;
  v_key text;
  v_keys jsonb := '{}'::jsonb;
  v_n int := 0;
begin
  p_distinct := array[]::text[];
  p_invalid := '[]'::jsonb;
  p_more := false;
  foreach v_raw in array coalesce(p_codes, array[]::text[]) loop
    -- the length is read on the raw text, before any trimming
    if v_raw is null or char_length(v_raw) > 200 or btrim(v_raw) = '' then
      if jsonb_array_length(p_invalid) < 50 then
        p_invalid := p_invalid || jsonb_build_array(jsonb_build_object('code', left(coalesce(v_raw, ''), 60), 'reason', 'invalid'));
      end if;
      continue;
    end if;
    v_code := btrim(v_raw);
    v_key := coalesce(public.stock_tag_normalize(v_code), v_code);
    if v_keys ? v_key then
      continue;
    end if;
    if v_n >= p_limit then
      p_more := true;
      exit;
    end if;
    v_keys := v_keys || jsonb_build_object(v_key, true);
    v_n := v_n + 1;
    p_distinct := p_distinct || v_code;
  end loop;
end;
$fn$;
revoke execute on function public.stock_read_distinct(text[], int) from public, anon, authenticated;

-- ── a read resolved ────────────────────────────────────────────────────
create or replace function public.stock_resolve_codes_v1(p_workspace_id uuid, p_codes text[])
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_limit int;
  v_d record;
  v_code text;
  v_r jsonb;
  v_t public.stock_tags;
  v_u public.stock_tagged_units;
  v_l public.stock_locations;
  v_out jsonb := '[]'::jsonb;
begin
  perform public.stock_read_actor(p_workspace_id);
  if p_codes is null then
    raise exception 'a read names its codes' using errcode = 'DKG07';
  end if;
  v_limit := coalesce((public.setting_value(p_workspace_id, 'stock.tag_read_max_tags') #>> '{}')::int, 500);
  -- a read keeps at most the setting's tags: what a client repeats is bounded, never without limit
  if coalesce(array_length(p_codes, 1), 0) > v_limit * 5 then
    raise exception 'a read sends at most % codes', v_limit * 5 using errcode = 'DKG07';
  end if;
  select * into v_d from public.stock_read_distinct(p_codes, v_limit);
  foreach v_code in array v_d.p_distinct loop
    v_r := public.stock_resolve_code_v1(p_workspace_id, v_code) || jsonb_build_object('input', v_code);
    if v_r ->> 'kind' = 'tag' and v_r #>> '{tag,owner_kind}' = 'piece' then
      select g.* into v_t from public.stock_tags g
       where g.workspace_id = p_workspace_id and g.code = v_r ->> 'code' and g.state = 'active' and g.owner_kind = 'piece';
      select * into v_u from public.stock_tagged_units u where u.id = v_t.piece_id and u.workspace_id = p_workspace_id;
      if v_u.id is not null then
        select * into v_l from public.stock_locations z where z.id = v_u.location_id;
        v_r := v_r || jsonb_build_object('piece', jsonb_build_object('id', v_u.id, 'state', v_u.state, 'item_id', v_u.item_id,
          'variant_id', v_u.variant_id, 'lot_id', v_u.lot_id,
          'place', jsonb_build_object('id', v_l.id, 'code', v_l.code, 'name', v_l.name)));
      end if;
    end if;
    v_out := v_out || jsonb_build_array(v_r);
  end loop;
  return jsonb_build_object('received', coalesce(array_length(p_codes, 1), 0), 'distinct', coalesce(array_length(v_d.p_distinct, 1), 0),
    'limit', v_limit, 'truncated', v_d.p_more, 'results', v_out, 'invalid', v_d.p_invalid);
end;
$fn$;
revoke execute on function public.stock_resolve_codes_v1(uuid, text[]) from public, anon;
grant execute on function public.stock_resolve_codes_v1(uuid, text[]) to authenticated;

-- ── a cycle count filled from a bulk read ──────────────────────────────
-- {task_id, request_id, task_state, lines: [{line_id, item_id, variant_id, lot_id, location_id, read, state}],
--  left_out: [{code, reason}], missing: [{piece_id, code, location_id}]}. A line is counted when a piece of its own item, variant and
-- lot was read at its place; the first read of a line is final (`already_counted`); `missing` only for whoever may see what the
-- ledger holds; a blind counter's other reasons are `not_counted`.
create or replace function public.stock_count_tag_read_v1(p_workspace_id uuid, p_request_id uuid, p_task_id uuid, p_codes text[])
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_limit int;
  v_d record;
  v_digest text;
  v_done jsonb;
  v_task public.stock_count_tasks;
  v_code text;
  v_key text;
  v_t public.stock_tags;
  v_u public.stock_tagged_units;
  v_read uuid[] := array[]::uuid[];
  v_left jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_missing jsonb := '[]'::jsonb;
  v_sees boolean;
  v_n int;
  v_line public.stock_count_task_lines;
  v_res jsonb;
  v_state text;
  v_result jsonb;
begin
  v_me := public.stock_blind_actor(p_workspace_id);
  if not (public.feature_effective(p_workspace_id, 'stockTags') and public.feature_effective(p_workspace_id, 'stockTagReads')) then
    raise exception 'reading tags in bulk is off in this business' using errcode = 'DKG01';
  end if;
  if p_request_id is null or p_task_id is null or p_codes is null then
    raise exception 'a read is sent with a request id, a task and its codes' using errcode = 'DKG07';
  end if;
  -- the replay first: a lowered limit never refuses the retry of a lost answer; the caller is in the digest, so another
  -- member's retry is not this answer
  v_digest := md5(p_task_id::text || '|' || v_me::text || '|' || array_to_string(p_codes, E'\u001f'));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_count_tag_read', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  v_limit := coalesce((public.setting_value(p_workspace_id, 'stock.tag_read_max_tags') #>> '{}')::int, 500);
  if coalesce(array_length(p_codes, 1), 0) > v_limit * 5 then
    raise exception 'a read sends at most % codes', v_limit * 5 using errcode = 'DKG07';
  end if;
  select * into v_d from public.stock_read_distinct(p_codes, v_limit);
  if v_d.p_more then
    raise exception 'a read keeps at most % different tags', v_limit using errcode = 'DKG07';
  end if;
  select * into v_task from public.stock_count_tasks t where t.id = p_task_id and t.workspace_id = p_workspace_id;
  if v_task.id is null then
    raise exception 'not a task of this business' using errcode = 'DKG04';
  end if;
  if v_task.state <> 'open' then
    raise exception 'this task is no longer open' using errcode = 'DKG19';
  end if;
  v_sees := public.has_permission(p_workspace_id, 'manageStock') or public.has_permission(p_workspace_id, 'approveStockAdjustments');
  v_left := v_d.p_invalid;

  -- each code to its piece: read (a pending line of its own item, variant, lot and place), already counted, or left out
  foreach v_code in array v_d.p_distinct loop
    v_key := public.stock_tag_normalize(v_code);
    select g.* into v_t from public.stock_tags g
     where v_key is not null and g.workspace_id = p_workspace_id and g.code = v_key and g.state = 'active' and g.owner_kind = 'piece';
    if v_t.id is null then
      v_left := v_left || jsonb_build_array(jsonb_build_object('code', coalesce(v_key, v_code), 'reason', 'not_a_piece'));
      continue;
    end if;
    select * into v_u from public.stock_tagged_units u where u.id = v_t.piece_id and u.workspace_id = p_workspace_id;
    if v_u.state <> 'in_stock' then
      v_left := v_left || jsonb_build_array(case when v_sees then jsonb_build_object('code', v_t.code, 'reason', 'not_in_stock', 'state', v_u.state)
                                                 else jsonb_build_object('code', v_t.code, 'reason', 'not_counted') end);
    elsif exists (select 1 from public.stock_count_task_lines l
                   where l.task_id = v_task.id and l.state = 'pending' and l.item_id = v_u.item_id and l.location_id = v_u.location_id
                     and l.variant_id is not distinct from v_u.variant_id and l.lot_id is not distinct from v_u.lot_id) then
      v_read := v_read || v_u.id;
    elsif exists (select 1 from public.stock_count_task_lines l
                   where l.task_id = v_task.id and l.state = 'counted' and l.item_id = v_u.item_id and l.location_id = v_u.location_id
                     and l.variant_id is not distinct from v_u.variant_id and l.lot_id is not distinct from v_u.lot_id) then
      -- the first read of a line is final; this tells a blind counter nothing of what was expected
      v_left := v_left || jsonb_build_array(jsonb_build_object('code', v_t.code, 'reason', 'already_counted'));
    else
      v_left := v_left || jsonb_build_array(case when v_sees then jsonb_build_object('code', v_t.code, 'reason', 'other_place')
                                                 else jsonb_build_object('code', v_t.code, 'reason', 'not_counted') end);
    end if;
  end loop;

  -- a pending per-unit line with a piece of its own read at its place is counted with the pieces read there, items in id order
  for v_line in
    select l.* from public.stock_count_task_lines l
     where l.task_id = v_task.id and l.state = 'pending'
       and (public.item_effective_core(l.item_id) #>> '{parameters,tag_mode,value}') = 'per_unit'
       and exists (select 1 from public.stock_tagged_units u
                    where u.id = any (v_read) and u.item_id = l.item_id and u.location_id = l.location_id
                      and u.variant_id is not distinct from l.variant_id and u.lot_id is not distinct from l.lot_id)
     order by l.item_id, l.id
  loop
    select count(*)::int into v_n from public.stock_tagged_units u
     where u.id = any (v_read) and u.item_id = v_line.item_id and u.location_id = v_line.location_id
       and u.variant_id is not distinct from v_line.variant_id and u.lot_id is not distinct from v_line.lot_id;
    v_res := public.stock_cycle_count_line_v1(p_workspace_id, md5(p_request_id::text || ':' || v_line.id::text)::uuid, v_line.id, v_n::text);
    v_lines := v_lines || jsonb_build_array(jsonb_build_object('line_id', v_line.id, 'item_id', v_line.item_id, 'variant_id', v_line.variant_id,
      'lot_id', v_line.lot_id, 'location_id', v_line.location_id, 'read', v_n));
    if v_sees then
      -- a piece once, whatever its tags
      select coalesce(jsonb_agg(jsonb_build_object('piece_id', x.id, 'code', x.code, 'location_id', x.location_id) order by x.code), '[]'::jsonb) into v_res
        from (select u.id, u.location_id, min(g.code) as code
                from public.stock_tagged_units u join public.stock_tags g on g.piece_id = u.id and g.state = 'active'
               where u.workspace_id = p_workspace_id and u.item_id = v_line.item_id and u.location_id = v_line.location_id and u.state = 'in_stock'
                 and u.variant_id is not distinct from v_line.variant_id and u.lot_id is not distinct from v_line.lot_id and not (u.id = any (v_read))
               group by u.id, u.location_id) x;
      v_missing := v_missing || v_res;
    end if;
  end loop;
  select t.state into v_state from public.stock_count_tasks t where t.id = v_task.id;
  v_result := jsonb_build_object('task_id', v_task.id, 'request_id', p_request_id, 'task_state', v_state, 'lines',
    (select coalesce(jsonb_agg(e || jsonb_build_object('state', (select l.state from public.stock_count_task_lines l where l.id = (e ->> 'line_id')::uuid))), '[]'::jsonb)
       from jsonb_array_elements(v_lines) e),
    'left_out', v_left, 'replayed', false);
  if v_sees then
    v_result := v_result || jsonb_build_object('missing', v_missing);
  end if;
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_count_tag_read', v_digest, v_result);
end;
$fn$;
revoke execute on function public.stock_count_tag_read_v1(uuid, uuid, uuid, text[]) from public, anon;
grant execute on function public.stock_count_tag_read_v1(uuid, uuid, uuid, text[]) to authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(920);
