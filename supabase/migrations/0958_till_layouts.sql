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
--                                  version is refused (DKL10, "Someone changed this layout; reload it"), an invalid
--                                  layout is refused with its first problem (DKL02), the right configureTill (DKN01) and
--                                  the flag counterTillLayout (DKG01) are checked first. Answers the draft's id and version.
--   till_layout_publish_v1         the draft at the version the editor read becomes the till's published layout. A till
--                                  session already open keeps what it loaded until it loads again (the app's rule).
--   configureTill                  a new right, an admin default: role_permission_catalog, has_permission_raw and
--                                  member_permission_raw restated from their live definitions with it added.
--   counterTillLayout              a new flag under counterTillSessions (the issue's `counterTill` parent does not
--                                  exist); counter.layout_max_cells and counter.layout_cashier_reorder, two settings.
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('counter.layout_max_cells', 'int', '200'::jsonb, 20, 600, 'cells', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'till layouts (#4448)', 'The most cells one till layout may hold, over all its pages and its phone, tablet and desk grids together. A larger layout is refused when it is saved; the tills already published keep theirs.'),
('counter.layout_cashier_reorder', 'bool', 'false'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'till layouts (#4448)', 'Whether a cashier may reorder the keys of a till on their own device, without changing the published layout. Off: every device shows the layout as it was published.')
on conflict (key) do nothing;
-- END GENERATED SEED

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

alter table public.till_layouts add column last_request_id uuid;

create or replace function public.till_layout_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to lay out the tills' using errcode = 'DKN01';
  end if;
  if not public.has_permission(p_workspace_id, 'configureTill') then
    raise exception 'not allowed to lay out the tills' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'counterTillLayout') then
    raise exception 'till layouts are off in this business' using errcode = 'DKG01';
  end if;
  return auth.uid();
end
$fn$;
revoke execute on function public.till_layout_actor(uuid) from public, anon, authenticated;

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
  v_cap integer;
begin
  perform public.till_layout_actor(p_workspace_id);
  if p_request_id is null then
    raise exception 'a request id is needed' using errcode = 'DKL02', detail = 'request_id';
  end if;
  if not exists (select 1 from public.counter_tills t where t.id = p_till_id and t.workspace_id = p_workspace_id) then
    raise exception 'no such till in this business' using errcode = 'DKL02', detail = 'till';
  end if;
  -- one editor at a time per till: the second waits here and then meets the version the first wrote
  perform pg_advisory_xact_lock(hashtextextended('till_layout:' || p_till_id::text, 0));
  select * into v_row from public.till_layouts where till_id = p_till_id and status = 'draft';
  if found and v_row.last_request_id = p_request_id then
    return jsonb_build_object('id', v_row.id, 'version', v_row.version, 'replayed', true);
  end if;
  if coalesce(v_row.version, 0) <> coalesce(p_expected_version, 0) then
    raise exception 'Someone changed this layout; reload it' using errcode = 'DKL10', detail = 'version';
  end if;
  v_cap := coalesce((public.setting_value(p_workspace_id, 'counter.layout_max_cells') #>> '{}')::integer, 200);
  v_problems := public.till_layout_problems(p_workspace_id, p_name, p_layout, v_cap);
  if cardinality(v_problems) > 0 then
    raise exception 'this layout cannot be saved: %', v_problems[1] using errcode = 'DKL02', detail = v_problems[1];
  end if;
  if v_row.id is null then
    insert into public.till_layouts (workspace_id, till_id, name, version, status, layout, last_request_id)
    values (p_workspace_id, p_till_id, btrim(p_name), 1, 'draft', p_layout, p_request_id)
    returning * into v_row;
  else
    update public.till_layouts set name = btrim(p_name), layout = p_layout, version = version + 1, last_request_id = p_request_id
     where id = v_row.id returning * into v_row;
  end if;
  return jsonb_build_object('id', v_row.id, 'version', v_row.version, 'replayed', false);
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
begin
  perform public.till_layout_actor(p_workspace_id);
  perform pg_advisory_xact_lock(hashtextextended('till_layout:' || p_till_id::text, 0));
  select * into v_pub from public.till_layouts where till_id = p_till_id and status = 'published' and workspace_id = p_workspace_id;
  if found and v_pub.last_request_id = p_request_id then
    return jsonb_build_object('id', v_pub.id, 'version', v_pub.version, 'replayed', true);
  end if;
  select * into v_draft from public.till_layouts where till_id = p_till_id and status = 'draft' and workspace_id = p_workspace_id;
  if not found or v_draft.version <> p_expected_version then
    raise exception 'Someone changed this layout; reload it' using errcode = 'DKL10', detail = 'version';
  end if;
  -- the items may have changed since the draft was saved: the published layout meets the rules today
  v_problems := public.till_layout_problems(p_workspace_id, v_draft.name, v_draft.layout,
    coalesce((public.setting_value(p_workspace_id, 'counter.layout_max_cells') #>> '{}')::integer, 200));
  if cardinality(v_problems) > 0 then
    raise exception 'this layout cannot be published: %', v_problems[1] using errcode = 'DKL02', detail = v_problems[1];
  end if;
  if v_pub.id is null then
    insert into public.till_layouts (workspace_id, till_id, name, version, status, layout, last_request_id)
    values (p_workspace_id, p_till_id, v_draft.name, 1, 'published', v_draft.layout, p_request_id)
    returning * into v_pub;
  else
    update public.till_layouts set name = v_draft.name, layout = v_draft.layout, version = version + 1, last_request_id = p_request_id
     where id = v_pub.id returning * into v_pub;
  end if;
  return jsonb_build_object('id', v_pub.id, 'version', v_pub.version, 'replayed', false);
end
$fn$;
revoke execute on function public.till_layout_publish_v1(uuid, uuid, uuid, integer) from public, anon;
grant execute on function public.till_layout_publish_v1(uuid, uuid, uuid, integer) to authenticated;

-- BEGIN FEATURE REGISTRY ROWS (dart run tool/build_feature_registry_sql.dart)
insert into public.feature_registry_entries (feature_key, parent, default_on, core, countries) values
('counterTillLayout', 'counterTillSessions', false, false, null)
on conflict (feature_key) do update set parent = excluded.parent, default_on = excluded.default_on, core = excluded.core, countries = excluded.countries;
-- END FEATURE REGISTRY ROWS

-- configureTill: the catalog, restated whole from its live definition with the new right appended
create or replace function public.role_permission_catalog()
 returns text[]
 language sql
 immutable
as $function$
  select array[
    'manageRoles','manageMembers','manageValidation','workspaceSettings',
    'issueInvoices','viewFinances','manageDocuments','manageServices',
    'approveExpenses','viewNegotiations','manageNegotiations','paymentTermsEdit',
    'manageSites','manageBilling','manageReservations','operateKiosk','exportData',
    'designDocuments','viewPersonalData','manageIntegrations','manageConfiguration',
    'deployToProd','deployToDev','accessProd','viewAnalytics',
    'useMessages','makeReservations','viewCalendar','viewDirectory',
    'viewMyMoney','viewDocuments','managePurchases','recordOutgoingPayments',
    'manageLease','managePrivacy','viewStock','manageStock','approveStockAdjustments',
    'manageBillingCustomers','countStock','configureTill'];
$function$;

-- configureTill is an admin default: both readers of the admin defaults, restated from their live definitions with it added
create or replace function public.has_permission_raw(ws uuid, perm text)
 returns boolean
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select exists (
    select 1 from public.members m join public.workspaces w on w.id = ws
     where m.workspace_id = ws and m.user_id = auth.uid() and m.status = 'active'
       and public.feature_effective_in(w.feature_flags, 'customRoles')
       and perm = any(public.member_custom_permissions(m.id)))
  or exists (
    select 1 from public.members m join public.workspaces w on w.id = ws
    where m.workspace_id = ws and m.user_id = auth.uid() and m.status = 'active'
      and ( m.is_owner
        or (m.co_owner = 'active' and (case when w.role_permissions ? 'co_owner' then w.role_permissions->'co_owner' ? perm else true end))
        or (m.is_admin and (
             (case when w.role_permissions ? 'admin' then w.role_permissions->'admin' ? perm
                   else perm in ('manageMembers','manageDocuments','manageServices','approveExpenses',
                                 'viewFinances','viewNegotiations','manageNegotiations','paymentTermsEdit',
                                 'manageSites','manageReservations','operateKiosk','exportData','viewPersonalData',
                                 'deployToDev','accessProd','viewAnalytics','configureTill') end)
             or (perm = 'issueInvoices' and public.feature_effective_in(w.feature_flags, 'adminInvoicing'))))
        or (not m.is_admin and not m.is_owner and m.co_owner <> 'active' and w.role_permissions ? 'member' and w.role_permissions->'member' ? perm)));
$function$;

create or replace function public.member_permission_raw(p_member_id uuid, perm text)
 returns boolean
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select exists (
    select 1 from public.members m join public.workspaces w on w.id = m.workspace_id
     where m.id = p_member_id and m.status = 'active'
       and public.feature_effective_in(w.feature_flags, 'customRoles')
       and perm = any(public.member_custom_permissions(m.id)))
  or exists (
    select 1 from public.members m join public.workspaces w on w.id = m.workspace_id
    where m.id = p_member_id and m.status = 'active'
      and ( m.is_owner
        or (m.co_owner = 'active' and (case when w.role_permissions ? 'co_owner' then w.role_permissions->'co_owner' ? perm else true end))
        or (m.is_admin and (
             (case when w.role_permissions ? 'admin' then w.role_permissions->'admin' ? perm
                   else perm in ('manageMembers','manageDocuments','manageServices','approveExpenses',
                                 'viewFinances','viewNegotiations','manageNegotiations','paymentTermsEdit',
                                 'manageSites','manageReservations','operateKiosk','exportData','viewPersonalData',
                                 'deployToDev','accessProd','viewAnalytics','configureTill') end)
             or (perm = 'issueInvoices' and public.feature_effective_in(w.feature_flags, 'adminInvoicing'))))
        or (not m.is_admin and not m.is_owner and m.co_owner <> 'active' and w.role_permissions ? 'member' and w.role_permissions->'member' ? perm)));
$function$;

create or replace function public.template_field_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select $json$[
    {"id":"floor_plan[].background_path","entity":"floor_plan","type":"text","portability":"never","absent":"inherit","key":"name","reason":"a storage file of the source","process":"spaceManagement"},
    {"id":"floor_plan[].bookable_as_whole","entity":"floor_plan","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].images","entity":"floor_plan","type":"text","portability":"never","absent":"inherit","key":"name","reason":"a storage file of the source","process":"spaceManagement"},
    {"id":"floor_plan[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].bookable_as_whole","entity":"floor_plan","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].color","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].bookable_as_whole","entity":"floor_plan","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].h","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].price_cents","entity":"floor_plan","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].accessories","entity":"floor_plan","type":"list","portability":"reference","absent":"inherit","key":"name","bindings":["accessories.name"],"process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].amenities","entity":"floor_plan","type":"list","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].chair","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].orientation","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].x","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].y","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].w","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].x","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].y","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].h","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].price_cents","entity":"floor_plan","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].w","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].x","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].y","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].price_cents","entity":"floor_plan","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan","process":"spaceManagement"},
    {"id":"floor_plan[].site","entity":"floor_plan","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites never travel","process":"spaceManagement"},
    {"id":"floor_plan[].sort_order","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].active","entity":"accessories","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].name","entity":"accessories","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].sort_order","entity":"accessories","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].supplement_cents","entity":"accessories","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].vat_rate","entity":"accessories","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"spaceManagement"},
    {"id":"tables.closure_days[].day","entity":"closure_days","type":"date","portability":"literal","absent":"inherit","key":"day","process":"coordination"},
    {"id":"tables.closure_days[].reason","entity":"closure_days","type":"text","portability":"literal","absent":"inherit","key":"day","process":"coordination"},
    {"id":"tables.credit_products[].active","entity":"credit_products","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].half_days","entity":"credit_products","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].name","entity":"credit_products","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].price_cents","entity":"credit_products","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].sort_order","entity":"credit_products","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].validity_months","entity":"credit_products","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].vat_rate","entity":"credit_products","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"membershipCommerce"},
    {"id":"tables.fee_bands[].fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.fee_bands[].from_pct","entity":"tariffs","type":"percent","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.fee_bands[].overage_fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.fee_bands[].to_pct","entity":"tariffs","type":"percent","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.number_sequences[].date_part","entity":"number_sequences","type":"enumeration","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].digits","entity":"number_sequences","type":"integer","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].gapless","entity":"number_sequences","type":"boolean","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].journal","entity":"number_sequences","type":"text","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].next_value","entity":"number_sequences","type":"integer","portability":"never","absent":"inherit","key":"journal","reason":"a counter (#1295)","process":"billingPayments"},
    {"id":"tables.number_sequences[].period_key","entity":"number_sequences","type":"text","portability":"never","absent":"inherit","key":"journal","reason":"a counter (#1295)","process":"billingPayments"},
    {"id":"tables.number_sequences[].prefix","entity":"number_sequences","type":"text","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].reset","entity":"number_sequences","type":"enumeration","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].suffix","entity":"number_sequences","type":"text","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.packages[].active","entity":"packages","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].days","entity":"packages","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].name","entity":"packages","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].price_cents","entity":"packages","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].vat_rate","entity":"packages","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"membershipCommerce"},
    {"id":"tables.plans[].active","entity":"tariffs","type":"boolean","portability":"never","absent":"inherit","key":"name","reason":"retired: a business's tariffs are its fee bands (#4042)","process":"membershipCommerce"},
    {"id":"tables.plans[].base_fee_cents","entity":"tariffs","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"retired: a business's tariffs are its fee bands (#4042)","process":"membershipCommerce"},
    {"id":"tables.plans[].included_half_days","entity":"tariffs","type":"integer","portability":"never","absent":"inherit","key":"name","reason":"retired: a business's tariffs are its fee bands (#4042)","process":"membershipCommerce"},
    {"id":"tables.plans[].name","entity":"tariffs","type":"text","portability":"never","absent":"inherit","key":"name","reason":"retired: a business's tariffs are its fee bands (#4042)","process":"membershipCommerce"},
    {"id":"tables.plans[].overage_fee_cents","entity":"tariffs","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"retired: a business's tariffs are its fee bands (#4042)","process":"membershipCommerce"},
    {"id":"tables.services[].active","entity":"services","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].name","entity":"services","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].price_cents","entity":"services","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].stock","entity":"services","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].vat_rate","entity":"services","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"membershipCommerce"},
    {"id":"tables.sites[].city","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].country_code","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].is_default","entity":"sites","type":"boolean","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].legal_id","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].name","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].postal_code","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].sort_order","entity":"sites","type":"integer","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].street","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].tax_exemption_reason","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].vat_id","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.validation_policies[].admins_may_validate","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].auto_validate_admin","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].auto_validate_owner","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].eligible_admin_ids","entity":"validation_rules","type":"list","portability":"never","absent":"inherit","key":"event_type","reason":"names people, who do not exist where a template is applied","process":"coordination"},
    {"id":"tables.validation_policies[].event_type","entity":"validation_rules","type":"text","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].min_amount_cents","entity":"validation_rules","type":"cents","portability":"unsupported","absent":"inherit","key":"event_type","reason":"the export does not carry it yet (#1655)","process":"coordination"},
    {"id":"tables.validation_policies[].owner_may_self_validate","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].owner_required","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].required_count","entity":"validation_rules","type":"integer","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].sequential","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].validator_scope","entity":"validation_rules","type":"enumeration","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.vat_rates[].active","entity":"vat","type":"boolean","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].category","entity":"vat","type":"enumeration","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].exemption_reason","entity":"vat","type":"text","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].group_key","entity":"vat","type":"text","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].is_default","entity":"vat","type":"boolean","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].label","entity":"vat","type":"text","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].outside_base","entity":"vat","type":"boolean","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].percent","entity":"vat","type":"decimal","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].supersedes","entity":"vat","type":"text","portability":"reference","absent":"inherit","key":"label@percent","bindings":["vat_rates.label"],"process":"billingPayments"},
    {"id":"tables.vat_rates[].valid_from","entity":"vat","type":"date","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].valid_to","entity":"vat","type":"date","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.workspace_documents[].category","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].min_role","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].provider","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].title","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].url","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_field_definitions[].active","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].contexts","entity":"field_definitions","type":"list","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].group_key","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].key","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].labels","entity":"field_definitions","type":"map","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].labels.{locale}.help_text","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].labels.{locale}.label","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options","entity":"field_definitions","type":"list","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].active","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].key","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].labels.{locale}","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].sort_order","entity":"field_definitions","type":"integer","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].personal_data","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].required","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].sort_order","entity":"field_definitions","type":"integer","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].type","entity":"field_definitions","type":"enumeration","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].validation","entity":"field_definitions","type":"map","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].visibility","entity":"field_definitions","type":"enumeration","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].active","entity":"workspace_roles","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].key","entity":"workspace_roles","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].names","entity":"workspace_roles","type":"map","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].names.{locale}","entity":"workspace_roles","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].permissions","entity":"workspace_roles","type":"list","portability":"literal","absent":"inherit","key":"key","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd","viewAnalytics","useMessages","makeReservations","viewCalendar","viewDirectory","viewMyMoney","viewDocuments","managePurchases","recordOutgoingPayments","manageLease","managePrivacy","viewStock","manageStock","approveStockAdjustments","manageBillingCustomers","countStock","configureTill"],"process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].sort_order","entity":"workspace_roles","type":"integer","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"template.description","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.entities","entity":"template","type":"list","portability":"unsupported","absent":"inherit","reason":"what the template carries","process":"operations"},
    {"id":"template.holidays.country","entity":"closure_days","type":"text","portability":"local_binding","absent":"product_default","reason":"the target's country unless the template names one","process":"coordination"},
    {"id":"template.holidays.years","entity":"closure_days","type":"integer","portability":"literal","absent":"product_default","min":1,"max":3,"depends_on":["closure_days"],"process":"coordination"},
    {"id":"template.key","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.name","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.owner_workspace_id","entity":"template","type":"text","portability":"never","absent":"inherit","reason":"who published it","process":"operations"},
    {"id":"template.schema_version","entity":"template","type":"integer","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.sort_order","entity":"template","type":"integer","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.tags","entity":"template","type":"list","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.template_version","entity":"template","type":"integer","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.visibility","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"workspace.accessory_supplements_since","entity":"workspace","type":"date","portability":"never","absent":"inherit","reason":"a date in this space's history","process":"operations"},
    {"id":"workspace.accounting_journals","entity":"identity","type":"map","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.address","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.billing_rules","entity":"tariffs","type":"map","portability":"literal","absent":"inherit","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.new_member_defaults.overage_policy","entity":"tariffs","type":"enumeration","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.new_member_defaults.subscription_pct","entity":"tariffs","type":"percent","portability":"literal","absent":"product_default","min":1,"max":100,"process":"membershipCommerce"},
    {"id":"workspace.billing_rules.repartition.excluded","entity":"tariffs","type":"map","portability":"never","absent":"inherit","reason":"names people, who do not exist where a template is applied","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.repartition.method","entity":"tariffs","type":"enumeration","portability":"literal","absent":"inherit","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.repartition.weights","entity":"tariffs","type":"map","portability":"never","absent":"inherit","reason":"names people, who do not exist where a template is applied","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.subscription_advance_days","entity":"tariffs","type":"integer","portability":"literal","absent":"product_default","min":0,"process":"membershipCommerce"},
    {"id":"workspace.billing_rules.subscription_auto","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.usage_auto","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.usage_when_zero","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.booking_rules","entity":"booking_rules","type":"map","portability":"literal","absent":"inherit","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.admin_check_out","entity":"booking_rules","type":"boolean","portability":"literal","absent":"product_default","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.advance_horizon_days","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"max":730,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.allow_past_bookings","entity":"booking_rules","type":"boolean","portability":"literal","absent":"product_default","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.full_day_hours","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.granularity","entity":"booking_rules","type":"enumeration","portability":"literal","absent":"product_default","values":["flexible","half_day","minutes_5","minutes_15","minutes_30","minutes_60","full_day","hours"],"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.grid_within_hours","entity":"booking_rules","type":"boolean","portability":"unsupported","absent":"inherit","reason":"retired by #634; read as outside_hours_mode, never written","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.half_boundary_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":0,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.half_day_hours","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.legend_profile","entity":"booking_rules","type":"enumeration","portability":"literal","absent":"product_default","values":["full","simple"],"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.max_duration_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":5,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.max_series_days","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.min_duration_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":5,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.open_weekdays","entity":"booking_rules","type":"list","portability":"literal","absent":"product_default","min":1,"max":7,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.outside_hours_mode","entity":"booking_rules","type":"enumeration","portability":"literal","absent":"product_default","values":["off","free","charged","walkup_only"],"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.simultaneous_reservations","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"max":20,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.work_end_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":0,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.work_start_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":0,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.branding","entity":"branding","type":"map","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.branding.office_palette","entity":"branding","type":"list","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.branding.seat_palette","entity":"branding","type":"enumeration","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.branding.seed_color","entity":"branding","type":"color","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.city","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.company_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.country_code","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.created_at","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.created_by","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.created_by_user","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.created_datetime","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.currency_code","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.default_locale","entity":"identity","type":"locale","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.desk_opacity","entity":"booking_rules","type":"percent","portability":"literal","absent":"product_default","min":20,"max":100,"process":"reservationsUsage"},
    {"id":"workspace.dev_mode","entity":"workspace","type":"boolean","portability":"never","absent":"inherit","reason":"this space's own switch","process":"operations"},
    {"id":"workspace.document_language_confirmed","entity":"workspace","type":"boolean","portability":"never","absent":"inherit","reason":"this space's own to-do, set when its language is saved","process":"operations"},
    {"id":"workspace.dunning_rules","entity":"reminders","type":"map","portability":"literal","absent":"inherit","process":"billingPayments"},
    {"id":"workspace.dunning_rules.automatic","entity":"reminders","type":"boolean","portability":"literal","absent":"product_default","process":"billingPayments"},
    {"id":"workspace.dunning_rules.between_days","entity":"reminders","type":"integer","portability":"literal","absent":"product_default","min":0,"process":"billingPayments"},
    {"id":"workspace.dunning_rules.first_after_days","entity":"reminders","type":"integer","portability":"literal","absent":"product_default","min":0,"process":"billingPayments"},
    {"id":"workspace.dunning_rules.levels","entity":"reminders","type":"integer","portability":"literal","absent":"product_default","min":1,"max":9,"process":"billingPayments"},
    {"id":"workspace.environment","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.feature_flags","entity":"features","type":"map","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.feature_flags.accessorySupplements","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.accountingBook","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.accountingConnectors","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.accountingBook"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.accountingPeriods","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.accountingBook"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.adminInvoicing","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.adminLevelAssign","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.levelBooking"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.adminSeatBlocking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"spaceManagement"},
    {"id":"workspace.feature_flags.assetRegister","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.purchases"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.autoCheckInOut","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.badgeSignIn","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.nfcBadges"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.bankImport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.biReportDesigner","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.billingCustomers","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.bookForOthers","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.bookingGate","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.bookingPolicies"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.bookingPolicies","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.calendarFileExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.calendarHub","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarTab"],"process":"coordination"},
    {"id":"workspace.feature_flags.calendarTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.calendarValidations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarHub"],"process":"coordination"},
    {"id":"workspace.feature_flags.calendarViews","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarHub"],"process":"coordination"},
    {"id":"workspace.feature_flags.capacityKpi","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"spaceManagement"},
    {"id":"workspace.feature_flags.captureProtection","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.carnets","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.coOwner","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.configurableSettings","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.configurationTransfer","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dataExport"],"process":"operations"},
    {"id":"workspace.feature_flags.counterOfflineCash","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.counterTillSessions"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.counterReceipts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.standaloneInvoicing"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.counterTillLayout","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.counterTillSessions"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.counterTillSessions","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.counterReceipts"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.customFields","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.customRoles","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.customerQuotes","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.dataAccessLog","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.dataExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.dataReport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dataExport"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.decisionSurface","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.deletionRequests","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.demoMode","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.deployments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.environmentPairs"],"process":"operations"},
    {"id":"workspace.feature_flags.documents","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.dunning","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.einvoiceCustomerDelivery","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"integrations"},
    {"id":"workspace.feature_flags.environmentPairs","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.eventsTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.expenseRepartition","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.expenseRepartitionWizard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.expenseRepartition"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.externalRooms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.levelBooking"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.financeFaces","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.foreignCurrencyPurchases","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.purchases"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.formHelpHints","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.guestParticipation","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.guestPasses","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.holidayImport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.publicHolidays"],"process":"spaceManagement"},
    {"id":"workspace.feature_flags.inputVat","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatDeclarations"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.instanceWizard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.invoiceAddressWindow","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.invoiceEmail","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoiceJourney","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoicePdfTemplate","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.invoiceSettlement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoicing","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoicingWizard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.kioskEnrolment","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.kioskMemberPhotos","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.kioskMode","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.letterStandard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportLayouts"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.levelBooking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.managedProfileAccess","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.managedProfiles"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.managedProfiles","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.mcpAccess","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"integrations"},
    {"id":"workspace.feature_flags.meetingRooms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.memberAccountMenu","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.memberDataExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.memberEnvironments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.environmentPairs"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.memberGettingStarted","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.memberNotifications","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.memberOrigin","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.memberPage","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.memberPaymentTerms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.memberReports","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.membersDirectory","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.messageForwarding","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.messageGestures","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.messageMentions","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.messagesHub","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.moneyTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"billingPayments"},
    {"id":"workspace.feature_flags.mtdSubmission","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatDeclarations"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.multiSite","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"spaceManagement"},
    {"id":"workspace.feature_flags.navigationStyle","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.nfcBadges","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.nfcSeatTags","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.notificationGrouping","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.eventsTab"],"process":"coordination"},
    {"id":"workspace.feature_flags.numberSequences","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.onlinePayments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.organisation","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.parking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.paymentReminders","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dunning"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.pdfExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.personalInfo","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.personalShell","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.placeBooking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.placeFeedback","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"operations"},
    {"id":"workspace.feature_flags.planDecor","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"spaceManagement"},
    {"id":"workspace.feature_flags.planMemberPhotos","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"spaceManagement"},
    {"id":"workspace.feature_flags.planObjectDelete","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"spaceManagement"},
    {"id":"workspace.feature_flags.premisesLease","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.scheduledExpenses"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.priceNegotiations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.publicHolidays","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.publicListings","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.purchaseAnalytics","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.purchases"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.purchaseOrders","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.purchases"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.purchases","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.pushNotifications","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"integrations"},
    {"id":"workspace.feature_flags.qrBadges","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.quickSearch","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.recapitulativeStatement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatDeclarations"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.recordingPrivacy","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.regionalFormats","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.reminderEmail","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dunning"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.reportDesignExchange","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportDesigner","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicePdfTemplate"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportLayouts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportTexts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.richMessageRefs","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.roleAssignment","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.roleManagement"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.roleManagement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.salesTax","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.scheduledExpenses","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.seatDayTimeline","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.seriesBooking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.serviceFulfilment","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.billingCustomers"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.services","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.settlementFold","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoiceSettlement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.setupGuide","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.singleRoomLevelNames","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"spaceManagement"},
    {"id":"workspace.feature_flags.spaceInquiries","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.spaceQrCodes","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.placeBooking"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.standaloneInvoicing","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.stockCounts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockManagement"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockCycleCounts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockCounts"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockExpiryReport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockManagement"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockHandlingUnits","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockManagement"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockItemGroups","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockManagement"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockLots","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockManagement"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockManagement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.services"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockReceiving","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockManagement"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockReorder","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockManagement"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockReturns","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockManagement"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockScanning","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockManagement"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockTagReads","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockTags"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockTags","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockManagement"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.stockTakeOut","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.stockManagement"],"process":"goodsStock"},
    {"id":"workspace.feature_flags.subscriptionInvoices","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.supplyClassification","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.supplyExpenses","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.services"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.taskRecorder","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.uiAnimations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.uniqueMonograms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.unitsOfMeasure","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"goodsStock"},
    {"id":"workspace.feature_flags.usageInvoices","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.usageRecords","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.usageReport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.usageRecords"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.validationChain","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.validationScopes","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.vatCounterparty","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatDeclarations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatGroups","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatManagement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatRateHistory","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatReport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatDeclarations"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.viesVerification","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.supplyClassification"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.webMcp","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.mcpAccess"],"process":"integrations"},
    {"id":"workspace.feature_flags.whatsappIntegration","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"integrations"},
    {"id":"workspace.feature_flags.workingHours","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.workspaceBranding","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.workspaceLibrary","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.workspaceOverview","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.workspaceStatus","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"operations"},
    {"id":"workspace.feature_flags.workspaceVocabulary","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.invitation_template","entity":"invitations","type":"text","portability":"never","absent":"inherit","reason":"names the source space and its people","process":"workspaceAccess"},
    {"id":"workspace.invitation_templates","entity":"invitations","type":"text","portability":"never","absent":"inherit","reason":"names the source space and its people","process":"workspaceAccess"},
    {"id":"workspace.invite_code","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"a secret","process":"operations"},
    {"id":"workspace.invoice_legal","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.invoice_pdf_template","entity":"document_design","type":"map","portability":"never","absent":"inherit","reason":"points at the source's image library; travels with the report design exchange","process":"documentsInformation"},
    {"id":"workspace.legal_id","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.lexicon","entity":"lexicon","type":"map","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.deskDetail","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.directoryTitle","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendBlocked","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendClosed","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendFree","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendMine","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendOccupied","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendReserved","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendUnavailable","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.levelDetail","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.levelReserveButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.messagesTitle","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planAfternoonChip","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planBookForLabel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planCheckInButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planCheckInTitle","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planDurationLabel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planFromLabel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planMorningChip","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planReserveButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveClosedShort","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveDayView","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveFullDayChip","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveMonthView","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveWeekView","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.shellReserveButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindDesk","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindLevel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindOffice","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindSeat","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabCalendar","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabEvents","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabMoney","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabPlan","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.modified_by_user","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.modified_datetime","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.name","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.network_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"the birth record of this row on its own installation","process":"operations"},
    {"id":"workspace.organisation_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"the organisation of this business on its own installation (#4004)","process":"operations"},
    {"id":"workspace.pair_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.paper","entity":"identity","type":"enumeration","portability":"literal","absent":"product_default","values":["A4","Letter"],"depends_on":["workspace.country_code"],"process":"operations"},
    {"id":"workspace.payment_instructions.iban","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.lydia","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.paypal_me","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.reference","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.wero","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.wise","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.postal_code","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.role_permissions","entity":"roles","type":"map","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.role_permissions.admin","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd","viewAnalytics","useMessages","makeReservations","viewCalendar","viewDirectory","viewMyMoney","viewDocuments","managePurchases","recordOutgoingPayments","manageLease","managePrivacy","viewStock","manageStock","approveStockAdjustments","manageBillingCustomers","countStock","configureTill"],"process":"workspaceAccess"},
    {"id":"workspace.role_permissions.co_owner","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd","viewAnalytics","useMessages","makeReservations","viewCalendar","viewDirectory","viewMyMoney","viewDocuments","managePurchases","recordOutgoingPayments","manageLease","managePrivacy","viewStock","manageStock","approveStockAdjustments","manageBillingCustomers","countStock","configureTill"],"process":"workspaceAccess"},
    {"id":"workspace.role_permissions.member","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd","viewAnalytics","useMessages","makeReservations","viewCalendar","viewDirectory","viewMyMoney","viewDocuments","managePurchases","recordOutgoingPayments","manageLease","managePrivacy","viewStock","manageStock","approveStockAdjustments","manageBillingCustomers","countStock","configureTill"],"process":"workspaceAccess"},
    {"id":"workspace.site_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.stock_initialized_at","entity":"workspace","type":"date","portability":"never","absent":"inherit","reason":"when this space first opened its stock ledger (#4170): history, never a setting","process":"operations"},
    {"id":"workspace.street","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.subscription_levels","entity":"tariffs","type":"map","portability":"literal","absent":"inherit","process":"membershipCommerce"},
    {"id":"workspace.subscription_levels.allow_custom","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.subscription_levels.enabled_presets","entity":"tariffs","type":"list","portability":"literal","absent":"product_default","min":1,"max":100,"process":"membershipCommerce"},
    {"id":"workspace.subscription_levels.extra_levels","entity":"tariffs","type":"list","portability":"literal","absent":"product_default","min":1,"max":100,"process":"membershipCommerce"},
    {"id":"workspace.subscription_vat_rate","entity":"vat","type":"text","portability":"reference","absent":"inherit","bindings":["vat_rates.label"],"process":"billingPayments"},
    {"id":"workspace.tax_exemption_reason","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.timezone","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.vat_account","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.vat_id","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.vat_regime","entity":"identity","type":"enumeration","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.visibility","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"the space's own listing choice; a template must not publish a space","process":"operations"},
    {"id":"workspace.visibility_set_at","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"the space's own listing choice; a template must not publish a space","process":"operations"},
    {"id":"workspace.whatsapp_group","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"}
  ]$json$::jsonb
$registry$;

select public.set_deskilo_schema_version(958);
