-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (the junction's unique key moves from the payment to the pair invoice and
-- payment; match_invoice gains a defaulted amount; four readers count what is
-- left of a payment; no stored row changes)
--
-- #3671 (part 1 of 3) -- one payment may settle several invoices.
--
--  * invoice_match_payments: one row per invoice a payment settles, each with
--    the part it settled (amount_cents). UNIQUE(payment_ledger_id) becomes
--    UNIQUE(invoice_id, payment_ledger_id); invoice_matches' unique index on
--    its latest payment becomes a plain index.
--  * The invariant, under a lock on the payment's ledger row: the parts of a
--    payment never add up to more than its amount
--    (guard_payment_allocation_sum).
--  * payment_used_cents(ledger id) is the one SQL definition of what a
--    payment has settled; what is left = its amount less that. Existing rows
--    each settled their whole payment, so every existing total reads the same.
--  * match_invoice takes an optional amount (default: what is left of the
--    payment, which for an unused payment is the whole payment, as before).
--  * member_account, member_statement, invoice_lines_for and
--    invoices_reimbursement_guard count what is left of a payment instead of
--    "has a row"; bank_line_status aggregates the payment's rows (it raised
--    on two); reconcile_workspace flags a payment whose parts exceed it.

alter table public.invoice_match_payments
  drop constraint if exists invoice_match_payments_payment_ledger_id_key;
alter table public.invoice_match_payments
  add constraint invoice_match_payments_invoice_payment_key unique (invoice_id, payment_ledger_id);
create index if not exists invoice_match_payments_payment_idx
  on public.invoice_match_payments (payment_ledger_id);
-- The per-invoice aggregate names the latest payment of its invoice; one
-- payment may now be the latest of two invoices.
drop index if exists public.invoice_matches_payment_unique;
create index if not exists invoice_matches_payment_idx
  on public.invoice_matches (payment_ledger_id) where payment_ledger_id is not null;

create or replace function public.payment_used_cents(p_ledger uuid)
returns bigint language sql stable security definer set search_path = public as $fn$
  select coalesce(sum(amount_cents), 0)::bigint
    from public.invoice_match_payments where payment_ledger_id = p_ledger;
$fn$;
revoke execute on function public.payment_used_cents(uuid) from public, anon, authenticated;

create or replace function public.guard_payment_allocation_sum()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare v_amount bigint; v_others bigint;
begin
  if new.payment_ledger_id is null then return new; end if;
  select amount_cents into v_amount from public.ledger_entries
   where id = new.payment_ledger_id for update;
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
revoke execute on function public.guard_payment_allocation_sum() from public, anon, authenticated;
drop trigger if exists invoice_match_payments_allocation_sum on public.invoice_match_payments;
create trigger invoice_match_payments_allocation_sum
  before insert or update of amount_cents, payment_ledger_id on public.invoice_match_payments
  for each row execute function public.guard_payment_allocation_sum();

drop function if exists public.match_invoice(uuid, uuid, text, text);
create or replace function public.match_invoice(p_invoice_id uuid, p_payment_ledger_id uuid, p_resolution text, p_note text default '', p_amount_cents integer default null)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_invoice public.invoices;
  v_existing public.invoice_matches;
  v_payment public.ledger_entries;
  v_paid int;
  v_due int;
  v_actor public.members;
  v_actor_name text;
  v_note text := btrim(coalesce(p_note, ''));
  v_has_policy boolean;
  v_event_id uuid;
  v_credit_id uuid := null;
  v_additional boolean := false;
  v_left bigint;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  if v_invoice.settled_by_invoice_id is not null then
    raise exception 'invoice is settled';
  end if;
  select * into v_existing from public.invoice_matches
    where invoice_id = p_invoice_id;
  if v_existing.invoice_id is not null then
    -- #506 — only a STANDING partial (not written off) accepts more.
    if v_existing.status <> 'confirmed'
       or v_existing.resolution <> 'under_accepted'
       or v_existing.writeoff_at is not null then
      raise exception 'invoice already matched';
    end if;
    v_additional := true;
    v_due := v_invoice.total_cents - v_existing.paid_cents;
  else
    v_due := v_invoice.total_cents;
  end if;
  -- #816 — the matrix alone decides who matches.
  v_actor := public.issuing_member(v_invoice.workspace_id);
  -- #513 — the CENTRAL permission decides: owner always passes,
  -- co-owner/admin/member per the workspace's role matrix; the
  -- legacy adminInvoicing flag keeps granting inside
  -- has_permission for compatibility.
  if not public.has_permission(v_invoice.workspace_id, 'issueInvoices') then
    raise exception 'admins may not issue invoices here';
  end if;

  -- #512 — settlement sources: registered payments AND account credits
  -- (category 'adjustment': credit-note excess) — the imputation of an
  -- avoir on any outstanding invoice, past months included.
  select * into v_payment from public.ledger_entries
    where id = p_payment_ledger_id
      and workspace_id = v_invoice.workspace_id
      and member_id = v_invoice.member_id
      and kind = 'credit' and category in ('payment', 'adjustment');
  if v_payment.id is null then raise exception 'unknown payment'; end if;
  -- A credit already BAKED into an issued invoice (negative line at
  -- derivation) was spent there — it cannot settle a second document.
  if exists (
    select 1 from public.invoices i
    where i.member_id = v_invoice.member_id
      and i.period = v_payment.period
      and i.voided_at is null
      and i.issued_at > v_payment.created_at) then
    raise exception 'credit already deducted on an issued invoice';
  end if;
  -- #3671: a payment may settle several invoices, each its own part; what
  -- is left of it is its amount less the parts already taken. Without an
  -- amount the whole remainder settles this invoice, as before.
  v_left := v_payment.amount_cents - public.payment_used_cents(p_payment_ledger_id);
  if v_left <= 0 or exists (select 1 from public.invoice_match_payments
                             where payment_ledger_id = p_payment_ledger_id
                               and invoice_id = p_invoice_id) then
    raise exception 'payment already matched';
  end if;
  if p_amount_cents is not null and (p_amount_cents <= 0 or p_amount_cents > v_left) then
    raise exception 'the amount is more than what is left of the payment';
  end if;
  v_paid := coalesce(p_amount_cents, v_left);

  if p_resolution not in
      ('exact','over_forced','over_credit_note','under_accepted') then
    raise exception 'unknown resolution';
  end if;
  -- All amount rules compare against what is STILL DUE (#506).
  if p_resolution = 'exact' and v_paid <> v_due then
    raise exception 'amount does not match the invoice';
  end if;
  if p_resolution in ('over_forced','over_credit_note')
     and v_paid <= v_due then
    raise exception 'amount does not exceed the invoice';
  end if;
  if p_resolution = 'under_accepted' and v_paid >= v_due then
    raise exception 'amount is not below the invoice';
  end if;
  if p_resolution in ('over_forced','under_accepted') and v_note = '' then
    raise exception 'a note is required';
  end if;

  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;

  if p_resolution = 'over_credit_note' then
    insert into public.ledger_entries
      (workspace_id, member_id, kind, category, amount_cents,
       description, period)
    values
      (v_invoice.workspace_id, v_invoice.member_id, 'credit',
       'adjustment', v_paid - v_due,
       'Credit note ' || v_invoice.number
         || case when v_note = '' then '' else ' — ' || v_note end,
       to_char(now(), 'YYYY-MM'))
    returning id into v_credit_id;
  end if;

  v_has_policy := exists (
    select 1 from public.validation_policies vp
    where vp.workspace_id = v_invoice.workspace_id
      and (vp.event_type = 'invoice_payment' or vp.event_type is null));

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values
    (v_invoice.workspace_id, 'invoice_payment', 'submitted',
     v_actor.id, v_invoice.member_id,
     jsonb_build_object(
       'invoice_id', v_invoice.id,
       'number', v_invoice.number,
       'due_cents', v_due,
       'paid_cents', v_paid,
       'amount_cents', v_paid,
       'payment_ledger_id', p_payment_ledger_id,
       'resolution', p_resolution,
       'note', v_note,
       'additional', v_additional),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end)
  returning id into v_event_id;

  -- The junction row reserves the payment even while pending.
  insert into public.invoice_match_payments
    (workspace_id, invoice_id, payment_ledger_id, amount_cents,
     resolution, note, event_id, credit_ledger_id, by_name)
  values
    (v_invoice.workspace_id, p_invoice_id, p_payment_ledger_id, v_paid,
     p_resolution, v_note, v_event_id, v_credit_id, v_actor_name);

  if v_additional then
    -- The aggregate moves only when the payment stands.
    if not v_has_policy then
      update public.invoice_matches
        set paid_cents = paid_cents + v_paid,
            resolution = p_resolution,
            note = case when v_note = '' then note else v_note end,
            payment_ledger_id = p_payment_ledger_id,
            credit_ledger_id = coalesce(v_credit_id, credit_ledger_id),
            matched_at = now(),
            by_name = v_actor_name
        where invoice_id = p_invoice_id;
    end if;
  else
    insert into public.invoice_matches
      (workspace_id, invoice_id, paid_cents, resolution, note, status,
       event_id, credit_ledger_id, payment_ledger_id, by_name)
    values
      (v_invoice.workspace_id, p_invoice_id, v_paid, p_resolution,
       v_note, case when v_has_policy then 'pending' else 'confirmed' end,
       v_event_id, v_credit_id, p_payment_ledger_id, v_actor_name);
  end if;
end;
$fn$;
revoke execute on function public.match_invoice(uuid, uuid, text, text, integer) from public, anon;
grant execute on function public.match_invoice(uuid, uuid, text, text, integer) to authenticated;

create or replace function public.bank_line_status(l public.bank_statement_lines)
returns text language sql stable security definer set search_path = public as $fn$
  select case
    when l.outgoing_payment_id is not null then 'reconciled'
    when l.payment_ledger_id is not null then coalesce(
      (select case when bool_or(e.status = 'pending') then 'pending'
                   when sum(imp.amount_cents) >= max(le.amount_cents) then 'matched'
                   else 'recorded' end
         from public.invoice_match_payments imp
         join public.ledger_entries le on le.id = imp.payment_ledger_id
         left join public.events e on e.id = imp.event_id
        where imp.payment_ledger_id = l.payment_ledger_id
       having count(*) > 0), 'recorded')
    else l.state end;
$fn$;

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_step record;
begin
  for v_step in
    select * from (values
      (1, 'member_account(uuid)', 'credit on account counts what is left',
       $old$  select coalesce(sum(le.amount_cents), 0) into v_credit$old$,
       $new$  select coalesce(sum(le.amount_cents - public.payment_used_cents(le.id)), 0) into v_credit$new$),
      (2, 'member_account(uuid)', 'a payment with something left stays on account',
       $old$    and not exists (
      select 1 from public.invoice_match_payments jr
      where jr.payment_ledger_id = le.id)
    and not exists (
      select 1 from public.invoices i$old$,
       $new$    and le.amount_cents > public.payment_used_cents(le.id)
    and not exists (
      select 1 from public.invoices i$new$),
      (3, 'member_statement(uuid,text)', 'a credit contributes what is left of it',
       $old$  select coalesce(sum(case when kind = 'credit' then amount_cents else -amount_cents end), 0)$old$,
       $new$  select coalesce(sum(case when kind = 'credit' then amount_cents - public.payment_used_cents(le.id) else -amount_cents end), 0)$new$),
      (4, 'member_statement(uuid,text)', 'no longer excluded whole by any row',
       $old$    and (le.kind <> 'credit' or not exists (
      select 1 from public.invoice_match_payments jr
      where jr.payment_ledger_id = le.id));$old$,
       $new$    and (le.kind <> 'credit' or le.amount_cents > public.payment_used_cents(le.id));$new$),
      (5, 'invoice_lines_for(uuid,text)', 'a credit line states what is left of it',
       $old$           (amount_cents - case when le.kind = 'credit' and le.category = 'expense'
                                then public.purchase_credit_paid(le.id) else 0 end)::int$old$,
       $new$           (amount_cents - case when le.kind = 'credit' and le.category = 'expense'
                                then public.purchase_credit_paid(le.id) else 0 end
                     - case when le.kind = 'credit'
                            then public.payment_used_cents(le.id) else 0 end)::int$new$),
      (6, 'invoice_lines_for(uuid,text)', 'no longer excluded whole by any row',
       $old$             and le.category in ('payment', 'expense', 'adjustment')
             and not exists (
               select 1 from public.invoice_match_payments jr
               where jr.payment_ledger_id = le.id)))$old$,
       $new$             and le.category in ('payment', 'expense', 'adjustment')))$new$),
      (7, 'invoices_reimbursement_guard()', 'the guard expects what the lines state',
       $old$  select coalesce(sum(greatest(le.amount_cents - public.purchase_credit_paid(le.id), 0)), 0)$old$,
       $new$  select coalesce(sum(greatest(le.amount_cents - public.purchase_credit_paid(le.id)
                                      - public.payment_used_cents(le.id), 0)), 0)$new$),
      (8, 'invoices_reimbursement_guard()', 'no longer excluded whole by any row',
       $old$     and le.kind = 'credit' and le.category = 'expense'
     and not exists (select 1 from public.invoice_match_payments jr
                      where jr.payment_ledger_id = le.id);$old$,
       $new$     and le.kind = 'credit' and le.category = 'expense';$new$),
      (9, 'reconcile_workspace(uuid)', 'a payment whose parts exceed it',
       $old$              else format('additional payment says %s, its ledger row says %s',
                          p.amount_cents, l.amount_cents) end
    from public.invoice_match_payments p
    join public.invoices i on i.id = p.invoice_id
    left join public.ledger_entries l on l.id = p.payment_ledger_id
   where p.workspace_id = p_workspace_id
     and (p.payment_ledger_id is null or l.amount_cents <> p.amount_cents)$old$,
       $new$              else format('the parts of its payment add up to %s, its ledger row says %s',
                          public.payment_used_cents(p.payment_ledger_id), l.amount_cents) end
    from public.invoice_match_payments p
    join public.invoices i on i.id = p.invoice_id
    left join public.ledger_entries l on l.id = p.payment_ledger_id
   where p.workspace_id = p_workspace_id
     and (p.payment_ledger_id is null
          or public.payment_used_cents(p.payment_ledger_id) > l.amount_cents)$new$)
    ) as s(n, sig, what, old_text, new_text)
    order by n
  loop
    if v_step.n in (1, 3, 5, 7, 9) then
      select pg_get_functiondef(('public.' || v_step.sig)::regprocedure) into v_def;
    end if;
    v_def := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_def is null then
      raise exception '0717: % anchor % (%) missing', v_step.sig, v_step.n, v_step.what;
    end if;
    if v_step.n in (2, 4, 6, 8, 9) then
      execute v_def;
    end if;
  end loop;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(717);
