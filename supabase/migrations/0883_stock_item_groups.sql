-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (two tables, columns with a default or null on services, three settings, functions, the workspace export
--  restated whole and save_stock_item_v1 patched at an asserted anchor)
--
-- #4361 (G12, third of three files) -- item groups: the tables and the functions.
--
--   * A group has a name, an optional parent and its parameters, each a typed nullable column
--     (null: not set at this level). Groups nest one level: a group may have sub-groups, a sub-group
--     has none (checked by a trigger). An item belongs to at most one group or sub-group
--     (`services.group_id`); a group in use cannot be deleted.
--   * An item's value of a parameter is its own when it is an override, else its sub-group's, else
--     its group's, else the business's default (a setting), else the system's. Five parameters
--     already have an item column (`tracking`, `shelf_life_days`, `inventory_unit`, `vat_rate_id`,
--     `supply_class`): the column keeps the value in force, `services.group_overrides` names the
--     ones the item keeps its own value of, and a group change writes the inheriting items' columns.
--     The other item parameters have a nullable item column of their own: null inherits, a value
--     overrides. Proposals (default purchase unit, price rounding and margin, reorder defaults, home
--     zone) live on the group alone and are only ever proposed.
--   * `item_group_history` records every change of a group parameter and of an item override: who,
--     when, the old and the new value, and how many items it reached. It is append-only.

--   * `item_effective_settings_v1` is the one read of what an item's settings are, for every consumer;
--     `item_group_save_v1` creates or changes a group and writes the inheriting items' columns at once
--     (an item that overrides a parameter keeps its value; an item the change cannot reach is skipped and
--     listed; with `p_apply` false it only says what it would do); `item_group_assign_v1` moves an item
--     into or out of a group with the same preview; `item_override_save_v1` sets an item's own value or
--     gives it back to its group; `item_group_delete_v1` deletes a group nothing uses; `item_groups_v1` and
--     `item_group_history_v1` read. `manageStock` edits; VAT, supply class, price rounding and margin also
--     need `manageServices` and `viewFinances`; an assistant reads group names and is refused every write.
--   * `save_stock_item_v1` marks the parameters an edit of the item itself changes as overrides, so a
--     later change of the group does not take them back.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('stock.group_default_tag_mode', 'enum', '"none"'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, '["none","per_batch","per_unit"]'::jsonb, 'item groups (#4361)', 'Whether an item that no group and no own setting speaks for carries an RFID tag: none, one tag naming a batch, or one tag per unit (which needs tracking by piece). The last level of the inheritance of an item: its own value, its sub-group, its group, this, then none.'),
('stock.group_default_count_days', 'int', '0'::jsonb, 0, 365, 'days', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'item groups (#4361)', 'Every how many days an item that no group and no own setting speaks for is proposed for a cycle count. 0 means not scheduled. The last level of the inheritance of an item before the system value.'),
('stock.price_rounding', 'enum', '"none"'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, '["none","0.05","0.10","0.99"]'::jsonb, 'item groups (#4361)', 'How a proposed sale price is rounded: to the nearest 0.05 or 0.10, or to a price ending in 0.99. Used only to propose a price, never to change one. The list of roundings a group may choose from is this setting''s list; this value is the business default.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the groups ─────────────────────────────────────────────────────────
create table public.item_groups (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  parent_id uuid,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  revision int not null default 1 check (revision >= 1),
  -- the parameters a group carries; null means not set at this level
  tracking text check (tracking in ('none', 'lot', 'expiry', 'serial')),
  shelf_life_days int check (shelf_life_days between 1 and 36500),
  tag_mode text check (tag_mode in ('none', 'per_batch', 'per_unit')),
  inventory_unit text references public.stock_units (code),
  default_purchase_unit text check (char_length(btrim(default_purchase_unit)) between 1 and 30),
  default_purchase_factor_num bigint check (default_purchase_factor_num > 0),
  default_purchase_factor_den bigint check (default_purchase_factor_den > 0),
  vat_rate_id uuid references public.vat_rates (id),
  supply_class text check (supply_class in ('property', 'general')),
  price_rounding text check (price_rounding in ('none', '0.05', '0.10', '0.99')),
  target_margin_bps int check (target_margin_bps between 0 and 100000),
  reorder_point_default numeric(18, 6) check (reorder_point_default >= 0),
  reorder_quantity_default numeric(18, 6) check (reorder_quantity_default > 0),
  home_zone_id uuid,
  count_every_days int check (count_every_days between 1 and 365),
  till_category text check (char_length(btrim(till_category)) between 1 and 40),
  quick_key_colour text check (quick_key_colour ~ '^#[0-9a-fA-F]{6}$'),
  min_age int check (min_age between 1 and 120),
  sold_by_weight boolean,
  weight_basis text check (weight_basis in ('kg', '100g')),
  deposit_item_id uuid,
  deposit_minor bigint check (deposit_minor >= 0),
  label_template text check (char_length(btrim(label_template)) between 1 and 60),
  unique (workspace_id, id),
  foreign key (workspace_id, parent_id) references public.item_groups (workspace_id, id),
  foreign key (workspace_id, home_zone_id) references public.stock_locations (workspace_id, id),
  foreign key (workspace_id, deposit_item_id) references public.services (workspace_id, id),
  check ((default_purchase_factor_num is null) = (default_purchase_factor_den is null)),
  check (parent_id is distinct from id)
);
select public.ensure_system_columns('item_groups');
create unique index item_groups_name_once on public.item_groups
  (workspace_id, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(btrim(name)));
create index item_groups_parent on public.item_groups (workspace_id, parent_id) where parent_id is not null;

-- one level of nesting: a sub-group's parent has none, and a group with sub-groups gets no parent
create or replace function public.item_groups_depth()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if new.parent_id is not null then
    -- the parent is locked: a sub-group made and a parent moved at once do not both pass
    perform 1 from public.item_groups p where p.id = new.parent_id for update;
    if exists (select 1 from public.item_groups p where p.id = new.parent_id and p.parent_id is not null) then
      raise exception 'a sub-group cannot have sub-groups' using errcode = 'DKG11',
        detail = jsonb_build_object('field', 'parent_id', 'reason', 'depth')::text;
    end if;
    if exists (select 1 from public.item_groups c where c.parent_id = new.id) then
      raise exception 'a group with sub-groups cannot become a sub-group' using errcode = 'DKG11',
        detail = jsonb_build_object('field', 'parent_id', 'reason', 'depth')::text;
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.item_groups_depth() from public, anon, authenticated;
create trigger item_groups_depth before insert or update of parent_id on public.item_groups
  for each row execute function public.item_groups_depth();

-- ── what an item says of its group ─────────────────────────────────────
-- audience: all row readers (the item's own settings are read with the item, by whoever reads it)
alter table public.services
  add column if not exists group_id uuid,
  add column if not exists group_overrides text[] not null default '{}'::text[],
  add column if not exists tag_mode text check (tag_mode in ('none', 'per_batch', 'per_unit')),
  add column if not exists count_every_days int check (count_every_days between 1 and 365),
  add column if not exists till_category text check (char_length(btrim(till_category)) between 1 and 40),
  add column if not exists quick_key_colour text check (quick_key_colour ~ '^#[0-9a-fA-F]{6}$'),
  add column if not exists min_age int check (min_age between 1 and 120),
  add column if not exists sold_by_weight boolean,
  add column if not exists weight_basis text check (weight_basis in ('kg', '100g')),
  add column if not exists deposit_item_id uuid,
  add column if not exists deposit_minor bigint check (deposit_minor >= 0),
  add column if not exists label_template text check (char_length(btrim(label_template)) between 1 and 60);
alter table public.services
  add constraint services_group_fk foreign key (workspace_id, group_id) references public.item_groups (workspace_id, id),
  add constraint services_deposit_item_fk foreign key (workspace_id, deposit_item_id) references public.services (workspace_id, id),
  add constraint services_group_overrides_known check (group_overrides <@ array['tracking', 'shelf_life_days', 'inventory_unit', 'vat_rate_id', 'supply_class']::text[]);
create index services_group on public.services (workspace_id, group_id) where group_id is not null;

-- An item's own value, written by any other path (the service editor writes the item directly), is its
-- own: the parameter is marked as an override so a later change of the group does not take it back.
-- The group functions write the columns themselves and say so (deskilo.item_groups_writing).
create or replace function public.services_group_overrides()
returns trigger language plpgsql set search_path = public as $fn$
declare
  v_param text;
begin
  if new.group_id is null or new.group_id is distinct from old.group_id
     or coalesce(current_setting('deskilo.item_groups_writing', true), '') = 'on' then
    return new;
  end if;
  foreach v_param in array array['tracking', 'shelf_life_days', 'inventory_unit', 'vat_rate_id', 'supply_class'] loop
    if to_jsonb(new) -> v_param is distinct from to_jsonb(old) -> v_param and not (v_param = any (new.group_overrides)) then
      new.group_overrides := new.group_overrides || v_param;
    end if;
  end loop;
  return new;
end;
$fn$;
revoke execute on function public.services_group_overrides() from public, anon, authenticated;
create trigger services_group_overrides before update on public.services
  for each row execute function public.services_group_overrides();
comment on column public.services.group_overrides is
  '#4361: the parameters with a column of their own here (tracking, shelf_life_days, inventory_unit, vat_rate_id, supply_class) whose value the item keeps against its group.';

-- ── the history ────────────────────────────────────────────────────────
create table public.item_group_history (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  group_id uuid,
  item_id uuid,
  parameter text not null check (char_length(parameter) between 1 and 40),
  old_value jsonb,
  new_value jsonb,
  affected int not null default 0 check (affected >= 0),
  kept_own int not null default 0 check (kept_own >= 0),
  skipped int not null default 0 check (skipped >= 0),
  changed_by_member_id uuid,
  request_id uuid,
  check (group_id is not null or item_id is not null),
  foreign key (workspace_id, changed_by_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('item_group_history');
create index item_group_history_group on public.item_group_history (workspace_id, group_id, created_datetime desc);
create index item_group_history_item on public.item_group_history (workspace_id, item_id, created_datetime desc);

create or replace function public.item_group_history_append_only()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  raise exception 'the history of a group is never edited or deleted' using errcode = 'DKG08';
end;
$fn$;
revoke execute on function public.item_group_history_append_only() from public, anon, authenticated;
create trigger item_group_history_append_only before update or delete on public.item_group_history
  for each row execute function public.item_group_history_append_only();

-- ── closed to the API roles: the functions read and write, the assistant is refused ──
alter table public.item_groups enable row level security;
alter table public.item_group_history enable row level security;
revoke all on public.item_groups, public.item_group_history from public, anon, authenticated;
-- the history is read through item_group_history_v1, which keeps the finance values to those who read the finances
-- the margin and the rounding are read through the functions, with the finances
do $grant$
declare
  v_cols text;
begin
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position) into v_cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'item_groups' and column_name not in ('target_margin_bps', 'price_rounding');
  execute 'grant select (' || v_cols || ') on public.item_groups to authenticated';
end
$grant$;
create policy item_groups_select on public.item_groups for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockItemGroups'));
create policy item_group_history_select on public.item_group_history for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['manageStock']))
         and public.feature_effective(workspace_id, 'stockItemGroups'));
create policy mcp_delegated_deny on public.item_groups as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.item_group_history as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
-- ── the workspace export carries them (#2860) ──────────────────────────
-- restates 0873
create or replace function public.export_workspace_records(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_tables text[] := array[
    -- configuration, readable (the XML stays the re-importable copy)
    'sites', 'fee_bands', 'packages', 'credit_products', 'vat_rates',
    'accessories', 'seat_accessories', 'closure_days', 'validation_policies',
    'workspace_roles', 'workspace_role_members', 'workspace_field_definitions',
    'workspace_field_values', 'number_sequences', 'charging_stations',
    'plan_images', 'setting_values',
    -- member accounts
    'member_credits', 'member_credit_uses', 'price_negotiations',
    'quota_extensions', 'usage_records', 'invoice_matches', 'invoice_reminders',
    'invoice_dunning_holds', 'tax_exemption_certificates',
    -- purchases, premises, assets, books
    'suppliers', 'purchase_documents', 'purchase_lines', 'purchase_obligations',
    'outgoing_payments', 'expense_schedules', 'expense_occurrences',
    'expense_repartitions', 'premises_leases', 'lease_terms',
    'lease_settlements', 'room_rentals', 'room_rental_fees', 'workspace_assets',
    'asset_valuation_batches', 'asset_valuation_rows', 'book_profiles',
    'book_accounts', 'book_mappings', 'book_periods', 'vat_declarations',
    'einvoice_inbox',
    -- people the space is accountable to
    'guest_participations', 'rights_requests',
    -- #3307 the orders to the suppliers
    'purchase_orders', 'purchase_order_lines', 'purchase_order_sends',
    'purchase_order_receipts', 'purchase_order_receipt_lines',
    -- #3308 the passes the space sells and the passes it sold
    'guest_pass_offers', 'guest_passes',
    -- #3824 the goods ledger
    'item_units', 'item_codes', 'stock_locations', 'stock_lots', 'stock_movements',
    'stock_balances',
    -- #4164 the billing identity of each customer the business invoices
    'billing_parties',
    -- #4166 the customer quotes, their revisions, the decisions the issuer recorded and
    -- the conversions into invoices
    'customer_quotes', 'customer_quote_revisions', 'customer_quote_decisions',
    'customer_quote_conversions',
    -- #4169 the variants and the supplier's article
    'item_dimensions', 'item_dimension_values', 'item_variants', 'item_variant_values',
    'supplier_item_mappings',
    -- #4171 what was put away from a delivery
    'stock_receipt_allocations',
    -- #4170 the transfers between sites and what each loaded
    'stock_transfers', 'stock_transfer_lines',
    -- #4294 the reorder points
    'stock_reorder_points', 'item_groups', 'item_group_history',
    -- #4172 the returns, and what each line reversed
    'stock_returns', 'stock_reversals',
    -- #4172 the counts and their decisions
    'stock_counts',
    -- #4295 the plans, the tasks and their lines
    'stock_count_plans', 'stock_count_tasks', 'stock_count_task_lines',
    -- #4178 the engagements of the services ordered, their steps and the invoice
    -- lines that billed a direct commitment
    'service_fulfilments', 'service_fulfilment_transitions', 'service_fulfilment_invoice_links'];
  v_left_out text[] := public.system_column_names() || array['workspace_id', 'source_xml'];
  v_table text;
  v_columns text[];
  v_rows jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'only someone who may export this workspace''s data reads its records'
      using errcode = 'DKN01';
  end if;
  foreach v_table in array v_tables loop
    select array_agg(c.column_name::text order by c.ordinal_position) into v_columns
      from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = v_table
       and c.column_name <> all (v_left_out);
    execute format(
      'select coalesce(jsonb_agg(jsonb_build_array(%s) order by created_datetime), ''[]''::jsonb)
         from public.%I where workspace_id = $1',
      (select string_agg(format('%I', c), ', ') from unnest(v_columns) c), v_table)
      into v_rows using p_workspace_id;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'table', v_table, 'columns', to_jsonb(v_columns), 'rows', v_rows));
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.export_workspace_records(uuid) from public, anon;
grant execute on function public.export_workspace_records(uuid) to authenticated;

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- ── the catalogue of parameters ────────────────────────────────────────
-- stored: has a column on the item and is written there; item: a nullable column that overrides;
-- proposal: lives on the group alone.
create or replace function public.item_group_param_kind(p_param text)
returns text language sql immutable set search_path = public as $fn$
  select case
    when p_param in ('tracking', 'shelf_life_days', 'inventory_unit', 'vat_rate_id', 'supply_class') then 'stored'
    when p_param in ('tag_mode', 'count_every_days', 'till_category', 'quick_key_colour', 'min_age', 'sold_by_weight',
                     'weight_basis', 'deposit_item_id', 'deposit_minor', 'label_template') then 'item'
    when p_param in ('default_purchase_unit', 'default_purchase_factor_num', 'default_purchase_factor_den',
                     'price_rounding', 'target_margin_bps', 'reorder_point_default', 'reorder_quantity_default',
                     'home_zone_id') then 'proposal'
    else null end;
$fn$;
revoke execute on function public.item_group_param_kind(text) from public, anon, authenticated;

create or replace function public.item_group_params()
returns text[] language sql immutable set search_path = public as $fn$
  select array['tracking', 'shelf_life_days', 'inventory_unit', 'vat_rate_id', 'supply_class',
               'tag_mode', 'count_every_days', 'till_category', 'quick_key_colour', 'min_age', 'sold_by_weight',
               'weight_basis', 'deposit_item_id', 'deposit_minor', 'label_template',
               'default_purchase_unit', 'default_purchase_factor_num', 'default_purchase_factor_den',
               'price_rounding', 'target_margin_bps', 'reorder_point_default', 'reorder_quantity_default',
               'home_zone_id'];
$fn$;
revoke execute on function public.item_group_params() from public, anon, authenticated;

-- the parameters that say what an item costs or sells for need the finances too
create or replace function public.item_group_param_finance(p_param text)
returns boolean language sql immutable set search_path = public as $fn$
  select p_param in ('vat_rate_id', 'supply_class', 'price_rounding', 'target_margin_bps');
$fn$;
revoke execute on function public.item_group_param_finance(text) from public, anon, authenticated;

-- ── one order of locks: the groups (by id), then the items (by id) ─────
-- A save takes its groups exclusively, a move or an override reads the chain for share; both before any
-- item, so a move between groups and a save of a group cannot wait on each other.
create or replace function public.item_group_lock(p_ids uuid[], p_exclusive boolean)
returns void language plpgsql volatile security definer set search_path = public as $fn$
begin
  if p_exclusive then
    perform 1 from public.item_groups g
     where g.id in (select x from unnest(p_ids) x where x is not null
                    union select g2.parent_id from public.item_groups g2 where g2.id = any (p_ids) and g2.parent_id is not null)
     order by g.id for update;
  else
    perform 1 from public.item_groups g
     where g.id in (select x from unnest(p_ids) x where x is not null
                    union select g2.parent_id from public.item_groups g2 where g2.id = any (p_ids) and g2.parent_id is not null)
     order by g.id for share;
  end if;
end;
$fn$;
revoke execute on function public.item_group_lock(uuid[], boolean) from public, anon, authenticated;

-- ── who may ────────────────────────────────────────────────────────────
create or replace function public.item_group_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null then
    raise exception 'not allowed to configure the item groups' using errcode = 'DKN01';
  end if;
  v_me := public.stock_config_actor(p_workspace_id);
  if not public.feature_effective(p_workspace_id, 'stockItemGroups') then
    raise exception 'item groups are off in this business' using errcode = 'DKG01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.item_group_actor(uuid) from public, anon, authenticated;

create or replace function public.item_group_finance_guard(p_workspace_id uuid, p_params text[])
returns void language plpgsql stable security definer set search_path = public as $fn$
declare
  v_p text;
begin
  foreach v_p in array coalesce(p_params, array[]::text[]) loop
    if public.item_group_param_finance(v_p)
       and not (public.has_permission(p_workspace_id, 'manageServices') and public.has_permission(p_workspace_id, 'viewFinances')) then
      raise exception 'not allowed to change what an item costs or sells for' using errcode = 'DKN01';
    end if;
  end loop;
end;
$fn$;
revoke execute on function public.item_group_finance_guard(uuid, text[]) from public, anon, authenticated;

-- ── the business's own default of a parameter, where it has one ────────
create or replace function public.item_group_business_default(p_workspace_id uuid, p_param text)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v jsonb;
begin
  if p_param = 'tag_mode' then
    return public.setting_value(p_workspace_id, 'stock.group_default_tag_mode');
  elsif p_param = 'count_every_days' then
    v := public.setting_value(p_workspace_id, 'stock.group_default_count_days');
    return case when v is null or v = '0'::jsonb then null else v end;
  elsif p_param = 'price_rounding' then
    return public.setting_value(p_workspace_id, 'stock.price_rounding');
  end if;
  return null;
end;
$fn$;
revoke execute on function public.item_group_business_default(uuid, text) from public, anon, authenticated;

-- ── what an item's settings are ────────────────────────────────────────
-- Each parameter: {value, source, group, since}; the sources are item (its own, or the item as it
-- stands where nothing above it speaks), subgroup, group and business. `problems` names what does
-- not agree (a per-unit tag mode on an item not tracked by piece).
create or replace function public.item_effective_core(p_item_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  s public.services;
  n public.item_groups;
  q public.item_groups;
  v_item jsonb;
  v_levels jsonb[] := array[]::jsonb[];
  v_names text[] := array[]::text[];
  v_srcs text[] := array[]::text[];
  v_ids uuid[] := array[]::uuid[];
  v_out jsonb := '{}'::jsonb;
  v_param text;
  v_kind text;
  v_val jsonb;
  v_src text;
  v_name text;
  v_gid uuid;
  v_i int;
  v_since timestamptz;
  v_problems jsonb := '[]'::jsonb;
begin
  select * into s from public.services where id = p_item_id;
  if s.id is null then
    return null;
  end if;
  v_item := to_jsonb(s);
  if s.group_id is not null then
    select * into n from public.item_groups where id = s.group_id;
    if n.parent_id is not null then
      select * into q from public.item_groups where id = n.parent_id;
      v_levels := array[to_jsonb(n), to_jsonb(q)];
      v_names := array[n.name, q.name];
      v_srcs := array['subgroup', 'group'];
      v_ids := array[n.id, q.id];
    else
      v_levels := array[to_jsonb(n)];
      v_names := array[n.name];
      v_srcs := array['group'];
      v_ids := array[n.id];
    end if;
  end if;
  foreach v_param in array public.item_group_params() loop
    v_kind := public.item_group_param_kind(v_param);
    v_val := null; v_src := null; v_name := null; v_gid := null;
    if v_kind = 'stored' then
      if v_param = any (s.group_overrides) or s.group_id is null then
        v_val := v_item -> v_param; v_src := 'item';
      else
        for v_i in 1 .. coalesce(array_length(v_levels, 1), 0) loop
          if v_levels[v_i] -> v_param is not null and v_levels[v_i] -> v_param <> 'null'::jsonb then
            v_val := v_levels[v_i] -> v_param; v_src := v_srcs[v_i]; v_name := v_names[v_i]; v_gid := v_ids[v_i];
            exit;
          end if;
        end loop;
        if v_src is null then
          v_val := v_item -> v_param; v_src := 'item';
        elsif v_item -> v_param is distinct from v_val then
          -- the group's value could not be written to this item: what is in force is the item's
          v_problems := v_problems || to_jsonb(v_param || '_not_applied');
          v_val := v_item -> v_param; v_src := 'item'; v_name := null; v_gid := null;
        end if;
      end if;
    elsif v_kind = 'item' then
      if v_item -> v_param is not null and v_item -> v_param <> 'null'::jsonb then
        v_val := v_item -> v_param; v_src := 'item';
      else
        for v_i in 1 .. coalesce(array_length(v_levels, 1), 0) loop
          if v_levels[v_i] -> v_param is not null and v_levels[v_i] -> v_param <> 'null'::jsonb then
            v_val := v_levels[v_i] -> v_param; v_src := v_srcs[v_i]; v_name := v_names[v_i]; v_gid := v_ids[v_i];
            exit;
          end if;
        end loop;
        if v_src is null then
          v_val := public.item_group_business_default(s.workspace_id, v_param);
          if v_val is not null then v_src := 'business'; end if;
        end if;
      end if;
    else
      -- a proposal: the group's, else the business's
      for v_i in 1 .. coalesce(array_length(v_levels, 1), 0) loop
        if v_levels[v_i] -> v_param is not null and v_levels[v_i] -> v_param <> 'null'::jsonb then
          v_val := v_levels[v_i] -> v_param; v_src := v_srcs[v_i]; v_name := v_names[v_i]; v_gid := v_ids[v_i];
          exit;
        end if;
      end loop;
      if v_src is null then
        v_val := public.item_group_business_default(s.workspace_id, v_param);
        if v_val is not null then v_src := 'business'; end if;
      end if;
    end if;
    v_since := null;
    if v_src in ('group', 'subgroup') then
      select max(h.created_datetime) into v_since from public.item_group_history h
       where h.workspace_id = s.workspace_id and h.group_id = v_gid and h.parameter = v_param;
    elsif v_src = 'item' and (v_param = any (s.group_overrides) or v_kind = 'item') then
      select max(h.created_datetime) into v_since from public.item_group_history h
       where h.workspace_id = s.workspace_id and h.item_id = s.id and h.parameter = v_param;
    end if;
    v_out := v_out || jsonb_build_object(v_param, jsonb_build_object(
      'value', coalesce(v_val, 'null'::jsonb), 'source', coalesce(v_src, 'none'),
      'group', v_name, 'since', v_since));
  end loop;
  if v_out #>> '{tag_mode,value}' = 'per_unit' and s.tracking <> 'serial' then
    v_problems := v_problems || to_jsonb('per_unit_needs_serial'::text);
  end if;
  return jsonb_build_object('item_id', s.id, 'group_id', s.group_id, 'parameters', v_out, 'problems', v_problems);
end;
$fn$;
revoke execute on function public.item_effective_core(uuid) from public, anon, authenticated;

create or replace function public.item_effective_settings_v1(p_workspace_id uuid, p_item_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_out jsonb;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to read the stock settings' using errcode = 'DKN01';
  end if;
  if not exists (select 1 from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active')
     or not (public.has_permission(p_workspace_id, 'viewStock') or public.has_permission(p_workspace_id, 'manageStock')) then
    raise exception 'not allowed to read the stock settings' using errcode = 'DKN01';
  end if;
  select workspace_id into v_ws from public.services where id = p_item_id;
  if v_ws is distinct from p_workspace_id then
    raise exception 'not an item of this business' using errcode = 'DKG04';
  end if;
  v_out := public.item_effective_core(p_item_id);
  -- the margin and the rounding show what goods cost: they are read with the finances
  if not public.has_permission(p_workspace_id, 'viewFinances') then
    v_out := jsonb_set(jsonb_set(v_out, '{parameters,target_margin_bps}', jsonb_build_object('value', null, 'source', 'hidden')),
                       '{parameters,price_rounding}', jsonb_build_object('value', null, 'source', 'hidden'));
  end if;
  return v_out;
end;
$fn$;
revoke execute on function public.item_effective_settings_v1(uuid, uuid) from public, anon;
grant execute on function public.item_effective_settings_v1(uuid, uuid) to authenticated;

-- ── the first level that speaks ────────────────────────────────────────
create or replace function public.item_chain_pick(p_levels jsonb[], p_param text)
returns jsonb language plpgsql immutable set search_path = public as $fn$
declare
  i int;
begin
  for i in 1 .. coalesce(array_length(p_levels, 1), 0) loop
    if p_levels[i] is not null and p_levels[i] -> p_param is not null and p_levels[i] -> p_param <> 'null'::jsonb then
      return p_levels[i] -> p_param;
    end if;
  end loop;
  return null;
end;
$fn$;
revoke execute on function public.item_chain_pick(jsonb[], text) from public, anon, authenticated;

-- ── one stored parameter written to one item ───────────────────────────
-- Answers null when written (or already so), else why the item is skipped.
create or replace function public.item_apply_stored(p_item_id uuid, p_param text, p_value jsonb)
returns text language plpgsql volatile security definer set search_path = public as $fn$
declare
  s public.services;
  v_text text := p_value #>> '{}';
  v_dim_old text;
  v_dim_new text;
begin
  select * into s from public.services where id = p_item_id for update;
  if p_param = 'tracking' then
    if v_text = s.tracking then return null; end if;
    if exists (select 1 from public.stock_movements m where m.item_id = s.id) then return 'has_movements'; end if;
    if public.item_effective_core(s.id) #>> '{parameters,tag_mode,value}' = 'per_unit' and v_text <> 'serial' then
      return 'per_unit_needs_serial';
    end if;
    perform set_config('deskilo.item_groups_writing', 'on', true);
    update public.services set tracking = v_text, stock_revision = stock_revision + 1 where id = s.id;
  elsif p_param = 'inventory_unit' then
    if v_text = s.inventory_unit then return null; end if;
    if exists (select 1 from public.stock_movements m where m.item_id = s.id) then return 'has_movements'; end if;
    if exists (select 1 from public.item_units u where u.item_id = s.id) then
      select dimension into v_dim_old from public.stock_units where code = s.inventory_unit;
      select dimension into v_dim_new from public.stock_units where code = v_text;
      if v_dim_old is distinct from v_dim_new then return 'dimension_mismatch'; end if;
    end if;
    perform set_config('deskilo.item_groups_writing', 'on', true);
    update public.services set inventory_unit = v_text, stock_revision = stock_revision + 1 where id = s.id;
  elsif p_param = 'shelf_life_days' then
    if v_text::int is not distinct from s.shelf_life_days then return null; end if;
    perform set_config('deskilo.item_groups_writing', 'on', true);
    update public.services set shelf_life_days = v_text::int, stock_revision = stock_revision + 1 where id = s.id;
  elsif p_param = 'vat_rate_id' then
    if v_text::uuid is not distinct from s.vat_rate_id then return null; end if;
    perform set_config('deskilo.item_groups_writing', 'on', true);
    update public.services set vat_rate_id = v_text::uuid, stock_revision = stock_revision + 1 where id = s.id;
  elsif p_param = 'supply_class' then
    if v_text = s.supply_class then return null; end if;
    perform set_config('deskilo.item_groups_writing', 'on', true);
    update public.services set supply_class = v_text, stock_revision = stock_revision + 1 where id = s.id;
  else
    return 'unknown_parameter';
  end if;
  perform set_config('deskilo.item_groups_writing', 'off', true);
  return null;
end;
$fn$;
revoke execute on function public.item_apply_stored(uuid, text, jsonb) from public, anon, authenticated;

-- A value of a stored parameter, as the groups carry it, is one the stock accepts.
create or replace function public.item_group_check_value(p_workspace_id uuid, p_param text, p_value jsonb)
returns void language plpgsql stable security definer set search_path = public as $fn$
begin
  if p_value is null or p_value = 'null'::jsonb then
    return;
  end if;
  if p_param = 'inventory_unit' and not exists (select 1 from public.stock_units u where u.code = p_value #>> '{}') then
    perform public.stock_config_refuse(p_param, 'unit_unknown');
  elsif p_param = 'vat_rate_id' and not exists (
      select 1 from public.vat_rates r where r.id = (p_value #>> '{}')::uuid and r.workspace_id = p_workspace_id and r.active) then
    perform public.stock_config_refuse(p_param, 'vat_rate_unknown');
  elsif p_param = 'home_zone_id' and not exists (
      select 1 from public.stock_locations l where l.id = (p_value #>> '{}')::uuid and l.workspace_id = p_workspace_id) then
    perform public.stock_config_refuse(p_param, 'place_unknown');
  elsif p_param = 'deposit_item_id' and not exists (
      select 1 from public.services v where v.id = (p_value #>> '{}')::uuid and v.workspace_id = p_workspace_id) then
    perform public.stock_config_refuse(p_param, 'item_unknown');
  end if;
exception when invalid_text_representation or numeric_value_out_of_range or invalid_parameter_value then
  perform public.stock_config_refuse(p_param, 'malformed');
end;
$fn$;
revoke execute on function public.item_group_check_value(uuid, text, jsonb) from public, anon, authenticated;

-- ── a group is created or changed ──────────────────────────────────────
-- p_body: {"name": ..., "parent_id": ..., "parameters": {"tracking": "expiry", "shelf_life_days": null, ...}}
-- A parameter named with null is cleared at this level. p_apply false: the preview, nothing written.
create or replace function public.item_group_save_v1(
  p_workspace_id uuid, p_request_id uuid, p_group_id uuid, p_expected_revision int, p_body jsonb,
  p_apply boolean default true)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_params jsonb;
  v_keys text[];
  v_k text;
  v_digest text;
  v_done jsonb;
  v_result jsonb;
begin
  v_me := public.item_group_actor(p_workspace_id);
  if p_group_id is null or p_expected_revision is null or p_expected_revision < 0
     or coalesce(jsonb_typeof(p_body), '') <> 'object' or (p_apply and p_request_id is null) then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  v_params := coalesce(p_body -> 'parameters', '{}'::jsonb);
  if jsonb_typeof(v_params) <> 'object' then
    perform public.stock_config_refuse('parameters', 'malformed');
  end if;
  select coalesce(array_agg(k), array[]::text[]) into v_keys from jsonb_object_keys(v_params) k;
  foreach v_k in array v_keys loop
    if not (v_k = any (public.item_group_params())) then
      perform public.stock_config_refuse('parameters.' || v_k, 'unknown');
    end if;
    perform public.item_group_check_value(p_workspace_id, v_k, v_params -> v_k);
  end loop;
  perform public.item_group_finance_guard(p_workspace_id, v_keys);
  if not p_apply then
    begin
      v_result := public.item_group_save_core(p_workspace_id, v_me, null, p_group_id, p_expected_revision, p_body, v_params, true);
    exception when sqlstate 'DKGZZ' then
      get stacked diagnostics v_digest = pg_exception_detail;
      return v_digest::jsonb;
    end;
    return v_result;
  end if;
  v_digest := md5(jsonb_build_array(p_group_id, p_expected_revision, p_body)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'item_group_save', v_digest);
  if v_done is not null then return v_done; end if;
  v_result := public.item_group_save_core(p_workspace_id, v_me, p_request_id, p_group_id, p_expected_revision, p_body, v_params, false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'item_group_save', v_digest, v_result);
end;
$fn$;
revoke execute on function public.item_group_save_v1(uuid, uuid, uuid, int, jsonb, boolean) from public, anon;
grant execute on function public.item_group_save_v1(uuid, uuid, uuid, int, jsonb, boolean) to authenticated;

-- The work of a save. dry: everything is done and rolled back, and the answer is the preview.
create or replace function public.item_group_save_core(
  p_workspace_id uuid, p_me uuid, p_request_id uuid, p_group_id uuid, p_expected int,
  p_body jsonb, p_params jsonb, p_dry boolean)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_old public.item_groups;
  v_new public.item_groups;
  v_parent_old public.item_groups;
  v_parent_new public.item_groups;
  v_creating boolean;
  v_patch jsonb := '{}'::jsonb;
  v_tracking text;
  v_changed text[] := array[]::text[];
  v_all text[] := public.item_group_params();
  v_param text;
  v_kind text;
  i public.services;
  c public.item_groups;
  v_lv_before jsonb[];
  v_lv_after jsonb[];
  v_before jsonb;
  v_after jsonb;
  v_reason text;
  v_skipped jsonb := '[]'::jsonb;
  v_items int := 0;
  v_idx int;
  v_aff int[];
  v_keep int[];
  v_skip int[];
  v_params_out jsonb := '{}'::jsonb;
  v_result jsonb;
  v_oldj jsonb;
  v_newj jsonb;
  v_parent_changed boolean;
  v_pre_parent uuid;
begin
  begin
    v_pre_parent := nullif(p_body ->> 'parent_id', '')::uuid;
  exception when others then
    perform public.stock_config_refuse('parent_id', 'malformed');
  end;
  perform public.item_group_lock(array[p_group_id, v_pre_parent], true);
  select * into v_old from public.item_groups where id = p_group_id and workspace_id = p_workspace_id for update;
  v_creating := v_old.id is null;
  if v_creating then
    if p_expected <> 0 then
      raise exception 'not a group of this business' using errcode = 'DKG04';
    end if;
    if exists (select 1 from public.item_groups g where g.id = p_group_id) then
      raise exception 'not a group of this business' using errcode = 'DKG04';
    end if;
    if not (p_body ? 'name') then
      perform public.stock_config_refuse('name', 'required');
    end if;
    v_old := jsonb_populate_record(null::public.item_groups,
      jsonb_build_object('id', p_group_id, 'workspace_id', p_workspace_id, 'name', 'new', 'revision', 0));
  elsif v_old.revision <> p_expected then
    raise exception 'the group changed since it was read' using errcode = 'DKG10';
  end if;
  if p_body ? 'name' then v_patch := v_patch || jsonb_build_object('name', p_body -> 'name'); end if;
  if p_body ? 'parent_id' then v_patch := v_patch || jsonb_build_object('parent_id', p_body -> 'parent_id'); end if;
  v_patch := v_patch || p_params;
  begin
    v_new := jsonb_populate_record(v_old, v_patch);
  exception when others then
    perform public.stock_config_refuse('body', 'malformed');
  end;
  v_new.revision := v_old.revision + 1;
  if char_length(btrim(coalesce(v_new.name, ''))) not between 1 and 80 then
    perform public.stock_config_refuse('name', 'name_length');
  end if;
  if v_new.parent_id is not null then
    select * into v_parent_new from public.item_groups where id = v_new.parent_id and workspace_id = p_workspace_id;
    if v_parent_new.id is null or v_new.parent_id = v_new.id then
      perform public.stock_config_refuse('parent_id', 'group_unknown');
    end if;
  end if;
  if v_old.parent_id is not null then
    select * into v_parent_old from public.item_groups where id = v_old.parent_id;
  end if;
  -- moving a group in use under another parent changes the finance values its items inherit
  if not v_creating and v_old.parent_id is distinct from v_new.parent_id
     and exists (select 1 from public.services s where s.workspace_id = p_workspace_id
                  and (s.group_id = p_group_id or s.group_id in (select g.id from public.item_groups g where g.parent_id = p_group_id))) then
    foreach v_param in array array['vat_rate_id', 'supply_class', 'price_rounding', 'target_margin_bps'] loop
      if public.item_chain_pick(array[to_jsonb(v_old), to_jsonb(v_parent_old)], v_param)
         is distinct from public.item_chain_pick(array[to_jsonb(v_new), to_jsonb(v_parent_new)], v_param) then
        perform public.item_group_finance_guard(p_workspace_id, array[v_param]);
      end if;
    end loop;
  end if;
  -- a per-unit tag needs tracking by piece, here or above
  v_tracking := coalesce(v_new.tracking, v_parent_new.tracking);
  if v_new.tag_mode = 'per_unit' and v_tracking is distinct from 'serial' then
    perform public.stock_config_refuse('tag_mode', 'needs_serial');
  end if;
  begin
    if v_creating then
      insert into public.item_groups (id, workspace_id, parent_id, name, revision, tracking, shelf_life_days, tag_mode,
        inventory_unit, default_purchase_unit, default_purchase_factor_num, default_purchase_factor_den, vat_rate_id,
        supply_class, price_rounding, target_margin_bps, reorder_point_default, reorder_quantity_default, home_zone_id,
        count_every_days, till_category, quick_key_colour, min_age, sold_by_weight, weight_basis,
        deposit_item_id, deposit_minor, label_template)
      values (v_new.id, v_new.workspace_id, v_new.parent_id, btrim(v_new.name), 1, v_new.tracking, v_new.shelf_life_days, v_new.tag_mode,
        v_new.inventory_unit, v_new.default_purchase_unit, v_new.default_purchase_factor_num, v_new.default_purchase_factor_den,
        v_new.vat_rate_id, v_new.supply_class, v_new.price_rounding, v_new.target_margin_bps, v_new.reorder_point_default,
        v_new.reorder_quantity_default, v_new.home_zone_id, v_new.count_every_days, v_new.till_category,
        v_new.quick_key_colour, v_new.min_age, v_new.sold_by_weight, v_new.weight_basis, v_new.deposit_item_id,
        v_new.deposit_minor, v_new.label_template);
      v_new.revision := 1;
    else
      update public.item_groups set parent_id = v_new.parent_id, name = btrim(v_new.name), revision = v_new.revision,
        tracking = v_new.tracking, shelf_life_days = v_new.shelf_life_days, tag_mode = v_new.tag_mode,
        inventory_unit = v_new.inventory_unit, default_purchase_unit = v_new.default_purchase_unit,
        default_purchase_factor_num = v_new.default_purchase_factor_num, default_purchase_factor_den = v_new.default_purchase_factor_den,
        vat_rate_id = v_new.vat_rate_id, supply_class = v_new.supply_class, price_rounding = v_new.price_rounding,
        target_margin_bps = v_new.target_margin_bps, reorder_point_default = v_new.reorder_point_default,
        reorder_quantity_default = v_new.reorder_quantity_default, home_zone_id = v_new.home_zone_id,
        count_every_days = v_new.count_every_days, till_category = v_new.till_category, quick_key_colour = v_new.quick_key_colour,
        min_age = v_new.min_age, sold_by_weight = v_new.sold_by_weight, weight_basis = v_new.weight_basis,
        deposit_item_id = v_new.deposit_item_id, deposit_minor = v_new.deposit_minor, label_template = v_new.label_template
       where id = v_new.id;
    end if;
  exception
    when unique_violation then perform public.stock_config_refuse('name', 'name_duplicate');
    when check_violation then perform public.stock_config_refuse('parameters', 'out_of_range');
    when foreign_key_violation then perform public.stock_config_refuse('parameters', 'unknown_reference');
  end;
  v_oldj := to_jsonb(v_old);
  v_newj := to_jsonb(v_new);
  v_parent_changed := v_old.parent_id is distinct from v_new.parent_id;
  foreach v_param in array v_all loop
    if v_parent_changed or v_oldj -> v_param is distinct from v_newj -> v_param then
      v_changed := v_changed || v_param;
    end if;
  end loop;
  v_aff := array_fill(0, array[coalesce(array_length(v_changed, 1), 1)]);
  v_keep := v_aff;
  v_skip := v_aff;
  for i in select s.* from public.services s
            where s.workspace_id = p_workspace_id
              and (s.group_id = p_group_id or s.group_id in (select g.id from public.item_groups g where g.parent_id = p_group_id))
            order by s.id for update loop
    v_items := v_items + 1;
    if i.group_id = p_group_id then
      v_lv_before := array[v_oldj, to_jsonb(v_parent_old)];
      v_lv_after := array[v_newj, to_jsonb(v_parent_new)];
    else
      select * into c from public.item_groups where id = i.group_id;
      v_lv_before := array[to_jsonb(c), v_oldj];
      v_lv_after := array[to_jsonb(c), v_newj];
    end if;
    for v_idx in 1 .. coalesce(array_length(v_changed, 1), 0) loop
      v_param := v_changed[v_idx];
      v_kind := public.item_group_param_kind(v_param);
      if v_kind = 'proposal' then continue; end if;
      v_before := public.item_chain_pick(v_lv_before, v_param);
      v_after := public.item_chain_pick(v_lv_after, v_param);
      if v_kind = 'stored' then
        if v_param = any (i.group_overrides) then
          if v_after is not null and v_after is distinct from v_before then v_keep[v_idx] := v_keep[v_idx] + 1; end if;
        elsif v_after is not null and to_jsonb(i) -> v_param is distinct from v_after then
          v_reason := public.item_apply_stored(i.id, v_param, v_after);
          if v_reason is null then
            v_aff[v_idx] := v_aff[v_idx] + 1;
          else
            v_skip[v_idx] := v_skip[v_idx] + 1;
            v_skipped := v_skipped || jsonb_build_object('item_id', i.id, 'parameter', v_param, 'reason', v_reason);
          end if;
        end if;
      else
        if to_jsonb(i) -> v_param is not null and to_jsonb(i) -> v_param <> 'null'::jsonb then
          if v_after is distinct from v_before then v_keep[v_idx] := v_keep[v_idx] + 1; end if;
        elsif v_after is distinct from v_before then
          v_aff[v_idx] := v_aff[v_idx] + 1;
        end if;
      end if;
    end loop;
  end loop;
  for v_idx in 1 .. coalesce(array_length(v_changed, 1), 0) loop
    v_param := v_changed[v_idx];
    v_params_out := v_params_out || jsonb_build_object(v_param, jsonb_build_object(
      'affected', v_aff[v_idx], 'kept_own', v_keep[v_idx], 'skipped', v_skip[v_idx]));
    insert into public.item_group_history (workspace_id, group_id, parameter, old_value, new_value, affected, kept_own, skipped,
                                           changed_by_member_id, request_id)
    values (p_workspace_id, p_group_id, v_param, v_oldj -> v_param, v_newj -> v_param,
            v_aff[v_idx], v_keep[v_idx], v_skip[v_idx], p_me, p_request_id);
  end loop;
  foreach v_param in array array['name', 'parent_id'] loop
    if v_creating or v_oldj -> v_param is distinct from v_newj -> v_param then
      insert into public.item_group_history (workspace_id, group_id, parameter, old_value, new_value, changed_by_member_id, request_id)
      values (p_workspace_id, p_group_id, v_param, case when v_creating then null else v_oldj -> v_param end,
              v_newj -> v_param, p_me, p_request_id);
    end if;
  end loop;
  v_result := jsonb_build_object('group_id', p_group_id, 'revision', v_new.revision, 'created', v_creating,
    'applied', not p_dry, 'items', v_items, 'parameters', v_params_out, 'skipped', v_skipped);
  if p_dry then
    raise exception 'preview' using errcode = 'DKGZZ', detail = v_result::text;
  end if;
  return v_result;
end;
$fn$;
revoke execute on function public.item_group_save_core(uuid, uuid, uuid, uuid, int, jsonb, jsonb, boolean) from public, anon, authenticated;

-- ── an item moves to a group, or out of one ────────────────────────────
create or replace function public.item_group_assign_core(
  p_workspace_id uuid, p_me uuid, p_request_id uuid, p_item_id uuid, p_expected int, p_group_id uuid, p_dry boolean)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  i public.services;
  n public.item_groups;
  q public.item_groups;
  o public.item_groups;
  oq public.item_groups;
  v_lv_before jsonb[] := array[]::jsonb[];
  v_lv_after jsonb[] := array[]::jsonb[];
  v_param text;
  v_kind text;
  v_before jsonb;
  v_after jsonb;
  v_reason text;
  v_aff int := 0;
  v_skip int := 0;
  v_skipped jsonb := '[]'::jsonb;
  v_result jsonb;
  v_pre_group uuid;
begin
  select s.group_id into v_pre_group from public.services s where s.id = p_item_id and s.workspace_id = p_workspace_id;
  perform public.item_group_lock(array[v_pre_group, p_group_id], false);
  select * into i from public.services where id = p_item_id and workspace_id = p_workspace_id for update;
  if i.id is null then
    raise exception 'not an item of this business' using errcode = 'DKG04';
  end if;
  if i.stock_revision <> p_expected or i.group_id is distinct from v_pre_group then
    raise exception 'the stock configuration of this item changed since it was read' using errcode = 'DKG10';
  end if;
  if p_group_id is not null then
    select * into n from public.item_groups where id = p_group_id and workspace_id = p_workspace_id;
    if n.id is null then
      perform public.stock_config_refuse('group_id', 'group_unknown');
    end if;
    if n.parent_id is not null then select * into q from public.item_groups where id = n.parent_id; end if;
    v_lv_after := array[to_jsonb(n), to_jsonb(q)];
  end if;
  if i.group_id is not null then
    select * into o from public.item_groups where id = i.group_id;
    if o.parent_id is not null then select * into oq from public.item_groups where id = o.parent_id; end if;
    v_lv_before := array[to_jsonb(o), to_jsonb(oq)];
  end if;
  if i.group_id is not distinct from p_group_id then
    v_result := jsonb_build_object('item_id', i.id, 'revision', i.stock_revision, 'group_id', p_group_id,
      'applied', not p_dry, 'affected', 0, 'skipped', '[]'::jsonb, 'unchanged', true);
    if p_dry then
      raise exception 'preview' using errcode = 'DKGZZ', detail = v_result::text;
    end if;
    return v_result;
  end if;
  foreach v_param in array public.item_group_params() loop
    v_kind := public.item_group_param_kind(v_param);
    v_before := public.item_chain_pick(v_lv_before, v_param);
    v_after := public.item_chain_pick(v_lv_after, v_param);
    if v_kind = 'proposal' then
      -- the margin and the rounding an item is proposed a price with are finance values too
      if public.item_group_param_finance(v_param) and v_before is distinct from v_after then
        perform public.item_group_finance_guard(p_workspace_id, array[v_param]);
      end if;
      continue;
    end if;
    if v_kind = 'stored' then
      if not (v_param = any (i.group_overrides)) and v_after is not null and to_jsonb(i) -> v_param is distinct from v_after then
        -- a move that would write what an item sells for needs the finances, as setting it does
        perform public.item_group_finance_guard(p_workspace_id, array[v_param]);
        v_reason := public.item_apply_stored(i.id, v_param, v_after);
        if v_reason is null then
          v_aff := v_aff + 1;
        else
          v_skip := v_skip + 1;
          v_skipped := v_skipped || jsonb_build_object('item_id', i.id, 'parameter', v_param, 'reason', v_reason);
        end if;
      end if;
    elsif (to_jsonb(i) -> v_param is null or to_jsonb(i) -> v_param = 'null'::jsonb) and v_after is distinct from v_before then
      v_aff := v_aff + 1;
    end if;
  end loop;
  update public.services set group_id = p_group_id, stock_revision = stock_revision + 1,
         group_overrides = case when p_group_id is null then '{}'::text[] else group_overrides end
   where id = i.id returning stock_revision into i.stock_revision;
  insert into public.item_group_history (workspace_id, group_id, item_id, parameter, old_value, new_value, affected, skipped,
                                         changed_by_member_id, request_id)
  values (p_workspace_id, p_group_id, i.id, 'group_id', to_jsonb(o.id), to_jsonb(p_group_id), v_aff, v_skip, p_me, p_request_id);
  v_result := jsonb_build_object('item_id', i.id, 'revision', i.stock_revision, 'group_id', p_group_id,
    'applied', not p_dry, 'affected', v_aff, 'skipped', v_skipped);
  if p_dry then
    raise exception 'preview' using errcode = 'DKGZZ', detail = v_result::text;
  end if;
  return v_result;
end;
$fn$;
revoke execute on function public.item_group_assign_core(uuid, uuid, uuid, uuid, int, uuid, boolean) from public, anon, authenticated;

create or replace function public.item_group_assign_v1(
  p_workspace_id uuid, p_request_id uuid, p_item_id uuid, p_expected_revision int, p_group_id uuid,
  p_apply boolean default true)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_detail text;
  v_result jsonb;
begin
  v_me := public.item_group_actor(p_workspace_id);
  if p_item_id is null or p_expected_revision is null or (p_apply and p_request_id is null) then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  if not p_apply then
    begin
      v_result := public.item_group_assign_core(p_workspace_id, v_me, null, p_item_id, p_expected_revision, p_group_id, true);
    exception when sqlstate 'DKGZZ' then
      get stacked diagnostics v_detail = pg_exception_detail;
      return v_detail::jsonb;
    end;
    return v_result;
  end if;
  v_digest := md5(jsonb_build_array(p_item_id, p_expected_revision, p_group_id)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'item_group_assign', v_digest);
  if v_done is not null then return v_done; end if;
  v_result := public.item_group_assign_core(p_workspace_id, v_me, p_request_id, p_item_id, p_expected_revision, p_group_id, false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'item_group_assign', v_digest, v_result);
end;
$fn$;
revoke execute on function public.item_group_assign_v1(uuid, uuid, uuid, int, uuid, boolean) from public, anon;
grant execute on function public.item_group_assign_v1(uuid, uuid, uuid, int, uuid, boolean) to authenticated;

-- ── an item keeps its own value, or gives it back to its group ─────────
create or replace function public.item_override_save_v1(
  p_workspace_id uuid, p_request_id uuid, p_item_id uuid, p_expected_revision int,
  p_parameter text, p_mode text, p_value jsonb default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_kind text;
  v_digest text;
  v_done jsonb;
  i public.services;
  n public.item_groups;
  q public.item_groups;
  v_old jsonb;
  v_new jsonb;
  v_pick jsonb;
  v_reason text;
  v_type text;
  v_result jsonb;
  v_pre_group uuid;
begin
  v_me := public.item_group_actor(p_workspace_id);
  v_kind := public.item_group_param_kind(p_parameter);
  if p_request_id is null or p_item_id is null or p_expected_revision is null or v_kind is null
     or p_mode is null or p_mode not in ('set', 'inherit') then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  if v_kind = 'proposal' then
    perform public.stock_config_refuse(p_parameter, 'not_overridable');
  end if;
  perform public.item_group_finance_guard(p_workspace_id, array[p_parameter]);
  if p_mode = 'set' then
    if p_value is null or p_value = 'null'::jsonb then
      perform public.stock_config_refuse(p_parameter, 'value_required');
    end if;
    perform public.item_group_check_value(p_workspace_id, p_parameter, p_value);
  end if;
  v_digest := md5(jsonb_build_array(p_item_id, p_expected_revision, p_parameter, p_mode, p_value)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'item_override_save', v_digest);
  if v_done is not null then return v_done; end if;
  select s.group_id into v_pre_group from public.services s where s.id = p_item_id and s.workspace_id = p_workspace_id;
  perform public.item_group_lock(array[v_pre_group], false);
  select * into i from public.services where id = p_item_id and workspace_id = p_workspace_id for update;
  if i.id is null then
    raise exception 'not an item of this business' using errcode = 'DKG04';
  end if;
  if i.stock_revision <> p_expected_revision or i.group_id is distinct from v_pre_group then
    raise exception 'the stock configuration of this item changed since it was read' using errcode = 'DKG10';
  end if;
  v_old := to_jsonb(i) -> p_parameter;
  if v_kind = 'stored' then
    if p_mode = 'set' then
      v_reason := public.item_apply_stored(i.id, p_parameter, p_value);
      if v_reason is not null then
        perform public.stock_config_refuse(p_parameter, v_reason);
      end if;
      if i.group_id is not null then
        update public.services set group_overrides = (select array_agg(distinct x) from unnest(group_overrides || p_parameter) x)
         where id = i.id;
      end if;
    else
      update public.services set group_overrides = array_remove(group_overrides, p_parameter) where id = i.id;
      if i.group_id is not null then
        select * into n from public.item_groups where id = i.group_id;
        if n.parent_id is not null then select * into q from public.item_groups where id = n.parent_id; end if;
        v_pick := public.item_chain_pick(array[to_jsonb(n), to_jsonb(q)], p_parameter);
        if v_pick is not null then
          v_reason := public.item_apply_stored(i.id, p_parameter, v_pick);
          if v_reason is not null then
            perform public.stock_config_refuse(p_parameter, v_reason);
          end if;
        end if;
      end if;
    end if;
  else
    if p_mode = 'set' and p_parameter = 'tag_mode' and p_value #>> '{}' = 'per_unit' and i.tracking <> 'serial' then
      perform public.stock_config_refuse(p_parameter, 'needs_serial');
    end if;
    select format_type(a.atttypid, a.atttypmod) into v_type from pg_attribute a
     where a.attrelid = 'public.services'::regclass and a.attname = p_parameter;
    begin
      if p_mode = 'set' then
        execute format('update public.services set %I = (%L::jsonb #>> ''{}'')::%s where id = $1', p_parameter, p_value::text, v_type)
          using i.id;
      else
        execute format('update public.services set %I = null where id = $1', p_parameter) using i.id;
      end if;
    exception
      when check_violation or invalid_text_representation or numeric_value_out_of_range then
        perform public.stock_config_refuse(p_parameter, 'out_of_range');
      when foreign_key_violation then
        perform public.stock_config_refuse(p_parameter, 'unknown_reference');
    end;
  end if;
  update public.services set stock_revision = stock_revision + 1 where id = i.id returning * into i;
  v_new := to_jsonb(i) -> p_parameter;
  insert into public.item_group_history (workspace_id, item_id, parameter, old_value, new_value, affected, changed_by_member_id, request_id)
  values (p_workspace_id, i.id, p_parameter, v_old, v_new, 1, v_me, p_request_id);
  v_result := jsonb_build_object('item_id', i.id, 'revision', i.stock_revision, 'parameter', p_parameter,
    'effective', public.item_effective_core(i.id) -> 'parameters' -> p_parameter);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'item_override_save', v_digest, v_result);
end;
$fn$;
revoke execute on function public.item_override_save_v1(uuid, uuid, uuid, int, text, text, jsonb) from public, anon;
grant execute on function public.item_override_save_v1(uuid, uuid, uuid, int, text, text, jsonb) to authenticated;

-- ── a group nothing uses is deleted ────────────────────────────────────
create or replace function public.item_group_delete_v1(
  p_workspace_id uuid, p_request_id uuid, p_group_id uuid, p_expected_revision int)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  g public.item_groups;
  v_n int;
  v_result jsonb;
begin
  v_me := public.item_group_actor(p_workspace_id);
  if p_request_id is null or p_group_id is null or p_expected_revision is null then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  v_digest := md5(jsonb_build_array(p_group_id, p_expected_revision)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'item_group_delete', v_digest);
  if v_done is not null then return v_done; end if;
  select * into g from public.item_groups where id = p_group_id and workspace_id = p_workspace_id for update;
  if g.id is null then
    raise exception 'not a group of this business' using errcode = 'DKG04';
  end if;
  if g.revision <> p_expected_revision then
    raise exception 'the group changed since it was read' using errcode = 'DKG10';
  end if;
  if exists (select 1 from public.item_groups c where c.parent_id = g.id) then
    perform public.stock_config_refuse('group_id', 'has_subgroups');
  end if;
  select count(*) into v_n from public.services s where s.group_id = g.id;
  if v_n > 0 then
    raise exception 'this group is used by % items: move them first', v_n using errcode = 'DKG11',
      detail = jsonb_build_object('field', 'group_id', 'reason', 'in_use', 'items', v_n)::text;
  end if;
  delete from public.item_groups where id = g.id;
  insert into public.item_group_history (workspace_id, group_id, parameter, old_value, changed_by_member_id, request_id)
  values (p_workspace_id, g.id, 'deleted', to_jsonb(g.name), v_me, p_request_id);
  v_result := jsonb_build_object('group_id', g.id, 'deleted', true);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'item_group_delete', v_digest, v_result);
end;
$fn$;
revoke execute on function public.item_group_delete_v1(uuid, uuid, uuid, int) from public, anon;
grant execute on function public.item_group_delete_v1(uuid, uuid, uuid, int) to authenticated;

-- ── reads ──────────────────────────────────────────────────────────────
-- Whoever sees the stock reads the groups; an assistant session reads their names only.
create or replace function public.item_groups_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_assistant boolean := public.mcp_is_delegated();
begin
  if auth.uid() is null
     or not exists (select 1 from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active')
     or not (public.has_permission(p_workspace_id, 'viewStock') or public.has_permission(p_workspace_id, 'manageStock')) then
    raise exception 'not allowed to read the item groups' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'stockItemGroups') then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(case when v_assistant
        then jsonb_build_object('id', g.id, 'parent_id', g.parent_id, 'name', g.name)
        else (to_jsonb(g) - public.system_column_names() - 'workspace_id'
              - case when public.has_permission(p_workspace_id, 'viewFinances') then array[]::text[] else array['target_margin_bps', 'price_rounding'] end)
             || jsonb_build_object('items', (select count(*) from public.services s where s.group_id = g.id)) end
      order by coalesce((select p.name from public.item_groups p where p.id = g.parent_id), g.name), g.parent_id nulls first, g.name)
      from public.item_groups g where g.workspace_id = p_workspace_id), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.item_groups_v1(uuid) from public, anon;
grant execute on function public.item_groups_v1(uuid) to authenticated;

create or replace function public.item_group_history_v1(
  p_workspace_id uuid, p_group_id uuid default null, p_item_id uuid default null, p_limit int default 50)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_finance boolean;
begin
  perform public.item_group_actor(p_workspace_id);
  v_finance := public.has_permission(p_workspace_id, 'viewFinances');
  return coalesce((
    select jsonb_agg(jsonb_build_object('at', h.created_datetime, 'group_id', h.group_id, 'item_id', h.item_id,
             'parameter', h.parameter,
             'old', case when public.item_group_param_finance(h.parameter) and not v_finance then null else h.old_value end,
             'new', case when public.item_group_param_finance(h.parameter) and not v_finance then null else h.new_value end,
             'affected', h.affected,
             'kept_own', h.kept_own, 'skipped', h.skipped, 'by', h.changed_by_member_id) order by h.created_datetime desc, h.id)
      from (select * from public.item_group_history x
             where x.workspace_id = p_workspace_id
               and (p_group_id is null or x.group_id = p_group_id) and (p_item_id is null or x.item_id = p_item_id)
             order by x.created_datetime desc, x.id limit least(greatest(coalesce(p_limit, 50), 1), 200)) h), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.item_group_history_v1(uuid, uuid, uuid, int) from public, anon;
grant execute on function public.item_group_history_v1(uuid, uuid, uuid, int) to authenticated;

-- ── an edit of the item itself keeps what it changes ───────────────────
-- restates 0836
do $patch$
declare
  v_def text := pg_get_functiondef('public.save_stock_item_v1(uuid, uuid, int, uuid, jsonb)'::regprocedure);
  v_next text;
begin
  v_next := pg_temp.anchor_replace(v_def, $o$         inventory_unit = v_inventory, tracking = v_tracking, shelf_life_days = v_shelf,
         stock_revision = stock_revision + 1$o$, $n$         inventory_unit = v_inventory, tracking = v_tracking, shelf_life_days = v_shelf,
         group_overrides = case when group_id is null then group_overrides else
           (select coalesce(array_agg(distinct x), '{}'::text[]) from unnest(group_overrides || array_remove(array[
              case when v_tracking is distinct from v_item.tracking then 'tracking' end,
              case when v_inventory is distinct from v_item.inventory_unit then 'inventory_unit' end,
              case when v_shelf is distinct from v_item.shelf_life_days then 'shelf_life_days' end], null)) x) end,
         stock_revision = stock_revision + 1$n$);
  if v_next is null then raise exception '0883: the item update of save_stock_item_v1 is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(883);
