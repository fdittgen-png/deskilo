-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4492 (row 4) -- a closed period of the books refuses what is dated inside it, at every door that takes a date.
-- Until here `book_period_closed` was asked by the void of an invoice, the match of a payment, the bank unmatch
-- and the move of a credit (0504, 0650-0660, 0690, 0901). A goods movement and a payment could still be DATED
-- inside a closed period: `stock_move_v1(p_occurred_at)` and its siblings, `record_payment(p_paid_on)` and its
-- siblings. The value of the stock at a closed date, and the payments of a closed period, moved afterwards.
--
-- One rule, where the row is written, so that no door is beside it (`book_period_dated_guard()`):
--   * `stock_movements`: the business's local day of `occurred_at`. Every goods command ends there: the move, the
--     transfer, the take-out and the loss, the return (they take a date); the sale at the counter, an invoice's
--     goods, a count, a put-away (they are dated now).
--   * `events` of type `payment`: the declared day (`record_payment`, `record_standalone_payment_v1`).
--   * `ledger_entries`, the payment credit an approved declaration books: the day it was declared for. A
--     declaration that waited while its period was closed is not approved into it; it is declined and declared
--     again in the open period, or the owner reopens the period.
--   * `outgoing_payments`: the day the money was paid (`record_supplier_payment_v1`,
--     `record_member_reimbursement_v1`).
-- The refusal is DKB08, worded as the void and the match word theirs. The business's own TODAY is never refused,
-- even inside a period closed today (a period may be closed on its last day): the till and the stock room keep
-- working. A date in the open period is taken as before, and so is a call that sends no date.
-- Existing rows are not read: a movement or a payment dated inside a period before this migration stays as it
-- is, and the upgrade cannot fail on it. Reopening a period (`reopen_book_period_v1`, the owner, with a reason)
-- lifts the refusal, as it does for the void.
-- An app of the last release shows the server's sentence for DKB08; from this release it has its own words.

create function public.book_period_dated_guard()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_day date;
  v_what text := 'payment';
begin
  if tg_table_name = 'stock_movements' then
    v_day := public.book_local_day(new.workspace_id, new.occurred_at);
    v_what := 'movement';
  elsif tg_table_name = 'events' then
    if coalesce(new.payload ->> 'paid_on', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
      v_day := (new.payload ->> 'paid_on')::date;
    end if;
  elsif tg_table_name = 'ledger_entries' then
    v_day := new.occurred_on;
  else
    v_day := new.reported_paid_on;
  end if;
  if v_day is not null
     and v_day <> public.book_local_day(new.workspace_id, now())
     and public.book_period_closed(new.workspace_id, v_day) then
    raise exception 'this % is dated inside a closed period of the books: it is booked in the open period', v_what
      using errcode = 'DKB08', detail = jsonb_build_object('day', v_day, 'what', v_what)::text;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.book_period_dated_guard() from public, anon, authenticated;

create trigger book_period_dated_guard before insert on public.stock_movements
  for each row execute function public.book_period_dated_guard();
create trigger book_period_dated_guard before insert on public.events
  for each row when (new.type = 'payment') execute function public.book_period_dated_guard();
create trigger book_period_dated_guard before insert on public.ledger_entries
  for each row when (new.kind = 'credit' and new.category = 'payment' and new.event_id is not null and new.occurred_on is not null)
  execute function public.book_period_dated_guard();
create trigger book_period_dated_guard before insert on public.outgoing_payments
  for each row execute function public.book_period_dated_guard();

select public.set_deskilo_schema_version(978);
