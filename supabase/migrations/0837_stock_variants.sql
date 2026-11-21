-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (the balances' uniqueness gains the variant, and the ledger's functions carry
--  it; every existing row has no variant and every existing amount is the same)
--
-- #4169 (A2) -- item dimensions and variants, and the supplier's article
-- mapping, in the stock ledger.
--
-- A dimension (Colour, Size) and its allowed values belong to the business; an
-- item has variants, each a combination of one value per dimension, unique
-- per item. A variant shares its item's inventory unit and supply nature. It
-- takes part in the LEDGER: red and blue of one item at one place are separate
-- stock (stock_balances is unique on item, variant, lot and place, nulls not
-- distinct), a movement names its variant, a lot belongs to one variant, and a
-- code (a barcode) may name a variant. An item without variants keeps
-- variant_id null everywhere, and every amount and answer of the ledger is
-- unchanged (test 410 runs unchanged on this migration).
--
-- A supplier's article is mapped to an item (and variant) and one of the
-- item's package units, by an explicit save: a name never binds it.

-- ── dimensions, values, variants ────────────────────────────────────────
create table public.item_dimensions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  active boolean not null default true,
  revision int not null default 1,
  unique (workspace_id, id),
  unique (workspace_id, name)
);
select public.ensure_system_columns('item_dimensions');

create table public.item_dimension_values (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  dimension_id uuid not null,
  label text not null check (char_length(btrim(label)) between 1 and 60),
  active boolean not null default true,
  unique (workspace_id, id),
  unique (id, dimension_id),
  unique (dimension_id, label),
  foreign key (workspace_id, dimension_id) references public.item_dimensions (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('item_dimension_values');

create table public.item_variants (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  item_id uuid not null,
  -- the combination, canonical: `dimension:value` pairs sorted, comma separated
  canonical text not null,
  price_cents int check (price_cents is null or price_cents >= 0),
  active boolean not null default true,
  unique (workspace_id, id),
  unique (item_id, id),
  unique (item_id, canonical),
  foreign key (workspace_id, item_id) references public.services (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('item_variants');

create table public.item_variant_values (
  variant_id uuid not null,
  dimension_id uuid not null,
  value_id uuid not null,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  primary key (variant_id, dimension_id),
  foreign key (workspace_id, variant_id) references public.item_variants (workspace_id, id) on delete cascade,
  foreign key (value_id, dimension_id) references public.item_dimension_values (id, dimension_id)
);
select public.ensure_system_columns('item_variant_values');

alter table public.item_dimensions enable row level security;
alter table public.item_dimension_values enable row level security;
alter table public.item_variants enable row level security;
alter table public.item_variant_values enable row level security;
revoke all on public.item_dimensions, public.item_dimension_values, public.item_variants,
  public.item_variant_values from public, anon, authenticated;
grant select on public.item_dimensions, public.item_dimension_values, public.item_variants,
  public.item_variant_values to authenticated;
create policy item_dimensions_select on public.item_dimensions for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy item_dimension_values_select on public.item_dimension_values for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy item_variants_select on public.item_variants for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy item_variant_values_select on public.item_variant_values for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy mcp_delegated_deny on public.item_dimensions as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.item_dimension_values as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.item_variants as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.item_variant_values as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the supplier's article ──────────────────────────────────────────────
create table public.supplier_item_mappings (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  supplier_id uuid not null,
  item_id uuid not null,
  variant_id uuid,
  article_ref text not null check (char_length(btrim(article_ref)) between 1 and 80),
  -- null: the item's inventory unit; else one of its package units
  purchase_unit text,
  active boolean not null default true,
  revision int not null default 1,
  unique (workspace_id, id),
  unique (supplier_id, article_ref),
  foreign key (workspace_id, supplier_id) references public.suppliers (workspace_id, id),
  foreign key (workspace_id, item_id) references public.services (workspace_id, id),
  foreign key (item_id, variant_id) references public.item_variants (item_id, id),
  foreign key (item_id, purchase_unit) references public.item_units (item_id, unit)
);
select public.ensure_system_columns('supplier_item_mappings');
alter table public.supplier_item_mappings enable row level security;
revoke all on public.supplier_item_mappings from public, anon, authenticated;
grant select on public.supplier_item_mappings to authenticated;
create policy supplier_item_mappings_select on public.supplier_item_mappings for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockManagement'));
create policy mcp_delegated_deny on public.supplier_item_mappings as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the ledger carries the variant ──────────────────────────────────────
alter table public.item_codes add column variant_id uuid;
alter table public.item_codes add constraint item_codes_variant_fkey
  foreign key (item_id, variant_id) references public.item_variants (item_id, id);
alter table public.stock_lots add column variant_id uuid;
alter table public.stock_lots add constraint stock_lots_variant_fkey
  foreign key (item_id, variant_id) references public.item_variants (item_id, id);
alter table public.stock_movements add column variant_id uuid;
alter table public.stock_movements add constraint stock_movements_variant_fkey
  foreign key (item_id, variant_id) references public.item_variants (item_id, id);
alter table public.stock_balances add column variant_id uuid;
alter table public.stock_balances add constraint stock_balances_variant_fkey
  foreign key (item_id, variant_id) references public.item_variants (item_id, id);
create index stock_balances_variant on public.stock_balances (variant_id) where variant_id is not null;

-- The balance of one item, variant, lot and place. The old key (without the
-- variant) is dropped by what it covers, whatever it was named.
do $k$
declare
  v_name text;
  v_dropped int := 0;
begin
  for v_name in
    select c.conname from pg_constraint c
     where c.conrelid = 'public.stock_balances'::regclass and c.contype = 'u'
       and (select array_agg(a.attname::text order by a.attname) from pg_attribute a
             where a.attrelid = c.conrelid and a.attnum = any (c.conkey))
           = array['item_id', 'location_id', 'lot_id']
  loop
    execute format('alter table public.stock_balances drop constraint %I', v_name);
    v_dropped := v_dropped + 1;
  end loop;
  if v_dropped <> 1 then
    raise exception '0837: expected to drop exactly one old balance key, dropped %', v_dropped using errcode = 'P0001';
  end if;
end
$k$;
alter table public.stock_balances
  add constraint stock_balances_item_variant_lot_location_key
  unique nulls not distinct (item_id, variant_id, lot_id, location_id);

-- A variant as a person reads it: `Colour: Red · Size: M`.
create or replace function public.stock_variant_label(p_variant_id uuid)
returns text language sql stable security definer set search_path = public as $fn$
  select string_agg(d.name || ': ' || v.label, ' · ' order by d.name)
    from public.item_variant_values x
    join public.item_dimensions d on d.id = x.dimension_id
    join public.item_dimension_values v on v.id = x.value_id
   where x.variant_id = p_variant_id;
$fn$;
revoke execute on function public.stock_variant_label(uuid) from public, anon, authenticated;

-- 0747's stock_take, with the variant: what is taken is that variant's stock.
drop function if exists public.stock_take(uuid, uuid, uuid, numeric);
create or replace function public.stock_take(
  p_workspace_id uuid, p_item_id uuid, p_location_id uuid, p_quantity numeric, p_variant_id uuid default null
) returns table (lot_id uuid, quantity numeric) language plpgsql stable security definer set search_path = public as $fn$
declare
  v_left numeric := p_quantity;
  r record;
begin
  for r in
    select b.lot_id as lot, b.quantity as q
      from public.stock_balances b left join public.stock_lots l on l.id = b.lot_id
     where b.workspace_id = p_workspace_id and b.item_id = p_item_id
       and b.variant_id is not distinct from p_variant_id
       and b.location_id = p_location_id and b.quantity > 0
     order by (b.lot_id is not null), l.expires_on nulls last, l.created_datetime
  loop
    exit when v_left <= 0;
    lot_id := r.lot;
    quantity := least(r.q, v_left);
    v_left := v_left - quantity;
    return next;
  end loop;
  if v_left > 0 then
    lot_id := null;
    quantity := v_left;
    return next;
  end if;
end;
$fn$;
revoke execute on function public.stock_take(uuid, uuid, uuid, numeric, uuid) from public, anon, authenticated;

-- 0747's trigger, with the variant in the balance's key and in the check.
create or replace function public.stock_movements_apply()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_left numeric;
begin
  insert into public.stock_balances (workspace_id, item_id, variant_id, lot_id, location_id, quantity)
  values (new.workspace_id, new.item_id, new.variant_id, new.lot_id, new.from_location_id, -new.quantity),
         (new.workspace_id, new.item_id, new.variant_id, new.lot_id, new.to_location_id, new.quantity)
  on conflict (item_id, variant_id, lot_id, location_id)
  do update set quantity = public.stock_balances.quantity + excluded.quantity;

  if not public.stock_place_is_virtual(new.from_location_id) then
    select b.quantity into v_left from public.stock_balances b
     where b.item_id = new.item_id and b.variant_id is not distinct from new.variant_id
       and b.lot_id is not distinct from new.lot_id
       and b.location_id = new.from_location_id;
    if v_left < 0 and coalesce((public.setting_value(new.workspace_id, 'stock.allow_negative') #>> '{}')::boolean, false) = false then
      raise exception 'not that much on hand at this place' using errcode = 'DKG03';
    end if;
  end if;

  if coalesce(current_setting('deskilo.stock_count_edit', true), '') <> 'on' then
    -- the mirror is not an edit of the count
    perform set_config('deskilo.stock_count_edit', 'on', true);
    update public.services s
       set stock = greatest(0, floor(coalesce((
             select sum(b.quantity) from public.stock_balances b
               join public.stock_locations l on l.id = b.location_id
               join public.stock_location_kinds k on k.key = l.kind
              where b.item_id = new.item_id and not k.virtual), 0)))::int
     where s.id = new.item_id;
    perform set_config('deskilo.stock_count_edit', '', true);
  end if;
  return null;
end;
$fn$;
revoke execute on function public.stock_movements_apply() from public, anon, authenticated;

-- 0836's stock_record, with the variant (an optional last argument).
drop function if exists public.stock_record(uuid, uuid, uuid, uuid, uuid, numeric, text, numeric, timestamptz, text, uuid, uuid, int, int, jsonb);
create or replace function public.stock_record(
  p_workspace_id uuid, p_item_id uuid, p_lot_id uuid, p_from uuid, p_to uuid,
  p_quantity numeric, p_entered_unit text, p_entered_quantity numeric,
  p_occurred_at timestamptz, p_reason text, p_actor uuid, p_request_id uuid,
  p_line_no int, p_part int, p_links jsonb, p_variant_id uuid default null
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
  v_cost numeric;
  v_num bigint;
  v_den bigint;
begin
  if p_lot_id is not null then
    select total_cost_minor::numeric / quantity_received into v_cost
      from public.stock_lots where id = p_lot_id;
  end if;
  select f.num, f.den into v_num, v_den from public.stock_unit_factor(p_item_id, p_entered_unit) f;
  insert into public.stock_movements
    (workspace_id, item_id, variant_id, lot_id, from_location_id, to_location_id, quantity,
     entered_unit, entered_quantity, occurred_at, reason, unit_cost, actor_member_id,
     request_id, line_no, part, receipt_line_id, purchase_line_id, event_id, invoice_id,
     entered_factor_num, entered_factor_den)
  values
    (p_workspace_id, p_item_id, p_variant_id, p_lot_id, p_from, p_to, p_quantity,
     p_entered_unit, p_entered_quantity, p_occurred_at, p_reason, v_cost, p_actor,
     p_request_id, p_line_no, p_part,
     nullif(p_links ->> 'receipt_line_id', '')::uuid, nullif(p_links ->> 'purchase_line_id', '')::uuid,
     nullif(p_links ->> 'event_id', '')::uuid, nullif(p_links ->> 'invoice_id', '')::uuid,
     v_num, v_den)
  returning id into v_id;
  return v_id;
end;
$fn$;
revoke execute on function public.stock_record(uuid, uuid, uuid, uuid, uuid, numeric, text, numeric, timestamptz, text, uuid, uuid, int, int, jsonb, uuid)
  from public, anon, authenticated;

-- ── stock_move_v1 and save_stock_item_v1 carry the variant: anchored patches ──
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

do $patch$
declare
  v_def text;
  v_next text;
  v_step record;
begin
  v_def := pg_get_functiondef('public.stock_move_v1(uuid, uuid, jsonb, text, timestamptz, jsonb)'::regprocedure);
  for v_step in select * from (values
    ('the item row is locked before its quantity is computed (the factor that computed it is the one frozen)',
     $o$where id = nullif(e ->> 'item_id', '')::uuid and workspace_id = p_workspace_id and stockable;$o$,
     $n$where id = nullif(e ->> 'item_id', '')::uuid and workspace_id = p_workspace_id and stockable
     for update;$n$),
    ('declare',
     $o$  v_lot uuid;
  v_part int;$o$,
     $n$  v_lot uuid;
  v_var uuid;
  v_part int;$n$),
    ('resolve the variant before the lot',
     $o$    v_lot := nullif(e ->> 'lot_id', '')::uuid;$o$,
     $n$    v_var := nullif(e ->> 'variant_id', '')::uuid;
    if v_var is not null and not exists (select 1 from public.item_variants x
         where x.id = v_var and x.workspace_id = p_workspace_id and x.item_id = v_item.id and x.active) then
      raise exception 'line %: not a variant of this item', v_no using errcode = 'DKG04';
    end if;
    if v_var is null and exists (select 1 from public.item_variants x where x.item_id = v_item.id and x.active) then
      raise exception 'line %: this item has variants: name which one', v_no using errcode = 'DKG12';
    end if;
    v_lot := nullif(e ->> 'lot_id', '')::uuid;$n$),
    ('a lot belongs to one variant',
     $o$where id = v_lot and workspace_id = p_workspace_id and item_id = v_item.id) then$o$,
     $n$where id = v_lot and workspace_id = p_workspace_id and item_id = v_item.id
         and variant_id is not distinct from v_var) then$n$),
    ('the new lot names the variant (columns)',
     $o$insert into public.stock_lots (workspace_id, item_id, lot_code, expires_on, total_cost_minor,$o$,
     $n$insert into public.stock_lots (workspace_id, item_id, variant_id, lot_code, expires_on, total_cost_minor,$n$),
    ('the new lot names the variant (values)',
     $o$values (p_workspace_id, v_item.id, coalesce(e -> 'new_lot' ->> 'code', ''),$o$,
     $n$values (p_workspace_id, v_item.id, v_var, coalesce(e -> 'new_lot' ->> 'code', ''),$n$),
    ('take from the variant',
     $o$stock_take(p_workspace_id, v_item.id, v_from.id, v_qty)$o$,
     $n$stock_take(p_workspace_id, v_item.id, v_from.id, v_qty, v_var)$n$),
    ('record the taken parts with the variant',
     $o$v_unit, v_entered, v_at, p_reason, v_me, p_request_id, v_no, v_part, v_links);$o$,
     $n$v_unit, v_entered, v_at, p_reason, v_me, p_request_id, v_no, v_part, v_links, v_var);$n$),
    ('record the single movement with the variant',
     $o$v_unit, v_entered, v_at, p_reason, v_me, p_request_id, v_no, 1, v_links);$o$,
     $n$v_unit, v_entered, v_at, p_reason, v_me, p_request_id, v_no, 1, v_links, v_var);$n$)
  ) as t(what, old_text, new_text) loop
    v_next := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_next is null then
      raise exception '0837: the anchor of stock_move_v1 (%) was not found', v_step.what using errcode = 'P0001';
    end if;
    v_def := v_next;
  end loop;
  execute v_def;

  v_def := pg_get_functiondef('public.save_stock_item_v1(uuid, uuid, integer, uuid, jsonb)'::regprocedure);
  for v_step in select * from (values
    ('a code may name a variant of the item (validation)',
     $o$    if v_kind not in ('gtin', 'own') then$o$,
     $n$    if nullif(e ->> 'variant_id', '') is not null and not exists (select 1 from public.item_variants x
         where x.id = nullif(e ->> 'variant_id', '')::uuid and x.workspace_id = p_workspace_id and x.item_id = p_item_id) then
      perform public.stock_config_refuse(format('codes[%s].variant_id', i - 1), 'variant_unknown');
    end if;
    if v_kind not in ('gtin', 'own') then$n$),
    ('a code names its variant (columns)',
     $o$insert into public.item_codes (workspace_id, item_id, unit, code, kind)$o$,
     $n$insert into public.item_codes (workspace_id, item_id, unit, code, kind, variant_id)$n$),
    ('a code names its variant (values)',
     $o$nullif(btrim(coalesce(e ->> 'unit', '')), ''), btrim(e ->> 'code'), e ->> 'kind');$o$,
     $n$nullif(btrim(coalesce(e ->> 'unit', '')), ''), btrim(e ->> 'code'), e ->> 'kind',
            nullif(e ->> 'variant_id', '')::uuid);$n$),
    ('removing a unit a supplier mapping names is refused',
     $o$  select coalesce(jsonb_agg(jsonb_build_object('code', c.code, 'kind', c.kind, 'unit', c.unit)), '[]'::jsonb)$o$,
     $n$  if v_units_given and exists (select 1 from public.supplier_item_mappings mp
        where mp.item_id = p_item_id and mp.purchase_unit is not null and not (mp.purchase_unit = any (v_seen))) then
    perform public.stock_config_refuse('units', 'unit_in_use');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('code', c.code, 'kind', c.kind, 'unit', c.unit)), '[]'::jsonb)$n$),
    ('units are updated in place',
     $o$if v_units_given then delete from public.item_units where item_id = p_item_id; end if;$o$,
     $n$if v_units_given then
    delete from public.item_units where item_id = p_item_id and not (unit = any (v_seen));
    update public.item_units set default_purchase = false, default_sale = false where item_id = p_item_id;
  end if;$n$),
    ('units are written by upsert',
     $o$coalesce((e ->> 'default_purchase')::boolean, false), coalesce((e ->> 'default_sale')::boolean, false));$o$,
     $n$coalesce((e ->> 'default_purchase')::boolean, false), coalesce((e ->> 'default_sale')::boolean, false))
    on conflict (item_id, unit) do update
      set factor_num = excluded.factor_num, factor_den = excluded.factor_den,
          default_purchase = excluded.default_purchase, default_sale = excluded.default_sale;$n$),
    ('the codes kept keep their variant',
     $o$jsonb_build_object('code', c.code, 'kind', c.kind, 'unit', c.unit)$o$,
     $n$jsonb_build_object('code', c.code, 'kind', c.kind, 'unit', c.unit, 'variant_id', c.variant_id)$n$)
  ) as t(what, old_text, new_text) loop
    v_next := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_next is null then
      raise exception '0837: the anchor of save_stock_item_v1 (%) was not found', v_step.what using errcode = 'P0001';
    end if;
    v_def := v_next;
  end loop;
  execute v_def;
end
$patch$;

-- ── dimensions and their values ─────────────────────────────────────────
-- p_dimension: {name, active, values: [{id, label, active}]}. The values sent
-- are the complete list: one that is not sent is deactivated, never deleted
-- (a variant, a movement and a code keep naming it).
create or replace function public.save_item_dimension_v1(
  p_workspace_id uuid, p_dimension_id uuid, p_expected_revision int, p_request_id uuid, p_dimension jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text;
  v_done public.purchase_requests;
  v_old public.item_dimensions;
  v_name text;
  v_active boolean;
  v_values jsonb := coalesce(p_dimension -> 'values', '[]'::jsonb);
  v_labels text[] := array[]::text[];
  e jsonb;
  i int := 0;
  v_label text;
  v_vid uuid;
  v_id uuid;
  v_rev int;
  v_result jsonb;
begin
  perform public.stock_config_actor(p_workspace_id);
  if p_request_id is null or coalesce(jsonb_typeof(p_dimension), '') <> 'object'
     or jsonb_typeof(v_values) <> 'array' or jsonb_array_length(v_values) > 200
     or (p_dimension_id is null) <> (p_expected_revision is null) then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  v_digest := md5('item_dimension_save|' || coalesce(p_dimension_id::text, '') || '|'
                  || coalesce(p_expected_revision::text, '') || '|' || p_dimension::text);
  perform pg_advisory_xact_lock(
    hashtextextended('purchase_request:' || p_workspace_id::text || p_request_id::text, 0));
  select * into v_done from public.purchase_requests
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.operation <> 'item_dimension_save' or v_done.digest <> v_digest then
      raise exception 'this request id was already used for a different request' using errcode = 'DKG07';
    end if;
    return v_done.result || jsonb_build_object('replayed', true);
  end if;
  if p_dimension_id is not null then
    select * into v_old from public.item_dimensions
     where id = p_dimension_id and workspace_id = p_workspace_id for update;
    if v_old.id is null then raise exception 'not a dimension of this business' using errcode = 'DKG04'; end if;
    if v_old.revision <> p_expected_revision then
      raise exception 'this dimension changed since it was read' using errcode = 'DKG10';
    end if;
  end if;
  v_name := btrim(coalesce(p_dimension ->> 'name', v_old.name, ''));
  v_active := coalesce((p_dimension ->> 'active')::boolean, v_old.active, true);
  if char_length(v_name) not between 1 and 60 then perform public.stock_config_refuse('name', 'name_malformed'); end if;
  if exists (select 1 from public.item_dimensions d where d.workspace_id = p_workspace_id and d.name = v_name
              and d.id is distinct from p_dimension_id) then
    perform public.stock_config_refuse('name', 'name_duplicate');
  end if;
  for e in select value from jsonb_array_elements(v_values) loop
    i := i + 1;
    v_label := btrim(coalesce(e ->> 'label', ''));
    if char_length(v_label) not between 1 and 60 then
      perform public.stock_config_refuse(format('values[%s].label', i - 1), 'name_malformed');
    end if;
    if v_label = any (v_labels) then
      perform public.stock_config_refuse(format('values[%s].label', i - 1), 'name_duplicate');
    end if;
    v_labels := v_labels || v_label;
    v_vid := nullif(e ->> 'id', '')::uuid;
    if v_vid is not null and not exists (select 1 from public.item_dimension_values x
         where x.id = v_vid and x.dimension_id = p_dimension_id and x.workspace_id = p_workspace_id) then
      perform public.stock_config_refuse(format('values[%s].id', i - 1), 'value_foreign');
    end if;
    -- a value left out of the list is deactivated and keeps its label
    if p_dimension_id is not null and exists (select 1 from public.item_dimension_values x
         where x.dimension_id = p_dimension_id and x.label = v_label and x.id is distinct from v_vid) then
      perform public.stock_config_refuse(format('values[%s].label', i - 1), 'name_duplicate');
    end if;
  end loop;

  if p_dimension_id is null then
    insert into public.item_dimensions (workspace_id, name, active) values (p_workspace_id, v_name, v_active)
    returning id, revision into v_id, v_rev;
  else
    update public.item_dimensions set name = v_name, active = v_active, revision = revision + 1
     where id = p_dimension_id returning id, revision into v_id, v_rev;
    update public.item_dimension_values set active = false
     where dimension_id = v_id
       and id not in (select nullif(x ->> 'id', '')::uuid from jsonb_array_elements(v_values) x
                       where nullif(x ->> 'id', '') is not null);
  end if;
  for e in select value from jsonb_array_elements(v_values) loop
    v_vid := nullif(e ->> 'id', '')::uuid;
    if v_vid is null then
      insert into public.item_dimension_values (workspace_id, dimension_id, label, active)
      values (p_workspace_id, v_id, btrim(e ->> 'label'), coalesce((e ->> 'active')::boolean, true));
    else
      update public.item_dimension_values
         set label = btrim(e ->> 'label'), active = coalesce((e ->> 'active')::boolean, true)
       where id = v_vid;
    end if;
  end loop;
  v_result := jsonb_build_object('dimension_id', v_id, 'revision', v_rev, 'replayed', false);
  insert into public.purchase_requests (workspace_id, request_id, operation, digest, result)
  values (p_workspace_id, p_request_id, 'item_dimension_save', v_digest, v_result);
  return v_result;
end;
$fn$;
revoke execute on function public.save_item_dimension_v1(uuid, uuid, int, uuid, jsonb) from public, anon;
grant execute on function public.save_item_dimension_v1(uuid, uuid, int, uuid, jsonb) to authenticated;

-- ── the variants of one item ────────────────────────────────────────────
-- p_variants: [{id, values: {<dimension id>: <value id>}, price_cents, active}].
-- The variants sent are the item's complete list; one not sent is
-- deactivated. A combination that something names (a movement, a balance, a
-- lot, a code) stays as written.
create or replace function public.save_item_variants_v1(
  p_workspace_id uuid, p_item_id uuid, p_expected_revision int, p_request_id uuid, p_variants jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text;
  v_done public.purchase_requests;
  v_item public.services;
  e jsonb;
  i int := 0;
  v_vid uuid;
  v_values jsonb;
  v_canonical text;
  v_seen text[] := array[]::text[];
  v_pairs record;
  v_old text;
  v_used boolean;
  v_ids uuid[] := array[]::uuid[];
  v_new uuid;
  v_price int;
  v_result jsonb;
begin
  perform public.stock_config_actor(p_workspace_id);
  if p_request_id is null or p_expected_revision is null
     or coalesce(jsonb_typeof(p_variants), '') <> 'array' or jsonb_array_length(p_variants) > 500 then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  v_digest := md5('item_variants_save|' || p_item_id::text || '|' || p_expected_revision::text || '|' || p_variants::text);
  perform pg_advisory_xact_lock(
    hashtextextended('purchase_request:' || p_workspace_id::text || p_request_id::text, 0));
  select * into v_done from public.purchase_requests
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.operation <> 'item_variants_save' or v_done.digest <> v_digest then
      raise exception 'this request id was already used for a different request' using errcode = 'DKG07';
    end if;
    return v_done.result || jsonb_build_object('replayed', true);
  end if;
  select * into v_item from public.services where id = p_item_id and workspace_id = p_workspace_id for update;
  if v_item.id is null then raise exception 'not an item of this business' using errcode = 'DKG04'; end if;
  if v_item.stock_revision <> p_expected_revision then
    raise exception 'the stock configuration of this item changed since it was read' using errcode = 'DKG10';
  end if;

  for e in select value from jsonb_array_elements(p_variants) loop
    i := i + 1;
    v_values := e -> 'values';
    if coalesce(jsonb_typeof(v_values), '') <> 'object' or v_values = '{}'::jsonb then
      perform public.stock_config_refuse(format('variants[%s].values', i - 1), 'variant_values_missing');
    end if;
    v_price := nullif(e ->> 'price_cents', '')::int;
    if v_price is not null and v_price < 0 then
      perform public.stock_config_refuse(format('variants[%s].price_cents', i - 1), 'price_invalid');
    end if;
    -- every pair names a dimension and one of its values, of this business
    for v_pairs in select k as dimension_id, val as value_id from jsonb_each_text(v_values) as t(k, val) loop
      if not exists (select 1 from public.item_dimension_values x
           where x.id = v_pairs.value_id::uuid and x.dimension_id = v_pairs.dimension_id::uuid
             and x.workspace_id = p_workspace_id) then
        perform public.stock_config_refuse(format('variants[%s].values', i - 1), 'value_foreign');
      end if;
    end loop;
    select string_agg(k || ':' || val, ',' order by k) into v_canonical from jsonb_each_text(v_values) as t(k, val);
    if v_canonical = any (v_seen) then
      perform public.stock_config_refuse(format('variants[%s].values', i - 1), 'variant_combination_duplicate');
    end if;
    v_seen := v_seen || v_canonical;
    v_vid := nullif(e ->> 'id', '')::uuid;
    if v_vid is not null then
      select canonical into v_old from public.item_variants
       where id = v_vid and item_id = p_item_id and workspace_id = p_workspace_id;
      if v_old is null then
        perform public.stock_config_refuse(format('variants[%s].id', i - 1), 'variant_unknown');
      end if;
      if v_old <> v_canonical then
        select exists (select 1 from public.stock_movements where variant_id = v_vid)
            or exists (select 1 from public.stock_balances where variant_id = v_vid)
            or exists (select 1 from public.stock_lots where variant_id = v_vid)
            or exists (select 1 from public.item_codes where variant_id = v_vid)
          into v_used;
        if v_used then
          perform public.stock_config_refuse(format('variants[%s].values', i - 1), 'variant_in_use');
        end if;
      end if;
    end if;
    if exists (select 1 from public.item_variants x where x.item_id = p_item_id and x.canonical = v_canonical
                and x.id is distinct from v_vid) then
      perform public.stock_config_refuse(format('variants[%s].values', i - 1), 'variant_combination_duplicate');
    end if;
  end loop;

  -- a variant with stock stays active: deactivating one strands its stock
  if exists (select 1 from public.item_variants x
               join public.stock_balances b on b.variant_id = x.id and b.quantity <> 0
              where x.item_id = p_item_id and x.active
                and x.id not in (select nullif(y ->> 'id', '')::uuid from jsonb_array_elements(p_variants) y
                                  where nullif(y ->> 'id', '') is not null
                                    and coalesce((y ->> 'active')::boolean, true))) then
    perform public.stock_config_refuse('variants', 'variant_has_stock');
  end if;
  -- an item with active variants is never moved without one: stock that has
  -- none is counted out first and received per variant
  if exists (select 1 from jsonb_array_elements(p_variants) y where coalesce((y ->> 'active')::boolean, true))
     and exists (select 1 from public.stock_balances b where b.item_id = p_item_id and b.variant_id is null and b.quantity <> 0) then
    perform public.stock_config_refuse('variants', 'stock_without_variant');
  end if;

  i := 0;
  for e in select value from jsonb_array_elements(p_variants) loop
    i := i + 1;
    v_values := e -> 'values';
    select string_agg(k || ':' || val, ',' order by k) into v_canonical from jsonb_each_text(v_values) as t(k, val);
    v_vid := nullif(e ->> 'id', '')::uuid;
    if v_vid is null then
      insert into public.item_variants (workspace_id, item_id, canonical, price_cents, active)
      values (p_workspace_id, p_item_id, v_canonical, nullif(e ->> 'price_cents', '')::int, coalesce((e ->> 'active')::boolean, true))
      returning id into v_new;
    else
      update public.item_variants set canonical = v_canonical, price_cents = nullif(e ->> 'price_cents', '')::int,
             active = coalesce((e ->> 'active')::boolean, true)
       where id = v_vid returning id into v_new;
      delete from public.item_variant_values where variant_id = v_new;
    end if;
    insert into public.item_variant_values (workspace_id, variant_id, dimension_id, value_id)
    select p_workspace_id, v_new, k::uuid, val::uuid from jsonb_each_text(v_values) as t(k, val);
    v_ids := v_ids || v_new;
  end loop;
  update public.item_variants set active = false
   where item_id = p_item_id and not (id = any (v_ids));
  update public.services set stock_revision = stock_revision + 1 where id = p_item_id;
  v_result := jsonb_build_object('item_id', p_item_id, 'revision', p_expected_revision + 1, 'replayed', false);
  insert into public.purchase_requests (workspace_id, request_id, operation, digest, result)
  values (p_workspace_id, p_request_id, 'item_variants_save', v_digest, v_result);
  return v_result;
end;
$fn$;
revoke execute on function public.save_item_variants_v1(uuid, uuid, int, uuid, jsonb) from public, anon;
grant execute on function public.save_item_variants_v1(uuid, uuid, int, uuid, jsonb) to authenticated;

-- ── the supplier's article ──────────────────────────────────────────────
-- p_mapping: {supplier_id, item_id, variant_id, article_ref, purchase_unit,
-- active}. An explicit save; a name never binds an article to an item.
create or replace function public.save_supplier_item_mapping_v1(
  p_workspace_id uuid, p_mapping_id uuid, p_expected_revision int, p_request_id uuid, p_mapping jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text;
  v_done public.purchase_requests;
  v_old public.supplier_item_mappings;
  v_supplier uuid;
  v_item uuid;
  v_variant uuid;
  v_ref text;
  v_unit text;
  v_active boolean;
  v_id uuid;
  v_rev int;
  v_result jsonb;
begin
  perform public.stock_config_actor(p_workspace_id);
  if p_request_id is null or coalesce(jsonb_typeof(p_mapping), '') <> 'object'
     or (p_mapping_id is null) <> (p_expected_revision is null) then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  v_digest := md5('supplier_item_mapping_save|' || coalesce(p_mapping_id::text, '') || '|'
                  || coalesce(p_expected_revision::text, '') || '|' || p_mapping::text);
  perform pg_advisory_xact_lock(
    hashtextextended('purchase_request:' || p_workspace_id::text || p_request_id::text, 0));
  select * into v_done from public.purchase_requests
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.operation <> 'supplier_item_mapping_save' or v_done.digest <> v_digest then
      raise exception 'this request id was already used for a different request' using errcode = 'DKG07';
    end if;
    return v_done.result || jsonb_build_object('replayed', true);
  end if;
  if p_mapping_id is not null then
    select * into v_old from public.supplier_item_mappings
     where id = p_mapping_id and workspace_id = p_workspace_id for update;
    if v_old.id is null then raise exception 'not a mapping of this business' using errcode = 'DKG04'; end if;
    if v_old.revision <> p_expected_revision then
      raise exception 'this mapping changed since it was read' using errcode = 'DKG10';
    end if;
  end if;
  v_supplier := coalesce(nullif(p_mapping ->> 'supplier_id', '')::uuid, v_old.supplier_id);
  v_item := coalesce(nullif(p_mapping ->> 'item_id', '')::uuid, v_old.item_id);
  v_variant := case when p_mapping ? 'variant_id' then nullif(p_mapping ->> 'variant_id', '')::uuid else v_old.variant_id end;
  v_ref := btrim(coalesce(p_mapping ->> 'article_ref', v_old.article_ref, ''));
  v_unit := case when p_mapping ? 'purchase_unit' then nullif(btrim(coalesce(p_mapping ->> 'purchase_unit', '')), '') else v_old.purchase_unit end;
  v_active := coalesce((p_mapping ->> 'active')::boolean, v_old.active, true);

  if v_supplier is null or not exists (select 1 from public.suppliers s where s.id = v_supplier and s.workspace_id = p_workspace_id) then
    perform public.stock_config_refuse('supplier_id', 'supplier_foreign');
  end if;
  if v_item is null or not exists (select 1 from public.services s where s.id = v_item and s.workspace_id = p_workspace_id) then
    perform public.stock_config_refuse('item_id', 'item_foreign');
  end if;
  if v_variant is not null and not exists (select 1 from public.item_variants x
       where x.id = v_variant and x.item_id = v_item and x.workspace_id = p_workspace_id) then
    perform public.stock_config_refuse('variant_id', 'variant_unknown');
  end if;
  if char_length(v_ref) not between 1 and 80 then perform public.stock_config_refuse('article_ref', 'code_malformed'); end if;
  if v_unit is not null and not exists (select 1 from public.item_units u where u.item_id = v_item and u.unit = v_unit) then
    perform public.stock_config_refuse('purchase_unit', 'unit_not_of_item');
  end if;
  if exists (select 1 from public.supplier_item_mappings m where m.supplier_id = v_supplier and m.article_ref = v_ref
              and m.id is distinct from p_mapping_id) then
    perform public.stock_config_refuse('article_ref', 'mapping_duplicate');
  end if;

  if p_mapping_id is null then
    insert into public.supplier_item_mappings (workspace_id, supplier_id, item_id, variant_id, article_ref, purchase_unit, active)
    values (p_workspace_id, v_supplier, v_item, v_variant, v_ref, v_unit, v_active)
    returning id, revision into v_id, v_rev;
  else
    update public.supplier_item_mappings
       set supplier_id = v_supplier, item_id = v_item, variant_id = v_variant, article_ref = v_ref,
           purchase_unit = v_unit, active = v_active, revision = revision + 1
     where id = p_mapping_id returning id, revision into v_id, v_rev;
  end if;
  v_result := jsonb_build_object('mapping_id', v_id, 'revision', v_rev, 'replayed', false);
  insert into public.purchase_requests (workspace_id, request_id, operation, digest, result)
  values (p_workspace_id, p_request_id, 'supplier_item_mapping_save', v_digest, v_result);
  return v_result;
end;
$fn$;
revoke execute on function public.save_supplier_item_mapping_v1(uuid, uuid, int, uuid, jsonb) from public, anon;
grant execute on function public.save_supplier_item_mapping_v1(uuid, uuid, int, uuid, jsonb) to authenticated;

-- ── the paged reads show the variant (0833's, restated whole) ───────────
create or replace function public.stock_on_hand_page_v1(
  p_workspace_id uuid, p_item_id uuid default null, p_location_id uuid default null,
  p_limit int default 50, p_after jsonb default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_zero constant uuid := '00000000-0000-0000-0000-000000000000';
  v_item uuid; v_loc uuid; v_lot uuid; v_var uuid;
  v_rows jsonb; v_n int; v_last jsonb;
begin
  perform public.stock_page_reader(p_workspace_id, p_limit);
  if p_after is not null then
    begin
      if p_after->>'version' is distinct from '1' then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
      v_item := (p_after->>'item_id')::uuid;
      v_loc := (p_after->>'location_id')::uuid;
      v_var := coalesce((p_after->>'variant_id')::uuid, v_zero);
      v_lot := coalesce((p_after->>'lot_id')::uuid, v_zero);
      if v_item is null or v_loc is null then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
    exception when others then
      raise exception 'invalid cursor' using errcode = 'DKG09';
    end;
  end if;
  with page as (
    select b.item_id, b.location_id, b.variant_id, b.lot_id, b.quantity, s.name as item_name,
           s.inventory_unit as unit, l.code as location_code, l.name as location_name,
           t.lot_code
      from public.stock_balances b
      join public.services s on s.id = b.item_id
      join public.stock_locations l on l.id = b.location_id
      join public.stock_location_kinds k on k.key = l.kind
      left join public.stock_lots t on t.id = b.lot_id
     where b.workspace_id = p_workspace_id and not k.virtual and b.quantity <> 0
       and (p_item_id is null or b.item_id = p_item_id)
       and (p_location_id is null or b.location_id = p_location_id)
       and (p_after is null
            or (b.item_id, b.location_id, coalesce(b.variant_id, v_zero), coalesce(b.lot_id, v_zero)) > (v_item, v_loc, v_var, v_lot))
     order by b.item_id, b.location_id, coalesce(b.variant_id, v_zero), coalesce(b.lot_id, v_zero)
     limit p_limit + 1)
  select count(*), coalesce(jsonb_agg(jsonb_build_object(
           'workspace_id', p_workspace_id, 'item_id', item_id, 'item_name', item_name,
           'variant_id', variant_id, 'variant_label', public.stock_variant_label(variant_id),
           'lot_id', lot_id, 'lot_code', lot_code, 'location_id', location_id,
           'location_code', location_code, 'location_name', location_name,
           'quantity', quantity::text, 'unit', unit)
           order by item_id, location_id, coalesce(variant_id, v_zero), coalesce(lot_id, v_zero)), '[]'::jsonb)
    into v_n, v_rows from page;
  if v_n > p_limit then
    v_rows := v_rows - p_limit;                     -- drop the look-ahead row
    v_last := v_rows -> (p_limit - 1);
    return jsonb_build_object('rows', v_rows, 'complete', false, 'next', jsonb_build_object(
      'version', 1, 'item_id', v_last -> 'item_id', 'location_id', v_last -> 'location_id',
      'variant_id', v_last -> 'variant_id', 'lot_id', v_last -> 'lot_id'));
  end if;
  return jsonb_build_object('rows', v_rows, 'complete', true, 'next', null);
end;
$fn$;
revoke execute on function public.stock_on_hand_page_v1(uuid, uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.stock_on_hand_page_v1(uuid, uuid, uuid, int, jsonb) to authenticated;

create or replace function public.stock_movements_page_v1(
  p_workspace_id uuid, p_item_id uuid default null, p_location_id uuid default null,
  p_limit int default 50, p_after jsonb default null, p_movement_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_at timestamptz; v_id uuid;
  v_rows jsonb; v_n int; v_last jsonb; v_cost boolean;
begin
  perform public.stock_page_reader(p_workspace_id, p_limit);
  v_cost := public.stock_sees_cost(p_workspace_id);
  if p_after is not null then
    begin
      if p_after->>'version' is distinct from '1' then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
      v_at := (p_after->>'occurred_at')::timestamptz;
      v_id := (p_after->>'id')::uuid;
      if v_at is null or v_id is null then raise exception 'invalid cursor' using errcode = 'DKG09'; end if;
    exception when others then
      raise exception 'invalid cursor' using errcode = 'DKG09';
    end;
  end if;
  with page as (
    select m.id, m.item_id, m.variant_id, s.name as item_name, s.inventory_unit as unit, m.lot_id, t.lot_code,
           m.from_location_id, lf.code as from_code, m.to_location_id, lt.code as to_code,
           m.quantity, m.entered_quantity, m.entered_unit, m.occurred_at, m.reason, m.unit_cost,
           m.actor_member_id, m.receipt_line_id, m.purchase_line_id, m.event_id, m.invoice_id
      from public.stock_movements m
      join public.services s on s.id = m.item_id
      join public.stock_locations lf on lf.id = m.from_location_id
      join public.stock_locations lt on lt.id = m.to_location_id
      left join public.stock_lots t on t.id = m.lot_id
     where m.workspace_id = p_workspace_id
       and (p_movement_id is null or m.id = p_movement_id)
       and (p_item_id is null or m.item_id = p_item_id)
       and (p_location_id is null or p_location_id in (m.from_location_id, m.to_location_id))
       and (p_after is null or (m.occurred_at, m.id) < (v_at, v_id))
     order by m.occurred_at desc, m.id desc
     limit p_limit + 1)
  select count(*), coalesce(jsonb_agg(jsonb_build_object(
           'workspace_id', p_workspace_id, 'id', id, 'item_id', item_id, 'item_name', item_name,
           'variant_id', variant_id, 'variant_label', public.stock_variant_label(variant_id),
           'lot_id', lot_id, 'lot_code', lot_code,
           'from_location_id', from_location_id, 'from_location_code', from_code,
           'to_location_id', to_location_id, 'to_location_code', to_code,
           'quantity', quantity::text, 'unit', unit,
           'entered_quantity', entered_quantity::text, 'entered_unit', entered_unit,
           'occurred_at', occurred_at, 'reason', reason,
           'unit_cost', case when v_cost then unit_cost::text end, 'actor_member_id', actor_member_id,
           'receipt_line_id', case when v_cost then receipt_line_id end,
           'purchase_line_id', case when v_cost then purchase_line_id end,
           'event_id', event_id, 'invoice_id', invoice_id)
           order by occurred_at desc, id desc), '[]'::jsonb)
    into v_n, v_rows from page;
  if v_n > p_limit then
    v_rows := v_rows - p_limit;
    v_last := v_rows -> (p_limit - 1);
    return jsonb_build_object('rows', v_rows, 'complete', false, 'next', jsonb_build_object(
      'version', 1, 'occurred_at', v_last -> 'occurred_at', 'id', v_last -> 'id'));
  end if;
  return jsonb_build_object('rows', v_rows, 'complete', true, 'next', null);
end;
$fn$;
revoke execute on function public.stock_movements_page_v1(uuid, uuid, uuid, int, jsonb, uuid) from public, anon;
grant execute on function public.stock_movements_page_v1(uuid, uuid, uuid, int, jsonb, uuid) to authenticated;



-- ── an item with active variants is never taken or counted without one ──
-- 0747's sale confirmation and shelf-count edit act on the item as a whole;
-- with variants that would count every variant but take the plain stock.
do $patch2$
declare
  v_def text;
  v_next text;
  v_step record;
begin
  v_def := pg_get_functiondef('public.apply_stock_on_confirm()'::regprocedure);
  for v_step in select * from (values
    ('the sale takes only plain stock',
     $o$where b.item_id = v_service_id and b.location_id = v_main and b.quantity > 0;$o$,
     $n$where b.item_id = v_service_id and b.location_id = v_main and b.quantity > 0
         and b.variant_id is null;$n$),
    ('a sale of an item with variants must name its variant',
     $o$      v_main := public.stock_place(new.workspace_id, 'warehouse');$o$,
     $n$      if exists (select 1 from public.item_variants x where x.item_id = v_service_id and x.active) then
        raise exception 'this item has variants: the sale must name its variant' using errcode = 'DKG12';
      end if;
      v_main := public.stock_place(new.workspace_id, 'warehouse');$n$)
  ) as t(what, old_text, new_text) loop
    v_next := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_next is null then
      raise exception '0837: the anchor of apply_stock_on_confirm (%) was not found', v_step.what using errcode = 'P0001';
    end if;
    v_def := v_next;
  end loop;
  execute v_def;

  v_def := pg_get_functiondef('public.services_stock_ledger_before()'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$  v_actor := public.stock_count_actor(new.workspace_id);$o$,
    $n$  if exists (select 1 from public.item_variants x where x.item_id = new.id and x.active) then
    raise exception 'this item has variants: its count is kept per variant' using errcode = 'DKG12';
  end if;
  v_actor := public.stock_count_actor(new.workspace_id);$n$);
  if v_next is null then
    raise exception '0837: the anchor of services_stock_ledger_before was not found' using errcode = 'P0001';
  end if;
  execute v_next;

  v_def := pg_get_functiondef('public.stock_on_hand_v1(uuid, uuid, uuid)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$'location_id', b.location_id, 'quantity', b.quantity, 'unit', s.inventory_unit)$o$,
    $n$'location_id', b.location_id, 'quantity', b.quantity, 'unit', s.inventory_unit,
             'variant_id', b.variant_id, 'variant_label', public.stock_variant_label(b.variant_id))$n$);
  if v_next is null then
    raise exception '0837: the anchor of stock_on_hand_v1 was not found' using errcode = 'P0001';
  end if;
  execute v_next;
end
$patch2$;

-- ── the workspace export carries the new tables (#2860): 0828's function restated whole ──
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
    'supplier_item_mappings'];
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

select public.set_deskilo_schema_version(837);
