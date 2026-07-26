-- SPDX-License-Identifier: 0BSD
-- Invoice = the SOLDE (field decision): all of the month's consumptions
-- AND all of its payments/credits, netting to the balance due. Credit
-- positions (confirmed payments, expense reimbursements, crediting
-- adjustments) join the derived lines with NEGATIVE amount_cents; the
-- invoice total therefore IS the solde. Charges stay positive; kinds
-- gain 'payment' and 'expense' (credit adjustments reuse 'adjustment'
-- with a negative amount).
create or replace function public.invoice_lines_for(
  p_member_id uuid,
  p_period text
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_stmt jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_row record;
begin
  v_stmt := public.member_statement(p_member_id, p_period);

  if (v_stmt->>'fee_cents')::int > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'subscription',
      'label', v_stmt->>'subscription_pct',
      'quantity', 1,
      'amount_cents', (v_stmt->>'fee_cents')::int);
  end if;
  if (v_stmt->>'overage_cents')::int > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'overage',
      'label', '',
      'quantity', (v_stmt->>'extra_half_days')::int,
      'amount_cents', (v_stmt->>'overage_cents')::int);
  end if;
  if coalesce((v_stmt->>'accessory_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'accessories', 'label', '', 'quantity', 1,
      'amount_cents', (v_stmt->>'accessory_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'level_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'level', 'label', '', 'quantity', 1,
      'amount_cents', (v_stmt->>'level_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'office_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'office', 'label', '', 'quantity', 1,
      'amount_cents', (v_stmt->>'office_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'desk_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'desk', 'label', '', 'quantity', 1,
      'amount_cents', (v_stmt->>'desk_supplement_cents')::int);
  end if;

  -- Confirmed positions booked to the period, in booking order:
  -- charges positive (services, packages, charging adjustments),
  -- credits NEGATIVE (payments, expense reimbursements, crediting
  -- adjustments). PENDING events stay excluded — confirm them first.
  for v_row in
    select kind, category, description, amount_cents
      from public.ledger_entries
     where member_id = p_member_id
       and period = p_period
       and ((kind = 'charge'
             and category in ('service', 'package', 'adjustment'))
         or (kind = 'credit'
             and category in ('payment', 'expense', 'adjustment')))
     order by created_at
  loop
    v_lines := v_lines || jsonb_build_object(
      'kind', v_row.category,
      'label', v_row.description,
      'quantity', 1,
      'amount_cents', case when v_row.kind = 'credit'
                           then -v_row.amount_cents
                           else v_row.amount_cents end);
  end loop;

  return v_lines;
end;
$$;
revoke execute on function public.invoice_lines_for(uuid, text)
  from public, anon;
