-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (two settings, three functions, and stock_pieces_apply patched at one asserted anchor)
--
-- #4364 (G15, third file) -- a UHF reader in keyboard mode types every tag it sees, often the same one many times a second. The
-- sheet collects them locally, bounded by a setting, and the server answers for the whole read in batches; nothing changes until
-- the user confirms with the sheet's own command and one request id.
--
--   * `stock_resolve_codes_v1(workspace, codes[])` resolves a read through the one resolver of a scan (G13), de-duplicated on the
--     normalised tag, in the order first read. A piece answers with its own id, its state and its place, so a move can name its
--     units and take each from where it is. It never raises for an unknown code, is scoped to the business, answers at most
--     `stock.tag_read_max_tags` different codes and says when it stopped (`truncated`). It is for a person, not for an assistant.
--   * A move needs no new command: the transfer names each piece and its source, several sources are several lines of one request
--     id, and a piece that someone moved while the read was open is refused at the confirm with its new place named (DKG26 detail).
--   * `stock_count_tag_read_v1(workspace, request, task, codes[])` fills the counted lines of a cycle count task from a bulk read:
--     each per-unit line of a place where a piece was read is counted with the pieces read there, through the cycle count's own
--     line command (so the count is recorded and waits for its approval; a balance is never adjusted by a read). A piece read at a
--     place the task has no line for, or that is not in stock, is left out and listed. The pieces expected and not read are listed
--     to whoever may see what the ledger holds (a blind counter is told how many it read, never what was expected).
--   * Off with the feature `stockTagReads`: tags are read one at a time as before.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('stock.tag_read_max_tags', 'int', '500'::jsonb, 1, 5000, 'tags', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'bulk tag reads (#4364)', 'How many different tags one bulk read keeps before it takes no more, and how many the server resolves in one request. The same tag read many times counts once.'),
('stock.tag_read_unit_as_quantity', 'bool', 'false'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'bulk tag reads (#4364)', 'Whether, in a bulk move, a tag on a piece of an item that is not tracked piece by piece is added as quantity 1 of that item. Off: such a tag is left out of the move and listed.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── who may bulk read ──────────────────────────────────────────────────
create or replace function public.stock_read_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to read tags in bulk' using errcode = 'DKN01';
  end if;
  select m.id into v_me from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null or not (public.has_permission(p_workspace_id, 'viewStock') or public.has_permission(p_workspace_id, 'manageStock')
                          or public.has_permission(p_workspace_id, 'countStock')) then
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

-- ── the codes of a read, de-duplicated and bounded ─────────────────────
-- The distinct codes in the order first read: a tag by its normalised form (uppercase hex), any other code as typed. At most the
-- limit; `p_more` says that a further distinct code was left out.
create or replace function public.stock_read_distinct(p_codes text[], p_limit int, out p_distinct text[], out p_more boolean)
language plpgsql immutable set search_path = public as $fn$
declare
  v_code text;
  v_key text;
  v_keys text[] := array[]::text[];
begin
  p_distinct := array[]::text[];
  p_more := false;
  foreach v_code in array coalesce(p_codes, array[]::text[]) loop
    v_code := btrim(coalesce(v_code, ''));
    if v_code = '' then
      continue;
    end if;
    v_key := coalesce(public.stock_tag_normalize(v_code), v_code);
    if v_key = any (v_keys) then
      continue;
    end if;
    if coalesce(array_length(v_keys, 1), 0) >= p_limit then
      p_more := true;
      exit;
    end if;
    v_keys := v_keys || v_key;
    p_distinct := p_distinct || v_code;
  end loop;
end;
$fn$;
revoke execute on function public.stock_read_distinct(text[], int) from public, anon, authenticated;

-- ── a read resolved ────────────────────────────────────────────────────
-- {received, distinct, limit, truncated, results: [{input, kind, matched_by, code, ..., piece?}]}. A piece: {id, state, item_id,
-- variant_id, lot_id, place: {id, code, name}}. Each code answers as the resolver of a scan answers it.
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
    raise exception 'a read names its codes' using errcode = '22023';
  end if;
  v_limit := coalesce((public.setting_value(p_workspace_id, 'stock.tag_read_max_tags') #>> '{}')::int, 500);
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
    'limit', v_limit, 'truncated', v_d.p_more, 'results', v_out);
end;
$fn$;
revoke execute on function public.stock_resolve_codes_v1(uuid, text[]) from public, anon;
grant execute on function public.stock_resolve_codes_v1(uuid, text[]) to authenticated;

-- ── a piece moved by someone else is refused with its new place named ──
-- restates 0887
create or replace function pg_temp.occurrences(p_def text, p_old text)
returns int language sql as $f$
  select (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old)
$f$;
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_pieces_apply(uuid, uuid, uuid, uuid, jsonb, uuid, uuid, text, numeric)'::regprocedure);
  v_old text := E'or pc.location_id <> p_from or pc.state <> v_expect or v_pid = any (v_ids) then\n        raise exception ''a named piece is not where this movement takes it from'' using errcode = ''DKG26'';';
  v_new text := E'or pc.location_id <> p_from or pc.state <> v_expect or v_pid = any (v_ids) then\n        raise exception ''a named piece is not where this movement takes it from'' using errcode = ''DKG26'',\n          detail = jsonb_build_object(''piece_id'', pc.id, ''state'', pc.state, ''place_id'', pc.location_id,\n                                      ''place'', (select z.code from public.stock_locations z where z.id = pc.location_id))::text;';
begin
  if pg_temp.occurrences(v_def, v_old) <> 1 then
    raise exception '0917: anchor not found exactly once in stock_pieces_apply' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, v_new);
end
$patch$;

-- ── a cycle count filled from a bulk read ──────────────────────────────
-- {task_id, request_id, task_state, lines: [{line_id, item_id, variant_id, lot_id, location_id, read, state}],
--  left_out: [{code, reason}], missing: [{piece_id, code, location_id}]}: `missing` only for whoever may see what the ledger holds.
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
  v_left jsonb := '[]'::jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_missing jsonb := '[]'::jsonb;
  v_sees boolean;
  v_n int;
  v_line public.stock_count_task_lines;
  v_res jsonb;
  v_state text;
  v_result jsonb;
begin
  v_me := public.stock_read_actor(p_workspace_id);
  perform public.stock_blind_actor(p_workspace_id);
  if p_request_id is null or p_task_id is null or p_codes is null then
    raise exception 'a read is sent with a request id, a task and its codes' using errcode = 'DKG07';
  end if;
  v_limit := coalesce((public.setting_value(p_workspace_id, 'stock.tag_read_max_tags') #>> '{}')::int, 500);
  select * into v_d from public.stock_read_distinct(p_codes, v_limit);
  if v_d.p_more then
    raise exception 'a read keeps at most % different tags', v_limit using errcode = 'DKG07';
  end if;
  v_digest := md5(p_task_id::text || '|' || (select coalesce(string_agg(x, ',' order by x), '') from unnest(v_d.p_distinct) x));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_count_tag_read', v_digest);
  if v_done is not null then
    return v_done || jsonb_build_object('replayed', true);
  end if;
  select * into v_task from public.stock_count_tasks t where t.id = p_task_id and t.workspace_id = p_workspace_id;
  if v_task.id is null then
    raise exception 'not a task of this business' using errcode = 'DKG04';
  end if;
  if v_task.state <> 'open' then
    raise exception 'this task is no longer open' using errcode = 'DKG19';
  end if;
  v_sees := public.has_permission(p_workspace_id, 'manageStock') or public.has_permission(p_workspace_id, 'approveStockAdjustments');

  -- each code to its piece, in stock, at a place the task has a pending line for
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
      v_left := v_left || jsonb_build_array(jsonb_build_object('code', v_t.code, 'reason', 'not_in_stock', 'state', v_u.state));
    elsif not exists (select 1 from public.stock_count_task_lines l
                       where l.task_id = v_task.id and l.state = 'pending' and l.item_id = v_u.item_id and l.location_id = v_u.location_id
                         and l.variant_id is not distinct from v_u.variant_id and l.lot_id is not distinct from v_u.lot_id) then
      v_left := v_left || jsonb_build_array(jsonb_build_object('code', v_t.code, 'reason', 'other_place'));
    else
      v_read := v_read || v_u.id;
    end if;
  end loop;

  -- a pending line of a place where a piece was read is counted with the pieces read there, items in id order
  for v_line in
    select l.* from public.stock_count_task_lines l
     where l.task_id = v_task.id and l.state = 'pending'
       and (public.item_effective_core(l.item_id) #>> '{parameters,tag_mode,value}') = 'per_unit'
       and exists (select 1 from public.stock_tagged_units u where u.id = any (v_read) and u.location_id = l.location_id)
     order by l.item_id, l.id
  loop
    select count(*)::int into v_n from public.stock_tagged_units u
     where u.id = any (v_read) and u.item_id = v_line.item_id and u.location_id = v_line.location_id
       and u.variant_id is not distinct from v_line.variant_id and u.lot_id is not distinct from v_line.lot_id;
    v_res := public.stock_cycle_count_line_v1(p_workspace_id, md5(p_request_id::text || ':' || v_line.id::text)::uuid, v_line.id, v_n::text);
    v_lines := v_lines || jsonb_build_array(jsonb_build_object('line_id', v_line.id, 'item_id', v_line.item_id, 'variant_id', v_line.variant_id,
      'lot_id', v_line.lot_id, 'location_id', v_line.location_id, 'read', v_n));
    if v_sees then
      select coalesce(jsonb_agg(jsonb_build_object('piece_id', u.id, 'code', g.code, 'location_id', u.location_id) order by g.code), '[]'::jsonb) into v_res
        from public.stock_tagged_units u join public.stock_tags g on g.piece_id = u.id and g.state = 'active'
       where u.workspace_id = p_workspace_id and u.item_id = v_line.item_id and u.location_id = v_line.location_id and u.state = 'in_stock'
         and u.variant_id is not distinct from v_line.variant_id and u.lot_id is not distinct from v_line.lot_id and not (u.id = any (v_read));
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
select public.set_deskilo_schema_version(917);
