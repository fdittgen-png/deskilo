-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one new function; the allocation guard raises on a missing payment row;
--  match_invoice and an approval lock the invoice before the payment)
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
revoke execute on function public.guard_payment_allocation_sum() from public, anon, authenticated;

-- What is still due on an invoice: its total, less what its confirmed
-- matches paid, less the further parts that await approval (the first
-- part of a pending match is already the aggregate's paid amount).
create or replace function public.invoice_still_due_cents(p_invoice_id uuid)
returns bigint language sql stable security definer set search_path = public as $fn$
  select i.total_cents
         - coalesce((select m.paid_cents from public.invoice_matches m
                      where m.invoice_id = i.id), 0)
         - coalesce((select sum(p.amount_cents) from public.invoice_match_payments p
                       join public.events e on e.id = p.event_id
                      where p.invoice_id = i.id and e.status = 'pending'
                        and coalesce(e.payload ->> 'additional', 'false') = 'true'), 0)
    from public.invoices i where i.id = p_invoice_id;
$fn$;
revoke execute on function public.invoice_still_due_cents(uuid) from public, anon, authenticated;

create or replace function public.match_invoice(p_invoice_id uuid, p_payment_ledger_id uuid, p_resolution text, p_note text DEFAULT ''::text, p_amount_cents integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $fn$
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
  -- #3671: one lock order everywhere: the invoice, its aggregate, then the
  -- payment; two parts against one remainder wait for each other.
  select * into v_invoice from public.invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  if v_invoice.settled_by_invoice_id is not null then
    raise exception 'invoice is settled';
  end if;
  select * into v_existing from public.invoice_matches
    where invoice_id = p_invoice_id for update;
  if v_existing.invoice_id is not null then
    -- #506 — only a STANDING partial (not written off) accepts more.
    if v_existing.status <> 'confirmed'
       or v_existing.resolution <> 'under_accepted'
       or v_existing.writeoff_at is not null then
      raise exception 'invoice already matched';
    end if;
    v_additional := true;
    -- #3671: what is still due also leaves out the parts awaiting approval.
    v_due := public.invoice_still_due_cents(p_invoice_id);
  else
    v_due := v_invoice.total_cents;
  end if;
  -- #3671: an invoice a waiting part already covers takes nothing more,
  -- not even an intended overpayment.
  if v_due <= 0 then
    raise exception 'nothing is due on this invoice';
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
      and kind = 'credit' and category in ('payment', 'adjustment')
    for update;
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
  if (select count(distinct x ->> 'invoice_id') from jsonb_array_elements(p_allocations) x)
     <> jsonb_array_length(p_allocations) then
    raise exception 'an invoice appears twice';
  end if;
  -- The lock order of match_invoice: the invoices by id, then the payment.
  perform 1 from public.invoices
   where workspace_id = p_workspace_id
     and id in (select (x ->> 'invoice_id')::uuid from jsonb_array_elements(p_allocations) x)
   order by id for update;
  select * into v_payment from public.ledger_entries
   where id = p_payment_ledger_id and workspace_id = p_workspace_id
     and kind = 'credit' and category in ('payment', 'adjustment')
   for update;
  if v_payment.id is null then raise exception 'unknown payment'; end if;
  select currency_code into v_currency from public.workspaces where id = p_workspace_id;
  v_left := v_payment.amount_cents - public.payment_used_cents(p_payment_ledger_id);
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
    v_due := public.invoice_still_due_cents(v_invoice.id);
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

-- What each open invoice of a payment's payer can take of it now, in the
-- rules of match_invoice: the one list the sheet offers. An invoice whose
-- match awaits approval is listed and cannot take a part (reason
-- awaiting_approval); one a waiting part already covers likewise.
create or replace function public.payment_invoice_capacity_v1(
  p_workspace_id uuid, p_payment_ledger_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_payment public.ledger_entries;
  v_currency text;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'admins may not issue invoices here';
  end if;
  select * into v_payment from public.ledger_entries
   where id = p_payment_ledger_id and workspace_id = p_workspace_id
     and kind = 'credit' and category in ('payment', 'adjustment');
  if v_payment.id is null then raise exception 'unknown payment'; end if;
  select currency_code into v_currency from public.workspaces where id = p_workspace_id;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'invoice_id', i.id,
             'still_due_cents', d.due,
             'can_take', d.due > 0 and not d.held,
             'reason', case when (d.due <= 0 or d.held) then 'awaiting_approval' end)
           order by i.issued_at, i.id)
      from public.invoices i
      left join public.invoice_matches m on m.invoice_id = i.id
      cross join lateral (
        select public.invoice_still_due_cents(i.id) as due,
               coalesce(m.status = 'pending', false) as held,
               exists (select 1 from public.invoice_match_payments p
                         join public.events e on e.id = p.event_id
                        where p.invoice_id = i.id and e.status = 'pending') as waiting) d
     where i.workspace_id = p_workspace_id
       and i.member_id = v_payment.member_id
       and i.currency = v_currency
       and i.voided_at is null
       and i.settled_by_invoice_id is null
       and (m.invoice_id is null or m.status = 'pending'
            or (m.resolution = 'under_accepted' and m.writeoff_at is null))
       and (d.due > 0 or d.held or d.waiting)), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.payment_invoice_capacity_v1(uuid, uuid) from public, anon;
grant execute on function public.payment_invoice_capacity_v1(uuid, uuid) to authenticated;

-- The approval of a further part checks it again under the invoice's lock
-- (the one lock order: the invoice, then its aggregate): a part accepted as
-- exact must still settle what is due, a partial must still be below it. A
-- part refused meanwhile changes both. The event is already confirmed here,
-- so what is still due no longer counts this part.
create or replace function public.recheck_invoice_payment_part()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  perform 1 from public.invoices
    where id = (new.payload ->> 'invoice_id')::uuid for update;
  if coalesce(new.payload ->> 'additional', 'false') = 'true' and exists (
    select 1 from public.invoice_match_payments jr
     where jr.event_id = new.id
       and ((jr.resolution = 'exact'
             and jr.amount_cents <> public.invoice_still_due_cents(jr.invoice_id))
         or (jr.resolution = 'under_accepted'
             and jr.amount_cents >= public.invoice_still_due_cents(jr.invoice_id)))) then
    raise exception 'the invoice changed while this part waited for approval'
      using errcode = '22023';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.recheck_invoice_payment_part() from public, anon, authenticated;

drop trigger if exists events_recheck_invoice_payment_part on public.events;
create trigger events_recheck_invoice_payment_part
  after update of status on public.events
  for each row
  when (new.type = 'invoice_payment' and old.status = 'pending' and new.status = 'confirmed')
  execute function public.recheck_invoice_payment_part();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(718);
