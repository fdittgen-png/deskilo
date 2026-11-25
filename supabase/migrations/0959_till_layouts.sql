-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4448 -- a till's layout: which keys and tools sit where on the till, per till, as a draft being edited and the one
-- published. A till with no layout keeps the generated one of #4366; nothing here changes a sale.
--
--   public.till_layouts            one draft and one published layout per till: its name, its version (the optimistic
--                                  save's), its status and the layout (pages, grids per size, cells).
--   public.till_layout_problems    the rules a layout must meet, the same as the app's validateTillLayout
--                                  (lib/features/money/domain/till_layout.dart): known kinds and functions, cells inside
--                                  their grid and at least their kind's span, no two cells on one place, the cell cap,
--                                  item keys naming an item of the business. Answers the problems, first one first.
--   till_layout_save_v1            the one way in for a draft: a request id and the version the editor read; a stale
--                                  version is refused (DKL10, the app says "Someone changed this layout; reload it"), an invalid
--                                  layout is refused with its first problem (DKL02), the right configureTill (DKN01) and
--                                  the flag counterTillLayout (DKG01) are checked first. Answers the draft's id and version.
--   till_layout_publish_v1         the draft at the version the editor read becomes the till's published layout. A till
--                                  session already open keeps what it loaded until it loads again (the app's rule).
--   The flag, the right and the settings are 0958's; the builtin association template is restated here with the flag.
create table public.till_layouts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  till_id uuid not null references public.counter_tills(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  version integer not null default 1 check (version >= 1),
  status text not null default 'draft' check (status in ('draft', 'published')),
  layout jsonb not null check (jsonb_typeof(layout) = 'object'),
  constraint till_layouts_one_per_status unique (till_id, status)
);
select public.ensure_system_columns('till_layouts');
create index till_layouts_workspace on public.till_layouts (workspace_id);

-- The widget catalogue: each kind's wire word and the smallest span it is usable at (TillWidgetKind).
create or replace function public.till_layout_kinds()
returns table (kind text, min_cols integer, min_rows integer) language sql immutable set search_path = public as $fn$
  values ('item_key', 1, 1), ('category_key', 1, 1), ('function_key', 1, 1), ('keypad', 2, 3), ('calculator', 2, 3),
         ('scan_field', 2, 1), ('basket', 2, 2), ('total_display', 2, 1), ('customer_note', 2, 1), ('studio_passes', 2, 2),
         ('cash_notes', 2, 1)
$fn$;
revoke execute on function public.till_layout_kinds() from public, anon;

-- The function keys: each an existing till command (TillFunction).
create or replace function public.till_layout_functions()
returns setof text language sql immutable set search_path = public as $fn$
  values ('pay_cash'), ('pay_card'), ('next_customer'), ('void_line'), ('line_discount'), ('quantity_times'),
         ('price_override'), ('deposit_return'), ('open_drawer'), ('reprint_last')
$fn$;
revoke execute on function public.till_layout_functions() from public, anon;

-- The largest layout in bytes, as tillLayoutMaxBytes: far above the largest cell cap (600 cells of a few hundred bytes).
create or replace function public.till_layout_max_bytes()
returns integer language sql immutable set search_path = public as $fn$ select 262144 $fn$;
revoke execute on function public.till_layout_max_bytes() from public, anon;

-- The largest grid side, as tillLayoutMaxGridSide.
create or replace function public.till_layout_max_grid_side()
returns integer language sql immutable set search_path = public as $fn$ select 24 $fn$;
revoke execute on function public.till_layout_max_grid_side() from public, anon;

create or replace function public.till_layout_problems(p_workspace_id uuid, p_name text, p_layout jsonb, p_max_cells integer)
returns text[] language plpgsql stable security definer set search_path = public as $fn$
declare
  v_out text[] := '{}';
  v_pages jsonb := coalesce(p_layout -> 'pages', '[]'::jsonb);
  v_page jsonb;
  v_size text;
  v_grid jsonb;
  v_cells jsonb;
  v_cell jsonb;
  v_other jsonb;
  v_cols integer;
  v_rows integer;
  v_p integer := 0;
  v_i integer;
  v_j integer;
  v_count integer := 0;
  v_c integer; v_r integer; v_cs integer; v_rs integer;
  v_min record;
  v_side integer := public.till_layout_max_grid_side();
  v_item text;
begin
  -- bounded before any walk: a layout past the byte cap or the cell cap is refused without looking at its cells, so a
  -- huge layout never costs the quadratic overlap check
  if octet_length(p_layout::text) > public.till_layout_max_bytes() then
    return array['too_large'];
  end if;
  if p_name is null or btrim(p_name) = '' then v_out := array_append(v_out, 'no_name'); end if;
  if jsonb_typeof(v_pages) <> 'array' or jsonb_array_length(v_pages) = 0 then
    return array_append(v_out, 'no_pages');
  end if;
  for v_page in select value from jsonb_array_elements(v_pages) loop
    for v_size, v_grid in select key, value from jsonb_each(coalesce(v_page -> 'grids', '{}'::jsonb)) loop
      -- every size counts, the ones this server does not know included
      v_count := v_count + case when jsonb_typeof(v_grid -> 'cells') = 'array' then jsonb_array_length(v_grid -> 'cells') else 0 end;
    end loop;
  end loop;
  if v_count > p_max_cells then return array_append(v_out, 'too_large'); end if;
  for v_page in select value from jsonb_array_elements(v_pages) loop
    if jsonb_typeof(v_page -> 'grids') is distinct from 'object' or v_page -> 'grids' = '{}'::jsonb then
      v_out := array_append(v_out, format('no_grid page %s', v_p));
    end if;
    for v_size, v_grid in select key, value from jsonb_each(coalesce(v_page -> 'grids', '{}'::jsonb)) loop
      if v_size not in ('phone', 'tablet', 'desk') then continue; end if;   -- a size this server does not know is kept, not drawn
      v_cols := (v_grid ->> 'cols')::integer;
      v_rows := (v_grid ->> 'rows')::integer;
      if v_cols is null or v_rows is null or v_cols < 1 or v_rows < 1 or v_cols > v_side or v_rows > v_side then
        v_out := array_append(v_out, format('bad_grid page %s %s', v_p, v_size));
        continue;
      end if;
      v_cells := case when jsonb_typeof(v_grid -> 'cells') = 'array' then v_grid -> 'cells' else '[]'::jsonb end;
      for v_i in 0 .. jsonb_array_length(v_cells) - 1 loop
        v_cell := v_cells -> v_i;
        v_c := coalesce((v_cell ->> 'col')::integer, 0);
        v_r := coalesce((v_cell ->> 'row')::integer, 0);
        v_cs := coalesce((v_cell ->> 'col_span')::integer, 1);
        v_rs := coalesce((v_cell ->> 'row_span')::integer, 1);
        select * into v_min from public.till_layout_kinds() k where k.kind = v_cell ->> 'kind';
        if not found then
          v_out := array_append(v_out, format('unknown_kind page %s %s cell %s', v_p, v_size, v_i));
          v_min := null;
        end if;
        if v_c < 0 or v_r < 0 or v_cs < 1 or v_rs < 1 or v_c + v_cs > v_cols or v_r + v_rs > v_rows then
          v_out := array_append(v_out, format('outside_grid page %s %s cell %s', v_p, v_size, v_i));
        elsif v_min is not null and (v_cs < v_min.min_cols or v_rs < v_min.min_rows) then
          v_out := array_append(v_out, format('too_small page %s %s cell %s', v_p, v_size, v_i));
        end if;
        for v_j in 0 .. v_i - 1 loop
          v_other := v_cells -> v_j;
          if v_c < coalesce((v_other ->> 'col')::integer, 0) + coalesce((v_other ->> 'col_span')::integer, 1)
             and coalesce((v_other ->> 'col')::integer, 0) < v_c + v_cs
             and v_r < coalesce((v_other ->> 'row')::integer, 0) + coalesce((v_other ->> 'row_span')::integer, 1)
             and coalesce((v_other ->> 'row')::integer, 0) < v_r + v_rs then
            v_out := array_append(v_out, format('overlap page %s %s cell %s', v_p, v_size, v_i));
          end if;
        end loop;
        if v_cell ->> 'kind' = 'function_key'
           and coalesce(v_cell #>> '{params,function}', '') not in (select f from public.till_layout_functions() f) then
          v_out := array_append(v_out, format('unknown_function page %s %s cell %s', v_p, v_size, v_i));
        end if;
        if v_cell ->> 'kind' = 'item_key' then
          v_item := v_cell #>> '{params,item_id}';
          if v_item is null or v_item !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
             or not exists (select 1 from public.services s where s.id = v_item::uuid and s.workspace_id = p_workspace_id) then
            v_out := array_append(v_out, format('unknown_item page %s %s cell %s', v_p, v_size, v_i));
          end if;
        end if;
      end loop;
    end loop;
    v_p := v_p + 1;
  end loop;
  return v_out;
end
$fn$;
revoke execute on function public.till_layout_problems(uuid, text, jsonb, integer) from public, anon, authenticated;

-- The widget catalogue: each kind's wire word and the smallest span it is usable at (TillWidgetKind).
create or replace function public.till_layout_kinds()
returns table (kind text, min_cols integer, min_rows integer) language sql immutable set search_path = public as $fn$
  values ('item_key', 1, 1), ('category_key', 1, 1), ('function_key', 1, 1), ('keypad', 2, 3), ('calculator', 2, 3),
         ('scan_field', 2, 1), ('basket', 2, 2), ('total_display', 2, 1), ('customer_note', 2, 1), ('studio_passes', 2, 2),
         ('cash_notes', 2, 1)
$fn$;
revoke execute on function public.till_layout_kinds() from public, anon, authenticated;

-- The function keys: each an existing till command (TillFunction).
create or replace function public.till_layout_functions()
returns setof text language sql immutable set search_path = public as $fn$
  values ('pay_cash'), ('pay_card'), ('next_customer'), ('void_line'), ('line_discount'), ('quantity_times'),
         ('price_override'), ('deposit_return'), ('open_drawer'), ('reprint_last')
$fn$;
revoke execute on function public.till_layout_functions() from public, anon, authenticated;

-- The largest layout in bytes, as tillLayoutMaxBytes: far above the largest cell cap (600 cells of a few hundred bytes).
create or replace function public.till_layout_max_bytes()
returns integer language sql immutable set search_path = public as $fn$ select 262144 $fn$;
revoke execute on function public.till_layout_max_bytes() from public, anon, authenticated;

-- The largest grid side, as tillLayoutMaxGridSide.
create or replace function public.till_layout_max_grid_side()
returns integer language sql immutable set search_path = public as $fn$ select 24 $fn$;
revoke execute on function public.till_layout_max_grid_side() from public, anon, authenticated;

create or replace function public.till_layout_problems(p_workspace_id uuid, p_name text, p_layout jsonb, p_max_cells integer)
returns text[] language plpgsql stable security definer set search_path = public as $fn$
declare
  v_out text[] := '{}';
  v_pages jsonb := coalesce(p_layout -> 'pages', '[]'::jsonb);
  v_page jsonb;
  v_size text;
  v_grid jsonb;
  v_cells jsonb;
  v_cell jsonb;
  v_other jsonb;
  v_cols integer;
  v_rows integer;
  v_p integer := 0;
  v_i integer;
  v_j integer;
  v_count integer := 0;
  v_c integer; v_r integer; v_cs integer; v_rs integer;
  v_min record;
  v_side integer := public.till_layout_max_grid_side();
  v_item text;
begin
  -- bounded before any walk: a layout past the byte cap or the cell cap is refused without looking at its cells, so a
  -- huge layout never costs the quadratic overlap check
  if octet_length(p_layout::text) > public.till_layout_max_bytes() then
    return array['too_large'];
  end if;
  if p_name is null or btrim(p_name) = '' then v_out := array_append(v_out, 'no_name'); end if;
  if jsonb_typeof(v_pages) <> 'array' or jsonb_array_length(v_pages) = 0 then
    return array_append(v_out, 'no_pages');
  end if;
  for v_page in select value from jsonb_array_elements(v_pages) loop
    for v_size, v_grid in select key, value from jsonb_each(coalesce(v_page -> 'grids', '{}'::jsonb)) loop
      -- every size counts, the ones this server does not know included
      v_count := v_count + case when jsonb_typeof(v_grid -> 'cells') = 'array' then jsonb_array_length(v_grid -> 'cells') else 0 end;
    end loop;
  end loop;
  if v_count > p_max_cells then return array_append(v_out, 'too_large'); end if;
  for v_page in select value from jsonb_array_elements(v_pages) loop
    if jsonb_typeof(v_page -> 'grids') is distinct from 'object' or v_page -> 'grids' = '{}'::jsonb then
      v_out := array_append(v_out, format('no_grid page %s', v_p));
    end if;
    for v_size, v_grid in select key, value from jsonb_each(coalesce(v_page -> 'grids', '{}'::jsonb)) loop
      if v_size not in ('phone', 'tablet', 'desk') then continue; end if;   -- a size this server does not know is kept, not drawn
      v_cols := (v_grid ->> 'cols')::integer;
      v_rows := (v_grid ->> 'rows')::integer;
      if v_cols is null or v_rows is null or v_cols < 1 or v_rows < 1 or v_cols > v_side or v_rows > v_side then
        v_out := array_append(v_out, format('bad_grid page %s %s', v_p, v_size));
        continue;
      end if;
      v_cells := case when jsonb_typeof(v_grid -> 'cells') = 'array' then v_grid -> 'cells' else '[]'::jsonb end;
      for v_i in 0 .. jsonb_array_length(v_cells) - 1 loop
        v_cell := v_cells -> v_i;
        v_c := coalesce((v_cell ->> 'col')::integer, 0);
        v_r := coalesce((v_cell ->> 'row')::integer, 0);
        v_cs := coalesce((v_cell ->> 'col_span')::integer, 1);
        v_rs := coalesce((v_cell ->> 'row_span')::integer, 1);
        select * into v_min from public.till_layout_kinds() k where k.kind = v_cell ->> 'kind';
        if not found then
          v_out := array_append(v_out, format('unknown_kind page %s %s cell %s', v_p, v_size, v_i));
          v_min := null;
        end if;
        if v_c < 0 or v_r < 0 or v_cs < 1 or v_rs < 1 or v_c + v_cs > v_cols or v_r + v_rs > v_rows then
          v_out := array_append(v_out, format('outside_grid page %s %s cell %s', v_p, v_size, v_i));
        elsif v_min is not null and (v_cs < v_min.min_cols or v_rs < v_min.min_rows) then
          v_out := array_append(v_out, format('too_small page %s %s cell %s', v_p, v_size, v_i));
        end if;
        for v_j in 0 .. v_i - 1 loop
          v_other := v_cells -> v_j;
          if v_c < coalesce((v_other ->> 'col')::integer, 0) + coalesce((v_other ->> 'col_span')::integer, 1)
             and coalesce((v_other ->> 'col')::integer, 0) < v_c + v_cs
             and v_r < coalesce((v_other ->> 'row')::integer, 0) + coalesce((v_other ->> 'row_span')::integer, 1)
             and coalesce((v_other ->> 'row')::integer, 0) < v_r + v_rs then
            v_out := array_append(v_out, format('overlap page %s %s cell %s', v_p, v_size, v_i));
          end if;
        end loop;
        if v_cell ->> 'kind' = 'function_key'
           and coalesce(v_cell #>> '{params,function}', '') not in (select f from public.till_layout_functions() f) then
          v_out := array_append(v_out, format('unknown_function page %s %s cell %s', v_p, v_size, v_i));
        end if;
        if v_cell ->> 'kind' = 'item_key' then
          v_item := v_cell #>> '{params,item_id}';
          if v_item is null or v_item !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
             or not exists (select 1 from public.services s where s.id = v_item::uuid and s.workspace_id = p_workspace_id) then
            v_out := array_append(v_out, format('unknown_item page %s %s cell %s', v_p, v_size, v_i));
          end if;
        end if;
      end loop;
    end loop;
    v_p := v_p + 1;
  end loop;
  return v_out;
end
$fn$;
revoke execute on function public.till_layout_problems(uuid, text, jsonb, integer) from public, anon, authenticated;

alter table public.till_layouts enable row level security;
revoke all on public.till_layouts from public, anon, authenticated;
grant select on public.till_layouts to authenticated;
create policy mcp_delegated_deny on public.till_layouts as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- published layouts are read by who sells at the till and by who lays it out; drafts only by who lays it out
create policy till_layouts_select on public.till_layouts for select to authenticated
  using (public.feature_effective(workspace_id, 'counterTillLayout')
         and (workspace_id in (select public.workspaces_permitting(array['configureTill']))
              or (status = 'published' and workspace_id in (select public.workspaces_permitting(array['issueInvoices'])))));

create or replace function public.till_layout_save_v1(
  p_workspace_id uuid,
  p_request_id uuid,
  p_till_id uuid,
  p_name text,
  p_expected_version integer,
  p_layout jsonb
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_row public.till_layouts%rowtype;
  v_problems text[];
  v_digest text := md5(concat_ws('|', p_till_id, p_name, p_expected_version, p_layout::text));
  v_done jsonb;
begin
  perform public.command_actor(p_workspace_id, 'configureTill', 'counterTillLayout', 'not allowed to lay out the tills',
    'till layouts are off in this business', 'DKG01');
  v_done := public.request_begin(p_workspace_id, p_request_id, 'till_layout_save', v_digest);
  if v_done is not null then
    return v_done || '{"replayed": true}'::jsonb;
  end if;
  if not exists (select 1 from public.counter_tills t where t.id = p_till_id and t.workspace_id = p_workspace_id) then
    raise exception 'no such till in this business' using errcode = 'DKL02', detail = '{"reason": "till"}';
  end if;
  -- one editor at a time per till: the second waits here and then meets the version the first wrote
  perform pg_advisory_xact_lock(hashtextextended('till_layout:' || p_till_id::text, 0));
  select * into v_row from public.till_layouts where till_id = p_till_id and status = 'draft';
  if coalesce(v_row.version, 0) <> coalesce(p_expected_version, 0) then
    raise exception 'someone changed this layout: reload it' using errcode = 'DKL10', detail = '{"reason": "version"}';
  end if;
  v_problems := public.till_layout_problems(p_workspace_id, p_name, p_layout,
    coalesce((public.setting_value(p_workspace_id, 'counter.layout_max_cells') #>> '{}')::integer, 200));
  if cardinality(v_problems) > 0 then
    raise exception 'this layout cannot be saved' using errcode = 'DKL02', detail = jsonb_build_object('reason', v_problems[1])::text;
  end if;
  if v_row.id is null then
    insert into public.till_layouts (workspace_id, till_id, name, version, status, layout)
    values (p_workspace_id, p_till_id, btrim(p_name), 1, 'draft', p_layout)
    returning * into v_row;
  else
    update public.till_layouts set name = btrim(p_name), layout = p_layout, version = version + 1
     where id = v_row.id returning * into v_row;
  end if;
  return public.request_finish(p_workspace_id, p_request_id, 'till_layout_save', v_digest,
    jsonb_build_object('id', v_row.id, 'version', v_row.version)) || '{"replayed": false}'::jsonb;
end
$fn$;
revoke execute on function public.till_layout_save_v1(uuid, uuid, uuid, text, integer, jsonb) from public, anon;
grant execute on function public.till_layout_save_v1(uuid, uuid, uuid, text, integer, jsonb) to authenticated;

create or replace function public.till_layout_publish_v1(
  p_workspace_id uuid,
  p_request_id uuid,
  p_till_id uuid,
  p_expected_version integer
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_draft public.till_layouts%rowtype;
  v_pub public.till_layouts%rowtype;
  v_problems text[];
  v_digest text := md5(concat_ws('|', p_till_id, p_expected_version));
  v_done jsonb;
begin
  perform public.command_actor(p_workspace_id, 'configureTill', 'counterTillLayout', 'not allowed to lay out the tills',
    'till layouts are off in this business', 'DKG01');
  v_done := public.request_begin(p_workspace_id, p_request_id, 'till_layout_publish', v_digest);
  if v_done is not null then
    return v_done || '{"replayed": true}'::jsonb;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('till_layout:' || p_till_id::text, 0));
  select * into v_draft from public.till_layouts where till_id = p_till_id and status = 'draft' and workspace_id = p_workspace_id;
  if v_draft.id is null or v_draft.version <> p_expected_version then
    raise exception 'someone changed this layout: reload it' using errcode = 'DKL10', detail = '{"reason": "version"}';
  end if;
  -- the items may have changed since the draft was saved: the published layout meets the rules today
  v_problems := public.till_layout_problems(p_workspace_id, v_draft.name, v_draft.layout,
    coalesce((public.setting_value(p_workspace_id, 'counter.layout_max_cells') #>> '{}')::integer, 200));
  if cardinality(v_problems) > 0 then
    raise exception 'this layout cannot be published' using errcode = 'DKL02', detail = jsonb_build_object('reason', v_problems[1])::text;
  end if;
  select * into v_pub from public.till_layouts where till_id = p_till_id and status = 'published' and workspace_id = p_workspace_id;
  if v_pub.id is null then
    insert into public.till_layouts (workspace_id, till_id, name, version, status, layout)
    values (p_workspace_id, p_till_id, v_draft.name, 1, 'published', v_draft.layout)
    returning * into v_pub;
  else
    update public.till_layouts set name = v_draft.name, layout = v_draft.layout, version = version + 1
     where id = v_pub.id returning * into v_pub;
  end if;
  return public.request_finish(p_workspace_id, p_request_id, 'till_layout_publish', v_digest,
    jsonb_build_object('id', v_pub.id, 'version', v_pub.version)) || '{"replayed": false}'::jsonb;
end
$fn$;
revoke execute on function public.till_layout_publish_v1(uuid, uuid, uuid, integer) from public, anon;
grant execute on function public.till_layout_publish_v1(uuid, uuid, uuid, integer) to authenticated;

-- ── the builtin association template writes the feature flags: it names counterTillLayout (dart run tool/build_builtin_templates.dart) ──
-- restates 0951
insert into public.workspace_templates
  (key, name, description, sort_order, visibility, schema_version, template_version,
   tags, entities, configuration, floor_plan)
values (
  'association_fr',
  'Association de coworking (France)',
  'Pour une association de coworking en France : demi-journées de 7 h à 13 h et de 13 h à 19 h du lundi au vendredi, jours fériés de l''année et de la suivante, cotisations à 50 % et 100 %, deux carnets prépayés pour qui ne cotise pas, les rôles du bureau, un calendrier où se prennent les validations, les mots de l''association, et deux étages prêts à réserver.',
  1,
  'builtin',
  1,
  1,
  array['association', 'coworking', 'france'],
  array['identity', 'tariffs', 'credit_products', 'floor_plan', 'booking_rules', 'closure_days', 'lexicon', 'workspace_roles', 'features'],
  $cfg${
  "workspace": {
    "default_locale": "fr",
    "vat_regime": "not_subject",
    "booking_rules": {
      "granularity": "half_day",
      "open_weekdays": [
        1,
        2,
        3,
        4,
        5
      ],
      "work_start_minutes": 420,
      "half_boundary_minutes": 780,
      "work_end_minutes": 1140,
      "max_series_days": 180,
      "advance_horizon_days": 90,
      "max_duration_minutes": 1440,
      "min_duration_minutes": 30
    },
    "subscription_levels": {
      "allow_custom": false,
      "extra_levels": [],
      "enabled_presets": [
        50,
        100
      ]
    },
    "feature_flags": {
      "accessorySupplements": false,
      "accountingBook": false,
      "accountingConnectors": false,
      "accountingPeriods": false,
      "adminInvoicing": false,
      "adminLevelAssign": false,
      "adminSeatBlocking": false,
      "assetRegister": false,
      "autoCheckInOut": false,
      "badgeSignIn": false,
      "bankImport": false,
      "biReportDesigner": false,
      "billingCustomers": false,
      "bookForOthers": true,
      "bookingGate": true,
      "bookingPolicies": true,
      "calendarFileExport": true,
      "calendarHub": true,
      "calendarTab": true,
      "calendarValidations": true,
      "calendarViews": true,
      "capacityKpi": false,
      "captureProtection": true,
      "carnets": true,
      "coOwner": false,
      "configurableSettings": false,
      "configurationTransfer": false,
      "counterOfflineCash": false,
      "counterReceipts": false,
      "counterTillLayout": false,
      "counterTillSessions": false,
      "customFields": false,
      "customRoles": true,
      "customerQuotes": false,
      "dataAccessLog": false,
      "dataExport": true,
      "dataReport": true,
      "decisionSurface": false,
      "deletionRequests": true,
      "demoMode": false,
      "deployments": false,
      "documents": true,
      "dunning": false,
      "einvoiceCustomerDelivery": false,
      "environmentPairs": false,
      "eventsTab": false,
      "expenseRepartition": false,
      "expenseRepartitionWizard": false,
      "externalRooms": false,
      "financeFaces": true,
      "foreignCurrencyPurchases": false,
      "formHelpHints": true,
      "guestParticipation": false,
      "guestPasses": false,
      "holidayImport": false,
      "inputVat": false,
      "instanceWizard": false,
      "invoiceAddressWindow": false,
      "invoiceEmail": false,
      "invoiceJourney": false,
      "invoicePdfTemplate": false,
      "invoiceSettlement": false,
      "invoicing": true,
      "invoicingWizard": false,
      "kioskEnrolment": false,
      "kioskMemberPhotos": false,
      "kioskMode": false,
      "letterStandard": false,
      "levelBooking": false,
      "managedProfileAccess": false,
      "managedProfiles": false,
      "mcpAccess": false,
      "meetingRooms": false,
      "memberAccountMenu": false,
      "memberDataExport": true,
      "memberEnvironments": false,
      "memberGettingStarted": true,
      "memberNotifications": true,
      "memberOrigin": false,
      "memberPage": false,
      "memberPaymentTerms": false,
      "memberReports": false,
      "membersDirectory": false,
      "messageForwarding": true,
      "messageGestures": true,
      "messageMentions": true,
      "messagesHub": true,
      "moneyTab": true,
      "mtdSubmission": false,
      "multiSite": false,
      "navigationStyle": true,
      "nfcBadges": false,
      "nfcSeatTags": false,
      "notificationGrouping": false,
      "numberSequences": false,
      "onlinePayments": false,
      "organisation": true,
      "parking": false,
      "paymentReminders": false,
      "pdfExport": true,
      "personalInfo": true,
      "personalShell": false,
      "placeBooking": true,
      "placeFeedback": true,
      "planDecor": true,
      "planMemberPhotos": false,
      "planObjectDelete": true,
      "premisesLease": false,
      "priceNegotiations": false,
      "publicHolidays": false,
      "publicListings": false,
      "purchaseAnalytics": false,
      "purchaseOrders": false,
      "purchases": false,
      "pushNotifications": true,
      "qrBadges": false,
      "quickSearch": true,
      "recapitulativeStatement": false,
      "recordingPrivacy": false,
      "regionalFormats": true,
      "reminderEmail": false,
      "reportDesignExchange": false,
      "reportDesigner": false,
      "reportLayouts": false,
      "reportTexts": false,
      "richMessageRefs": true,
      "roleAssignment": true,
      "roleManagement": true,
      "salesTax": false,
      "scheduledExpenses": false,
      "seatDayTimeline": true,
      "seriesBooking": true,
      "serviceFulfilment": false,
      "services": true,
      "settlementFold": false,
      "setupGuide": true,
      "singleRoomLevelNames": true,
      "spaceInquiries": true,
      "spaceQrCodes": true,
      "standaloneInvoicing": false,
      "stockCounts": false,
      "stockCycleCounts": false,
      "stockExpiryReport": false,
      "stockHandlingUnits": false,
      "stockItemGroups": false,
      "stockLots": false,
      "stockManagement": false,
      "stockReceiving": false,
      "stockReorder": false,
      "stockReturns": false,
      "stockScanning": false,
      "stockTagReads": false,
      "stockTags": false,
      "stockTakeOut": false,
      "subscriptionInvoices": false,
      "supplyClassification": false,
      "supplyExpenses": false,
      "taskRecorder": false,
      "uiAnimations": true,
      "uniqueMonograms": true,
      "unitsOfMeasure": false,
      "usageInvoices": false,
      "usageRecords": false,
      "usageReport": false,
      "validationChain": false,
      "validationScopes": false,
      "vatCounterparty": false,
      "vatDeclarations": false,
      "vatGroups": false,
      "vatManagement": false,
      "vatRateHistory": false,
      "vatReport": false,
      "viesVerification": false,
      "webMcp": false,
      "whatsappIntegration": false,
      "workingHours": true,
      "workspaceBranding": false,
      "workspaceLibrary": false,
      "workspaceOverview": false,
      "workspaceStatus": false,
      "workspaceVocabulary": true
    },
    "lexicon": {
      "fr": {
        "spaceKindSeat": "Place",
        "spaceKindLevel": "Étage",
        "shellReserveButton": "Réservations"
      }
    }
  },
  "tables": {
    "fee_bands": [
      {
        "from_pct": 0,
        "to_pct": 50,
        "fee_cents": 5000,
        "overage_fee_cents": 0
      },
      {
        "from_pct": 50,
        "to_pct": 100,
        "fee_cents": 10000,
        "overage_fee_cents": 0
      }
    ],
    "workspace_roles": [
      {
        "key": "tresorier",
        "names": {
          "fr": "Trésorier·ère",
          "en": "Treasurer",
          "de": "Kassenwart",
          "es": "Tesorero/a",
          "it": "Tesoriere"
        },
        "permissions": [
          "viewFinances",
          "issueInvoices",
          "manageBilling",
          "approveExpenses",
          "exportData"
        ],
        "sort_order": 1,
        "active": true
      },
      {
        "key": "secretaire",
        "names": {
          "fr": "Secrétaire",
          "en": "Secretary",
          "de": "Schriftführer",
          "es": "Secretario/a",
          "it": "Segretario"
        },
        "permissions": [
          "manageMembers",
          "manageDocuments",
          "viewPersonalData"
        ],
        "sort_order": 2,
        "active": true
      },
      {
        "key": "referent_salle",
        "names": {
          "fr": "Référent·e de salle",
          "en": "Room steward",
          "de": "Raumverantwortlicher",
          "es": "Responsable de sala",
          "it": "Referente di sala"
        },
        "permissions": [
          "manageReservations",
          "manageValidation",
          "operateKiosk"
        ],
        "sort_order": 3,
        "active": true
      }
    ],
    "credit_products": [
      {
        "name": "Carnet 10 demi-journées",
        "half_days": 10,
        "price_cents": 5000,
        "validity_months": null,
        "active": true,
        "sort_order": 1
      },
      {
        "name": "Carnet 20 demi-journées",
        "half_days": 20,
        "price_cents": 8000,
        "validity_months": null,
        "active": true,
        "sort_order": 2
      }
    ]
  },
  "holidays": {
    "years": 2
  }
}$cfg$::jsonb,
  $tpl$[
  {
    "name": "Rez-de-chaussée",
    "sort_order": 0,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": [
      {
        "name": "Salle principale",
        "color": 0,
        "bookable_as_whole": true,
        "price_cents": 0,
        "x": 0,
        "y": 0,
        "w": 40,
        "h": 24,
        "desks": [
          {
            "name": "Table 1",
            "x": 2,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "A1",
                "x": 4,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "A2",
                "x": 12,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          },
          {
            "name": "Table 2",
            "x": 22,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "B1",
                "x": 24,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "B2",
                "x": 32,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          }
        ]
      }
    ]
  },
  {
    "name": "Étage",
    "sort_order": 1,
    "bookable_as_whole": false,
    "price_cents": 0,
    "background_path": "",
    "site": null,
    "images": [],
    "offices": [
      {
        "name": "Salle du haut",
        "color": 0,
        "bookable_as_whole": true,
        "price_cents": 0,
        "x": 0,
        "y": 0,
        "w": 40,
        "h": 24,
        "desks": [
          {
            "name": "Table 3",
            "x": 2,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "C1",
                "x": 4,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "C2",
                "x": 12,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          },
          {
            "name": "Table 4",
            "x": 22,
            "y": 2,
            "w": 14,
            "h": 8,
            "bookable_as_whole": true,
            "price_cents": 0,
            "seats": [
              {
                "name": "D1",
                "x": 24,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              },
              {
                "name": "D2",
                "x": 32,
                "y": 4,
                "orientation": "n",
                "chair": "standard",
                "amenities": [],
                "accessories": []
              }
            ]
          }
        ]
      }
    ]
  }
]$tpl$::jsonb
)
on conflict (key) where owner_workspace_id is null do update
  set name = excluded.name,
      description = excluded.description,
      sort_order = excluded.sort_order,
      schema_version = excluded.schema_version,
      template_version = public.workspace_templates.template_version + 1,
      tags = excluded.tags,
      entities = excluded.entities,
      configuration = excluded.configuration,
      floor_plan = excluded.floor_plan;

select public.set_deskilo_schema_version(959);
