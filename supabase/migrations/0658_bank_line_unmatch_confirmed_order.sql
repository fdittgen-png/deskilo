-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (unmatch_bank_line_in_v1 restated whole from 0657, its latest body)
--
-- 0658 (#2380) -- the payment a part-paid match is restated from is the
-- latest one by its CONFIRMATION. 0657 ordered the remaining payments by
-- invoice_match_payments.matched_at, which is the submission. A payment
-- that a validation released is booked when it was confirmed: 0101 sets the
-- aggregate's matched_at to the moment of the decision (events.decided_at).
-- So undoing another payment could back-date the surviving match into the
-- submission's period, pick the wrong latest payment, or refuse DKB06 for a
-- closed period that the confirmation was not in.
--
-- Each payment is now dated by coalesce(events.decided_at, matched_at) of its
-- own event: the latest by that date gives the restated match its link,
-- note and date, and the closed-period checks read the same dates. A
-- payment without an event keeps its own matched_at, as before.

create or replace function public.unmatch_bank_line_in_v1(
  p_line_id uuid, p_reason text, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_me uuid;
  v_line public.bank_statement_lines;
  v_invoice public.invoices;
  v_match public.invoice_matches;
  v_pay public.invoice_match_payments;
  v_rest public.invoice_match_payments;
  v_rest_id uuid;
  v_rest_at timestamptz;
  v_event public.events;
  v_done public.bank_line_unmatches;
  v_unmatch uuid := gen_random_uuid();
  v_reversal uuid := gen_random_uuid();
  v_reason text := left(btrim(coalesce(p_reason, '')), 300);
begin
  -- Authorised first, locked after: an unknown line reads as one the
  -- caller may not act on.
  select workspace_id into v_ws from public.bank_statement_lines where id = p_line_id;
  if v_ws is null then raise exception 'you may not do this for the bank statements' using errcode = '42501'; end if;
  v_me := public.bank_import_actor(v_ws, 'issueInvoices');
  if p_request_id is null then
    raise exception 'a request id is required' using errcode = '22023';
  end if;
  -- The order of the locks is fixed: the line, the invoice, its links.
  select * into v_line from public.bank_statement_lines where id = p_line_id for update;
  -- The same request again answers what it answered and changes nothing.
  select * into v_done from public.bank_line_unmatches
   where workspace_id = v_ws and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.line_id <> p_line_id then
      raise exception 'this request id was already used for a different request' using errcode = '22023';
    end if;
    return jsonb_build_object('id', p_line_id, 'invoice_id', v_done.invoice_id,
      'payment_ledger_id', v_done.payment_ledger_id, 'unmatch_id', v_done.id,
      'status', public.bank_line_status(v_line));
  end if;
  if v_reason = '' then
    raise exception 'state why the match is undone' using errcode = '22023';
  end if;
  if v_line.amount_cents <= 0 then
    raise exception 'money out settles no invoice: undo its reconciliation' using errcode = 'DKB02';
  end if;
  if v_line.payment_ledger_id is null or v_line.invoice_id is null then
    raise exception 'this movement settles no invoice' using errcode = 'DKB01';
  end if;
  select * into v_invoice from public.invoices
   where id = v_line.invoice_id and workspace_id = v_ws for update;
  select * into v_match from public.invoice_matches where invoice_id = v_invoice.id for update;
  select * into v_pay from public.invoice_match_payments
   where invoice_id = v_invoice.id and payment_ledger_id = v_line.payment_ledger_id for update;
  -- The state is read AGAIN under the locks: what was true when the screen
  -- was drawn is not what is decided on.
  if v_invoice.id is null or v_match.invoice_id is null or v_pay.invoice_id is null then
    raise exception 'this movement settles no invoice' using errcode = 'DKB01';
  end if;
  select * into v_event from public.events where id = v_pay.event_id;
  if v_match.status is distinct from 'confirmed' or v_event.status is distinct from 'confirmed' then
    raise exception 'this match awaits its validation: reject it there' using errcode = 'DKB01';
  end if;
  if v_pay.resolution = 'over_credit_note' or v_pay.credit_ledger_id is not null
     or v_match.credit_ledger_id is not null or v_match.writeoff_at is not null
     or v_invoice.settled_by_invoice_id is not null
     or exists (select 1 from public.invoices s where s.settled_by_invoice_id = v_invoice.id) then
    raise exception 'this match did more than link a payment: it cannot be undone here' using errcode = 'DKB04';
  end if;
  -- The aggregate must be the sum of its payments: a match whose amount the
  -- payments do not explain is not restated by guesswork.
  if v_match.paid_cents is distinct from
     (select sum(amount_cents) from public.invoice_match_payments where invoice_id = v_invoice.id) then
    raise exception 'the payments of this invoice do not add up to its match' using errcode = 'DKB05';
  end if;
  -- What remains: the latest other payment BY ITS CONFIRMATION, which the
  -- match is restated from. A payment a validation released is booked when
  -- it was confirmed (0101 dates the aggregate then), not when submitted.
  select p.id, coalesce(e.decided_at, p.matched_at) into v_rest_id, v_rest_at
    from public.invoice_match_payments p left join public.events e on e.id = p.event_id
   where p.invoice_id = v_invoice.id and p.payment_ledger_id <> v_line.payment_ledger_id
   order by coalesce(e.decided_at, p.matched_at) desc, p.id desc limit 1;
  select * into v_rest from public.invoice_match_payments where id = v_rest_id;
  -- The payment undone, the match and the date the match would take: none
  -- of them may stand in a closed period of the books.
  if public.book_period_closed(v_ws, public.book_local_day(v_ws,
       coalesce(v_match.writeoff_at, v_event.decided_at, v_pay.matched_at)))
     or public.book_period_closed(v_ws, public.book_local_day(v_ws, coalesce(v_match.writeoff_at, v_match.matched_at)))
     or (v_rest.invoice_id is not null and public.book_period_closed(v_ws,
           public.book_local_day(v_ws, coalesce(v_match.writeoff_at, v_rest_at)))) then
    raise exception 'this payment is dated inside a closed period of the books' using errcode = 'DKB06';
  end if;

  -- The record of the reversal first, then the match goes; the credit stays.
  -- The subject is the acting staff member, never the invoice's member (events_select
  -- lets a subject read its events), and the reason is not in the payload: it
  -- stays in bank_line_unmatches, which the invoice's member cannot read.
  insert into public.events
    (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status, decided_at)
  values
    (v_reversal, v_ws, 'invoice_payment_reversed', 'created', v_me, v_me,
     jsonb_build_object(
       'invoice_id', v_invoice.id, 'number', v_invoice.number,
       'line_id', v_line.id, 'payment_ledger_id', v_line.payment_ledger_id,
       'amount_cents', v_pay.amount_cents, 'resolution', v_pay.resolution,
       'original_event_id', v_pay.event_id, 'unmatch_id', v_unmatch),
     'applied', now());
  insert into public.bank_line_unmatches
    (id, workspace_id, line_id, invoice_id, payment_ledger_id, amount_cents, resolution,
     matched_by_member_id, matched_at, original_event_id, reversal_event_id,
     reason, request_id, actor_member_id)
  values
    (v_unmatch, v_ws, v_line.id, v_invoice.id, v_line.payment_ledger_id, v_pay.amount_cents,
     v_pay.resolution, v_line.matched_by_member_id, v_line.matched_at, v_pay.event_id, v_reversal,
     v_reason, p_request_id, v_me);
  delete from public.invoice_match_payments
   where invoice_id = v_invoice.id and payment_ledger_id = v_line.payment_ledger_id;
  -- The last payment of the invoice: the match goes. Otherwise the match is
  -- what the remaining payments make it, as match_invoice (0104) builds it:
  -- their sum, and the latest one's link, event, note and date. Less than the
  -- total is a part payment, accepted as such.
  if v_rest.invoice_id is null then
    delete from public.invoice_matches where invoice_id = v_invoice.id;
  else
    update public.invoice_matches
       set paid_cents = paid_cents - v_pay.amount_cents,
           resolution = case when paid_cents - v_pay.amount_cents < v_invoice.total_cents
                             then 'under_accepted' else v_rest.resolution end,
           note = coalesce(nullif(v_rest.note, ''), v_reason),
           payment_ledger_id = v_rest.payment_ledger_id,
           event_id = v_rest.event_id,
           by_name = v_rest.by_name,
           matched_at = v_rest_at
     where invoice_id = v_invoice.id;
  end if;
  update public.bank_statement_lines
     set invoice_id = null, matched_by_member_id = null, matched_at = null
   where id = v_line.id
  returning * into v_line;
  return jsonb_build_object('id', v_line.id, 'invoice_id', v_invoice.id,
    'payment_ledger_id', v_line.payment_ledger_id, 'unmatch_id', v_unmatch,
    'remaining_cents', coalesce((select paid_cents from public.invoice_matches where invoice_id = v_invoice.id), 0),
    'status', public.bank_line_status(v_line));
end;
$fn$;
revoke execute on function public.unmatch_bank_line_in_v1(uuid, text, uuid) from public, anon;
grant execute on function public.unmatch_bank_line_in_v1(uuid, text, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(658);
