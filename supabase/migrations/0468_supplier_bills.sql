-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0468 (#2574, C2b of #2464) -- a supplier bill is submitted, decided by a
-- second person, becomes what the space owes the supplier, and is paid.
--
--   * `submit_purchase_v1` (restated) sends a captured bill to approval:
--     supplier required, still to be paid, an amount. A credit note stays a
--     draft until it is applied to its bill (a later step).
--   * `decide_purchase_v1`: someone holding approveExpenses other than the
--     submitter approves or rejects. Approval snapshots the supplier and the
--     recipient and files the obligation (creditor kind `supplier`); nothing
--     else is written -- no ledger row, no cash, no tax line. Rejection
--     files nothing. The decision is stored on the document
--     (`decided_by_member_id`), frozen like every decided document.
--   * `record_supplier_payment_v1`: the same payment/allocation records as a
--     member's reimbursement (0467), without a member-account effect: a
--     supplier's payable is not in a member's ledger. Reporting a payment is
--     not bank verification. `reverse_purchase_allocation_v1` (restated)
--     reverses either kind.
--   * `purchase_obligation_json` names the supplier creditor.
--
-- Not here: maker-checker policy beyond the two-person rule, offsetting a
-- credit note, posting (#2365), statement reconciliation (#2380).

alter table public.purchase_documents
  add column decided_by_member_id uuid,
  add column decided_at timestamptz,
  add column decision_reason text not null default '' check (char_length(decision_reason) <= 300);
alter table public.purchase_documents
  add constraint purchase_documents_decider_fkey
  foreign key (workspace_id, decided_by_member_id) references public.members (workspace_id, id);

-- An approved document is approved by an expense event (a member receipt) or
-- by a person (a supplier bill).
alter table public.purchase_documents drop constraint purchase_documents_check4;
alter table public.purchase_documents add constraint purchase_documents_approval_check
  check ((state = 'approved') = (approved_event_id is not null
                                 or (decided_by_member_id is not null and state <> 'rejected')));

create or replace function public.purchase_documents_guard()
returns trigger language plpgsql as $fn$
declare
  o jsonb := to_jsonb(old) - public.system_column_names();
  n jsonb := to_jsonb(new) - public.system_column_names();
  v_open text[] := array['state', 'approved_event_id', 'recipient_snapshot',
                         'supplier_snapshot', 'legacy_decided_at',
                         'decided_by_member_id', 'decided_at', 'decision_reason'];
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

-- A supplier payment has no member-account row.
alter table public.purchase_settlement_allocations alter column ledger_entry_id drop not null;

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
  if v_doc.kind = 'credit_note' then
    raise exception 'a credit note is applied to its bill in a later step';
  end if;
  if v_doc.state <> 'draft' then raise exception 'only a draft can be submitted'; end if;
  if v_doc.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if v_doc.kind = 'bill' then
    -- A supplier bill goes to a second person: the submitter captured it
    -- (managePurchases, checked on the draft), the approver decides it.
    if not public.has_permission(p_workspace_id, 'managePurchases') then
      raise exception 'not allowed to capture supplier bills';
    end if;
    if v_doc.supplier_id is null then raise exception 'a bill needs its supplier'; end if;
    if v_doc.payer_kind <> 'unpaid' then
      raise exception 'only a bill still to be paid goes to approval';
    end if;
    select count(*), coalesce(sum(gross_cents), 0) into v_lines, v_gross
      from public.purchase_lines where purchase_id = v_doc.id;
    if v_lines = 0 or v_gross <= 0 then raise exception 'a bill needs an amount'; end if;
    if v_gross > 2147483647 then raise exception 'the amount of a bill is too large'; end if;
    update public.purchase_documents set state = 'pending' where id = v_doc.id;
    v_result := jsonb_build_object('purchase_id', v_doc.id, 'revision', v_doc.revision,
                                   'state', 'pending');
    return public.purchase_request_end(p_workspace_id, p_request_id, 'submit', v_digest, v_result);
  end if;
  if v_doc.submitter_member_id <> v_me then raise exception 'not your purchase'; end if;
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


create or replace function public.decide_purchase_v1(
  p_workspace_id uuid, p_purchase_id uuid, p_revision int, p_approve boolean,
  p_reason text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  d public.purchase_documents;
  v_gross bigint;
  v_supplier jsonb;
  v_obligation uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.has_permission(p_workspace_id, 'approveExpenses') then
    raise exception 'you may not decide purchases';
  end if;
  v_digest := md5(v_me::text || p_purchase_id::text || coalesce(p_revision, 0)::text
                  || coalesce(p_approve, false)::text || btrim(coalesce(p_reason, '')));
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'decide', v_digest);
  if v_done is not null then return v_done; end if;

  select * into d from public.purchase_documents
   where id = p_purchase_id and workspace_id = p_workspace_id for update;
  if d.id is null then raise exception 'unknown purchase'; end if;
  if d.kind <> 'bill' then raise exception 'only a supplier bill is decided here'; end if;
  if d.state <> 'pending' then raise exception 'only a purchase awaiting approval is decided'; end if;
  if d.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if d.submitter_member_id = v_me then
    raise exception 'another person must decide a purchase you submitted';
  end if;
  if p_approve is null then raise exception 'approve or reject'; end if;
  if not p_approve and btrim(coalesce(p_reason, '')) = '' then
    raise exception 'state why it is rejected';
  end if;

  if p_approve then
    select coalesce(sum(gross_cents), 0) into v_gross
      from public.purchase_lines where purchase_id = d.id;
    select jsonb_build_object('supplier_id', s.id, 'supplier_number', s.supplier_number,
                              'name', s.name, 'tax_identifier', s.tax_identifier,
                              'street', s.street, 'postal_code', s.postal_code,
                              'city', s.city, 'country_code', s.country_code,
                              'bank_revision', s.bank_revision)
      into v_supplier from public.suppliers s
     where s.id = d.supplier_id and s.workspace_id = d.workspace_id;
    if v_supplier is null then raise exception 'unknown supplier'; end if;
    update public.purchase_documents
       set state = 'approved', decided_by_member_id = v_me, decided_at = now(),
           supplier_snapshot = v_supplier,
           recipient_snapshot = (select jsonb_build_object('workspace_id', w.id, 'name', w.name,
                                        'country_code', w.country_code)
                                   from public.workspaces w where w.id = d.workspace_id)
     where id = d.id;
    insert into public.purchase_obligations
      (workspace_id, purchase_id, creditor_kind, creditor_supplier_id, amount_cents, currency, due_on)
    values (d.workspace_id, d.id, 'supplier', d.supplier_id, v_gross, d.currency, d.due_on)
    returning id into v_obligation;
  else
    update public.purchase_documents
       set state = 'rejected', decided_by_member_id = v_me, decided_at = now(),
           decision_reason = left(btrim(p_reason), 300)
     where id = d.id;
  end if;
  v_result := jsonb_build_object('purchase_id', d.id,
    'state', case when p_approve then 'approved' else 'rejected' end,
    'obligation_id', v_obligation);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'decide', v_digest, v_result);
end;
$fn$;
revoke execute on function public.decide_purchase_v1(uuid, uuid, int, boolean, text, uuid) from public, anon;
grant execute on function public.decide_purchase_v1(uuid, uuid, int, boolean, text, uuid) to authenticated;

create or replace function public.record_supplier_payment_v1(
  p_workspace_id uuid, p_obligation_id uuid, p_amount_cents bigint, p_revision int,
  p_request_id uuid, p_paid_on date, p_method text default 'bank_transfer',
  p_reference text default ''
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  o public.purchase_obligations;
  v_tz text;
  v_paid bigint;
  v_payment uuid;
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
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'pay_supplier', v_digest);
  if v_done is not null then return v_done; end if;

  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  select * into o from public.purchase_obligations
   where id = p_obligation_id and workspace_id = p_workspace_id for update;
  if o.id is null then raise exception 'unknown obligation'; end if;
  if o.creditor_kind <> 'supplier' then
    raise exception 'a member is reimbursed through the claim';
  end if;
  if o.state <> 'open' then raise exception 'this payable is not open'; end if;
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
  select coalesce(sum(a.amount_cents), 0) into v_paid
    from public.purchase_settlement_allocations a
   where a.workspace_id = o.workspace_id and a.obligation_id = o.id;
  if p_amount_cents > o.amount_cents - v_paid then
    raise exception 'the amount exceeds what remains of the payable';
  end if;
  if p_amount_cents > 2147483647 then raise exception 'the amount is too large'; end if;

  insert into public.outgoing_payments
    (workspace_id, payee_kind, payee_supplier_id, currency, amount_cents, method,
     reported_paid_on, reference, state, actor_member_id, request_id)
  values (o.workspace_id, 'supplier', o.creditor_supplier_id, o.currency, p_amount_cents,
          p_method, p_paid_on, left(coalesce(p_reference, ''), 200), 'reported', v_me, p_request_id)
  returning id into v_payment;
  insert into public.purchase_settlement_allocations
    (workspace_id, obligation_id, payment_id, kind, amount_cents, request_id, actor_member_id)
  values (o.workspace_id, o.id, v_payment, 'payment', p_amount_cents, p_request_id, v_me)
  returning id into v_alloc;
  update public.purchase_obligations set revision = revision + 1 where id = o.id;

  select public.purchase_obligation_json(po) into v_result
    from public.purchase_obligations po where po.id = o.id;
  v_result := jsonb_build_object('payment_id', v_payment, 'allocation_id', v_alloc,
                                 'obligation', v_result);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'pay_supplier', v_digest, v_result);
end;
$fn$;
revoke execute on function public.record_supplier_payment_v1(uuid, uuid, bigint, int, uuid, date, text, text)
  from public, anon;
grant execute on function public.record_supplier_payment_v1(uuid, uuid, bigint, int, uuid, date, text, text)
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
  if o.creditor_kind = 'member' and public.purchase_obligation_invoice(o) is not null then
    raise exception 'this claim is already applied to an invoice';
  end if;
  if o.creditor_kind = 'member' then
    select * into c from public.ledger_entries where id = o.legacy_member_credit_id;
    insert into public.ledger_entries
      (workspace_id, member_id, kind, category, amount_cents, description, period,
       occurred_on, vat_percent)
    values (o.workspace_id, o.creditor_member_id, 'credit', 'reimbursement', a.amount_cents::int,
            left(btrim(p_reason), 200), c.period, null, 0)
    returning id into v_ledger;
  end if;
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
    'creditor_name', (select s.name from public.suppliers s
                       where s.workspace_id = p_ob.workspace_id and s.id = p_ob.creditor_supplier_id),
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

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(468);
