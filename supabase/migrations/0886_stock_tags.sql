-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (two tables, one setting, functions, and item_override_save_v1 patched at an asserted anchor)
--
-- #4362 (G13, third of four files) -- RFID tags, and the one resolver of what a scan reads.
--
--   * A tag is an EPC (UHF, hex, 24 to 128 digits) or a chip UID (HF, 8 to 20 digits), stored in
--     uppercase hex and unique per business among the tags in force, whatever it names: a place, an
--     item, a variant, a lot, a package unit, or one piece. An SGTIN-96 EPC is decoded to the GTIN-14
--     and the serial it carries (GS1 EPC Tag Data Standard, partitions 0 to 6).
--   * An item's tag mode (G12) says what a tag on it names: `per_batch` binds to the item, a variant, a
--     lot or a package unit; `per_unit` names one piece, which exists from the moment its tag is
--     bound at a reception (`stock_tagged_units`, with its place and its state). Binding the first tag
--     of an item pins its tag mode on the item, so a later change of its group does not reach it; the
--     mode of an item with tags in force is not changed until they are retired.
--   * Binding and retiring are commands with a request id and need `manageStock`; a tag in force
--     elsewhere is refused with its owner named; a retired tag is kept, and may be bound again only
--     after the grace period of the setting `stock.tag_rebind_grace_days`.
--   * `stock_resolve_code_v1` is the one resolver of a scan: a place (its barcode or its code), an item
--     (GTIN with its check digit, an own code or a package-unit code), a variant, a lot label or a tag;
--     it never raises for an unknown code, is scoped to the business, and tells an assistant session
--     names only.

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('stock.tag_rebind_grace_days', 'int', '30'::jsonb, 0, 365, 'days', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'stock tags (#4362)', 'How many days after it was retired a tag code may be bound again. 0 means at once. A tag in force is never bound twice; this only protects a code read from a tag that was taken off lately.'),
('stock.repeated_scan', 'enum', '"add_one"'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, '["add_one","ask_quantity"]'::jsonb, 'scanning (#4359)', 'What a goods sheet does when the same code is scanned again: add one more to the line, or ask the quantity.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the pieces and the tags ────────────────────────────────────────────
create table public.stock_tagged_units (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  item_id uuid not null,
  variant_id uuid references public.item_variants (id),
  lot_id uuid,
  location_id uuid not null,
  state text not null default 'in_stock' check (state in ('in_stock', 'sold', 'returned', 'written_off', 'retired')),
  unique (workspace_id, id),
  foreign key (workspace_id, item_id) references public.services (workspace_id, id) on delete cascade,
  foreign key (workspace_id, lot_id) references public.stock_lots (workspace_id, id) on delete cascade,
  foreign key (workspace_id, location_id) references public.stock_locations (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('stock_tagged_units');
create index stock_tagged_units_place on public.stock_tagged_units (workspace_id, item_id, location_id) where state = 'in_stock';

create table public.stock_tags (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  code text not null check (code ~ '^[0-9A-F]{8,128}$'),
  tag_kind text not null check (tag_kind in ('epc', 'uid')),
  owner_kind text not null check (owner_kind in ('item', 'variant', 'lot', 'unit', 'place', 'piece')),
  item_id uuid,
  variant_id uuid,
  lot_id uuid,
  unit_code text,
  location_id uuid,
  piece_id uuid,
  state text not null default 'active' check (state in ('active', 'retired')),
  retired_at timestamptz,
  retired_reason text check (char_length(retired_reason) <= 200),
  bound_by_member_id uuid,
  retired_by_member_id uuid,
  check ((state = 'retired') = (retired_at is not null)),
  check (case owner_kind
    when 'item' then item_id is not null and variant_id is null and lot_id is null and unit_code is null and location_id is null and piece_id is null
    when 'variant' then item_id is not null and variant_id is not null and lot_id is null and unit_code is null and location_id is null and piece_id is null
    when 'lot' then item_id is not null and lot_id is not null and variant_id is null and unit_code is null and location_id is null and piece_id is null
    when 'unit' then item_id is not null and unit_code is not null and variant_id is null and lot_id is null and location_id is null and piece_id is null
    when 'place' then location_id is not null and item_id is null and variant_id is null and lot_id is null and unit_code is null and piece_id is null
    else piece_id is not null and item_id is not null and variant_id is null and lot_id is null and unit_code is null and location_id is null end),
  foreign key (workspace_id, item_id) references public.services (workspace_id, id) on delete cascade,
  foreign key (workspace_id, lot_id) references public.stock_lots (workspace_id, id) on delete cascade,
  foreign key (workspace_id, location_id) references public.stock_locations (workspace_id, id) on delete cascade,
  foreign key (workspace_id, piece_id) references public.stock_tagged_units (workspace_id, id) on delete cascade,
  foreign key (workspace_id, bound_by_member_id) references public.members (workspace_id, id),
  foreign key (workspace_id, retired_by_member_id) references public.members (workspace_id, id)
);
select public.ensure_system_columns('stock_tags');
create unique index stock_tags_in_force on public.stock_tags (workspace_id, code) where state = 'active';
create index stock_tags_code on public.stock_tags (workspace_id, code);
create index stock_tags_owner_item on public.stock_tags (workspace_id, item_id) where item_id is not null and state = 'active';

alter table public.stock_tagged_units enable row level security;
alter table public.stock_tags enable row level security;
revoke all on public.stock_tagged_units, public.stock_tags from public, anon, authenticated;
grant select on public.stock_tagged_units, public.stock_tags to authenticated;
create policy stock_tagged_units_select on public.stock_tagged_units for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockTags'));
create policy stock_tags_select on public.stock_tags for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
         and public.feature_effective(workspace_id, 'stockTags'));
create policy mcp_delegated_deny on public.stock_tagged_units as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.stock_tags as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── a code, normalised and read ────────────────────────────────────────
-- Uppercase hex without separators, or null when it is no tag code: 8 to 20 digits (a chip UID) or 24 to 128 (an EPC).
create or replace function public.stock_tag_normalize(p_code text)
returns text language sql immutable set search_path = public as $fn$
  select case when c ~ '^[0-9A-F]{8,20}$' or c ~ '^[0-9A-F]{24,128}$' then c end
    from (select upper(regexp_replace(coalesce(p_code, ''), '[\s:-]', '', 'g')) c) x;
$fn$;
revoke execute on function public.stock_tag_normalize(text) from public, anon, authenticated;

create or replace function public.stock_tag_kind(p_code text)
returns text language sql immutable set search_path = public as $fn$
  select case when length(p_code) >= 24 then 'epc' else 'uid' end;
$fn$;
revoke execute on function public.stock_tag_kind(text) from public, anon, authenticated;

-- The unsigned value of a bit string of at most 64 bits.
create or replace function public.stock_bits_value(p_bits bit varying)
returns numeric language plpgsql immutable set search_path = public as $fn$
declare
  v numeric := 0;
  i int;
begin
  for i in 1 .. length(p_bits) loop
    v := v * 2 + case when substring(p_bits from i for 1) = B'1' then 1 else 0 end;
  end loop;
  return v;
end;
$fn$;
revoke execute on function public.stock_bits_value(bit varying) from public, anon, authenticated;

-- The check digit of a GTIN body (13 digits for a GTIN-14), by the GS1 rule.
create or replace function public.stock_gtin_check_digit(p_body text)
returns int language plpgsql immutable set search_path = public as $fn$
declare
  v_sum int := 0;
  i int;
  n int := length(p_body);
begin
  for i in 1 .. n loop
    v_sum := v_sum + substring(p_body from i for 1)::int * case when (n - i) % 2 = 0 then 3 else 1 end;
  end loop;
  return (10 - v_sum % 10) % 10;
end;
$fn$;
revoke execute on function public.stock_gtin_check_digit(text) from public, anon, authenticated;

-- SGTIN-96 (header 0x30): {filter, partition, gtin14, serial}, or null when the code is not one.
create or replace function public.stock_sgtin96_decode(p_code text)
returns jsonb language plpgsql immutable set search_path = public as $fn$
declare
  b bit(96);
  v_part int;
  v_cpbits int; v_cpdig int; v_irbits int; v_irdig int;
  v_cp text; v_ir text; v_body text;
begin
  if p_code is null or p_code !~ '^30[0-9A-F]{22}$' then
    return null;
  end if;
  b := ('x' || p_code)::bit(96);
  v_part := public.stock_bits_value(substring(b from 12 for 3))::int;
  select t.cb, t.cd, t.ib, t.idg into v_cpbits, v_cpdig, v_irbits, v_irdig
    from (values (0, 40, 12, 4, 1), (1, 37, 11, 7, 2), (2, 34, 10, 10, 3), (3, 30, 9, 14, 4),
                 (4, 27, 8, 17, 5), (5, 24, 7, 20, 6), (6, 20, 6, 24, 7)) t (p, cb, cd, ib, idg)
   where t.p = v_part;
  if v_cpbits is null then
    return null;
  end if;
  v_cp := lpad(public.stock_bits_value(substring(b from 15 for v_cpbits))::text, v_cpdig, '0');
  v_ir := lpad(public.stock_bits_value(substring(b from 15 + v_cpbits for v_irbits))::text, v_irdig, '0');
  -- the item reference starts with the indicator digit; the rest follows the company prefix
  v_body := substring(v_ir from 1 for 1) || v_cp || substring(v_ir from 2);
  if length(v_body) <> 13 then
    return null;
  end if;
  return jsonb_build_object('filter', public.stock_bits_value(substring(b from 9 for 3))::int, 'partition', v_part,
    'gtin14', v_body || public.stock_gtin_check_digit(v_body)::text,
    'serial', public.stock_bits_value(substring(b from 59 for 38))::text);
end;
$fn$;
revoke execute on function public.stock_sgtin96_decode(text) from public, anon, authenticated;

-- ── who may ────────────────────────────────────────────────────────────
create or replace function public.stock_tag_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null then
    raise exception 'not allowed to bind or retire tags' using errcode = 'DKN01';
  end if;
  v_me := public.stock_config_actor(p_workspace_id);
  if not public.feature_effective(p_workspace_id, 'stockTags') then
    raise exception 'tags are off in this business' using errcode = 'DKG01';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.stock_tag_actor(uuid) from public, anon, authenticated;

-- What a tag names, in words: "place MAIN-B2", "item Mugs", "lot L7 of Mugs", "piece 3 of Gift basket".
create or replace function public.stock_tag_owner_text(t public.stock_tags)
returns text language sql stable security definer set search_path = public as $fn$
  select case t.owner_kind
    when 'place' then 'place ' || (select l.code from public.stock_locations l where l.id = t.location_id)
    when 'item' then 'item ' || (select s.name from public.services s where s.id = t.item_id)
    when 'variant' then 'variant of ' || (select s.name from public.services s where s.id = t.item_id)
    when 'lot' then 'lot ' || coalesce((select nullif(x.lot_code, '') from public.stock_lots x where x.id = t.lot_id), '') || ' of '
                    || (select s.name from public.services s where s.id = t.item_id)
    when 'unit' then 'unit ' || t.unit_code || ' of ' || (select s.name from public.services s where s.id = t.item_id)
    else 'a piece of ' || (select s.name from public.services s where s.id = t.item_id) end;
$fn$;
revoke execute on function public.stock_tag_owner_text(public.stock_tags) from public, anon, authenticated;

-- ── a tag is bound ─────────────────────────────────────────────────────
-- p_tag: {"code": "E280...", "owner": {"kind": "item" | "variant" | "lot" | "unit" | "place", "item_id": ..,
-- "variant_id": .., "lot_id": .., "unit": .., "location_id": ..}}. A piece is bound by the movement that
-- brings it in (the movement path), never alone.
create or replace function public.stock_tag_bind_v1(p_workspace_id uuid, p_request_id uuid, p_tag jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_code text;
  o jsonb;
  v_kind text;
  v_item uuid;
  v_var uuid;
  v_lot uuid;
  v_unit text;
  v_loc uuid;
  v_digest text;
  v_done jsonb;
  v_have public.stock_tags;
  v_grace int := coalesce((public.setting_value(p_workspace_id, 'stock.tag_rebind_grace_days') #>> '{}')::int, 30);
  v_mode text;
  v_row public.stock_tags;
  v_result jsonb;
begin
  v_me := public.stock_tag_actor(p_workspace_id);
  if p_request_id is null or coalesce(jsonb_typeof(p_tag), '') <> 'object' or coalesce(jsonb_typeof(p_tag -> 'owner'), '') <> 'object' then
    perform public.stock_config_refuse('tag', 'malformed');
  end if;
  v_code := public.stock_tag_normalize(p_tag ->> 'code');
  if v_code is null then
    perform public.stock_config_refuse('code', 'tag_malformed');
  end if;
  o := p_tag -> 'owner';
  v_kind := o ->> 'kind';
  if v_kind is null or v_kind not in ('item', 'variant', 'lot', 'unit', 'place') then
    perform public.stock_config_refuse('owner', 'tag_owner_unknown');
  end if;
  begin
    v_item := nullif(o ->> 'item_id', '')::uuid;
    v_var := nullif(o ->> 'variant_id', '')::uuid;
    v_lot := nullif(o ->> 'lot_id', '')::uuid;
    v_loc := nullif(o ->> 'location_id', '')::uuid;
  exception when others then
    perform public.stock_config_refuse('owner', 'malformed');
  end;
  v_unit := nullif(btrim(coalesce(o ->> 'unit', '')), '');
  v_digest := md5(jsonb_build_array(v_code, v_kind, v_item, v_var, v_lot, v_unit, v_loc)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_tag_bind', v_digest);
  if v_done is not null then return v_done; end if;
  -- the owner is of this business
  if v_kind = 'place' then
    if v_loc is null or not exists (select 1 from public.stock_locations l where l.id = v_loc and l.workspace_id = p_workspace_id)
       or public.stock_place_is_virtual(v_loc) then
      perform public.stock_config_refuse('owner', 'tag_owner_unknown');
    end if;
  else
    if v_item is null or not exists (select 1 from public.services s where s.id = v_item and s.workspace_id = p_workspace_id and s.stockable) then
      perform public.stock_config_refuse('owner', 'tag_owner_unknown');
    end if;
    if (v_kind = 'variant' and not exists (select 1 from public.item_variants x where x.id = v_var and x.item_id = v_item))
       or (v_kind = 'lot' and not exists (select 1 from public.stock_lots x where x.id = v_lot and x.item_id = v_item and x.workspace_id = p_workspace_id))
       or (v_kind = 'unit' and not exists (select 1 from public.item_units x where x.item_id = v_item and x.unit = v_unit)) then
      perform public.stock_config_refuse('owner', 'tag_owner_unknown');
    end if;
  end if;
  -- one tag, one owner, in the whole business
  perform pg_advisory_xact_lock(hashtextextended('stock_tag:' || p_workspace_id::text || ':' || v_code, 0));
  select * into v_have from public.stock_tags where workspace_id = p_workspace_id and code = v_code and state = 'active';
  if v_have.id is not null then
    if v_have.owner_kind = v_kind and v_have.item_id is not distinct from v_item and v_have.variant_id is not distinct from
       (case when v_kind = 'variant' then v_var end) and v_have.lot_id is not distinct from (case when v_kind = 'lot' then v_lot end)
       and v_have.unit_code is not distinct from (case when v_kind = 'unit' then v_unit end)
       and v_have.location_id is not distinct from (case when v_kind = 'place' then v_loc end) then
      v_result := jsonb_build_object('tag_id', v_have.id, 'code', v_code, 'tag_kind', v_have.tag_kind, 'owner_kind', v_kind, 'replayed', true);
      return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_tag_bind', v_digest, v_result);
    end if;
    raise exception 'tag % is already on %', v_code, public.stock_tag_owner_text(v_have) using errcode = 'DKG22',
      detail = jsonb_build_object('code', v_code, 'owner', public.stock_tag_owner_text(v_have))::text;
  end if;
  if exists (select 1 from public.stock_tags t where t.workspace_id = p_workspace_id and t.code = v_code and t.state = 'retired'
              and t.retired_at > now() - make_interval(days => v_grace)) then
    raise exception 'tag % was retired lately and may be bound again after % days', v_code, v_grace using errcode = 'DKG23',
      detail = jsonb_build_object('code', v_code, 'days', v_grace)::text;
  end if;
  -- what a tag on an item names is the item's tag mode: batches here, pieces by the movement path
  if v_kind <> 'place' then
    v_mode := public.item_effective_core(v_item) #>> '{parameters,tag_mode,value}';
    if v_mode = 'per_unit' then
      perform public.stock_config_refuse('owner', 'tag_per_unit_item');
    elsif v_mode is distinct from 'per_batch' then
      perform public.stock_config_refuse('owner', 'tag_mode_none');
    end if;
    update public.services set tag_mode = 'per_batch', stock_revision = stock_revision + 1
     where id = v_item and tag_mode is distinct from 'per_batch';
  end if;
  insert into public.stock_tags (workspace_id, code, tag_kind, owner_kind, item_id, variant_id, lot_id, unit_code, location_id, bound_by_member_id)
  values (p_workspace_id, v_code, public.stock_tag_kind(v_code), v_kind, case when v_kind <> 'place' then v_item end,
          case when v_kind = 'variant' then v_var end, case when v_kind = 'lot' then v_lot end,
          case when v_kind = 'unit' then v_unit end, case when v_kind = 'place' then v_loc end, v_me)
  returning * into v_row;
  v_result := jsonb_build_object('tag_id', v_row.id, 'code', v_code, 'tag_kind', v_row.tag_kind, 'owner_kind', v_kind, 'replayed', false);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_tag_bind', v_digest, v_result);
end;
$fn$;
revoke execute on function public.stock_tag_bind_v1(uuid, uuid, jsonb) from public, anon;
grant execute on function public.stock_tag_bind_v1(uuid, uuid, jsonb) to authenticated;

-- ── a tag is retired ───────────────────────────────────────────────────
-- The tag stays as history. A piece is retired with its tag, and only when it is not in stock.
create or replace function public.stock_tag_retire_v1(p_workspace_id uuid, p_request_id uuid, p_code text, p_reason text default '')
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_code text := public.stock_tag_normalize(p_code);
  v_digest text;
  v_done jsonb;
  t public.stock_tags;
  v_result jsonb;
begin
  v_me := public.stock_tag_actor(p_workspace_id);
  if p_request_id is null or v_code is null or char_length(coalesce(p_reason, '')) > 200 then
    perform public.stock_config_refuse('code', 'tag_malformed');
  end if;
  v_digest := md5(jsonb_build_array(v_code, coalesce(p_reason, ''))::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_tag_retire', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtextextended('stock_tag:' || p_workspace_id::text || ':' || v_code, 0));
  select * into t from public.stock_tags where workspace_id = p_workspace_id and code = v_code and state = 'active' for update;
  if t.id is null then
    raise exception 'not a tag in force in this business' using errcode = 'DKG04';
  end if;
  if t.owner_kind = 'piece' then
    if exists (select 1 from public.stock_tagged_units u where u.id = t.piece_id and u.state = 'in_stock') then
      raise exception 'this piece is in stock: move it out or write it off first' using errcode = 'DKG24';
    end if;
    update public.stock_tagged_units set state = 'retired' where id = t.piece_id;
  end if;
  update public.stock_tags set state = 'retired', retired_at = now(), retired_reason = coalesce(p_reason, ''), retired_by_member_id = v_me
   where id = t.id;
  v_result := jsonb_build_object('tag_id', t.id, 'code', v_code, 'retired', true);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_tag_retire', v_digest, v_result);
end;
$fn$;
revoke execute on function public.stock_tag_retire_v1(uuid, uuid, text, text) from public, anon;
grant execute on function public.stock_tag_retire_v1(uuid, uuid, text, text) to authenticated;

-- ── the tags of one owner ──────────────────────────────────────────────
create or replace function public.stock_tags_v1(p_workspace_id uuid, p_owner jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_item uuid;
  v_loc uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not exists (select 1 from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active')
     or not (public.has_permission(p_workspace_id, 'viewStock') or public.has_permission(p_workspace_id, 'manageStock')) then
    raise exception 'not allowed to read the tags' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'stockTags') then
    return '[]'::jsonb;
  end if;
  begin
    v_item := nullif(p_owner ->> 'item_id', '')::uuid;
    v_loc := nullif(p_owner ->> 'location_id', '')::uuid;
  exception when others then
    return '[]'::jsonb;
  end;
  return coalesce((
    select jsonb_agg(jsonb_build_object('tag_id', t.id, 'code', t.code, 'tag_kind', t.tag_kind, 'owner_kind', t.owner_kind,
             'variant_id', t.variant_id, 'lot_id', t.lot_id, 'unit', t.unit_code, 'piece_id', t.piece_id, 'bound_at', t.created_datetime)
           order by t.created_datetime, t.id)
      from public.stock_tags t
     where t.workspace_id = p_workspace_id and t.state = 'active'
       and ((v_item is not null and t.item_id = v_item) or (v_loc is not null and t.location_id = v_loc))), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.stock_tags_v1(uuid, jsonb) from public, anon;
grant execute on function public.stock_tags_v1(uuid, jsonb) to authenticated;

-- ── the one resolver of a scan ─────────────────────────────────────────
-- Answers {kind, matched_by, code, place | item | variant | unit | lot | tag}; never raises for an unknown code.
create or replace function public.stock_resolve_code_v1(p_workspace_id uuid, p_code text)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_names boolean := public.mcp_is_delegated();
  v_code text := btrim(coalesce(p_code, ''));
  v_norm text;
  v_gtin text;
  v_sg jsonb;
  l public.stock_locations;
  c public.item_codes;
  x public.stock_lots;
  t public.stock_tags;
  s public.services;
  v_unit public.item_units;
  v_var public.item_variants;
  v_out jsonb;
  v_item uuid;
  v_known boolean := false;
begin
  if auth.uid() is null
     or not exists (select 1 from public.members m where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active')
     or not (public.has_permission(p_workspace_id, 'viewStock') or public.has_permission(p_workspace_id, 'manageStock')) then
    raise exception 'not allowed to read the stock' using errcode = 'DKN01';
  end if;
  if v_code = '' or char_length(v_code) > 200 then
    return jsonb_build_object('kind', 'unknown', 'matched_by', null, 'code', v_code);
  end if;
  -- a place: its barcode, then its code
  select * into l from public.stock_locations where workspace_id = p_workspace_id and barcode = v_code and active;
  if l.id is not null then
    return jsonb_build_object('kind', 'place', 'matched_by', 'place_barcode', 'code', v_code,
      'place', case when v_names then jsonb_build_object('code', l.code, 'name', l.name, 'kind', l.kind)
                    else jsonb_build_object('id', l.id, 'code', l.code, 'name', l.name, 'kind', l.kind) end);
  end if;
  select * into l from public.stock_locations where workspace_id = p_workspace_id and code = v_code and active and not public.stock_place_is_virtual(id);
  if l.id is not null then
    return jsonb_build_object('kind', 'place', 'matched_by', 'place_code', 'code', v_code,
      'place', case when v_names then jsonb_build_object('code', l.code, 'name', l.name, 'kind', l.kind)
                    else jsonb_build_object('id', l.id, 'code', l.code, 'name', l.name, 'kind', l.kind) end);
  end if;
  -- an item, a variant or a package unit by its code, exactly as typed, then as a GTIN of any length
  select * into c from public.item_codes where workspace_id = p_workspace_id and code = v_code;
  if c.id is null and v_code ~ '^[0-9]{8,14}$' and public.stock_gtin_valid(v_code) then
    select * into c from public.item_codes where workspace_id = p_workspace_id and kind = 'gtin' and lpad(code, 14, '0') = lpad(v_code, 14, '0') limit 1;
  end if;
  if c.id is not null then
    select * into s from public.services where id = c.item_id;
    v_out := jsonb_build_object('code', v_code, 'matched_by', case when c.unit is not null then 'unit_code' when c.kind = 'gtin' then 'gtin' else 'own_code' end,
      'item', case when v_names then jsonb_build_object('name', s.name, 'unit', s.inventory_unit)
                   else jsonb_build_object('id', s.id, 'name', s.name, 'unit', s.inventory_unit) end);
    if c.variant_id is not null then
      select * into v_var from public.item_variants where id = c.variant_id;
      return v_out || jsonb_build_object('kind', 'variant', 'variant',
        case when v_names then jsonb_build_object('label', v_var.canonical) else jsonb_build_object('id', v_var.id, 'label', v_var.canonical) end);
    end if;
    if c.unit is not null and not v_names then
      select * into v_unit from public.item_units where item_id = c.item_id and unit = c.unit;
      v_out := v_out || jsonb_build_object('unit', jsonb_build_object('unit', c.unit, 'factor_num', v_unit.factor_num, 'factor_den', v_unit.factor_den));
    elsif c.unit is not null then
      v_out := v_out || jsonb_build_object('unit', jsonb_build_object('unit', c.unit));
    end if;
    return v_out || jsonb_build_object('kind', 'item');
  end if;
  -- a lot by its label
  select * into x from public.stock_lots where workspace_id = p_workspace_id and label_code = v_code;
  if x.id is not null then
    select * into s from public.services where id = x.item_id;
    return jsonb_build_object('kind', 'lot', 'matched_by', 'lot_label', 'code', v_code,
      'item', case when v_names then jsonb_build_object('name', s.name, 'unit', s.inventory_unit)
                   else jsonb_build_object('id', s.id, 'name', s.name, 'unit', s.inventory_unit) end,
      'lot', case when v_names then jsonb_build_object('code', x.lot_code) else jsonb_build_object('id', x.id, 'code', x.lot_code, 'expires_on', x.expires_on) end);
  end if;
  -- a tag in force, or an SGTIN of a product the business knows
  v_norm := case when public.feature_effective(p_workspace_id, 'stockTags') then public.stock_tag_normalize(v_code) end;
  if v_norm is not null then
    select * into t from public.stock_tags where workspace_id = p_workspace_id and code = v_norm and state = 'active';
    v_sg := public.stock_sgtin96_decode(v_norm);
    if t.id is not null then
      v_out := jsonb_build_object('kind', 'tag', 'matched_by', 'tag', 'code', v_norm);
      if not v_names then
        v_out := v_out || jsonb_build_object('tag', jsonb_build_object('tag_kind', t.tag_kind, 'owner_kind', t.owner_kind, 'bound', true,
                 'gtin', v_sg ->> 'gtin14', 'serial', v_sg ->> 'serial'));
      end if;
      if t.owner_kind = 'place' then
        select * into l from public.stock_locations where id = t.location_id;
        return v_out || jsonb_build_object('place', case when v_names then jsonb_build_object('code', l.code, 'name', l.name, 'kind', l.kind)
                                                          else jsonb_build_object('id', l.id, 'code', l.code, 'name', l.name, 'kind', l.kind) end);
      end if;
      select * into s from public.services where id = t.item_id;
      v_out := v_out || jsonb_build_object('item', case when v_names then jsonb_build_object('name', s.name, 'unit', s.inventory_unit)
                                                          else jsonb_build_object('id', s.id, 'name', s.name, 'unit', s.inventory_unit) end);
      if t.owner_kind = 'lot' then
        select * into x from public.stock_lots where id = t.lot_id;
        v_out := v_out || jsonb_build_object('lot', case when v_names then jsonb_build_object('code', x.lot_code) else jsonb_build_object('id', x.id, 'code', x.lot_code, 'expires_on', x.expires_on) end);
      elsif t.owner_kind = 'variant' then
        select * into v_var from public.item_variants where id = t.variant_id;
        v_out := v_out || jsonb_build_object('variant', case when v_names then jsonb_build_object('label', v_var.canonical) else jsonb_build_object('id', v_var.id, 'label', v_var.canonical) end);
      elsif t.owner_kind = 'unit' and not v_names then
        select * into v_unit from public.item_units where item_id = t.item_id and unit = t.unit_code;
        v_out := v_out || jsonb_build_object('unit', jsonb_build_object('unit', t.unit_code, 'factor_num', v_unit.factor_num, 'factor_den', v_unit.factor_den));
      elsif t.owner_kind = 'piece' then
        select u.lot_id into x.id from public.stock_tagged_units u where u.id = t.piece_id;
        if x.id is not null then
          select * into x from public.stock_lots where id = x.id;
          v_out := v_out || jsonb_build_object('lot', case when v_names then jsonb_build_object('code', x.lot_code) else jsonb_build_object('id', x.id, 'code', x.lot_code, 'expires_on', x.expires_on) end);
        end if;
        select * into v_var from public.item_variants where id = (select u.variant_id from public.stock_tagged_units u where u.id = t.piece_id);
        if v_var.id is not null then
          v_out := v_out || jsonb_build_object('variant', case when v_names then jsonb_build_object('label', v_var.canonical) else jsonb_build_object('id', v_var.id, 'label', v_var.canonical) end);
        end if;
      end if;
      return v_out;
    end if;
    if v_sg is not null then
      v_gtin := v_sg ->> 'gtin14';
      select * into c from public.item_codes where workspace_id = p_workspace_id and kind = 'gtin' and lpad(code, 14, '0') = v_gtin limit 1;
      if c.id is not null then
        select * into s from public.services where id = c.item_id;
        v_out := jsonb_build_object('kind', case when c.variant_id is null then 'item' else 'variant' end, 'matched_by', 'sgtin', 'code', v_norm,
          'known_product', true,
          'item', case when v_names then jsonb_build_object('name', s.name, 'unit', s.inventory_unit) else jsonb_build_object('id', s.id, 'name', s.name, 'unit', s.inventory_unit) end);
        if not v_names then
          v_out := v_out || jsonb_build_object('tag', jsonb_build_object('tag_kind', public.stock_tag_kind(v_norm), 'bound', false,
                   'gtin', v_gtin, 'serial', v_sg ->> 'serial'));
        end if;
        if c.variant_id is not null then
          select * into v_var from public.item_variants where id = c.variant_id;
          v_out := v_out || jsonb_build_object('variant', case when v_names then jsonb_build_object('label', v_var.canonical) else jsonb_build_object('id', v_var.id, 'label', v_var.canonical) end);
        end if;
        return v_out;
      end if;
    end if;
  end if;
  return jsonb_build_object('kind', 'unknown', 'matched_by', null, 'code', v_code);
end;
$fn$;
revoke execute on function public.stock_resolve_code_v1(uuid, text) from public, anon;
grant execute on function public.stock_resolve_code_v1(uuid, text) to authenticated;

-- ── the tag mode of an item with tags in force is not changed ───────────
-- restates 0883
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
  v_def text := pg_get_functiondef('public.item_override_save_v1(uuid, uuid, uuid, int, text, text, jsonb)'::regprocedure);
  v_next text;
begin
  v_next := pg_temp.anchor_replace(v_def, $o$  perform public.item_group_finance_guard(p_workspace_id, array[p_parameter]);$o$,
$n$  perform public.item_group_finance_guard(p_workspace_id, array[p_parameter]);
  -- the tag mode of an item with tags in force stays until they are retired
  if p_parameter = 'tag_mode' and exists (select 1 from public.stock_tags t
        where t.workspace_id = p_workspace_id and t.item_id = p_item_id and t.state = 'active')
     and (p_mode = 'inherit' or p_value #>> '{}' is distinct from (select s.tag_mode from public.services s where s.id = p_item_id)) then
    perform public.stock_config_refuse(p_parameter, 'has_tags');
  end if;$n$);
  if v_next is null then raise exception '0886: the finance guard of item_override_save_v1 is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- the workspace export carries the tags and the named pieces (#2860)
-- restates 0883
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
    -- #4362 the tags bound to items, places and pieces, and the named pieces
    'stock_tags', 'stock_tagged_units',
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

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(886);
