-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0467 (#2574, C2a of #2464) -- recording the cash a member is paid back.
--
--   * Permission `recordOutgoingPayments` (catalogue restated; owners and
--     co-owners hold the whole catalogue, nobody else until a role is given
--     it). It is not gated by the `purchases` flag: settling an existing
--     lawful claim never depends on a feature switch.
--   * `outgoing_payments`: a payment a human affirmed ("reported"); a record
--     is not bank verification. `purchase_settlement_allocations`: the
--     append-only link from a claim to a payment (or its reversal), signed
--     minor units, one request id and digest.
--   * `record_member_reimbursement_v1` / `reverse_purchase_allocation_v1`:
--     one transaction writes the payment, the allocation and the
--     member-account effect, bumps the claim's revision and stores the
--     result under the request id (replay answers the original; a changed
--     argument is refused). The member-account effect is a ledger CHARGE of
--     category `reimbursement` booked to the credit's own period: like
--     `refund` (0436) it never becomes an invoice line, and the member's
--     balance falls by what was paid. A reversal is the matching credit.
--   * The claim's credit stays ONE spendable amount: `invoice_lines_for`
--     (anchored patch) states the credit net of what was paid, so the
--     invoice of its period can never apply it twice. A claim already
--     applied to an invoice is neither paid nor reversed; a guard on
--     `invoices` refuses an invoice whose expense lines disagree with the
--     account when reimbursements exist (the derive-then-insert window).
--   * Usage stays derived: remaining = amount - paid - applied-to-invoice.
--
-- Not here: payments of supplier bills (the bill itself awaits C2b), offsets
-- against a separate invoice, maker-checker validation of the payment,
-- statement reconciliation (#2380), postings (#2365).

-- ── the permission ─────────────────────────────────────────────────────
create or replace function public.role_permission_catalog()
returns text[] language sql immutable as $$
  select array[
    'manageRoles','manageMembers','manageValidation','workspaceSettings',
    'issueInvoices','viewFinances','manageDocuments','manageServices',
    'approveExpenses','viewNegotiations','manageNegotiations','paymentTermsEdit',
    'manageSites','manageBilling','manageReservations','operateKiosk','exportData',
    'designDocuments','viewPersonalData','manageIntegrations','manageConfiguration',
    'deployToProd','deployToDev','accessProd','viewAnalytics',
    'useMessages','makeReservations','viewCalendar','viewDirectory',
    'viewMyMoney','viewDocuments','managePurchases','recordOutgoingPayments'];
$$;
revoke execute on function public.role_permission_catalog() from public, anon;

-- ── the member-account effect has its own category ─────────────────────
alter table public.ledger_entries drop constraint ledger_entries_category_check;
alter table public.ledger_entries add constraint ledger_entries_category_check
  check (category in ('subscription','overage','expense','payment','adjustment',
                      'service','package','refund','reimbursement'));

-- ── tables ─────────────────────────────────────────────────────────────
create unique index purchase_obligations_workspace_id_id_key
  on public.purchase_obligations (workspace_id, id);

create table public.outgoing_payments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  payee_kind text not null check (payee_kind in ('member', 'supplier')),
  payee_member_id uuid,
  payee_supplier_id uuid,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  amount_cents bigint not null check (amount_cents > 0),
  method text not null check (method in ('bank_transfer', 'cash', 'card', 'other')),
  reported_paid_on date not null,
  booking_date date,
  value_date date,
  reference text not null default '' check (char_length(reference) <= 200),
  state text not null check (state in ('prepared', 'reported', 'reconciled', 'reversed')),
  revision int not null default 1 check (revision >= 1),
  actor_member_id uuid not null,
  request_id uuid not null,
  foreign key (workspace_id, payee_member_id) references public.members (workspace_id, id),
  foreign key (workspace_id, payee_supplier_id) references public.suppliers (workspace_id, id),
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id),
  check ((payee_kind = 'member') = (payee_member_id is not null)),
  check ((payee_kind = 'supplier') = (payee_supplier_id is not null)),
  unique (workspace_id, id),
  unique (workspace_id, request_id)
);
select public.ensure_system_columns('outgoing_payments');
create index outgoing_payments_member on public.outgoing_payments (payee_member_id);

create table public.purchase_settlement_allocations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  obligation_id uuid not null,
  payment_id uuid not null,
  kind text not null check (kind in ('payment', 'reversal')),
  amount_cents bigint not null check (amount_cents <> 0),
  original_allocation_id uuid references public.purchase_settlement_allocations(id),
  ledger_entry_id uuid not null references public.ledger_entries(id),
  reason text not null default '' check (char_length(reason) <= 300),
  request_id uuid not null,
  actor_member_id uuid not null,
  foreign key (workspace_id, obligation_id)
    references public.purchase_obligations (workspace_id, id),
  foreign key (workspace_id, payment_id) references public.outgoing_payments (workspace_id, id),
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id),
  check ((kind = 'payment') = (amount_cents > 0)),
  check ((kind = 'reversal') = (original_allocation_id is not null))
);
select public.ensure_system_columns('purchase_settlement_allocations');
create index purchase_settlement_allocations_obligation
  on public.purchase_settlement_allocations (obligation_id);
create unique index purchase_settlement_allocations_one_reversal
  on public.purchase_settlement_allocations (original_allocation_id)
  where original_allocation_id is not null;

alter table public.outgoing_payments enable row level security;
revoke all on public.outgoing_payments from public, anon, authenticated;
grant select on public.outgoing_payments to authenticated;
create policy outgoing_payments_select on public.outgoing_payments
  for select to authenticated
  using (
    workspace_id in (select public.workspaces_permitting(array['viewFinances', 'recordOutgoingPayments']))
    or payee_member_id in (
      select m.id from public.members m
       where m.user_id = (select auth.uid()) and m.status = 'active')
  );
create policy mcp_delegated_deny on public.outgoing_payments as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.purchase_settlement_allocations enable row level security;
revoke all on public.purchase_settlement_allocations from public, anon, authenticated;
grant select on public.purchase_settlement_allocations to authenticated;
create policy purchase_settlement_allocations_select on public.purchase_settlement_allocations
  for select to authenticated
  using (exists (
    select 1 from public.purchase_obligations o
     where o.workspace_id = purchase_settlement_allocations.workspace_id
       and o.id = purchase_settlement_allocations.obligation_id));
create policy mcp_delegated_deny on public.purchase_settlement_allocations as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- Allocations are history: never edited, never removed.
create or replace function public.purchase_allocations_guard()
returns trigger language plpgsql as $fn$
begin
  raise exception 'a settlement allocation is never edited or removed; reverse it';
end;
$fn$;
revoke execute on function public.purchase_allocations_guard() from public, anon, authenticated;
create trigger purchase_allocations_guard
  before update or delete on public.purchase_settlement_allocations
  for each row execute function public.purchase_allocations_guard();

-- A payment keeps what it was; it may only move from reported to reversed.
create or replace function public.outgoing_payments_guard()
returns trigger language plpgsql as $fn$
begin
  if tg_op = 'DELETE' then
    raise exception 'an outgoing payment is never removed; reverse it';
  end if;
  if new.workspace_id is distinct from old.workspace_id
     or new.payee_kind is distinct from old.payee_kind
     or new.payee_member_id is distinct from old.payee_member_id
     or new.payee_supplier_id is distinct from old.payee_supplier_id
     or new.currency is distinct from old.currency
     or new.amount_cents is distinct from old.amount_cents
     or new.method is distinct from old.method
     or new.reported_paid_on is distinct from old.reported_paid_on
     or new.reference is distinct from old.reference
     or new.actor_member_id is distinct from old.actor_member_id
     or new.request_id is distinct from old.request_id then
    raise exception 'an outgoing payment keeps what was reported';
  end if;
  if new.state is distinct from old.state
     and not (old.state = 'reported' and new.state = 'reversed') then
    raise exception 'an outgoing payment moves only from reported to reversed here';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.outgoing_payments_guard() from public, anon, authenticated;
create trigger outgoing_payments_guard
  before update or delete on public.outgoing_payments
  for each row execute function public.outgoing_payments_guard();

-- ── what was paid on a credit, and the credit net of it ────────────────
create or replace function public.purchase_credit_paid(p_credit_id uuid)
returns bigint language sql stable security definer set search_path = public as $fn$
  select coalesce(sum(a.amount_cents), 0)::bigint
    from public.purchase_obligations o
    join public.purchase_settlement_allocations a
      on a.workspace_id = o.workspace_id and a.obligation_id = o.id
   where o.legacy_member_credit_id = p_credit_id;
$fn$;
revoke execute on function public.purchase_credit_paid(uuid) from public, anon, authenticated;

-- ── invoice_lines_for states a paid claim's credit net of the cash ─────
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
  v_def text := pg_get_functiondef('public.invoice_lines_for(uuid, text)'::regprocedure);
  v_next text;
begin
  if (length(v_def) - length(replace(v_def,
        'select kind, category, description, amount_cents, vat_percent, supply_class',
        ''))) <> length('select kind, category, description, amount_cents, vat_percent, supply_class') then
    raise exception '0467: the ledger select of invoice_lines_for is not there exactly once';
  end if;
  v_next := pg_temp.anchor_replace(v_def,
    'select kind, category, description, amount_cents, vat_percent, supply_class',
    'select kind, category, description,
           (amount_cents - case when le.kind = ''credit'' and le.category = ''expense''
                                then public.purchase_credit_paid(le.id) else 0 end)::int
             as amount_cents,
           vat_percent, supply_class');
  if v_next is null or v_next = v_def then
    raise exception '0467: the ledger select of invoice_lines_for did not change';
  end if;
  v_def := v_next;
  v_next := pg_temp.anchor_replace(v_def,
    E'    v_lines := v_lines || jsonb_build_object(\n      ''kind'', v_row.category,',
    E'    -- #2574: a claim paid in cash states only what is left of its credit.\n    if v_row.amount_cents <= 0 then continue; end if;\n    v_lines := v_lines || jsonb_build_object(\n      ''kind'', v_row.category,');
  if v_next is null or v_next = v_def then
    raise exception '0467: the line append of invoice_lines_for did not change';
  end if;
  execute v_next;
end
$patch$;

-- An invoice whose expense lines disagree with the account is refused while
-- reimbursements exist: the lines were derived before the insert, and a
-- payment may have committed in between.
create or replace function public.invoices_reimbursement_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_expected bigint;
  v_actual bigint;
begin
  if new.voided_at is not null or new.period is null
     or new.kind not in ('full', 'usage') then
    return new;
  end if;
  if not exists (select 1 from public.ledger_entries r
                  where r.member_id = new.member_id and r.period = new.period
                    and r.category = 'reimbursement') then
    return new;
  end if;
  select coalesce(sum(greatest(le.amount_cents - public.purchase_credit_paid(le.id), 0)), 0)
    into v_expected
    from public.ledger_entries le
   where le.member_id = new.member_id and le.period = new.period
     and le.kind = 'credit' and le.category = 'expense'
     and not exists (select 1 from public.invoice_match_payments jr
                      where jr.payment_ledger_id = le.id);
  select coalesce(sum(-(x ->> 'amount_cents')::bigint), 0) into v_actual
    from jsonb_array_elements(new.lines) x
   where x ->> 'kind' = 'expense' and jsonb_typeof(x -> 'amount_cents') = 'number';
  if v_expected <> v_actual then
    raise exception 'the member account changed while the invoice was being issued; issue it again';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.invoices_reimbursement_guard() from public, anon, authenticated;
create trigger invoices_reimbursement_guard
  before insert on public.invoices
  for each row execute function public.invoices_reimbursement_guard();

-- ── usage, now net of the cash ─────────────────────────────────────────
create or replace function public.purchase_obligation_invoice(p_ob public.purchase_obligations)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  c public.ledger_entries;
  v_net bigint;
  v_inv jsonb;
begin
  if p_ob.legacy_member_credit_id is null then return null; end if;
  select * into c from public.ledger_entries where id = p_ob.legacy_member_credit_id;
  if c.id is null then return null; end if;
  v_net := c.amount_cents - public.purchase_credit_paid(c.id);
  if v_net <= 0 then return null; end if;
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
             and (x ->> 'amount_cents')::bigint = -v_net)
         >= (select count(*) from public.ledger_entries o
              where o.member_id = c.member_id and o.period = c.period
                and o.kind = 'credit' and o.category = 'expense'
                and o.amount_cents - public.purchase_credit_paid(o.id) = v_net
                and o.created_at <= i.issued_at
                and (o.created_at, o.id) <= (c.created_at, c.id))
   order by i.issued_at, i.id
   limit 1;
  return v_inv;
end;
$fn$;
revoke execute on function public.purchase_obligation_invoice(public.purchase_obligations)
  from public, anon, authenticated;

create or replace function public.purchase_obligation_json(p_ob public.purchase_obligations)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_inv jsonb := public.purchase_obligation_invoice(p_ob);
  v_paid bigint;
  v_applied bigint;
begin
  select coalesce(sum(a.amount_cents), 0) into v_paid
    from public.purchase_settlement_allocations a
   where a.workspace_id = p_ob.workspace_id and a.obligation_id = p_ob.id;
  v_applied := case when v_inv is null then 0 else p_ob.amount_cents - v_paid end;
  return jsonb_build_object(
    'id', p_ob.id, 'purchase_id', p_ob.purchase_id,
    'creditor_kind', p_ob.creditor_kind,
    'creditor_id', coalesce(p_ob.creditor_member_id, p_ob.creditor_supplier_id),
    'amount_cents', p_ob.amount_cents, 'currency', p_ob.currency,
    'due_on', p_ob.due_on, 'state', p_ob.state, 'hold_reason', p_ob.hold_reason,
    'revision', p_ob.revision,
    'paid_cents', v_paid,
    'mine', exists (select 1 from public.members m
                     where m.workspace_id = p_ob.workspace_id and m.id = p_ob.creditor_member_id
                       and m.user_id = auth.uid()),
    'applied_cents', v_applied,
    'remaining_cents', case when p_ob.state = 'cancelled' then 0
                            else p_ob.amount_cents - v_paid - v_applied end,
    'applied_invoice', v_inv,
    'allocations', coalesce((select jsonb_agg(jsonb_build_object(
        'id', a.id, 'kind', a.kind, 'amount_cents', a.amount_cents,
        'payment_id', a.payment_id, 'original_allocation_id', a.original_allocation_id,
        'paid_on', p.reported_paid_on, 'method', p.method, 'reference', p.reference,
        'reversed', exists (select 1 from public.purchase_settlement_allocations r
                             where r.original_allocation_id = a.id))
        order by a.created_datetime, a.id)
        from public.purchase_settlement_allocations a
        join public.outgoing_payments p
          on p.workspace_id = a.workspace_id and p.id = a.payment_id
       where a.workspace_id = p_ob.workspace_id and a.obligation_id = p_ob.id), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.purchase_obligation_json(public.purchase_obligations)
  from public, anon, authenticated;

-- ── the two commands ───────────────────────────────────────────────────
create or replace function public.record_member_reimbursement_v1(
  p_workspace_id uuid, p_obligation_id uuid, p_amount_cents bigint, p_revision int,
  p_request_id uuid, p_paid_on date, p_method text default 'bank_transfer',
  p_reference text default ''
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  o public.purchase_obligations;
  c public.ledger_entries;
  v_tz text;
  v_paid bigint;
  v_payment uuid;
  v_ledger uuid;
  v_alloc uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.has_permission(p_workspace_id, 'recordOutgoingPayments') then
    raise exception 'you may not record outgoing payments';
  end if;
  v_digest := md5(v_me::text || p_obligation_id::text || coalesce(p_amount_cents, 0)::text
                  || coalesce(p_revision, 0)::text || coalesce(p_paid_on::text, '')
                  || coalesce(p_method, '') || coalesce(p_reference, ''));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'reimburse', v_digest);
  if v_done is not null then return v_done; end if;

  -- The same lock the invoice issue takes: a payment and an invoice of this
  -- workspace never interleave their reads of the member account.
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  select * into o from public.purchase_obligations
   where id = p_obligation_id and workspace_id = p_workspace_id for update;
  if o.id is null then raise exception 'unknown obligation'; end if;
  if o.creditor_kind <> 'member' then
    raise exception 'a supplier is paid once its bill can be submitted';
  end if;
  if o.creditor_member_id = v_me then
    raise exception 'another person must record the payment of your own claim';
  end if;
  if o.state <> 'open' then raise exception 'this claim is not open'; end if;
  if o.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if coalesce(p_amount_cents, 0) <= 0 then raise exception 'the amount must be positive'; end if;
  if coalesce(p_method, '') not in ('bank_transfer', 'cash', 'card', 'other') then
    raise exception 'unknown payment method';
  end if;
  if p_paid_on is null then raise exception 'state the date the money was paid'; end if;
  select w.timezone into v_tz from public.workspaces w where w.id = p_workspace_id;
  if p_paid_on > (now() at time zone coalesce(nullif(v_tz, ''), 'UTC'))::date then
    raise exception 'a payment dated in the future is not a payment yet';
  end if;
  if o.legacy_member_credit_id is null then
    raise exception 'the credit of this claim is not identified; review it first';
  end if;
  select * into c from public.ledger_entries where id = o.legacy_member_credit_id;
  if public.purchase_obligation_invoice(o) is not null then
    raise exception 'this claim is already applied to an invoice';
  end if;
  select coalesce(sum(a.amount_cents), 0) into v_paid
    from public.purchase_settlement_allocations a
   where a.workspace_id = o.workspace_id and a.obligation_id = o.id;
  if p_amount_cents > o.amount_cents - v_paid then
    raise exception 'the amount exceeds what remains of the claim';
  end if;
  if p_amount_cents > 2147483647 then raise exception 'the amount is too large'; end if;

  insert into public.outgoing_payments
    (workspace_id, payee_kind, payee_member_id, currency, amount_cents, method,
     reported_paid_on, reference, state, actor_member_id, request_id)
  values (o.workspace_id, 'member', o.creditor_member_id, o.currency, p_amount_cents,
          p_method, p_paid_on, left(coalesce(p_reference, ''), 200), 'reported', v_me, p_request_id)
  returning id into v_payment;
  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period,
     occurred_on, vat_percent)
  values (o.workspace_id, o.creditor_member_id, 'charge', 'reimbursement', p_amount_cents::int,
          left(coalesce(nullif(p_reference, ''), c.description), 200), c.period, p_paid_on, 0)
  returning id into v_ledger;
  insert into public.purchase_settlement_allocations
    (workspace_id, obligation_id, payment_id, kind, amount_cents, ledger_entry_id,
     request_id, actor_member_id)
  values (o.workspace_id, o.id, v_payment, 'payment', p_amount_cents, v_ledger,
          p_request_id, v_me)
  returning id into v_alloc;
  update public.purchase_obligations set revision = revision + 1 where id = o.id;

  select public.purchase_obligation_json(po) into v_result
    from public.purchase_obligations po where po.id = o.id;
  v_result := jsonb_build_object('payment_id', v_payment, 'allocation_id', v_alloc,
                                 'obligation', v_result);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'reimburse', v_digest, v_result);
end;
$fn$;
revoke execute on function public.record_member_reimbursement_v1(uuid, uuid, bigint, int, uuid, date, text, text)
  from public, anon;
grant execute on function public.record_member_reimbursement_v1(uuid, uuid, bigint, int, uuid, date, text, text)
  to authenticated;

create or replace function public.reverse_purchase_allocation_v1(
  p_workspace_id uuid, p_allocation_id uuid, p_revision int, p_reason text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  a public.purchase_settlement_allocations;
  o public.purchase_obligations;
  c public.ledger_entries;
  v_ledger uuid;
  v_alloc uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.has_permission(p_workspace_id, 'recordOutgoingPayments') then
    raise exception 'you may not record outgoing payments';
  end if;
  if btrim(coalesce(p_reason, '')) = '' then raise exception 'state why it is reversed'; end if;
  v_digest := md5(v_me::text || p_allocation_id::text || coalesce(p_revision, 0)::text
                  || btrim(p_reason));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'reverse', v_digest);
  if v_done is not null then return v_done; end if;

  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  select * into a from public.purchase_settlement_allocations
   where id = p_allocation_id and workspace_id = p_workspace_id;
  if a.id is null then raise exception 'unknown allocation'; end if;
  select * into o from public.purchase_obligations
   where id = a.obligation_id and workspace_id = p_workspace_id for update;
  if a.kind <> 'payment' then raise exception 'only a payment can be reversed'; end if;
  if o.creditor_member_id = v_me then
    raise exception 'another person must reverse the payment of your own claim';
  end if;
  if o.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if exists (select 1 from public.purchase_settlement_allocations r
              where r.original_allocation_id = a.id) then
    raise exception 'this payment is already reversed';
  end if;
  if public.purchase_obligation_invoice(o) is not null then
    raise exception 'this claim is already applied to an invoice';
  end if;
  select * into c from public.ledger_entries where id = o.legacy_member_credit_id;

  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period,
     occurred_on, vat_percent)
  values (o.workspace_id, o.creditor_member_id, 'credit', 'reimbursement', a.amount_cents::int,
          left(btrim(p_reason), 200), c.period, null, 0)
  returning id into v_ledger;
  insert into public.purchase_settlement_allocations
    (workspace_id, obligation_id, payment_id, kind, amount_cents, original_allocation_id,
     ledger_entry_id, reason, request_id, actor_member_id)
  values (o.workspace_id, o.id, a.payment_id, 'reversal', -a.amount_cents, a.id,
          v_ledger, left(btrim(p_reason), 300), p_request_id, v_me)
  returning id into v_alloc;
  update public.outgoing_payments set state = 'reversed', revision = revision + 1
   where id = a.payment_id;
  update public.purchase_obligations set revision = revision + 1 where id = o.id;

  select public.purchase_obligation_json(po) into v_result
    from public.purchase_obligations po where po.id = o.id;
  v_result := jsonb_build_object('allocation_id', v_alloc, 'obligation', v_result);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'reverse', v_digest, v_result);
end;
$fn$;
revoke execute on function public.reverse_purchase_allocation_v1(uuid, uuid, int, text, uuid)
  from public, anon;
grant execute on function public.reverse_purchase_allocation_v1(uuid, uuid, int, text, uuid)
  to authenticated;

-- ── the template field registry knows the permission ──
create or replace function public.template_field_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select $json$[
    {"id":"floor_plan[].background_path","entity":"floor_plan","type":"text","portability":"never","absent":"inherit","key":"name","reason":"a storage file of the source","process":"spaceManagement"},
    {"id":"floor_plan[].bookable_as_whole","entity":"floor_plan","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].images","entity":"floor_plan","type":"text","portability":"never","absent":"inherit","key":"name","reason":"a storage file of the source","process":"spaceManagement"},
    {"id":"floor_plan[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].bookable_as_whole","entity":"floor_plan","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].color","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].bookable_as_whole","entity":"floor_plan","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].h","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].price_cents","entity":"floor_plan","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].accessories","entity":"floor_plan","type":"list","portability":"reference","absent":"inherit","key":"name","bindings":["accessories.name"],"process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].amenities","entity":"floor_plan","type":"list","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].chair","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].orientation","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].x","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].seats[].y","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].w","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].x","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].desks[].y","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].h","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].name","entity":"floor_plan","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].price_cents","entity":"floor_plan","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].w","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].x","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].offices[].y","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"floor_plan[].price_cents","entity":"floor_plan","type":"cents","portability":"never","absent":"inherit","key":"name","reason":"stripped by strip_template_plan","process":"spaceManagement"},
    {"id":"floor_plan[].site","entity":"floor_plan","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites never travel","process":"spaceManagement"},
    {"id":"floor_plan[].sort_order","entity":"floor_plan","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].active","entity":"accessories","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].name","entity":"accessories","type":"text","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].sort_order","entity":"accessories","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].supplement_cents","entity":"accessories","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"spaceManagement"},
    {"id":"tables.accessories[].vat_rate","entity":"accessories","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"spaceManagement"},
    {"id":"tables.closure_days[].day","entity":"closure_days","type":"date","portability":"literal","absent":"inherit","key":"day","process":"coordination"},
    {"id":"tables.closure_days[].reason","entity":"closure_days","type":"text","portability":"literal","absent":"inherit","key":"day","process":"coordination"},
    {"id":"tables.credit_products[].active","entity":"credit_products","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].half_days","entity":"credit_products","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].name","entity":"credit_products","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].price_cents","entity":"credit_products","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].sort_order","entity":"credit_products","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].validity_months","entity":"credit_products","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.credit_products[].vat_rate","entity":"credit_products","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"membershipCommerce"},
    {"id":"tables.fee_bands[].fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.fee_bands[].from_pct","entity":"tariffs","type":"percent","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.fee_bands[].overage_fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.fee_bands[].to_pct","entity":"tariffs","type":"percent","portability":"literal","absent":"inherit","key":"from_pct","process":"membershipCommerce"},
    {"id":"tables.number_sequences[].date_part","entity":"number_sequences","type":"enumeration","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].digits","entity":"number_sequences","type":"integer","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].gapless","entity":"number_sequences","type":"boolean","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].journal","entity":"number_sequences","type":"text","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].next_value","entity":"number_sequences","type":"integer","portability":"never","absent":"inherit","key":"journal","reason":"a counter (#1295)","process":"billingPayments"},
    {"id":"tables.number_sequences[].period_key","entity":"number_sequences","type":"text","portability":"never","absent":"inherit","key":"journal","reason":"a counter (#1295)","process":"billingPayments"},
    {"id":"tables.number_sequences[].prefix","entity":"number_sequences","type":"text","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].reset","entity":"number_sequences","type":"enumeration","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.number_sequences[].suffix","entity":"number_sequences","type":"text","portability":"literal","absent":"inherit","key":"journal","process":"billingPayments"},
    {"id":"tables.packages[].active","entity":"packages","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].days","entity":"packages","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].name","entity":"packages","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].price_cents","entity":"packages","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.packages[].vat_rate","entity":"packages","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"membershipCommerce"},
    {"id":"tables.plans[].active","entity":"tariffs","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.plans[].base_fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.plans[].included_half_days","entity":"tariffs","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.plans[].name","entity":"tariffs","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.plans[].overage_fee_cents","entity":"tariffs","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].active","entity":"services","type":"boolean","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].name","entity":"services","type":"text","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].price_cents","entity":"services","type":"cents","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].stock","entity":"services","type":"integer","portability":"literal","absent":"inherit","key":"name","process":"membershipCommerce"},
    {"id":"tables.services[].vat_rate","entity":"services","type":"text","portability":"reference","absent":"inherit","key":"name","bindings":["vat_rates.label"],"process":"membershipCommerce"},
    {"id":"tables.sites[].city","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].country_code","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].is_default","entity":"sites","type":"boolean","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].legal_id","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].name","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].postal_code","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].sort_order","entity":"sites","type":"integer","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].street","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].tax_exemption_reason","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.sites[].vat_id","entity":"sites","type":"text","portability":"never","absent":"inherit","key":"name","reason":"sites carry addresses, legal identifiers and VAT numbers","process":"spaceManagement"},
    {"id":"tables.validation_policies[].admins_may_validate","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].auto_validate_admin","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].auto_validate_owner","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].eligible_admin_ids","entity":"validation_rules","type":"list","portability":"never","absent":"inherit","key":"event_type","reason":"names people, who do not exist where a template is applied","process":"coordination"},
    {"id":"tables.validation_policies[].event_type","entity":"validation_rules","type":"text","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].min_amount_cents","entity":"validation_rules","type":"cents","portability":"unsupported","absent":"inherit","key":"event_type","reason":"the export does not carry it yet (#1655)","process":"coordination"},
    {"id":"tables.validation_policies[].owner_may_self_validate","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].owner_required","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].required_count","entity":"validation_rules","type":"integer","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].sequential","entity":"validation_rules","type":"boolean","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.validation_policies[].validator_scope","entity":"validation_rules","type":"enumeration","portability":"literal","absent":"inherit","key":"event_type","process":"coordination"},
    {"id":"tables.vat_rates[].active","entity":"vat","type":"boolean","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].category","entity":"vat","type":"enumeration","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].exemption_reason","entity":"vat","type":"text","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].group_key","entity":"vat","type":"text","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].is_default","entity":"vat","type":"boolean","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].label","entity":"vat","type":"text","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].outside_base","entity":"vat","type":"boolean","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].percent","entity":"vat","type":"decimal","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].supersedes","entity":"vat","type":"text","portability":"reference","absent":"inherit","key":"label@percent","bindings":["vat_rates.label"],"process":"billingPayments"},
    {"id":"tables.vat_rates[].valid_from","entity":"vat","type":"date","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.vat_rates[].valid_to","entity":"vat","type":"date","portability":"literal","absent":"inherit","key":"label@percent","process":"billingPayments"},
    {"id":"tables.workspace_documents[].category","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].min_role","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].provider","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].title","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_documents[].url","entity":"document_links","type":"text","portability":"never","absent":"inherit","key":"title@url","reason":"links to the source's own documents","process":"documentsInformation"},
    {"id":"tables.workspace_field_definitions[].active","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].contexts","entity":"field_definitions","type":"list","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].group_key","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].key","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].labels","entity":"field_definitions","type":"map","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].labels.{locale}.help_text","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].labels.{locale}.label","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options","entity":"field_definitions","type":"list","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].active","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].key","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].labels.{locale}","entity":"field_definitions","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].options[].sort_order","entity":"field_definitions","type":"integer","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].personal_data","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].required","entity":"field_definitions","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].sort_order","entity":"field_definitions","type":"integer","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].type","entity":"field_definitions","type":"enumeration","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].validation","entity":"field_definitions","type":"map","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_field_definitions[].visibility","entity":"field_definitions","type":"enumeration","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].active","entity":"workspace_roles","type":"boolean","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].key","entity":"workspace_roles","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].names","entity":"workspace_roles","type":"map","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].names.{locale}","entity":"workspace_roles","type":"text","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].permissions","entity":"workspace_roles","type":"list","portability":"literal","absent":"inherit","key":"key","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd","viewAnalytics","useMessages","makeReservations","viewCalendar","viewDirectory","viewMyMoney","viewDocuments","managePurchases","recordOutgoingPayments"],"process":"workspaceAccess"},
    {"id":"tables.workspace_roles[].sort_order","entity":"workspace_roles","type":"integer","portability":"literal","absent":"inherit","key":"key","process":"workspaceAccess"},
    {"id":"template.description","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.entities","entity":"template","type":"list","portability":"unsupported","absent":"inherit","reason":"what the template carries","process":"operations"},
    {"id":"template.holidays.country","entity":"closure_days","type":"text","portability":"local_binding","absent":"product_default","reason":"the target's country unless the template names one","process":"coordination"},
    {"id":"template.holidays.years","entity":"closure_days","type":"integer","portability":"literal","absent":"product_default","min":1,"max":3,"depends_on":["closure_days"],"process":"coordination"},
    {"id":"template.key","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.name","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.owner_workspace_id","entity":"template","type":"text","portability":"never","absent":"inherit","reason":"who published it","process":"operations"},
    {"id":"template.schema_version","entity":"template","type":"integer","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.sort_order","entity":"template","type":"integer","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.tags","entity":"template","type":"list","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.template_version","entity":"template","type":"integer","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"template.visibility","entity":"template","type":"text","portability":"unsupported","absent":"inherit","reason":"describes the template, not a space","process":"operations"},
    {"id":"workspace.accessory_supplements_since","entity":"workspace","type":"date","portability":"never","absent":"inherit","reason":"a date in this space's history","process":"operations"},
    {"id":"workspace.address","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.billing_rules","entity":"tariffs","type":"map","portability":"literal","absent":"inherit","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.new_member_defaults.overage_policy","entity":"tariffs","type":"enumeration","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.new_member_defaults.subscription_pct","entity":"tariffs","type":"percent","portability":"literal","absent":"product_default","min":1,"max":100,"process":"membershipCommerce"},
    {"id":"workspace.billing_rules.repartition.excluded","entity":"tariffs","type":"map","portability":"never","absent":"inherit","reason":"names people, who do not exist where a template is applied","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.repartition.method","entity":"tariffs","type":"enumeration","portability":"literal","absent":"inherit","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.repartition.weights","entity":"tariffs","type":"map","portability":"never","absent":"inherit","reason":"names people, who do not exist where a template is applied","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.subscription_advance_days","entity":"tariffs","type":"integer","portability":"literal","absent":"product_default","min":0,"process":"membershipCommerce"},
    {"id":"workspace.billing_rules.subscription_auto","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.usage_auto","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.billing_rules.usage_when_zero","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.booking_rules","entity":"booking_rules","type":"map","portability":"literal","absent":"inherit","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.admin_check_out","entity":"booking_rules","type":"boolean","portability":"literal","absent":"product_default","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.advance_horizon_days","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"max":730,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.allow_past_bookings","entity":"booking_rules","type":"boolean","portability":"literal","absent":"product_default","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.full_day_hours","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.granularity","entity":"booking_rules","type":"enumeration","portability":"literal","absent":"product_default","values":["flexible","half_day","minutes_5","minutes_15","minutes_30","minutes_60","full_day","hours"],"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.grid_within_hours","entity":"booking_rules","type":"boolean","portability":"unsupported","absent":"inherit","reason":"retired by #634; read as outside_hours_mode, never written","process":"reservationsUsage"},
    {"id":"workspace.booking_rules.half_boundary_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":0,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.half_day_hours","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.legend_profile","entity":"booking_rules","type":"enumeration","portability":"literal","absent":"product_default","values":["full","simple"],"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.max_duration_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":5,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.max_series_days","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.min_duration_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":5,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.open_weekdays","entity":"booking_rules","type":"list","portability":"literal","absent":"product_default","min":1,"max":7,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.outside_hours_mode","entity":"booking_rules","type":"enumeration","portability":"literal","absent":"product_default","values":["off","free","charged","walkup_only"],"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.simultaneous_reservations","entity":"booking_rules","type":"integer","portability":"literal","absent":"product_default","min":1,"max":20,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.work_end_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":0,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.booking_rules.work_start_minutes","entity":"booking_rules","type":"minutes","portability":"literal","absent":"product_default","min":0,"max":1440,"process":"reservationsUsage"},
    {"id":"workspace.branding","entity":"branding","type":"map","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.branding.office_palette","entity":"branding","type":"list","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.branding.seat_palette","entity":"branding","type":"enumeration","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.branding.seed_color","entity":"branding","type":"color","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.city","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.company_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.country_code","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.created_at","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.created_by","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.created_by_user","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.created_datetime","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.currency_code","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.default_locale","entity":"identity","type":"locale","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.desk_opacity","entity":"booking_rules","type":"percent","portability":"literal","absent":"product_default","min":20,"max":100,"process":"reservationsUsage"},
    {"id":"workspace.dev_mode","entity":"workspace","type":"boolean","portability":"never","absent":"inherit","reason":"this space's own switch","process":"operations"},
    {"id":"workspace.dunning_rules","entity":"reminders","type":"map","portability":"literal","absent":"inherit","process":"billingPayments"},
    {"id":"workspace.dunning_rules.automatic","entity":"reminders","type":"boolean","portability":"literal","absent":"product_default","process":"billingPayments"},
    {"id":"workspace.dunning_rules.between_days","entity":"reminders","type":"integer","portability":"literal","absent":"product_default","min":0,"process":"billingPayments"},
    {"id":"workspace.dunning_rules.first_after_days","entity":"reminders","type":"integer","portability":"literal","absent":"product_default","min":0,"process":"billingPayments"},
    {"id":"workspace.dunning_rules.levels","entity":"reminders","type":"integer","portability":"literal","absent":"product_default","min":1,"max":9,"process":"billingPayments"},
    {"id":"workspace.environment","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.feature_flags","entity":"features","type":"map","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.feature_flags.accessorySupplements","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.accountingBook","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.adminInvoicing","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.adminLevelAssign","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.levelBooking"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.adminSeatBlocking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.autoCheckInOut","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.badgeSignIn","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.nfcBadges"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.bookForOthers","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.bookingGate","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.bookingPolicies"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.bookingPolicies","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.calendarFileExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.calendarHub","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarTab"],"process":"coordination"},
    {"id":"workspace.feature_flags.calendarTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.calendarValidations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarHub"],"process":"coordination"},
    {"id":"workspace.feature_flags.calendarViews","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.calendarHub"],"process":"coordination"},
    {"id":"workspace.feature_flags.capacityKpi","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.captureProtection","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.carnets","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.coOwner","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.configurableSettings","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.configurationTransfer","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dataExport"],"process":"operations"},
    {"id":"workspace.feature_flags.customFields","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.customRoles","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.dataAccessLog","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.dataExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.decisionSurface","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.deletionRequests","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.demoMode","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.deployments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.environmentPairs"],"process":"operations"},
    {"id":"workspace.feature_flags.documents","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.dunning","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.einvoiceCustomerDelivery","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"integrations"},
    {"id":"workspace.feature_flags.environmentPairs","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.eventsTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.expenseRepartition","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.expenseRepartitionWizard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.expenseRepartition"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.financeFaces","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.formHelpHints","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.guestParticipation","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.holidayImport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.publicHolidays"],"process":"spaceManagement"},
    {"id":"workspace.feature_flags.inputVat","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatDeclarations"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.instanceWizard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.invoiceAddressWindow","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.invoiceJourney","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoicePdfTemplate","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.invoiceSettlement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoicing","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.invoicingWizard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.kioskMemberPhotos","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.kioskMode","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.letterStandard","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportLayouts"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.levelBooking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.managedProfileAccess","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.managedProfiles"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.managedProfiles","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.mcpAccess","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"integrations"},
    {"id":"workspace.feature_flags.meetingRooms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.memberAccountMenu","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.memberDataExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.memberEnvironments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.environmentPairs"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.memberGettingStarted","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.memberNotifications","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.memberOrigin","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.memberPage","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.memberPaymentTerms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.memberReports","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.membersDirectory","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.messageForwarding","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.messageGestures","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.messageMentions","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.messagesHub","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.moneyTab","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"billingPayments"},
    {"id":"workspace.feature_flags.multiSite","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.navigationStyle","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.nfcBadges","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.nfcSeatTags","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.notificationGrouping","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.eventsTab"],"process":"coordination"},
    {"id":"workspace.feature_flags.numberSequences","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.onlinePayments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.parking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.paymentReminders","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.dunning"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.pdfExport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.personalInfo","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.placeFeedback","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.planMemberPhotos","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.planObjectDelete","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.priceNegotiations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.publicHolidays","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.publicListings","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.purchases","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.pushNotifications","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"integrations"},
    {"id":"workspace.feature_flags.qrBadges","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.kioskMode"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.recapitulativeStatement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatDeclarations"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.recordingPrivacy","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"documentsInformation"},
    {"id":"workspace.feature_flags.regionalFormats","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.reportDesignExchange","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportDesigner","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicePdfTemplate"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportLayouts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.reportTexts","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.reportDesigner"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.richMessageRefs","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.memberNotifications"],"process":"coordination"},
    {"id":"workspace.feature_flags.roleAssignment","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.roleManagement"],"process":"workspaceAccess"},
    {"id":"workspace.feature_flags.roleManagement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.salesTax","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.scheduledExpenses","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.seatDayTimeline","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.seriesBooking","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"reservationsUsage"},
    {"id":"workspace.feature_flags.services","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.moneyTab"],"process":"membershipCommerce"},
    {"id":"workspace.feature_flags.settlementFold","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoiceSettlement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.singleRoomLevelNames","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.siteDocuments","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.multiSite"],"process":"operations"},
    {"id":"workspace.feature_flags.spaceInquiries","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.spaceQrCodes","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.feature_flags.subscriptionInvoices","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.supplyClassification","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.supplyExpenses","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.services"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.taskRecorder","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.uiAnimations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.uniqueMonograms","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.usageInvoices","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.usageRecords","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"reservationsUsage"},
    {"id":"workspace.feature_flags.usageReport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.usageRecords"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.validationChain","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.validationScopes","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"coordination"},
    {"id":"workspace.feature_flags.vatCounterparty","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatDeclarations","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatGroups","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatManagement","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatRateHistory","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatManagement"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.vatReport","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.vatDeclarations"],"process":"documentsInformation"},
    {"id":"workspace.feature_flags.viesVerification","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.supplyClassification"],"process":"billingPayments"},
    {"id":"workspace.feature_flags.webMcp","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.mcpAccess"],"process":"integrations"},
    {"id":"workspace.feature_flags.whatsappIntegration","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.membersDirectory"],"process":"integrations"},
    {"id":"workspace.feature_flags.workingHours","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.workspaceBranding","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.feature_flags.workspaceLibrary","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"operations"},
    {"id":"workspace.feature_flags.workspaceStatus","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","depends_on":["workspace.feature_flags.invoicing"],"process":"operations"},
    {"id":"workspace.feature_flags.workspaceVocabulary","entity":"features","type":"boolean","portability":"literal","absent":"registry_default","process":"spaceManagement"},
    {"id":"workspace.id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.invitation_template","entity":"invitations","type":"text","portability":"never","absent":"inherit","reason":"names the source space and its people","process":"workspaceAccess"},
    {"id":"workspace.invitation_templates","entity":"invitations","type":"text","portability":"never","absent":"inherit","reason":"names the source space and its people","process":"workspaceAccess"},
    {"id":"workspace.invite_code","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"a secret","process":"operations"},
    {"id":"workspace.invoice_legal","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.invoice_pdf_template","entity":"document_design","type":"map","portability":"never","absent":"inherit","reason":"points at the source's image library; travels with the report design exchange","process":"documentsInformation"},
    {"id":"workspace.legal_id","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.lexicon","entity":"lexicon","type":"map","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.deskDetail","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.directoryTitle","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendBlocked","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendClosed","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendFree","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendMine","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendOccupied","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendReserved","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.legendUnavailable","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.levelDetail","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.levelReserveButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.messagesTitle","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planAfternoonChip","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planBookForLabel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planCheckInButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planCheckInTitle","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planDurationLabel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planFromLabel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planMorningChip","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.planReserveButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveClosedShort","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveDayView","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveFullDayChip","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveMonthView","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.reserveWeekView","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.shellReserveButton","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindDesk","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindLevel","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindOffice","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.spaceKindSeat","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabCalendar","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabEvents","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabMoney","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.lexicon.{locale}.tabPlan","entity":"lexicon","type":"text","portability":"literal","absent":"inherit","process":"operations"},
    {"id":"workspace.modified_by_user","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.modified_datetime","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.name","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.pair_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.payment_instructions.iban","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.lydia","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.paypal_me","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.reference","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.wero","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.payment_instructions.wise","entity":"payment_instructions","type":"text","portability":"never","absent":"inherit","reason":"bank details are the source's own","process":"billingPayments"},
    {"id":"workspace.postal_code","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.role_permissions","entity":"roles","type":"map","portability":"literal","absent":"registry_default","process":"workspaceAccess"},
    {"id":"workspace.role_permissions.admin","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd","viewAnalytics","useMessages","makeReservations","viewCalendar","viewDirectory","viewMyMoney","viewDocuments","managePurchases","recordOutgoingPayments"],"process":"workspaceAccess"},
    {"id":"workspace.role_permissions.co_owner","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd","viewAnalytics","useMessages","makeReservations","viewCalendar","viewDirectory","viewMyMoney","viewDocuments","managePurchases","recordOutgoingPayments"],"process":"workspaceAccess"},
    {"id":"workspace.role_permissions.member","entity":"roles","type":"list","portability":"literal","absent":"registry_default","values":["manageRoles","manageMembers","manageValidation","workspaceSettings","issueInvoices","viewFinances","manageDocuments","manageServices","approveExpenses","viewNegotiations","manageNegotiations","paymentTermsEdit","manageSites","manageBilling","manageReservations","operateKiosk","exportData","designDocuments","viewPersonalData","manageIntegrations","manageConfiguration","deployToProd","deployToDev","accessProd","viewAnalytics","useMessages","makeReservations","viewCalendar","viewDirectory","viewMyMoney","viewDocuments","managePurchases","recordOutgoingPayments"],"process":"workspaceAccess"},
    {"id":"workspace.site_id","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"which row and which twin this is","process":"operations"},
    {"id":"workspace.street","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.subscription_levels","entity":"tariffs","type":"map","portability":"literal","absent":"inherit","process":"membershipCommerce"},
    {"id":"workspace.subscription_levels.allow_custom","entity":"tariffs","type":"boolean","portability":"literal","absent":"product_default","process":"membershipCommerce"},
    {"id":"workspace.subscription_levels.enabled_presets","entity":"tariffs","type":"list","portability":"literal","absent":"product_default","min":1,"max":100,"process":"membershipCommerce"},
    {"id":"workspace.subscription_levels.extra_levels","entity":"tariffs","type":"list","portability":"literal","absent":"product_default","min":1,"max":100,"process":"membershipCommerce"},
    {"id":"workspace.subscription_vat_rate","entity":"vat","type":"text","portability":"reference","absent":"inherit","bindings":["vat_rates.label"],"process":"billingPayments"},
    {"id":"workspace.tax_exemption_reason","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.timezone","entity":"workspace","type":"text","portability":"local_binding","absent":"required","reason":"the new space says who and where it is","process":"operations"},
    {"id":"workspace.vat_account","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.vat_id","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"},
    {"id":"workspace.vat_regime","entity":"identity","type":"enumeration","portability":"literal","absent":"product_default","process":"operations"},
    {"id":"workspace.visibility","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"the space's own listing choice; a template must not publish a space","process":"operations"},
    {"id":"workspace.visibility_set_at","entity":"workspace","type":"text","portability":"never","absent":"inherit","reason":"the space's own listing choice; a template must not publish a space","process":"operations"},
    {"id":"workspace.whatsapp_group","entity":"identity","type":"text","portability":"never","absent":"inherit","reason":"the source's own identity","process":"operations"}
  ]$json$::jsonb
$registry$;
revoke execute on function public.template_field_registry() from public, anon;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(467);
