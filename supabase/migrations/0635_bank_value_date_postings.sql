-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (compute_postings patched at one asserted anchor: the receipt of a matched
-- invoice is wrapped, nothing else of any entry changes)
--
-- 0635 (#2380) -- the bank statement's value date and reference reach the
-- books. A receipt the engine books for an invoice (Dr bank / Cr customers)
-- is the money of one or more payments the invoice consumed
-- (invoice_match_payments). When exactly one of those payments is the
-- payment a reconciled statement line became (bank_statement_lines.
-- payment_ledger_id, 0603), the entry now carries that line's facts beside
-- its own date:
--
--   value_date      the line's value date: the day the money moved at the
--                   bank. It is NOT the entry's `date` (the day the match was
--                   confirmed, which still decides the period), not a tax
--                   point and not a validation date; nothing is derived from
--                   it.
--   bank_reference  the reference the bank gave the line, omitted when empty.
--
-- An invoice paid by several lines (instalments), by a payment no statement
-- line explains, or in a space that never imported a statement, gets neither
-- key: its entry is byte-for-byte what it was. The exporters read the keys:
-- the FEC (PieceDate / PieceRef) and the Xero Payment (Date).

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

-- [p_entry] (one posting_entry, a one-element array) with the facts of the
-- statement line that became the one payment [p_invoice_id] consumed; the
-- entry itself when there is not exactly one such line.
create or replace function public.posting_bank_entry(
  p_workspace_id uuid, p_invoice_id uuid, p_entry jsonb
) returns jsonb language sql stable security definer set search_path = public as $fn$
  with lines as (
    select l.value_date, l.reference
      from public.bank_statement_lines l
     where l.workspace_id = p_workspace_id
       and l.payment_ledger_id is not null
       and l.payment_ledger_id in (
             select pay.payment_ledger_id
               from public.invoice_match_payments pay
              where pay.workspace_id = p_workspace_id and pay.invoice_id = p_invoice_id)
  )
  select case when (select count(*) from lines) = 1 then
    jsonb_build_array((p_entry -> 0) || (
      select jsonb_build_object('value_date', value_date)
             || case when reference <> '' then jsonb_build_object('bank_reference', reference) else '{}'::jsonb end
        from lines))
  else p_entry end;
$fn$;
revoke execute on function public.posting_bank_entry(uuid, uuid, jsonb) from public, anon, authenticated;

do $migration$
declare
  v_def text;
  v_patched text;
begin
  select pg_get_functiondef('public.compute_postings(uuid, uuid, date, date)'::regprocedure) into v_def;
  -- Idempotent: a definition that already asks for the line's facts stays.
  v_patched := case when position('posting_bank_entry' in v_def) > 0 then v_def end;
  v_patched := coalesce(v_patched, pg_temp.anchor_replace(v_def,
    $a$      v_postings := v_postings || public.posting_entry('bank',
        case when m.paid < 0 then 'refund' else 'receipt' end, v_day, m.id, m.number, m.currency,
        public.posting_line(p_issuer_site_id, 'bank', null, v_day, m.paid, true)
        || public.posting_line(p_issuer_site_id, 'customers', null, v_day, m.paid, false));$a$,
    $a$      v_postings := v_postings || public.posting_bank_entry(p_workspace_id, m.id, public.posting_entry('bank',
        case when m.paid < 0 then 'refund' else 'receipt' end, v_day, m.id, m.number, m.currency,
        public.posting_line(p_issuer_site_id, 'bank', null, v_day, m.paid, true)
        || public.posting_line(p_issuer_site_id, 'customers', null, v_day, m.paid, false)));$a$));
  if v_patched is null then
    raise exception '0635: compute_postings anchor missing';
  end if;
  execute v_patched;
end
$migration$;

select public.set_deskilo_schema_version(635);
