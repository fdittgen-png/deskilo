-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0466 (#2574, C1 of #2464) -- who is owed what for an approved purchase.
--
--   * `purchase_obligations`: the settlement INDEX over a purchase document,
--     keyed by (workspace, purchase, creditor kind, creditor). It is not an
--     expense and not a second liability: an approved member outlay already
--     issued its running-account credit (a `ledger_entries` row of category
--     `expense`); the obligation records that this credit is the member's
--     claim on the purchase and links to it (`legacy_member_credit_id`). The
--     creditor is a member OR a supplier -- a member is never made a supplier
--     to be reimbursed. Nothing here writes a ledger row, a payment or a tax
--     line.
--   * One path files the obligation of an approved member receipt:
--     `purchase_obligation_sync`, called by the validation outcome, by the
--     ledger credit that approval issues (it is inserted after the status
--     change, so the link is completed by its own trigger) and by the
--     backfill. Idempotent: repeating it changes nothing.
--   * Usage is DERIVED, not stored: a credit is applied once an issued, not
--     voided invoice of the same member and period, cut after the credit,
--     carries an `expense` line of that exact negative amount (the Nth equal
--     credit of the period needs N such lines). The obligation then reads
--     "applied to invoice X". Recorded payments and offsets are the
--     allocations of the next checkpoint; until then a claim is either open
--     or applied, and says so.
--   * `purchase_payables_page_v1` lists the claims (a member reads their
--     own, viewFinances / managePurchases the workspace's); the purchase
--     detail gains the obligations of the document.
--
-- Supplier creditors have no producer yet: a supplier bill cannot be
-- submitted before its payable exists (#2574 C2); the column and the filter
-- are ready for it.

create table public.purchase_obligations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  purchase_id uuid not null,
  creditor_kind text not null check (creditor_kind in ('member', 'supplier')),
  creditor_member_id uuid,
  creditor_supplier_id uuid,
  amount_cents bigint not null check (amount_cents > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  due_on date,
  state text not null default 'open' check (state in ('open', 'held', 'cancelled')),
  hold_reason text not null default '' check (char_length(hold_reason) <= 300),
  revision int not null default 1 check (revision >= 1),
  legacy_member_credit_id uuid references public.ledger_entries(id),
  foreign key (workspace_id, purchase_id)
    references public.purchase_documents (workspace_id, id) on delete cascade,
  foreign key (workspace_id, creditor_member_id)
    references public.members (workspace_id, id),
  foreign key (workspace_id, creditor_supplier_id)
    references public.suppliers (workspace_id, id),
  check ((creditor_kind = 'member') = (creditor_member_id is not null)),
  check ((creditor_kind = 'supplier') = (creditor_supplier_id is not null)),
  check (legacy_member_credit_id is null or creditor_kind = 'member')
);
select public.ensure_system_columns('purchase_obligations');
create unique index purchase_obligations_creditor_key
  on public.purchase_obligations
     (workspace_id, purchase_id, creditor_kind,
      coalesce(creditor_member_id, creditor_supplier_id));
create index purchase_obligations_workspace
  on public.purchase_obligations (workspace_id, state, created_datetime desc);
create index purchase_obligations_member
  on public.purchase_obligations (creditor_member_id);

alter table public.purchase_obligations enable row level security;
revoke all on public.purchase_obligations from public, anon, authenticated;
grant select on public.purchase_obligations to authenticated;
create policy purchase_obligations_select on public.purchase_obligations
  for select to authenticated
  using (
    workspace_id in (select public.workspaces_permitting(array['viewFinances', 'managePurchases']))
    or creditor_member_id in (
      select m.id from public.members m
       where m.user_id = (select auth.uid()) and m.status = 'active')
  );
create policy mcp_delegated_deny on public.purchase_obligations as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- The claim's identity is frozen: who, how much, on which purchase.
create or replace function public.purchase_obligations_guard()
returns trigger language plpgsql as $fn$
begin
  if new.workspace_id is distinct from old.workspace_id
     or new.purchase_id is distinct from old.purchase_id
     or new.creditor_kind is distinct from old.creditor_kind
     or new.creditor_member_id is distinct from old.creditor_member_id
     or new.creditor_supplier_id is distinct from old.creditor_supplier_id
     or new.amount_cents is distinct from old.amount_cents
     or new.currency is distinct from old.currency then
    raise exception 'a purchase obligation keeps its purchase, creditor and amount';
  end if;
  if old.legacy_member_credit_id is not null
     and new.legacy_member_credit_id is distinct from old.legacy_member_credit_id then
    raise exception 'a purchase obligation keeps the credit it indexes';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.purchase_obligations_guard() from public, anon, authenticated;
create trigger purchase_obligations_guard
  before update on public.purchase_obligations
  for each row execute function public.purchase_obligations_guard();

-- ── the one path that files the claim of an approved member receipt ────
create or replace function public.purchase_obligation_sync(p_purchase_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  d public.purchase_documents;
  v_gross bigint;
  v_credit uuid;
begin
  select * into d from public.purchase_documents where id = p_purchase_id;
  if d.id is null or d.kind <> 'member_receipt' or d.state <> 'approved'
     or d.payer_member_id is null then
    return;
  end if;
  select coalesce(sum(l.gross_cents), 0) into v_gross
    from public.purchase_lines l where l.purchase_id = d.id;
  if v_gross <= 0 then return; end if;
  -- The credit approval issued: one row per approved expense event.
  select le.id into v_credit from public.ledger_entries le
   where le.workspace_id = d.workspace_id and le.event_id = d.approved_event_id
     and le.kind = 'credit' and le.category = 'expense'
   order by le.created_at, le.id limit 1;
  insert into public.purchase_obligations
    (workspace_id, purchase_id, creditor_kind, creditor_member_id, amount_cents,
     currency, due_on, legacy_member_credit_id)
  values (d.workspace_id, d.id, 'member', d.payer_member_id, v_gross, d.currency,
          d.due_on, v_credit)
  on conflict (workspace_id, purchase_id, creditor_kind,
               (coalesce(creditor_member_id, creditor_supplier_id)))
  do update set
    legacy_member_credit_id =
      coalesce(public.purchase_obligations.legacy_member_credit_id, excluded.legacy_member_credit_id);
end;
$fn$;
revoke execute on function public.purchase_obligation_sync(uuid) from public, anon, authenticated;

-- The validation outcome of 0461, restated whole with one added step: the
-- approved document files its claim.
create or replace function public.purchase_apply_event_state(p_event public.events)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_state text := public.purchase_state_of_event(p_event.status);
  v_id uuid;
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
                    and s.source_kind = 'expense_event' and s.source_id = p_event.id)
  returning d.id into v_id;
  if v_id is not null and v_state = 'approved' then
    perform public.purchase_obligation_sync(v_id);
  end if;
end;
$fn$;
revoke execute on function public.purchase_apply_event_state(public.events)
  from public, anon, authenticated;

-- The credit is inserted AFTER the event's status changes: its own trigger
-- completes the link between the claim and the credit.
create or replace function public.purchase_obligation_credit_link()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_purchase uuid;
begin
  select s.purchase_id into v_purchase from public.purchase_sources s
   where s.workspace_id = new.workspace_id
     and s.source_kind = 'expense_event' and s.source_id = new.event_id;
  if v_purchase is not null then
    perform public.purchase_obligation_sync(v_purchase);
  end if;
  return null;
end;
$fn$;
revoke execute on function public.purchase_obligation_credit_link()
  from public, anon, authenticated;
create trigger purchase_obligation_credit_link
  after insert on public.ledger_entries
  for each row when (new.kind = 'credit' and new.category = 'expense'
                     and new.event_id is not null)
  execute function public.purchase_obligation_credit_link();

-- Backfill: the claim of every approved member receipt that has none.
select public.purchase_obligation_sync(d.id)
  from public.purchase_documents d
 where d.kind = 'member_receipt' and d.state = 'approved'
 order by d.created_datetime, d.id;

-- ── usage, derived ─────────────────────────────────────────────────────
-- The invoice that applied the claim's credit, or NULL while it is open.
create or replace function public.purchase_obligation_invoice(p_ob public.purchase_obligations)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  c public.ledger_entries;
  v_inv jsonb;
begin
  if p_ob.legacy_member_credit_id is null then return null; end if;
  select * into c from public.ledger_entries where id = p_ob.legacy_member_credit_id;
  if c.id is null then return null; end if;
  select jsonb_build_object('id', i.id, 'number', i.number, 'issued_at', i.issued_at,
                            'total_cents', i.total_cents) into v_inv
    from public.invoices i
   where i.workspace_id = p_ob.workspace_id
     and i.member_id = c.member_id
     and i.period = c.period
     and i.voided_at is null
     and i.issued_at >= c.created_at
     and jsonb_typeof(i.lines) = 'array'
     and (select count(*) from jsonb_array_elements(i.lines) x
           where x ->> 'kind' = 'expense'
             and jsonb_typeof(x -> 'amount_cents') = 'number'
             and (x ->> 'amount_cents')::bigint = -c.amount_cents)
         >= (select count(*) from public.ledger_entries o
              where o.member_id = c.member_id and o.period = c.period
                and o.kind = 'credit' and o.category = 'expense'
                and o.amount_cents = c.amount_cents
                and o.created_at <= i.issued_at
                and (o.created_at, o.id) <= (c.created_at, c.id))
   order by i.issued_at, i.id
   limit 1;
  return v_inv;
end;
$fn$;
revoke execute on function public.purchase_obligation_invoice(public.purchase_obligations)
  from public, anon, authenticated;

-- One claim as the clients read it.
create or replace function public.purchase_obligation_json(p_ob public.purchase_obligations)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_inv jsonb := public.purchase_obligation_invoice(p_ob);
  v_applied bigint := case when v_inv is null then 0 else p_ob.amount_cents end;
begin
  return jsonb_build_object(
    'id', p_ob.id, 'purchase_id', p_ob.purchase_id,
    'creditor_kind', p_ob.creditor_kind,
    'creditor_id', coalesce(p_ob.creditor_member_id, p_ob.creditor_supplier_id),
    'amount_cents', p_ob.amount_cents, 'currency', p_ob.currency,
    'due_on', p_ob.due_on, 'state', p_ob.state, 'hold_reason', p_ob.hold_reason,
    'revision', p_ob.revision,
    'applied_cents', v_applied,
    'remaining_cents', case when p_ob.state = 'cancelled' then 0
                            else p_ob.amount_cents - v_applied end,
    'applied_invoice', v_inv);
end;
$fn$;
revoke execute on function public.purchase_obligation_json(public.purchase_obligations)
  from public, anon, authenticated;

-- ── the To-pay page ────────────────────────────────────────────────────
create or replace function public.purchase_payables_page_v1(
  p_workspace_id uuid,
  p_creditor_kind text default null,
  p_limit int default 50,
  p_after_created timestamptz default null,
  p_after_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_wide boolean;
  v_me uuid;
  v_limit int := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_rows jsonb;
  v_count int;
  v_last_c timestamptz;
  v_last_i uuid;
begin
  if p_creditor_kind is not null and p_creditor_kind not in ('member', 'supplier') then
    raise exception 'unknown creditor kind';
  end if;
  v_wide := public.has_permission(p_workspace_id, 'viewFinances')
         or public.has_permission(p_workspace_id, 'managePurchases');
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if not v_wide and v_me is null then
    raise exception 'unknown workspace';
  end if;
  with q as (
    select jsonb_build_object(
             'obligation', public.purchase_obligation_json(o),
             'purchase', jsonb_build_object(
               'kind', d.kind, 'state', d.state, 'category', d.category,
               'original_reference', d.original_reference, 'received_on', d.received_on,
               'legacy', d.legacy_qualification <> 'none')) as j,
           o.created_datetime as c, o.id as i,
           row_number() over (order by o.created_datetime desc, o.id desc) as rn
      from public.purchase_obligations o
      join public.purchase_documents d
        on d.workspace_id = o.workspace_id and d.id = o.purchase_id
     where o.workspace_id = p_workspace_id
       and (v_wide or o.creditor_member_id = v_me)
       and (p_creditor_kind is null or o.creditor_kind = p_creditor_kind)
       and (p_after_created is null
            or (o.created_datetime, o.id) < (p_after_created, p_after_id))
     order by o.created_datetime desc, o.id desc
     limit v_limit + 1)
  select coalesce(jsonb_agg(j order by rn) filter (where rn <= v_limit), '[]'::jsonb),
         count(*)::int,
         (array_agg(c order by rn) filter (where rn = v_limit))[1],
         (array_agg(i order by rn) filter (where rn = v_limit))[1]
    into v_rows, v_count, v_last_c, v_last_i
    from q;
  return jsonb_build_object(
    'rows', v_rows,
    'next', case when v_count > v_limit
                 then jsonb_build_object('created', v_last_c, 'id', v_last_i) end);
end;
$fn$;
revoke execute on function public.purchase_payables_page_v1(uuid, text, int, timestamptz, uuid)
  from public, anon;
grant execute on function public.purchase_payables_page_v1(uuid, text, int, timestamptz, uuid)
  to authenticated;

-- The detail of 0461 gains the claims of the document.
create or replace function public.purchase_detail_v1(p_workspace_id uuid, p_purchase_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  d public.purchase_documents;
  v_wide boolean;
  v_readable boolean;
  v_me uuid;
begin
  select * into d from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id;
  if d.id is not null then
    v_wide := public.has_permission(p_workspace_id, 'viewFinances')
      or public.has_permission(p_workspace_id, 'managePurchases');
    select m.id into v_me from public.members m
     where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
    v_readable := v_wide or v_me = d.submitter_member_id;
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
        from public.purchase_sources s where s.purchase_id = d.id), '[]'::jsonb),
    -- A member reads only their own claim; a manager all of them.
    'obligations', coalesce((select jsonb_agg(public.purchase_obligation_json(o)
                                              order by o.created_datetime, o.id)
        from public.purchase_obligations o
       where o.purchase_id = d.id
         and (v_wide or o.creditor_member_id = v_me)), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.purchase_detail_v1(uuid, uuid) from public, anon;
grant execute on function public.purchase_detail_v1(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(466);
