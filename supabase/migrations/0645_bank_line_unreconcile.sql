-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (outgoing_payments_guard restated whole from 0603, its latest body; the
-- one change: reconciled -> reported is allowed once the line that
-- reconciled the payment has let it go and the undoing is on record)
--
-- 0645 (#2380) -- a reconciliation of money out is undone by a person, on
-- the record. reconcile_bank_line_out_v1 (0603) links a movement out to the
-- payment reported as made of its amount and moves that payment from
-- reported to reconciled with the bank's booking and value days. A wrong
-- link (two reimbursements of the same amount, the wrong one chosen) had no
-- way back.
--
--   bank_line_unreconciliations   append-only: one row per reconciliation
--                                 undone. It keeps what the reconciliation
--                                 was (the line, the payment, who linked
--                                 them and when, the booking and value days
--                                 the payment had taken), why it is undone,
--                                 who undid it, and the request id. Nothing
--                                 deletes or changes it; the client has no
--                                 write grant.
--   unreconcile_bank_line_out_v1  recordOutgoingPayments (the right that
--                                 reconciles) while bankImport is on; a
--                                 reason is required. Exactly once: the
--                                 line is locked and must still name a
--                                 payment, so a second attempt is refused
--                                 as decided meanwhile (DKB01); the same
--                                 request id answers what it answered the
--                                 first time and changes nothing, a request
--                                 id used for another line is refused. The
--                                 line is open again (it names no payment,
--                                 nobody matched it), the payment is
--                                 reported again with no bank days; the
--                                 statement, the line's bank facts and the
--                                 payment's reported facts are untouched.
--                                 The books follow by themselves: the
--                                 payment's entry reads its line's value
--                                 date only while a line names it (0642).
--
-- Money in is not undone here: a confirmed match of money in consumed a
-- payment credit through match_invoice and its validation; undoing it is a
-- reversal of that match and of the credit in the invoice engine, not a
-- change of the bank line.
--
-- Refusals as in 0603: 42501 for an unknown line, a stranger, a member
-- without the right, an assistant's token; 0A000 with the flag off; DKB01
-- the movement reconciles no payment (any more); DKB02 money in; 22023 no
-- reason.

-- ── the record ────────────────────────────────────────────────────────────
create table public.bank_line_unreconciliations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  line_id uuid not null references public.bank_statement_lines(id) on delete cascade,
  outgoing_payment_id uuid not null,
  reconciled_by_member_id uuid references public.members(id) on delete set null,
  reconciled_at timestamptz,
  booking_date date,
  value_date date,
  reason text not null check (char_length(reason) between 1 and 300),
  request_id uuid not null,
  actor_member_id uuid not null,
  foreign key (workspace_id, outgoing_payment_id) references public.outgoing_payments (workspace_id, id),
  foreign key (workspace_id, actor_member_id) references public.members (workspace_id, id),
  constraint bank_line_unreconciliations_request unique (workspace_id, request_id)
);
select public.ensure_system_columns('bank_line_unreconciliations');
create index bank_line_unreconciliations_line on public.bank_line_unreconciliations (line_id);
create index bank_line_unreconciliations_payment on public.bank_line_unreconciliations (outgoing_payment_id);

alter table public.bank_line_unreconciliations enable row level security;
revoke all on public.bank_line_unreconciliations from public, anon, authenticated;
grant select on public.bank_line_unreconciliations to authenticated;
create policy bank_line_unreconciliations_select on public.bank_line_unreconciliations
  for select to authenticated using (public.bank_statement_reader(workspace_id));
create policy mcp_delegated_deny on public.bank_line_unreconciliations as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── a reported payment leaves reconciled only when its line let it go ─────
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
     and not (old.state = 'reported' and new.state = 'reversed')
     and not (old.state = 'reported' and new.state = 'reconciled'
              and exists (select 1 from public.bank_statement_lines b
                           where b.outgoing_payment_id = new.id))
     and not (old.state = 'reconciled' and new.state = 'reported'
              and not exists (select 1 from public.bank_statement_lines b
                               where b.outgoing_payment_id = new.id)
              -- The undo of THIS transaction: an older undo row must not let a
              -- payment reconciled again slip back without a fresh undo.
              and exists (select 1 from public.bank_line_unreconciliations u
                           where u.outgoing_payment_id = new.id
                             and u.created_datetime = now())) then
    raise exception 'an outgoing payment moves only from reported to reversed, or to reconciled by a bank line and back when that line is undone';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.outgoing_payments_guard() from public, anon, authenticated;

-- ── the command ───────────────────────────────────────────────────────────
create or replace function public.unreconcile_bank_line_out_v1(
  p_line_id uuid, p_reason text, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_me uuid;
  v_line public.bank_statement_lines;
  v_pay public.outgoing_payments;
  v_done public.bank_line_unreconciliations;
  v_id uuid;
begin
  -- Authorised first, locked after: an unknown line reads as one the
  -- caller may not act on.
  select workspace_id into v_ws from public.bank_statement_lines where id = p_line_id;
  if v_ws is null then raise exception 'you may not do this for the bank statements' using errcode = '42501'; end if;
  v_me := public.bank_import_actor(v_ws, 'recordOutgoingPayments');
  if p_request_id is null then
    raise exception 'a request id is required' using errcode = '22023';
  end if;
  select * into v_line from public.bank_statement_lines where id = p_line_id for update;
  -- The same request again answers what it answered and changes nothing.
  select * into v_done from public.bank_line_unreconciliations
   where workspace_id = v_ws and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.line_id <> p_line_id then
      raise exception 'this request id was already used for a different request' using errcode = '22023';
    end if;
    return jsonb_build_object('id', p_line_id, 'outgoing_payment_id', v_done.outgoing_payment_id,
      'unreconciliation_id', v_done.id, 'status', 'open');
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'state why the reconciliation is undone' using errcode = '22023';
  end if;
  if v_line.amount_cents > 0 then
    raise exception 'money in reconciles no payment out' using errcode = 'DKB02';
  end if;
  if v_line.outgoing_payment_id is null then
    raise exception 'this movement reconciles no payment' using errcode = 'DKB01';
  end if;
  select * into v_pay from public.outgoing_payments
   where id = v_line.outgoing_payment_id and workspace_id = v_ws for update;
  if v_pay.state <> 'reconciled' then
    raise exception 'the payment this movement names is not reconciled' using errcode = 'DKB01';
  end if;

  insert into public.bank_line_unreconciliations
    (workspace_id, line_id, outgoing_payment_id, reconciled_by_member_id, reconciled_at,
     booking_date, value_date, reason, request_id, actor_member_id)
  values (v_ws, v_line.id, v_pay.id, v_line.matched_by_member_id, v_line.matched_at,
          v_pay.booking_date, v_pay.value_date, left(btrim(p_reason), 300), p_request_id, v_me)
  returning id into v_id;
  update public.bank_statement_lines
     set outgoing_payment_id = null, matched_by_member_id = null, matched_at = null
   where id = v_line.id
  returning * into v_line;
  update public.outgoing_payments
     set state = 'reported', booking_date = null, value_date = null
   where id = v_pay.id;
  return jsonb_build_object('id', v_line.id, 'outgoing_payment_id', v_pay.id,
    'unreconciliation_id', v_id, 'status', public.bank_line_status(v_line));
end;
$fn$;
revoke execute on function public.unreconcile_bank_line_out_v1(uuid, text, uuid) from public, anon;
grant execute on function public.unreconcile_bank_line_out_v1(uuid, text, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(645);
