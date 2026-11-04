-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2380 — a QR reference frozen at issue, collision-free.
--
-- The QRR a Swiss QR-IBAN issuer prints was derived from the invoice
-- number's digits alone, so `F-2026-0402` and `U-2026-04-02` shared one
-- and a payment quoting it could not say which invoice it paid. From now on
-- every invoice that asks for money is given, when it is inserted, its own
-- QRR in `legal_snapshot.qrr`:
--
--   * the body is `1` followed by the next value of a dedicated sequence,
--     left-padded to 25 digits, then the recursive modulus-10 check digit
--     (Swiss implementation guidelines for the QR-bill, 27 digits);
--   * a sequence value is never handed out twice, so two invoices never
--     share a frozen reference, in one space or across spaces;
--   * the leading `1` keeps the frozen references apart from the derived
--     ones, which are zero-padded digits of a number (a number would need
--     26 digits to reach that position);
--   * the trigger overwrites whatever the insert carried: a caller never
--     chooses a reference;
--   * a credit note (total <= 0) asks for no payment and gets none.
--
-- The reference is frozen with the rest of the snapshot: the invoices
-- guard (`invoices_immutable`) refuses any later change of the row.
-- Invoices issued before this migration keep no `qrr`; the client keeps
-- deriving theirs from the number, and the bank matching accepts both.
--
-- The trigger is named after `invoice_legal_freeze` so it runs once the
-- snapshot exists (BEFORE triggers fire in name order).

create sequence if not exists public.invoice_qrr_seq;
revoke all on sequence public.invoice_qrr_seq from public, anon, authenticated;

create or replace function public.qrr_check_digit(p_body text)
returns int
language plpgsql immutable set search_path = public as $fn$
declare
  v_table constant int[] := array[0, 9, 4, 6, 8, 2, 7, 1, 3, 5];
  v_carry int := 0;
  i int;
begin
  if p_body !~ '^[0-9]+$' then
    raise exception 'a QR reference body is digits only';
  end if;
  for i in 1 .. length(p_body) loop
    v_carry := v_table[((v_carry + substr(p_body, i, 1)::int) % 10) + 1];
  end loop;
  return (10 - v_carry) % 10;
end;
$fn$;

revoke execute on function public.qrr_check_digit(text) from public, anon, authenticated;

create or replace function public.invoice_qrr_freeze()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare
  v_body text;
begin
  if new.total_cents > 0 then
    v_body := '1' || lpad(nextval('public.invoice_qrr_seq')::text, 25, '0');
    new.legal_snapshot := coalesce(new.legal_snapshot, '{}'::jsonb)
      || jsonb_build_object('qrr', v_body || public.qrr_check_digit(v_body)::text);
  elsif new.legal_snapshot ? 'qrr' then
    new.legal_snapshot := new.legal_snapshot - 'qrr';
  end if;
  return new;
end;
$fn$;

revoke execute on function public.invoice_qrr_freeze() from public, anon, authenticated;

drop trigger if exists invoice_qrr_freeze on public.invoices;
create trigger invoice_qrr_freeze
  before insert on public.invoices
  for each row execute function public.invoice_qrr_freeze();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(676);
