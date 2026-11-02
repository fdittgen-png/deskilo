-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (book_period_match_guard restated whole from 0504, its latest body: one
-- branch more, for a DELETE; event_type_view_permissions restated whole from
-- 0639, one type more; events_type_check gains one type)
--
-- 0650 (#2380) -- a confirmed match of money in is undone by a person, on the
-- record. match_bank_line_v1 (0603) links a movement in to an invoice through
-- a payment credit and match_invoice (0104): one invoice_matches row, one
-- invoice_match_payments row and an invoice_payment event. A wrong link (the
-- right amount against the wrong invoice) had no way back: the invoice reads
-- paid until somebody edits the books by hand.
--
-- What is undone is the MATCH, never the money. The bank payment credit stays
-- on the member's account (the money did arrive), the line keeps its
-- payment_ledger_id and so reads 'recorded', and a new match reuses the same
-- credit: no second credit is ever minted. release_invoice_payment (0144) is
-- not called: it also deletes ledger rows and is the helper of a rejection.
--
--   bank_line_unmatches          append-only: one row per match undone. It
--                                keeps what the match was (the line, the
--                                invoice, the credit, the amount and the
--                                resolution, who matched and when), why it is
--                                undone, who undid it, the request id, and
--                                the two events (the original invoice_payment
--                                and the reversal). Nothing deletes or
--                                changes it; the client has no write grant.
--   invoice_payment_reversed     a new event type: the timeline and the audit
--                                feed show the undoing next to the payment
--                                they undid. It is 'applied' (nobody decides
--                                it), has no validation policy, and reads as
--                                nothing but a record: it is not a payment and
--                                moves no money, no notification, no provider.
--   unmatch_bank_line_in_v1      issueInvoices (the right that matches) while
--                                bankImport is on; a reason is required.
--                                Exactly once: the line, then the invoice,
--                                then its links are locked in that order and
--                                the state is read again under the locks; the
--                                same request id answers what it answered the
--                                first time, a request id used for another
--                                line is refused.
--   book_period_match_guard      a CONFIRMED payment that stood in a closed
--                                period of the books is never removed, by any
--                                path: the DELETE case. The rejection or the
--                                expiry of a PENDING match is not that.
--
-- This slice undoes the exact, single-payment, open-period match. Refused,
-- each with its own code (DKB01 is the existing "decided meanwhile"):
--   DKB01  the movement settles no invoice any more, or the match still
--          awaits its validation (reject it there instead)
--   DKB02  money out (it reconciles a payment: unreconcile_bank_line_out_v1)
--   DKB04  the match did more than link: it minted a credit note
--          (over_credit_note), it belongs to a settlement, or it was written off
--   DKB05  the invoice has more than this payment matched to it
--   DKB06  the match is dated inside a closed period of the books
-- Plus 42501 (an unknown line, a stranger, a member without the right, an
-- assistant's token), 0A000 (bankImport off) and 22023 (no reason, a request
-- id used for another line).

-- ── the record ────────────────────────────────────────────────────────────
create table public.bank_line_unmatches (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  line_id uuid not null references public.bank_statement_lines(id) on delete cascade,
  invoice_id uuid not null references public.invoices(id),
  payment_ledger_id uuid not null references public.ledger_entries(id),
  amount_cents int not null,
  resolution text not null,
  matched_by_member_id uuid references public.members(id) on delete set null,
  matched_at timestamptz,
  original_event_id uuid references public.events(id),
  reversal_event_id uuid not null references public.events(id),
  reason text not null check (char_length(reason) between 1 and 300),
  request_id uuid not null,
  actor_member_id uuid not null,
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id),
  constraint bank_line_unmatches_request unique (workspace_id, request_id)
);
select public.ensure_system_columns('bank_line_unmatches');
create index bank_line_unmatches_line on public.bank_line_unmatches (line_id);
create index bank_line_unmatches_invoice on public.bank_line_unmatches (invoice_id);

alter table public.bank_line_unmatches enable row level security;
revoke all on public.bank_line_unmatches from public, anon, authenticated;
grant select on public.bank_line_unmatches to authenticated;
create policy bank_line_unmatches_select on public.bank_line_unmatches
  for select to authenticated using (public.bank_statement_reader(workspace_id));
create policy mcp_delegated_deny on public.bank_line_unmatches as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the event type ────────────────────────────────────────────────────────
-- Only events_type_check: the undoing is recorded, not validated, so it has
-- no row in validation_policies and its check stays as it is.
do $constraints$
declare v_def text;
begin
  select pg_get_constraintdef(oid) into v_def from pg_constraint
   where conrelid = 'public.events'::regclass and conname = 'events_type_check';
  if v_def is null or position('CHECK (' in v_def) <> 1 then
    raise exception 'event type constraint anchor missing: events_type_check';
  end if;
  if position('invoice_payment_reversed' in v_def) = 0 then
    alter table public.events drop constraint events_type_check;
    execute 'alter table public.events add constraint events_type_check '
      || replace(v_def, 'CHECK (', format('CHECK (type = %L OR ', 'invoice_payment_reversed'));
  end if;
end;
$constraints$;

-- Who reads the event: whoever reads the payment it undoes. 0639's body, one
-- type more in the finance branch.
create or replace function public.event_type_view_permissions(p_type text)
returns text[] language sql immutable set search_path = public as $fn$
  select case
    when p_type in ('payment', 'adjustment', 'service_charge', 'invoice_payment',
                    'invoice_payment_reversed',
                    'invoice_writeoff', 'invoice_reminder', 'invoice_issue',
                    'invoice_void', 'refund', 'usage_correction', 'usage_record_delete')
      then array['viewFinances', 'issueInvoices']
    when p_type in ('expense', 'expense_schedule', 'expense_repartition')
      then array['approveExpenses', 'viewFinances']
    when p_type in ('reservation', 'space_reservation', 'reservation_delete')
      then array['manageReservations']
    when p_type = 'quota'
      then array['manageReservations', 'viewFinances', 'issueInvoices']
    when p_type in ('member_join', 'member_status_change', 'subscription_change', 'role_change')
      then array['manageMembers']
    when p_type = 'matrix_change'
      then array['manageRoles', 'manageMembers']
    when p_type = 'price_negotiation'
      then array['viewNegotiations']
    when p_type = 'payment_terms_change'
      then array['paymentTermsEdit', 'viewNegotiations']
    when p_type = 'lease_change'
      then array['manageLease', 'viewFinances']
    when p_type = 'commitment_variance'
      then array['managePurchases', 'viewFinances']
    when p_type = 'badge_security_alert'
      then array['workspaceSettings']
    when p_type = 'payment_instructions_change'
      then array['manageIntegrations']
    else array['manageConfiguration']
  end;
$fn$;
revoke execute on function public.event_type_view_permissions(text) from public, anon;
grant execute on function public.event_type_view_permissions(text) to authenticated;

-- ── a payment that stood in a closed period is never removed ──────────────
-- 0504's body, one branch more. A DELETE is guarded only for a CONFIRMED
-- match, and only when it is the statement itself that deletes it (trigger
-- depth 1): the rejection or the expiry of a pending match, and the cascade
-- of a deleted workspace, are not an undoing of a booked payment.
create or replace function public.book_period_match_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare v_at timestamptz;
begin
  if tg_op = 'DELETE' then
    if old.status = 'confirmed' and pg_trigger_depth() = 1
       and public.book_period_closed(old.workspace_id,
             public.book_local_day(old.workspace_id, coalesce(old.writeoff_at, old.matched_at))) then
      raise exception 'this payment is dated inside a closed period of the books: it cannot be undone';
    end if;
    return old;
  end if;
  v_at := coalesce(new.writeoff_at, new.matched_at);
  if (tg_op = 'INSERT' or new.matched_at is distinct from old.matched_at
      or new.writeoff_at is distinct from old.writeoff_at or new.paid_cents is distinct from old.paid_cents)
     and public.book_period_closed(new.workspace_id, public.book_local_day(new.workspace_id, v_at)) then
    raise exception 'this payment is dated inside a closed period of the books: it is booked in the open period';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.book_period_match_guard() from public, anon, authenticated;
drop trigger if exists book_period_match_guard on public.invoice_matches;
create trigger book_period_match_guard before insert or update or delete on public.invoice_matches
  for each row execute function public.book_period_match_guard();

-- ── the command ───────────────────────────────────────────────────────────
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
  if (select count(*) from public.invoice_match_payments where invoice_id = v_invoice.id) <> 1
     or v_match.paid_cents is distinct from v_pay.amount_cents then
    raise exception 'other payments are matched to this invoice' using errcode = 'DKB05';
  end if;
  if public.book_period_closed(v_ws, public.book_local_day(v_ws, coalesce(v_match.writeoff_at, v_match.matched_at))) then
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
  delete from public.invoice_matches where invoice_id = v_invoice.id;
  update public.bank_statement_lines
     set invoice_id = null, matched_by_member_id = null, matched_at = null
   where id = v_line.id
  returning * into v_line;
  return jsonb_build_object('id', v_line.id, 'invoice_id', v_invoice.id,
    'payment_ledger_id', v_line.payment_ledger_id, 'unmatch_id', v_unmatch,
    'status', public.bank_line_status(v_line));
end;
$fn$;
revoke execute on function public.unmatch_bank_line_in_v1(uuid, text, uuid) from public, anon;
grant execute on function public.unmatch_bank_line_in_v1(uuid, text, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(650);
