-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #3556 (1b) — My finances pays and declares the invoices a person selects,
-- and withdraws a payment they no longer want. It needs two facts of each
-- invoice the overview did not answer:
--   period            the month the invoice is of: a payment that names
--                     invoices is of their month (DKC04), so a selection is
--                     paid one month at a time;
--   claim_payment_id  the online payment whose open claim names the invoice
--                     (withdraw_payment_claim takes it); null for a declared
--                     payment, which is taken back by its own command
--                     (withdraw_payment_declaration, 0800; the app's action
--                     comes with #4140);
--   claim_handed_at   when that payment was handed to its provider: the
--                     row says since when it is in payment;
--   claim_settling    the hand-over is younger than the provider's read age
--                     (payment_read_after, 0798): a payment just made at
--                     the provider may still be confirmed, and withdrawing
--                     it says so.
-- my_finance_overview is restated whole from its live definition (0797),
-- with these answers added and nothing else changed.
--
-- Money that arrived and was not applied holds its invoice (0797's
-- invoice_payment_received, widened): an invoice is `payment_received`, and
-- not payable, while a captured payment (or an approved declared one) of
-- its member names it in its claim, did not apply to it — whatever the
-- reason: an error, a claim withdrawn before the capture, a claim that
-- lapsed — and still has money unmatched. It is free again once that money
-- is matched elsewhere, refunded or reversed.

create or replace function public.invoice_payment_received(p_invoice uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1
      from public.invoices i
      join public.payment_intents pi
        on pi.workspace_id = i.workspace_id and pi.member_id = i.member_id
      join public.ledger_entries l on l.id = pi.ledger_entry_id
     where i.id = p_invoice
       and pi.status = 'captured'
       and i.id = any (pi.claimed_invoice_ids)
       and not coalesce(pi.claim_outcome -> 'applied'
             @> jsonb_build_array(jsonb_build_object('invoice_id', p_invoice)), false)
       and l.amount_cents - public.payment_used_cents(l.id) > 0)
  or exists (
    select 1
      from public.invoices i
      join public.events e
        on e.workspace_id = i.workspace_id and e.type = 'payment' and e.status = 'confirmed'
      join public.ledger_entries l
        on l.event_id = e.id and l.kind = 'credit' and l.category = 'payment'
     where i.id = p_invoice
       and jsonb_typeof(e.payload -> 'claim') = 'array'
       and e.payload -> 'claim' @> jsonb_build_array(jsonb_build_object('invoice_id', p_invoice))
       and not coalesce(e.payload -> 'claim_outcome' -> 'applied'
             @> jsonb_build_array(jsonb_build_object('invoice_id', p_invoice)), false)
       and l.amount_cents - public.payment_used_cents(l.id) > 0);
$fn$;
revoke execute on function public.invoice_payment_received(uuid) from public, anon, authenticated;

create or replace function public.my_finance_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_invoices jsonb;
  v_cut boolean;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  with claimed as (
    -- #3556 — the open claims of each of the person's businesses, read once.
    select o.invoice_id
      from (select distinct i.workspace_id from public.invoices i
              join public.members mem on mem.id = i.member_id
             where mem.user_id = auth.uid()) ws
     cross join lateral public.open_claim_invoices(ws.workspace_id) o
  ),
  mine as (
    select i.id, i.workspace_id, w.name as workspace_name, w.timezone as workspace_timezone,
           i.number, i.issued_at, i.period,
           (select max(mat.due_on) from public.invoice_maturities mat where mat.invoice_id = i.id) as due_on,
           i.total_cents, i.currency, coalesce(m.paid_cents, 0) as paid_cents,
           case when m.id is null then 'open'
                when m.status = 'pending' then 'awaiting_validation'
                when m.resolution = 'refunded' then 'refunded'
                when m.resolution = 'under_accepted'
                     then case when m.writeoff_at is null then 'partially_paid' else 'closed' end
                else 'paid' end as state,
           public.invoice_still_due_cents(i.id) as still_due_cents,
           -- #3556 — the invoice is in a payment being processed (an online
           -- payment or a declared one that names it): not for another.
           exists (select 1 from claimed c where c.invoice_id = i.id) as in_payment,
           -- #3556 (1b) — the online payment whose open claim names it: the
           -- one its member may withdraw. Null for a declared payment, which
           -- waits for the business.
           oc.id as claim_payment_id,
           oc.handed_at as claim_handed_at,
           coalesce(oc.handed_at > now() - public.payment_read_after(oc.provider), false)
             as claim_settling,
           -- Its money arrived and waits for a person to match it (6c).
           pr.received as payment_received,
           -- What a payment may name: the invoice takes a match now (the
           -- rule its settlement follows), is in the business's currency
           -- (a payment is taken in it), is in no open claim and has no
           -- payment waiting to be matched to it.
           public.invoice_match_blocker(i.id) is null
             and upper(i.currency) = upper(w.currency_code)
             and not exists (select 1 from claimed c where c.invoice_id = i.id)
             and not pr.received as payable,
           coalesce((select sum(p.amount_cents) from public.invoice_match_payments p
                       join public.events e on e.id = p.event_id
                      where p.invoice_id = i.id and e.status = 'pending'), 0)
             + case when m.status = 'pending'
                     and not exists (select 1 from public.invoice_match_payments p
                                      where p.invoice_id = i.id and p.event_id = m.event_id)
                    then coalesce(m.paid_cents, 0) else 0 end as awaiting_cents,
           (select count(*) from public.invoice_reminders r where r.invoice_id = i.id) as reminder_count,
           (select max(r.sent_at) from public.invoice_reminders r where r.invoice_id = i.id) as last_reminder_at
      from public.invoices i
      join public.members mem on mem.id = i.member_id
      join public.workspaces w on w.id = i.workspace_id
      left join lateral (
        select x.* from public.invoice_matches x
         where x.invoice_id = i.id order by x.matched_at desc limit 1
      ) m on true
      cross join lateral (select public.invoice_payment_received(i.id) as received) pr
      left join lateral (
        select pi.id, pi.handed_at, pi.provider from public.payment_intents pi
         where pi.workspace_id = i.workspace_id and pi.member_id = i.member_id
           and i.id = any (pi.claimed_invoice_ids)
           and public.payment_intent_claim_open(pi)
         order by pi.created_at desc, pi.id
         limit 1
      ) oc on true
     where mem.user_id = auth.uid()
       and i.voided_at is null and i.settled_by_invoice_id is null
  ),
  owed as (
    select * from mine where state in ('open', 'awaiting_validation', 'partially_paid')
  ),
  settled as (
    select * from mine where state not in ('open', 'awaiting_validation', 'partially_paid')
     order by issued_at desc, id desc
     limit 301
  ),
  answered as (
    select * from owed
    union all
    select * from (select * from settled order by issued_at desc, id desc limit 300) s
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', a.id, 'workspace_id', a.workspace_id, 'workspace_name', a.workspace_name,
           'workspace_timezone', a.workspace_timezone, 'number', a.number,
           'issued_at', a.issued_at, 'period', a.period, 'due_on', a.due_on, 'total_cents', a.total_cents,
           'currency', a.currency, 'paid_cents', a.paid_cents, 'state', a.state,
           'still_due_cents', a.still_due_cents, 'awaiting_cents', a.awaiting_cents,
           'in_payment', a.in_payment, 'claim_payment_id', a.claim_payment_id,
           'claim_handed_at', a.claim_handed_at, 'claim_settling', a.claim_settling,
           'payment_received', a.payment_received,
           'payable', a.payable,
           'reminder_count', a.reminder_count, 'last_reminder_at', a.last_reminder_at)
         order by a.issued_at desc, a.id desc), '[]'::jsonb),
         (select count(*) from settled) > 300
    into v_invoices, v_cut
    from answered a;
  return jsonb_build_object(
    'invoices', v_invoices,
    'settled_cut', v_cut,
    'reminders', coalesce((
      select jsonb_agg(q2 order by q2.sent_at desc, q2.id desc) from (
        select r.id, r.invoice_id, i.number as invoice_number, w.name as workspace_name,
               r.sent_at, r.level, r.automatic
          from public.invoice_reminders r
          join public.invoices i on i.id = r.invoice_id
          join public.members mem on mem.id = i.member_id
          join public.workspaces w on w.id = i.workspace_id
         where mem.user_id = auth.uid() and i.voided_at is null
         order by r.sent_at desc, r.id desc
         limit 100
      ) q2), '[]'::jsonb));
end;
$fn$;

revoke execute on function public.my_finance_overview() from public, anon;
grant execute on function public.my_finance_overview() to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(805);
