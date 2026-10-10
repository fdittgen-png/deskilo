-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0401 (#2355) — an invoice freezes the VAT tax point its seller's
-- country gives it when the workspace never chose one.
--
-- 0349 froze `vat_exigibility` as `coalesce(stored, 'invoice')`: a
-- French VAT-registered space that never chose was frozen on the debits
-- and its invoices printed « TVA acquittée sur les débits », although
-- the legal rule for services in France is receipts (CGI art. 269-2-c)
-- and the debits are an OPTION the seller must state on the invoice.
--
-- The app now stores the choice as `invoice_legal.vat_tax_point`
-- (`standard` | `invoice` | `cash`, absent = never chose) and writes the
-- two-value `vat_exigibility` beside it only for a non-default choice;
-- the default's value depends on the country, so it is derived here:
-- `payment` (receipts) for a French seller, `invoice` everywhere else —
-- which keeps the printed mention of every other country as it was.
-- A stored `vat_exigibility` still wins, so a space that chose (or an
-- older app that wrote the key) is frozen exactly as before.
--
-- Only the snapshot changes. Issued invoices keep the snapshot they
-- were issued with (`invoices_immutable`); submitted VAT declarations
-- are stored figures and are not touched.

create or replace function public.invoice_legal_snapshot(
  p_workspace_id uuid, p_member_id uuid, p_parties jsonb
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_legal jsonb;
  v_country text;
  v_member_terms jsonb;
  v_member_capacity text;
  v_default_capacity text;
  v_capacity text;
  v_source text;
  v_body jsonb;
begin
  select coalesce(w.invoice_legal, '{}'::jsonb), w.country_code
    into v_legal, v_country
    from public.workspaces w where w.id = p_workspace_id;
  select m.payment_terms, m.customer_capacity
    into v_member_terms, v_member_capacity
    from public.members m where m.id = p_member_id;
  v_default_capacity := v_legal ->> 'customer_capacity';
  if v_member_capacity in ('business', 'consumer') then
    v_capacity := v_member_capacity; v_source := 'member';
  elsif v_default_capacity in ('business', 'consumer') then
    v_capacity := v_default_capacity; v_source := 'workspace';
  else
    v_capacity := 'unknown'; v_source := 'none';
  end if;
  v_body := jsonb_build_object(
    'schema', 1,
    'seller_kind', coalesce(v_legal ->> 'seller_kind', ''),
    'seller_country', upper(coalesce(nullif(p_parties #>> '{seller,country}', ''),
                                     v_country, '')),
    'buyer_country', upper(coalesce(p_parties #>> '{buyer,country}', '')),
    'buyer_capacity', v_capacity,
    'capacity_source', v_source,
    'terms_source', case when v_member_terms is not null then 'member'
                         else 'workspace' end,
    'clauses', public.payment_terms_clean(v_legal)
               || coalesce(public.payment_terms_clean(v_member_terms), '{}'::jsonb),
    'legal_form', btrim(coalesce(v_legal ->> 'legal_form', '')),
    'registration', btrim(coalesce(v_legal ->> 'registration', '')),
    'insurance', btrim(coalesce(v_legal ->> 'insurance', '')),
    'special_mentions', btrim(coalesce(v_legal ->> 'special_mentions', '')),
    -- #2355: the stored option, or the seller country's legal default
    -- when the workspace never chose (France: services on receipts).
    'vat_exigibility', coalesce(v_legal ->> 'vat_exigibility',
      case when upper(coalesce(nullif(p_parties #>> '{seller,country}', ''),
                               v_country, '')) = 'FR'
           then 'payment' else 'invoice' end));
  return v_body || jsonb_build_object('fingerprint',
    encode(extensions.digest(convert_to(v_body::text, 'UTF8'), 'sha256'), 'hex'));
end;
$fn$;

-- The ACL 0349 gave it, restated where the function is created again.
revoke execute on function public.invoice_legal_snapshot(uuid, uuid, jsonb)
  from public, anon, authenticated;

select public.set_deskilo_schema_version(401);
