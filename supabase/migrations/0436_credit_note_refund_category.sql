-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0436 (#2570, Refs #2365) — a refunded credit note is not re-invoiced.
--
-- settle_credit_invoice (0144) booked the refund by bank transfer as a
-- ledger `charge` / `adjustment`, and invoice_lines_for turns every
-- charge adjustment of the period into a positive line of the member's next
-- invoice: the refund came back as a charge.
--
-- Decision (the route the issue offers): the ledger row keeps being
-- written, with a distinct category `refund`. invoice_lines_for selects
-- charges by an explicit category list (service, package, adjustment), so
-- a `refund` row never reaches it, and no other reader filters on it:
-- member_statement and the balance sum the ledger by kind, so the member
-- statement still shows the money returned. The invoice_matches row
-- (resolution `refunded`, paid_cents) stays the settlement of the credit
-- note; #2365's engine books the refund from it.
--
-- Rows booked before this file keep `adjustment` (they may already be baked
-- into an issued invoice); only new settlements are affected.

alter table public.ledger_entries drop constraint ledger_entries_category_check;
alter table public.ledger_entries add constraint ledger_entries_category_check
  check (category in ('subscription','overage','expense','payment','adjustment',
                      'service','package','refund'));

create or replace function public.settle_credit_invoice(
  p_invoice_id uuid, p_note text default ''
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_invoice public.invoices;
  v_actor public.members;
  v_actor_name text;
  v_note text := btrim(coalesce(p_note, ''));
  v_has_policy boolean;
  v_event_id uuid;
  v_payout_id uuid;
  v_amount int;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'unknown invoice'; end if;
  if v_invoice.voided_at is not null then
    raise exception 'invoice is voided';
  end if;
  if v_invoice.total_cents >= 0 then
    raise exception 'not a credit note';
  end if;
  if exists (select 1 from public.invoice_matches
              where invoice_id = p_invoice_id) then
    raise exception 'invoice already matched';
  end if;
  v_actor := public.issuing_member(v_invoice.workspace_id);

  v_amount := -v_invoice.total_cents;
  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;

  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents,
     description, period)
  values
    (v_invoice.workspace_id, v_invoice.member_id, 'charge',
     'refund', v_amount,
     'Refund ' || v_invoice.number
       || case when v_note = '' then '' else ' — ' || v_note end,
     to_char(now(), 'YYYY-MM'))
  returning id into v_payout_id;

  v_has_policy := exists (
    select 1 from public.validation_policies vp
    where vp.workspace_id = v_invoice.workspace_id
      and vp.event_type = 'invoice_payment');

  insert into public.events
    (workspace_id, type, action, actor_member_id, subject_member_id,
     payload, status, decided_at)
  values
    (v_invoice.workspace_id, 'invoice_payment', 'submitted',
     v_actor.id, v_invoice.member_id,
     jsonb_build_object(
       'invoice_id', v_invoice.id,
       'number', v_invoice.number,
       'due_cents', v_invoice.total_cents,
       'paid_cents', v_amount,
       'amount_cents', v_amount,
       'resolution', 'refunded',
       'note', v_note),
     case when v_has_policy then 'pending' else 'confirmed' end,
     case when v_has_policy then null else now() end)
  returning id into v_event_id;

  insert into public.invoice_matches
    (workspace_id, invoice_id, paid_cents, resolution, note, status,
     event_id, credit_ledger_id, by_name)
  values
    (v_invoice.workspace_id, p_invoice_id, v_amount, 'refunded',
     v_note, case when v_has_policy then 'pending' else 'confirmed' end,
     v_event_id, v_payout_id, v_actor_name);
end;
$$;
revoke execute on function
  public.settle_credit_invoice(uuid, text) from public, anon;
grant execute on function
  public.settle_credit_invoice(uuid, text) to authenticated;

select public.set_deskilo_schema_version(436);
