-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0491 (#2576, C1) -- the equipment register.
--
-- A purchase line that someone classified as long-lasting equipment
-- (`recognition_kind = 'asset'`) can be registered as an asset CANDIDATE: a
-- row that points at the line (the source document is never copied) and holds
-- the acquisition cost as the line gives it -- gross minus the recoverable
-- input tax, i.e. the net plus the tax that is not recovered; unknown (null)
-- while the deductible share is not qualified, never a guessed zero. An
-- authorised reviewer (`manageBilling` with `viewFinances`) then DECIDES:
-- capitalise or expense, with the basis, and (to put it in use) the date it was
-- available for use. Nothing is inferred: no date, no useful life, no policy.
--
--   register_asset_candidate_v1   managePurchases: suggest equipment on a line
--   decide_asset_v1               manageBilling + viewFinances: the treatment
--   workspace_assets_v1           viewFinances / manageBilling / managePurchases
--
-- The register is a record of acquisitions and evidence. Statutory book
-- depreciation, tax allowances and impairment stay with the accountant (C2
-- imports their figures as a read model); nothing here posts to a ledger.

create table public.workspace_assets (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  asset_number int not null check (asset_number >= 1),
  description text not null check (char_length(description) between 1 and 200),
  purchase_line_id uuid not null references public.purchase_lines(id),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  acquisition_cost_cents bigint check (acquisition_cost_cents is null or acquisition_cost_cents >= 0),
  decision text not null default 'pending' check (decision in ('pending', 'capitalise', 'expense')),
  decision_basis text not null default '' check (char_length(decision_basis) <= 300),
  state text not null default 'candidate' check (state in ('candidate', 'in_use', 'disposed', 'expensed')),
  available_for_use_on date,
  site_id uuid,
  custodian_member_id uuid references public.members(id),
  external_asset_id text not null default '' check (char_length(external_asset_id) <= 100),
  decided_by_member_id uuid references public.members(id),
  decided_at timestamptz,
  revision int not null default 1 check (revision >= 1),
  created_by_member_id uuid references public.members(id),
  unique (workspace_id, asset_number),
  unique (purchase_line_id),
  check ((decision = 'pending') = (decided_at is null)),
  check (state <> 'in_use' or (decision = 'capitalise' and available_for_use_on is not null)),
  check (decision <> 'pending' or state = 'candidate'),
  check ((state = 'expensed') = (decision = 'expense'))
);
select public.ensure_system_columns('workspace_assets');
create index workspace_assets_workspace on public.workspace_assets (workspace_id, state);

alter table public.workspace_assets enable row level security;
revoke all on public.workspace_assets from public, anon, authenticated;
grant select on public.workspace_assets to authenticated;
create policy workspace_assets_select on public.workspace_assets
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageBilling', 'managePurchases'])));
create policy mcp_delegated_deny on public.workspace_assets as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the member behind a call, with the register's flag and rights checked ──
create or replace function public.asset_actor(p_workspace_id uuid, p_review boolean)
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
  if p_review then
    if not (public.has_permission(p_workspace_id, 'manageBilling')
            and public.has_permission(p_workspace_id, 'viewFinances')) then
      raise exception 'you may not decide the accounting treatment of equipment';
    end if;
  elsif not public.has_permission(p_workspace_id, 'managePurchases') then
    raise exception 'you may not register equipment';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.asset_actor(uuid, boolean) from public, anon, authenticated;

-- ── the reading ───────────────────────────────────────────────────────────
create or replace function public.workspace_asset_json(a public.workspace_assets)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'id', a.id, 'revision', a.revision, 'asset_number', a.asset_number,
    'description', a.description, 'currency', a.currency,
    'acquisition_cost_cents', a.acquisition_cost_cents,
    'purchase_id', d.id, 'line_no', l.line_no, 'line_gross_cents', l.gross_cents,
    'supplier_name', (select s.name from public.suppliers s
                       where s.workspace_id = a.workspace_id and s.id = d.supplier_id),
    'original_reference', d.original_reference, 'original_date', d.original_date,
    'decision', a.decision, 'decision_basis', a.decision_basis, 'state', a.state,
    'available_for_use_on', a.available_for_use_on, 'site_id', a.site_id,
    'custodian_member_id', a.custodian_member_id, 'external_asset_id', a.external_asset_id,
    'decided_at', a.decided_at)
    from public.purchase_lines l
    join public.purchase_documents d on d.id = l.purchase_id and d.workspace_id = l.workspace_id
   where l.id = a.purchase_line_id and l.workspace_id = a.workspace_id;
$fn$;
revoke execute on function public.workspace_asset_json(public.workspace_assets) from public, anon, authenticated;

create or replace function public.workspace_assets_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not exists (select 1 from public.members m
                  where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active') then
    raise exception 'not an active member';
  end if;
  if not public.feature_effective(p_workspace_id, 'assetRegister') then
    raise exception 'the equipment register is switched off in this space';
  end if;
  if not (public.has_permission(p_workspace_id, 'viewFinances')
          or public.has_permission(p_workspace_id, 'manageBilling')
          or public.has_permission(p_workspace_id, 'managePurchases')) then
    raise exception 'you may not read the equipment register';
  end if;
  return jsonb_build_object('assets', coalesce((
    select jsonb_agg(public.workspace_asset_json(a) order by a.asset_number)
      from public.workspace_assets a where a.workspace_id = p_workspace_id), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.workspace_assets_v1(uuid) from public, anon;
grant execute on function public.workspace_assets_v1(uuid) to authenticated;

-- ── suggest equipment on a purchase line ─────────────────────────────────
create or replace function public.register_asset_candidate_v1(
  p_workspace_id uuid, p_purchase_line_id uuid, p_description text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  l public.purchase_lines;
  d public.purchase_documents;
  a public.workspace_assets;
  v_description text := btrim(coalesce(p_description, ''));
  v_cost bigint;
  v_result jsonb;
begin
  v_me := public.asset_actor(p_workspace_id, false);
  v_digest := md5(v_me::text || coalesce(p_purchase_line_id::text, '') || v_description);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'asset_register', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));

  select * into l from public.purchase_lines
   where id = p_purchase_line_id and workspace_id = p_workspace_id;
  if l.id is null then raise exception 'unknown purchase line'; end if;
  select * into d from public.purchase_documents
   where id = l.purchase_id and workspace_id = p_workspace_id;
  if d.state in ('rejected', 'cancelled') then
    raise exception 'a rejected or cancelled purchase registers no equipment';
  end if;
  if l.recognition_kind <> 'asset' then
    raise exception 'the line is not classified as long-lasting equipment';
  end if;
  if v_description = '' then v_description := left(btrim(l.description), 200); end if;
  if v_description = '' then raise exception 'name the equipment'; end if;
  if exists (select 1 from public.workspace_assets x where x.purchase_line_id = l.id) then
    raise exception 'this line is already registered';
  end if;
  -- Net plus the tax that is not recovered; unknown while the deductible
  -- share is not qualified.
  v_cost := case when l.recoverable_tax_cents is null then null
                 else l.gross_cents - l.recoverable_tax_cents end;

  insert into public.workspace_assets
    (workspace_id, asset_number, description, purchase_line_id, currency, acquisition_cost_cents, created_by_member_id)
  values (p_workspace_id,
          coalesce((select max(x.asset_number) from public.workspace_assets x where x.workspace_id = p_workspace_id), 0) + 1,
          left(v_description, 200), l.id, d.currency, v_cost, v_me)
  returning * into a;

  v_result := public.workspace_asset_json(a);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'asset_register', v_digest, v_result);
end;
$fn$;
revoke execute on function public.register_asset_candidate_v1(uuid, uuid, text, uuid) from public, anon;
grant execute on function public.register_asset_candidate_v1(uuid, uuid, text, uuid) to authenticated;

-- ── the accounting treatment ─────────────────────────────────────────────
create or replace function public.decide_asset_v1(
  p_workspace_id uuid, p_asset_id uuid, p_revision int, p_decision text, p_basis text,
  p_available_for_use_on date, p_site_id uuid, p_custodian_member_id uuid,
  p_external_asset_id text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  a public.workspace_assets;
  v_basis text := btrim(coalesce(p_basis, ''));
  v_result jsonb;
begin
  v_me := public.asset_actor(p_workspace_id, true);
  v_digest := md5(v_me::text || coalesce(p_asset_id::text, '') || coalesce(p_revision, 0)::text
                  || coalesce(p_decision, '') || v_basis || coalesce(p_available_for_use_on::text, '')
                  || coalesce(p_site_id::text, '') || coalesce(p_custodian_member_id::text, '')
                  || coalesce(p_external_asset_id, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'asset_decide', v_digest);
  if v_done is not null then return v_done; end if;
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));

  select * into a from public.workspace_assets
   where id = p_asset_id and workspace_id = p_workspace_id for update;
  if a.id is null then raise exception 'unknown asset'; end if;
  if a.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if a.state in ('in_use', 'expensed', 'disposed') then
    raise exception 'a decided asset is corrected in the open period, not here';
  end if;
  if coalesce(p_decision, '') not in ('capitalise', 'expense') then
    raise exception 'capitalise or expense';
  end if;
  if v_basis = '' then raise exception 'state the basis of the decision'; end if;
  if p_decision = 'capitalise' and a.acquisition_cost_cents is null then
    raise exception 'qualify the deductible share of the purchase before capitalising it';
  end if;
  if p_decision = 'expense' and p_available_for_use_on is not null then
    raise exception 'an expensed item has no date of availability for use';
  end if;
  if p_site_id is not null and not exists (select 1 from public.sites s
                                            where s.id = p_site_id and s.workspace_id = p_workspace_id) then
    raise exception 'unknown site';
  end if;
  if p_custodian_member_id is not null and not exists (
       select 1 from public.members m
        where m.id = p_custodian_member_id and m.workspace_id = p_workspace_id and m.status = 'active') then
    raise exception 'the custodian must be an active member of this space';
  end if;

  update public.workspace_assets
     set decision = p_decision, decision_basis = left(v_basis, 300),
         state = case p_decision
                   when 'expense' then 'expensed'
                   when 'capitalise' then case when p_available_for_use_on is null then 'candidate' else 'in_use' end
                 end,
         available_for_use_on = p_available_for_use_on, site_id = p_site_id,
         custodian_member_id = p_custodian_member_id,
         external_asset_id = left(btrim(coalesce(p_external_asset_id, '')), 100),
         decided_by_member_id = v_me, decided_at = now(), revision = revision + 1
   where id = a.id and workspace_id = p_workspace_id
  returning * into a;

  v_result := public.workspace_asset_json(a);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'asset_decide', v_digest, v_result);
end;
$fn$;
revoke execute on function public.decide_asset_v1(uuid, uuid, int, text, text, date, uuid, uuid, text, uuid)
  from public, anon;
grant execute on function public.decide_asset_v1(uuid, uuid, int, text, text, date, uuid, uuid, text, uuid)
  to authenticated;

select public.set_deskilo_schema_version(491);
