-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0500 (#2576, C2a) -- the accountant's valuations of the equipment, as a read
-- model.
--
-- The statutory book depreciation, tax allowances and impairment are the
-- accountant's. A BATCH is what they send for one basis (`book` or `tax`) and
-- one period; its ROWS give, per registered asset, opening value, additions,
-- disposals, depreciation, impairment and closing value in exact minor units.
-- A blank figure is UNKNOWN, never zero. Nothing here posts anything: the
-- values are evidence next to the register and are never re-exported as new
-- purchase or depreciation postings.
--
--   stage_asset_valuations_v1    manageBilling + viewFinances: validate, store as staged
--   confirm_asset_valuations_v1  the same: make a staged batch the evidence of its period
--   asset_valuations_page_v1     viewFinances / manageBilling: batches, or one batch's rows
--
-- A batch is identified by its source hash: staging the same bytes again
-- answers the same batch. Movements are stated as `period` or `ytd` (year to
-- date) and kept as stated; nothing sums overlapping rows. Confirming a batch
-- whose basis, currency and period overlap a confirmed one for the same asset
-- is refused unless it names the batch it supersedes, with a reason; the older
-- batch is kept, marked superseded.

create table public.asset_valuation_batches (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  basis text not null check (basis in ('book', 'tax')),
  source_system text not null check (char_length(btrim(source_system)) between 1 and 100),
  source_reference text not null default '' check (char_length(source_reference) <= 200),
  source_hash text not null check (source_hash ~ '^[0-9a-f]{64}$'),
  period_from date not null,
  period_to date not null,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  movements text not null check (movements in ('period', 'ytd')),
  complete_scope boolean not null,
  status text not null default 'staged' check (status in ('staged', 'confirmed', 'superseded')),
  supersedes uuid references public.asset_valuation_batches(id),
  reason text not null default '' check (char_length(reason) <= 300),
  revision int not null default 1 check (revision >= 1),
  created_by_member_id uuid references public.members(id),
  reviewed_by_member_id uuid references public.members(id),
  reviewed_at timestamptz,
  check (period_to >= period_from),
  check ((status = 'staged') = (reviewed_at is null)),
  unique (workspace_id, source_hash, basis)
);
select public.ensure_system_columns('asset_valuation_batches');
create index asset_valuation_batches_workspace
  on public.asset_valuation_batches (workspace_id, basis, status, period_from);

create table public.asset_valuation_rows (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  batch_id uuid not null references public.asset_valuation_batches(id) on delete cascade,
  asset_id uuid not null references public.workspace_assets(id),
  external_reference text not null default '' check (char_length(external_reference) <= 100),
  opening_minor bigint,
  additions_minor bigint,
  disposals_minor bigint,
  depreciation_minor bigint,
  impairment_minor bigint,
  closing_minor bigint,
  unique (batch_id, asset_id),
  check (closing_minor is null or closing_minor >= 0),
  check (opening_minor is null or opening_minor >= 0)
);
select public.ensure_system_columns('asset_valuation_rows');
create index asset_valuation_rows_asset on public.asset_valuation_rows (asset_id);

alter table public.asset_valuation_batches enable row level security;
alter table public.asset_valuation_rows enable row level security;
revoke all on public.asset_valuation_batches, public.asset_valuation_rows from public, anon, authenticated;
grant select on public.asset_valuation_batches, public.asset_valuation_rows to authenticated;
create policy asset_valuation_batches_select on public.asset_valuation_batches
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageBilling'])));
create policy asset_valuation_rows_select on public.asset_valuation_rows
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageBilling'])));
create policy mcp_delegated_deny on public.asset_valuation_batches as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.asset_valuation_rows as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── who may stage and confirm ─────────────────────────────────────────────
create or replace function public.valuation_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare v_me uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'assetRegister') then
    raise exception 'the equipment register is switched off in this space';
  end if;
  if not (public.has_permission(p_workspace_id, 'manageBilling')
          and public.has_permission(p_workspace_id, 'viewFinances')) then
    raise exception 'you may not import valuations';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.valuation_actor(uuid) from public, anon, authenticated;

-- The six figures of a row bridge when the opening plus additions less
-- disposals, depreciation and impairment is the closing; null while any
-- figure is unknown.
create or replace function public.valuation_bridge(r public.asset_valuation_rows)
returns text language sql immutable set search_path = public as $fn$
  select case
    when r.opening_minor is null or r.additions_minor is null or r.disposals_minor is null
      or r.depreciation_minor is null or r.impairment_minor is null or r.closing_minor is null then 'unknown'
    when r.opening_minor + r.additions_minor - r.disposals_minor - r.depreciation_minor - r.impairment_minor
         = r.closing_minor then 'ok'
    else 'mismatch' end;
$fn$;
revoke execute on function public.valuation_bridge(public.asset_valuation_rows) from public, anon, authenticated;

create or replace function public.valuation_batch_json(b public.asset_valuation_batches)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'id', b.id, 'revision', b.revision, 'basis', b.basis, 'source_system', b.source_system,
    'source_reference', b.source_reference, 'source_hash', b.source_hash,
    'period_from', b.period_from, 'period_to', b.period_to, 'currency', b.currency,
    'movements', b.movements, 'complete_scope', b.complete_scope, 'status', b.status,
    'supersedes', b.supersedes, 'reason', b.reason, 'reviewed_at', b.reviewed_at,
    'rows', (select count(*) from public.asset_valuation_rows r where r.batch_id = b.id),
    'mismatches', (select count(*) from public.asset_valuation_rows r
                    where r.batch_id = b.id and public.valuation_bridge(r) = 'mismatch'));
$fn$;
revoke execute on function public.valuation_batch_json(public.asset_valuation_batches) from public, anon, authenticated;

-- ── stage ─────────────────────────────────────────────────────────────────
-- metadata: {basis, source_system, source_reference, source_hash, period_from,
--            period_to, currency, movements, complete_scope}
-- rows: [{asset_number, external_reference, opening_minor, ... closing_minor}]
-- A blank figure is null. At most 2000 rows a batch (one row per asset).
create or replace function public.stage_asset_valuations_v1(
  p_workspace_id uuid, p_request_id uuid, p_metadata jsonb, p_rows jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  b public.asset_valuation_batches;
  e jsonb;
  v_asset public.workspace_assets;
  v_n int := 0;
  v_basis text := p_metadata->>'basis';
  v_hash text := lower(coalesce(p_metadata->>'source_hash', ''));
  v_currency text := upper(coalesce(p_metadata->>'currency', ''));
  v_result jsonb;
begin
  v_me := public.valuation_actor(p_workspace_id);
  v_digest := md5(v_me::text || coalesce(p_metadata::text, '') || coalesce(p_rows::text, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'asset_valuation_stage', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtext('asset-valuations:' || p_workspace_id));

  if jsonb_typeof(p_metadata) <> 'object' or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'the batch is a description and a list of rows';
  end if;
  if jsonb_array_length(p_rows) not between 1 and 2000 then
    raise exception 'a batch has between 1 and 2000 rows';
  end if;
  if v_basis not in ('book', 'tax') then raise exception 'the basis is book or tax'; end if;
  if coalesce(p_metadata->>'movements', '') not in ('period', 'ytd') then
    raise exception 'say whether the movements are for the period or year to date';
  end if;
  if v_hash !~ '^[0-9a-f]{64}$' then raise exception 'the source hash is a sha-256 in hex'; end if;
  if v_currency !~ '^[A-Z]{3}$' then raise exception 'the currency is a three-letter code'; end if;
  if jsonb_typeof(p_metadata->'complete_scope') is distinct from 'boolean' then
    raise exception 'say whether the batch covers every asset';
  end if;
  if coalesce(btrim(p_metadata->>'source_system'), '') = '' then
    raise exception 'name the accountant or the system the figures come from';
  end if;
  if (p_metadata->>'period_to')::date < (p_metadata->>'period_from')::date then
    raise exception 'the period ends before it starts';
  end if;

  -- The same source bytes for the same basis answer the batch already held.
  select * into b from public.asset_valuation_batches
   where workspace_id = p_workspace_id and source_hash = v_hash and basis = v_basis;
  if b.id is not null then
    v_result := public.valuation_batch_json(b);
    return public.purchase_request_end(p_workspace_id, p_request_id, 'asset_valuation_stage', v_digest, v_result);
  end if;

  insert into public.asset_valuation_batches
    (workspace_id, basis, source_system, source_reference, source_hash, period_from, period_to,
     currency, movements, complete_scope, created_by_member_id)
  values (p_workspace_id, v_basis, btrim(p_metadata->>'source_system'),
          coalesce(p_metadata->>'source_reference', ''), v_hash,
          (p_metadata->>'period_from')::date, (p_metadata->>'period_to')::date,
          v_currency, p_metadata->>'movements', (p_metadata->>'complete_scope')::boolean, v_me)
  returning * into b;

  for e in select * from jsonb_array_elements(p_rows) loop
    v_n := v_n + 1;
    select * into v_asset from public.workspace_assets a
     where a.workspace_id = p_workspace_id and a.asset_number = (e->>'asset_number')::int;
    if v_asset.id is null then
      raise exception 'row %: unknown asset number %', v_n, e->>'asset_number';
    end if;
    if v_asset.currency <> v_currency then
      raise exception 'row %: the asset is in %, the batch in %', v_n, v_asset.currency, v_currency;
    end if;
    if exists (select 1 from public.asset_valuation_rows x where x.batch_id = b.id and x.asset_id = v_asset.id) then
      raise exception 'row %: the asset appears twice in the batch', v_n;
    end if;
    insert into public.asset_valuation_rows
      (workspace_id, batch_id, asset_id, external_reference, opening_minor, additions_minor,
       disposals_minor, depreciation_minor, impairment_minor, closing_minor)
    values (p_workspace_id, b.id, v_asset.id, coalesce(e->>'external_reference', ''),
            (e->>'opening_minor')::bigint, (e->>'additions_minor')::bigint,
            (e->>'disposals_minor')::bigint, (e->>'depreciation_minor')::bigint,
            (e->>'impairment_minor')::bigint, (e->>'closing_minor')::bigint);
  end loop;

  v_result := public.valuation_batch_json(b);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'asset_valuation_stage', v_digest, v_result);
end;
$fn$;
revoke execute on function public.stage_asset_valuations_v1(uuid, uuid, jsonb, jsonb) from public, anon;
grant execute on function public.stage_asset_valuations_v1(uuid, uuid, jsonb, jsonb) to authenticated;

-- ── confirm ───────────────────────────────────────────────────────────────
create or replace function public.confirm_asset_valuations_v1(
  p_workspace_id uuid, p_batch_id uuid, p_revision int, p_supersedes uuid, p_reason text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  b public.asset_valuation_batches;
  o public.asset_valuation_batches;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_overlap uuid[];
  v_result jsonb;
begin
  v_me := public.valuation_actor(p_workspace_id);
  v_digest := md5(v_me::text || coalesce(p_batch_id::text, '') || coalesce(p_revision::text, '')
                  || coalesce(p_supersedes::text, '') || v_reason);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'asset_valuation_confirm', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtext('asset-valuations:' || p_workspace_id));

  select * into b from public.asset_valuation_batches
   where id = p_batch_id and workspace_id = p_workspace_id for update;
  if b.id is null then raise exception 'unknown batch'; end if;
  if b.revision <> p_revision then raise exception 'the batch changed meanwhile'; end if;
  if b.status <> 'staged' then raise exception 'only a staged batch is confirmed'; end if;
  if exists (select 1 from public.asset_valuation_rows r where r.batch_id = b.id
              and public.valuation_bridge(r) = 'mismatch') then
    raise exception 'a row does not balance: opening plus additions less disposals, depreciation and impairment is not the closing value';
  end if;

  -- Confirmed batches of the same basis and currency whose period overlaps and
  -- that value one of the same assets.
  select coalesce(array_agg(distinct x.id), '{}') into v_overlap
    from public.asset_valuation_batches x
   where x.workspace_id = p_workspace_id and x.id <> b.id and x.status = 'confirmed'
     and x.basis = b.basis and x.currency = b.currency
     and daterange(x.period_from, x.period_to, '[]') && daterange(b.period_from, b.period_to, '[]')
     and exists (select 1 from public.asset_valuation_rows xr
                   join public.asset_valuation_rows br on br.asset_id = xr.asset_id and br.batch_id = b.id
                  where xr.batch_id = x.id);
  if cardinality(v_overlap) > 0 then
    if p_supersedes is null or v_overlap <> array[p_supersedes] then
      raise exception 'a confirmed batch already values some of these assets in this period; name it and say why it is replaced';
    end if;
    if v_reason = '' then raise exception 'say why the earlier batch is replaced'; end if;
    update public.asset_valuation_batches set status = 'superseded', revision = revision + 1
     where id = p_supersedes returning * into o;
  elsif p_supersedes is not null then
    raise exception 'there is no overlapping batch to replace';
  end if;

  update public.asset_valuation_batches
     set status = 'confirmed', revision = revision + 1, supersedes = p_supersedes, reason = v_reason,
         reviewed_by_member_id = v_me, reviewed_at = now()
   where id = b.id returning * into b;

  v_result := public.valuation_batch_json(b);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'asset_valuation_confirm', v_digest, v_result);
end;
$fn$;
revoke execute on function public.confirm_asset_valuations_v1(uuid, uuid, int, uuid, text, uuid) from public, anon;
grant execute on function public.confirm_asset_valuations_v1(uuid, uuid, int, uuid, text, uuid) to authenticated;

-- ── read ──────────────────────────────────────────────────────────────────
-- filters: {batch_id?, basis?, status?}. Without batch_id the batches (newest
-- period first, then id), 50 a page by cursor = the last id; with it the rows
-- of that batch with the bridge verdict of each. Unknown figures stay null.
create or replace function public.asset_valuations_page_v1(
  p_workspace_id uuid, p_filters jsonb, p_cursor uuid
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_batch uuid := nullif(p_filters->>'batch_id', '')::uuid;
  v_basis text := nullif(p_filters->>'basis', '');
  v_status text := nullif(p_filters->>'status', '');
  v_items jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not exists (select 1 from public.members m
                  where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active') then
    raise exception 'not an active member';
  end if;
  if not public.feature_effective(p_workspace_id, 'assetRegister') then
    raise exception 'the equipment register is switched off in this space';
  end if;
  if not (public.has_permission(p_workspace_id, 'viewFinances') or public.has_permission(p_workspace_id, 'manageBilling')) then
    raise exception 'you may not read valuations';
  end if;
  if v_batch is not null then
    return jsonb_build_object('batch',
      (select public.valuation_batch_json(b) from public.asset_valuation_batches b
        where b.id = v_batch and b.workspace_id = p_workspace_id),
      'rows', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'asset_id', r.asset_id, 'asset_number', a.asset_number, 'description', a.description,
                 'external_reference', r.external_reference,
                 'opening_minor', r.opening_minor, 'additions_minor', r.additions_minor,
                 'disposals_minor', r.disposals_minor, 'depreciation_minor', r.depreciation_minor,
                 'impairment_minor', r.impairment_minor, 'closing_minor', r.closing_minor,
                 'bridge', public.valuation_bridge(r)) order by a.asset_number)
          from public.asset_valuation_rows r join public.workspace_assets a on a.id = r.asset_id
         where r.batch_id = v_batch and r.workspace_id = p_workspace_id), '[]'::jsonb));
  end if;
  select coalesce(jsonb_agg(public.valuation_batch_json(q) order by q.id), '[]'::jsonb) into v_items
    from (select b.* from public.asset_valuation_batches b
           where b.workspace_id = p_workspace_id
             and (v_basis is null or b.basis = v_basis)
             and (v_status is null or b.status = v_status)
             and (p_cursor is null or b.id > p_cursor)
           order by b.id
           limit 50) q;
  return jsonb_build_object('batches', v_items);
end;
$fn$;
revoke execute on function public.asset_valuations_page_v1(uuid, jsonb, uuid) from public, anon;
grant execute on function public.asset_valuations_page_v1(uuid, jsonb, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(500);
