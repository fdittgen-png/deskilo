-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one table, its guard, helpers and three commands; stock_move_v1 is patched at one asserted anchor of its
--  live definition; the workspace export function is restated whole)
--
-- #4172 (G5, checkpoint A, second server file): stock counts, approved before they move the stock.
--
--   * A COUNT is the scope (item, variant, lot, place), what was observed there, what the ledger held
--     there when it was counted (`baseline_quantity`) and how many movements had touched the scope
--     (`baseline_moves`: the ledger is append-only, so the number only grows), the author and a
--     reason. It has a stable `count_id` per business, apart from the transport request id: the same
--     count sent again answers what was recorded, other content under that id is refused (DKG16).
--     `manageStock` records it. Recording moves nothing.
--   * `approveStockAdjustments` decides it: APPLY posts the difference as one adjustment movement to or
--     from the loss place, and only if no movement has touched the scope since the count (otherwise
--     DKG20: the stock moved, count again; nothing is overwritten); REJECT and CANCEL post nothing. Whoever
--     counted does not apply their own count while another active member may approve adjustments (DKG21). A
--     decided count is final (DKG19), and the same decision sent again answers the same result. A person
--     who holds both rights, the owner of a one-person business, records and applies it themselves, and
--     both are kept (`author_member_id`, `decided_by_member_id`).
--   * The generic move can no longer be an adjustment or an opening without that right: `stock_move_v1` with
--     the reason `adjustment` or `opening` needs `approveStockAdjustments` on top of `manageStock`. The shelf count of an item
--     (`services.stock`) is already refused once the ledger exists (0847, DKG13).
--   * `stock_counts_v1` reads the counts, each with whether it is stale.

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

-- ── the generic move is not a way round the approval ───────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.stock_move_v1(uuid, uuid, jsonb, text, timestamptz, jsonb)'::regprocedure);
  v_next text;
begin
  v_next := pg_temp.anchor_replace(v_def,
    $o$  if v_me is null or not public.has_permission(p_workspace_id, 'manageStock') then
    raise exception 'not allowed to move stock' using errcode = 'DKN01';
  end if;$o$,
    $n$  if v_me is null or not public.has_permission(p_workspace_id, 'manageStock') then
    raise exception 'not allowed to move stock' using errcode = 'DKN01';
  end if;
  -- stock made from nothing, with no document behind it, is approved: by whoever holds the right to approve
  -- adjustments, however it is made (an adjustment, or an opening count)
  if p_reason in ('adjustment', 'opening') and not public.has_permission(p_workspace_id, 'approveStockAdjustments') then
    raise exception 'an adjustment or an opening is made by someone who may approve adjustments' using errcode = 'DKN01';
  end if;$n$);
  if v_next is null then raise exception '0869: the anchor of stock_move_v1 is not found' using errcode = 'P0001'; end if;
  execute v_next;
end
$patch$;

-- ── the counts ─────────────────────────────────────────────────────────
create table public.stock_counts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  count_id uuid not null,
  item_id uuid not null,
  variant_id uuid,
  lot_id uuid,
  location_id uuid not null,
  observed_quantity numeric(18, 6) not null check (observed_quantity >= 0),
  baseline_quantity numeric(18, 6) not null,
  baseline_moves integer not null check (baseline_moves >= 0),
  reason text not null default '' check (char_length(reason) <= 300),
  state text not null default 'recorded' check (state in ('recorded', 'applied', 'rejected', 'cancelled')),
  author_member_id uuid not null,
  decided_by_member_id uuid,
  decided_at timestamptz,
  decision_note text not null default '' check (char_length(decision_note) <= 300),
  applied_movement_id uuid,
  request_id uuid not null,
  digest text not null,
  unique (workspace_id, count_id),
  check ((state = 'recorded') = (decided_at is null)),
  check ((state = 'recorded') = (decided_by_member_id is null)),
  foreign key (workspace_id, item_id) references public.services (workspace_id, id) on delete cascade,
  foreign key (workspace_id, lot_id) references public.stock_lots (workspace_id, id) on delete cascade,
  foreign key (workspace_id, location_id) references public.stock_locations (workspace_id, id) on delete cascade,
  foreign key (workspace_id, author_member_id) references public.members (workspace_id, id),
  foreign key (workspace_id, decided_by_member_id) references public.members (workspace_id, id),
  foreign key (workspace_id, applied_movement_id) references public.stock_movements (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('stock_counts');
create index stock_counts_state on public.stock_counts (workspace_id, state, created_datetime);

-- a count is decided once: only its state, its decision and the movement it made change, only from `recorded`
create or replace function public.stock_counts_guard()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' then
    if not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then return old; end if;
    raise exception 'a count is never deleted: it is cancelled' using errcode = 'DKG08';
  end if;
  if old.state <> 'recorded' then
    raise exception 'a decided count is final' using errcode = 'DKG19';
  end if;
  if (new.id, new.workspace_id, new.count_id, new.item_id, new.variant_id, new.lot_id, new.location_id,
      new.observed_quantity, new.baseline_quantity, new.baseline_moves, new.reason, new.author_member_id,
      new.request_id, new.digest)
     is distinct from
     (old.id, old.workspace_id, old.count_id, old.item_id, old.variant_id, old.lot_id, old.location_id,
      old.observed_quantity, old.baseline_quantity, old.baseline_moves, old.reason, old.author_member_id,
      old.request_id, old.digest) then
    raise exception 'a count is decided, never edited' using errcode = 'DKG08';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.stock_counts_guard() from public, anon, authenticated;
create trigger stock_counts_guard before update or delete on public.stock_counts
  for each row execute function public.stock_counts_guard();

alter table public.stock_counts enable row level security;
revoke all on public.stock_counts from public, anon, authenticated;
grant select on public.stock_counts to authenticated;
create policy stock_counts_select on public.stock_counts for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock', 'approveStockAdjustments']))
         and public.feature_effective(workspace_id, 'stockCounts'));
create policy mcp_delegated_deny on public.stock_counts as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- how many movements have touched a scope: the ledger is append-only, so only a growing number says it moved.
-- An item that is not tracked by lot is counted as a whole: a cost lot a receipt put on it is part of the count.
create or replace function public.stock_scope_moves(p_workspace_id uuid, p_item_id uuid, p_variant_id uuid, p_lot_id uuid, p_location_id uuid)
returns integer language sql stable security definer set search_path = public as $fn$
  select count(*)::integer from public.stock_movements m
   where m.workspace_id = p_workspace_id and m.item_id = p_item_id
     and m.variant_id is not distinct from p_variant_id
     and (m.lot_id is not distinct from p_lot_id
          or (p_lot_id is null and exists (select 1 from public.services s where s.id = p_item_id and s.tracking = 'none')))
     and (m.from_location_id = p_location_id or m.to_location_id = p_location_id)
$fn$;
revoke execute on function public.stock_scope_moves(uuid, uuid, uuid, uuid, uuid) from public, anon, authenticated;

create or replace function public.stock_scope_on_hand(p_workspace_id uuid, p_item_id uuid, p_variant_id uuid, p_lot_id uuid, p_location_id uuid)
returns numeric language sql stable security definer set search_path = public as $fn$
  select coalesce(sum(b.quantity), 0)::numeric(18, 6) from public.stock_balances b
   where b.workspace_id = p_workspace_id and b.item_id = p_item_id
     and b.variant_id is not distinct from p_variant_id
     and (b.lot_id is not distinct from p_lot_id
          or (p_lot_id is null and exists (select 1 from public.services s where s.id = p_item_id and s.tracking = 'none')))
     and b.location_id = p_location_id
$fn$;
revoke execute on function public.stock_scope_on_hand(uuid, uuid, uuid, uuid, uuid) from public, anon, authenticated;

-- ── recording a count ──────────────────────────────────────────────────
-- Scope: {item_id, variant_id?, lot_id?, location_id}. Nothing moves.
create or replace function public.stock_count_record_v1(
  p_workspace_id uuid, p_request_id uuid, p_count_id uuid, p_scope jsonb, p_observed text, p_reason text default ''
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.stock_ops_actor(p_workspace_id);
  v_item public.services;
  v_loc public.stock_locations;
  v_var uuid;
  v_lot uuid;
  v_obs numeric;
  v_digest text;
  v_done jsonb;
  v_first public.stock_counts;
  v_base numeric;
  v_moves integer;
  v_result jsonb;
  v_uuid constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
begin
  if not public.feature_effective(p_workspace_id, 'stockCounts') then
    raise exception 'counts are off in this business' using errcode = 'DKG01';
  end if;
  if p_request_id is null or p_count_id is null or coalesce(jsonb_typeof(p_scope), '') <> 'object'
     or coalesce(p_observed, '') !~ '^[0-9]{1,12}(\.[0-9]{1,6})?$' or char_length(coalesce(p_reason, '')) > 300
     or coalesce(p_scope ->> 'item_id', '') !~ v_uuid or coalesce(p_scope ->> 'location_id', '') !~ v_uuid
     or (nullif(p_scope ->> 'variant_id', '') is not null and (p_scope ->> 'variant_id') !~ v_uuid)
     or (nullif(p_scope ->> 'lot_id', '') is not null and (p_scope ->> 'lot_id') !~ v_uuid) then
    raise exception 'a count has an identity, a scope (item, place, and a variant or a lot where it has them), a quantity and at most 300 characters of reason'
      using errcode = 'DKG07';
  end if;
  v_obs := p_observed::numeric(18, 6);
  v_var := nullif(p_scope ->> 'variant_id', '')::uuid;
  v_lot := nullif(p_scope ->> 'lot_id', '')::uuid;
  v_digest := md5(jsonb_build_array(p_count_id, p_scope ->> 'item_id', v_var, v_lot, p_scope ->> 'location_id', v_obs, coalesce(p_reason, ''))::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_count', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtextextended('stock_count:' || p_workspace_id::text || ':' || p_count_id::text, 0));
  select * into v_first from public.stock_counts where workspace_id = p_workspace_id and count_id = p_count_id;
  if v_first.id is not null then
    if v_first.digest <> v_digest then
      raise exception 'this count was already recorded with other content' using errcode = 'DKG16';
    end if;
    return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_count', v_digest, jsonb_build_object(
      'count_id', v_first.count_id, 'state', v_first.state, 'baseline', v_first.baseline_quantity::text,
      'observed', v_first.observed_quantity::text, 'difference', (v_first.observed_quantity - v_first.baseline_quantity)::text));
  end if;

  -- the item first (as every stock command), then what the scope holds
  select * into v_item from public.services
   where id = (p_scope ->> 'item_id')::uuid and workspace_id = p_workspace_id and stockable for update;
  if v_item.id is null then raise exception 'not a stock item of this business' using errcode = 'DKG04'; end if;
  select * into v_loc from public.stock_locations
   where id = (p_scope ->> 'location_id')::uuid and workspace_id = p_workspace_id and active;
  if v_loc.id is null or public.stock_place_is_virtual(v_loc.id) or v_loc.id = public.stock_transit_place(p_workspace_id) then
    raise exception 'a count is taken at a real place of this business' using errcode = 'DKG05';
  end if;
  if v_var is not null and not exists (select 1 from public.item_variants x
       where x.id = v_var and x.workspace_id = p_workspace_id and x.item_id = v_item.id and x.active) then
    raise exception 'not a variant of this item' using errcode = 'DKG04';
  end if;
  if v_var is null and exists (select 1 from public.item_variants x where x.item_id = v_item.id and x.active) then
    raise exception 'this item has variants: name which one' using errcode = 'DKG12';
  end if;
  if v_lot is not null and not exists (select 1 from public.stock_lots l
       where l.id = v_lot and l.workspace_id = p_workspace_id and l.item_id = v_item.id and l.variant_id is not distinct from v_var) then
    raise exception 'the lot is not of this item' using errcode = 'DKG06';
  end if;
  if v_item.tracking <> 'none' and v_lot is null then
    raise exception 'this item is tracked by lot: a count names the lot' using errcode = 'DKG06';
  end if;
  v_base := public.stock_scope_on_hand(p_workspace_id, v_item.id, v_var, v_lot, v_loc.id);
  v_moves := public.stock_scope_moves(p_workspace_id, v_item.id, v_var, v_lot, v_loc.id);
  insert into public.stock_counts (workspace_id, count_id, item_id, variant_id, lot_id, location_id, observed_quantity,
                                   baseline_quantity, baseline_moves, reason, author_member_id, request_id, digest)
  values (p_workspace_id, p_count_id, v_item.id, v_var, v_lot, v_loc.id, v_obs, v_base, v_moves, coalesce(p_reason, ''), v_me, p_request_id, v_digest);
  v_result := jsonb_build_object('count_id', p_count_id, 'state', 'recorded', 'baseline', v_base::text,
    'observed', v_obs::text, 'difference', (v_obs - v_base)::text);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_count', v_digest, v_result);
end;
$fn$;
revoke execute on function public.stock_count_record_v1(uuid, uuid, uuid, jsonb, text, text) from public, anon;
grant execute on function public.stock_count_record_v1(uuid, uuid, uuid, jsonb, text, text) to authenticated;

-- ── deciding a count ───────────────────────────────────────────────────
-- decision: apply | reject | cancel. Apply and reject need approveStockAdjustments; a count is cancelled by
-- its author or by whoever may approve. Lock order: the item, then the count.
create or replace function public.stock_count_decide_v1(
  p_workspace_id uuid, p_request_id uuid, p_count_id uuid, p_decision text, p_note text default ''
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me public.members;
  v_can_approve boolean;
  v_peek public.stock_counts;
  v_c public.stock_counts;
  v_digest text;
  v_done jsonb;
  v_unit text;
  v_loss uuid;
  v_diff numeric;
  v_mid uuid;
  v_state text;
  v_part integer := 0;
  v_one uuid;
  t record;
  v_result jsonb;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed to decide a count' using errcode = 'DKN01';
  end if;
  select * into v_me from public.members where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_me.id is null then raise exception 'not allowed to decide a count' using errcode = 'DKN01'; end if;
  if not public.feature_effective(p_workspace_id, 'stockManagement') or not public.feature_effective(p_workspace_id, 'stockCounts') then
    raise exception 'counts are off in this business' using errcode = 'DKG01';
  end if;
  if p_request_id is null or p_count_id is null or p_decision is null or p_decision not in ('apply', 'reject', 'cancel')
     or char_length(coalesce(p_note, '')) > 300 then
    raise exception 'a decision has a request id, a count, apply, reject or cancel, and at most 300 characters of note' using errcode = 'DKG07';
  end if;
  v_can_approve := public.has_permission(p_workspace_id, 'approveStockAdjustments');
  select * into v_peek from public.stock_counts where workspace_id = p_workspace_id and count_id = p_count_id;
  -- the right first, without a lock
  if p_decision in ('apply', 'reject') and not v_can_approve then
    raise exception 'only someone who may approve adjustments decides a count' using errcode = 'DKN01';
  end if;
  if p_decision = 'cancel' and not (v_can_approve or (v_peek.id is not null and v_peek.author_member_id = v_me.id
                                                      and public.has_permission(p_workspace_id, 'manageStock'))) then
    raise exception 'a count is cancelled by its author or by someone who may approve adjustments' using errcode = 'DKN01';
  end if;
  if v_peek.id is null then raise exception 'not a count of this business' using errcode = 'DKG04'; end if;

  v_digest := md5(jsonb_build_array(p_count_id, p_decision, coalesce(p_note, ''))::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'stock_count_decide', v_digest);
  if v_done is not null then return v_done; end if;

  perform 1 from public.services where id = v_peek.item_id and workspace_id = p_workspace_id for update;
  select * into v_c from public.stock_counts where id = v_peek.id for update;
  v_state := case p_decision when 'apply' then 'applied' when 'reject' then 'rejected' else 'cancelled' end;
  if v_c.state <> 'recorded' then
    -- the same decision sent again answers what it decided; another decision of a decided count is refused
    if v_c.state = v_state then
      return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_count_decide', v_digest, jsonb_build_object(
        'count_id', v_c.count_id, 'state', v_c.state, 'movement_id', v_c.applied_movement_id,
        'difference', (v_c.observed_quantity - v_c.baseline_quantity)::text));
    end if;
    raise exception 'this count was already decided' using errcode = 'DKG19';
  end if;

  v_mid := null;
  if p_decision = 'apply' then
    -- whoever counted does not approve their own count while someone else may: a business of one approves its own
    if v_c.author_member_id = v_me.id and exists (
         select 1 from public.members m
          where m.workspace_id = p_workspace_id and m.status = 'active' and m.id <> v_me.id
            and public.member_has_permission(m.id, 'approveStockAdjustments')) then
      raise exception 'a count is approved by someone other than whoever counted it, since there is someone' using errcode = 'DKG21';
    end if;
    -- the stock moved since it was counted: nothing is overwritten, a fresh count is reviewed
    if public.stock_scope_moves(p_workspace_id, v_c.item_id, v_c.variant_id, v_c.lot_id, v_c.location_id) <> v_c.baseline_moves then
      raise exception 'the stock moved since it was counted: count it again' using errcode = 'DKG20';
    end if;
    v_diff := v_c.observed_quantity - v_c.baseline_quantity;
    if v_diff <> 0 then
      select inventory_unit into v_unit from public.services where id = v_c.item_id;
      v_loss := public.stock_place(p_workspace_id, 'loss');
      if v_diff > 0 then
        v_mid := public.stock_record(p_workspace_id, v_c.item_id, v_c.lot_id, v_loss, v_c.location_id, v_diff, v_unit, v_diff,
                                     now(), 'adjustment', v_me.id, p_request_id, 1, 1, '{}'::jsonb, v_c.variant_id);
      elsif v_c.lot_id is not null then
        v_mid := public.stock_record(p_workspace_id, v_c.item_id, v_c.lot_id, v_c.location_id, v_loss, -v_diff, v_unit, -v_diff,
                                     now(), 'adjustment', v_me.id, p_request_id, 1, 1, '{}'::jsonb, v_c.variant_id);
      else
        -- an item counted as a whole gives back what it holds across its lots, oldest first
        for t in select * from public.stock_take(p_workspace_id, v_c.item_id, v_c.location_id, -v_diff, v_c.variant_id) loop
          v_part := v_part + 1;
          v_one := public.stock_record(p_workspace_id, v_c.item_id, t.lot_id, v_c.location_id, v_loss, t.quantity,
                                       v_unit, t.quantity, now(), 'adjustment', v_me.id, p_request_id, 1, v_part, '{}'::jsonb, v_c.variant_id);
          v_mid := coalesce(v_mid, v_one);
        end loop;
      end if;
    end if;
  end if;
  update public.stock_counts
     set state = v_state, decided_by_member_id = v_me.id, decided_at = now(), decision_note = coalesce(p_note, ''),
         applied_movement_id = v_mid
   where id = v_c.id;
  v_result := jsonb_build_object('count_id', v_c.count_id, 'state', v_state, 'movement_id', v_mid,
    'difference', (v_c.observed_quantity - v_c.baseline_quantity)::text);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'stock_count_decide', v_digest, v_result);
end;
$fn$;
revoke execute on function public.stock_count_decide_v1(uuid, uuid, uuid, text, text) from public, anon;
grant execute on function public.stock_count_decide_v1(uuid, uuid, uuid, text, text) to authenticated;

-- ── reading the counts ─────────────────────────────────────────────────
-- Each count with whether its scope has moved since (a recorded count that is stale cannot be applied).
create or replace function public.stock_counts_v1(p_workspace_id uuid, p_state text default null)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null or public.mcp_is_delegated() or not public.is_member_of(p_workspace_id)
     or not (public.has_permission(p_workspace_id, 'viewStock') or public.has_permission(p_workspace_id, 'manageStock')
             or public.has_permission(p_workspace_id, 'approveStockAdjustments')) then
    raise exception 'not allowed to read the counts' using errcode = 'DKN01';
  end if;
  if not public.feature_effective(p_workspace_id, 'stockCounts') then
    raise exception 'counts are off in this business' using errcode = 'DKG01';
  end if;
  if p_state is not null and p_state not in ('recorded', 'applied', 'rejected', 'cancelled') then
    raise exception 'a state is recorded, applied, rejected or cancelled' using errcode = 'DKG07';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'count_id', c.count_id, 'item_id', c.item_id, 'variant_id', c.variant_id, 'lot_id', c.lot_id,
      'location_id', c.location_id, 'observed', c.observed_quantity::text, 'baseline', c.baseline_quantity::text,
      'difference', (c.observed_quantity - c.baseline_quantity)::text, 'state', c.state, 'reason', c.reason,
      'author_member_id', c.author_member_id, 'decided_by_member_id', c.decided_by_member_id,
      'decided_at', c.decided_at, 'movement_id', c.applied_movement_id,
      'stale', c.state = 'recorded'
               and public.stock_scope_moves(c.workspace_id, c.item_id, c.variant_id, c.lot_id, c.location_id) <> c.baseline_moves)
      order by c.created_datetime, c.id)
      from public.stock_counts c
     where c.workspace_id = p_workspace_id and (p_state is null or c.state = p_state)
  ), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.stock_counts_v1(uuid, text) from public, anon;
grant execute on function public.stock_counts_v1(uuid, text) to authenticated;

-- the workspace export carries the counts (#2860): 0866's function restated
-- restates 0866
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
    -- #4172 the returns, and what each line reversed
    'stock_returns', 'stock_reversals',
    -- #4172 the counts and their decisions
    'stock_counts',
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

select public.set_deskilo_schema_version(869);
