-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (events gains a type; two readers of events and one saver of the supplier's articles are
--  patched at asserted anchors; new tables and functions)
--
-- #4294 (G8, server side): reorder points per item and site, low-stock alerts and a
-- replenishment list.
--
--   * A POINT says: at this site, when this item (or one variant of it) is at or below
--     `reorder_point`, it is low. Exact quantities in the item's inventory unit; an optional
--     `reorder_quantity` (what to order) or `target_quantity` (order up to it), never both. A
--     site is the root place of a tree (`stock_site_of`, until #4293 gives it its own level;
--     the points follow whatever that function says). An item with no point is never low. A
--     point of an item with variants and no variant counts the item as a whole.
--   * LOW is read from the ledger: what the real places of the site hold, in-transit goods and
--     virtual places not counted. One alert per point while it stays low: an inbox event
--     `stock_low` (the form `payment_attempt_unreadable` set: the owner is its actor, one open
--     notice per point held by the database), opened when a movement or a save finds the point
--     crossed and ended, with the time, when the stock rises above it. A repeated movement
--     while low changes nothing. Read with manageStock or managePurchases.
--   * The REPLENISHMENT list groups what is low by the supplier whose article is marked
--     `preferred` for the item (one per item and variant; none preferred: "no supplier
--     chosen"), in the article's purchase unit, rounded up to whole units. A DRAFT purchase
--     order is made from it (managePurchases); nothing is ordered, priced or sent.
--   * The movement trigger is cheap: it leaves at once when the item has no active point.

-- an anchored replace: whitespace-flexible, NULL when the anchor is missing
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

-- ── the supplier's preferred article ─────────────────────────────────────
alter table public.supplier_item_mappings add column preferred boolean not null default false;
create unique index supplier_item_mappings_one_preferred
  on public.supplier_item_mappings (item_id, variant_id) nulls not distinct
  where preferred and active;

do $patch$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.save_supplier_item_mapping_v1(uuid, uuid, int, uuid, jsonb)'::regprocedure);
  for v_old, v_new in
    select * from (values
      ($a$  v_active boolean;
  v_id uuid;$a$,
       $b$  v_active boolean;
  v_pref boolean;
  v_id uuid;$b$),
      ($a$  v_active := coalesce((p_mapping ->> 'active')::boolean, v_old.active, true);$a$,
       $b$  v_active := coalesce((p_mapping ->> 'active')::boolean, v_old.active, true);
  v_pref := public.stock_config_bool(p_mapping, 'preferred', 'preferred', coalesce(v_old.preferred, false));$b$),
      ($a$  if p_mapping_id is null then
    insert into public.supplier_item_mappings (workspace_id, supplier_id, item_id, variant_id, article_ref, purchase_unit, active)
    values (p_workspace_id, v_supplier, v_item, v_variant, v_ref, v_unit, v_active)$a$,
       $b$  -- one preferred article per item and variant
  if v_pref and v_active and exists (select 1 from public.supplier_item_mappings m
       where m.item_id = v_item and m.variant_id is not distinct from v_variant and m.preferred and m.active
         and m.id is distinct from p_mapping_id) then
    perform public.stock_config_refuse('preferred', 'preferred_twice');
  end if;
  if p_mapping_id is null then
    insert into public.supplier_item_mappings (workspace_id, supplier_id, item_id, variant_id, article_ref, purchase_unit, active, preferred)
    values (p_workspace_id, v_supplier, v_item, v_variant, v_ref, v_unit, v_active, v_pref)$b$),
      ($a$           purchase_unit = v_unit, active = v_active, revision = revision + 1$a$,
       $b$           purchase_unit = v_unit, active = v_active, preferred = v_pref, revision = revision + 1$b$)
    ) t(o, n)
  loop
    if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
      raise exception '0855: an anchor of save_supplier_item_mapping_v1 is not found exactly once: %', left(v_old, 70) using errcode = 'P0001';
    end if;
    v_def := replace(v_def, v_old, v_new);
  end loop;
  execute v_def;
end
$patch$;

-- ── the points ───────────────────────────────────────────────────────────
create table public.stock_reorder_points (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  item_id uuid not null,
  variant_id uuid,
  -- the site: its root place (stock_site_of)
  site_id uuid not null,
  reorder_point numeric(18, 6) not null check (reorder_point >= 0),
  reorder_quantity numeric(18, 6) check (reorder_quantity is null or reorder_quantity > 0),
  target_quantity numeric(18, 6) check (target_quantity is null or target_quantity > 0),
  active boolean not null default true,
  revision int not null default 1,
  unique (workspace_id, id),
  check (reorder_quantity is null or target_quantity is null),
  foreign key (workspace_id, item_id) references public.services (workspace_id, id),
  foreign key (item_id, variant_id) references public.item_variants (item_id, id),
  foreign key (workspace_id, site_id) references public.stock_locations (workspace_id, id)
);
select public.ensure_system_columns('stock_reorder_points');
create unique index stock_reorder_points_one on public.stock_reorder_points (item_id, variant_id, site_id) nulls not distinct;
create index stock_reorder_points_active_item on public.stock_reorder_points (item_id) where active;

alter table public.stock_reorder_points enable row level security;
revoke all on public.stock_reorder_points from public, anon, authenticated;
grant select on public.stock_reorder_points to authenticated;
create policy stock_reorder_points_select on public.stock_reorder_points for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock', 'managePurchases']))
         and public.feature_effective(workspace_id, 'stockReorder'));
create policy mcp_delegated_deny on public.stock_reorder_points as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the alert: an inbox event ────────────────────────────────────────────
do $constraints$
declare r record; v_def text;
begin
  for r in select * from (values
    ('events', 'events_type_check', 'type'),
    ('validation_policies', 'validation_policies_event_type_check', 'event_type')
  ) as c(table_name, constraint_name, column_name) loop
    select pg_get_constraintdef(oid) into v_def from pg_constraint
     where conrelid = ('public.' || r.table_name)::regclass and conname = r.constraint_name;
    if v_def is null or position('CHECK (' in v_def) <> 1 then
      raise exception '0855: the event type constraint % is not there', r.constraint_name using errcode = 'P0001';
    end if;
    if position('stock_low' in v_def) = 0 then
      execute format('alter table public.%I drop constraint %I', r.table_name, r.constraint_name);
      execute format('alter table public.%I add constraint %I ', r.table_name, r.constraint_name)
        || replace(v_def, 'CHECK (', format('CHECK (%I = %L OR ', r.column_name, 'stock_low'));
    end if;
  end loop;
end;
$constraints$;

do $patch$
declare
  v_def text;
  v_next text;
begin
  -- who reads it: those who manage the stock or the purchases
  v_def := pg_get_functiondef('public.event_type_view_permissions(text)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$ else array['manageConfiguration']$o$,
    $n$ when p_type = 'stock_low' then array['manageStock', 'managePurchases'] else array['manageConfiguration']$n$);
  if v_next is null then raise exception '0855: the anchor of event_type_view_permissions is not found' using errcode = 'P0001'; end if;
  execute v_next;

  -- a notice nobody decides
  v_def := pg_get_functiondef('public.event_type_waits_for_decision(text)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def, $o$'settlement_review')$o$, $n$'settlement_review', 'stock_low')$n$);
  if v_next is null then raise exception '0855: the anchor of event_type_waits_for_decision is not found' using errcode = 'P0001'; end if;
  execute v_next;

  -- the owner is its actor and subject: it is not the owner's own data
  v_def := pg_get_functiondef('public.export_my_data(uuid)'::regprocedure);
  v_next := pg_temp.anchor_replace(v_def,
    $o$and e.type <> 'payment_attempt_unreadable'$o$,
    $n$and e.type not in ('payment_attempt_unreadable', 'stock_low')$n$);
  if v_next is null then raise exception '0855: the anchor of export_my_data is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- the workspace export carries the points (#2860): 0852's function restated
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
    'stock_reorder_points',
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

-- one open notice per point, held by the database
create unique index events_stock_low_open_once on public.events ((payload ->> 'point'))
  where type = 'stock_low' and not (payload ? 'ended');

-- ── what a site holds ────────────────────────────────────────────────────
-- The site of a real place; none for a virtual place, the in-transit place or an unknown one.
create or replace function public.stock_real_site(p_location_id uuid)
returns uuid language sql stable security definer set search_path = public as $fn$
  select case when k.virtual or l.kind = 'in_transit' then null else public.stock_site_of(l.id) end
    from public.stock_locations l join public.stock_location_kinds k on k.key = l.kind
   where l.id = p_location_id
$fn$;
revoke execute on function public.stock_real_site(uuid) from public, anon, authenticated;

-- What the real places of a site hold of an item (one variant, or every variant when null):
-- goods in transit and in virtual places are not counted.
create or replace function public.stock_site_on_hand(p_workspace_id uuid, p_item_id uuid, p_variant_id uuid, p_site_id uuid)
returns numeric language sql stable security definer set search_path = public as $fn$
  select coalesce(sum(b.quantity), 0)
    from public.stock_balances b
   where b.workspace_id = p_workspace_id and b.item_id = p_item_id
     and (p_variant_id is null or b.variant_id = p_variant_id)
     and public.stock_real_site(b.location_id) = p_site_id
$fn$;
revoke execute on function public.stock_site_on_hand(uuid, uuid, uuid, uuid) from public, anon, authenticated;

-- ── the alert ────────────────────────────────────────────────────────────
-- Opens the point's notice when it is low and has none, ends it when it is not low any more. A
-- point that is low and already has its notice changes nothing: one alert while it stays low.
create or replace function public.stock_reorder_check(p_point_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_pt public.stock_reorder_points;
  v_on numeric;
  v_open uuid;
  v_actor uuid;
begin
  select * into v_pt from public.stock_reorder_points where id = p_point_id;
  if v_pt.id is null or not public.feature_effective(v_pt.workspace_id, 'stockReorder') then return; end if;
  select e.id into v_open from public.events e
   where e.workspace_id = v_pt.workspace_id and e.type = 'stock_low'
     and e.payload ->> 'point' = p_point_id::text and not (e.payload ? 'ended')
   order by e.created_at, e.id limit 1;
  v_on := public.stock_site_on_hand(v_pt.workspace_id, v_pt.item_id, v_pt.variant_id, v_pt.site_id);
  if v_pt.active and v_on <= v_pt.reorder_point then
    if v_open is null then
      select m.id into v_actor from public.members m
       where m.workspace_id = v_pt.workspace_id and m.is_owner and m.status = 'active'
       order by m.joined_at, m.id limit 1;
      if v_actor is null then return; end if;
      insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
      values (v_pt.workspace_id, 'stock_low', 'created', v_actor, v_actor,
              jsonb_build_object('point', v_pt.id, 'item_id', v_pt.item_id, 'variant_id', v_pt.variant_id,
                                 'site_id', v_pt.site_id, 'on_hand', v_on::text,
                                 'reorder_point', v_pt.reorder_point::text),
              'applied')
      on conflict ((payload ->> 'point')) where type = 'stock_low' and not (payload ? 'ended') do nothing;
    end if;
  elsif v_open is not null then
    update public.events
       set payload = payload || jsonb_build_object('ended', 'cleared', 'ended_at', now())
     where id = v_open;
  end if;
end;
$fn$;
revoke execute on function public.stock_reorder_check(uuid) from public, anon, authenticated;

-- A movement may cross a point: cheap, and nothing at all for an item without an active point.
create or replace function public.stock_movements_reorder()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  r record;
  v_from uuid;
  v_to uuid;
begin
  if not exists (select 1 from public.stock_reorder_points p where p.item_id = new.item_id and p.active) then
    return null;
  end if;
  v_from := public.stock_real_site(new.from_location_id);
  v_to := public.stock_real_site(new.to_location_id);
  if v_from is null and v_to is null then return null; end if;
  for r in select p.id from public.stock_reorder_points p
            where p.item_id = new.item_id and p.active
              and (p.variant_id is null or p.variant_id is not distinct from new.variant_id)
              and p.site_id in (v_from, v_to)
  loop
    perform public.stock_reorder_check(r.id);
  end loop;
  return null;
end;
$fn$;
revoke execute on function public.stock_movements_reorder() from public, anon, authenticated;
create trigger stock_movements_reorder after insert on public.stock_movements
  for each row execute function public.stock_movements_reorder();

-- ── setting a point ──────────────────────────────────────────────────────
-- A quantity of the request, exact: absent answers [p_default]; null or empty is none.
create or replace function public.stock_reorder_quantity(p_obj jsonb, p_key text, p_default numeric)
returns numeric language plpgsql immutable set search_path = public as $fn$
declare
  v text;
begin
  if not (p_obj ? p_key) then return p_default; end if;
  v := nullif(btrim(coalesce(p_obj ->> p_key, '')), '');
  if v is null then return null; end if;
  if v !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' then
    perform public.stock_config_refuse(p_key, 'quantity_invalid');
  end if;
  return v::numeric;
end;
$fn$;
revoke execute on function public.stock_reorder_quantity(jsonb, text, numeric) from public, anon, authenticated;

create or replace function public.save_stock_reorder_point_v1(
  p_workspace_id uuid, p_point_id uuid, p_expected_revision int, p_request_id uuid, p_point jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text;
  v_done public.purchase_requests;
  v_old public.stock_reorder_points;
  v_item uuid;
  v_variant uuid;
  v_site uuid;
  v_point numeric;
  v_qty numeric;
  v_target numeric;
  v_active boolean;
  v_id uuid;
  v_rev int;
  v_result jsonb;
begin
  perform public.stock_config_actor(p_workspace_id);
  if not public.feature_effective(p_workspace_id, 'stockReorder') then
    raise exception 'reorder points are off in this business' using errcode = 'DKG01';
  end if;
  if p_request_id is null or coalesce(jsonb_typeof(p_point), '') <> 'object'
     or (p_point_id is null) <> (p_expected_revision is null) then
    perform public.stock_config_refuse('request', 'malformed');
  end if;
  v_digest := md5('stock_reorder_point_save|' || coalesce(p_point_id::text, '') || '|'
                  || coalesce(p_expected_revision::text, '') || '|' || p_point::text);
  perform pg_advisory_xact_lock(
    hashtextextended('purchase_request:' || p_workspace_id::text || p_request_id::text, 0));
  select * into v_done from public.purchase_requests
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.operation <> 'stock_reorder_point_save' or v_done.digest <> v_digest then
      raise exception 'this request id was already used for a different request' using errcode = 'DKG07';
    end if;
    return v_done.result || jsonb_build_object('replayed', true);
  end if;
  if p_point_id is not null then
    select * into v_old from public.stock_reorder_points
     where id = p_point_id and workspace_id = p_workspace_id for update;
    if v_old.id is null then raise exception 'not a reorder point of this business' using errcode = 'DKG04'; end if;
    if v_old.revision <> p_expected_revision then
      raise exception 'this reorder point changed since it was read' using errcode = 'DKG10';
    end if;
  end if;
  v_item := coalesce(public.stock_config_uuid(p_point, 'item_id', 'item_id'), v_old.item_id);
  v_variant := case when p_point ? 'variant_id' then public.stock_config_uuid(p_point, 'variant_id', 'variant_id') else v_old.variant_id end;
  v_site := coalesce(public.stock_config_uuid(p_point, 'site_id', 'site_id'), v_old.site_id);
  v_point := public.stock_reorder_quantity(p_point, 'reorder_point', v_old.reorder_point);
  v_qty := public.stock_reorder_quantity(p_point, 'reorder_quantity', v_old.reorder_quantity);
  v_target := public.stock_reorder_quantity(p_point, 'target_quantity', v_old.target_quantity);
  v_active := public.stock_config_bool(p_point, 'active', 'active', coalesce(v_old.active, true));

  if v_item is null or not exists (select 1 from public.services s
       where s.id = v_item and s.workspace_id = p_workspace_id and s.stockable) then
    perform public.stock_config_refuse('item_id', 'item_foreign');
  end if;
  if v_variant is not null and not exists (select 1 from public.item_variants x
       where x.id = v_variant and x.item_id = v_item and x.workspace_id = p_workspace_id) then
    perform public.stock_config_refuse('variant_id', 'variant_unknown');
  end if;
  if v_site is null or public.stock_real_site(v_site) is distinct from v_site
     or not exists (select 1 from public.stock_locations l where l.id = v_site and l.workspace_id = p_workspace_id) then
    perform public.stock_config_refuse('site_id', 'site_unknown');
  end if;
  if p_point_id is not null and (v_item is distinct from v_old.item_id or v_variant is distinct from v_old.variant_id
                                 or v_site is distinct from v_old.site_id) then
    perform public.stock_config_refuse('item_id', 'point_fixed');
  end if;
  if v_point is null then perform public.stock_config_refuse('reorder_point', 'quantity_invalid'); end if;
  if v_qty is not null and v_target is not null then
    perform public.stock_config_refuse('target_quantity', 'quantity_and_target');
  end if;
  if v_target is not null and v_target <= v_point then
    perform public.stock_config_refuse('target_quantity', 'target_below_point');
  end if;
  if exists (select 1 from public.stock_reorder_points x
              where x.item_id = v_item and x.variant_id is not distinct from v_variant and x.site_id = v_site
                and x.id is distinct from p_point_id) then
    perform public.stock_config_refuse('item_id', 'point_twice');
  end if;

  if p_point_id is null then
    insert into public.stock_reorder_points (workspace_id, item_id, variant_id, site_id, reorder_point, reorder_quantity, target_quantity, active)
    values (p_workspace_id, v_item, v_variant, v_site, v_point, v_qty, v_target, v_active)
    returning id, revision into v_id, v_rev;
  else
    update public.stock_reorder_points
       set reorder_point = v_point, reorder_quantity = v_qty, target_quantity = v_target, active = v_active,
           revision = revision + 1
     where id = p_point_id returning id, revision into v_id, v_rev;
  end if;
  -- the point may already be crossed (or no longer be): the alert follows
  perform public.stock_reorder_check(v_id);
  v_result := jsonb_build_object('point_id', v_id, 'revision', v_rev, 'replayed', false);
  insert into public.purchase_requests (workspace_id, request_id, operation, digest, result)
  values (p_workspace_id, p_request_id, 'stock_reorder_point_save', v_digest, v_result);
  return v_result;
end;
$fn$;
revoke execute on function public.save_stock_reorder_point_v1(uuid, uuid, int, uuid, jsonb) from public, anon;
grant execute on function public.save_stock_reorder_point_v1(uuid, uuid, int, uuid, jsonb) to authenticated;

-- ── reading what is low, and the replenishment list ──────────────────────
-- Who reads: managing the stock or the purchases, or viewing the stock; the feature on.
create or replace function public.stock_reorder_reader(p_workspace_id uuid)
returns void language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not exists (select 1 from public.members m where m.workspace_id = p_workspace_id
                      and m.user_id = auth.uid() and m.status = 'active')
     or not (public.has_permission(p_workspace_id, 'viewStock')
             or public.has_permission(p_workspace_id, 'manageStock')
             or public.has_permission(p_workspace_id, 'managePurchases')) then
    raise exception 'not allowed to see what is low' using errcode = 'DKN01';
  end if;
  if not (public.feature_effective(p_workspace_id, 'stockManagement')
          and public.feature_effective(p_workspace_id, 'stockReorder')) then
    raise exception 'reorder points are off in this business' using errcode = 'DKG01';
  end if;
end;
$fn$;
revoke execute on function public.stock_reorder_reader(uuid) from public, anon, authenticated;

-- The points at or below their level, with what to order: the reorder quantity, or what is
-- missing up to the target (never below zero); none when the point names neither.
create or replace function public.stock_low_rows(p_workspace_id uuid, p_site_id uuid)
returns table (point_id uuid, item_id uuid, item_name text, unit text, variant_id uuid, site_id uuid, site_code text,
               on_hand numeric, reorder_point numeric, proposed numeric, since timestamptz)
language sql stable security definer set search_path = public as $fn$
  select x.* from (
    select r.id, r.item_id, s.name, s.inventory_unit, r.variant_id, r.site_id, l.code,
           public.stock_site_on_hand(r.workspace_id, r.item_id, r.variant_id, r.site_id) as on_hand,
           r.reorder_point,
           case when r.reorder_quantity is not null then r.reorder_quantity
                when r.target_quantity is not null
                  then greatest(r.target_quantity - public.stock_site_on_hand(r.workspace_id, r.item_id, r.variant_id, r.site_id), 0)
           end as proposed,
           (select e.created_at from public.events e
             where e.workspace_id = r.workspace_id and e.type = 'stock_low'
               and e.payload ->> 'point' = r.id::text and not (e.payload ? 'ended')
             order by e.created_at limit 1) as since
      from public.stock_reorder_points r
      join public.services s on s.id = r.item_id
      join public.stock_locations l on l.id = r.site_id
     where r.workspace_id = p_workspace_id and r.active and (p_site_id is null or r.site_id = p_site_id)
  ) x
  where x.on_hand <= x.reorder_point
  order by x.code, x.name, x.variant_id nulls first
$fn$;
revoke execute on function public.stock_low_rows(uuid, uuid) from public, anon, authenticated;

create or replace function public.stock_low_v1(p_workspace_id uuid, p_site_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.stock_reorder_reader(p_workspace_id);
  return jsonb_build_object('rows', coalesce((
    select jsonb_agg(jsonb_build_object(
             'point_id', r.point_id, 'item_id', r.item_id, 'item_name', r.item_name, 'unit', r.unit,
             'variant_id', r.variant_id, 'site_id', r.site_id, 'site_code', r.site_code,
             'on_hand', r.on_hand::text, 'reorder_point', r.reorder_point::text,
             'proposed', r.proposed::text, 'since', r.since))
      from public.stock_low_rows(p_workspace_id, p_site_id) r), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.stock_low_v1(uuid, uuid) from public, anon;
grant execute on function public.stock_low_v1(uuid, uuid) to authenticated;

-- What is low, by the supplier whose article is preferred for it: the article, its purchase unit and the
-- quantity in that unit, rounded up to whole units. Without a preferred article: "no supplier chosen".
create or replace function public.stock_replenishment_v1(p_workspace_id uuid, p_site_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.stock_reorder_reader(p_workspace_id);
  return (
    with l as (
      select r.point_id, r.item_id, r.item_name, r.unit, r.variant_id, r.site_id, r.site_code,
             m.supplier_id, m.article_ref, m.purchase_unit,
             case when m.id is null then null
                  when m.purchase_unit is null then r.proposed
                  else ceil(r.proposed * f.den / f.num) end as quantity,
             r.proposed as inventory_quantity
        from public.stock_low_rows(p_workspace_id, p_site_id) r
        left join lateral (
          select mm.* from public.supplier_item_mappings mm
           where mm.workspace_id = p_workspace_id and mm.item_id = r.item_id and mm.preferred and mm.active
             and (mm.variant_id is null or mm.variant_id = r.variant_id)
           order by (mm.variant_id is not null) desc limit 1) m on true
        left join lateral (select u.factor_num as num, u.factor_den as den from public.item_units u
                            where u.item_id = r.item_id and u.unit = m.purchase_unit) f on true
       where coalesce(r.proposed, 0) > 0
    )
    select jsonb_build_object(
      'groups', coalesce((
        select jsonb_agg(t.g order by t.g ->> 'supplier_name') from (
          select jsonb_build_object('supplier_id', l.supplier_id, 'supplier_name', s.name,
                   'lines', jsonb_agg(jsonb_build_object(
                     'point_id', l.point_id, 'item_id', l.item_id, 'item_name', l.item_name, 'variant_id', l.variant_id,
                     'site_id', l.site_id, 'site_code', l.site_code, 'article_ref', l.article_ref,
                     'purchase_unit', coalesce(l.purchase_unit, l.unit), 'quantity', l.quantity::text,
                     'inventory_quantity', l.inventory_quantity::text) order by l.site_code, l.item_name)) as g
            from l join public.suppliers s on s.id = l.supplier_id
           where l.supplier_id is not null group by l.supplier_id, s.name) t), '[]'::jsonb),
      'no_supplier', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'point_id', l.point_id, 'item_id', l.item_id, 'item_name', l.item_name, 'variant_id', l.variant_id,
                 'site_id', l.site_id, 'site_code', l.site_code, 'unit', l.unit,
                 'inventory_quantity', l.inventory_quantity::text) order by l.site_code, l.item_name)
          from l where l.supplier_id is null), '[]'::jsonb))
  );
end;
$fn$;
revoke execute on function public.stock_replenishment_v1(uuid, uuid) from public, anon;
grant execute on function public.stock_replenishment_v1(uuid, uuid) to authenticated;

-- A DRAFT purchase order from lines of the list: each line must be an article preferred at that supplier.
-- Priced at zero (unpriced), never sent: the owner confirms it as any draft order.
create or replace function public.create_replenishment_draft_v1(
  p_workspace_id uuid, p_request_id uuid, p_supplier_id uuid, p_lines jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_digest text;
  v_done jsonb;
  e jsonb;
  i int := 0;
  v_item uuid;
  v_variant uuid;
  v_m public.supplier_item_mappings;
  v_name text;
  v_unit text;
  v_lines jsonb := '[]'::jsonb;
  v_order jsonb;
begin
  perform public.purchase_order_actor(p_workspace_id);
  if not (public.feature_effective(p_workspace_id, 'stockManagement')
          and public.feature_effective(p_workspace_id, 'stockReorder')) then
    raise exception 'reorder points are off in this business' using errcode = 'DKG01';
  end if;
  if p_request_id is null or coalesce(jsonb_typeof(p_lines), '') <> 'array'
     or jsonb_array_length(p_lines) not between 1 and 200 then
    perform public.stock_config_refuse('lines', 'malformed');
  end if;
  v_digest := md5(coalesce(p_supplier_id::text, '') || '|' || p_lines::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'replenishment_draft', v_digest);
  if v_done is not null then return v_done; end if;
  for e in select value from jsonb_array_elements(p_lines) loop
    i := i + 1;
    v_item := public.stock_config_uuid(e, 'item_id', format('lines[%s].item_id', i - 1));
    v_variant := public.stock_config_uuid(e, 'variant_id', format('lines[%s].variant_id', i - 1));
    if coalesce(e ->> 'quantity', '') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' or (e ->> 'quantity')::numeric <= 0 then
      perform public.stock_config_refuse(format('lines[%s].quantity', i - 1), 'quantity_invalid');
    end if;
    select mm.* into v_m from public.supplier_item_mappings mm
     where mm.workspace_id = p_workspace_id and mm.supplier_id = p_supplier_id and mm.item_id = v_item
       and mm.preferred and mm.active and (mm.variant_id is null or mm.variant_id is not distinct from v_variant)
     order by (mm.variant_id is not null) desc limit 1;
    if v_m.id is null then
      perform public.stock_config_refuse(format('lines[%s]', i - 1), 'mapping_unknown');
    end if;
    select s.name, s.inventory_unit into v_name, v_unit from public.services s where s.id = v_item;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'service_id', v_item, 'description', v_m.article_ref || ' ' || v_name, 'quantity', e ->> 'quantity',
      'unit', coalesce(v_m.purchase_unit, v_unit), 'unit_price_cents', 0));
  end loop;
  v_order := public.save_purchase_order_v1(p_workspace_id, md5(p_request_id::text || 'replenishment')::uuid, null,
    jsonb_build_object('supplier_id', p_supplier_id, 'lines', v_lines));
  return public.purchase_request_end(p_workspace_id, p_request_id, 'replenishment_draft', v_digest, v_order);
end;
$fn$;
revoke execute on function public.create_replenishment_draft_v1(uuid, uuid, uuid, jsonb) from public, anon;
grant execute on function public.create_replenishment_draft_v1(uuid, uuid, uuid, jsonb) to authenticated;

select public.set_deskilo_schema_version(855);
