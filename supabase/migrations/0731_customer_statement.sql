-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one new read; no table, policy or other function changes)
--
-- #3673 (customer statement) -- an open-items statement of one customer as
-- of a date, as decided on the issue (11 November 2026):
--
--  * the customer's open documents at the cutoff, each with what is still
--    due after the parts already allocated to it, and the payment parts that
--    settled it as detail -- a payment appears only there, never as a second
--    deduction;
--  * the credits and payment remainders not yet applied;
--  * one signed balance per currency = still due - unapplied. One statement
--    per currency: nothing is added across currencies. A credit note's still
--    due is negative (the business owes it).
--
-- The rules are the customer page's, read on the server and at a cutoff
-- (the end of the given day in the business's time zone):
--
--  * still due (invoice_journey.dart, invoiceRemainingCents): a voided
--    document, or one regrouped into a settlement, owes nothing; with no
--    match, or a match awaiting approval, the whole total; a part payment
--    accepted (under_accepted) without a write-off, the total less the
--    approved parts; any other match, nothing;
--  * unapplied (payment_candidates.dart, unmatchedPaymentsOf): a payment or
--    adjustment credit of the customer, less every part allocated from it
--    (awaiting approval included, as a part already spoken for), never a
--    credit moved to another customer, never one already baked into a later
--    document of the same month. The ledger is kept in the business's
--    currency.
--
-- Rows dated after the cutoff (a document, a part, a payment, a move, a
-- write-off) are not part of the statement. A match's approval is read as it
-- stands now: a statement of a past day shows its decision as later taken.
-- Moving the customer page onto this read is a later issue.
--
-- Who may read it: the customer themselves, and whoever views finances or
-- issues invoices in the business (may_view_member_finances). An assistant's
-- delegated session is refused, as the invoices it reads refuse it
-- (mcp_delegated_deny on invoices, invoice_matches and ledger_entries).

create or replace function public.customer_statement_v1(
  p_workspace_id uuid, p_member_id uuid, p_as_of date
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_member public.members;
  v_ws public.workspaces;
  v_cutoff timestamptz;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_member from public.members
   where id = p_member_id and workspace_id = p_workspace_id;
  if v_member.id is null or not public.may_view_member_finances(p_member_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_as_of is null then
    raise exception 'a statement names its date' using errcode = '22023';
  end if;
  select * into v_ws from public.workspaces where id = p_workspace_id;
  v_cutoff := ((p_as_of + 1)::timestamp at time zone coalesce(nullif(v_ws.timezone, ''), 'UTC'));
  return (
    with docs as (
      select i.id, i.number, i.currency, i.issued_at, i.total_cents,
             (select mt.due_on from public.invoice_maturities mt where mt.invoice_id = i.id) as due_on,
             (i.voided_at is not null and i.voided_at < v_cutoff)
             or exists (select 1 from public.invoices s
                         where s.id = i.settled_by_invoice_id and s.issued_at < v_cutoff) as closed
        from public.invoices i
       where i.workspace_id = p_workspace_id and i.member_id = p_member_id
         and i.issued_at < v_cutoff and i.total_cents <> 0
    ),
    -- The parts allocated by the cutoff, and whether each awaits approval.
    parts as (
      select p.invoice_id, p.payment_ledger_id, p.amount_cents, p.matched_at,
             coalesce(e.status = 'pending', false) as waiting
        from public.invoice_match_payments p
        left join public.events e on e.id = p.event_id
       where p.workspace_id = p_workspace_id and p.created_datetime < v_cutoff
    ),
    due as (
      select d.*,
             case
               when d.closed then 0
               when m.id is null or m.created_datetime >= v_cutoff then d.total_cents
               when m.status = 'pending' then d.total_cents
               when m.resolution = 'under_accepted'
                    and (m.writeoff_at is null or m.writeoff_at >= v_cutoff)
                 then d.total_cents - coalesce((select sum(pt.amount_cents) from parts pt
                                                 where pt.invoice_id = d.id and not pt.waiting), 0)
               else 0
             end as still_due,
             case
               when d.total_cents < 0 then 'credit_note'
               when m.id is not null and m.created_datetime < v_cutoff and m.status = 'pending'
                 then 'awaiting_approval'
               when m.id is not null and m.created_datetime < v_cutoff then 'partly_paid'
               else 'open'
             end as state
        from docs d
        left join public.invoice_matches m on m.invoice_id = d.id
    ),
    credits as (
      select le.id, le.category, le.description, le.occurred_on, le.created_at,
             le.amount_cents - coalesce((select sum(pt.amount_cents) from parts pt
                                          where pt.payment_ledger_id = le.id), 0) as left_cents
        from public.ledger_entries le
       where le.workspace_id = p_workspace_id and le.member_id = p_member_id
         and le.kind = 'credit' and le.category in ('payment', 'adjustment')
         and le.created_at < v_cutoff
         and not exists (select 1 from public.ledger_credit_moves cm
                          where (cm.from_credit_id = le.id or cm.reversal_ledger_id = le.id)
                            and cm.created_datetime < v_cutoff)
         and not exists (select 1 from public.invoices i
                          where i.workspace_id = p_workspace_id and i.member_id = p_member_id
                            and i.period = le.period and i.issued_at > le.created_at
                            and i.issued_at < v_cutoff
                            and (i.voided_at is null or i.voided_at >= v_cutoff))
    ),
    lines as (
      select d.currency, jsonb_build_object(
               'invoice_id', d.id, 'number', d.number, 'issued_at', d.issued_at,
               'due_on', d.due_on, 'total_cents', d.total_cents,
               'still_due_cents', d.still_due, 'state', d.state,
               'allocations', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'payment_id', pt.payment_ledger_id, 'on', pt.matched_at,
                          'amount_cents', pt.amount_cents, 'awaiting_approval', pt.waiting)
                          order by pt.matched_at, pt.payment_ledger_id)
                   from parts pt where pt.invoice_id = d.id), '[]'::jsonb)) as line,
             d.still_due, d.issued_at, d.number
        from due d where d.still_due <> 0
    ),
    open_credits as (
      select v_ws.currency_code as currency, jsonb_build_object(
               'ledger_id', c.id, 'category', c.category, 'description', c.description,
               'on', coalesce(c.occurred_on, c.created_at::date), 'left_cents', c.left_cents) as line,
             c.left_cents, c.created_at, c.id
        from credits c where c.left_cents > 0
    ),
    currencies as (
      select currency from lines union select currency from open_credits
    )
    select jsonb_build_object(
             'member_id', v_member.id,
             'as_of', p_as_of,
             'cutoff', v_cutoff,
             'currencies', coalesce(jsonb_agg(jsonb_build_object(
               'currency', c.currency,
               'still_due_cents', coalesce((select sum(l.still_due) from lines l where l.currency = c.currency), 0),
               'unapplied_cents', coalesce((select sum(o.left_cents) from open_credits o where o.currency = c.currency), 0),
               'balance_cents', coalesce((select sum(l.still_due) from lines l where l.currency = c.currency), 0)
                                - coalesce((select sum(o.left_cents) from open_credits o where o.currency = c.currency), 0),
               'invoices', coalesce((select jsonb_agg(l.line order by l.issued_at, l.number)
                                       from lines l where l.currency = c.currency), '[]'::jsonb),
               'credits', coalesce((select jsonb_agg(o.line order by o.created_at, o.id)
                                      from open_credits o where o.currency = c.currency), '[]'::jsonb))
             order by c.currency), '[]'::jsonb))
      from currencies c
  );
end;
$fn$;
revoke execute on function public.customer_statement_v1(uuid, uuid, date) from public, anon;
grant execute on function public.customer_statement_v1(uuid, uuid, date) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(731);
