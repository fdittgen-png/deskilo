-- SPDX-License-Identifier: 0BSD
-- NEGATIVE invoices are CREDIT NOTES the WORKSPACE pays (#508). A month
-- where credits exceed charges derives a negative document — an avoir:
-- the workspace owes the member. Such a document cannot be settled by
-- matching a member payment; it is settled by RECORDING THE REFUND the
-- workspace paid out. The refund books a ledger CHARGE (offsetting the
-- member's credit) and closes the document with the new 'refunded'
-- resolution — through the same invoice_payment validation policy as
-- every settlement.

alter table public.invoice_matches
  drop constraint invoice_matches_resolution_check;
alter table public.invoice_matches
  add constraint invoice_matches_resolution_check check (resolution in
    ('exact','over_forced','over_credit_note','under_accepted',
     'refunded'));

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
  select * into v_actor from public.members
    where workspace_id = v_invoice.workspace_id and user_id = auth.uid()
      and status = 'active' and (is_admin or is_owner);
  if v_actor.id is null then raise exception 'not an admin of this workspace'; end if;
  if not public.is_owner_of(v_invoice.workspace_id) and not coalesce(
    (select w.feature_flags -> 'adminInvoicing' = to_jsonb(true)
       from public.workspaces w where w.id = v_invoice.workspace_id), false) then
    raise exception 'admins may not issue invoices here';
  end if;

  v_amount := -v_invoice.total_cents;
  select coalesce(display_name, '') into v_actor_name
    from public.profiles where id = v_actor.user_id;

  -- The payout: a CHARGE that offsets the member's credit — their
  -- balance returns to zero because the money left the workspace.
  insert into public.ledger_entries
    (workspace_id, member_id, kind, category, amount_cents,
     description, period)
  values
    (v_invoice.workspace_id, v_invoice.member_id, 'charge',
     'adjustment', v_amount,
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

  -- The payout entry rides credit_ledger_id: a REJECT deletes it
  -- through the existing invoice_payment reject branch, reopening the
  -- credit note with the member's balance restored.
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
