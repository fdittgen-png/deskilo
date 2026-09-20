-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0213 — #1230: a reconciliation that runs, instead of a note saying the
-- figures were checked by hand.
--
-- The word "reconcil" appeared ten times in this repository and every
-- one was prose. The closest thing to an arithmetic assertion summed one
-- exported journal column on fixture data. Nothing compared the ledger
-- to the invoices it came from, or to the payments that settled them.
--
-- `reconcile_workspace(p_workspace_id)` returns one row per discrepancy:
-- a `check` naming the rule, the `subject` row it is about, and a
-- `detail` saying what disagrees with what. No rows means the three
-- legs agree. It is deliberately a QUERY and not a constraint: a
-- constraint that could fire on the invoicing path would take the
-- workspace down over an accounting question, and the honest answer to
-- a discrepancy is to show somebody, not to refuse the next booking.
--
-- ## The two legs that need no provider
--
-- **invoices ↔ ledger.** A match that posted a credit carries its id,
-- and that credit's amount is decided by the resolution:
--
--   over_credit_note   the member overpaid and a credit note absorbs the
--                      difference, so the credit is `paid − invoice total`
--   everything else    the credit is exactly what was paid
--
-- **payments ↔ ledger.** A captured payment intent must have posted a
-- credit for its own amount, in its own period, to its own member; and
-- an additional payment must point at a ledger row that says the same
-- figure it does.
--
-- A rule that was WRITTEN and then removed, because it can never fire:
-- "a match points at a credit that is not there". `credit_ledger_id`
-- carries `on delete set null`, so the dangling pointer it looked for is
-- structurally impossible — and a confirmed `exact` match legitimately
-- has no credit at all, so the null is not a defect either. A check that
-- cannot report anything is decoration, which is the thing this
-- programme exists to remove rather than add to.
--
-- Plus three tenancy rules that are cheap here and would be expensive to
-- discover later: a ledger row, an invoice and a match must each sit in
-- the same workspace as the member or invoice they point at. #1227
-- proves a member of one workspace cannot READ another's rows; this
-- proves the server never WROTE one across the line.
--
-- The provider leg — Stripe and Mollie transaction lists — needs an
-- outbound call and belongs to the edge function that already holds
-- those credentials. It is not in this function and this function does
-- not pretend otherwise.
create or replace function public.reconcile_workspace(p_workspace_id uuid)
returns table("check" text, subject uuid, detail text)
language plpgsql security definer set search_path = public as $fn$
begin
  if not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'only someone who may see the finances may reconcile them';
  end if;

  return query
  -- The credit does not say what the match says was paid.
  select 'match_credit_amount'::text, m.id,
         format('match paid %s, invoice total %s, ledger credit %s (%s)',
                m.paid_cents, i.total_cents, l.amount_cents, m.resolution)
    from public.invoice_matches m
    join public.ledger_entries l on l.id = m.credit_ledger_id
    join public.invoices i on i.id = m.invoice_id
   where m.workspace_id = p_workspace_id
     and l.amount_cents <> case m.resolution
                             when 'over_credit_note' then m.paid_cents - i.total_cents
                             else m.paid_cents
                           end

  union all
  -- An additional payment against an invoice, and the ledger row it
  -- claims to be. There is no `on delete set null` here to hide a
  -- dangling pointer, so both halves can actually go wrong.
  select 'extra_payment_unbacked'::text, p.id,
         case when p.payment_ledger_id is null
              then format('additional payment of %s on invoice %s has no ledger row',
                          p.amount_cents, i.number)
              else format('additional payment says %s, its ledger row says %s',
                          p.amount_cents, l.amount_cents) end
    from public.invoice_match_payments p
    join public.invoices i on i.id = p.invoice_id
    left join public.ledger_entries l on l.id = p.payment_ledger_id
   where p.workspace_id = p_workspace_id
     and (p.payment_ledger_id is null or l.amount_cents <> p.amount_cents)

  union all
  -- Money the provider says it took that the ledger never heard about.
  select 'captured_payment_uncredited'::text, pi.id,
         format('%s intent %s captured %s for %s, no matching ledger credit',
                pi.provider, pi.reference, pi.amount_cents, pi.period)
    from public.payment_intents pi
   where pi.workspace_id = p_workspace_id
     and pi.status = 'captured'
     and not exists (
       select 1 from public.ledger_entries l
        where l.workspace_id = pi.workspace_id
          and l.member_id = pi.member_id
          and l.kind = 'credit' and l.category = 'payment'
          and l.amount_cents = pi.amount_cents
          and l.period = pi.period)

  union all
  select 'ledger_crosses_workspaces'::text, l.id,
         format('ledger entry in %s posted to a member of %s',
                l.workspace_id, mm.workspace_id)
    from public.ledger_entries l
    join public.members mm on mm.id = l.member_id
   where l.workspace_id = p_workspace_id and mm.workspace_id <> l.workspace_id

  union all
  select 'invoice_crosses_workspaces'::text, i.id,
         format('invoice %s in %s issued to a member of %s',
                i.number, i.workspace_id, mm.workspace_id)
    from public.invoices i
    join public.members mm on mm.id = i.member_id
   where i.workspace_id = p_workspace_id and mm.workspace_id <> i.workspace_id

  union all
  select 'match_crosses_workspaces'::text, m.id,
         format('match in %s against an invoice of %s', m.workspace_id, i.workspace_id)
    from public.invoice_matches m
    join public.invoices i on i.id = m.invoice_id
   where m.workspace_id = p_workspace_id and i.workspace_id <> m.workspace_id;
end;
$fn$;
revoke execute on function public.reconcile_workspace(uuid) from public, anon;
