-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0365 (#1916) -- an invoice is not issued while its essentials are unknown.
--
-- create_invoice froze whatever the seller's settings and the buyer's
-- profile happened to hold: an invoice with no seller address, no buyer
-- name or an exempt line without its reason was issued like any other,
-- and the numbered document of record could not be taken back. The
-- essentials a VAT invoice needs (art. 226 directive 2006/112/EC) are now
-- checked on the parties the invoice is about to freeze:
--
--   seller_address        no street and no city
--   seller_vat_id         VAT-registered regime without a VAT identifier
--   exemption_reason      an exempt line (or a buyer treated as exempt)
--                         without the legal basis that exempts it
--   buyer_name            no name to address the document to
--   buyer_address         a business customer without a postal address
--   buyer_vat_id          reverse charge without the buyer's VAT identifier
--
-- Only issuing is blocked: previews, bookings and every other function are
-- untouched. The refusal carries the list in its DETAIL
-- (SQLSTATE DKI01), and `invoice_issue_readiness` answers the same list
-- WITHOUT issuing anything (a rolled-back dry run of the very same
-- create_invoice, so the preview and the issue cannot disagree).
--
-- A consumer is not asked for a postal address: the capacity is the one
-- the seller stated (member, else workspace default), never guessed.
--
-- Anchored patch: the anchor is asserted; a body without it fails the
-- migration rather than being skipped.

create or replace function public.invoice_essentials_missing(
  p_workspace_id uuid, p_member_id uuid, p_parties jsonb, p_vat_totals jsonb
) returns text[]
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_missing text[] := '{}';
  v_seller jsonb := coalesce(p_parties -> 'seller', '{}'::jsonb);
  v_buyer jsonb := coalesce(p_parties -> 'buyer', '{}'::jsonb);
  v_capacity text;
  v_exempt_line boolean;
  v_reverse boolean;
begin
  if btrim(coalesce(v_seller ->> 'street', '')) = ''
     and btrim(coalesce(v_seller ->> 'city', '')) = '' then
    v_missing := array_append(v_missing, 'seller_address'::text);
  end if;
  if v_seller ->> 'vat_regime' = 'vat_registered'
     and btrim(coalesce(v_seller ->> 'vat_id', '')) = '' then
    v_missing := array_append(v_missing, 'seller_vat_id'::text);
  end if;

  select coalesce(bool_or(t ->> 'category' in ('E', 'G')), false),
         coalesce(bool_or(t ->> 'category' = 'AE'), false)
    into v_exempt_line, v_reverse
    from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t;
  if v_exempt_line
     and btrim(coalesce(
           case when v_buyer ->> 'vat_treatment' in ('exempt', 'export')
                then v_buyer ->> 'tax_exemption_reason'
                else v_seller ->> 'tax_exemption_reason' end, '')) = '' then
    v_missing := array_append(v_missing, 'exemption_reason'::text);
  end if;
  if v_reverse and btrim(coalesce(v_buyer ->> 'vat_id', '')) = '' then
    v_missing := array_append(v_missing, 'buyer_vat_id'::text);
  end if;

  if btrim(coalesce(v_buyer ->> 'name', '')) = ''
     and btrim(coalesce(v_buyer ->> 'company', '')) = '' then
    v_missing := array_append(v_missing, 'buyer_name'::text);
  end if;
  v_capacity := public.invoice_legal_snapshot(p_workspace_id, p_member_id, p_parties)
                  ->> 'buyer_capacity';
  if v_capacity = 'business'
     and btrim(coalesce(v_buyer ->> 'street', '')) = ''
     and btrim(coalesce(v_buyer ->> 'city', '')) = '' then
    v_missing := array_append(v_missing, 'buyer_address'::text);
  end if;
  return v_missing;
end;
$fn$;

revoke execute on function public.invoice_essentials_missing(uuid, uuid, jsonb, jsonb)
  from public, anon, authenticated;

-- ── the gate inside create_invoice ─────────────────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_patched text;
  c_old constant text :=
    $a$  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  v_number := public.next_document_number(p_workspace_id, 'invoice');$a$;
  c_new constant text :=
    $a$  -- #1916 -- the essentials of a legal invoice, before a number is taken.
  v_essentials := public.invoice_essentials_missing(
    p_workspace_id, v_subject.id, v_parties, v_vat_totals);
  if cardinality(v_essentials) > 0 then
    raise exception 'invoice_essentials_missing'
      using errcode = 'DKI01', detail = array_to_string(v_essentials, ',');
  end if;

  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  v_number := public.next_document_number(p_workspace_id, 'invoice');$a$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p
   where p.proname = 'create_invoice' and p.pronamespace = 'public'::regnamespace
     and pg_get_function_identity_arguments(p.oid) like 'p_workspace_id uuid, p_member_id uuid, p_period text, p_replaces uuid, p_detailed boolean, p_kind text, p_allow_zero boolean, p_buyer_reference text, p_purchase_order text';
  if v_def is null then
    raise exception '0365: create_invoice not found';
  end if;
  v_patched := pg_temp.anchor_replace(v_def, c_old, c_new);
  if v_patched is null then
    raise exception '0365: the number anchor of create_invoice did not match';
  end if;
  v_patched := pg_temp.anchor_replace(
    v_patched, E'  v_site public.sites;\nbegin',
    E'  v_site public.sites;\n  v_essentials text[];\nbegin');
  if v_patched is null then
    raise exception '0365: the declaration anchor of create_invoice did not match';
  end if;
  execute v_patched;
end
$migration$;

-- ── the same question, without issuing ─────────────────────────────────
create or replace function public.invoice_issue_readiness(
  p_workspace_id uuid, p_member_id uuid, p_period text,
  p_kind text default 'full', p_replaces uuid default null
) returns text[]
language plpgsql security definer set search_path = public as $fn$
declare
  v_detail text;
begin
  if auth.uid() is null
     or not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'admins may not issue invoices here';
  end if;
  begin
    perform public.create_invoice(
      p_workspace_id, p_member_id, p_period, p_replaces, false, p_kind, true);
    -- Issued inside this block: undo it, nothing was missing.
    raise exception 'dry run' using errcode = 'DKI02';
  exception
    when sqlstate 'DKI01' then
      get stacked diagnostics v_detail = pg_exception_detail;
      return string_to_array(v_detail, ',');
    when sqlstate 'DKI02' then
      return '{}'::text[];
  end;
end;
$fn$;

revoke execute on function public.invoice_issue_readiness(uuid, uuid, text, text, uuid)
  from public, anon;
grant execute on function public.invoice_issue_readiness(uuid, uuid, text, text, uuid)
  to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(365);
