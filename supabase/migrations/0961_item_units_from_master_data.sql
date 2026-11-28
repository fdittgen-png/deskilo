-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
--
-- #4471 B -- an item's own units (a carton of 12) and a group's purchase unit are PICKED from the business's units of measure, never
-- typed: the unit 'carton' is the business's, the factor 12 is the item's. So the business's units hold every name already in use:
--   * for every distinct unit name of an item (`item_units`), of a group (`default_purchase_unit`) or of a supplier mapping
--     (`purchase_unit`) that is no unit of its business, a unit is made (count, factor 1, labelled with the name as typed; the code
--     is the name when it is already one, else made from it, per business, never twice), and what held the name holds the code.
--     Done once and idempotent: a second run finds every name a unit and makes none. Movements keep what they froze.
--   * `save_stock_item_v1` (restates 0836, patched by 0952 at an asserted anchor): a packaging unit is a unit of the business; the
--     item's own inventory unit is the one it may not take (still `registry_unit`); anything else is `unit_unknown`.
--   * `item_group_check_value` (0883, 0952): a group's `default_purchase_unit` is a unit of the business.
--   * `unit_is_pickable` (0960): the item's own units are units of the business now; the answer is the business's units alone.
--   * #4499 (amended, with the owner's approval): a barcode (`item_codes.unit`) and a supplier's article
--     (`supplier_item_mappings.purchase_unit`) name an item's unit through a foreign key that refused the rename, so an
--     installation holding one on a typed name stopped here. The two keys now follow the rename (ON UPDATE CASCADE), and
--     a tag bound to the unit (`stock_tags.unit_code`, no key) moves with it. 0991 gives the keys the same rule on an
--     installation that applied this file before the amendment. Proven by scripts/upgrade_equivalence_check.sh (its
--     archive_seed_0960.sql stage).

-- ── 1. the names in use become units of the business ────────────────────
-- #4499: what names an item's unit follows its rename
alter table public.item_codes drop constraint item_codes_item_id_unit_fkey;
alter table public.item_codes add constraint item_codes_item_id_unit_fkey
  foreign key (item_id, unit) references public.item_units (item_id, unit) on update cascade on delete cascade;
alter table public.supplier_item_mappings drop constraint supplier_item_mappings_item_id_purchase_unit_fkey;
alter table public.supplier_item_mappings add constraint supplier_item_mappings_item_id_purchase_unit_fkey
  foreign key (item_id, purchase_unit) references public.item_units (item_id, unit) on update cascade;

do $backfill$
declare
  r record;
  v_base text;
  v_code text;
  n integer;
  v_made integer := 0;
  v_moved integer := 0;
begin
  create temp table backfill_names (workspace_id uuid not null, name text not null, code text) on commit drop;
  insert into backfill_names (workspace_id, name)
  select distinct workspace_id, name from (
    select workspace_id, btrim(unit) as name from public.item_units
    union all select workspace_id, btrim(default_purchase_unit) from public.item_groups
      where default_purchase_unit is not null and workspace_id is not null
    union all select workspace_id, btrim(purchase_unit) from public.supplier_item_mappings where purchase_unit is not null
  ) x where name <> '';
  -- a name that already is a unit of its business needs nothing
  delete from backfill_names b
   where exists (select 1 from public.workspace_units u where u.workspace_id = b.workspace_id and u.code = b.name);
  -- a name that already is a code takes it first, so 'case' is 'case' and 'Case' is 'case_2'
  for r in select * from backfill_names order by workspace_id, (name !~ '^[a-z][a-z0-9_]{0,19}$'), name loop
    v_base := regexp_replace(lower(r.name), '[^a-z0-9]+', '_', 'g');
    v_base := regexp_replace(v_base, '^_+|_+$', '', 'g');
    if v_base = '' then v_base := 'unit'; end if;
    if v_base !~ '^[a-z]' then v_base := 'u_' || v_base; end if;
    v_base := left(v_base, 20);
    v_code := v_base;
    n := 1;
    while exists (select 1 from public.workspace_units u where u.workspace_id = r.workspace_id and u.code = v_code) loop
      n := n + 1;
      v_code := left(v_base, 20 - length(n::text) - 1) || '_' || n;
    end loop;
    insert into public.workspace_units (workspace_id, code, label, dimension, factor_num, factor_den)
    values (r.workspace_id, v_code, left(r.name, 40), 'count', 1, 1);
    update backfill_names b set code = v_code where b.workspace_id = r.workspace_id and b.name = r.name;
    v_made := v_made + 1;
  end loop;
  -- what held the name holds the code (an item that would then hold one unit twice keeps the name: it is flagged where it is edited)
  update public.item_units i set unit = b.code from backfill_names b
   where i.workspace_id = b.workspace_id and btrim(i.unit) = b.name and i.unit is distinct from b.code
     and not exists (select 1 from public.item_units j where j.item_id = i.item_id and j.unit = b.code and j.id <> i.id);
  get diagnostics v_moved = row_count;
  -- #4499: a tag bound to an item's unit names it by the same name: it follows the item's unit
  update public.stock_tags t set unit_code = b.code from backfill_names b
   where t.owner_kind = 'unit' and t.workspace_id = b.workspace_id and btrim(t.unit_code) = b.name
     and exists (select 1 from public.item_units i where i.item_id = t.item_id and i.unit = b.code)
     and not exists (select 1 from public.item_units i where i.item_id = t.item_id and i.unit = t.unit_code);
  update public.item_groups g set default_purchase_unit = b.code from backfill_names b
   where g.workspace_id = b.workspace_id and btrim(g.default_purchase_unit) = b.name and g.default_purchase_unit is distinct from b.code;
  update public.supplier_item_mappings m set purchase_unit = b.code from backfill_names b
   where m.workspace_id = b.workspace_id and btrim(m.purchase_unit) = b.name and m.purchase_unit is distinct from b.code;
  raise notice '0961: % units made from names in use, % item units now hold a code', v_made, v_moved;
end
$backfill$;

-- ── 2. a packaging unit is a unit of the business ───────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.save_stock_item_v1(uuid, uuid, integer, uuid, jsonb)'::regprocedure);
  v_old text := $o$if v_unit = v_inventory or exists (select 1 from public.workspace_units where workspace_id = p_workspace_id and code = v_unit) then$o$;
  v_new text := $n$if not exists (select 1 from public.workspace_units where workspace_id = p_workspace_id and code = v_unit) then
      perform public.stock_config_refuse(format('units[%s].unit', i - 1), 'unit_unknown');
    end if;
    if v_unit = v_inventory then$n$;
begin
  if position(v_old in v_def) > 0 then
    execute replace(v_def, v_old, v_new);
  elsif position('if v_unit = v_inventory then' in v_def) = 0 then
    raise exception '0961: the packaging unit anchor of save_stock_item_v1 is missing' using errcode = 'P0001';
  end if;
end
$patch$;

-- ── 3. a group's purchase unit is a unit of the business ────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.item_group_check_value(uuid, text, jsonb)'::regprocedure);
  v_old text := $o$elsif p_param = 'vat_rate_id' and not exists ($o$;
  v_new text := $n$elsif p_param = 'default_purchase_unit' and not exists (
      select 1 from public.workspace_units u where u.workspace_id = p_workspace_id and u.code = p_value #>> '{}') then
    perform public.stock_config_refuse(p_param, 'unit_unknown');
  elsif p_param = 'vat_rate_id' and not exists ($n$;
begin
  if position('''default_purchase_unit'' and not exists' in v_def) = 0 then
    if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
      raise exception '0961: the vat anchor of item_group_check_value is not found exactly once' using errcode = 'P0001';
    end if;
    execute replace(v_def, v_old, v_new);
  end if;
end
$patch$;

-- ── 4. the answer of 0960 narrows to the business's units ───────────────
-- restates 0960
create or replace function public.unit_is_pickable(p_workspace uuid, p_unit text, p_item uuid default null)
returns boolean language sql stable security definer set search_path = public as $fn$
  select btrim(coalesce(p_unit, '')) = ''
      or exists (select 1 from public.workspace_units u where u.workspace_id = p_workspace and u.code = btrim(p_unit));
$fn$;
revoke execute on function public.unit_is_pickable(uuid, text, uuid) from public, anon, authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(961);
