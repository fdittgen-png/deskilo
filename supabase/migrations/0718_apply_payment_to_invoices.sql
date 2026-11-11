-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one new function; the allocation guard raises on a missing payment row)
--
-- #3671 (part 2) -- one payment settles several invoices in one call.
--
-- apply_payment_to_invoices(workspace, payment, allocations, note):
--  * allocations: a JSON array of {invoice_id, amount_cents}, amounts in
--    minor units as the caller gives them (never split proportionally);
--  * every invoice is of the payment's payer, in the payment's business and
--    in the business's currency (a ledger entry has no currency of its own);
--  * each part is at most what is still due on its invoice, and together at
--    most what is left of the payment; what is left after stays the payer's
--    credit on the payment itself;
--  * each part is one match_invoice call: its rules, its approval event and
--    its refusal stay per invoice (a part below what is due is a standing
--    partial and needs the note);
--  * all or nothing: one refused part refuses the call.
-- Ledger amounts are never edited (ledger_entries_append_only), so a payment
-- cannot shrink under its parts.

create or replace function public.guard_payment_allocation_sum()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare v_amount bigint; v_others bigint;
begin
  if new.payment_ledger_id is null then return new; end if;
  select amount_cents into v_amount from public.ledger_entries
   where id = new.payment_ledger_id for update;
  if v_amount is null then
    raise exception 'unknown payment' using errcode = '22023';
  end if;
  select coalesce(sum(amount_cents), 0) into v_others
    from public.invoice_match_payments
   where payment_ledger_id = new.payment_ledger_id
     and id is distinct from new.id;
  if v_others + new.amount_cents > v_amount then
    raise exception 'the parts of a payment add up to more than the payment'
      using errcode = '22023';
  end if;
  return new;
end;
$fn$;

create or replace function public.apply_payment_to_invoices(
  p_workspace_id uuid, p_payment_ledger_id uuid, p_allocations jsonb, p_note text default '')
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_payment public.ledger_entries;
  v_currency text;
  v_left bigint;
  v_total bigint := 0;
  v_part record;
  v_invoice public.invoices;
  v_due bigint;
  v_n int := 0;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'admins may not issue invoices here';
  end if;
  if p_allocations is null or jsonb_typeof(p_allocations) <> 'array'
     or jsonb_array_length(p_allocations) = 0 then
    raise exception 'no invoice to pay';
  end if;
  select * into v_payment from public.ledger_entries
   where id = p_payment_ledger_id and workspace_id = p_workspace_id
     and kind = 'credit' and category in ('payment', 'adjustment')
   for update;
  if v_payment.id is null then raise exception 'unknown payment'; end if;
  select currency_code into v_currency from public.workspaces where id = p_workspace_id;
  v_left := v_payment.amount_cents - public.payment_used_cents(p_payment_ledger_id);
  if (select count(distinct x ->> 'invoice_id') from jsonb_array_elements(p_allocations) x)
     <> jsonb_array_length(p_allocations) then
    raise exception 'an invoice appears twice';
  end if;
  for v_part in
    select (x ->> 'invoice_id')::uuid as invoice_id, (x ->> 'amount_cents')::bigint as amount, n
      from jsonb_array_elements(p_allocations) with ordinality as a(x, n)
     order by n
  loop
    if v_part.amount is null or v_part.amount <= 0 then
      raise exception 'each part is a positive amount';
    end if;
    select * into v_invoice from public.invoices
     where id = v_part.invoice_id and workspace_id = p_workspace_id;
    if v_invoice.id is null or v_invoice.member_id <> v_payment.member_id then
      raise exception 'an invoice is not of this payer';
    end if;
    if v_invoice.currency <> v_currency then
      raise exception 'an invoice is not in the business''s currency';
    end if;
    v_due := v_invoice.total_cents - coalesce((select paid_cents from public.invoice_matches
                                                 where invoice_id = v_invoice.id), 0);
    if v_part.amount > v_due then
      raise exception 'a part is more than what is due on its invoice';
    end if;
    v_total := v_total + v_part.amount;
    if v_total > v_left then
      raise exception 'the parts are more than what is left of the payment';
    end if;
    perform public.match_invoice(v_invoice.id, p_payment_ledger_id,
      case when v_part.amount = v_due then 'exact' else 'under_accepted' end,
      p_note, v_part.amount::int);
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('invoices', v_n, 'left_cents', v_left - v_total);
end;
$fn$;
revoke execute on function public.apply_payment_to_invoices(uuid, uuid, jsonb, text) from public, anon;
grant execute on function public.apply_payment_to_invoices(uuid, uuid, jsonb, text) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(718);
