-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0461 (#2573, C1 of #2464) -- ONE purchase document for supplier bills and
-- member expenses.
--
--   * `purchase_documents` / `purchase_lines` / `purchase_sources`: the
--     document, its exact integer lines, and the evidence that funds it. A
--     source (an expense event, an inbox invoice, ...) can fund ONE purchase
--     (`unique (workspace_id, source_kind, source_id)`). Every foreign key
--     between them is workspace-qualified, so equal ids in two workspaces
--     never meet.
--   * The expense event stays the money authority. An approved member outlay
--     already issued its running-account credit; this file only LINKS a
--     document to that event. Nothing here writes a ledger row, a VAT
--     return line or a payment. Old clients keep calling `submit_expense`:
--     an AFTER INSERT trigger on `events` files the same document for them,
--     and an AFTER UPDATE trigger follows the validation outcome, so the
--     purchase is approved / rejected by the existing expense validation and
--     never by a second engine.
--   * Backfill: every existing expense event gets its document
--     (`legacy_unverified`), with the original amount, VAT payload and asset
--     flag kept as written. Unknown tax stays NULL (not zero); the legacy
--     decision timestamp is kept as provenance, never as a tax point. The
--     backfill and the trigger share ONE function and are idempotent.
--   * RPCs: `save_purchase_draft_v1`, `submit_purchase_v1`,
--     `link_purchase_source_v1`, `purchase_detail_v1`. Totals, actor and
--     state are derived here, never read from the client. Each write takes a
--     request id: the same id with the same arguments returns the committed
--     result, a changed argument is refused.
--   * Submitting a MEMBER receipt files the expense through `submit_expense`
--     itself (one event, one later credit). Submitting a supplier bill or a
--     credit note is refused here: the payable it creates belongs to the
--     obligations checkpoint (#2574); a bill is captured, linked and read.
--
-- Read: the submitting member; viewFinances / managePurchases for the
-- workspace. Write: only through the RPCs. Bills: managePurchases while
-- `purchases` is on.

-- ── supplier identity for the composite key ────────────────────────────
create unique index suppliers_workspace_id_id_key
  on public.suppliers (workspace_id, id);

-- ── tables ─────────────────────────────────────────────────────────────
create table public.purchase_documents (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  kind text not null check (kind in ('bill', 'credit_note', 'member_receipt')),
  state text not null default 'draft'
    check (state in ('draft', 'pending', 'approved', 'rejected', 'cancelled')),
  revision int not null default 1 check (revision >= 1),
  supplier_id uuid,
  original_reference text not null default '' check (char_length(original_reference) <= 200),
  original_date date,
  received_on date,
  service_from date,
  service_to date,
  due_on date,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  category text not null default '' check (char_length(category) <= 80),
  submitter_member_id uuid not null,
  payer_kind text not null check (payer_kind in ('workspace', 'member', 'unpaid')),
  payer_member_id uuid,
  supplier_snapshot jsonb,
  recipient_snapshot jsonb,
  approved_event_id uuid references public.events(id),
  original_document_id uuid,
  classification_status text not null default 'unreviewed'
    check (classification_status in ('unreviewed', 'reviewed', 'legacy')),
  legacy_qualification text not null default 'none'
    check (legacy_qualification in ('none', 'legacy_unverified')),
  legacy_decided_at timestamptz,
  unique (workspace_id, id),
  foreign key (workspace_id, supplier_id) references public.suppliers (workspace_id, id),
  foreign key (workspace_id, submitter_member_id) references public.members (workspace_id, id),
  foreign key (workspace_id, payer_member_id) references public.members (workspace_id, id),
  foreign key (workspace_id, original_document_id)
    references public.purchase_documents (workspace_id, id),
  check ((payer_kind = 'member') = (payer_member_id is not null)),
  check (kind <> 'member_receipt' or payer_kind = 'member'),
  check (kind = 'credit_note' or original_document_id is null),
  check (service_from is null or service_to is null or service_to >= service_from),
  check ((state = 'approved') = (approved_event_id is not null))
);
select public.ensure_system_columns('purchase_documents');
create index purchase_documents_workspace
  on public.purchase_documents (workspace_id, state, kind);
create index purchase_documents_submitter
  on public.purchase_documents (submitter_member_id);

create table public.purchase_lines (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  purchase_id uuid not null,
  line_no int not null check (line_no >= 1),
  description text not null default '' check (char_length(description) <= 500),
  quantity numeric(18, 6) not null default 1 check (quantity > 0),
  unit text not null default '' check (char_length(unit) <= 20),
  -- Exact integer money. NULL net/tax = the document did not say (partial,
  -- never zero); a stated zero is a valid, distinct value.
  net_cents bigint check (net_cents is null or net_cents >= 0),
  tax_cents bigint check (tax_cents is null or tax_cents >= 0),
  gross_cents bigint not null check (gross_cents >= 0),
  tax_rate_percent numeric(7, 4)
    check (tax_rate_percent is null or (tax_rate_percent >= 0 and tax_rate_percent <= 100)),
  -- NULL = the deductible share is not qualified yet (review, not 100 %).
  recoverable_tax_cents bigint check (recoverable_tax_cents is null or recoverable_tax_cents >= 0),
  nonrecoverable_tax_cents bigint
    check (nonrecoverable_tax_cents is null or nonrecoverable_tax_cents >= 0),
  tax_component_keys text[] not null default '{}',
  supply jsonb,
  recognition_kind text not null default 'unresolved'
    check (recognition_kind in
      ('operating', 'asset', 'stock', 'prepayment', 'deposit', 'unresolved')),
  foreign key (workspace_id, purchase_id)
    references public.purchase_documents (workspace_id, id) on delete cascade,
  unique (purchase_id, line_no),
  check ((net_cents is null) = (tax_cents is null)),
  check (net_cents is null or net_cents + tax_cents = gross_cents),
  check ((recoverable_tax_cents is null) = (nonrecoverable_tax_cents is null)),
  check (recoverable_tax_cents is null
         or (tax_cents is not null
             and recoverable_tax_cents + nonrecoverable_tax_cents = tax_cents))
);
select public.ensure_system_columns('purchase_lines');

create table public.purchase_sources (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  purchase_id uuid not null,
  source_kind text not null check (source_kind in ('expense_event', 'inbox', 'occurrence', 'manual')),
  source_id uuid not null,
  role text not null default 'evidence' check (role in ('origin', 'evidence')),
  original_hash text not null default ''
    check (original_hash = '' or original_hash ~ '^[0-9a-f]{64}$'),
  original_reference text not null default '' check (char_length(original_reference) <= 200),
  linked_by uuid,
  foreign key (workspace_id, purchase_id)
    references public.purchase_documents (workspace_id, id) on delete cascade,
  foreign key (workspace_id, linked_by) references public.members (workspace_id, id),
  unique (workspace_id, source_kind, source_id)
);
select public.ensure_system_columns('purchase_sources');
create index purchase_sources_purchase on public.purchase_sources (purchase_id);

-- The committed result of a write, by request id: a replay returns it, a
-- changed argument under the same id is refused.
create table public.purchase_requests (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  request_id uuid not null,
  operation text not null,
  digest text not null,
  result jsonb not null,
  unique (workspace_id, request_id)
);
select public.ensure_system_columns('purchase_requests');

-- ── row level security ─────────────────────────────────────────────────
alter table public.purchase_documents enable row level security;
revoke all on public.purchase_documents from public, anon, authenticated;
grant select on public.purchase_documents to authenticated;
create policy purchase_documents_select on public.purchase_documents
  for select to authenticated
  using (
    workspace_id in (select public.workspaces_permitting(array['viewFinances', 'managePurchases']))
    or submitter_member_id in (
      select m.id from public.members m where m.user_id = (select auth.uid()) and m.status = 'active')
  );
create policy mcp_delegated_deny on public.purchase_documents as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.purchase_lines enable row level security;
revoke all on public.purchase_lines from public, anon, authenticated;
grant select on public.purchase_lines to authenticated;
create policy purchase_lines_select on public.purchase_lines
  for select to authenticated
  using (exists (
    select 1 from public.purchase_documents d
     where d.workspace_id = purchase_lines.workspace_id and d.id = purchase_lines.purchase_id));
create policy mcp_delegated_deny on public.purchase_lines as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.purchase_sources enable row level security;
revoke all on public.purchase_sources from public, anon, authenticated;
grant select on public.purchase_sources to authenticated;
create policy purchase_sources_select on public.purchase_sources
  for select to authenticated
  using (exists (
    select 1 from public.purchase_documents d
     where d.workspace_id = purchase_sources.workspace_id and d.id = purchase_sources.purchase_id));
create policy mcp_delegated_deny on public.purchase_sources as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.purchase_requests enable row level security;
revoke all on public.purchase_requests from public, anon, authenticated;
create policy mcp_delegated_deny on public.purchase_requests as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── guards: a submitted document and its lines are frozen ──────────────
create or replace function public.purchase_documents_guard()
returns trigger language plpgsql as $fn$
declare
  o jsonb := to_jsonb(old) - public.system_column_names();
  n jsonb := to_jsonb(new) - public.system_column_names();
  v_open text[] := array['state', 'approved_event_id', 'recipient_snapshot',
                         'supplier_snapshot', 'legacy_decided_at'];
begin
  if old.state in ('approved', 'rejected', 'cancelled') then
    if o is distinct from n then
      raise exception 'a decided purchase is frozen; correct it with a linked reversal';
    end if;
    return new;
  end if;
  if old.state = 'pending' then
    if (o - v_open) is distinct from (n - v_open) then
      raise exception 'a purchase awaiting approval cannot be edited';
    end if;
    if new.state = 'draft' then raise exception 'a submitted purchase does not go back to draft'; end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.purchase_documents_guard() from public, anon, authenticated;
create trigger purchase_documents_guard
  before update on public.purchase_documents
  for each row execute function public.purchase_documents_guard();

create or replace function public.purchase_lines_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_state text;
begin
  select d.state into v_state from public.purchase_documents d
   where d.id = coalesce(new.purchase_id, old.purchase_id);
  -- No parent left: the document is being deleted with its workspace.
  if v_state is not null and v_state <> 'draft' then
    raise exception 'the lines of a submitted purchase are frozen';
  end if;
  return coalesce(new, old);
end;
$fn$;
revoke execute on function public.purchase_lines_guard() from public, anon, authenticated;
create trigger purchase_lines_guard
  before insert or update or delete on public.purchase_lines
  for each row execute function public.purchase_lines_guard();

-- ── the bridge to the expense event ────────────────────────────────────
create or replace function public.purchase_state_of_event(p_status text)
returns text language sql immutable as $fn$
  select case p_status
           when 'confirmed' then 'approved'
           when 'applied' then 'approved'
           when 'rejected' then 'rejected'
           when 'expired' then 'cancelled'
           else 'pending' end;
$fn$;
revoke execute on function public.purchase_state_of_event(text) from public, anon, authenticated;

-- The document follows the validation outcome of its expense event.
create or replace function public.purchase_apply_event_state(p_event public.events)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_state text := public.purchase_state_of_event(p_event.status);
begin
  update public.purchase_documents d
     set state = v_state,
         approved_event_id = case when v_state = 'approved' then p_event.id end,
         recipient_snapshot = case when v_state = 'approved' then
           (select jsonb_build_object('workspace_id', w.id, 'name', w.name,
                                      'country_code', w.country_code)
              from public.workspaces w where w.id = p_event.workspace_id)
           else d.recipient_snapshot end,
         legacy_decided_at = case when d.legacy_qualification <> 'none'
                                  then p_event.decided_at else d.legacy_decided_at end
   where d.workspace_id = p_event.workspace_id
     and d.state in ('draft', 'pending')
     and d.id = (select s.purchase_id from public.purchase_sources s
                  where s.workspace_id = p_event.workspace_id
                    and s.source_kind = 'expense_event' and s.source_id = p_event.id);
end;
$fn$;
revoke execute on function public.purchase_apply_event_state(public.events)
  from public, anon, authenticated;

-- The ONE path that files the document of an expense event (the trigger for
-- every writer, the backfill for history). Idempotent. Never touches the
-- ledger: the credit an approval issued stays the only credit.
create or replace function public.purchase_bridge_expense(p_event public.events)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_id uuid;
  v_native uuid := nullif(current_setting('deskilo.purchase_bridge', true), '')::uuid;
  v_doc public.purchase_documents;
  v_ws public.workspaces;
  v_gross bigint := coalesce((p_event.payload ->> 'amount_cents')::bigint, 0);
  v_percent numeric := (p_event.payload #>> '{vat,percent}')::numeric;
  v_share numeric := coalesce((p_event.payload #>> '{vat,deductible_pct}')::numeric, 100);
  v_net bigint;
  v_tax bigint;
  v_rec bigint;
begin
  select s.purchase_id into v_id from public.purchase_sources s
   where s.workspace_id = p_event.workspace_id
     and s.source_kind = 'expense_event' and s.source_id = p_event.id;
  if v_id is null then
    if v_native is not null then
      select * into v_doc from public.purchase_documents
       where id = v_native and workspace_id = p_event.workspace_id
         and kind = 'member_receipt' and state = 'draft';
      if v_doc.id is null then raise exception 'unknown purchase draft'; end if;
      v_id := v_doc.id;
    else
      select * into v_ws from public.workspaces where id = p_event.workspace_id;
      insert into public.purchase_documents
        (workspace_id, kind, state, currency, category, received_on,
         submitter_member_id, payer_kind, payer_member_id,
         classification_status, legacy_qualification)
      values
        (p_event.workspace_id, 'member_receipt', 'draft', v_ws.currency_code,
         left(coalesce(p_event.payload ->> 'category', ''), 80),
         (p_event.created_at at time zone coalesce(nullif(v_ws.timezone, ''), 'UTC'))::date,
         p_event.actor_member_id, 'member', p_event.subject_member_id,
         'legacy', 'legacy_unverified')
      returning id into v_id;
      if v_percent is not null and v_percent > 0 then
        v_net := public.vat_split_net(v_gross, v_percent);
        v_tax := v_gross - v_net;
        v_rec := round(v_tax::numeric * greatest(0, least(100, v_share)) / 100)::bigint;
      end if;
      insert into public.purchase_lines
        (workspace_id, purchase_id, line_no, description, gross_cents, net_cents, tax_cents,
         tax_rate_percent, recoverable_tax_cents, nonrecoverable_tax_cents, supply,
         recognition_kind)
      values
        (p_event.workspace_id, v_id, 1,
         left(coalesce(nullif(p_event.payload ->> 'note', ''), p_event.payload ->> 'category', ''), 500),
         v_gross, v_net, v_tax, trim_scale(v_percent), v_rec, v_tax - v_rec,
         p_event.payload -> 'supply',
         case when coalesce((p_event.payload #>> '{vat,asset}')::boolean, false)
              then 'asset' else 'unresolved' end);
    end if;
    insert into public.purchase_sources
      (workspace_id, purchase_id, source_kind, source_id, role, linked_by)
    values (p_event.workspace_id, v_id, 'expense_event', p_event.id, 'origin',
            p_event.actor_member_id);
  end if;
  -- The supplier invoice this expense was matched to is evidence of the
  -- same purchase, never a second one.
  insert into public.purchase_sources
    (workspace_id, purchase_id, source_kind, source_id, role, original_hash,
     original_reference, linked_by)
  select i.workspace_id, v_id, 'inbox', i.id, 'evidence', i.document_hash,
         left(i.invoice_number, 200), p_event.actor_member_id
    from public.einvoice_inbox i
   where i.workspace_id = p_event.workspace_id and i.matched_event_id = p_event.id
  on conflict (workspace_id, source_kind, source_id) do nothing;
  perform public.purchase_apply_event_state(p_event);
  return v_id;
end;
$fn$;
revoke execute on function public.purchase_bridge_expense(public.events)
  from public, anon, authenticated;

create or replace function public.purchase_expense_event_stamp()
returns trigger language plpgsql as $fn$
declare
  v_native text := nullif(current_setting('deskilo.purchase_bridge', true), '');
begin
  if new.type = 'expense' and v_native is not null then
    new.payload := new.payload
      || jsonb_build_object('purchase_id', v_native, 'payer', 'member');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.purchase_expense_event_stamp() from public, anon, authenticated;
create trigger purchase_expense_event_stamp
  before insert on public.events
  for each row when (new.type = 'expense')
  execute function public.purchase_expense_event_stamp();

create or replace function public.purchase_expense_event_bridge()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  perform public.purchase_bridge_expense(new);
  return null;
end;
$fn$;
revoke execute on function public.purchase_expense_event_bridge() from public, anon, authenticated;
create trigger purchase_expense_event_bridge
  after insert on public.events
  for each row when (new.type = 'expense')
  execute function public.purchase_expense_event_bridge();

create or replace function public.purchase_expense_event_state()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  perform public.purchase_apply_event_state(new);
  return null;
end;
$fn$;
revoke execute on function public.purchase_expense_event_state() from public, anon, authenticated;
create trigger purchase_expense_event_state
  after update of status on public.events
  for each row when (new.type = 'expense' and old.status is distinct from new.status)
  execute function public.purchase_expense_event_state();

-- An invoice matched to an expense AFTER the event was filed joins that
-- expense's purchase as evidence.
create or replace function public.purchase_inbox_match_link()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  insert into public.purchase_sources
    (workspace_id, purchase_id, source_kind, source_id, role, original_hash, original_reference)
  select new.workspace_id, s.purchase_id, 'inbox', new.id, 'evidence',
         new.document_hash, left(new.invoice_number, 200)
    from public.purchase_sources s
   where s.workspace_id = new.workspace_id
     and s.source_kind = 'expense_event' and s.source_id = new.matched_event_id
  on conflict (workspace_id, source_kind, source_id) do nothing;
  return null;
end;
$fn$;
revoke execute on function public.purchase_inbox_match_link() from public, anon, authenticated;
create trigger purchase_inbox_match_link
  after update of matched_event_id on public.einvoice_inbox
  for each row when (new.matched_event_id is not null
                     and old.matched_event_id is distinct from new.matched_event_id)
  execute function public.purchase_inbox_match_link();

-- Backfill: the document of every expense event that has none. Events,
-- credits, invoices, VAT returns and balances are not read for writing.
select public.purchase_bridge_expense(e)
  from public.events e
 where e.type = 'expense'
 order by e.created_at, e.id;

-- ── request replay ─────────────────────────────────────────────────────
create or replace function public.purchase_request_begin(
  p_workspace_id uuid, p_request_id uuid, p_operation text, p_digest text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v public.purchase_requests;
begin
  perform pg_advisory_xact_lock(
    hashtextextended('purchase_request:' || p_workspace_id::text || p_request_id::text, 0));
  select * into v from public.purchase_requests
   where workspace_id = p_workspace_id and request_id = p_request_id;
  if v.id is null then return null; end if;
  if v.operation <> p_operation or v.digest <> p_digest then
    raise exception 'this request id was already used for a different request';
  end if;
  return v.result;
end;
$fn$;
revoke execute on function public.purchase_request_begin(uuid, uuid, text, text)
  from public, anon, authenticated;

create or replace function public.purchase_request_end(
  p_workspace_id uuid, p_request_id uuid, p_operation text, p_digest text, p_result jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
begin
  insert into public.purchase_requests (workspace_id, request_id, operation, digest, result)
  values (p_workspace_id, p_request_id, p_operation, p_digest, p_result);
  return p_result;
end;
$fn$;
revoke execute on function public.purchase_request_end(uuid, uuid, text, text, jsonb)
  from public, anon, authenticated;

-- ── lines ──────────────────────────────────────────────────────────────
create or replace function public.purchase_write_lines(
  p_workspace_id uuid, p_purchase_id uuid, p_lines jsonb
) returns void language plpgsql security definer set search_path = public as $fn$
declare
  e jsonb;
  n int := 0;
  v_gross bigint;
  v_net bigint;
  v_tax bigint;
  v_rec bigint;
  v_kind text;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) not between 1 and 200 then
    raise exception 'a purchase has between 1 and 200 lines';
  end if;
  delete from public.purchase_lines where purchase_id = p_purchase_id;
  for e in select value from jsonb_array_elements(p_lines) loop
    n := n + 1;
    v_gross := (e ->> 'gross_cents')::bigint;
    if v_gross is null or v_gross < 0 then raise exception 'a line needs a gross amount'; end if;
    v_net := nullif(e ->> 'net_cents', '')::bigint;
    v_tax := nullif(e ->> 'tax_cents', '')::bigint;
    if (v_net is null) <> (v_tax is null) then
      raise exception 'net and tax are given together or not at all';
    end if;
    if v_net is not null and v_net + v_tax <> v_gross then
      raise exception 'net plus tax is not the gross amount';
    end if;
    v_rec := nullif(e ->> 'recoverable_tax_cents', '')::bigint;
    if v_rec is not null and (v_tax is null or v_rec < 0 or v_rec > v_tax) then
      raise exception 'the recoverable tax lies between 0 and the tax';
    end if;
    v_kind := coalesce(nullif(e ->> 'recognition_kind', ''), 'unresolved');
    insert into public.purchase_lines
      (workspace_id, purchase_id, line_no, description, quantity, unit, gross_cents,
       net_cents, tax_cents, tax_rate_percent, recoverable_tax_cents,
       nonrecoverable_tax_cents, tax_component_keys, supply, recognition_kind)
    values
      (p_workspace_id, p_purchase_id, n, left(coalesce(e ->> 'description', ''), 500),
       coalesce(nullif(e ->> 'quantity', '')::numeric, 1), left(coalesce(e ->> 'unit', ''), 20),
       v_gross, v_net, v_tax, nullif(e ->> 'tax_rate_percent', '')::numeric, v_rec,
       case when v_rec is null then null else v_tax - v_rec end,
       coalesce(array(select jsonb_array_elements_text(e -> 'tax_component_keys')), '{}'),
       e -> 'supply', v_kind);
  end loop;
end;
$fn$;
revoke execute on function public.purchase_write_lines(uuid, uuid, jsonb)
  from public, anon, authenticated;

-- ── RPCs ───────────────────────────────────────────────────────────────
create or replace function public.save_purchase_draft_v1(
  p_workspace_id uuid, p_request_id uuid, p_expected_revision int, p_payload jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_id uuid := nullif(p_payload ->> 'purchase_id', '')::uuid;
  v_kind text;
  v_doc public.purchase_documents;
  v_ws public.workspaces;
  v_supplier uuid := nullif(p_payload ->> 'supplier_id', '')::uuid;
  v_payer text;
  v_payer_member uuid;
  v_manager boolean;
  v_currency text;
  v_original uuid := nullif(p_payload ->> 'original_document_id', '')::uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'purchases') then
    raise exception 'purchases are switched off in this space';
  end if;
  v_digest := md5(auth.uid()::text || coalesce(p_expected_revision, 0)::text || p_payload::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'save', v_digest);
  if v_done is not null then return v_done; end if;

  select * into v_ws from public.workspaces where id = p_workspace_id;
  v_manager := public.has_permission(p_workspace_id, 'managePurchases');
  v_kind := coalesce(nullif(p_payload ->> 'kind', ''), 'member_receipt');
  if v_kind not in ('bill', 'credit_note', 'member_receipt') then
    raise exception 'unknown purchase kind';
  end if;
  if v_kind <> 'member_receipt' and not v_manager then
    raise exception 'not allowed to capture supplier bills';
  end if;
  v_currency := coalesce(nullif(p_payload ->> 'currency', ''), v_ws.currency_code);
  if v_currency <> v_ws.currency_code then
    raise exception 'a purchase is in the currency of the space';
  end if;
  if v_supplier is not null and not exists (
       select 1 from public.suppliers s
        where s.id = v_supplier and s.workspace_id = p_workspace_id and s.status = 'active') then
    raise exception 'unknown supplier';
  end if;
  if v_original is not null and (v_kind <> 'credit_note' or not exists (
       select 1 from public.purchase_documents o
        where o.id = v_original and o.workspace_id = p_workspace_id and o.kind = 'bill')) then
    raise exception 'a credit note reverses a bill of this space';
  end if;
  if v_kind = 'member_receipt' then
    v_payer := 'member';
    v_payer_member := v_me;
  else
    v_payer := coalesce(nullif(p_payload ->> 'payer_kind', ''), 'unpaid');
    if v_payer not in ('workspace', 'member', 'unpaid') then raise exception 'unknown payer'; end if;
    v_payer_member := case when v_payer = 'member'
      then nullif(p_payload ->> 'payer_member_id', '')::uuid end;
    if v_payer = 'member' and not exists (
         select 1 from public.members m
          where m.id = v_payer_member and m.workspace_id = p_workspace_id) then
      raise exception 'unknown payer member';
    end if;
  end if;

  if v_id is null then
    if coalesce(p_expected_revision, 0) <> 0 then raise exception 'stale revision'; end if;
    insert into public.purchase_documents
      (workspace_id, kind, currency, category, supplier_id, original_reference, original_date,
       received_on, service_from, service_to, due_on, submitter_member_id, payer_kind,
       payer_member_id, original_document_id)
    values
      (p_workspace_id, v_kind, v_currency, left(coalesce(p_payload ->> 'category', ''), 80),
       v_supplier, left(coalesce(p_payload ->> 'original_reference', ''), 200),
       nullif(p_payload ->> 'original_date', '')::date, nullif(p_payload ->> 'received_on', '')::date,
       nullif(p_payload ->> 'service_from', '')::date, nullif(p_payload ->> 'service_to', '')::date,
       nullif(p_payload ->> 'due_on', '')::date, v_me, v_payer, v_payer_member, v_original)
    returning * into v_doc;
  else
    select * into v_doc from public.purchase_documents
     where id = v_id and workspace_id = p_workspace_id for update;
    if v_doc.id is null then raise exception 'unknown purchase'; end if;
    if v_doc.kind = 'member_receipt' and v_doc.submitter_member_id <> v_me then
      raise exception 'not your purchase';
    end if;
    if v_doc.kind <> 'member_receipt' and not v_manager then
      raise exception 'not allowed to capture supplier bills';
    end if;
    if v_doc.kind <> v_kind then raise exception 'the kind of a purchase does not change'; end if;
    if v_doc.state <> 'draft' then raise exception 'only a draft can be edited'; end if;
    if v_doc.revision <> coalesce(p_expected_revision, 0) then raise exception 'stale revision'; end if;
    update public.purchase_documents set
        revision = revision + 1,
        category = left(coalesce(p_payload ->> 'category', ''), 80),
        supplier_id = v_supplier,
        original_reference = left(coalesce(p_payload ->> 'original_reference', ''), 200),
        original_date = nullif(p_payload ->> 'original_date', '')::date,
        received_on = nullif(p_payload ->> 'received_on', '')::date,
        service_from = nullif(p_payload ->> 'service_from', '')::date,
        service_to = nullif(p_payload ->> 'service_to', '')::date,
        due_on = nullif(p_payload ->> 'due_on', '')::date,
        payer_kind = v_payer, payer_member_id = v_payer_member,
        original_document_id = v_original
      where id = v_doc.id
      returning * into v_doc;
  end if;
  perform public.purchase_write_lines(p_workspace_id, v_doc.id, p_payload -> 'lines');
  v_result := jsonb_build_object('purchase_id', v_doc.id, 'revision', v_doc.revision,
                                 'state', v_doc.state);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'save', v_digest, v_result);
end;
$fn$;
revoke execute on function public.save_purchase_draft_v1(uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.save_purchase_draft_v1(uuid, uuid, int, jsonb) to authenticated;

create or replace function public.submit_purchase_v1(
  p_workspace_id uuid, p_purchase_id uuid, p_revision int, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_doc public.purchase_documents;
  v_gross bigint;
  v_net bigint;
  v_tax bigint;
  v_rates int;
  v_unknown int;
  v_assets int;
  v_lines int;
  v_percent numeric;
  v_rec bigint;
  v_unqualified int;
  v_vat jsonb := null;
  v_supply jsonb := null;
  v_desc text;
  v_event uuid;
  v_state text;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'purchases') then
    raise exception 'purchases are switched off in this space';
  end if;
  v_digest := md5(auth.uid()::text || p_purchase_id::text || coalesce(p_revision, 0)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'submit', v_digest);
  if v_done is not null then return v_done; end if;

  select * into v_doc from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id for update;
  if v_doc.id is null then raise exception 'unknown purchase'; end if;
  if v_doc.kind <> 'member_receipt' then
    raise exception 'a supplier bill is submitted once its payable exists';
  end if;
  if v_doc.submitter_member_id <> v_me then raise exception 'not your purchase'; end if;
  if v_doc.state <> 'draft' then raise exception 'only a draft can be submitted'; end if;
  if v_doc.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if v_doc.category = '' then raise exception 'a receipt needs a category'; end if;

  select count(*), coalesce(sum(gross_cents), 0), count(*) filter (where tax_cents is null or tax_rate_percent is null),
         count(distinct tax_rate_percent), count(*) filter (where recognition_kind = 'asset'),
         coalesce(sum(net_cents), 0), coalesce(sum(tax_cents), 0),
         coalesce(sum(recoverable_tax_cents), 0),
         count(*) filter (where tax_cents > 0 and recoverable_tax_cents is null)
    into v_lines, v_gross, v_unknown, v_rates, v_assets, v_net, v_tax, v_rec, v_unqualified
    from public.purchase_lines where purchase_id = v_doc.id;
  if v_lines = 0 or v_gross <= 0 then raise exception 'a receipt needs an amount'; end if;
  if v_gross > 2147483647 then raise exception 'the amount of a receipt is too large'; end if;
  if v_assets not in (0, v_lines) then
    raise exception 'a receipt mixing assets and other lines awaits the posting model';
  end if;
  if v_tax > 0 then
    -- Input VAT travels on the expense as ONE rate and ONE deductible share.
    if v_unknown > 0 or v_rates <> 1 then
      raise exception 'a receipt with several tax rates awaits the posting model';
    end if;
    if v_unqualified > 0 then
      raise exception 'qualify the deductible tax of every line before submitting';
    end if;
    select max(tax_rate_percent) into v_percent from public.purchase_lines where purchase_id = v_doc.id;
    if v_percent is null or v_percent <= 0 then
      raise exception 'the tax rate of a taxed line is missing';
    end if;
    if v_net <> public.vat_split_net(v_gross, v_percent) then
      raise exception 'the tax amounts do not follow from the rate';
    end if;
    if public.feature_effective(p_workspace_id, 'inputVat') then
      v_vat := jsonb_build_object('percent', trim_scale(v_percent),
                 'deductible_pct', trim_scale(round(v_rec::numeric * 100 / v_tax, 4)))
               || case when v_assets > 0 then jsonb_build_object('asset', true) else '{}'::jsonb end;
    end if;
  end if;
  select l.description, l.supply into v_desc, v_supply from public.purchase_lines l
   where l.purchase_id = v_doc.id and l.line_no = 1;
  if v_lines > 1 then v_supply := null; end if;

  perform set_config('deskilo.purchase_bridge', v_doc.id::text, true);
  v_event := public.submit_expense(p_workspace_id, v_gross::int, v_doc.category,
                                   coalesce(v_desc, ''), v_supply, v_vat);
  perform set_config('deskilo.purchase_bridge', '', true);

  select d.state into v_state from public.purchase_documents d where d.id = v_doc.id;
  v_result := jsonb_build_object('purchase_id', v_doc.id, 'event_id', v_event,
                                 'revision', v_doc.revision, 'state', v_state);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'submit', v_digest, v_result);
end;
$fn$;
revoke execute on function public.submit_purchase_v1(uuid, uuid, int, uuid) from public, anon;
grant execute on function public.submit_purchase_v1(uuid, uuid, int, uuid) to authenticated;

create or replace function public.link_purchase_source_v1(
  p_workspace_id uuid, p_purchase_id uuid, p_source_kind text, p_source_id uuid,
  p_revision int, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  v_doc public.purchase_documents;
  v_inbox public.einvoice_inbox;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.has_permission(p_workspace_id, 'managePurchases') then
    raise exception 'not allowed to link purchase sources';
  end if;
  if not public.feature_effective(p_workspace_id, 'purchases') then
    raise exception 'purchases are switched off in this space';
  end if;
  v_digest := md5(auth.uid()::text || p_purchase_id::text || p_source_kind || p_source_id::text
                  || coalesce(p_revision, 0)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'link', v_digest);
  if v_done is not null then return v_done; end if;

  select * into v_doc from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id for update;
  if v_doc.id is null then raise exception 'unknown purchase'; end if;
  if v_doc.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if v_doc.state in ('rejected', 'cancelled') then
    raise exception 'a rejected or cancelled purchase takes no new evidence';
  end if;
  if p_source_kind <> 'inbox' then
    raise exception 'only a received supplier invoice can be linked by hand';
  end if;
  select * into v_inbox from public.einvoice_inbox
   where id = p_source_id and workspace_id = p_workspace_id;
  if v_inbox.id is null then raise exception 'unknown supplier invoice'; end if;
  if v_inbox.status = 'rejected' then raise exception 'that supplier invoice was rejected'; end if;
  if v_inbox.currency <> v_doc.currency then
    raise exception 'the invoice is in another currency than the purchase';
  end if;
  if v_doc.supplier_id is not null and v_inbox.supplier_id is not null
     and v_doc.supplier_id <> v_inbox.supplier_id then
    raise exception 'the invoice belongs to another supplier';
  end if;
  -- One economic acquisition once: an invoice that already funds an expense
  -- links only to the purchase of THAT expense.
  if v_inbox.matched_event_id is not null and not exists (
       select 1 from public.purchase_sources s
        where s.purchase_id = v_doc.id and s.source_kind = 'expense_event'
          and s.source_id = v_inbox.matched_event_id) then
    raise exception 'that invoice already funds another expense';
  end if;
  if exists (select 1 from public.purchase_sources s
              where s.workspace_id = p_workspace_id and s.source_kind = 'inbox'
                and s.source_id = v_inbox.id and s.purchase_id <> v_doc.id) then
    raise exception 'that invoice is already linked to another purchase';
  end if;
  insert into public.purchase_sources
    (workspace_id, purchase_id, source_kind, source_id, role, original_hash,
     original_reference, linked_by)
  values (p_workspace_id, v_doc.id, 'inbox', v_inbox.id, 'evidence', v_inbox.document_hash,
          left(v_inbox.invoice_number, 200), v_me)
  on conflict (workspace_id, source_kind, source_id) do nothing;
  v_result := jsonb_build_object('purchase_id', v_doc.id, 'source_kind', 'inbox',
                                 'source_id', v_inbox.id);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'link', v_digest, v_result);
end;
$fn$;
revoke execute on function public.link_purchase_source_v1(uuid, uuid, text, uuid, int, uuid)
  from public, anon;
grant execute on function public.link_purchase_source_v1(uuid, uuid, text, uuid, int, uuid)
  to authenticated;

-- The document with its lines, evidence and supplier, for who may read it.
create or replace function public.purchase_detail_v1(p_workspace_id uuid, p_purchase_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  d public.purchase_documents;
  v_readable boolean;
begin
  select * into d from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id;
  if d.id is not null then
    v_readable := public.has_permission(p_workspace_id, 'viewFinances')
      or public.has_permission(p_workspace_id, 'managePurchases')
      or exists (select 1 from public.members m
                  where m.id = d.submitter_member_id and m.user_id = auth.uid()
                    and m.status = 'active');
  end if;
  if d.id is null or not coalesce(v_readable, false) then
    raise exception 'unknown purchase';
  end if;
  return jsonb_build_object(
    'id', d.id, 'kind', d.kind, 'state', d.state, 'revision', d.revision,
    'category', d.category, 'currency', d.currency,
    'original_reference', d.original_reference, 'original_date', d.original_date,
    'received_on', d.received_on, 'service_from', d.service_from, 'service_to', d.service_to,
    'due_on', d.due_on, 'payer_kind', d.payer_kind, 'payer_member_id', d.payer_member_id,
    'submitter_member_id', d.submitter_member_id, 'approved_event_id', d.approved_event_id,
    'classification_status', d.classification_status,
    'legacy_qualification', d.legacy_qualification,
    'supplier', (select jsonb_build_object('id', s.id, 'supplier_number', s.supplier_number,
                                           'name', s.name)
                   from public.suppliers s where s.id = d.supplier_id),
    'supplier_snapshot', d.supplier_snapshot, 'recipient_snapshot', d.recipient_snapshot,
    'lines', coalesce((select jsonb_agg(jsonb_build_object(
        'line_no', l.line_no, 'description', l.description, 'quantity', l.quantity,
        'unit', l.unit, 'gross_cents', l.gross_cents, 'net_cents', l.net_cents,
        'tax_cents', l.tax_cents, 'tax_rate_percent', l.tax_rate_percent,
        'recoverable_tax_cents', l.recoverable_tax_cents,
        'nonrecoverable_tax_cents', l.nonrecoverable_tax_cents,
        'recognition_kind', l.recognition_kind) order by l.line_no)
        from public.purchase_lines l where l.purchase_id = d.id), '[]'::jsonb),
    'sources', coalesce((select jsonb_agg(jsonb_build_object(
        'source_kind', s.source_kind, 'source_id', s.source_id, 'role', s.role,
        'original_hash', s.original_hash, 'original_reference', s.original_reference)
        order by s.created_datetime)
        from public.purchase_sources s where s.purchase_id = d.id), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.purchase_detail_v1(uuid, uuid) from public, anon;
grant execute on function public.purchase_detail_v1(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(461);
