-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0469 (#2574, C2c of #2464) -- a member's claim offset against an invoice
-- of the same member.
--
--   * `offset_member_claim_v1`: instead of paying the member in cash, the
--     claim settles (all or part of) one of the member's own open invoices.
--     In one transaction: the claim's credit is reduced by a `reimbursement`
--     charge (like a cash payment, 0467); a `payment` credit of the same
--     amount is registered for the member and matched to the invoice by the
--     existing `match_invoice` -- so the invoice keeps its gross sales and
--     VAT, only its settlement is explained; the allocation of kind
--     `offset` links claim and invoice. The offset is refused when a
--     validation policy would hold the match (the claim must not fall
--     without the invoice standing paid), when the invoice is the one that
--     already applied the claim, for a stranger's invoice, for more than
--     the invoice still owes or the claim still has, and for one's own claim.
--   * An offset is not reversed here (it follows the match's own undoing).
--   * `purchase_obligation_json` lists offsets beside payments.
--
-- Not here: offsets across entities, currencies or third parties (refused by
-- construction: the invoice must be the claimant's own, in the claim's
-- currency), automatic netting.

alter table public.purchase_settlement_allocations
  alter column payment_id drop not null,
  add column invoice_id uuid references public.invoices(id);

alter table public.purchase_settlement_allocations
  drop constraint purchase_settlement_allocations_kind_check,
  drop constraint purchase_settlement_allocations_check;
alter table public.purchase_settlement_allocations
  add constraint purchase_settlement_allocations_kind_check
    check (kind in ('payment', 'reversal', 'offset')),
  add constraint purchase_settlement_allocations_sign_check
    check ((kind in ('payment', 'offset')) = (amount_cents > 0)),
  add constraint purchase_settlement_allocations_source_check
    check ((kind = 'offset') = (invoice_id is not null)
           and (kind = 'offset') = (payment_id is null));

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
        'method', case when a.kind = 'offset' then 'offset' else p.method end,
        'reference', case when a.kind = 'offset'
                          then (select i.number from public.invoices i where i.id = a.invoice_id)
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

create or replace function public.offset_member_claim_v1(
  p_workspace_id uuid, p_obligation_id uuid, p_invoice_id uuid, p_amount_cents bigint,
  p_revision int, p_request_id uuid, p_note text default ''
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_digest text;
  v_done jsonb;
  o public.purchase_obligations;
  c public.ledger_entries;
  i public.invoices;
  v_match public.invoice_matches;
  v_paid bigint;
  v_due bigint;
  v_resolution text;
  v_note text := btrim(coalesce(p_note, ''));
  v_payment_ledger uuid;
  v_ledger uuid;
  v_alloc uuid;
  v_applied jsonb;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  if not public.has_permission(p_workspace_id, 'recordOutgoingPayments') then
    raise exception 'you may not record outgoing payments';
  end if;
  v_digest := md5(v_me::text || p_obligation_id::text || p_invoice_id::text
                  || coalesce(p_amount_cents, 0)::text || coalesce(p_revision, 0)::text || v_note);
  v_done := public.purchase_request_begin(p_workspace_id, p_request_id, 'offset', v_digest);
  if v_done is not null then return v_done; end if;

  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  select * into o from public.purchase_obligations
   where id = p_obligation_id and workspace_id = p_workspace_id for update;
  if o.id is null then raise exception 'unknown obligation'; end if;
  if o.creditor_kind <> 'member' then raise exception 'only a member''s claim is offset'; end if;
  if o.creditor_member_id = v_me then
    raise exception 'another person must offset your own claim';
  end if;
  if o.state <> 'open' then raise exception 'this claim is not open'; end if;
  if o.revision <> coalesce(p_revision, 0) then raise exception 'stale revision'; end if;
  if coalesce(p_amount_cents, 0) <= 0 then raise exception 'the amount must be positive'; end if;
  if p_amount_cents > 2147483647 then raise exception 'the amount is too large'; end if;
  if o.legacy_member_credit_id is null then
    raise exception 'the credit of this claim is not identified; review it first';
  end if;
  select * into c from public.ledger_entries where id = o.legacy_member_credit_id;
  v_applied := public.purchase_obligation_invoice(o);
  if v_applied is not null then raise exception 'this claim is already applied to an invoice'; end if;

  select * into i from public.invoices
   where id = p_invoice_id and workspace_id = p_workspace_id;
  if i.id is null or i.member_id <> o.creditor_member_id then
    raise exception 'an invoice of the same member';
  end if;
  if i.currency <> o.currency then raise exception 'an invoice in the currency of the claim'; end if;
  if i.voided_at is not null or i.total_cents <= 0 then
    raise exception 'an open invoice to settle';
  end if;
  if i.settled_by_invoice_id is not null then raise exception 'an open invoice to settle'; end if;
  select * into v_match from public.invoice_matches where invoice_id = i.id;
  v_due := i.total_cents - coalesce(v_match.paid_cents, 0);
  if v_match.invoice_id is not null and
     (v_match.status <> 'confirmed' or v_match.resolution <> 'under_accepted'
      or v_match.writeoff_at is not null) then
    raise exception 'an open invoice to settle';
  end if;
  if p_amount_cents > v_due then raise exception 'the amount exceeds what the invoice still owes'; end if;
  select coalesce(sum(a.amount_cents), 0) into v_paid
    from public.purchase_settlement_allocations a
   where a.workspace_id = o.workspace_id and a.obligation_id = o.id;
  if p_amount_cents > o.amount_cents - v_paid then
    raise exception 'the amount exceeds what remains of the claim';
  end if;
  v_resolution := case when p_amount_cents = v_due then 'exact' else 'under_accepted' end;
  if v_resolution = 'under_accepted' and v_note = '' then
    v_note := 'part offset against an expense claim';
  end if;

  -- 1. the claim falls by the offset, like a cash payment
  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period,
     occurred_on, vat_percent)
  values (o.workspace_id, o.creditor_member_id, 'charge', 'reimbursement', p_amount_cents::int,
          left('Offset against ' || i.number, 200), c.period, null, 0)
  returning id into v_ledger;
  -- 2. a registered payment of the same amount, matched to the invoice
  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
  values (o.workspace_id, o.creditor_member_id, 'credit', 'payment', p_amount_cents::int,
          left('Offset of an expense claim against ' || i.number, 200),
          to_char(now(), 'YYYY-MM'), null)
  returning id into v_payment_ledger;
  perform public.match_invoice(i.id, v_payment_ledger, v_resolution, v_note);
  if not exists (select 1 from public.invoice_matches im
                  where im.invoice_id = i.id and im.status = 'confirmed') then
    raise exception 'a validation policy holds invoice payments; the offset is refused';
  end if;
  -- 3. the allocation, and the claim moves on
  insert into public.purchase_settlement_allocations
    (workspace_id, obligation_id, kind, amount_cents, invoice_id, ledger_entry_id,
     request_id, actor_member_id)
  values (o.workspace_id, o.id, 'offset', p_amount_cents, i.id, v_ledger, p_request_id, v_me)
  returning id into v_alloc;
  update public.purchase_obligations set revision = revision + 1 where id = o.id;

  select public.purchase_obligation_json(po) into v_result
    from public.purchase_obligations po where po.id = o.id;
  v_result := jsonb_build_object('allocation_id', v_alloc, 'invoice_id', i.id,
                                 'resolution', v_resolution, 'obligation', v_result);
  return public.purchase_request_end(p_workspace_id, p_request_id, 'offset', v_digest, v_result);
end;
$fn$;
revoke execute on function public.offset_member_claim_v1(uuid, uuid, uuid, bigint, int, uuid, text)
  from public, anon;
grant execute on function public.offset_member_claim_v1(uuid, uuid, uuid, bigint, int, uuid, text)
  to authenticated;


notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(469);
