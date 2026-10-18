-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0470 (#2574, C2d of #2464) -- a supplier's credit note is applied to the
-- bill it reverses.
--
--   * `apply_supplier_credit_note_v1`: someone holding approveExpenses, other
--     than the person who captured the credit note, applies a drafted credit
--     note to the open payable of its bill. The credit note becomes approved
--     (decided by that person, frozen like every decided document) and an
--     allocation of kind `credit` lowers what the space still owes. No ledger
--     row, no cash, no tax line is written; a credit note is not a payment and
--     the supplier's own correction of the invoice is a document, not money.
--   * The credit is refused for a bill that is not approved, not a supplier's,
--     not open, in another currency, for another supplier, for more than the
--     payable still has, and for a credit note without an amount.
--   * `purchase_obligation_json` lists credits beside payments and offsets.
--   * A credit is not reversed here: it follows the supplier's own correction.
--
-- Not here: a credit note larger than its bill (a refund claim on the
-- supplier), VAT recomputation (the posting engine, #2365).

alter table public.purchase_settlement_allocations
  add column credit_document_id uuid;
alter table public.purchase_settlement_allocations
  add constraint purchase_settlement_allocations_credit_fkey
  foreign key (workspace_id, credit_document_id)
  references public.purchase_documents (workspace_id, id);
create unique index purchase_settlement_allocations_one_credit
  on public.purchase_settlement_allocations (credit_document_id)
  where credit_document_id is not null;

alter table public.purchase_settlement_allocations
  drop constraint purchase_settlement_allocations_kind_check,
  drop constraint purchase_settlement_allocations_sign_check,
  drop constraint purchase_settlement_allocations_source_check;
alter table public.purchase_settlement_allocations
  add constraint purchase_settlement_allocations_kind_check
    check (kind in ('payment', 'reversal', 'offset', 'credit')),
  add constraint purchase_settlement_allocations_sign_check
    check ((kind in ('payment', 'offset', 'credit')) = (amount_cents > 0)),
  add constraint purchase_settlement_allocations_source_check
    check ((kind = 'offset') = (invoice_id is not null)
           and (kind = 'credit') = (credit_document_id is not null)
           and (kind in ('offset', 'credit')) = (payment_id is null));

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
        'paid_on', coalesce(p.reported_paid_on,
                            (a.created_datetime at time zone 'UTC')::date),
        'method', case when a.kind in ('offset', 'credit') then a.kind else p.method end,
        'reference', case a.kind
                       when 'offset' then (select i.number from public.invoices i
                                            where i.id = a.invoice_id)
                       when 'credit' then (select d.original_reference
                                             from public.purchase_documents d
                                            where d.id = a.credit_document_id)
                       else p.reference end,
        'reversed', exists (select 1 from public.purchase_settlement_allocations r
                             where r.original_allocation_id = a.id))
        order by a.created_datetime, a.id)
        from public.purchase_settlement_allocations a
        left join public.outgoing_payments p
          on p.workspace_id = a.workspace_id and p.id = a.payment_id
       where a.workspace_id = p_ob.workspace_id and a.obligation_id = p_ob.id), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.purchase_obligation_json(public.purchase_obligations)
  from public, anon, authenticated;

create or replace function public.apply_supplier_credit_note_v1(
  p_workspace_id uuid, p_credit_id uuid, p_revision int, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  d public.purchase_documents;
  b public.purchase_documents;
  o public.purchase_obligations;
  v_amount bigint;
  v_paid bigint;
  v_alloc uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.feature_effective(p_workspace_id, 'purchases') then
    raise exception 'purchases are switched off in this space';
  end if;
  if not public.has_permission(p_workspace_id, 'approveExpenses') then
    raise exception 'you may not decide purchases';
  end if;
  v_digest := md5(v_me::text || p_credit_id::text || coalesce(p_revision, 0)::text);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'apply_credit', v_digest);
  if v_done is not null then return v_done; end if;

  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  select * into d from public.purchase_documents
   where id = p_credit_id and workspace_id = p_workspace_id for update;
  if d.id is null then raise exception 'unknown purchase'; end if;
  if d.kind <> 'credit_note' then raise exception 'only a credit note is applied to a bill'; end if;
  if d.state <> 'draft' then raise exception 'this credit note is already decided'; end if;
  if d.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if d.submitter_member_id = v_me then
    raise exception 'another person must apply a credit note you captured';
  end if;
  if d.original_document_id is null then raise exception 'name the bill this credit note reverses'; end if;
  if d.supplier_id is null then raise exception 'a credit note needs its supplier'; end if;

  select * into b from public.purchase_documents
   where id = d.original_document_id and workspace_id = p_workspace_id;
  if b.id is null or b.kind <> 'bill' or b.state <> 'approved' then
    raise exception 'the bill must be approved first';
  end if;
  if b.supplier_id is distinct from d.supplier_id then
    raise exception 'the credit note and its bill have the same supplier';
  end if;
  if b.currency <> d.currency then raise exception 'the credit note is in the currency of its bill'; end if;
  select * into o from public.purchase_obligations
   where purchase_id = b.id and workspace_id = p_workspace_id and creditor_kind = 'supplier'
   for update;
  if o.id is null then raise exception 'the bill has no payable'; end if;
  if o.state <> 'open' then raise exception 'this payable is not open'; end if;

  select coalesce(sum(gross_cents), 0) into v_amount
    from public.purchase_lines where purchase_id = d.id;
  if v_amount <= 0 then raise exception 'a credit note needs an amount'; end if;
  select coalesce(sum(a.amount_cents), 0) into v_paid
    from public.purchase_settlement_allocations a
   where a.workspace_id = o.workspace_id and a.obligation_id = o.id;
  if v_amount > o.amount_cents - v_paid then
    raise exception 'the credit note exceeds what remains of the payable';
  end if;

  update public.purchase_documents
     set state = 'approved', decided_by_member_id = v_me, decided_at = now(),
         submitted_by_member_id = d.submitter_member_id,
         supplier_snapshot = b.supplier_snapshot, recipient_snapshot = b.recipient_snapshot
   where id = d.id;
  insert into public.purchase_settlement_allocations
    (workspace_id, obligation_id, kind, amount_cents, credit_document_id,
     request_id, actor_member_id)
  values (o.workspace_id, o.id, 'credit', v_amount, d.id, p_request_id, v_me)
  returning id into v_alloc;
  update public.purchase_obligations set revision = revision + 1 where id = o.id;

  select public.purchase_obligation_json(po) into v_result
    from public.purchase_obligations po where po.id = o.id;
  v_result := jsonb_build_object('allocation_id', v_alloc, 'purchase_id', d.id,
                                 'state', 'approved', 'obligation', v_result);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'apply_credit', v_digest, v_result);
end;
$fn$;
revoke execute on function public.apply_supplier_credit_note_v1(uuid, uuid, int, uuid)
  from public, anon;
grant execute on function public.apply_supplier_credit_note_v1(uuid, uuid, int, uuid)
  to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(470);
