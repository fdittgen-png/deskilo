-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (compute_postings patched at two asserted anchors: the payment-out loop
-- also reads its allocation's payment, and that payment's entry is extended;
-- nothing else of any entry changes)
--
-- 0642 (#2380) -- money out gets the bank statement's value date and
-- reference, as money in did (0635 for the postings, 0641 for the DATEV
-- source). A payment out the engine books for a purchase (a supplier
-- payment: Dr suppliers / Cr bank; a member's reimbursement: Dr customers /
-- Cr bank) is the money of ONE outgoing payment, the one its settlement
-- allocation names (purchase_settlement_allocations.payment_id). When
-- exactly one reconciled statement line became that payment
-- (bank_statement_lines.outgoing_payment_id, 0603), the entry carries the
-- line's facts beside its own date:
--
--   value_date      the line's value date: the day the money left the bank.
--                   It is NOT the entry's `date` (the day the payment was
--                   reported as made, which still decides the period), not
--                   a tax point and not a validation date.
--   bank_reference  the line's reference, omitted when empty.
--
-- A payment no line explains, and every space that never imported a
-- statement, keep their entry byte for byte (`|| '{}'`). The exporters that
-- already read the keys on a receipt read them here too: the FEC (PieceDate,
-- PieceRef) and the DATEV Kreditor's payment row (Beleginfo Valutadatum /
-- Bankreferenz; its Belegdatum stays the entry's date). Xero books a
-- payment out as a manual journal on the entry's date; neither key reaches
-- it, and the posting digest does not read them.
--
-- The rule is bank_line_facts' (0641), mirrored on the outgoing column: the
-- facts when exactly one line names the payment, '{}' otherwise. The
-- outgoing column is unique among lines (bank_statement_lines_outgoing,
-- 0603), so "several lines" cannot arise today; the count stays so the two
-- helpers answer by the same rule. An invoker function, as bank_line_facts:
-- a member reads it under the line policies (bank_statement_reader), the
-- definer engine sees what it saw before.
--
-- Indexes: both lookups (payment_ledger_id for money in, outgoing_payment_id
-- for money out) are already served by 0603's unique partial indexes
-- bank_statement_lines_payment and bank_statement_lines_outgoing; a second,
-- non-unique index on the same column and predicate would only duplicate
-- them, so none is added.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  -- An anchor names one place: it occurs exactly once, or nothing is patched.
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon, authenticated;

-- The facts of the statement line that became the outgoing payment
-- [p_payment_id]: {value_date[, bank_reference]}; '{}' when not exactly one.
create or replace function public.bank_line_out_facts(p_workspace_id uuid, p_payment_id uuid)
returns jsonb language sql stable security invoker set search_path = public as $fn$
  with lines as (
    select l.value_date, l.reference
      from public.bank_statement_lines l
     where l.workspace_id = p_workspace_id
       and l.outgoing_payment_id is not null
       and l.outgoing_payment_id = p_payment_id
  )
  select case when (select count(*) from lines) = 1 then
    (select jsonb_build_object('value_date', value_date)
            || case when reference <> '' then jsonb_build_object('bank_reference', reference) else '{}'::jsonb end
       from lines)
  else '{}'::jsonb end;
$fn$;
revoke execute on function public.bank_line_out_facts(uuid, uuid) from public, anon;
grant execute on function public.bank_line_out_facts(uuid, uuid) to authenticated;

do $migration$
declare
  v_def text;
  v_patched text;
begin
  select pg_get_functiondef('public.compute_postings(uuid, uuid, date, date)'::regprocedure) into v_def;
  -- Idempotent: a definition that already asks for the outgoing line's facts stays.
  if position('bank_line_out_facts' in v_def) > 0 then
    return;
  end if;
  -- 1. The loop reads the payment its allocation names (last, so `order by 5`
  --    still names the payment day).
  v_patched := pg_temp.anchor_replace(v_def,
    $a$             o.creditor_kind
        from public.purchase_settlement_allocations a$a$,
    $a$             o.creditor_kind, a.payment_id
        from public.purchase_settlement_allocations a$a$);
  if v_patched is null then
    raise exception '0642: compute_postings anchor missing (payment-out select)';
  end if;
  -- 2. That payment's entry gains its line's facts, '{}' when none.
  v_patched := pg_temp.anchor_replace(v_patched,
    $a$        v_postings := v_postings || public.posting_entry('bank',
          case when pay.creditor_kind = 'member' then 'reimbursement' else 'supplier_payment' end,
          pay.paid_on, pay.id, pay.original_reference, pay.currency,
          public.posting_line(p_issuer_site_id,
            case when pay.creditor_kind = 'member' then 'customers' else 'suppliers' end,
            null, pay.paid_on, pay.amount, true)
          || public.posting_line(p_issuer_site_id, 'bank', null, pay.paid_on, pay.amount, false));$a$,
    $a$        v_postings := v_postings || jsonb_build_array((public.posting_entry('bank',
          case when pay.creditor_kind = 'member' then 'reimbursement' else 'supplier_payment' end,
          pay.paid_on, pay.id, pay.original_reference, pay.currency,
          public.posting_line(p_issuer_site_id,
            case when pay.creditor_kind = 'member' then 'customers' else 'suppliers' end,
            null, pay.paid_on, pay.amount, true)
          || public.posting_line(p_issuer_site_id, 'bank', null, pay.paid_on, pay.amount, false)) -> 0)
          || public.bank_line_out_facts(p_workspace_id, pay.payment_id));$a$);
  if v_patched is null then
    raise exception '0642: compute_postings anchor missing (payment-out entry)';
  end if;
  execute v_patched;
end
$migration$;

select public.set_deskilo_schema_version(642);
