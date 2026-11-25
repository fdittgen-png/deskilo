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
  if p_name is null or btrim(p_name) = '' then v_out := array_append(v_out, 'no_name'); end if;
  if jsonb_typeof(v_pages) <> 'array' or jsonb_array_length(v_pages) = 0 then
    return array_append(v_out, 'no_pages');
  end if;
  for v_page in select value from jsonb_array_elements(v_pages) loop
    for v_size, v_grid in select key, value from jsonb_each(coalesce(v_page -> 'grids', '{}'::jsonb)) loop
      v_count := v_count + coalesce(jsonb_array_length(v_grid -> 'cells'), 0);
    end loop;
  end loop;
  if v_count > p_max_cells then v_out := array_append(v_out, 'too_large'); end if;
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
      v_cells := coalesce(v_grid -> 'cells', '[]'::jsonb);
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

-- TODO(#4448, registry): the select policy, till_layout_save_v1 and till_layout_publish_v1 need the configureTill right
-- and the counterTillLayout flag; they land with the registry change.

select public.set_deskilo_schema_version(958);
