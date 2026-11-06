-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #3346 — follow-up to 0688 (independent review of move_payment_credit_v1):
--   1. the biller never moves a payment onto, or off, their own account;
--   2. the receiving member's month must be open too;
--   3. a credit that was moved can no longer be matched to an invoice, and
--      a match and a move of the same credit serialise on the credit's row
--      (the move already locks it; the match side takes the same lock in a
--      trigger), so a credit is never both matched and moved.
-- move_payment_credit_v1 is restated whole (this file defines it).

create or replace function public.move_payment_credit_v1(
  p_credit_id uuid, p_to_member_id uuid, p_reason text, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_me uuid;
  v_credit public.ledger_entries;
  v_done public.ledger_credit_moves;
  v_reason text := left(btrim(coalesce(p_reason, '')), 300);
  v_to public.members;
  v_to_name text;
  v_reversal uuid;
  v_new uuid;
  v_move uuid;
  v_day date;
begin
  -- Authorised first, locked after: an unknown credit reads as one the
  -- caller may not act on.
  select workspace_id into v_ws from public.ledger_entries where id = p_credit_id;
  if v_ws is null then raise exception 'you may not move this credit' using errcode = '42501'; end if;
  v_me := public.bank_import_actor(v_ws, 'issueInvoices');
  if p_request_id is null then
    raise exception 'a request id is required' using errcode = '22023';
  end if;
  select * into v_credit from public.ledger_entries where id = p_credit_id for update;
  -- The same request again answers what it answered and changes nothing.
  select * into v_done from public.ledger_credit_moves
   where workspace_id = v_ws and request_id = p_request_id;
  if v_done.id is not null then
    if v_done.from_credit_id <> p_credit_id or v_done.to_member_id <> p_to_member_id then
      raise exception 'this request id was already used for a different request' using errcode = '22023';
    end if;
    return jsonb_build_object('id', v_done.id, 'reversal_id', v_done.reversal_ledger_id,
      'credit_id', v_done.to_credit_id, 'replayed', true);
  end if;
  if v_reason = '' then raise exception 'a reason is required' using errcode = '22023'; end if;
  if v_credit.kind <> 'credit' or v_credit.category <> 'payment' then
    raise exception 'only a payment credit is moved' using errcode = '22023';
  end if;
  if exists (select 1 from public.ledger_credit_moves m where m.from_credit_id = p_credit_id
                                                       or m.reversal_ledger_id = p_credit_id) then
    raise exception 'this credit was already moved' using errcode = '22023';
  end if;
  if exists (select 1 from public.invoice_match_payments p
              where p.payment_ledger_id = p_credit_id or p.credit_ledger_id = p_credit_id)
     or exists (select 1 from public.invoice_matches m
                 where m.payment_ledger_id = p_credit_id or m.credit_ledger_id = p_credit_id) then
    raise exception 'this credit pays an invoice: undo the match first' using errcode = '22023';
  end if;
  if p_to_member_id = v_credit.member_id then
    raise exception 'the credit is already on this member' using errcode = '22023';
  end if;
  select * into v_to from public.members
   where id = p_to_member_id and workspace_id = v_ws;
  if v_to.id is null or v_to.status = 'exited' then
    raise exception 'unknown or departed member' using errcode = '22023';
  end if;
  -- #3346 — the biller never moves money onto, or off, their own account:
  -- the reason they write is the only trace, and it is theirs to write.
  if p_to_member_id = v_me or v_credit.member_id = v_me then
    raise exception 'you may not move a payment to or from your own account'
      using errcode = '42501';
  end if;
  if exists (select 1 from public.invoices i
              where i.member_id = v_credit.member_id and i.period = v_credit.period
                and i.voided_at is null) then
    raise exception 'this month is already invoiced to the member: correct that invoice first'
      using errcode = '22023';
  end if;
  -- #3346 — the month must be open on the receiving side too: a credit
  -- landing in an invoiced month reaches the balance but never an invoice.
  if exists (select 1 from public.invoices i
              where i.member_id = p_to_member_id and i.period = v_credit.period
                and i.voided_at is null) then
    raise exception 'this month is already invoiced to the receiving member: correct that invoice first'
      using errcode = '22023';
  end if;
  v_day := coalesce(v_credit.occurred_on, public.book_local_day(v_ws, v_credit.created_at));
  if public.book_period_closed(v_ws, v_day) then
    raise exception 'this credit is dated inside a closed period of the books' using errcode = '22023';
  end if;

  v_to_name := coalesce(nullif(v_to.managed_name, ''),
                        (select nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), '')
                           from public.profiles p where p.id = v_to.user_id), '');
  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
  values (v_ws, v_credit.member_id, 'charge', 'adjustment', v_credit.amount_cents,
          left('Payment moved to ' || coalesce(nullif(v_to_name, ''), 'another member') || ': ' || v_reason, 200),
          v_credit.period, v_day)
  returning id into v_reversal;
  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
  values (v_ws, p_to_member_id, 'credit', 'payment', v_credit.amount_cents,
          v_credit.description, v_credit.period, v_day)
  returning id into v_new;
  insert into public.ledger_credit_moves
    (workspace_id, from_credit_id, reversal_ledger_id, to_credit_id, from_member_id, to_member_id,
     amount_cents, reason, request_id, actor_member_id)
  values (v_ws, p_credit_id, v_reversal, v_new, v_credit.member_id, p_to_member_id,
          v_credit.amount_cents, v_reason, p_request_id, v_me)
  returning id into v_move;
  -- The bank line that brought this money now names the right credit.
  update public.bank_statement_lines set payment_ledger_id = v_new
   where workspace_id = v_ws and payment_ledger_id = p_credit_id;
  return jsonb_build_object('id', v_move, 'reversal_id', v_reversal, 'credit_id', v_new, 'replayed', false);
end;
$fn$;
revoke execute on function public.move_payment_credit_v1(uuid, uuid, text, uuid) from public, anon;
grant execute on function public.move_payment_credit_v1(uuid, uuid, text, uuid) to authenticated;


-- ── 3. a match and a move of one credit serialise ─────────────────────────
-- move_payment_credit_v1 locks the credit row `for update`. The match side
-- takes the same lock before it looks, so under READ COMMITTED whichever
-- commits second sees the other's row: a match inserted after a move is
-- refused here, and a move started after a match is refused by the move.
create or replace function public.refuse_match_of_moved_credit()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  perform 1 from public.ledger_entries
   where id in (new.payment_ledger_id, new.credit_ledger_id)
   order by id for update;
  if exists (select 1 from public.ledger_credit_moves m
              where m.from_credit_id in (new.payment_ledger_id, new.credit_ledger_id)
                 or m.reversal_ledger_id in (new.payment_ledger_id, new.credit_ledger_id)) then
    raise exception 'this credit was moved: it cannot pay an invoice' using errcode = '22023';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.refuse_match_of_moved_credit() from public, anon, authenticated;

drop trigger if exists invoice_matches_refuse_moved on public.invoice_matches;
create trigger invoice_matches_refuse_moved
  before insert or update of payment_ledger_id, credit_ledger_id on public.invoice_matches
  for each row execute function public.refuse_match_of_moved_credit();
drop trigger if exists invoice_match_payments_refuse_moved on public.invoice_match_payments;
create trigger invoice_match_payments_refuse_moved
  before insert or update of payment_ledger_id, credit_ledger_id on public.invoice_match_payments
  for each row execute function public.refuse_match_of_moved_credit();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(690);
